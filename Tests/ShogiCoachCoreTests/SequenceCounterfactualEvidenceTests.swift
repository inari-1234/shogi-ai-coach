import XCTest
@testable import ShogiCoachCore

final class SequenceCounterfactualEvidenceTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"

    private var engineContext: EngineComparisonContext {
        EngineComparisonContext(
            engineContextID: "yaneuraou-production",
            searchConditionID: "build19-2-sequence",
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
                sourceEvidence: [
                    .init(id: "\(id)-line", kind: "equal_condition_engine_line", sourceMoves: pv)
                ],
                engineContext: engineContext,
                branchType: branch
            )
        )
    }

    private func comparison(
        a: CandidateAnalysis,
        b: CandidateAnalysis,
        kind: CandidatePairKind = .top1VsTop2,
        id: String = "sequence-test"
    ) -> CandidateComparison {
        CandidateComparisonResolver.compare(
            comparisonID: id,
            pairKind: kind,
            candidateA: a,
            candidateB: b
        )
    }

    func testReconstructsStableSequenceThroughConfiguredHorizon() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d", "2g2f", "2c2d"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d", "8g8f", "2c2d"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 4
        )

        XCTAssertEqual(result.candidateASequence.reconstructedPlyCount, 4)
        XCTAssertEqual(result.candidateBSequence.reconstructedPlyCount, 4)
        XCTAssertEqual(result.stableHorizonPly, 4)
        XCTAssertTrue(result.sequenceStable)
        XCTAssertTrue(result.candidateASequence.plies.allSatisfy(\.withinStableHorizon))
        XCTAssertTrue(result.candidateBSequence.plies.allSatisfy(\.withinStableHorizon))
    }

    func testFirstGroundedDifferenceIgnoresQuietFirstMoveIdentity() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d", "2g2f"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 3
        )

        let first = try XCTUnwrap(result.firstGroundedDifference)
        XCTAssertEqual(first.ply, 3)
        XCTAssertEqual(first.kind, .continuationMove)
        XCTAssertTrue(first.safeToVerbalize)
    }

    func testImmediateRecaptureIsResolvedAtOpponentReply() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8h2b+",
            score: 180,
            pv: ["8h2b+", "3a2b", "2g2f"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 30,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 3
        )

        XCTAssertTrue(result.opponentConsequences.contains {
            $0.candidateID == "A" && $0.kind == .recapture && $0.ply == 2 && $0.safeToVerbalize
        })
        let recapture = try XCTUnwrap(result.futureDifferenceResolutions.first {
            $0.reason == .immediateRecaptureDetected
        })
        XCTAssertEqual(recapture.status, .resolved)
        XCTAssertEqual(recapture.resolvedAtPly, 2)
        XCTAssertEqual(result.exchangeConsequence?.horizonPly, 3)
    }

    func testUnstableContinuationCapsStableHorizonAtFirstMove() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d", "2g2f"],
            continuationStable: false
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d", "8g8f"],
            continuationStable: false
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 3
        )

        XCTAssertEqual(result.stableHorizonPly, 1)
        XCTAssertFalse(result.sequenceStable)
        XCTAssertTrue(result.candidateASequence.plies[0].withinStableHorizon)
        XCTAssertFalse(result.candidateASequence.plies[1].withinStableHorizon)
        XCTAssertTrue(result.sequenceDifferences.filter { $0.ply > 1 }.allSatisfy { !$0.safeToVerbalize })
        XCTAssertTrue(result.futureDifferenceResolutions.contains { $0.status == .unresolvedUnstable })
    }

    func testUnstableComparisonHasZeroStableSequenceHorizon() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d"],
            comparisonStable: false
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 2
        )

        XCTAssertEqual(result.stableHorizonPly, 0)
        XCTAssertFalse(result.sequenceStable)
        XCTAssertTrue(result.sequenceDifferences.allSatisfy { !$0.safeToVerbalize })
    }

    func testObservedOpponentConsequenceDoesNotClaimForcedReply() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8h2b+",
            score: 180,
            pv: ["8h2b+", "3a2b"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 30,
            pv: ["2g2f", "8c8d"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 2
        )

        let capture = try XCTUnwrap(result.opponentConsequences.first {
            $0.candidateID == "A" && $0.kind == .capture
        })
        XCTAssertTrue(capture.safeToVerbalize)
        XCTAssertTrue(capture.limitations.contains("observed_in_engine_pv_not_exhaustive_and_not_proven_forced"))
    }

    func testBestVsActualProducesActualAndCounterfactualTimelines() throws {
        let best = try candidate(
            id: "best",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d"],
            branch: .recommended
        )
        let actual = try candidate(
            id: "actual",
            rank: 3,
            move: "2g2f",
            score: 20,
            pv: ["2g2f", "8c8d"],
            branch: .actual
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: best, b: actual, kind: .bestVsActual, id: "best-actual"),
            maxPlies: 2
        )

        XCTAssertEqual(result.candidateATimeline.realityStatus, .counterfactual)
        XCTAssertEqual(result.candidateBTimeline.realityStatus, .actual)
    }

    func testInvalidLaterPVMoveTruncatesWithDiagnosticInsteadOfCrashing() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d", "8g8f"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 3
        )

        XCTAssertEqual(result.candidateASequence.reconstructedPlyCount, 2)
        XCTAssertFalse(result.candidateASequence.reconstructionComplete)
        XCTAssertTrue(result.candidateASequence.warnings.contains { $0.hasPrefix("sequence_reconstruction_failed_at_ply_3") })
    }

    func testDiagnosticIsStructuredJSON() throws {
        let a = try candidate(
            id: "A",
            rank: 1,
            move: "8g8f",
            score: 80,
            pv: ["8g8f", "8c8d", "2g2f"]
        )
        let b = try candidate(
            id: "B",
            rank: 2,
            move: "2g2f",
            score: 60,
            pv: ["2g2f", "8c8d", "8g8f"]
        )
        let result = SequenceCounterfactualEvidenceResolver.resolve(
            comparison: comparison(a: a, b: b),
            maxPlies: 3
        )
        let data = try JSONEncoder().encode(SequenceComparisonDiagnostic(result))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["comparisonID"] as? String, "sequence-test")
        XCTAssertNotNil(object["candidateA"])
        XCTAssertNotNil(object["differences"])
        XCTAssertNotNil(object["futureResolutions"])
    }

    func testBuild19SequenceLayerPreservesIsolationContract() {
        XCTAssertFalse(ComparisonIsolationContract.mutatesMoveIntent)
        XCTAssertFalse(ComparisonIsolationContract.mutatesContextConfidence)
        XCTAssertFalse(ComparisonIsolationContract.mutatesIntentCandidate)
    }
}
