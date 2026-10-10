import Foundation

public enum VE1BStabilityState: String, Equatable, Sendable {
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

public enum VE1BStabilityEvaluator {
    /// Evaluates stability as convergence under increasing node budgets.
    /// Repeating the same node budget can test reproducibility but can never
    /// provide an additional stability tier.
    ///
    /// VE1-B candidate discovery is also part of the conclusion: when a tier
    /// supplies candidateTopMove, Top-1 identity is included in the semantic
    /// fingerprint. A fixed searchmoves pair therefore cannot appear stable if
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
            // Same-budget duplicates do not add semantic confirmation. Keep the
            // last observation as the representative while separately recording
            // whether the duplicate set was reproducible.
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

        // A deeper attempted tier that is bounded, aborted, inconsistent, or
        // otherwise non-qualifying invalidates an earlier stability claim. The
        // deeper target remains unconfirmed rather than silently falling back to
        // the shallower pair.
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
