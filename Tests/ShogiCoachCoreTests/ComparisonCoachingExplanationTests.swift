import XCTest
@testable import ShogiCoachCore

final class ComparisonCoachingExplanationTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"

    private var engineContext: EngineComparisonContext {
        EngineComparisonContext(
            engineContextID: "yaneuraou-production",
            searchConditionID: "build19-3b-explanation",
            scorePerspective: "side_to_move",
            requestedMoveTimeMs: 800,
            requestedDepth: nil
        )
    }

    private func candidate(
        id: String,
        rank: Int,
        move: String,
        score: Int,
        pv: [String],
        comparisonStable: Bool = true,
        continuationStable: Bool = true,
        branch: CandidateBranchType = .rankedCandidate
    ) throws -> CandidateAnalysis {
        try CandidateAnalysisResolver.resolve(
            .init(
                candidateID: id,
                rank: rank,
                move: move,
                score: .centipawn(score, bound: nil),
                pv: pv,
                comparisonStable: comparisonStable,
                continuationStable: continuationStable,
                positionCommand: position,
                sourceEvidence: [.init(id: "\(id)-line", kind: "equal_condition_engine_line", sourceMoves: pv)],
                engineContext: engineContext,
                branchType: branch
            )
        )
    }

    private func evidence(
        id: String,
        kind: DifferenceKind,
        horizon: ComparisonHorizon = .immediate,
        causalStrength: CausalStrength = .directConsequence,
        safe: Bool = true,
        aValue: String = "A-value",
        bValue: String = "B-value"
    ) -> DifferenceEvidence {
        DifferenceEvidence(
            id: id,
            kind: kind,
            candidateAValue: aValue,
            candidateBValue: bValue,
            sourceEvidenceIDs: ["A-line", "B-line"],
            sourceMoves: ["8h2b+", "2g2f"],
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

    private func noGrounded(_ a: CandidateAnalysis, _ b: CandidateAnalysis) -> DifferenceEvidence {
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
        pairKind: CandidatePairKind = .top1VsTop2,
        evidence injected: [DifferenceEvidence]? = nil,
        dominant: DifferenceEvidence? = nil,
        requestedAxes: [ComparisonAxis] = [.evaluation, .capture, .material, .promotion, .check, .exchangeConsequence, .opponentReply, .sequenceEvent],
        id: String = "explanation-test"
    ) -> CandidateComparison {
        let base = CandidateComparisonResolver.compare(
            comparisonID: id,
            pairKind: pairKind,
            candidateA: a,
            candidateB: b,
            requestedAxes: requestedAxes
        )
        guard let injected else { return base }
        let selectedDominant = dominant ?? injected.first {
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
            differenceEvidence: injected,
            immediateDifferences: injected.filter { $0.horizon == .immediate },
            futureDifferenceCandidates: base.futureDifferenceCandidates,
            dominantDifferenceCandidate: selectedDominant,
            comparisonStable: base.comparisonStable,
            continuationStable: base.continuationStable,
            requiresSequenceEvidence: injected.contains { $0.horizon != .immediate },
            unsupportedClaims: base.unsupportedClaims,
            comparisonWarnings: base.comparisonWarnings
        )
    }

    func testScoreOnlyComparisonAbstainsInsteadOfInventingReason() throws {
        let a = try candidate(id: "A", rank: 1, move: "8g8f", score: 1000, pv: ["8g8f", "8c8d"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 0, pv: ["2g2f", "8c8d"])
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), noGrounded(a, b)])
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        XCTAssertEqual(confidence.level, .unresolved)
        XCTAssertEqual(explanation.confidence, .unresolved)
        XCTAssertTrue(explanation.usedEvidenceIDs.isEmpty)
        XCTAssertTrue(explanation.primaryReason.contains("評価値や順位だけでは"))
        XCTAssertNil(explanation.alternativeOutcome)
        XCTAssertNil(explanation.opponentOpportunity)
    }

    func testHighDirectClaimProducesGroundedBeginnerExplanationWithoutScoreCause() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: 30, pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 0, pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "capture-direct", kind: .captureDifference, aValue: "bishop", bValue: "none")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        XCTAssertEqual(confidence.level, .high)
        XCTAssertEqual(explanation.confidence, .high)
        XCTAssertTrue(explanation.usedEvidenceIDs.contains("capture-direct"))
        XCTAssertFalse(explanation.usedEvidenceIDs.contains("score"))
        XCTAssertTrue(explanation.primaryReason.contains("具体的な根拠"))
        XCTAssertFalse(explanation.primaryReason.contains("評価値"))
        XCTAssertTrue(explanation.sections.first { $0.kind == .groundedDifference }?.causalWordingUsed == true)
    }

    func testSequenceCorrelatedClaimUsesQualifiedWording() throws {
        let a = try candidate(id: "A", rank: 1, move: "8g8f", score: 80, pv: ["8g8f", "8c8d"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 60, pv: ["2g2f", "8c8d"])
        let correlated = evidence(
            id: "sequence-correlated",
            kind: .sequenceEventDifference,
            causalStrength: .sequenceCorrelated
        )
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), correlated], dominant: correlated)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        XCTAssertEqual(confidence.level, .medium)
        XCTAssertEqual(explanation.tone, .measured)
        XCTAssertTrue(explanation.primaryReason.contains("直接原因とは断定しません"))
        XCTAssertTrue(explanation.sections.first { $0.kind == .groundedDifference }?.causalWordingUsed == false)
    }

    func testUnstableFutureClaimIsWithheldWhileImmediateReasonRemains() throws {
        let a = try candidate(
            id: "A", rank: 1, move: "8h2b+", score: 80,
            pv: ["8h2b+", "3a2b", "2g2f"], continuationStable: false
        )
        let b = try candidate(
            id: "B", rank: 2, move: "2g2f", score: 60,
            pv: ["2g2f", "8c8d", "8g8f"], continuationStable: false
        )
        let immediate = evidence(id: "immediate", kind: .captureDifference, aValue: "bishop", bValue: "none")
        let future = evidence(
            id: "future-reply",
            kind: .opponentReplyDifference,
            horizon: .opponentReply,
            causalStrength: .replyLinked
        )
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), immediate, future], dominant: immediate)
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: pair, maxPlies: 3)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair, sequence: sequence)

        let explanation = ComparisonCoachingExplanationResolver.resolve(
            comparison: pair,
            confidence: confidence,
            sequence: sequence
        )

        XCTAssertEqual(confidence.level, .high)
        XCTAssertTrue(explanation.usedEvidenceIDs.contains("immediate"))
        XCTAssertFalse(explanation.usedEvidenceIDs.contains("future-reply"))
        XCTAssertTrue(explanation.withheldEvidenceIDs.contains("future-reply"))
        XCTAssertNil(explanation.alternativeOutcome)
        XCTAssertNil(explanation.opponentOpportunity)
    }

    func testBestVsActualUsesRecommendedAndActualFraming() throws {
        let best = try candidate(
            id: "best", rank: 1, move: "8g8f", score: 80,
            pv: ["8g8f", "8c8d"], branch: .recommended
        )
        let actual = try candidate(
            id: "actual", rank: 3, move: "2g2f", score: 20,
            pv: ["2g2f", "8c8d"], branch: .actual
        )
        let direct = evidence(id: "check", kind: .checkDifference, aValue: "true", bValue: "false")
        let pair = comparison(
            a: best,
            b: actual,
            pairKind: .bestVsActual,
            evidence: [scoreEvidence(best, actual), direct],
            dominant: direct,
            id: "best-vs-actual"
        )
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        XCTAssertEqual(explanation.preferredMove, "8g8f")
        XCTAssertEqual(explanation.alternativeMove, "2g2f")
        XCTAssertTrue(explanation.headline.contains("推奨手"))
        XCTAssertTrue(explanation.headline.contains("実戦手"))
    }

    func testReplyLinkedAlternativeCanDescribeObservedOpponentConsequenceWithoutCallingItForced() throws {
        let preferred = try candidate(
            id: "A", rank: 1, move: "2g2f", score: 80,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let alternative = try candidate(
            id: "B", rank: 2, move: "8h2b+", score: 60,
            pv: ["8h2b+", "3a2b", "2g2f"]
        )
        let reply = evidence(
            id: "reply",
            kind: .opponentReplyDifference,
            horizon: .opponentReply,
            causalStrength: .replyLinked,
            aValue: "8c8d",
            bValue: "3a2b"
        )
        let pair = comparison(a: preferred, b: alternative, evidence: [scoreEvidence(preferred, alternative), reply], dominant: reply)
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: pair, maxPlies: 3)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair, sequence: sequence)

        let explanation = ComparisonCoachingExplanationResolver.resolve(
            comparison: pair,
            confidence: confidence,
            sequence: sequence
        )

        XCTAssertEqual(confidence.level, .high)
        let opportunity = try XCTUnwrap(explanation.opponentOpportunity)
        XCTAssertTrue(opportunity.contains("PV"))
        XCTAssertTrue(opportunity.contains("強制"))
        XCTAssertFalse(opportunity.contains("必ず"))
    }

    func testExchangeExplanationPreservesEventDifferenceEvenWhenNetMaterialMayEqualize() throws {
        let a = try candidate(
            id: "A", rank: 1, move: "8h2b+", score: 80,
            pv: ["8h2b+", "3a2b", "2g2f"]
        )
        let b = try candidate(
            id: "B", rank: 2, move: "2g2f", score: 60,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let exchange = evidence(
            id: "exchange",
            kind: .exchangeConsequenceDifference,
            horizon: .opponentReply,
            causalStrength: .replyLinked,
            aValue: "immediate_recapture",
            bValue: "no_immediate_recapture_observed"
        )
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), exchange], dominant: exchange)
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: pair, maxPlies: 3)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair, sequence: sequence)

        let explanation = ComparisonCoachingExplanationResolver.resolve(
            comparison: pair,
            confidence: confidence,
            sequence: sequence
        )

        XCTAssertNotNil(sequence.exchangeEventConsequence)
        XCTAssertNotNil(explanation.exchangeAfter)
        XCTAssertTrue(explanation.exchangeAfter?.contains("最終的な駒数が同じでも") == true)
    }

    func testMismatchedConfidenceIDFailsClosed() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: 80, pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 20, pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct", kind: .captureDifference, aValue: "bishop", bValue: "none")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)
        let original = ComparisonConfidenceResolver.resolve(comparison: pair)
        let mismatched = ComparisonConfidenceResult(
            comparisonID: "different-id",
            level: original.level,
            wordingStrength: original.wordingStrength,
            preferenceMagnitude: original.preferenceMagnitude,
            components: original.components,
            claimAssessments: original.claimAssessments,
            eligibleEvidenceIDs: original.eligibleEvidenceIDs,
            withheldEvidenceIDs: original.withheldEvidenceIDs,
            reasons: original.reasons,
            warnings: original.warnings
        )

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: mismatched)

        XCTAssertEqual(explanation.confidence, .unresolved)
        XCTAssertTrue(explanation.usedEvidenceIDs.isEmpty)
        XCTAssertTrue(explanation.warnings.contains("confidence_comparison_id_mismatch"))
    }

    func testUnsupportedAxesStayWithheldFromExplanationAuthority() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: 80, pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 20, pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct", kind: .captureDifference, aValue: "bishop", bValue: "none")
        let pair = comparison(
            a: a,
            b: b,
            evidence: [scoreEvidence(a, b), direct],
            dominant: direct,
            requestedAxes: [.capture, .initiative, .tempo, .practicalComplexity]
        )
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)

        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        XCTAssertTrue(explanation.warnings.contains("unsupported_axis_withheld:initiative"))
        XCTAssertTrue(explanation.warnings.contains("unsupported_axis_withheld:tempo"))
        XCTAssertTrue(explanation.warnings.contains("unsupported_axis_withheld:practicalComplexity"))
        let visible = ([explanation.headline, explanation.primaryReason, explanation.confidenceNote] + explanation.sections.map(\.text)).joined(separator: "|")
        XCTAssertFalse(visible.lowercased().contains("initiative"))
        XCTAssertFalse(visible.lowercased().contains("tempo"))
    }

    func testDiagnosticExportsStructuredExplanation() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: 80, pv: ["8h2b+", "3a2b"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 20, pv: ["2g2f", "8c8d"])
        let direct = evidence(id: "direct", kind: .captureDifference, aValue: "bishop", bValue: "none")
        let pair = comparison(a: a, b: b, evidence: [scoreEvidence(a, b), direct], dominant: direct)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: pair)
        let explanation = ComparisonCoachingExplanationResolver.resolve(comparison: pair, confidence: confidence)

        let data = try JSONEncoder().encode(ComparisonCoachingExplanationDiagnostic(explanation))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["comparisonID"] as? String, "explanation-test")
        XCTAssertEqual(object["confidence"] as? String, "HIGH")
        XCTAssertNotNil(object["sections"])
        XCTAssertNotNil(object["usedEvidenceIDs"])
    }

    func testExplanationLayerPreservesAuthorityIsolation() {
        XCTAssertFalse(ComparisonCoachingExplanationIsolationContract.mutatesMoveIntent)
        XCTAssertFalse(ComparisonCoachingExplanationIsolationContract.mutatesContextConfidence)
        XCTAssertFalse(ComparisonCoachingExplanationIsolationContract.mutatesGroundedExplanation)
        XCTAssertFalse(ComparisonCoachingExplanationIsolationContract.promotesHoldConcepts)
        XCTAssertFalse(ComparisonCoachingExplanationIsolationContract.usesScoreGapAsCausalReason)
    }
}
