import XCTest
@testable import ShogiCoachCore

final class CandidateComparisonTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"

    private func context(movetime: Int = 800, condition: String = "pairwise-v1") -> EngineComparisonContext {
        EngineComparisonContext(
            engineContextID: "yaneuraou-production",
            searchConditionID: condition,
            scorePerspective: "side_to_move",
            requestedMoveTimeMs: movetime,
            requestedDepth: nil
        )
    }

    private func candidate(
        id: String,
        rank: Int,
        move: String,
        score: USIScore,
        pv: [String]? = nil,
        comparisonStable: Bool = true,
        continuationStable: Bool = true,
        branch: CandidateBranchType = .rankedCandidate,
        context: EngineComparisonContext? = nil
    ) throws -> CandidateAnalysis {
        try CandidateAnalysisResolver.resolve(
            .init(
                candidateID: id,
                rank: rank,
                move: move,
                score: score,
                pv: pv ?? [move],
                comparisonStable: comparisonStable,
                continuationStable: continuationStable,
                positionCommand: position,
                sourceEvidence: [
                    .init(id: "\(id)-engine", kind: "equal_condition_engine_line", sourceMoves: [move])
                ],
                engineContext: context ?? self.context(),
                branchType: branch
            )
        )
    }

    func testSharedEvidenceIsNotDifferenceEvidence() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h3c+", score: .centipawn(120, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "8h3c+", score: .centipawn(120, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "shared",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertTrue(result.sharedEvidence.contains { $0.kind == "CHECK_STATE" })
        XCTAssertTrue(result.sharedEvidence.contains { $0.kind == "PROMOTION_EVENT" })
        XCTAssertFalse(result.differenceEvidence.contains { $0.kind == .checkDifference })
        XCTAssertFalse(result.differenceEvidence.contains { $0.kind == .promotionDifference })
    }

    func testCaptureDifferenceGenerated() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(250, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(40, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "capture",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertTrue(result.differenceEvidence.contains { $0.kind == .captureDifference })
        XCTAssertTrue(result.differenceEvidence.contains { $0.kind == .materialDifference })
    }

    func testImmediateRecapturePreventsSimpleMaterialCause() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8h2b+",
            score: .centipawn(180, bound: nil),
            pv: ["8h2b+", "3a2b"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: .centipawn(30, bound: nil),
            pv: ["2g2f", "8c8d"]
        )
        let result = CandidateComparisonResolver.compare(
            comparisonID: "recapture",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        let capture = try XCTUnwrap(result.differenceEvidence.first { $0.kind == .captureDifference })
        let material = try XCTUnwrap(result.differenceEvidence.first { $0.kind == .materialDifference })
        XCTAssertEqual(capture.causalStrength, .unresolved)
        XCTAssertEqual(material.causalStrength, .unresolved)
        XCTAssertTrue(result.differenceEvidence.contains {
            $0.kind == .exchangeConsequenceDifference && $0.horizon == .opponentReply
        })
        XCTAssertTrue(result.futureDifferenceCandidates.contains { $0.reason == .immediateRecaptureDetected })
        XCTAssertNotEqual(result.dominantDifferenceCandidate?.kind, .captureDifference)
        XCTAssertNotEqual(result.dominantDifferenceCandidate?.kind, .materialDifference)
    }

    func testCheckDifferenceDoesNotClaimScoreCause() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h3c+", score: .centipawn(300, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(100, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "check",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        let check = try XCTUnwrap(result.differenceEvidence.first { $0.kind == .checkDifference })
        XCTAssertTrue(check.limitations.contains("check_state_does_not_by_itself_explain_score_delta"))
        let score = try XCTUnwrap(result.differenceEvidence.first { $0.kind == .scoreDifference })
        XCTAssertEqual(score.causalStrength, .unresolved)
    }

    func testMaterialInventoryDifferenceAvailableAtImmediateHorizon() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h2b+", score: .centipawn(250, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(40, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "material",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )
        let material = try XCTUnwrap(result.immediateDifferences.first { $0.kind == .materialDifference })
        XCTAssertNotEqual(material.candidateAValue, material.candidateBValue)
    }

    func testUnstableComparisonSuppressesDominantConclusion() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8h2b+",
            score: .centipawn(250, bound: nil),
            comparisonStable: false
        )
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(40, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "unstable",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertFalse(result.comparisonStable)
        XCTAssertNil(result.dominantDifferenceCandidate)
        XCTAssertTrue(result.comparisonWarnings.contains("comparison_unstable_preference_explanation_suppressed"))
    }

    func testScoreOnlyProducesNoGroundedCausalDifference() throws {
        let a = try candidate(id: "A", rank: 1, move: "7g7f", score: .centipawn(120, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(0, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "score-only",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertTrue(result.differenceEvidence.contains { $0.kind == .scoreDifference })
        XCTAssertTrue(result.differenceEvidence.contains { $0.kind == .noGroundedCausalDifference })
        XCTAssertFalse(result.differenceEvidence.first { $0.kind == .scoreDifference }?.causalStrength == .directConsequence)
    }

    func testComparisonIsolationContractDoesNotMutateIntentState() {
        XCTAssertFalse(ComparisonIsolationContract.mutatesMoveIntent)
        XCTAssertFalse(ComparisonIsolationContract.mutatesContextConfidence)
        XCTAssertFalse(ComparisonIsolationContract.mutatesIntentCandidate)
    }

    func testUnsupportedAxesAreReportedButNeverGrounded() throws {
        let a = try candidate(id: "A", rank: 1, move: "7g7f", score: .centipawn(100, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(90, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "unsupported",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b,
            requestedAxes: [.risk, .practicalComplexity, .moveFlexibility, .humanEase]
        )

        XCTAssertEqual(Set(result.unsupportedClaims), Set(["risk", "practicalComplexity", "moveFlexibility", "humanEase"]))
        XCTAssertFalse(result.differenceEvidence.contains { evidence in
            ["risk", "practicalComplexity", "moveFlexibility", "humanEase"].contains(evidence.kind.rawValue)
        })
    }

    func testDifferentSearchConditionsMakeComparisonUnstable() throws {
        let a = try candidate(id: "A", rank: 1, move: "7g7f", score: .centipawn(100, bound: nil))
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: .centipawn(90, bound: nil),
            context: context(movetime: 1600)
        )
        let result = CandidateComparisonResolver.compare(
            comparisonID: "conditions",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertFalse(result.comparisonStable)
        XCTAssertTrue(result.comparisonWarnings.contains("different_movetime"))
    }

    func testMateStateRemainsCategorical() throws {
        let a = try candidate(id: "A", rank: 1, move: "8h3c+", score: .mate(3, bound: nil))
        let b = try candidate(id: "B", rank: 2, move: "2g2f", score: .centipawn(500, bound: nil))
        let result = CandidateComparisonResolver.compare(
            comparisonID: "mate",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        let mate = try XCTUnwrap(result.differenceEvidence.first { $0.kind == .mateStateDifference })
        XCTAssertTrue(mate.candidateAValue.hasPrefix("mate "))
        XCTAssertTrue(mate.candidateBValue.hasPrefix("cp "))
    }

    func testBestVsActualBranchMetadataAndDiagnosticJSON() throws {
        let a = try candidate(
            id: "best",
            rank: 1,
            move: "8h3c+",
            score: .centipawn(300, bound: nil),
            branch: .recommended
        )
        let b = try candidate(
            id: "actual",
            rank: 3,
            move: "2g2f",
            score: .centipawn(80, bound: nil),
            branch: .actual
        )
        let result = CandidateComparisonResolver.compare(
            comparisonID: "best-actual",
            pairKind: .bestVsActual,
            candidateA: a,
            candidateB: b
        )

        XCTAssertEqual(result.recommendedMove, "8h3c+")
        XCTAssertEqual(result.actualMove, "2g2f")
        let data = try JSONEncoder().encode(CandidateComparisonDiagnostic(result))
        XCTAssertFalse(data.isEmpty)
    }
}
