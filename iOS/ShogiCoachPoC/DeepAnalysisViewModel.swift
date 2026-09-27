import Foundation
import ShogiCoachCore

struct DeepCandidateLine: Identifiable {
    let id: Int
    let rank: Int
    let move: String
    let scoreText: String
    let centipawn: Int?
    let depthText: String
    let nodesText: String
    let npsText: String
    let pv: String
    let opponentReply: String
}

struct DeepAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let actualMove: String
    let shallowBestMove: String
    let shallowEstimatedLossCp: Int?
    let bestMove: String
    let bestScoreText: String
    let actualScoreText: String
    let actualLossCp: Int?
    let actualPV: String
    let actualAnalysisSource: String
    let opponentBestReply: String
    let candidates: [DeepCandidateLine]
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
}

@MainActor
final class DeepAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [DeepAnalysisEntry] = []
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

    func analyze(
        game: KIFGame,
        shallowEntries: [ShallowAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?,
        deepMovetimeMs: Int = 800,
        multiPV: Int = 3,
        maxPositions: Int = 5
    ) async {
        guard shallowEntries.count == game.moves.count,
              !shallowEntries.isEmpty else {
            status = "深掘り 未PASS"
            summary = "工程3の全局面解析結果が揃っていません"
            return
        }
        guard let sourceDiagnosticURL else {
            status = "深掘り 未PASS"
            summary = "工程3の診断JSONがありません"
            return
        }

        let selection = Self.selectImportantPositions(
            game: game,
            entries: shallowEntries,
            maxPositions: maxPositions
        )
        guard !selection.items.isEmpty else {
            status = "深掘り 未PASS"
            summary = "重要局面候補を抽出できません"
            return
        }

        isRunning = true
        entries = []
        summary = ""
        diagnosticURL = nil
        diagnosticError = nil
        status = "深掘り 準備中"
        SimulatorStage.mark("deep_start_count_\(selection.items.count)")

        let totalStarted = ContinuousClock.now
        var finalError: String?

        do {
            try await session.beginAnalysis(multiPV: multiPV)
            var collected: [DeepAnalysisEntry] = []
            collected.reserveCapacity(selection.items.count)

            for (offset, selected) in selection.items.enumerated() {
                status = "深掘り \(offset + 1)/\(selection.items.count)"
                let move = game.moves[selected.index]
                let shallow = shallowEntries[selected.index]
                SimulatorStage.mark("deep_ply_\(move.ply)_start")

                let candidateSample = try await session.analyzePosition(
                    command: move.positionBefore,
                    movetimeMs: deepMovetimeMs
                )

                let candidateLines: [DeepCandidateLine] = candidateSample.result.principalVariations
                    .prefix(max(1, multiPV))
                    .enumerated()
                    .compactMap { index, pv in
                        guard let score = pv.score, !pv.pv.isEmpty else { return nil }
                        let moves = pv.pv
                        return DeepCandidateLine(
                            id: index + 1,
                            rank: index + 1,
                            move: moves[0],
                            scoreText: Self.scoreText(score),
                            centipawn: Self.centipawn(score),
                            depthText: pv.depth.map(String.init) ?? "-",
                            nodesText: pv.nodes.map(String.init) ?? "-",
                            npsText: pv.nps.map(String.init) ?? "-",
                            pv: moves.joined(separator: " "),
                            opponentReply: moves.dropFirst().first ?? "-"
                        )
                    }

                guard let bestLine = candidateLines.first else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "\(move.ply)手目のMultiPVが不足"
                    )
                }

                let actualScoreText: String
                let actualCp: Int?
                let actualPVText: String
                let actualAnalysisSource: String
                let actualElapsedMs: Int
                let actualThermalAfter: String

                if let actualCandidate = candidateLines.first(where: { $0.move == move.usi }) {
                    actualScoreText = actualCandidate.scoreText
                    actualCp = actualCandidate.centipawn
                    actualPVText = actualCandidate.pv
                    actualAnalysisSource = "multipv"
                    actualElapsedMs = 0
                    actualThermalAfter = candidateSample.thermalAfter
                } else {
                    let actualSample = try await session.analyzePosition(
                        command: move.positionBefore,
                        movetimeMs: deepMovetimeMs,
                        searchMoves: [move.usi]
                    )
                    guard actualSample.result.bestMove.move == move.usi,
                          let actualPV = actualSample.result.principalVariations.first,
                          let actualScore = actualPV.score,
                          !actualPV.pv.isEmpty else {
                        throw EngineUSISession.ProbeError.protocolError(
                            "\(move.ply)手目の実戦手限定解析が不正"
                        )
                    }

                    actualScoreText = Self.scoreText(actualScore)
                    actualCp = Self.centipawn(actualScore)
                    actualPVText = actualPV.pv.joined(separator: " ")
                    actualAnalysisSource = "searchmoves"
                    actualElapsedMs = actualSample.elapsedMs
                    actualThermalAfter = actualSample.thermalAfter
                }

                let lossCp: Int?
                if let bestCp = bestLine.centipawn, let actualCp {
                    lossCp = max(0, bestCp - actualCp)
                } else {
                    lossCp = nil
                }

                let elapsed = candidateSample.elapsedMs + actualElapsedMs
                let entry = DeepAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    shallowBestMove: shallow.bestMove,
                    shallowEstimatedLossCp: selected.estimatedLossCp,
                    bestMove: bestLine.move,
                    bestScoreText: bestLine.scoreText,
                    actualScoreText: actualScoreText,
                    actualLossCp: lossCp,
                    actualPV: actualPVText,
                    actualAnalysisSource: actualAnalysisSource,
                    opponentBestReply: bestLine.opponentReply,
                    candidates: candidateLines,
                    elapsedMs: elapsed,
                    thermalBefore: candidateSample.thermalBefore,
                    thermalAfter: actualThermalAfter
                )
                collected.append(entry)
                entries = collected

                SimulatorStage.mark(
                    "deep_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)"
                )

                if candidateSample.thermalAfter == "critical"
                    || actualThermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()
            status = "深掘り PASS"
        } catch {
            await session.endAnalysis()
            finalError = error.localizedDescription
            status = "深掘り 未PASS"
            SimulatorStage.mark("deep_error_\(error.localizedDescription)")
        }

        let totalElapsedMs = Self.elapsedMilliseconds(
            from: totalStarted,
            to: ContinuousClock.now
        )

        summary = Self.makeSummary(
            entries: entries,
            selectedCount: selection.items.count,
            deepMovetimeMs: deepMovetimeMs,
            multiPV: multiPV,
            totalElapsedMs: totalElapsedMs,
            focus: selection.focus,
            error: finalError
        )

        let deepInfo = ShogiDiagnosticDocument.DeepAnalysisInfo(
            status: status,
            requestedMoveTimeMs: deepMovetimeMs,
            multiPV: multiPV,
            selectedPositions: selection.items.count,
            completedPositions: entries.count,
            totalElapsedMs: totalElapsedMs,
            focus: selection.focus,
            positions: entries.map { entry in
                .init(
                    ply: entry.ply,
                    actualMove: entry.actualMove,
                    shallowBestMove: entry.shallowBestMove,
                    shallowEstimatedLossCp: entry.shallowEstimatedLossCp,
                    bestMove: entry.bestMove,
                    bestScore: entry.bestScoreText,
                    actualScore: entry.actualScoreText,
                    actualLossCp: entry.actualLossCp,
                    actualPV: entry.actualPV,
                    actualAnalysisSource: entry.actualAnalysisSource,
                    opponentBestReply: entry.opponentBestReply,
                    candidates: entry.candidates.map { candidate in
                        .init(
                            rank: candidate.rank,
                            move: candidate.move,
                            score: candidate.scoreText,
                            centipawn: candidate.centipawn,
                            depth: candidate.depthText,
                            nodes: candidate.nodesText,
                            nps: candidate.npsText,
                            pv: candidate.pv,
                            opponentReply: candidate.opponentReply
                        )
                    },
                    elapsedMs: entry.elapsedMs,
                    thermalBefore: entry.thermalBefore,
                    thermalAfter: entry.thermalAfter
                )
            },
            error: finalError
        )

        do {
            diagnosticURL = try DiagnosticExporter.augmentWithDeepAnalysis(
                url: sourceDiagnosticURL,
                deepAnalysis: deepInfo
            )
            SimulatorStage.mark("deep_diagnostic_json_written")
        } catch {
            diagnosticError = error.localizedDescription
            status = "深掘り 未PASS"
            summary += "\n診断JSON更新失敗: \(error.localizedDescription)"
            SimulatorStage.mark("deep_diagnostic_json_error_\(error.localizedDescription)")
        }

        if status == "深掘り PASS" {
            SimulatorStage.mark("deep_complete_\(entries.count)")
        }
        isRunning = false
    }

    private struct SelectedPosition {
        let index: Int
        let estimatedLossCp: Int?
        let importance: Int
    }

    private struct Selection {
        let items: [SelectedPosition]
        let focus: String
    }

    private static func selectImportantPositions(
        game: KIFGame,
        entries: [ShallowAnalysisEntry],
        maxPositions: Int
    ) -> Selection {
        let sente = game.metadata["先手"] ?? ""
        let gote = game.metadata["後手"] ?? ""
        let focusParity: Int?
        let focus: String

        if sente.contains("あなた"), !gote.contains("あなた") {
            focusParity = 1
            focus = "先手"
        } else if gote.contains("あなた"), !sente.contains("あなた") {
            focusParity = 0
            focus = "後手"
        } else {
            focusParity = nil
            focus = "両者"
        }

        var candidates: [SelectedPosition] = []
        for index in entries.indices {
            let entry = entries[index]
            if let focusParity, entry.ply % 2 != focusParity { continue }

            let isBlackMove = entry.ply % 2 == 1
            var estimatedLossCp: Int?
            if let beforeBlack = entry.blackPerspectiveCp,
               index + 1 < entries.count,
               let afterBlack = entries[index + 1].blackPerspectiveCp {
                let beforeMover = isBlackMove ? beforeBlack : -beforeBlack
                let afterMover = isBlackMove ? afterBlack : -afterBlack
                estimatedLossCp = max(0, beforeMover - afterMover)
            }

            var importance = estimatedLossCp ?? 0
            if !entry.matchesBestMove { importance += 120 }
            if entry.scoreText.hasPrefix("mate ") { importance += 700 }
            if estimatedLossCp == nil && !entry.matchesBestMove { importance += 180 }

            candidates.append(
                SelectedPosition(
                    index: index,
                    estimatedLossCp: estimatedLossCp,
                    importance: importance
                )
            )
        }

        candidates.sort {
            if $0.importance != $1.importance { return $0.importance > $1.importance }
            return entries[$0.index].ply < entries[$1.index].ply
        }

        let limit = max(1, min(5, maxPositions))
        return Selection(items: Array(candidates.prefix(limit)), focus: focus)
    }

    private static func makeSummary(
        entries: [DeepAnalysisEntry],
        selectedCount: Int,
        deepMovetimeMs: Int,
        multiPV: Int,
        totalElapsedMs: Int,
        focus: String,
        error: String?
    ) -> String {
        var lines = [
            "focus: \(focus)",
            "important positions: \(entries.count)/\(selectedCount)",
            "deep: \(deepMovetimeMs) ms x best+actual",
            "MultiPV: \(multiPV)",
            "total elapsed: \(totalElapsedMs) ms"
        ]
        for entry in entries {
            let loss = entry.actualLossCp.map { "\($0)cp" } ?? "mate/unknown"
            lines.append(
                "#\(entry.ply) loss \(loss) best \(entry.bestMove) / actual \(entry.actualMove) [\(entry.actualAnalysisSource)] / reply \(entry.opponentBestReply)"
            )
        }
        if let error { lines.append(error) }
        return lines.joined(separator: "\n")
    }

    private static func scoreText(_ score: USIScore) -> String {
        switch score {
        case .centipawn(let value, _): return "cp \(value)"
        case .mate(let value, _): return "mate \(value)"
        }
    }

    private static func centipawn(_ score: USIScore) -> Int? {
        switch score {
        case .centipawn(let value, _): return value
        case .mate: return nil
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
