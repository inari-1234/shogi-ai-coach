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
    let bestPV: String
    let actualPV: String
    let actualAnalysisSource: String
    let opponentBestReply: String
    let candidates: [DeepCandidateLine]
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let comparisonStable: Bool
    let instabilityReasons: [String]
    let continuationStable: Bool
    let continuationInstabilityReasons: [String]
    let analysisAttempts: Int
    let finalMovetimeMs: Int
    let adaptiveTriggered: Bool
    let topCandidateGapCp: Int?
    let stabilityState: String
    let confirmedBestPVPlyCount: Int
    let confirmedActualPVPlyCount: Int
    let nodePolicyAuthorityStatus: String
    let candidateDiscoveryNodes: Int
    let confirmationNodeTiers: [Int]
    let safetyCeilingMs: Int
    let finalNodeBudget: Int
    let searchEvidence: [VE1BSearchAttemptRecord]
}

struct DeepAnalysisCompletionCounts: Equatable, Sendable {
    let stable: Int
    let unstable: Int
    let unconfirmed: Int

    var total: Int { stable + unstable + unconfirmed }

    static func classify(_ entries: [DeepAnalysisEntry]) -> Self {
        var stable = 0
        var unstable = 0
        var unconfirmed = 0
        for entry in entries {
            switch entry.stabilityState {
            case VE1BStabilityState.stable.rawValue:
                stable += 1
            case VE1BStabilityState.unstable.rawValue:
                unstable += 1
            case VE1BStabilityState.unconfirmed.rawValue,
                 VE1BStabilityState.unknown.rawValue:
                unconfirmed += 1
            default:
                // An unknown future label must never disappear from the accounting.
                unconfirmed += 1
            }
        }
        return .init(stable: stable, unstable: unstable, unconfirmed: unconfirmed)
    }
}

enum DeepAnalysisRunState: Equatable, Sendable {
    case idle
    case running
    case completed(DeepAnalysisCompletionCounts)
    case incomplete(reason: String, completedPositions: Int, expectedPositions: Int)
    case error(message: String)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var completionCounts: DeepAnalysisCompletionCounts? {
        if case .completed(let counts) = self { return counts }
        return nil
    }

    var displayText: String {
        switch self {
        case .idle:
            return "深掘り 未解析"
        case .running:
            return "深掘り 解析中"
        case .completed(let counts):
            return "深掘り 完了（安定 \(counts.stable) / 不安定 \(counts.unstable) / 未確認 \(counts.unconfirmed)）"
        case .incomplete(_, let completed, let expected):
            return "深掘り 未完了（\(completed)/\(expected)局面）"
        case .error(let message):
            return "深掘り エラー: \(message)"
        }
    }
}

@MainActor
final class DeepAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var runState: DeepAnalysisRunState = .idle
    @Published private(set) var summary = ""

    var displayStatus: String { runState.displayText }
    @Published private(set) var entries: [DeepAnalysisEntry] = []
    @Published private(set) var isRunning = false
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?
    @Published private(set) var searchEvidenceURL: URL?

    private(set) var incompleteSearchEvidence: [VE1BSearchAttemptRecord] = []
    private let session = EngineUSISession()

    func reset() {
        status = "未解析"
        runState = .idle
        summary = ""
        entries = []
        isRunning = false
        diagnosticURL = nil
        diagnosticError = nil
        searchEvidenceURL = nil
        incompleteSearchEvidence = []
    }

    func analyze(
        game: KIFGame,
        shallowEntries: [ShallowAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?,
        deepMovetimeMs: Int = 800,
        multiPV: Int = 3,
        maxPositions: Int = 5,
        nodePolicy: VE1BNodeSearchPolicy = .calibrationUnfrozen
    ) async {
        guard shallowEntries.count == game.moves.count,
              !shallowEntries.isEmpty else {
            status = "深掘り 未PASS"
            let message = "工程3の全局面解析結果が揃っていません"
            runState = .error(message: message)
            summary = message
            return
        }
        guard let sourceDiagnosticURL else {
            status = "深掘り 未PASS"
            let message = "工程3の診断JSONがありません"
            runState = .error(message: message)
            summary = message
            return
        }

        // This legacy parameter only preserves the pre-VE1-B position-selection
        // mode used by regression fixtures. It is no longer an engine search
        // budget. All deep engine searches below are node-budgeted.
        let productionSelectionMode = deepMovetimeMs >= 800
        let provisionalLimit = productionSelectionMode
            ? min(8, max(maxPositions, 7))
            : maxPositions
        let selection = Self.selectImportantPositions(
            game: game,
            entries: shallowEntries,
            maxPositions: provisionalLimit
        )
        guard !selection.items.isEmpty else {
            status = "深掘り 未PASS"
            let message = "重要局面候補を抽出できません"
            runState = .error(message: message)
            summary = message
            return
        }

        isRunning = true
        entries = []
        summary = ""
        diagnosticURL = nil
        diagnosticError = nil
        searchEvidenceURL = nil
        incompleteSearchEvidence = []
        status = "深掘り 準備中"
        runState = .running
        SimulatorStage.mark("deep_start_count_\(selection.items.count)")

        let totalStarted = ContinuousClock.now
        var finalError: String?
        var analyzedEntries: [DeepAnalysisEntry] = []

        do {
            try await session.beginAnalysis(multiPV: multiPV)
            analyzedEntries.reserveCapacity(selection.items.count)

            for (offset, selected) in selection.items.enumerated() {
                status = "深掘り \(offset + 1)/\(selection.items.count)"
                let move = game.moves[selected.index]
                let shallow = shallowEntries[selected.index]
                SimulatorStage.mark("deep_ply_\(move.ply)_start")

                let comparison = try await VE1BNodeComparisonAnalyzer.analyze(
                    session: session,
                    command: move.positionBefore,
                    actualMove: move.usi,
                    candidateCount: multiPV,
                    policy: nodePolicy
                )
                let final = comparison.finalAttempt

                let candidateLines = comparison.candidateLines.enumerated().map { index, line in
                    DeepCandidateLine(
                        id: index + 1,
                        rank: index + 1,
                        move: line.move,
                        scoreText: line.scoreText,
                        centipawn: line.centipawn,
                        depthText: line.depth.map(String.init) ?? "-",
                        nodesText: line.nodes.map(String.init) ?? "-",
                        npsText: line.nps.map(String.init) ?? "-",
                        pv: line.pvText,
                        opponentReply: line.opponentReply
                    )
                }

                let source = final.bestLine.move == move.usi
                    ? "node-equal-condition-same-move"
                    : "node-equal-condition"
                let confirmedBestPV = comparison.confirmedBestPV
                let confirmedActualPV = comparison.confirmedActualPV
                let entry = DeepAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    shallowBestMove: shallow.bestMove,
                    shallowEstimatedLossCp: selected.estimatedLossCp,
                    bestMove: final.bestLine.move,
                    bestScoreText: final.bestLine.scoreText,
                    actualScoreText: final.actualLine.scoreText,
                    actualLossCp: comparison.comparisonStable ? final.lossCp : nil,
                    bestPV: confirmedBestPV.joined(separator: " "),
                    actualPV: confirmedActualPV.joined(separator: " "),
                    actualAnalysisSource: source,
                    opponentBestReply: confirmedBestPV.dropFirst().first ?? "-",
                    candidates: candidateLines,
                    elapsedMs: comparison.totalElapsedMs,
                    thermalBefore: comparison.discoveryEvidence.thermalBefore,
                    thermalAfter: final.evidence.thermalAfter,
                    comparisonStable: comparison.comparisonStable,
                    instabilityReasons: comparison.comparisonInstabilityReasons,
                    continuationStable: comparison.continuationStable,
                    continuationInstabilityReasons: comparison.continuationInstabilityReasons,
                    analysisAttempts: comparison.evidenceRecords.count,
                    finalMovetimeMs: 0,
                    adaptiveTriggered: comparison.attempts.count > 1,
                    topCandidateGapCp: comparison.topCandidateGapCp,
                    stabilityState: comparison.stability.state.rawValue,
                    confirmedBestPVPlyCount: confirmedBestPV.count,
                    confirmedActualPVPlyCount: confirmedActualPV.count,
                    nodePolicyAuthorityStatus: nodePolicy.authorityStatus,
                    candidateDiscoveryNodes: nodePolicy.candidateDiscoveryNodes,
                    confirmationNodeTiers: nodePolicy.confirmationNodeTiers,
                    safetyCeilingMs: nodePolicy.safetyCeilingMs,
                    finalNodeBudget: comparison.finalNodeBudget,
                    searchEvidence: comparison.evidenceRecords
                )
                analyzedEntries.append(entry)

                SimulatorStage.mark(
                    "deep_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)_stability_\(entry.stabilityState)_final_nodes_\(entry.finalNodeBudget)_attempts_\(entry.analysisAttempts)"
                )

                if final.evidence.thermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()

            entries = productionSelectionMode
                ? Self.finalizeImportantEntries(
                    analyzedEntries,
                    maxPositions: maxPositions
                )
                : analyzedEntries
            let counts = DeepAnalysisCompletionCounts.classify(entries)
            guard counts.total == entries.count else {
                throw EngineUSISession.ProbeError.protocolError(
                    "深掘り状態件数不整合: stable+unstable+unconfirmed=\(counts.total), entries=\(entries.count)"
                )
            }
            runState = .completed(counts)
            status = "深掘り PASS"
        } catch {
            await session.endAnalysis()
            if let failure = error as? VE1BNodeComparisonFailure {
                incompleteSearchEvidence = failure.evidence
                status = "深掘り 未PASS（解析未完了）"
                runState = .incomplete(
                    reason: error.localizedDescription,
                    completedPositions: analyzedEntries.count,
                    expectedPositions: selection.items.count
                )
            } else {
                status = "深掘り 未PASS"
                runState = .error(message: error.localizedDescription)
            }
            entries = productionSelectionMode
                ? Self.finalizeImportantEntries(
                    analyzedEntries,
                    maxPositions: maxPositions
                )
                : analyzedEntries
            finalError = error.localizedDescription
            SimulatorStage.mark("deep_error_\(error.localizedDescription)")
        }

        let totalElapsedMs = Self.elapsedMilliseconds(
            from: totalStarted,
            to: ContinuousClock.now
        )

        do {
            searchEvidenceURL = try VE1BSearchEvidenceExporter.write(
                status: status,
                policy: nodePolicy,
                positions: analyzedEntries.map { entry in
                    VE1BPositionEvidenceRecord(
                        ply: entry.ply,
                        stabilityState: entry.stabilityState,
                        confirmedBestPVPlyCount: entry.confirmedBestPVPlyCount,
                        confirmedActualPVPlyCount: entry.confirmedActualPVPlyCount,
                        attempts: entry.searchEvidence
                    )
                },
                incompleteAttempts: incompleteSearchEvidence,
                error: finalError
            )
            SimulatorStage.mark("ve1b_search_evidence_json_written")
        } catch {
            let evidenceError = "VE1-B探索証拠JSON更新失敗: \(error.localizedDescription)"
            diagnosticError = evidenceError
            finalError = finalError.map { "\($0); \(evidenceError)" } ?? evidenceError
            status = "深掘り 未PASS"
            runState = .error(message: evidenceError)
            SimulatorStage.mark("ve1b_search_evidence_json_error_\(error.localizedDescription)")
        }

        summary = Self.makeSummary(
            entries: entries,
            provisionalCount: selection.items.count,
            analyzedCount: analyzedEntries.count,
            multiPV: multiPV,
            totalElapsedMs: totalElapsedMs,
            focus: selection.focus,
            policy: nodePolicy,
            productionSelectionMode: productionSelectionMode,
            error: finalError
        )

        let deepInfo = ShogiDiagnosticDocument.DeepAnalysisInfo(
            status: status,
            requestedMoveTimeMs: 0,
            multiPV: multiPV,
            selectedPositions: selection.items.count,
            completedPositions: entries.count,
            totalElapsedMs: totalElapsedMs,
            focus: selection.focus,
            adaptivePolicy: "ve1b-node-\(nodePolicy.authorityStatus)",
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
                    bestPV: entry.bestPV,
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
                    thermalAfter: entry.thermalAfter,
                    comparisonStable: entry.comparisonStable,
                    instabilityReasons: entry.instabilityReasons,
                    continuationStable: entry.continuationStable,
                    continuationInstabilityReasons: entry.continuationInstabilityReasons,
                    analysisAttempts: entry.analysisAttempts,
                    finalMovetimeMs: 0,
                    adaptiveTriggered: entry.adaptiveTriggered,
                    topCandidateGapCp: entry.topCandidateGapCp
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
            let message = error.localizedDescription
            diagnosticError = diagnosticError.map { "\($0); \(message)" } ?? message
            status = "深掘り 未PASS"
            runState = .error(message: "診断JSON更新失敗: \(message)")
            summary += "\n診断JSON更新失敗: \(message)"
            SimulatorStage.mark("deep_diagnostic_json_error_\(message)")
        }

        if case .completed(let counts) = runState {
            SimulatorStage.mark(
                "deep_complete_\(entries.count)_stable_\(counts.stable)_unstable_\(counts.unstable)_unconfirmed_\(counts.unconfirmed)"
            )
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

        let limit = max(1, min(8, maxPositions))
        return Selection(items: Array(candidates.prefix(limit)), focus: focus)
    }

    private static func finalizeImportantEntries(
        _ analyzed: [DeepAnalysisEntry],
        maxPositions: Int
    ) -> [DeepAnalysisEntry] {
        let candidates = analyzed.map { entry in
            DeepImportanceCandidate(
                ply: entry.ply,
                shallowEstimatedLossCp: entry.shallowEstimatedLossCp,
                actualLossCp: entry.actualLossCp,
                bestMove: entry.bestMove,
                actualMove: entry.actualMove,
                bestScoreText: entry.bestScoreText,
                actualScoreText: entry.actualScoreText,
                opponentBestReply: entry.opponentBestReply,
                comparisonStable: entry.comparisonStable
            )
        }
        return DeepImportanceSelector.selectIndices(
            candidates,
            maxPositions: maxPositions
        ).map { analyzed[$0] }
    }

    private static func makeSummary(
        entries: [DeepAnalysisEntry],
        provisionalCount: Int,
        analyzedCount: Int,
        multiPV: Int,
        totalElapsedMs: Int,
        focus: String,
        policy: VE1BNodeSearchPolicy,
        productionSelectionMode: Bool,
        error: String?
    ) -> String {
        let counts = DeepAnalysisCompletionCounts.classify(entries)
        let continuationStable = entries.filter(\.continuationStable).count
        var lines = [
            "focus: \(focus)",
            "provisional positions: \(provisionalCount)",
            "analyzed positions: \(analyzedCount)",
            "final important positions: \(entries.count)",
            "position selection mode: \(productionSelectionMode ? "production" : "regression")",
            "search budget mode: nodes",
            "node policy: \(policy.authorityStatus)",
            "candidate discovery tiers: \(policy.candidateDiscoveryNodeTiers.map(String.init).joined(separator: ",")) nodes / MultiPV \(multiPV) / cold each tier",
            "fixed-pair confirmation tiers: \(policy.confirmationNodeTiers.map(String.init).joined(separator: ",")) nodes",
            "safety ceiling: \(policy.safetyCeilingMs) ms (abort only)",
            "search series: cold MultiPV each discovery tier -> independent cold MultiPV1 searchmoves for recommended and actual at every tier",
            "comparison stable: \(counts.stable)/\(entries.count)",
            "comparison unstable: \(counts.unstable)/\(entries.count)",
            "comparison unconfirmed: \(counts.unconfirmed)/\(entries.count)",
            "continuation stable: \(continuationStable)/\(entries.count)",
            "total elapsed: \(totalElapsedMs) ms"
        ]
        for entry in entries {
            let loss = entry.actualLossCp.map { "\($0)cp" }
                ?? "\(entry.stabilityState)"
            lines.append(
                "#\(entry.ply) loss \(loss) best \(entry.bestMove) / actual \(entry.actualMove) [\(entry.actualAnalysisSource)] / final \(entry.finalNodeBudget) nodes x\(entry.analysisAttempts)"
            )
        }
        if let error { lines.append("解析が完了しませんでした: \(error)") }
        return lines.joined(separator: "\n")
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
