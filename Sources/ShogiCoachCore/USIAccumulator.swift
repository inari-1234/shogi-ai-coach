import Foundation

public struct USIAccumulator: Sendable {
    private var latestScoredByMultiPV: [Int: USIInfo] = [:]
    private var observations: [USIInfo] = []

    public init() {}

    public mutating func consume(_ line: String) -> EngineProbeResult? {
        if let info = USIParser.parseInfo(line) {
            if !line.hasPrefix("info string ") {
                observations.append(info)
            }

            if !info.pv.isEmpty,
               info.score != nil,
               shouldReplace(current: latestScoredByMultiPV[info.multipv], with: info) {
                latestScoredByMultiPV[info.multipv] = info
            }
            return nil
        }

        if let bestMove = USIParser.parseBestMove(line) {
            let pvs = latestScoredByMultiPV.values.sorted { $0.multipv < $1.multipv }
            let consistency: USIBestMoveConsistency
            if let primary = pvs.first(where: { $0.multipv == 1 }),
               let head = primary.pv.first {
                consistency = head == bestMove.move ? .consistent : .inconsistent
            } else {
                consistency = .unavailable
            }
            return EngineProbeResult(
                bestMove: bestMove,
                principalVariations: pvs,
                observations: observations,
                bestMoveConsistency: consistency
            )
        }

        return nil
    }

    private func shouldReplace(current: USIInfo?, with candidate: USIInfo) -> Bool {
        guard candidate.score != nil else { return false }
        guard let current else { return true }

        let currentDepth = current.depth ?? -1
        let candidateDepth = candidate.depth ?? -1
        if candidateDepth != currentDepth {
            return candidateDepth > currentDepth
        }

        let currentExact = current.hasExactScore
        let candidateExact = candidate.hasExactScore
        if currentExact != candidateExact {
            return candidateExact
        }

        if candidate.nodes != current.nodes {
            return (candidate.nodes ?? 0) >= (current.nodes ?? 0)
        }
        return (candidate.timeMs ?? 0) >= (current.timeMs ?? 0)
    }
}
