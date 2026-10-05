import XCTest
@testable import ShogiCoachCore

final class CandidateComparisonNormalizationTests: XCTestCase {
    private let position = "position startpos moves 7g7f 3c3d"
    private let context = EngineComparisonContext(
        engineContextID: "yaneuraou-production",
        searchConditionID: "pairwise-v1",
        scorePerspective: "side_to_move",
        requestedMoveTimeMs: 800,
        requestedDepth: nil
    )

    private func candidate(
        id: String,
        move: String,
        pv: [String],
        rank: Int
    ) throws -> CandidateAnalysis {
        try CandidateAnalysisResolver.resolve(
            .init(
                candidateID: id,
                rank: rank,
                move: move,
                score: .centipawn(rank == 1 ? 100 : 80, bound: nil),
                pv: pv,
                comparisonStable: true,
                continuationStable: true,
                positionCommand: position,
                engineContext: context,
                branchType: .rankedCandidate
            )
        )
    }

    func testCandidateSpecificPVMismatchInvalidatesStability() throws {
        let a = try candidate(id: "A", move: "8g8f", pv: ["2g2f", "8c8d"], rank: 1)
        let b = try candidate(id: "B", move: "2g2f", pv: ["2g2f", "8c8d"], rank: 2)
        let result = CandidateComparisonResolver.compare(
            comparisonID: "pv-mismatch",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertFalse(a.comparisonStable)
        XCTAssertFalse(a.continuationStable)
        XCTAssertTrue(a.analysisWarnings.contains("pv_first_move_mismatch"))
        XCTAssertFalse(result.comparisonStable)
        XCTAssertNil(result.dominantDifferenceCandidate)
    }

    func testDefaultComparisonDoesNotPretendUnsupportedAxesWereRequested() throws {
        let a = try candidate(id: "A", move: "8g8f", pv: ["8g8f"], rank: 1)
        let b = try candidate(id: "B", move: "2g2f", pv: ["2g2f"], rank: 2)
        let result = CandidateComparisonResolver.compare(
            comparisonID: "default-grounded",
            pairKind: .top1VsTop2,
            candidateA: a,
            candidateB: b
        )

        XCTAssertTrue(result.unsupportedClaims.isEmpty)
    }
}
