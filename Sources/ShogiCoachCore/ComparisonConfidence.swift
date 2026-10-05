import Foundation

public enum ComparisonConfidenceLevel: String, CaseIterable, Equatable, Sendable, Codable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case unresolved = "UNRESOLVED"
}

public enum ComparisonWordingStrength: String, Equatable, Sendable, Codable {
    case directCausal = "DIRECT_CAUSAL"
    case qualifiedCausal = "QUALIFIED_CAUSAL"
    case factualOnly = "FACTUAL_ONLY"
    case rankingOnly = "RANKING_ONLY"
}

public enum DifferenceSpecificity: String, Equatable, Sendable, Codable {
    case none = "NONE"
    case generic = "GENERIC"
    case concrete = "CONCRETE"
}

public enum ConflictingDifferenceState: String, Equatable, Sendable, Codable {
    case none = "NONE"
    case multiplePlausible = "MULTIPLE_PLAUSIBLE"
    case contradictory = "CONTRADICTORY"
}

public struct PreferenceMagnitude: Equatable, Sendable, Codable {
    public let scoreDomain: String
    public let exactCentipawnDelta: Int?
    public let candidateAValue: String
    public let candidateBValue: String

    public init(
        scoreDomain: String,
        exactCentipawnDelta: Int?,
        candidateAValue: String,
        candidateBValue: String
    ) {
        self.scoreDomain = scoreDomain
        self.exactCentipawnDelta = exactCentipawnDelta
        self.candidateAValue = candidateAValue
        self.candidateBValue = candidateBValue
    }
}

public struct ComparisonConfidenceComponents: Equatable, Sendable, Codable {
    public let pairwiseConditionMatch: Bool
    public let rankingStability: Bool
    public let scoreDomainComparability: Bool
    public let firstMoveTraceability: Bool
    public let sequenceStableThroughClaimedHorizon: Bool
    public let differenceSpecificity: DifferenceSpecificity
    public let strongestCausalStrength: String
    public let conflictingDifferenceState: ConflictingDifferenceState
    public let provenanceCompleteness: Bool

    public init(
        pairwiseConditionMatch: Bool,
        rankingStability: Bool,
        scoreDomainComparability: Bool,
        firstMoveTraceability: Bool,
        sequenceStableThroughClaimedHorizon: Bool,
        differenceSpecificity: DifferenceSpecificity,
        strongestCausalStrength: String,
        conflictingDifferenceState: ConflictingDifferenceState,
        provenanceCompleteness: Bool
    ) {
        self.pairwiseConditionMatch = pairwiseConditionMatch
        self.rankingStability = rankingStability
        self.scoreDomainComparability = scoreDomainComparability
        self.firstMoveTraceability = firstMoveTraceability
        self.sequenceStableThroughClaimedHorizon = sequenceStableThroughClaimedHorizon
        self.differenceSpecificity = differenceSpecificity
        self.strongestCausalStrength = strongestCausalStrength
        self.conflictingDifferenceState = conflictingDifferenceState
        self.provenanceCompleteness = provenanceCompleteness
    }
}

public struct ClaimConfidenceAssessment: Equatable, Sendable, Codable {
    public let evidenceID: String
    public let kind: String
    public let horizon: String
    public let causalStrength: String
    public let confidence: ComparisonConfidenceLevel
    public let safeToVerbalize: Bool
    public let eligibleForCausalWording: Bool
    public let limitations: [String]

    public init(
        evidenceID: String,
        kind: String,
        horizon: String,
        causalStrength: String,
        confidence: ComparisonConfidenceLevel,
        safeToVerbalize: Bool,
        eligibleForCausalWording: Bool,
        limitations: [String]
    ) {
        self.evidenceID = evidenceID
        self.kind = kind
        self.horizon = horizon
        self.causalStrength = causalStrength
        self.confidence = confidence
        self.safeToVerbalize = safeToVerbalize
        self.eligibleForCausalWording = eligibleForCausalWording
        self.limitations = limitations
    }
}

public struct ComparisonConfidenceResult: Equatable, Sendable {
    public let comparisonID: String
    public let level: ComparisonConfidenceLevel
    public let wordingStrength: ComparisonWordingStrength
    public let preferenceMagnitude: PreferenceMagnitude
    public let components: ComparisonConfidenceComponents
    public let claimAssessments: [ClaimConfidenceAssessment]
    public let eligibleEvidenceIDs: [String]
    public let withheldEvidenceIDs: [String]
    public let reasons: [String]
    public let warnings: [String]

    public init(
        comparisonID: String,
        level: ComparisonConfidenceLevel,
        wordingStrength: ComparisonWordingStrength,
        preferenceMagnitude: PreferenceMagnitude,
        components: ComparisonConfidenceComponents,
        claimAssessments: [ClaimConfidenceAssessment],
        eligibleEvidenceIDs: [String],
        withheldEvidenceIDs: [String],
        reasons: [String],
        warnings: [String]
    ) {
        self.comparisonID = comparisonID
        self.level = level
        self.wordingStrength = wordingStrength
        self.preferenceMagnitude = preferenceMagnitude
        self.components = components
        self.claimAssessments = claimAssessments
        self.eligibleEvidenceIDs = eligibleEvidenceIDs
        self.withheldEvidenceIDs = withheldEvidenceIDs
        self.reasons = reasons
        self.warnings = warnings
    }
}

public enum ComparisonConfidenceResolver {
    public static func resolve(
        comparison: CandidateComparison,
        sequence: SequenceComparisonEvidence? = nil
    ) -> ComparisonConfidenceResult {
        let conditionMatch = pairwiseConditionMatch(comparison)
        let scoreComparable = scoreDomainComparable(comparison)
        let traceable = firstMoveTraceable(comparison)
        let nonScoreEvidence = comparison.differenceEvidence.filter(isSubstantiveDifference)
        let strongest = strongestCausalStrength(nonScoreEvidence)
        let conflictState = conflictingState(comparison: comparison, evidence: nonScoreEvidence)

        let claims = comparison.differenceEvidence.map {
            assessClaim(
                $0,
                comparison: comparison,
                sequence: sequence,
                conditionMatch: conditionMatch,
                traceable: traceable
            )
        }

        let usableClaims = claims.filter {
            $0.kind != DifferenceKind.scoreDifference.rawValue
                && $0.kind != DifferenceKind.noGroundedCausalDifference.rawValue
                && $0.safeToVerbalize
                && $0.confidence != .unresolved
        }
        let usableIDs = Set(usableClaims.map(\.evidenceID))
        let usableEvidence = nonScoreEvidence.filter { usableIDs.contains($0.id) }
        let provenance = usableEvidence.isEmpty == false && usableEvidence.allSatisfy(evidenceProvenanceComplete)
        let sequenceStableForClaimedHorizon = usableClaims.allSatisfy {
            !$0.limitations.contains("claim_horizon_not_stably_reconstructed")
        }
        let specificity: DifferenceSpecificity = usableClaims.isEmpty ? .none : .concrete

        let components = ComparisonConfidenceComponents(
            pairwiseConditionMatch: conditionMatch,
            rankingStability: comparison.comparisonStable,
            scoreDomainComparability: scoreComparable,
            firstMoveTraceability: traceable,
            sequenceStableThroughClaimedHorizon: sequenceStableForClaimedHorizon,
            differenceSpecificity: specificity,
            strongestCausalStrength: strongest.rawValue,
            conflictingDifferenceState: conflictState,
            provenanceCompleteness: provenance
        )

        let level = overallLevel(components: components, claims: usableClaims)
        let wording = wordingStrength(level: level, claims: usableClaims)

        var reasons: [String] = []
        if !conditionMatch { reasons.append("pairwise_conditions_not_equal") }
        if !comparison.comparisonStable { reasons.append("ranking_unstable") }
        if !scoreComparable { reasons.append("score_domains_not_directly_comparable") }
        if !traceable { reasons.append("first_move_not_fully_traceable") }
        if !provenance { reasons.append("provenance_incomplete_for_usable_claims") }
        if nonScoreEvidence.isEmpty { reasons.append("no_non_score_difference_evidence") }
        if claims.contains(where: { $0.limitations.contains("claim_horizon_not_stably_reconstructed") }) {
            reasons.append("unstable_future_claims_withheld")
        }
        if conflictState != .none { reasons.append("multiple_or_conflicting_difference_state") }
        switch level {
        case .high:
            reasons.append("grounded_direct_or_reply_linked_difference_with_complete_gates")
        case .medium:
            reasons.append("grounded_difference_present_but_causal_attribution_is_incomplete")
        case .low:
            reasons.append("only_limited_grounded_explanation_is_safe")
        case .unresolved:
            reasons.append("causal_explanation_not_safely_resolved")
        }

        let eligibleIDs = usableClaims.map(\.evidenceID).sorted()
        let withheldIDs = claims.filter {
            $0.kind != DifferenceKind.scoreDifference.rawValue
                && (!$0.safeToVerbalize || $0.confidence == .unresolved)
        }.map(\.evidenceID).sorted()

        var warnings = comparison.comparisonWarnings
        warnings.append(contentsOf: sequence?.warnings ?? [])
        if !comparison.unsupportedClaims.isEmpty {
            warnings.append("unsupported_axes_do_not_gain_authority_from_comparison_confidence")
        }
        warnings.append("evaluation_gap_is_not_a_comparison_confidence_booster")
        warnings = Array(Set(warnings)).sorted()

        return ComparisonConfidenceResult(
            comparisonID: comparison.comparisonID,
            level: level,
            wordingStrength: wording,
            preferenceMagnitude: preferenceMagnitude(comparison),
            components: components,
            claimAssessments: claims,
            eligibleEvidenceIDs: eligibleIDs,
            withheldEvidenceIDs: withheldIDs,
            reasons: Array(Set(reasons)).sorted(),
            warnings: warnings
        )
    }

    private static func isSubstantiveDifference(_ evidence: DifferenceEvidence) -> Bool {
        evidence.kind != .scoreDifference && evidence.kind != .noGroundedCausalDifference
    }

    private static func pairwiseConditionMatch(_ comparison: CandidateComparison) -> Bool {
        let a = comparison.candidateA
        let b = comparison.candidateB
        return a.positionCommand == b.positionCommand
            && a.engineContext.engineContextID == b.engineContext.engineContextID
            && a.engineContext.searchConditionID == b.engineContext.searchConditionID
            && a.engineContext.scorePerspective == b.engineContext.scorePerspective
            && a.engineContext.requestedMoveTimeMs == b.engineContext.requestedMoveTimeMs
            && a.engineContext.requestedDepth == b.engineContext.requestedDepth
    }

    private static func scoreDomainComparable(_ comparison: CandidateComparison) -> Bool {
        let a = comparison.candidateA.scoreKind
        let b = comparison.candidateB.scoreKind
        if a == .centipawn || b == .centipawn {
            return a == .centipawn && b == .centipawn
        }
        return true
    }

    private static func firstMoveTraceable(_ comparison: CandidateComparison) -> Bool {
        [comparison.candidateA, comparison.candidateB].allSatisfy { candidate in
            candidate.pv.first == candidate.move
                && candidate.sourceEvidence.contains {
                    !$0.id.isEmpty && $0.sourceMoves.contains(candidate.move)
                }
        }
    }

    private static func evidenceProvenanceComplete(_ evidence: DifferenceEvidence) -> Bool {
        !evidence.sourceEvidenceIDs.isEmpty && !evidence.sourceMoves.isEmpty
    }

    private static func strongestCausalStrength(_ evidence: [DifferenceEvidence]) -> CausalStrength {
        if evidence.contains(where: { $0.causalStrength == .directConsequence }) { return .directConsequence }
        if evidence.contains(where: { $0.causalStrength == .replyLinked }) { return .replyLinked }
        if evidence.contains(where: { $0.causalStrength == .sequenceCorrelated }) { return .sequenceCorrelated }
        return .unresolved
    }

    private static func conflictingState(
        comparison: CandidateComparison,
        evidence: [DifferenceEvidence]
    ) -> ConflictingDifferenceState {
        let warningText = comparison.comparisonWarnings.joined(separator: "|").lowercased()
        if warningText.contains("contradict") { return .contradictory }
        if warningText.contains("evidence_conflict") { return .multiplePlausible }
        let verbalizable = evidence.filter(\.safeToVerbalize)
        if verbalizable.count > 1 && comparison.dominantDifferenceCandidate == nil {
            return .multiplePlausible
        }
        return .none
    }

    private static func assessClaim(
        _ evidence: DifferenceEvidence,
        comparison: CandidateComparison,
        sequence: SequenceComparisonEvidence?,
        conditionMatch: Bool,
        traceable: Bool
    ) -> ClaimConfidenceAssessment {
        var limitations = evidence.limitations

        if evidence.kind == .scoreDifference {
            return ClaimConfidenceAssessment(
                evidenceID: evidence.id,
                kind: evidence.kind.rawValue,
                horizon: evidence.horizon.rawValue,
                causalStrength: evidence.causalStrength.rawValue,
                confidence: comparison.comparisonStable && conditionMatch ? .low : .unresolved,
                safeToVerbalize: comparison.comparisonStable && conditionMatch,
                eligibleForCausalWording: false,
                limitations: Array(Set(limitations + ["score_difference_is_not_causal_evidence"])).sorted()
            )
        }

        if evidence.kind == .noGroundedCausalDifference {
            return ClaimConfidenceAssessment(
                evidenceID: evidence.id,
                kind: evidence.kind.rawValue,
                horizon: evidence.horizon.rawValue,
                causalStrength: evidence.causalStrength.rawValue,
                confidence: .unresolved,
                safeToVerbalize: evidence.safeToVerbalize,
                eligibleForCausalWording: false,
                limitations: Array(Set(limitations + ["no_grounded_causal_reason_resolved"])).sorted()
            )
        }

        guard conditionMatch,
              comparison.comparisonStable,
              traceable,
              evidenceProvenanceComplete(evidence) else {
            limitations.append("comparison_confidence_foundation_gate_failed")
            if !evidenceProvenanceComplete(evidence) {
                limitations.append("claim_provenance_incomplete")
            }
            return ClaimConfidenceAssessment(
                evidenceID: evidence.id,
                kind: evidence.kind.rawValue,
                horizon: evidence.horizon.rawValue,
                causalStrength: evidence.causalStrength.rawValue,
                confidence: .unresolved,
                safeToVerbalize: false,
                eligibleForCausalWording: false,
                limitations: Array(Set(limitations)).sorted()
            )
        }

        let horizonStable: Bool
        if evidence.horizon == .immediate {
            horizonStable = true
        } else if let sequence {
            horizonStable = comparison.continuationStable
                && sequence.stableHorizonPly >= minimumPly(for: evidence.horizon)
        } else {
            horizonStable = false
        }

        guard horizonStable else {
            limitations.append("claim_horizon_not_stably_reconstructed")
            return ClaimConfidenceAssessment(
                evidenceID: evidence.id,
                kind: evidence.kind.rawValue,
                horizon: evidence.horizon.rawValue,
                causalStrength: evidence.causalStrength.rawValue,
                confidence: .unresolved,
                safeToVerbalize: false,
                eligibleForCausalWording: false,
                limitations: Array(Set(limitations)).sorted()
            )
        }

        let level: ComparisonConfidenceLevel
        let causalAllowed: Bool
        switch evidence.causalStrength {
        case .directConsequence:
            level = evidence.safeToVerbalize ? .high : .unresolved
            causalAllowed = evidence.safeToVerbalize
        case .replyLinked:
            level = evidence.safeToVerbalize ? .high : .unresolved
            causalAllowed = evidence.safeToVerbalize
        case .sequenceCorrelated:
            level = evidence.safeToVerbalize ? .medium : .unresolved
            causalAllowed = false
            limitations.append("sequence_correlation_does_not_authorize_direct_causality")
        case .unresolved:
            level = evidence.safeToVerbalize ? .low : .unresolved
            causalAllowed = false
        }

        return ClaimConfidenceAssessment(
            evidenceID: evidence.id,
            kind: evidence.kind.rawValue,
            horizon: evidence.horizon.rawValue,
            causalStrength: evidence.causalStrength.rawValue,
            confidence: level,
            safeToVerbalize: evidence.safeToVerbalize,
            eligibleForCausalWording: causalAllowed,
            limitations: Array(Set(limitations)).sorted()
        )
    }

    private static func minimumPly(for horizon: ComparisonHorizon) -> Int {
        switch horizon {
        case .immediate: return 1
        case .opponentReply: return 2
        case .ownContinuation: return 3
        case .shortHorizon: return 2
        }
    }

    private static func overallLevel(
        components: ComparisonConfidenceComponents,
        claims: [ClaimConfidenceAssessment]
    ) -> ComparisonConfidenceLevel {
        guard components.pairwiseConditionMatch,
              components.rankingStability,
              components.scoreDomainComparability,
              components.firstMoveTraceability,
              components.provenanceCompleteness,
              components.differenceSpecificity != .none else {
            return .unresolved
        }
        if components.conflictingDifferenceState == .contradictory {
            return .unresolved
        }
        guard !claims.isEmpty else { return .unresolved }

        let hasHighCausal = claims.contains {
            $0.confidence == .high && $0.eligibleForCausalWording
        }
        if hasHighCausal,
           components.sequenceStableThroughClaimedHorizon,
           components.conflictingDifferenceState == .none {
            return .high
        }

        if claims.contains(where: { $0.confidence == .high || $0.confidence == .medium }) {
            return .medium
        }
        return .low
    }

    private static func wordingStrength(
        level: ComparisonConfidenceLevel,
        claims: [ClaimConfidenceAssessment]
    ) -> ComparisonWordingStrength {
        switch level {
        case .high:
            return claims.contains(where: { $0.eligibleForCausalWording }) ? .directCausal : .qualifiedCausal
        case .medium:
            return .qualifiedCausal
        case .low:
            return .factualOnly
        case .unresolved:
            return .rankingOnly
        }
    }

    private static func preferenceMagnitude(_ comparison: CandidateComparison) -> PreferenceMagnitude {
        let a = comparison.candidateA.engineScore
        let b = comparison.candidateB.engineScore
        let delta: Int?
        if a.kind == .centipawn, b.kind == .centipawn,
           let aValue = a.centipawn, let bValue = b.centipawn {
            delta = aValue - bValue
        } else {
            delta = nil
        }
        let domain: String
        if a.kind == .centipawn && b.kind == .centipawn {
            domain = "CENTIPAWN"
        } else if a.kind != .centipawn && b.kind != .centipawn {
            domain = "MATE_CATEGORICAL"
        } else {
            domain = "MIXED_SCORE_DOMAIN"
        }
        return PreferenceMagnitude(
            scoreDomain: domain,
            exactCentipawnDelta: delta,
            candidateAValue: a.text,
            candidateBValue: b.text
        )
    }
}

public struct ComparisonConfidenceDiagnostic: Codable, Equatable, Sendable {
    public let comparisonID: String
    public let level: String
    public let wordingStrength: String
    public let preferenceMagnitude: PreferenceMagnitude
    public let components: ComparisonConfidenceComponents
    public let claims: [ClaimConfidenceAssessment]
    public let eligibleEvidenceIDs: [String]
    public let withheldEvidenceIDs: [String]
    public let reasons: [String]
    public let warnings: [String]

    public init(_ result: ComparisonConfidenceResult) {
        self.comparisonID = result.comparisonID
        self.level = result.level.rawValue
        self.wordingStrength = result.wordingStrength.rawValue
        self.preferenceMagnitude = result.preferenceMagnitude
        self.components = result.components
        self.claims = result.claimAssessments
        self.eligibleEvidenceIDs = result.eligibleEvidenceIDs
        self.withheldEvidenceIDs = result.withheldEvidenceIDs
        self.reasons = result.reasons
        self.warnings = result.warnings
    }
}

public enum ComparisonConfidenceIsolationContract {
    public static let mutatesMoveIntent = false
    public static let mutatesContextConfidence = false
    public static let mutatesIntentWeights = false
    public static let promotesHoldConcepts = false
}
