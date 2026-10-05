import XCTest
@testable import ShogiCoachCore

final class ComparisonConfidenceTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"

    private func engineContext(searchConditionID: String = "build19-3a-confidence") -> EngineComparisonContext {
        EngineComparisonContext(
            engineContextID: "yaneuraou-production",
            searchConditionID: searchConditionID,
            scorePerspective: "side_to_move",
            requestedMoveTimeMs: 800,
            requestedDepth: nil
        )
    }

    private func candidate(
        id: String,
        rank: Int,
        move: String,
        score: USIScore,
        pv: [String],
        comparisonStable: Bool = true,
        continuationStable: Bool = true,
        searchConditionID: String = "build19-3a-confidence",
        includeSourceEvidence: Bool = true
    ) throws -> CandidateAnalysis {
        try CandidateAnalysisResolver.resolve(
            .init(
                candidateID: id,
                rank: rank,
                move: move,
                score: score,
                pv: pv,
                comparisonStable: comparisonStable,
                continuationStable: continuationStable,
                positionCommand: position,
                sourceEvidence: includeSourceEvidence
                    ? [.init(id: "\(id)-line", kind: "equal_condition_engine_line", sourceMoves: pv)]
                    : [],
                engineContext: engineContext(searchConditionID: searchConditionID),
                branchType: .rankedCandidate
            )
        )
    }

    private func evidence(
        id: String,
        kind: DifferenceKind = .captureDifference,
        horizon: ComparisonHorizon = .immediate,
        causalStrength: CausalStrength = .directConsequence,
        safe: Bool = true,
        provenance: Bool = true
    ) -> DifferenceEvidence {
        DifferenceEvidence(
            id: id,
            kind: kind,
            candidateAValue: "A-value",
            candidateBValue: "B-value",
            sourceEvidenceIDs: provenance ? ["A-line", "B-line"] : [],
            sourceMoves: provenance ? ["8h2b+", "2g2f"] : [],
            horizon: horizon,
            causalStrength: causalStrength,
            safeToVerbalize: safe,
            limitations: []
        )
    }

    private func scoreEvidence(_ a: CandidateAnalysis, _ b: CandidateAnalysis) -> DifferenceEvidence {
        DifferenceEvidence(
            id: "score",
            kind: .scoreDifference,
            candidateAValue: a.engineScore.text,
            candidateBValue: b.engineScore.text,
            sourceEvidenceIDs: ["A-line", "B-line"],
            sourceMoves: [a.move, b.move],
            horizon: .immediate,
            causalStrength: .unresolved,
            safeToVerbalize: true,
            limitations: ["score_gap_alone_is_not_a_causal_explanation"]
        )
    }

    private func noGroundedEvidence(_ a: CandidateAnalysis, _ b: CandidateAnalysis) -> DifferenceEvidence {
        DifferenceEvidence(
            id: "no-grounded",
            kind: .noGroundedCausalDifference,
            candidateAValue: "unresolved",
            candidateBValue: "unresolved",
            sourceEvidenceIDs: ["A-line", "B-line"],
            sourceMoves: [a.move, b.move],
            horizon: .immediate,
            causalStrength: .unresolved,
            safeToVerbalize: true,
            limitations: ["score_gap_alone_is_not_a_causal_explanation"]
        )
    }

    private func comparison(
        a: CandidateAnalysis,
        b: CandidateAnalysis,
        evidence injectedEvidence: [DifferenceEvidence]? = nil,
        dominant: DifferenceEvidence? = nil,
        requestedAxes: [ComparisonAxis] = ComparisonAxis.allCases,
        id: String = "confidence-test"
    ) -> CandidateComparison {
        let base = CandidateComparisonResolver.compare(
            comparisonID: id,
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b,
            requestedAxes: requestedAxes
        )
        guard let injectedEvidence else { return base }
        let selectedDominant = dominant ?? injectedEvidence.first {
            $0.kind != .scoreDifference && $0.kind != .noGroundedCausalDifference
        }
        return CandidateComparison(
            comparisonID: base.comparisonID,
            pairKind: base.pairKind,
            candidateA: base.candidateA,
            candidateB: base.candidateB,
            actualMove: base.actualMove,
            recommendedMove: base.recommendedMove,
            alternativeCandidate: base.alternativeCandidate,
            sharedEvidence: base.sharedEvidence,
            differenceEvidence: injectedEvidence,
            immediateDifferences: injectedEvidence.filter { $0.horizon == .immediate },
            futureDifferenceCandidates: base.futureDifferenceCandidates,
            dominantDifferenceCandidate: selectedDominant,
            comparisonStable: base.comparisonStable,
            continuationStable: base.continuationStable,
            requiresSequenceEvidence: injectedEvidence.contains { $0.horizon != .immediate },
            unsupportedClaims: base.unsupportedClaims,
            comparisonWarnings: base.comparisonWarnings
        )
    }

    func testHugeScoreGapWithoutGroundedDifferenceRemainsUnresolved() throws {
        let a = try candidate(id: "A", rank: 1, move: "8g8f", score: .centipawn(1000, bound: nil), pv: ["8g8f", "8c8d"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(0, bound: nil), pv: ["2g2f", "8c8d"])
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), noGroundedEvidence(a, b)])

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .unresolved)
        XCTAssertEqual(result.wordingStrength, .rankingOnly)
        XCTAssertEqual(result.preferenceMagnitude.exactCentipawnDelta, 1000)
        XCTAssertTrue(result.warnings.contains("evaluation_gap_is_not_a_comparison_confidence_booster"))
        XCTAssertTrue(result.reasons.contains("no_non_score_difference_evidence"))
    }

    func testSmallScoreGapWithDirectGroundedDifferenceCanBeHigh() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(30, bound: nil), pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(0, bound: nil), pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct-capture")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)
        let claim = try XCTUnwrap(result.claimAssessments.first { $0.evidenceID == "direct-capture" })

        XCTAssertEqual(result.level, .high)
        XCTAssertEqual(result.wordingStrength, .directCausal)
        XCTAssertEqual(result.preferenceMagnitude.exactCentipawnDelta, 30)
        XCTAssertEqual(claim.confidence, .high)
        XCTAssertTrue(claim.eligibleForCausalWording)
    }

    func testUnstableContinuationDegradesOnlyFutureClaim() throws {
        let a = try candidate(
            id: "A", rank: 1, move: "8h2b+", score: .centipawn(80, bound: nil),
            pv: ["8h2b+", "3a2b", "2g2f"], continuationStable: false
        )
        let b = try candidate(
            id: "B", rank: 2, move: "2g2f", score: .centipawn(60, bound: nil),
            pv: ["2g2f", "8c8d", "8g8f"], continuationStable: false
        )
        let immediate = evidence(id: "immediate-direct")
        let future = evidence(id: "future-reply", horizon: .opponentReply, causalStrength: .replyLinked)
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), immediate, future], dominant: immediate)
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: pair, maxPlies: 3)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair, sequence: sequence)
        let immediateClaim = try XCTUnwrap(result.claimAssessments.first { $0.evidenceID == "immediate-direct" })
        let futureClaim = try XCTUnwrap(result.claimAssessments.first { $0.evidenceID == "future-reply" })

        XCTAssertEqual(sequence.stableHorizonPly, 1)
        XCTAssertEqual(immediateClaim.confidence, .high)
        XCTAssertTrue(immediateClaim.safeToVerbalize)
        XCTAssertEqual(futureClaim.confidence, .unresolved)
        XCTAssertFalse(futureClaim.safeToVerbalize)
        XCTAssertTrue(futureClaim.limitations.contains("claim_horizon_not_stably_reconstructed"))
        XCTAssertEqual(result.level, .high)
        XCTAssertTrue(result.withheldEvidenceIDs.contains("future-reply"))
        XCTAssertTrue(result.eligibleEvidenceIDs.contains("immediate-direct"))
    }

    func testUnstableComparisonIsUnresolved() throws {
        let a = try candidate(
            id: "A", rank: 1, move: "8h2b+", score: .centipawn(80, bound: nil),
            pv: ["8h2b+", "3a2b"], comparisonStable: false
        )
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(20, bound: nil), pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .unresolved)
        XCTAssertEqual(result.wordingStrength, .rankingOnly)
        XCTAssertFalse(result.components.rankingStability)
    }

    func testUnequalSearchConditionsAreUnresolved() throws {
        let a = try candidate(
            id: "A", rank: 1, move: "8h2b+", score: .centipawn(80, bound: nil),
            pv: ["8h2b+", "3a2b"], searchConditionID: "condition-A"
        )
        let b = try candidate(
            id: "B", rank: 2, move: "2g2f", score: .centipawn(20, bound: nil),
            pv: ["2g2f", "8c8d"], searchConditionID: "condition-B"
        )
        let direct = evidence(id: "direct")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .unresolved)
        XCTAssertFalse(result.components.pairwiseConditionMatch)
        XCTAssertTrue(result.reasons.contains("pairwise_conditions_not_equal"))
    }

    func testMixedCentipawnAndMateDomainsCannotYieldHighConfidence() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .mate(5, bound: nil), pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(0, bound: nil), pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .unresolved)
        XCTAssertFalse(result.components.scoreDomainComparability)
        XCTAssertEqual(result.preferenceMagnitude.scoreDomain, "MIXED_SCORE_DOMAIN")
    }

    func testSequenceCorrelatedClaimIsAtMostMediumAndNotDirectCausal() throws {
        let a = try candidate(id: "A", rank: 1, move: "8g8f", score: .centipawn(80, bound: nil), pv: ["8g8f", "8c8d"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(60, bound: nil), pv: ["2g2f", "8c8d"])
        let correlated = evidence(id: "correlated", kind: .sequenceEventDifference, causalStrength: .sequenceCorrelated)
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), correlated], dominant: correlated)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)
        let claim = try XCTUnwrap(result.claimAssessments.first { $0.evidenceID == "correlated" })

        XCTAssertEqual(claim.confidence, .medium)
        XCTAssertFalse(claim.eligibleForCausalWording)
        XCTAssertEqual(result.level, .medium)
        XCTAssertEqual(result.wordingStrength, .qualifiedCausal)
    }

    func testMissingClaimProvenanceIsUnresolved() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(80, bound: nil), pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(20, bound: nil), pv: ["2g2f", "8c8d"])
        let missing = evidence(id: "missing-provenance", provenance: false)
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), missing], dominant: missing)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)
        let claim = try XCTUnwrap(result.claimAssessments.first { $0.evidenceID == "missing-provenance" })

        XCTAssertEqual(result.level, .unresolved)
        XCTAssertEqual(claim.confidence, .unresolved)
        XCTAssertTrue(claim.limitations.contains("claim_provenance_incomplete"))
        XCTAssertFalse(result.components.provenanceCompleteness)
    }

    func testUnsupportedAxesRemainUnauthorizedEvenWhenGroundedClaimIsHigh() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(80, bound: nil), pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(20, bound: nil), pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct")
        let pair = comparison(
            a: a,
            b: b,
            evidence: [scoreEvidence(a, b), direct],
            dominant: direct,
            requestedAxes: [.capture, .initiative, .tempo, .practicalComplexity]
        )

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .high)
        XCTAssertEqual(Set(pair.unsupportedClaims), Set(["initiative", "tempo", "practicalComplexity"]))
        XCTAssertTrue(result.warnings.contains("unsupported_axes_do_not_gain_authority_from_comparison_confidence"))
        XCTAssertFalse(ComparisonConfidenceIsolationContract.promotesHoldConcepts)
    }

    func testUnresolvedCausalStrengthProducesLowFactualOnlyOutput() throws {
        let a = try candidate(id: "A", rank: 1, move: "8g8f", score: .centipawn(80, bound: nil), pv: ["8g8f", "8c8d"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(60, bound: nil), pv: ["2g2f", "8c8d"])
        let weak = evidence(id: "weak-fact", kind: .boardEffectDifference, causalStrength: .unresolved)
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), weak], dominant: weak)

        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        XCTAssertEqual(result.level, .low)
        XCTAssertEqual(result.wordingStrength, .factualOnly)
    }

    func testDiagnosticExportsStructuredComponentsClaimsAndMagnitude() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(30, bound: nil), pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(0, bound: nil), pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)
        let result = ComparisonConfidenceResolver.resolve(comparison: pair)

        let data = try JSONEncoder().encode(ComparisonConfidenceDiagnostic(result))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["comparisonID"] as? String, "confidence-test")
        XCTAssertEqual(object["level"] as? String, "HIGH")
        XCTAssertNotNil(object["preferenceMagnitude"])
        XCTAssertNotNil(object["components"])
        XCTAssertNotNil(object["claims"])
    }

    func testConfidenceLayerPreservesBuild18AndHoldIsolation() {
        XCTAssertFalse(ComparisonConfidenceIsolationContract.mutatesMoveIntent)
        XCTAssertFalse(ComparisonConfidenceIsolationContract.mutatesContextConfidence)
        XCTAssertFalse(ComparisonConfidenceIsolationContract.mutatesIntentWeights)
        XCTAssertFalse(ComparisonConfidenceIsolationContract.promotesHoldConcepts)
    }
}
