import Foundation

/// Selects the deepest fully completed exact iterative-deepening snapshot from
/// raw USI observations.
///
/// A deeper bounded line is terminal/search-progress evidence, not a completed
/// exact measurement. The returned observations retain their own original
/// depth/nodes; no shallower result is relabeled as a deeper target result.
public enum USICompletedIterationSelector {
    public static func deepestExactSnapshot(
        observations: [USIInfo],
        requiredMultiPV: Int
    ) -> [USIInfo]? {
        guard requiredMultiPV > 0 else { return nil }

        let exactScored = observations.enumerated().compactMap { index, info -> (Int, USIInfo)? in
            guard let depth = info.depth,
                  (1...requiredMultiPV).contains(info.multipv),
                  info.score != nil,
                  info.hasExactScore,
                  !info.pv.isEmpty else {
                return nil
            }
            return (index, info)
        }

        let depths = Set(exactScored.compactMap { $0.1.depth }).sorted(by: >)
        for depth in depths {
            var snapshot: [USIInfo] = []
            var complete = true

            for rank in 1...requiredMultiPV {
                let candidates = exactScored.filter {
                    $0.1.depth == depth && $0.1.multipv == rank
                }
                guard let selected = candidates.max(by: { lhs, rhs in
                    if lhs.1.nodes != rhs.1.nodes {
                        return (lhs.1.nodes ?? 0) < (rhs.1.nodes ?? 0)
                    }
                    if lhs.1.timeMs != rhs.1.timeMs {
                        return (lhs.1.timeMs ?? 0) < (rhs.1.timeMs ?? 0)
                    }
                    return lhs.0 < rhs.0
                })?.1 else {
                    complete = false
                    break
                }
                snapshot.append(selected)
            }

            if complete {
                return snapshot.sorted { $0.multipv < $1.multipv }
            }
        }

        return nil
    }
}
