import Foundation
import ShogiCoachCore

struct AdaptiveEngineLine {
    let move: String
    let score: USIScore
    let scoreText: String
    let centipawn: Int?
    let depthText: String
    let nodesText: String
    let npsText: String
    let pvMoves: [String]

    var pvText: String { pvMoves.joined(separator: " ") }
    var opponentReply: String { pvMoves.dropFirst().first ?? "-" }
}

struct AdaptiveComparisonAttempt {
    let movetimeMs: Int
    let candidateLines: [AdaptiveEngineLine]
    let bestLine: AdaptiveEngineLine
    let actualLine: AdaptiveEngineLine
    let lossCp: Int?
    let topGapCp: Int?
    let extensionReasons: [String]
    let unstableReasons: [String]
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
}

enum AdaptiveAnalysisPolicy {
    case productionV1
    case experimentalV2
}

struct AdaptiveComparisonResult {
    let attempts: [AdaptiveComparisonAttempt]
    let stable: Bool
    let instabilityReasons: [String]
    let comparisonStable: Bool
    let continuationStable: Bool
    let comparisonInstabilityReasons: [String]
    let continuationInstabilityReasons: [String]

    var finalAttempt: AdaptiveComparisonAttempt { attempts[attempts.count - 1] }
    var finalMovetimeMs: Int { finalAttempt.movetimeMs }
    var adaptiveTriggered: Bool { attempts.count > 1 }
    var totalElapsedMs: Int { attempts.reduce(0) { $0 + $1.elapsedMs } }
}

enum AdaptiveComparisonAnalyzer {
    private static let closeCandidateThresholdCp = 40
    private static let lossSwingThresholdCp = 120
    private static let minimumBestPVPlies = 4
    private static let minimumActualPVPlies = 3
    private static let decisiveConfirmationThresholdCp = 1_500
    private static let minimumConfirmedBestPVPrefixPlies = 3
    private static let minimumConfirmedActualPVPrefixPlies = 2

    static func analyze(
        session: EngineUSISession,
        command: String,
        actualMove: String,
        baseMovetimeMs: Int,
        candidateCount: Int = 3,
        policy: AdaptiveAnalysisPolicy = .productionV1
    ) async throws -> AdaptiveComparisonResult {
        let tiers = analysisTiers(baseMovetimeMs: baseMovetimeMs)
        var attempts: [AdaptiveComparisonAttempt] = []
        var previousBestMove: String?
        var previousBestScoreKind: String?
        var previousActualScoreKind: String?
        var previousLossCp: Int?
        var previousBestPV: [String]?
        var previousActualPV: [String]?

        for (index, movetimeMs) in tiers.enumerated() {
            let candidateSample = try await session.analyzePosition(
                command: command,
                movetimeMs: movetimeMs,
                multiPV: max(1, candidateCount)
            )
            let candidates = candidateSample.result.principalVariations
                .prefix(max(1, candidateCount))
                .compactMap(makeLine)

            guard let discoveredBest = candidates.first else {
                throw EngineUSISession.ProbeError.protocolError(
                    "MultiPV候補にscore/PVがありません"
                )
            }

            let searchMoves = discoveredBest.move == actualMove
                ? [discoveredBest.move]
                : [discoveredBest.move, actualMove]
            let compareSample = try await session.analyzePosition(
                command: command,
                movetimeMs: movetimeMs,
                searchMoves: searchMoves,
                multiPV: searchMoves.count
            )
            let compared = compareSample.result.principalVariations.compactMap(makeLine)

            guard let comparedBest = compared.first(where: { $0.move == discoveredBest.move }) else {
                throw EngineUSISession.ProbeError.protocolError(
                    "同条件比較で最善候補のscore/PVがありません"
                )
            }
            let comparedActual: AdaptiveEngineLine
            if discoveredBest.move == actualMove {
                comparedActual = comparedBest
            } else {
                guard let line = compared.first(where: { $0.move == actualMove }) else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "同条件比較で実戦手のscore/PVがありません"
                    )
                }
                comparedActual = line
            }

            let lossCp = centipawnLoss(best: comparedBest, actual: comparedActual)
            let topGapCp = candidateGap(candidates)
            var extensionReasons: [String] = []
            var unstableReasons: [String] = []

            if discoveredBest.move != actualMove,
               isBetter(comparedActual.score, than: comparedBest.score) {
                extensionReasons.append("comparison_inversion")
                unstableReasons.append("comparison_inversion")
            }

            if let previousBestMove, previousBestMove != discoveredBest.move {
                extensionReasons.append("bestmove_changed")
                unstableReasons.append("bestmove_changed")
            }

            let bestKind = scoreKind(comparedBest.score)
            let actualKind = scoreKind(comparedActual.score)
            if let previousBestScoreKind, previousBestScoreKind != bestKind {
                extensionReasons.append("best_score_kind_changed")
                unstableReasons.append("best_score_kind_changed")
            }
            if let previousActualScoreKind, previousActualScoreKind != actualKind {
                extensionReasons.append("actual_score_kind_changed")
                unstableReasons.append("actual_score_kind_changed")
            }

            if let previousLossCp, let lossCp,
               abs(previousLossCp - lossCp) >= lossSwingThresholdCp {
                extensionReasons.append("loss_changed")
                unstableReasons.append("loss_changed")
            }

            if let topGapCp, topGapCp <= closeCandidateThresholdCp {
                extensionReasons.append("top_candidates_close")
            }

            if !isMate(comparedBest.score),
               comparedBest.pvMoves.count < minimumBestPVPlies {
                extensionReasons.append("best_pv_short")
            }
            if !isMate(comparedActual.score),
               comparedActual.pvMoves.count < minimumActualPVPlies {
                extensionReasons.append("actual_pv_short")
            }

            if policy == .experimentalV2 {
                if index == 0,
                   isDecisiveNonMate(comparedBest.score) {
                    extensionReasons.append("decisive_confirmation")
                }

                if let previousBestPV,
                   previousBestPV.count >= minimumConfirmedBestPVPrefixPlies,
                   comparedBest.pvMoves.count >= minimumConfirmedBestPVPrefixPlies,
                   !samePrefix(
                       previousBestPV,
                       comparedBest.pvMoves,
                       count: minimumConfirmedBestPVPrefixPlies
                   ) {
                    extensionReasons.append("best_pv_changed")
                }

                if let previousActualPV,
                   previousActualPV.count >= minimumConfirmedActualPVPrefixPlies,
                   comparedActual.pvMoves.count >= minimumConfirmedActualPVPrefixPlies,
                   !samePrefix(
                       previousActualPV,
                       comparedActual.pvMoves,
                       count: minimumConfirmedActualPVPrefixPlies
                   ) {
                    extensionReasons.append("actual_pv_changed")
                }
            }

            let attempt = AdaptiveComparisonAttempt(
                movetimeMs: movetimeMs,
                candidateLines: candidates,
                bestLine: comparedBest,
                actualLine: comparedActual,
                lossCp: lossCp,
                topGapCp: topGapCp,
                extensionReasons: extensionReasons,
                unstableReasons: unstableReasons,
                elapsedMs: candidateSample.elapsedMs + compareSample.elapsedMs,
                thermalBefore: candidateSample.thermalBefore,
                thermalAfter: compareSample.thermalAfter
            )
            attempts.append(attempt)

            previousBestMove = discoveredBest.move
            previousBestScoreKind = bestKind
            previousActualScoreKind = actualKind
            previousLossCp = lossCp
            previousBestPV = comparedBest.pvMoves
            previousActualPV = comparedActual.pvMoves

            let hasNextTier = index + 1 < tiers.count
            if extensionReasons.isEmpty || !hasNextTier {
                break
            }
        }

        guard let final = attempts.last else {
            throw EngineUSISession.ProbeError.protocolError("適応型解析結果がありません")
        }

        let comparisonReasons = Array(Set(final.unstableReasons)).sorted()
        var continuationReasons: [String] = []
        if final.extensionReasons.contains("best_pv_short") {
            continuationReasons.append("best_pv_short")
        }
        if final.extensionReasons.contains("actual_pv_short") {
            continuationReasons.append("actual_pv_short")
        }
        if policy == .experimentalV2,
           final.extensionReasons.contains("best_pv_changed") {
            continuationReasons.append("best_pv_changed")
        }
        if policy == .experimentalV2,
           final.extensionReasons.contains("actual_pv_changed") {
            continuationReasons.append("actual_pv_changed")
        }
        continuationReasons = Array(Set(continuationReasons)).sorted()
        let finalUnstableReasons = Array(
            Set(comparisonReasons + continuationReasons)
        ).sorted()

        return AdaptiveComparisonResult(
            attempts: attempts,
            stable: finalUnstableReasons.isEmpty,
            instabilityReasons: finalUnstableReasons,
            comparisonStable: comparisonReasons.isEmpty,
            continuationStable: continuationReasons.isEmpty,
            comparisonInstabilityReasons: comparisonReasons,
            continuationInstabilityReasons: continuationReasons
        )
    }

    static func analysisTiers(baseMovetimeMs: Int) -> [Int] {
        let base = max(50, baseMovetimeMs)
        guard base >= 800 else { return [base] }

        let second = min(2400, max(1600, base * 2))
        var result = [base, second, 2400]
        var seen = Set<Int>()
        result = result.filter { value in
            guard !seen.contains(value) else { return false }
            seen.insert(value)
            return true
        }
        return result
    }

    static func scoreText(_ score: USIScore) -> String {
        switch score {
        case .centipawn(let value, _): return "cp \(value)"
        case .mate(let value, _): return "mate \(value)"
        }
    }

    static func centipawn(_ score: USIScore) -> Int? {
        switch score {
        case .centipawn(let value, _): return value
        case .mate: return nil
        }
    }

    private static func makeLine(_ info: USIInfo) -> AdaptiveEngineLine? {
        guard let score = info.score, let move = info.pv.first else { return nil }
        return AdaptiveEngineLine(
            move: move,
            score: score,
            scoreText: scoreText(score),
            centipawn: centipawn(score),
            depthText: info.depth.map(String.init) ?? "-",
            nodesText: info.nodes.map(String.init) ?? "-",
            npsText: info.nps.map(String.init) ?? "-",
            pvMoves: info.pv
        )
    }

    private static func centipawnLoss(
        best: AdaptiveEngineLine,
        actual: AdaptiveEngineLine
    ) -> Int? {
        if best.move == actual.move { return 0 }
        guard let bestCp = best.centipawn, let actualCp = actual.centipawn else {
            return nil
        }
        guard bestCp >= actualCp else { return nil }
        return bestCp - actualCp
    }

    private static func candidateGap(_ candidates: [AdaptiveEngineLine]) -> Int? {
        guard candidates.count >= 2,
              let first = candidates[0].centipawn,
              let second = candidates[1].centipawn else {
            return nil
        }
        return max(0, first - second)
    }

    private static func scoreKind(_ score: USIScore) -> String {
        switch score {
        case .centipawn: return "cp"
        case .mate(let value, _): return value >= 0 ? "mate_win" : "mate_loss"
        }
    }

    private static func isMate(_ score: USIScore) -> Bool {
        if case .mate = score { return true }
        return false
    }

    private static func isDecisiveNonMate(_ score: USIScore) -> Bool {
        guard case .centipawn(let value, _) = score else { return false }
        return abs(value) >= decisiveConfirmationThresholdCp
    }

    private static func samePrefix(
        _ lhs: [String],
        _ rhs: [String],
        count: Int
    ) -> Bool {
        guard lhs.count >= count, rhs.count >= count else { return false }
        return Array(lhs.prefix(count)) == Array(rhs.prefix(count))
    }

    private static func isBetter(_ lhs: USIScore, than rhs: USIScore) -> Bool {
        let left = orderingKey(lhs)
        let right = orderingKey(rhs)
        if left.category != right.category {
            return left.category > right.category
        }
        return left.value > right.value
    }

    private static func orderingKey(_ score: USIScore) -> (category: Int, value: Int) {
        switch score {
        case .centipawn(let value, _):
            return (1, value)
        case .mate(let value, _):
            if value >= 0 {
                return (2, -abs(value))
            }
            return (0, abs(value))
        }
    }
}
