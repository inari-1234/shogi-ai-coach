import XCTest
@testable import ShogiCoachCore

final class ContextIntentMatrixTests: XCTestCase {
    private func assertIntent(
        _ analysis: MoveContextAnalysis,
        expected: MoveIntent,
        acceptable: Set<MoveIntent> = [],
        forbidden: Set<MoveIntent> = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let allowed = acceptable.union([expected])
        XCTAssertTrue(
            allowed.contains(analysis.selectedIntent),
            "expected \(expected.rawValue), acceptable \(acceptable.map(\.rawValue).sorted()), actual \(analysis.selectedIntent.rawValue)",
            file: file,
            line: line
        )
        XCTAssertFalse(
            forbidden.contains(analysis.selectedIntent),
            "forbidden primary intent \(analysis.selectedIntent.rawValue)",
            file: file,
            line: line
        )
    }

    private func engineEvidence(
        move: String,
        actualMate: Bool = false,
        createsThreatmate: Bool = false,
        opponentThreatmateBefore: Bool = false,
        opponentThreatmateAfter: Bool = false
    ) -> MoveContextEngineEvidence {
        MoveContextEngineEvidence(
            bestMove: move,
            actualMove: move,
            comparisonStable: true,
            continuationStable: true,
            bestPV: [move],
            actualPV: [move],
            actualLossCp: 0,
            actualMate: actualMate,
            createsThreatmate: createsThreatmate,
            opponentThreatmateBefore: opponentThreatmateBefore,
            opponentThreatmateAfter: opponentThreatmateAfter
        )
    }

    func testRookPawnResponseExpectedAndGeometryForbidden() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g"
        )
        assertIntent(
            analysis,
            expected: .rookPawnResponse,
            forbidden: [.attackPreparation]
        )
        XCTAssertEqual(analysis.confidence, .high)
    }

    func testBishopLineResponseExpected() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )
        assertIntent(
            analysis,
            expected: .bishopLineResponse,
            forbidden: [.attackPreparation]
        )
    }

    func testCaptureThreatResponseExpected() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "8f8e"
        )
        assertIntent(
            analysis,
            expected: .captureThreatResponse,
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(analysis.facts.contains { $0.kind == .capture })
    }

    func testImmediateRecaptureIsExchangeContext() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e 8h7g 3c3d 7i8h 2b7g+",
            move: "8h7g"
        )
        assertIntent(
            analysis,
            expected: .postExchangeImprovement,
            acceptable: [.bishopLineResponse],
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(
            analysis.evidence.contains {
                $0.supportedIntent == .postExchangeImprovement
                    && $0.kind == .previousMoveCausality
            }
        )
    }

    func testOpeningKingRelocationIsCastlingContext() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 6g6f 8c8d",
            move: "5i6h"
        )
        assertIntent(
            analysis,
            expected: .castling,
            acceptable: [.kingSafety],
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(analysis.intentCandidates.contains { $0.intent == .castling })
    }

    func testKingEscapeExpectedWhenMovingOutOfCheck() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 5c5d 2g2f 5d5e 2f2e 5e5f 2e2d 5f5g+ 2d2c+ 5g5h",
            move: "5i5h"
        )
        assertIntent(
            analysis,
            expected: .kingEscape,
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(analysis.facts.contains { $0.kind == .sideInCheck })
    }

    func testNonKingMoveThatResolvesCheckIsDefense() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 5c5d 2g2f 5d5e 2f2e 5e5f 2e2d 5f5g+ 2d2c+ 5g5h",
            move: "4i5h"
        )
        assertIntent(
            analysis,
            expected: .defense,
            acceptable: [.captureThreatResponse],
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(
            analysis.evidence.contains {
                $0.supportedIntent == .defense
                    && $0.kind == .previousMoveCausality
            }
        )
    }

    func testCheckIsFactAndAttackContinuationIsIntent() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: "B*3c"
        )
        assertIntent(
            analysis,
            expected: .attackContinuation,
            acceptable: [.handPieceDeployment]
        )
        XCTAssertTrue(analysis.facts.contains { $0.kind == .check })
        XCTAssertTrue(analysis.effects.contains { $0.id == "gives_check" })
    }

    func testForcedMateEvidencePromotesMatingAttackAboveCheck() throws {
        let move = "B*3c"
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: move,
            engineEvidence: engineEvidence(move: move, actualMate: true)
        )
        assertIntent(
            analysis,
            expected: .matingAttack,
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(
            analysis.evidence.contains {
                $0.supportedIntent == .matingAttack && $0.kind == .enginePV
            }
        )
    }

    func testVerifiedThreatmateHasOwnIntent() throws {
        let move = "B*5e"
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: move,
            engineEvidence: engineEvidence(move: move, createsThreatmate: true)
        )
        assertIntent(
            analysis,
            expected: .threatmate,
            forbidden: [.attackPreparation]
        )
    }

    func testVerifiedThreatmateRemovalIsThreatmateDefense() throws {
        let move = "6i7h"
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: move,
            engineEvidence: engineEvidence(
                move: move,
                opponentThreatmateBefore: true,
                opponentThreatmateAfter: false
            )
        )
        assertIntent(
            analysis,
            expected: .threatmateDefense,
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(
            analysis.evidence.contains {
                $0.supportedIntent == .threatmateDefense
                    && $0.kind == .counterfactual
            }
        )
    }

    func testConcreteLocalThreatIgnoredByDistantMoveIsTenuki() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "2g2f"
        )
        assertIntent(
            analysis,
            expected: .tenuki,
            forbidden: [.attackPreparation]
        )
        XCTAssertTrue(
            analysis.facts.contains {
                $0.kind == .newlyAttackedPiece && $0.detail == "8f"
            }
        )
    }

    func testPlainDropRemainsDeploymentWhenNoStrongerIntentExists() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 8b2b",
            move: "B*5e"
        )
        assertIntent(
            analysis,
            expected: .handPieceDeployment,
            acceptable: [.attackPreparation, .exchangePreparation]
        )
        XCTAssertTrue(analysis.facts.contains { $0.kind == .drop })
    }
}
