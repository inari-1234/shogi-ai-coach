import Foundation

public enum VE1BPhysicalQualificationMetrics {
    public struct PairwiseJaccard: Equatable, Sendable {
        public let leftRunIndex: Int
        public let rightRunIndex: Int
        public let value: Double

        public init(leftRunIndex: Int, rightRunIndex: Int, value: Double) {
            self.leftRunIndex = leftRunIndex
            self.rightRunIndex = rightRunIndex
            self.value = value
        }
    }

    public struct ModalTop1: Equatable, Sendable {
        public let ply: Int?
        public let count: Int
        public let totalRuns: Int

        public init(ply: Int?, count: Int, totalRuns: Int) {
            self.ply = ply
            self.count = count
            self.totalRuns = totalRuns
        }
    }

    public static func jaccard(_ lhs: [Int], _ rhs: [Int]) -> Double {
        let left = Set(lhs)
        let right = Set(rhs)
        let union = left.union(right)
        guard !union.isEmpty else { return 1.0 }
        return Double(left.intersection(right).count) / Double(union.count)
    }

    public static func pairwiseJaccards(_ runs: [[Int]]) -> [PairwiseJaccard] {
        guard runs.count >= 2 else { return [] }
        var output: [PairwiseJaccard] = []
        for left in 0..<(runs.count - 1) {
            for right in (left + 1)..<runs.count {
                output.append(
                    PairwiseJaccard(
                        leftRunIndex: left,
                        rightRunIndex: right,
                        value: jaccard(runs[left], runs[right])
                    )
                )
            }
        }
        return output
    }

    public static func modalTop1(_ runs: [[Int]]) -> ModalTop1 {
        let values = runs.compactMap(\.first)
        guard !values.isEmpty else {
            return ModalTop1(ply: nil, count: 0, totalRuns: runs.count)
        }

        let counts = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        let best = counts.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key < $1.key
        }.first!
        return ModalTop1(ply: best.key, count: best.value, totalRuns: runs.count)
    }

    public static func median(_ values: [Int]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (Double(sorted[middle - 1]) + Double(sorted[middle])) / 2.0
        }
        return Double(sorted[middle])
    }

    /// Nearest-rank P95 required by the frozen B6 contract:
    /// rank = ceil(0.95 * N), one-based, capped at N.
    public static func nearestRankP95(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let rank = min(sorted.count, Int(ceil(0.95 * Double(sorted.count))))
        return sorted[max(0, rank - 1)]
    }
}
