import Foundation
import ShogiCoachCore

struct ShallowAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let actualMove: String
    let bestMove: String
    let scoreText: String
    let blackPerspectiveCp: Int?
    let depthText: String
    let nodesText: String
    let npsText: String
    let pv: String
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let fixedNodeEvidence: VE1BSearchAttemptRecord?

    var matchesBestMove: Bool { actualMove == bestMove }
}

enum ShallowAnalysisAuthority {
    static let productionNodeBudget = 50_000
    static let productionSafetyCeilingMs = 15_000
    static let productionMultiPV = 1
    static let authorityStatus = "B6_SHALLOW_FIXED_NODE_PREMEASUREMENT_20261011"
}

@MainActor
final class ShallowAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ShallowAnalysisEntry] = []
    @Published private(set) var isRunning = false
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    private let session = EngineUSISession()

    func reset() {
        status = "未解析"
        summary = ""
        entries = []
        isRunning = false
        diagnosticURL = nil
        diagnosticError = nil
    }

    /// Production shallow analysis. B6 fixed-node authority replaces the old
    /// time-based 150 ms triage with a deterministic 50k-node cold search for
    /// every ply.
    func analyze(game: KIFGame, fileName: String? = nil) async {
        await analyzeFixedNodes(
            game: game,
            fileName: fileName,
            nodeBudget: ShallowAnalysisAuthority.productionNodeBudget,
            safetyCeilingMs: ShallowAnalysisAuthority.productionSafetyCeilingMs
        )
    }

    /// Legacy/time-based entry point retained only for existing diagnostic and
    /// fault-injection fixtures that explicitly request movetime. Production UI
    /// and B6 qualification must use the fixed-node overload above.
    func analyze(game: KIFGame, fileName: String? = nil, movetimeMs: Int) async {
        guard !game.moves.isEmpty else {
            status = "浅解析 未PASS"
            summary = "解析対象局面がありません"
            return
        }

        isRunning = true
        entries = []
        summary = ""
        diagnosticURL = nil
        diagnosticError = nil
        status = "浅解析 準備中"
        SimulatorStage.reset()
        SimulatorStage.mark("shallow_start_count_\(game.moves.count)")

        let totalStarted = ContinuousClock.now
        var finalError: String?

        do {
            try await session.beginAnalysis(multiPV: 1)

            var collected: [ShallowAnalysisEntry] = []
            collected.reserveCapacity(game.moves.count)

            for (index, move) in game.moves.enumerated() {
                let completed = index + 1
                status = "浅解析 \(completed)/\(game.moves.count)"
                SimulatorStage.mark("shallow_ply_\(move.ply)_start")

                let sample = try await session.analyzePosition(
                    command: move.positionBefore,
                    movetimeMs: movetimeMs
                )

                guard let primary = sample.result.principalVariations.first,
                      let score = primary.score,
                      !primary.pv.isEmpty else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "\(move.ply)手目のscore/PVが不足"
                    )
                }

                let scoreInfo = Self.scoreInfo(score, ply: move.ply)
                let entry = ShallowAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    bestMove: sample.result.bestMove.move,
                    scoreText: scoreInfo.text,
                    blackPerspectiveCp: scoreInfo.blackCp,
                    depthText: primary.depth.map(String.init) ?? "-",
                    nodesText: primary.nodes.map(String.init) ?? "-",
                    npsText: primary.nps.map(String.init) ?? "-",
                    pv: primary.pv.joined(separator: " "),
                    elapsedMs: sample.elapsedMs,
                    thermalBefore: sample.thermalBefore,
                    thermalAfter: sample.thermalAfter,
                    fixedNodeEvidence: nil
                )
                collected.append(entry)
                entries = collected

                SimulatorStage.mark(
                    "shallow_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)"
                )

                if sample.thermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()
            completeSummary(
                collected: collected,
                modeText: "legacy movetime: \(movetimeMs) ms/position",
                totalStarted: totalStarted
            )
            SimulatorStage.mark("shallow_complete_\(collected.count)")
            status = "浅解析 PASS"
        } catch {
            await session.endAnalysis()
            finalError = error.localizedDescription
            SimulatorStage.mark("shallow_error_\(error.localizedDescription)")
            status = "浅解析 未PASS"
            summary = [
                "completed: \(entries.count)/\(game.moves.count)",
                error.localizedDescription
            ].joined(separator: "\n")
        }

        await finishDiagnostic(
            game: game,
            fileName: fileName,
            requestedMoveTimeMs: movetimeMs,
            totalStarted: totalStarted,
            error: finalError
        )
        isRunning = false
    }

    func analyzeFixedNodes(
        game: KIFGame,
        fileName: String? = nil,
        nodeBudget: Int = ShallowAnalysisAuthority.productionNodeBudget,
        safetyCeilingMs: Int = ShallowAnalysisAuthority.productionSafetyCeilingMs
    ) async {
        guard !game.moves.isEmpty else {
            status = "浅解析 未PASS"
            summary = "解析対象局面がありません"
            return
        }
        guard nodeBudget > 0, safetyCeilingMs > 0 else {
            status = "浅解析 未PASS"
            summary = "fixed-node shallow policyが不正です"
            return
        }

        isRunning = true
        entries = []
        summary = ""
        diagnosticURL = nil
        diagnosticError = nil
        status = "浅解析 準備中"
        SimulatorStage.reset()
        SimulatorStage.mark("shallow_fixed_node_start_count_\(game.moves.count)")

        let totalStarted = ContinuousClock.now
        var finalError: String?

        do {
            try await session.beginAnalysis(multiPV: ShallowAnalysisAuthority.productionMultiPV)

            var collected: [ShallowAnalysisEntry] = []
            collected.reserveCapacity(game.moves.count)

            for (index, move) in game.moves.enumerated() {
                let completed = index + 1
                status = "浅解析 \(completed)/\(game.moves.count)"
                SimulatorStage.mark("shallow_fixed_node_ply_\(move.ply)_start")

                _ = try await session.resetForColdSeries(reason: "shallow_ply_\(move.ply)")
                let sample = try await session.analyzePositionNodes(
                    command: move.positionBefore,
                    nodeBudget: nodeBudget,
                    safetyCeilingMs: safetyCeilingMs,
                    role: .diagnostic,
                    searchMoves: [],
                    multiPV: ShallowAnalysisAuthority.productionMultiPV
                )
                let evidence = VE1BSearchAttemptRecord(
                    attemptID: "shallow-ply-\(move.ply)-\(nodeBudget)-tt\(sample.ttGeneration)",
                    positionCommand: move.positionBefore,
                    multiPV: ShallowAnalysisAuthority.productionMultiPV,
                    searchMoves: [],
                    measurementTarget: "shallow_selection",
                    sample: sample
                )

                guard sample.isNormalCompletedResult,
                      let result = sample.result,
                      let primary = result.principalVariations.first,
                      let score = primary.score,
                      let selectedMove = primary.pv.first else {
                    throw VE1BNodeComparisonFailure(
                        detail: "shallow ply \(move.ply) did not complete normally (\(sample.completion.rawValue))",
                        evidence: [evidence]
                    )
                }

                let scoreInfo = Self.scoreInfo(score, ply: move.ply)
                let entry = ShallowAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    bestMove: selectedMove,
                    scoreText: scoreInfo.text,
                    blackPerspectiveCp: scoreInfo.blackCp,
                    depthText: primary.depth.map(String.init) ?? "-",
                    nodesText: primary.nodes.map(String.init) ?? "-",
                    npsText: primary.nps.map(String.init) ?? "-",
                    pv: primary.pv.joined(separator: " "),
                    elapsedMs: sample.elapsedMs,
                    thermalBefore: sample.thermalBefore,
                    thermalAfter: sample.thermalAfter,
                    fixedNodeEvidence: evidence
                )
                collected.append(entry)
                entries = collected

                SimulatorStage.mark(
                    "shallow_fixed_node_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)_nodes_\(evidence.selectedNodes.map(String.init) ?? "-")"
                )

                if sample.thermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()
            completeSummary(
                collected: collected,
                modeText: "fixed nodes: \(nodeBudget)/position, cold TT, ceiling \(safetyCeilingMs) ms",
                totalStarted: totalStarted
            )
            SimulatorStage.mark("shallow_fixed_node_complete_\(collected.count)")
            status = "浅解析 PASS"
        } catch {
            await session.endAnalysis()
            finalError = error.localizedDescription
            SimulatorStage.mark("shallow_fixed_node_error_\(error.localizedDescription)")
            status = "浅解析 未PASS"
            summary = [
                "completed: \(entries.count)/\(game.moves.count)",
                "fixed nodes: \(nodeBudget)/position",
                error.localizedDescription
            ].joined(separator: "\n")
        }

        // DiagnosticExport's legacy field is movetime-shaped. Zero explicitly
        // means the production Shallow stage is node-budgeted; detailed fixed-
        // node provenance is retained in each ShallowAnalysisEntry for B6.
        await finishDiagnostic(
            game: game,
            fileName: fileName,
            requestedMoveTimeMs: 0,
            totalStarted: totalStarted,
            error: finalError
        )
        isRunning = false
    }

    private func completeSummary(
        collected: [ShallowAnalysisEntry],
        modeText: String,
        totalStarted: ContinuousClock.Instant
    ) {
        let totalElapsedMs = Self.elapsedMilliseconds(
            from: totalStarted,
            to: ContinuousClock.now
        )
        let elapsed = collected.map(\.elapsedMs).sorted()
        let medianElapsed = elapsed[elapsed.count / 2]
        let bestMatchCount = collected.filter(\.matchesBestMove).count
        let cpCount = collected.compactMap(\.blackPerspectiveCp).count

        summary = [
            "positions: \(collected.count)",
            modeText,
            "total elapsed: \(totalElapsedMs) ms",
            "median elapsed: \(medianElapsed) ms",
            "bestmove match: \(bestMatchCount)/\(collected.count)",
            "cp scores: \(cpCount)/\(collected.count)",
            "first: #\(collected.first?.ply ?? 0) \(collected.first?.scoreText ?? "-")",
            "last: #\(collected.last?.ply ?? 0) \(collected.last?.scoreText ?? "-")"
        ].joined(separator: "\n")
    }

    private func finishDiagnostic(
        game: KIFGame,
        fileName: String?,
        requestedMoveTimeMs: Int,
        totalStarted: ContinuousClock.Instant,
        error: String?
    ) async {
        let totalElapsedMs = Self.elapsedMilliseconds(
            from: totalStarted,
            to: ContinuousClock.now
        )
        do {
            diagnosticURL = try DiagnosticExporter.write(
                game: game,
                fileName: fileName,
                entries: entries,
                status: status,
                requestedMoveTimeMs: requestedMoveTimeMs,
                totalElapsedMs: totalElapsedMs,
                error: error
            )
            SimulatorStage.mark("diagnostic_json_written")
        } catch {
            diagnosticError = error.localizedDescription
            SimulatorStage.mark("diagnostic_json_error_\(error.localizedDescription)")
        }
    }

    private static func scoreInfo(_ score: USIScore, ply: Int) -> (text: String, blackCp: Int?) {
        switch score {
        case .centipawn(let value, _):
            let blackValue = ply.isMultiple(of: 2) ? -value : value
            return ("cp \(value)", blackValue)
        case .mate(let value, _):
            return ("mate \(value)", nil)
        }
    }

    private static func elapsedMilliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Int {
        let components = start.duration(to: end).components
        return Int(components.seconds * 1000)
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
