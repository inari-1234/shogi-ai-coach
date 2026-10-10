import Foundation

extension DeepAnalysisEntry {
    /// Semantic/explanation authority. These values contain only the PV prefix
    /// confirmed by VE1-B stability evaluation. Empty is a valid result when
    /// the comparison/continuation has not converged.
    var confirmedBestPV: String { bestPV }
    var confirmedActualPV: String { actualPV }

    /// Observation-only reference PV from the deepest successful direct
    /// measurement. This is intentionally NOT explanation authority and must
    /// never be used by Reason/HDS/Continuation to fill a missing confirmed PV.
    var referenceBestPV: String {
        referencePV(measurementTarget: "recommended_move")
    }

    /// Observation-only reference PV from the deepest successful direct
    /// measurement. This is intentionally NOT explanation authority.
    var referenceActualPV: String {
        referencePV(measurementTarget: "actual_move")
    }

    private func referencePV(measurementTarget: String) -> String {
        let eligible = searchEvidence.filter {
            $0.measurementTarget == measurementTarget
                && $0.completion == EngineNodeSearchCompletion.nodeBudgetReached.rawValue
                && $0.selectedBoundKind == "exact"
                && !$0.selectedPV.isEmpty
        }
        guard let deepest = eligible.max(by: { lhs, rhs in
            if lhs.nodeBudget != rhs.nodeBudget {
                return lhs.nodeBudget < rhs.nodeBudget
            }
            return (lhs.selectedDepth ?? -1) < (rhs.selectedDepth ?? -1)
        }) else {
            return ""
        }
        return deepest.selectedPV.joined(separator: " ")
    }
}
