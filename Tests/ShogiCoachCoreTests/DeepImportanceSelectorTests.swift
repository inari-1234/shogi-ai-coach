import XCTest
@testable import ShogiCoachCore

final class DeepImportanceSelectorTests: XCTestCase {
    private func candidate(
        ply: Int,
        shallowLoss: Int?,
        actualLoss: Int?,
        stable: Bool,
        bestMove: String = "7g7f",
        actualMove: String = "2g2f",
        reply: String = "3c3d"
    ) -> DeepImportanceCandidate {
        DeepImportanceCandidate(
            ply: ply,
            shallowEstimatedLossCp: shallowLoss,
            actualLossCp: actualLoss,
            bestMove: bestMove,
            actualMove: actualMove,
            bestScoreText: "cp 100",
            actualScoreText: "cp 0",
            opponentBestReply: reply,
            comparisonStable: stable
        )
    }

    func testUnstableLowLossDoesNotOutrankStableHighLoss() {
        let unstable = candidate(
            ply: 11,
            shallowLoss: 20,
            actualLoss: 999,
            stable: false,
            bestMove: "7g7f",
            reply: "3c3d"
        )
        let stable = candidate(
            ply: 30,
            shallowLoss: 30,
            actualLoss: 120,
            stable: true,
            bestMove: "2g2f",
            reply: "8c8d"
        )

        XCTAssertLessThan(
            DeepImportanceSelector.importanceScore(unstable),
            DeepImportanceSelector.importanceScore(stable)
        )
        XCTAssertEqual(
            DeepImportanceSelector.selectIndices([unstable, stable], maxPositions: 1),
            [1]
        )
    }

    func testUnstableRankingUsesShallowLoss() {
        let highShallow = candidate(
            ply: 12,
            shallowLoss: 140,
            actualLoss: 1,
            stable: false,
            bestMove: "7g7f",
            reply: "3c3d"
        )
        let lowShallow = candidate(
            ply: 40,
            shallowLoss: 20,
            actualLoss: 999,
            stable: false,
            bestMove: "2g2f",
            reply: "8c8d"
        )

        XCTAssertEqual(DeepImportanceSelector.lossForImportance(highShallow), 140)
        XCTAssertEqual(DeepImportanceSelector.lossForImportance(lowShallow), 20)
        XCTAssertGreaterThan(
            DeepImportanceSelector.importanceScore(highShallow),
            DeepImportanceSelector.importanceScore(lowShallow)
        )
        XCTAssertEqual(
            DeepImportanceSelector.selectIndices([lowShallow, highShallow], maxPositions: 1),
            [1]
        )
    }

    func testInstabilityAloneDoesNotMakePositionMeaningful() {
        let stableMeaningful = candidate(
            ply: 10,
            shallowLoss: 90,
            actualLoss: 120,
            stable: true,
            bestMove: "7g7f",
            reply: "3c3d"
        )
        let unstableSmallLoss = candidate(
            ply: 40,
            shallowLoss: 20,
            actualLoss: nil,
            stable: false,
            bestMove: "2g2f",
            reply: "8c8d"
        )

        XCTAssertTrue(DeepImportanceSelector.isMeaningful(stableMeaningful))
        XCTAssertFalse(DeepImportanceSelector.isMeaningful(unstableSmallLoss))
        XCTAssertEqual(
            DeepImportanceSelector.selectIndices(
                [stableMeaningful, unstableSmallLoss],
                maxPositions: 2
            ),
            [0]
        )
    }
}
