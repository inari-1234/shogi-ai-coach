import Foundation

public enum VE1BStabilityState: String, Codable, Equatable, Sendable {
    case unknown
    case unconfirmed
    case stable
    case unstable
}

public struct VE1BConfirmationTier: Equatable, Sendable {
    public let nodeBudget: Int
    public let conclusionFingerprint: String?
    public let qualifiesForStability: Bool
    public let bestPV: [String]
    public let actualPV: [String]
    public let candidateTopMove: String?

    public init(
        nodeBudget: Int,
        conclusionFingerprint: String?,
        qualifiesForStability: Bool,
        bestPV: [String] = [],
        actualPV: [String] = [],
        candidateTopMove: String? = nil
    ) {
        self.nodeBudget = nodeBudget
        self.conclusionFingerprint = conclusionFingerprint
        self.qualifiesForStability = qualifiesForStability
        self.bestPV = bestPV
        self.actualPV = actualPV
        self.candidateTopMove = candidateTopMove
    }
}

public struct VE1BStabilityAssessment: Equatable, Sendable {
    public let state: VE1BStabilityState
    public let distinctQualifyingBudgets: [Int]
    public let convergenceBudgets: [Int]
    public let earlierConflictObserved: Bool
    public let reproducibilityConflictObserved: Bool
    public let confirmedBestPVPrefix: [String]
    public let confirmedActualPVPrefix: [String]

    public init(
        state: VE1BStabilityState,
        distinctQualifyingBudgets: [Int],
        convergenceBudgets: [Int],
        earlierConflictObserved: Bool,
        reproducibilityConflictObserved: Bool,
        confirmedBestPVPrefix: [String],
        confirmedActualPVPrefix: [String]
    ) {
        self.state = state
        self.distinctQualifyingBudgets = distinctQualifyingBudgets
        self.convergenceBudgets = convergenceBudgets
        self.earlierConflictObserved = earlierConflictObserved
        self.reproducibilityConflictObserved = reproducibilityConflictObserved
        self.confirmedBestPVPrefix = confirmedBestPVPrefix
        self.confirmedActualPVPrefix = confirmedActualPVPrefix
    }
}

/// VE1-B classification parameters are evidence metadata, not engine authority.
/// The 120cp value preserves the pre-existing behavior only so the current
/// label can be reproduced. VE1-C owns semantic calibration and may reclassify
/// stored evidence with a different rule set without rerunning the engine.
public struct VE1BStabilityRules: Codable, Equatable, Sendable {
    public let lossSwingThresholdCp: Int
    public let authorityStatus: String

    public init(lossSwingThresholdCp: Int, authorityStatus: String) {
        self.lossSwingThresholdCp = lossSwingThresholdCp
        self.authorityStatus = authorityStatus
    }

    public static let ve1bCalibration = VE1BStabilityRules(
        lossSwingThresholdCp: 120,
        authorityStatus: "UNFROZEN_VE1C_CALIBRATION"
    )
}

/// Raw, engine-independent inputs needed to reproduce a VE1-B stability label.
/// Candidate discovery observations remain separately archived in full; this
/// projection binds the candidate Top-1 for the tier to the two independently
/// measured single-move searches used for comparison.
public struct VE1BStabilityEvidenceTier: Codable, Equatable, Sendable {
    public let nodeBudget: Int
    public let candidateTopMove: String
    public let candidateTopBoundKind: String
    public let bestMove: String
    public let bestScoreKind: String
    public let bestScoreValue: Int?
    public let bestBoundKind: String
    public let bestPV: [String]
    public let actualMove: String
    public let actualScoreKind: String
    public let actualScoreValue: Int?
    public let actualBoundKind: String
    public let actualPV: [String]
    public let lossCp: Int?
    public let comparisonInversion: Bool

    public init(
        nodeBudget: Int,
        candidateTopMove: String,
        candidateTopBoundKind: String,
        bestMove: String,
        bestScoreKind: String,
        bestScoreValue: Int?,
        bestBoundKind: String,
        bestPV: [String],
        actualMove: String,
        actualScoreKind: String,
        actualScoreValue: Int?,
        actualBoundKind: String,
        actualPV: [String],
        lossCp: Int?,
        comparisonInversion: Bool
    ) {
        self.nodeBudget = nodeBudget
        self.candidateTopMove = candidateTopMove
        self.candidateTopBoundKind = candidateTopBoundKind
        self.bestMove = bestMove
        self.bestScoreKind = bestScoreKind
        self.bestScoreValue = bestScoreValue
        self.bestBoundKind = bestBoundKind
        self.bestPV = bestPV
        self.actualMove = actualMove
        self.actualScoreKind = actualScoreKind
        self.actualScoreValue = actualScoreValue
        self.actualBoundKind = actualBoundKind
        self.actualPV = actualPV
        self.lossCp = lossCp
        self.comparisonInversion = comparisonInversion
    }
}

public struct VE1BStabilityTierClassification: Equatable, Sendable {
    public let nodeBudget: Int
    public let unstableReasons: [String]
    public let qualifiesForStability: Bool
    public let conclusionGroup: Int

    public init(
        nodeBudget: Int,
        unstableReasons: [String],
        qualifiesForStability: Bool,
        conclusionGroup: Int
    ) {
        self.nodeBudget = nodeBudget
        self.unstableReasons = unstableReasons
        self.qualifiesForStability = qualifiesForStability
        self.conclusionGroup = conclusionGroup
    }
}

public struct VE1BStabilityReclassification: Equatable, Sendable {
    public let assessment: VE1BStabilityAssessment
    public let tierClassifications: [VE1BStabilityTierClassification]
    public let comparisonInstabilityReasons: [String]

    public init(
        assessment: VE1BStabilityAssessment,
        tierClassifications: [VE1BStabilityTierClassification],
        comparisonInstabilityReasons: [String]
    ) {
        self.assessment = assessment
        self.tierClassifications = tierClassifications
        self.comparisonInstabilityReasons = comparisonInstabilityReasons
    }
}

public enum VE1BStabilityReclassifier {
    /// Recomputes the complete comparison-stability label using only persisted
    /// evidence plus explicit rules. No engine/session state is consulted.
    /// `candidate_top1_changed` is deliberately retained as its own reason. It
    /// does not mean `MULTIPLE_GOOD`; near-tie semantics remain VE1-C authority.
    public static func assess(
        evidence: [VE1BStabilityEvidenceTier],
        rules: VE1BStabilityRules
    ) -> VE1BStabilityReclassification {
        var classifications: [VE1BStabilityTierClassification] = []
        var confirmationTiers: [VE1BConfirmationTier] = []
        var previousQualifyingIndex: Int?
        var conclusionGroup = 0

        for index in evidence.indices {
            let tier = evidence[index]
            var reasons: [String] = []
            if tier.candidateTopBoundKind != "exact" {
                reasons.append("candidate_discovery_bounded_at_target")
            }
            if tier.bestBoundKind != "exact" || tier.actualBoundKind != "exact" {
                reasons.append("bounded_at_target")
            }
            if tier.comparisonInversion {
                reasons.append("comparison_inversion")
            }

            // Eligibility is determined before adding disagreement diagnostics.
            // A valid Top-1 change remains a qualifying observation whose changed
            // candidate identity is also encoded in the semantic fingerprint.
            let qualifies = reasons.isEmpty
            if index > 0,
               evidence[index - 1].candidateTopMove != tier.candidateTopMove {
                reasons.append("candidate_top1_changed")
            }

            if let previousIndex = previousQualifyingIndex {
                let previous = evidence[previousIndex]
                var pairReasons: [String] = []
                if previous.bestScoreKind != tier.bestScoreKind {
                    pairReasons.append("best_score_kind_changed")
                }
                if previous.actualScoreKind != tier.actualScoreKind {
                    pairReasons.append("actual_score_kind_changed")
                }
                if let previousLoss = previous.lossCp,
                   let loss = tier.lossCp,
                   abs(previousLoss - loss) >= rules.lossSwingThresholdCp {
                    pairReasons.append("loss_changed")
                }
                if previous.comparisonInversion != tier.comparisonInversion {
                    pairReasons.append("comparison_inversion_changed")
                }
                reasons.append(contentsOf: pairReasons)

                if qualifies && pairReasons.isEmpty {
                    conclusionGroup = classifications[previousIndex].conclusionGroup
                } else if qualifies {
                    conclusionGroup = classifications[previousIndex].conclusionGroup + 1
                }
            } else if qualifies {
                conclusionGroup = 0
            }

            let normalizedReasons = Array(Set(reasons)).sorted()
            let classification = VE1BStabilityTierClassification(
                nodeBudget: tier.nodeBudget,
                unstableReasons: normalizedReasons,
                qualifiesForStability: qualifies,
                conclusionGroup: conclusionGroup
            )
            classifications.append(classification)

            confirmationTiers.append(
                VE1BConfirmationTier(
                    nodeBudget: tier.nodeBudget,
                    conclusionFingerprint: qualifies ? "group-\(conclusionGroup)" : nil,
                    qualifiesForStability: qualifies,
                    bestPV: tier.bestPV,
                    actualPV: tier.actualPV,
                    candidateTopMove: tier.candidateTopMove
                )
            )
            if qualifies {
                previousQualifyingIndex = index
            }
        }

        let stability = VE1BStabilityEvaluator.assess(confirmationTiers)
        var comparisonReasons = Array(Set(classifications.flatMap(\.unstableReasons)).sorted())
        if stability.state != .stable {
            comparisonReasons.append("convergence_\(stability.state.rawValue)")
        }
        comparisonReasons = Array(Set(comparisonReasons)).sorted()

        return VE1BStabilityReclassification(
            assessment: stability,
            tierClassifications: classifications,
            comparisonInstabilityReasons: comparisonReasons
        )
    }
}

public enum VE1BStabilityEvaluator {
    /// Evaluates stability as convergence under increasing node budgets.
    /// Repeating the same node budget can test reproducibility but can never
    /// provide an additional stability tier.
    ///
    /// VE1-B candidate discovery is also part of the conclusion: when a tier
    /// supplies candidateTopMove, Top-1 identity is included in the semantic
    /// fingerprint. A fixed comparison therefore cannot appear stable if
    /// unrestricted deeper MultiPV discovery changes the leading candidate.
    public static func assess(_ tiers: [VE1BConfirmationTier]) -> VE1BStabilityAssessment {
        let attemptedBudgets = tiers.filter { $0.nodeBudget > 0 }.map(\.nodeBudget)
        let valid = tiers.filter {
            $0.qualifiesForStability
                && $0.nodeBudget > 0
                && semanticFingerprint($0) != nil
        }

        guard !valid.isEmpty else {
            return VE1BStabilityAssessment(
                state: .unknown,
                distinctQualifyingBudgets: [],
                convergenceBudgets: [],
                earlierConflictObserved: false,
                reproducibilityConflictObserved: false,
                confirmedBestPVPrefix: [],
                confirmedActualPVPrefix: []
            )
        }

        let grouped = Dictionary(grouping: valid, by: \.nodeBudget)
        let reproducibilityConflict = grouped.values.contains { sameBudget in
            Set(sameBudget.compactMap(semanticFingerprint)).count > 1
        }

        let budgets = grouped.keys.sorted()
        let representatives: [VE1BConfirmationTier] = budgets.compactMap { budget in
            guard let sameBudget = grouped[budget], !sameBudget.isEmpty else { return nil }
            return sameBudget.last
        }

        if reproducibilityConflict {
            return VE1BStabilityAssessment(
                state: .unstable,
                distinctQualifyingBudgets: budgets,
                convergenceBudgets: [],
                earlierConflictObserved: true,
                reproducibilityConflictObserved: true,
                confirmedBestPVPrefix: [],
                confirmedActualPVPrefix: []
            )
        }

        if let deepestAttempted = attemptedBudgets.max(),
           let deepestQualifying = budgets.max(),
           deepestAttempted > deepestQualifying {
            return VE1BStabilityAssessment(
                state: .unconfirmed,
                distinctQualifyingBudgets: budgets,
                convergenceBudgets: [],
                earlierConflictObserved: false,
                reproducibilityConflictObserved: false,
                confirmedBestPVPrefix: [],
                confirmedActualPVPrefix: []
            )
        }

        guard representatives.count >= 2 else {
            return VE1BStabilityAssessment(
                state: .unconfirmed,
                distinctQualifyingBudgets: budgets,
                convergenceBudgets: [],
                earlierConflictObserved: false,
                reproducibilityConflictObserved: false,
                confirmedBestPVPrefix: [],
                confirmedActualPVPrefix: []
            )
        }

        let highest = representatives[representatives.count - 1]
        let previous = representatives[representatives.count - 2]
        guard semanticFingerprint(highest) == semanticFingerprint(previous) else {
            return VE1BStabilityAssessment(
                state: .unstable,
                distinctQualifyingBudgets: budgets,
                convergenceBudgets: [],
                earlierConflictObserved: true,
                reproducibilityConflictObserved: false,
                confirmedBestPVPrefix: [],
                confirmedActualPVPrefix: []
            )
        }

        let fingerprint = semanticFingerprint(highest)
        var suffix: [VE1BConfirmationTier] = []
        for tier in representatives.reversed() {
            guard semanticFingerprint(tier) == fingerprint else { break }
            suffix.append(tier)
        }
        suffix.reverse()

        let earlier = representatives.dropLast(suffix.count)
        let earlierConflict = earlier.contains { semanticFingerprint($0) != fingerprint }
        let bestPrefix = commonPrefix(suffix.map(\.bestPV))
        let actualPrefix = commonPrefix(suffix.map(\.actualPV))

        return VE1BStabilityAssessment(
            state: .stable,
            distinctQualifyingBudgets: budgets,
            convergenceBudgets: suffix.map(\.nodeBudget),
            earlierConflictObserved: earlierConflict,
            reproducibilityConflictObserved: false,
            confirmedBestPVPrefix: bestPrefix,
            confirmedActualPVPrefix: actualPrefix
        )
    }

    private static func semanticFingerprint(_ tier: VE1BConfirmationTier) -> String? {
        guard let base = tier.conclusionFingerprint else { return nil }
        guard let candidateTopMove = tier.candidateTopMove else { return base }
        return "\(base)|candidateTop=\(candidateTopMove)"
    }

    public static func commonPrefix(_ lines: [[String]]) -> [String] {
        guard let first = lines.first, lines.count >= 2 else { return [] }
        var prefix = first
        for line in lines.dropFirst() {
            var count = 0
            let limit = min(prefix.count, line.count)
            while count < limit, prefix[count] == line[count] {
                count += 1
            }
            prefix = Array(prefix.prefix(count))
            if prefix.isEmpty { break }
        }
        return prefix
    }
}
