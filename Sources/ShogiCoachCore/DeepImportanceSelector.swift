import Foundation

public struct DeepImportanceCandidate: Equatable, Sendable {
    public let ply: Int
    public let shallowEstimatedLossCp: Int?
    public let actualLossCp: Int?
    public let bestMove: String
    public let actualMove: String
    public let bestScoreText: String
    public let actualScoreText: String
    public let opponentBestReply: String
    public let comparisonStable: Bool

    public init(
        ply: Int,
        shallowEstimatedLossCp: Int?,
        actualLossCp: Int?,
        bestMove: String,
        actualMove: String,
        bestScoreText: String,
        actualScoreText: String,
        opponentBestReply: String,
        comparisonStable: Bool
    ) {
        self.ply = ply
        self.shallowEstimatedLossCp = shallowEstimatedLossCp
        self.actualLossCp = actualLossCp
        self.bestMove = bestMove
        self.actualMove = actualMove
        self.bestScoreText = bestScoreText
        self.actualScoreText = actualScoreText
        self.opponentBestReply = opponentBestReply
        self.comparisonStable = comparisonStable
    }
}

public enum DeepImportanceSelector {
    // Legacy FV16-era threshold. VE1-C must recalibrate this under FV24 using
    // behavior/semantic evidence rather than mechanically rescaling the number.
    public static let legacyMeaningfulLossThresholdCp = 80

    public static func selectIndices(
        _ candidates: [DeepImportanceCandidate],
        maxPositions: Int
    ) -> [Int] {
        guard !candidates.isEmpty else { return [] }

        let limit = max(1, min(5, maxPositions))
        let ranked = candidates.indices.sorted {
            let left = importanceScore(candidates[$0])
            let right = importanceScore(candidates[$1])
            if left != right { return left > right }
            return candidates[$0].ply < candidates[$1].ply
        }

        var selected: [Int] = []
        for index in ranked {
            let candidate = candidates[index]
            let meaningful = isMeaningful(candidate)
            if !meaningful && !selected.isEmpty { continue }
            if selected.contains(where: { likelySameEvent(candidates[$0], candidate) }) {
                continue
            }
            selected.append(index)
            if selected.count == limit { break }
        }

        if selected.isEmpty, let first = ranked.first {
            selected = [first]
        }
        return selected.sorted { candidates[$0].ply < candidates[$1].ply }
    }

    public static func lossForImportance(_ candidate: DeepImportanceCandidate) -> Int {
        if candidate.comparisonStable {
            return candidate.actualLossCp ?? candidate.shallowEstimatedLossCp ?? 0
        }
        // Deep-search instability is confidence metadata. When the deep comparison is
        // unstable, importance is derived from the already-selected shallow loss signal.
        return candidate.shallowEstimatedLossCp ?? 0
    }

    public static func importanceScore(_ candidate: DeepImportanceCandidate) -> Int {
        var value = lossForImportance(candidate) * 10
        if candidate.bestScoreText.hasPrefix("mate "),
           !candidate.actualScoreText.hasPrefix("mate ") {
            value += 10_000
        }
        if candidate.bestMove != candidate.actualMove { value += 100 }
        return value
    }

    public static func isMeaningful(_ candidate: DeepImportanceCandidate) -> Bool {
        lossForImportance(candidate) >= legacyMeaningfulLossThresholdCp
            || (candidate.bestScoreText.hasPrefix("mate ")
                && !candidate.actualScoreText.hasPrefix("mate "))
    }

    private static func likelySameEvent(
        _ lhs: DeepImportanceCandidate,
        _ rhs: DeepImportanceCandidate
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
}
