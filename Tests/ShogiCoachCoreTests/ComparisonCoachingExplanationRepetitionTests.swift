import XCTest
@testable import ShogiCoachCore

final class ComparisonCoachingExplanationRepetitionTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"

    private var engineContext: EngineComparisonContext {
        EngineComparisonContext(
            engineContextID: "yaneuraou-production",
            searchConditionID: "build19-3b-repetition",
            scorePerspective: "side_to_move",
            requestedMoveTimeMs: 800,
            requestedDepth: nil
        )
    }

    private func candidate(id: String, rank: Int, move: String, score: Int, pv: [String]) throws -> CandidateAnalysis {
        try CandidateAnalysisResolver.resolve(
            .init(
                candidateID: id,
                rank: rank,
                move: move,
                score: .centipawn(score, bound: nil),
                pv: pv,
                comparisonStable: true,
                continuationStable: true,
                positionCommand: position,
                sourceEvidence: [.init(id: "\(id)-line", kind: "equal_condition_engine_line", sourceMoves: pv)],
                engineContext: engineContext,
                branchType: .rankedCandidate
            )
        )
    }

    private func pair() throws -> (CandidateComparison, ComparisonConfidenceResult, SequenceComparisonEvidence) {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: 80, pv: ["8h2b+", "3a2b", "2g2f"])
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: 20, pv: ["2g2f", "8c8d", "8g8f"])
        let comparison = CandidateComparisonResolver.compare(
            comparisonID: "repetition-test",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b,
            requestedAxes: [.evaluation, .capture, .material, .promotion, .check, .exchangeConsequence, .opponentReply, .sequenceEvent]
        )
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: comparison, maxPlies: 3)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: comparison, sequence: sequence)
        return (comparison, confidence, sequence)
    }

    func testEquivalentExplanationUsesStandardThenContinuityThenSuppression() throws {
        let (comparison, confidence, sequence) = try pair()
        var state = ComparisonCoachingExplanationRepetitionState()

        let first = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        let second = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        let third = state.present(comparison: comparison, confidence: confidence, sequence: sequence)

        XCTAssertEqual(first.mode, .standard)
        XCTAssertNotNil(first.displayedExplanation)
        XCTAssertEqual(first.equivalentRunLength, 1)
        XCTAssertEqual(first.resetReasons, ["INITIAL"])

        XCTAssertEqual(second.mode, .continuity)
        XCTAssertNotNil(second.displayedExplanation)
        XCTAssertEqual(second.equivalentRunLength, 2)
        XCTAssertTrue(second.resetReasons.isEmpty)
        XCTAssertNil(second.displayedExplanation?.alternativeOutcome)
        XCTAssertNil(second.displayedExplanation?.opponentOpportunity)
        XCTAssertTrue(second.displayedExplanation?.warnings.contains("comparison_repetition_continuity_presentation") == true)

        XCTAssertEqual(third.mode, .suppressedDuplicate)
        XCTAssertNil(third.displayedExplanation)
        XCTAssertEqual(third.equivalentRunLength, 3)
    }

    func testSemanticExplanationIsNeverChangedByPresentationState() throws {
        let (comparison, confidence, sequence) = try pair()
        let direct = ComparisonCoachingExplanationResolver.resolve(
            comparison: comparison,
            confidence: confidence,
            sequence: sequence
        )
        var state = ComparisonCoachingExplanationRepetitionState()

        let first = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        let second = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        let third = state.present(comparison: comparison, confidence: confidence, sequence: sequence)

        XCTAssertEqual(first.semanticExplanation, direct)
        XCTAssertEqual(second.semanticExplanation, direct)
        XCTAssertEqual(third.semanticExplanation, direct)
    }

    func testConfidenceChangeResetsRepetition() throws {
        let (comparison, confidence, sequence) = try pair()
        var state = ComparisonCoachingExplanationRepetitionState()
        _ = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        _ = state.present(comparison: comparison, confidence: confidence, sequence: sequence)

        let changed = ComparisonConfidenceResult(
            comparisonID: confidence.comparisonID,
            level: .medium,
            wordingStrength: .qualifiedCausal,
            preferenceMagnitude: confidence.preferenceMagnitude,
            components: confidence.components,
            claimAssessments: confidence.claimAssessments,
            eligibleEvidenceIDs: confidence.eligibleEvidenceIDs,
            withheldEvidenceIDs: confidence.withheldEvidenceIDs,
            reasons: confidence.reasons,
            warnings: confidence.warnings
        )
        let reset = state.present(comparison: comparison, confidence: changed, sequence: sequence)

        XCTAssertEqual(reset.mode, .standard)
        XCTAssertEqual(reset.equivalentRunLength, 1)
        XCTAssertTrue(reset.resetReasons.contains("COMPARISON_CONFIDENCE_CHANGED"))
    }

    func testEvidenceShapeChangeResetsRepetition() throws {
        let (comparison, confidence, sequence) = try pair()
        var state = ComparisonCoachingExplanationRepetitionState()
        _ = state.present(comparison: comparison, confidence: confidence, sequence: sequence)

        let direct = DifferenceEvidence(
            id: "manual-check",
            kind: .checkDifference,
            candidateAValue: "true",
            candidateBValue: "false",
            sourceEvidenceIDs: ["A-line", "B-line"],
            sourceMoves: [comparison.candidateA.move, comparison.candidateB.move],
            horizon: .immediate,
            causalStrength: .directConsequence,
            safeToVerbalize: true,
            limitations: []
        )
        let changedComparison = CandidateComparison(
            comparisonID: comparison.comparisonID,
            pairKind: comparison.pairKind,
            candidateA: comparison.candidateA,
            candidateB: comparison.candidateB,
            actualMove: comparison.actualMove,
            recommendedMove: comparison.recommendedMove,
            alternativeCandidate: comparison.alternativeCandidate,
            sharedEvidence: comparison.sharedEvidence,
            differenceEvidence: [direct],
            immediateDifferences: [direct],
            futureDifferenceCandidates: [],
            dominantDifferenceCandidate: direct,
            comparisonStable: true,
            continuationStable: true,
            requiresSequenceEvidence: false,
            unsupportedClaims: [],
            comparisonWarnings: []
        )
        let changedConfidence = ComparisonConfidenceResolver.resolve(comparison: changedComparison)
        let reset = state.present(comparison: changedComparison, confidence: changedConfidence)

        XCTAssertEqual(reset.mode, .standard)
        XCTAssertEqual(reset.equivalentRunLength, 1)
        XCTAssertTrue(reset.resetReasons.contains("AUTHORIZED_EVIDENCE_CHANGED") || reset.resetReasons.contains("VISIBLE_SECTION_KIND_CHANGED"))
    }

    func testExplicitResetRestoresStandardPresentation() throws {
        let (comparison, confidence, sequence) = try pair()
        var state = ComparisonCoachingExplanationRepetitionState()
        _ = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        _ = state.present(comparison: comparison, confidence: confidence, sequence: sequence)
        state.reset()

        let afterReset = state.present(comparison: comparison, confidence: confidence, sequence: sequence)

        XCTAssertEqual(afterReset.mode, .standard)
        XCTAssertEqual(afterReset.equivalentRunLength, 1)
        XCTAssertEqual(afterReset.resetReasons, ["INITIAL"])
    }

    func testRepetitionLayerPreservesAuthorityIsolation() {
        XCTAssertFalse(ComparisonCoachingExplanationRepetitionIsolationContract.mutatesSemanticExplanation)
        XCTAssertFalse(ComparisonCoachingExplanationRepetitionIsolationContract.mutatesMoveIntent)
        XCTAssertFalse(ComparisonCoachingExplanationRepetitionIsolationContract.mutatesContextConfidence)
        XCTAssertFalse(ComparisonCoachingExplanationRepetitionIsolationContract.promotesHoldConcepts)
    }
}
