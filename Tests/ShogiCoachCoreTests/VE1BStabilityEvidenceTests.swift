import Foundation
import Testing
@testable import ShogiCoachCore

private struct VE1BStoredClassificationFixture: Codable {
    let rules: VE1BStabilityRules
    let evidence: [VE1BStabilityEvidenceTier]
    let storedState: VE1BStabilityState
}

private func evidenceTier(
    nodes: Int,
    candidate: String,
    bestScore: Int,
    actualScore: Int,
    bestPV: [String] = ["3g2e", "8b8c"],
    actualPV: [String] = ["4i3h", "8b8c"]
) -> VE1BStabilityEvidenceTier {
    VE1BStabilityEvidenceTier(
        nodeBudget: nodes,
        candidateTopMove: candidate,
        candidateTopBoundKind: "exact",
        bestMove: "3g2e",
        bestScoreKind: "cp",
        bestScoreValue: bestScore,
        bestBoundKind: "exact",
        bestPV: bestPV,
        actualMove: "4i3h",
        actualScoreKind: "cp",
        actualScoreValue: actualScore,
        actualBoundKind: "exact",
        actualPV: actualPV,
        lossCp: bestScore - actualScore,
        comparisonInversion: false
    )
}

@Test func ve1bPersistedEvidenceReclassifiesToSameLabelWithoutEngine() throws {
    let rules = VE1BStabilityRules.ve1bCalibration
    let evidence = [
        evidenceTier(nodes: 50_000, candidate: "3g2e", bestScore: 655, actualScore: -65),
        evidenceTier(nodes: 100_000, candidate: "3g2e", bestScore: 747, actualScore: 5),
        evidenceTier(nodes: 200_000, candidate: "3g2e", bestScore: 731, actualScore: -20)
    ]
    let original = VE1BStabilityReclassifier.assess(evidence: evidence, rules: rules)
    let fixture = VE1BStoredClassificationFixture(
        rules: rules,
        evidence: evidence,
        storedState: original.assessment.state
    )

    let encoded = try JSONEncoder().encode(fixture)
    let decoded = try JSONDecoder().decode(VE1BStoredClassificationFixture.self, from: encoded)
    let recomputed = VE1BStabilityReclassifier.assess(
        evidence: decoded.evidence,
        rules: decoded.rules
    )

    #expect(recomputed.assessment.state == decoded.storedState)
    #expect(recomputed == original)
}

@Test func ve1bLossThresholdIsExplicitRuleNotEngineState() {
    let evidence = [
        evidenceTier(nodes: 50_000, candidate: "P*2e", bestScore: 700, actualScore: 138),
        evidenceTier(nodes: 100_000, candidate: "P*2e", bestScore: 750, actualScore: 118),
        evidenceTier(nodes: 200_000, candidate: "P*2e", bestScore: 700, actualScore: 230)
    ]
    let strict = VE1BStabilityReclassifier.assess(
        evidence: evidence,
        rules: VE1BStabilityRules(lossSwingThresholdCp: 120, authorityStatus: "TEST")
    )
    let relaxed = VE1BStabilityReclassifier.assess(
        evidence: evidence,
        rules: VE1BStabilityRules(lossSwingThresholdCp: 200, authorityStatus: "TEST")
    )

    #expect(strict.comparisonInstabilityReasons.contains("loss_changed"))
    #expect(!relaxed.comparisonInstabilityReasons.contains("loss_changed"))
}

@Test func ve1bCandidateTop1ChangeRemainsIndependentReasonCode() {
    let evidence = [
        evidenceTier(nodes: 50_000, candidate: "4g5f", bestScore: -297, actualScore: -534),
        evidenceTier(nodes: 100_000, candidate: "3g3f", bestScore: -320, actualScore: -507),
        evidenceTier(nodes: 200_000, candidate: "4g5f", bestScore: -405, actualScore: -512)
    ]
    let result = VE1BStabilityReclassifier.assess(
        evidence: evidence,
        rules: .ve1bCalibration
    )

    #expect(result.comparisonInstabilityReasons.contains("candidate_top1_changed"))
    #expect(!result.comparisonInstabilityReasons.contains("multiple_good"))
}
