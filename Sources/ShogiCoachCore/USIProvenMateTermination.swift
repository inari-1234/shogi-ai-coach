import Foundation

/// Qualifies the narrow case where a node-budget search ends before the
/// requested node count because the engine has already produced a coherent,
/// exact mate result for every requested MultiPV rank.
///
/// This predicate establishes search-completion provenance only. It does not
/// assign winning/losing mate semantics; mate-sign interpretation remains a
/// separate policy concern.
public enum USIProvenMateTermination {
    public static func qualifies(
        measurementResult: EngineProbeResult?,
        terminalResult: EngineProbeResult?,
        requiredMultiPV: Int,
        safetyAborted: Bool
    ) -> Bool {
        guard !safetyAborted,
              requiredMultiPV > 0,
              let measurementResult,
              let terminalResult,
              terminalResult.bestMoveConsistency == .consistent,
              measurementResult.bestMove.move == terminalResult.bestMove.move,
              measurementResult.principalVariations.count == requiredMultiPV else {
            return false
        }

        var seenRanks = Set<Int>()
        for line in measurementResult.principalVariations {
            guard (1...requiredMultiPV).contains(line.multipv),
                  seenRanks.insert(line.multipv).inserted,
                  line.hasExactScore,
                  !line.pv.isEmpty,
                  let score = line.score else {
                return false
            }

            if case .mate(_, let bound) = score {
                guard bound == nil else { return false }
            } else {
                return false
            }
        }

        guard seenRanks == Set(1...requiredMultiPV),
              let primary = measurementResult.principalVariations.first(where: { $0.multipv == 1 }),
              primary.pvHead == terminalResult.bestMove.move else {
            return false
        }

        return true
    }
}
