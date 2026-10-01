import XCTest
@testable import ShogiCoachCore

final class Build17SafeConceptEffectTests: XCTestCase {
    func testPieceMobilityEffectIsSecondaryToBishopLineResponse() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )

        XCTAssertEqual(analysis.selectedIntent, .bishopLineResponse)
        XCTAssertTrue(
            analysis.effects.contains {
                $0.id == "piece_mobility" && $0.detail == "attack_squares:6->13"
            }
        )
    }

    func testEscapeRouteControlEffectDoesNotReplaceAttackContinuation() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: "B*3c"
        )

        XCTAssertEqual(analysis.selectedIntent, .attackContinuation)
        XCTAssertTrue(
            analysis.effects.contains {
                $0.id == "escape_route_control"
                    && $0.detail == "opponent_escape_squares:3->2"
            }
        )
    }

    func testAttackAttackerIsSubordinateMetadata() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "8f8e"
        )

        XCTAssertEqual(analysis.selectedIntent, .captureThreatResponse)
        XCTAssertTrue(
            analysis.effects.contains {
                $0.id == "attack_attacker" && $0.detail == "8e"
            }
        )
    }

    func testTenukiDoesNotGainAttackAttackerMetadata() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "2g2f"
        )

        XCTAssertEqual(analysis.selectedIntent, .tenuki)
        XCTAssertFalse(analysis.effects.contains { $0.id == "attack_attacker" })
    }

    func testLockedRegressionPrimaryIntentRemainsRookPawnResponse() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g"
        )

        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertEqual(analysis.confidence, .high)
    }
}
