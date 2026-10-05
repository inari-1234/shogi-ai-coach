import Foundation

public struct CandidateComparisonDiagnostic: Codable, Equatable, Sendable {
    public struct Candidate: Codable, Equatable, Sendable {
        public let id: String
        public let rank: Int
        public let move: String
        public let score: String
        public let scoreKind: String
        public let branchType: String
        public let comparisonStable: Bool
        public let continuationStable: Bool
        public let pv: [String]
        public let warnings: [String]
    }

    public struct Difference: Codable, Equatable, Sendable {
        public let id: String
        public let kind: String
        public let candidateAValue: String
        public let candidateBValue: String
        public let sourceEvidenceIDs: [String]
        public let sourceMoves: [String]
        public let horizon: String
        public let causalStrength: String
        public let safeToVerbalize: Bool
        public let limitations: [String]
    }

    public let comparisonID: String
    public let pairKind: String
    public let position: String
    public let candidateA: Candidate
    public let candidateB: Candidate
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let sharedEvidence: [String]
    public let differences: [Difference]
    public let futureDifferenceCandidates: [String]
    public let dominantDifferenceID: String?
    public let requiresSequenceEvidence: Bool
    public let unsupportedClaims: [String]
    public let warnings: [String]

    public init(_ comparison: CandidateComparison) {
        func candidate(_ value: CandidateAnalysis) -> Candidate {
            Candidate(
                id: value.candidateID,
                rank: value.rank,
                move: value.move,
                score: value.engineScore.text,
                scoreKind: value.scoreKind.rawValue,
                branchType: value.branchType.rawValue,
                comparisonStable: value.comparisonStable,
                continuationStable: value.continuationStable,
                pv: value.pv,
                warnings: value.analysisWarnings
            )
        }
        self.comparisonID = comparison.comparisonID
        self.pairKind = comparison.pairKind.rawValue
        self.position = comparison.candidateA.positionCommand
        self.candidateA = candidate(comparison.candidateA)
        self.candidateB = candidate(comparison.candidateB)
        self.comparisonStable = comparison.comparisonStable
        self.continuationStable = comparison.continuationStable
        self.sharedEvidence = comparison.sharedEvidence.map { "\($0.kind):\($0.value)" }
        self.differences = comparison.differenceEvidence.map {
            Difference(
                id: $0.id,
                kind: $0.kind.rawValue,
                candidateAValue: $0.candidateAValue,
                candidateBValue: $0.candidateBValue,
                sourceEvidenceIDs: $0.sourceEvidenceIDs,
                sourceMoves: $0.sourceMoves,
                horizon: $0.horizon.rawValue,
                causalStrength: $0.causalStrength.rawValue,
                safeToVerbalize: $0.safeToVerbalize,
                limitations: $0.limitations
            )
        }
        self.futureDifferenceCandidates = comparison.futureDifferenceCandidates.map {
            "\($0.horizon.rawValue):\($0.reason.rawValue)"
        }
        self.dominantDifferenceID = comparison.dominantDifferenceCandidate?.id
        self.requiresSequenceEvidence = comparison.requiresSequenceEvidence
        self.unsupportedClaims = comparison.unsupportedClaims
        self.warnings = comparison.comparisonWarnings
    }
}
