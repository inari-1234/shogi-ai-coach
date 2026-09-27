import XCTest
@testable import ShogiCoachCore

final class MoveEffectTests: XCTestCase {
    func testNormalMoveEffect() throws {
        let effect = try MoveEffectResolver.resolve(
            positionCommand: "position startpos",
            move: "7g7f"
        )
        XCTAssertEqual(effect.side, .black)
        XCTAssertEqual(effect.source, BoardCoordinate(file: 7, rank: 7))
        XCTAssertEqual(effect.destination, BoardCoordinate(file: 7, rank: 6))
        XCTAssertEqual(effect.pieceBefore, .pawn)
        XCTAssertEqual(effect.pieceAfter, .pawn)
        XCTAssertNil(effect.capturedPiece)
        XCTAssertFalse(effect.isDrop)
        XCTAssertFalse(effect.promotes)
    }

    func testCaptureAndPromotionEffect() throws {
        let position = "position startpos moves 7g7f 3c3d"
        let effect = try MoveEffectResolver.resolve(
            positionCommand: position,
            move: "8h2b+"
        )
        XCTAssertEqual(effect.pieceBefore, .bishop)
        XCTAssertEqual(effect.pieceAfter, .horse)
        XCTAssertEqual(effect.capturedPiece, .bishop)
        XCTAssertTrue(effect.promotes)
    }

    func testDropEffectAndAppend() throws {
        let position = "position startpos moves 7g7f 3c3d 8h2b+ 8b2b"
        let effect = try MoveEffectResolver.resolve(
            positionCommand: position,
            move: "B*5e"
        )
        XCTAssertEqual(effect.side, .black)
        XCTAssertNil(effect.source)
        XCTAssertEqual(effect.destination, BoardCoordinate(file: 5, rank: 5))
        XCTAssertEqual(effect.pieceBefore, .bishop)
        XCTAssertTrue(effect.isDrop)

        let appended = try MoveEffectResolver.appending(move: "B*5e", to: position)
        let snapshot = try BoardSnapshotResolver.resolve(positionCommand: appended)
        XCTAssertEqual(
            snapshot.piece(at: BoardCoordinate(file: 5, rank: 5)),
            BoardPieceState(side: .black, kind: .bishop)
        )
        XCTAssertEqual(snapshot.sideToMove, .white)
    }

    func testOpponentReplyEffectAfterActualMove() throws {
        let afterActual = try MoveEffectResolver.appending(
            move: "7g7f",
            to: "position startpos"
        )
        let reply = try MoveEffectResolver.resolve(
            positionCommand: afterActual,
            move: "3c3d"
        )
        XCTAssertEqual(reply.side, .white)
        XCTAssertEqual(reply.pieceBefore, .pawn)
        XCTAssertNil(reply.capturedPiece)
    }
}
