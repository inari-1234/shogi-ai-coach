import XCTest
@testable import ShogiCoachCore

final class VE1BPhysicalQualificationMetricsTests: XCTestCase {
    func testJaccardForThreePlySetsUsesSetSemantics() {
        XCTAssertEqual(
            VE1BPhysicalQualificationMetrics.jaccard([41, 49, 69], [41, 49, 77]),
            0.5,
            accuracy: 0.000_001
        )
    }

    func testFiveRunsProduceTenPairwiseJaccards() {
        let runs = [
            [1, 2, 3],
            [1, 2, 4],
            [1, 2, 5],
            [1, 2, 6],
            [1, 2, 7]
        ]
        let pairs = VE1BPhysicalQualificationMetrics.pairwiseJaccards(runs)
        XCTAssertEqual(pairs.count, 10)
        XCTAssertEqual(pairs.map(\.value).min(), 0.5)
    }

    func testModalTop1RequiresDeterministicTieBreak() {
        let modal = VE1BPhysicalQualificationMetrics.modalTop1([
            [49, 1, 2], [49, 3, 4], [69, 5, 6], [69, 7, 8]
        ])
        XCTAssertEqual(modal.ply, 49)
        XCTAssertEqual(modal.count, 2)
        XCTAssertEqual(modal.totalRuns, 4)
    }

    func testMedianUsesConventionalAverageForEvenCount() {
        XCTAssertEqual(VE1BPhysicalQualificationMetrics.median([10, 20, 30, 40]), 25.0)
        XCTAssertEqual(VE1BPhysicalQualificationMetrics.median([10, 20, 30]), 20.0)
    }

    func testNearestRankP95UsesFrozenRule() {
        XCTAssertEqual(VE1BPhysicalQualificationMetrics.nearestRankP95(Array(1...20)), 19)
        XCTAssertEqual(VE1BPhysicalQualificationMetrics.nearestRankP95(Array(1...5)), 5)
    }
}
