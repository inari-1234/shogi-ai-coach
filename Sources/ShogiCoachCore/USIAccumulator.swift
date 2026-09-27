import Foundation

public struct USIAccumulator: Sendable {
    private var latestByMultiPV: [Int: USIInfo] = [:]

    public init() {}

    public mutating func consume(_ line: String) -> EngineProbeResult? {
        if let info = USIParser.parseInfo(line), !info.pv.isEmpty {
            if shouldReplace(current: latestByMultiPV[info.multipv], with: info) {
                latestByMultiPV[info.multipv] = info
            }
            return nil
        }

        if let bestMove = USIParser.parseBestMove(line) {
            let pvs = latestByMultiPV.values.sorted { $0.multipv < $1.multipv }
            return EngineProbeResult(bestMove: bestMove, principalVariations: pvs)
        }

        return nil
    }

    private func shouldReplace(current: USIInfo?, with candidate: USIInfo) -> Bool {
        guard let current else { return true }
        let currentDepth = current.depth ?? -1
        let candidateDepth = candidate.depth ?? -1
        if candidateDepth != currentDepth { return candidateDepth > currentDepth }
        return (candidate.timeMs ?? 0) >= (current.timeMs ?? 0)
    }
}
