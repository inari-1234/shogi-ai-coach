import Testing
@testable import ShogiCoachCore

private func tier(
    _ nodes: Int,
    _ fingerprint: String,
    qualifies: Bool = true,
    bestPV: [String] = ["7g7f", "3c3d", "2g2f"],
    actualPV: [String] = ["2g2f", "8c8d", "7g7f"]
) -> VE1BConfirmationTier {
    VE1BConfirmationTier(
        nodeBudget: nodes,
        conclusionFingerprint: fingerprint,
        qualifiesForStability: qualifies,
        bestPV: bestPV,
        actualPV: actualPV
    )
}

@Test func ve1bSingleTierIsUnconfirmed() {
    let result = VE1BStabilityEvaluator.assess([tier(10_000, "A")])
    #expect(result.state == .unconfirmed)
    #expect(result.distinctQualifyingBudgets == [10_000])
    #expect(result.convergenceBudgets.isEmpty)
}

@Test func ve1bSameBudgetRepeatDoesNotCreateStability() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(10_000, "A")
    ])
    #expect(result.state == .unconfirmed)
    #expect(result.distinctQualifyingBudgets == [10_000])
    #expect(result.reproducibilityConflictObserved == false)
}

@Test func ve1bSameBudgetConflictIsUnstableNotConfirmation() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(10_000, "B")
    ])
    #expect(result.state == .unstable)
    #expect(result.reproducibilityConflictObserved == true)
}

@Test func ve1bTwoIncreasingAgreeingTiersCanBecomeStable() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(20_000, "A")
    ])
    #expect(result.state == .stable)
    #expect(result.convergenceBudgets == [10_000, 20_000])
    #expect(result.earlierConflictObserved == false)
}

@Test func ve1bHigherTwoTiersCanConvergeAfterEarlierDisagreement() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(20_000, "B"),
        tier(40_000, "B")
    ])
    #expect(result.state == .stable)
    #expect(result.convergenceBudgets == [20_000, 40_000])
    #expect(result.earlierConflictObserved == true)
}

@Test func ve1bLaterDeeperContradictionRemovesStable() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(20_000, "A"),
        tier(40_000, "B")
    ])
    #expect(result.state == .unstable)
    #expect(result.convergenceBudgets.isEmpty)
}

@Test func ve1bInvalidTierDoesNotConfirmStability() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(20_000, "A", qualifies: false)
    ])
    #expect(result.state == .unconfirmed)
    #expect(result.distinctQualifyingBudgets == [10_000])
}

@Test func ve1bDeeperInvalidTierRemovesEarlierStableClaim() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A"),
        tier(20_000, "A"),
        tier(40_000, "A", qualifies: false)
    ])
    #expect(result.state == .unconfirmed)
    #expect(result.convergenceBudgets.isEmpty)
}

@Test func ve1bConfirmedPVUsesOnlyStableConvergenceSuffix() {
    let result = VE1BStabilityEvaluator.assess([
        tier(
            10_000,
            "old",
            bestPV: ["2g2f", "8c8d"],
            actualPV: ["7g7f", "3c3d"]
        ),
        tier(
            20_000,
            "new",
            bestPV: ["7g7f", "3c3d", "2g2f", "8c8d"],
            actualPV: ["2g2f", "8c8d", "7g7f"]
        ),
        tier(
            40_000,
            "new",
            bestPV: ["7g7f", "3c3d", "8h2b+"],
            actualPV: ["2g2f", "8c8d", "2f2e"]
        )
    ])
    #expect(result.state == .stable)
    #expect(result.confirmedBestPVPrefix == ["7g7f", "3c3d"])
    #expect(result.confirmedActualPVPrefix == ["2g2f", "8c8d"])
}

@Test func ve1bFirstPlyDisagreementYieldsNoConfirmedPrefix() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A", bestPV: ["7g7f", "3c3d"]),
        tier(20_000, "A", bestPV: ["2g2f", "8c8d"])
    ])
    #expect(result.state == .stable)
    #expect(result.confirmedBestPVPrefix.isEmpty)
}

@Test func ve1bShorterPVTruncatesConfirmedPrefix() {
    let result = VE1BStabilityEvaluator.assess([
        tier(10_000, "A", bestPV: ["7g7f", "3c3d"]),
        tier(20_000, "A", bestPV: ["7g7f", "3c3d", "2g2f"])
    ])
    #expect(result.confirmedBestPVPrefix == ["7g7f", "3c3d"])
}
