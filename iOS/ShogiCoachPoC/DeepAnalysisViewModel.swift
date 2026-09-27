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
    let analysisAttempts: Int
    let finalMovetimeMs: Int
    let adaptiveTriggered: Bool
    let topCandidateGapCp: Int?
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

        let productionQualityMode = deepMovetimeMs >= 800
        let provisionalLimit = productionQualityMode
            ? min(8, max(maxPositions, 7))
            : maxPositions
        let selection = Self.selectImportantPositions(
            game: game,
            entries: shallowEntries,
            maxPositions: provisionalLimit
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
        var analyzedEntries: [DeepAnalysisEntry] = []

        do {
            try await session.beginAnalysis(multiPV: multiPV)
            analyzedEntries.reserveCapacity(selection.items.count)

            for (offset, selected) in selection.items.enumerated() {
                status = "深掘り \(offset + 1)/\(selection.items.count)"
                let move = game.moves[selected.index]
                let shallow = shallowEntries[selected.index]
                SimulatorStage.mark("deep_ply_\(move.ply)_start")

                let comparison = try await AdaptiveComparisonAnalyzer.analyze(
                    session: session,
                    command: move.positionBefore,
                    actualMove: move.usi,
                    baseMovetimeMs: deepMovetimeMs,
                    candidateCount: multiPV
                )
                let final = comparison.finalAttempt

                let candidateLines = final.candidateLines.enumerated().map { index, line in
                    DeepCandidateLine(
                        id: index + 1,
                        rank: index + 1,
                        move: line.move,
                        scoreText: line.scoreText,
                        centipawn: line.centipawn,
                        depthText: line.depthText,
                        nodesText: line.nodesText,
                        npsText: line.npsText,
                        pv: line.pvText,
                        opponentReply: line.opponentReply
                    )
                }

                let source = final.bestLine.move == move.usi
                    ? "equal-condition-same-move"
                    : "equal-condition"
                let entry = DeepAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    shallowBestMove: shallow.bestMove,
                    shallowEstimatedLossCp: selected.estimatedLossCp,
                    bestMove: final.bestLine.move,
                    bestScoreText: final.bestLine.scoreText,
                    actualScoreText: final.actualLine.scoreText,
                    actualLossCp: comparison.stable ? final.lossCp : nil,
                    bestPV: final.bestLine.pvText,
                    actualPV: final.actualLine.pvText,
                    actualAnalysisSource: source,
                    opponentBestReply: final.bestLine.opponentReply,
                    candidates: candidateLines,
                    elapsedMs: comparison.totalElapsedMs,
                    thermalBefore: comparison.attempts.first?.thermalBefore ?? "unknown",
                    thermalAfter: final.thermalAfter,
                    comparisonStable: comparison.stable,
                    instabilityReasons: comparison.instabilityReasons,
                    analysisAttempts: comparison.attempts.count,
                    finalMovetimeMs: comparison.finalMovetimeMs,
                    adaptiveTriggered: comparison.adaptiveTriggered,
                    topCandidateGapCp: final.topGapCp
                )
                analyzedEntries.append(entry)

                SimulatorStage.mark(
                    "deep_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)_stable_\(entry.comparisonStable)_attempts_\(entry.analysisAttempts)"
                )

                if final.thermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()

            entries = productionQualityMode
                ? Self.finalizeImportantEntries(
                    analyzedEntries,
                    maxPositions: maxPositions
                )
                : analyzedEntries
            status = "深掘り PASS"
        } catch {
            await session.endAnalysis()
            entries = productionQualityMode
                ? Self.finalizeImportantEntries(
                    analyzedEntries,
                    maxPositions: maxPositions
                )
                : analyzedEntries
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
            provisionalCount: selection.items.count,
            analyzedCount: analyzedEntries.count,
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
                    analysisAttempts: entry.analysisAttempts,
                    finalMovetimeMs: entry.finalMovetimeMs,
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

        let limit = max(1, min(8, maxPositions))
        return Selection(items: Array(candidates.prefix(limit)), focus: focus)
    }

    private static func finalizeImportantEntries(
        _ analyzed: [DeepAnalysisEntry],
        maxPositions: Int
    ) -> [DeepAnalysisEntry] {
        guard !analyzed.isEmpty else { return [] }
        let limit = max(1, min(5, maxPositions))
        let ranked = analyzed.sorted {
            let left = verifiedImportance($0)
            let right = verifiedImportance($1)
            if left != right { return left > right }
            return $0.ply < $1.ply
        }

        var selected: [DeepAnalysisEntry] = []
        for entry in ranked {
            let meaningful = !entry.comparisonStable
                || (entry.actualLossCp ?? 0) >= 80
                || (entry.bestScoreText.hasPrefix("mate ")
                    && !entry.actualScoreText.hasPrefix("mate "))
            if !meaningful && !selected.isEmpty { continue }
            if selected.contains(where: { likelySameEvent($0, entry) }) { continue }
            selected.append(entry)
            if selected.count == limit { break }
        }

        if selected.isEmpty, let first = ranked.first {
            selected = [first]
        }
        return selected.sorted { $0.ply < $1.ply }
    }

    private static func verifiedImportance(_ entry: DeepAnalysisEntry) -> Int {
        var value = (entry.actualLossCp ?? entry.shallowEstimatedLossCp ?? 0) * 10
        if !entry.comparisonStable { value += 2_000 }
        if entry.bestScoreText.hasPrefix("mate "),
           !entry.actualScoreText.hasPrefix("mate ") {
            value += 10_000
        }
        if entry.bestMove != entry.actualMove { value += 100 }
        return value
    }

    private static func likelySameEvent(
        _ lhs: DeepAnalysisEntry,
        _ rhs: DeepAnalysisEntry
    ) -> Bool {
        guard abs(lhs.ply - rhs.ply) <= 4 else { return false }
        let sameBestDestination = moveDestination(lhs.bestMove) == moveDestination(rhs.bestMove)
        let sameReplyDestination = moveDestination(lhs.opponentBestReply)
            == moveDestination(rhs.opponentBestReply)
        return sameBestDestination && sameReplyDestination
    }

    private static func moveDestination(_ move: String) -> String {
        guard move != "-", move.count >= 2 else { return move }
        return String(move.suffix(2))
    }

    private static func makeSummary(
        entries: [DeepAnalysisEntry],
        provisionalCount: Int,
        analyzedCount: Int,
        deepMovetimeMs: Int,
        multiPV: Int,
        totalElapsedMs: Int,
        focus: String,
        error: String?
    ) -> String {
        let adaptive = entries.filter(\.adaptiveTriggered).count
        let unstable = entries.filter { !$0.comparisonStable }.count
        var lines = [
            "focus: \(focus)",
            "provisional positions: \(provisionalCount)",
            "analyzed positions: \(analyzedCount)",
            "final important positions: \(entries.count)",
            "deep base: \(deepMovetimeMs) ms",
            "MultiPV discovery: \(multiPV)",
            "comparison: equal-condition searchmoves",
            "adaptive extended: \(adaptive)",
            "unstable final: \(unstable)",
            "total elapsed: \(totalElapsedMs) ms"
        ]
        for entry in entries {
            let loss = entry.actualLossCp.map { "\($0)cp" }
                ?? (entry.comparisonStable ? "mate/unknown" : "unstable")
            lines.append(
                "#\(entry.ply) loss \(loss) best \(entry.bestMove) / actual \(entry.actualMove) [\(entry.actualAnalysisSource)] / \(entry.finalMovetimeMs)ms x\(entry.analysisAttempts)"
            )
        }
        if let error { lines.append(error) }
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
