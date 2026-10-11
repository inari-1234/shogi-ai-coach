import XCTest
@testable import ShogiCoachCore

final class USIProvenMateTerminationTests: XCTestCase {
    func testExactCoherentMultiPVMateQualifies() {
        let lines = [
            info(rank: 1, score: .mate(3, bound: nil), pv: ["S*1b", "1a1b"]),
            info(rank: 2, score: .mate(5, bound: nil), pv: ["G*1b", "1a1b"]),
            info(rank: 3, score: .mate(7, bound: nil), pv: ["R*1b", "1a1b"]),
        ]
        let terminal = result(bestMove: "S*1b", lines: lines, consistency: .consistent)
        let measurement = result(bestMove: "S*1b", lines: lines, consistency: .consistent)

        XCTAssertTrue(
            USIProvenMateTermination.qualifies(
                measurementResult: measurement,
                terminalResult: terminal,
                requiredMultiPV: 3
            )
        )
    }

    func testExactCentipawnEarlyReturnDoesNotQualify() {
        let lines = [
            info(rank: 1, score: .centipawn(900, bound: nil), pv: ["S*1b"]),
        ]
        let terminal = result(bestMove: "S*1b", lines: lines, consistency: .consistent)

        XCTAssertFalse(
            USIProvenMateTermination.qualifies(
                measurementResult: terminal,
                terminalResult: terminal,
                requiredMultiPV: 1
            )
        )
    }

    func testBoundedMateDoesNotQualify() {
        let lines = [
            info(rank: 1, score: .mate(3, bound: .lower), pv: ["S*1b"]),
        ]
        let terminal = result(bestMove: "S*1b", lines: lines, consistency: .consistent)

        XCTAssertFalse(
            USIProvenMateTermination.qualifies(
                measurementResult: terminal,
                terminalResult: terminal,
                requiredMultiPV: 1
            )
        )
    }

    func testMissingRequestedMultiPVRankDoesNotQualify() {
        let lines = [
            info(rank: 1, score: .mate(3, bound: nil), pv: ["S*1b"]),
            info(rank: 2, score: .mate(5, bound: nil), pv: ["G*1b"]),
        ]
        let terminal = result(bestMove: "S*1b", lines: lines, consistency: .consistent)

        XCTAssertFalse(
            USIProvenMateTermination.qualifies(
                measurementResult: terminal,
                terminalResult: terminal,
                requiredMultiPV: 3
            )
        )
    }

    func testEmptyPVDoesNotQualify() {
        let lines = [
            info(rank: 1, score: .mate(3, bound: nil), pv: []),
        ]
        let terminal = result(bestMove: "S*1b", lines: lines, consistency: .consistent)

        XCTAssertFalse(
            USIProvenMateTermination.qualifies(
                measurementResult: terminal,
                terminalResult: terminal,
                requiredMultiPV: 1
            )
        )
    }

    func testInconsistentTerminalBestMoveDoesNotQualify() {
        let lines = [
            info(rank: 1, score: .mate(3, bound: nil), pv: ["S*1b"]),
        ]
        let terminal = result(bestMove: "G*1b", lines: lines, consistency: .inconsistent)
        let measurement = result(bestMove: "G*1b", lines: lines, consistency: .inconsistent)

        XCTAssertFalse(
            USIProvenMateTermination.qualifies(
                measurementResult: measurement,
                terminalResult: terminal,
                requiredMultiPV: 1
            )
        )
    }

    func testExactNegativeMateCanQualifyAsCompletionOnly() {
        let lines = [
            info(rank: 1, score: .mate(-5, bound: nil), pv: ["4i3h"]),
        ]
        let terminal = result(bestMove: "4i3h", lines: lines, consistency: .consistent)

        XCTAssertTrue(
            USIProvenMateTermination.qualifies(
                measurementResult: terminal,
                terminalResult: terminal,
                requiredMultiPV: 1
            )
        )
    }

    private func info(rank: Int, score: USIScore, pv: [String]) -> USIInfo {
        USIInfo(
            depth: 42,
            selDepth: 44,
            multipv: rank,
            score: score,
            nodes: 80_000,
            nps: 1_000_000,
            timeMs: 80,
            pv: pv
        )
    }

    private func result(
        bestMove: String,
        lines: [USIInfo],
        consistency: USIBestMoveConsistency
    ) -> EngineProbeResult {
        EngineProbeResult(
            bestMove: .init(move: bestMove, ponder: nil),
            principalVariations: lines,
            observations: lines,
            bestMoveConsistency: consistency
        )
    }
}
