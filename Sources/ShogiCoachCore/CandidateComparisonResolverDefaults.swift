import Foundation

public extension CandidateComparisonResolver {
    static func compare(
        comparisonID: String,
        pairKind: CandidatePairKind,
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis
    ) -> CandidateComparison {
        compare(
            comparisonID: comparisonID,
            pairKind: pairKind,
            candidateA: candidateA,
            candidateB: candidateB,
            requestedAxes: [
                .evaluation,
                .capture,
                .material,
                .promotion,
                .check,
                .mateState,
                .kingSafety,
                .exchangeConsequence,
                .opponentReply,
                .boardEffect,
                .sequenceEvent
            ]
        )
    }
}
