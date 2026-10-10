import XCTest
@testable import ShogiCoachCore

final class USICompletedIterationSelectorTests: XCTestCase {
    func testDeeperBoundDoesNotReplaceShallowerCompletedExactIteration() {
        let observations = [
            info(depth: 12, rank: 1, cp: 560, bound: nil, nodes: 42_000, pv: ["3g2e", "8c8d"]),
            info(depth: 13, rank: 1, cp: 605, bound: .lower, nodes: 50_000, pv: ["3g2e", "8c8d"]),
        ]

        let snapshot = USICompletedIterationSelector.deepestExactSnapshot(
            observations: observations,
            requiredMultiPV: 1
        )

        XCTAssertEqual(snapshot?.count, 1)
        XCTAssertEqual(snapshot?.first?.depth, 12)
        XCTAssertEqual(snapshot?.first?.boundKind, .exact)
        XCTAssertEqual(snapshot?.first?.nodes, 42_000)
    }

    func testMultiPVRequiresCoherentExactSnapshotAtSameDepth() {
        let observations = [
            info(depth: 12, rank: 1, cp: 100, bound: nil, nodes: 40_000, pv: ["7g7f"]),
            info(depth: 12, rank: 2, cp: 90, bound: nil, nodes: 41_000, pv: ["2g2f"]),
            info(depth: 13, rank: 1, cp: 110, bound: .lower, nodes: 50_000, pv: ["7g7f"]),
            info(depth: 13, rank: 2, cp: 92, bound: nil, nodes: 50_000, pv: ["2g2f"]),
        ]

        let snapshot = USICompletedIterationSelector.deepestExactSnapshot(
            observations: observations,
            requiredMultiPV: 2
        )

        XCTAssertEqual(snapshot?.map(\.depth), [12, 12])
        XCTAssertEqual(snapshot?.map(\.multipv), [1, 2])
        XCTAssertTrue(snapshot?.allSatisfy(\.hasExactScore) == true)
    }

    func testNoExactObservationIsIncomplete() {
        let observations = [
            info(depth: 12, rank: 1, cp: -58, bound: .upper, nodes: 50_000, pv: ["4i3h"]),
        ]

        XCTAssertNil(
            USICompletedIterationSelector.deepestExactSnapshot(
                observations: observations,
                requiredMultiPV: 1
            )
        )
    }

    func testLatestExactObservationWinsWithinSameDepthAndRank() {
        let observations = [
            info(depth: 10, rank: 1, cp: 10, bound: nil, nodes: 20_000, timeMs: 20, pv: ["7g7f"]),
            info(depth: 10, rank: 1, cp: 20, bound: nil, nodes: 22_000, timeMs: 22, pv: ["2g2f"]),
        ]

        let snapshot = USICompletedIterationSelector.deepestExactSnapshot(
            observations: observations,
            requiredMultiPV: 1
        )

        XCTAssertEqual(snapshot?.first?.nodes, 22_000)
        XCTAssertEqual(snapshot?.first?.pv.first, "2g2f")
    }

    private func info(
        depth: Int,
        rank: Int,
        cp: Int,
        bound: USIScore.Bound?,
        nodes: UInt64,
        timeMs: UInt64 = 0,
        pv: [String]
    ) -> USIInfo {
        USIInfo(
            depth: depth,
            selDepth: depth + 2,
            multipv: rank,
            score: .centipawn(cp, bound: bound),
            nodes: nodes,
            nps: 1_000_000,
            timeMs: timeMs,
            pv: pv
        )
    }
}
