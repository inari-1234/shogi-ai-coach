import XCTest
@testable import ShogiCoachCore

final class BoardSnapshotTests: XCTestCase {
    func testStartposSnapshot() throws {
        let snapshot = try BoardSnapshotResolver.resolve(positionCommand: "position startpos")
        XCTAssertEqual(snapshot.pieceCount, 40)
        XCTAssertEqual(snapshot.sideToMove, .black)
        XCTAssertEqual(
            snapshot.piece(at: BoardCoordinate(file: 7, rank: 7)),
            BoardPieceState(side: .black, kind: .pawn)
        )
        XCTAssertEqual(
            snapshot.piece(at: BoardCoordinate(file: 5, rank: 1)),
            BoardPieceState(side: .white, kind: .king)
        )
    }

    func testReplaysNormalMovesAndSideToMove() throws {
        let snapshot = try BoardSnapshotResolver.resolve(
            positionCommand: "position startpos moves 7g7f 3c3d"
        )
        XCTAssertNil(snapshot.piece(at: BoardCoordinate(file: 7, rank: 7)))
        XCTAssertEqual(
            snapshot.piece(at: BoardCoordinate(file: 7, rank: 6)),
            BoardPieceState(side: .black, kind: .pawn)
        )
        XCTAssertEqual(
            snapshot.piece(at: BoardCoordinate(file: 3, rank: 4)),
            BoardPieceState(side: .white, kind: .pawn)
        )
        XCTAssertEqual(snapshot.sideToMove, .black)
    }

    func testCapturePromotionAndDropHands() throws {
        let beforeDrop = try BoardSnapshotResolver.resolve(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 8b2b"
        )
        XCTAssertEqual(beforeDrop.handCount(side: .black, kind: .bishop), 1)
        XCTAssertEqual(beforeDrop.handCount(side: .white, kind: .bishop), 1)
        XCTAssertEqual(beforeDrop.sideToMove, .black)

        let afterDrop = try BoardSnapshotResolver.resolve(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 8b2b B*5e"
        )
        XCTAssertEqual(afterDrop.handCount(side: .black, kind: .bishop), 0)
        XCTAssertEqual(
            afterDrop.piece(at: BoardCoordinate(file: 5, rank: 5)),
            BoardPieceState(side: .black, kind: .bishop)
        )
        XCTAssertEqual(afterDrop.sideToMove, .white)
    }

    func testUSIMoveVisualNormalPromotionAndDrop() throws {
        XCTAssertEqual(
            try USIMoveVisual.parse("1d2c+"),
            USIMoveVisual(
                source: BoardCoordinate(file: 1, rank: 4),
                destination: BoardCoordinate(file: 2, rank: 3),
                dropPiece: nil,
                promotes: true
            )
        )

        XCTAssertEqual(
            try USIMoveVisual.parse("G*1b"),
            USIMoveVisual(
                source: nil,
                destination: BoardCoordinate(file: 1, rank: 2),
                dropPiece: .gold,
                promotes: false
            )
        )
    }
}
