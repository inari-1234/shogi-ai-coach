import XCTest
@testable import ShogiCoachCore

final class YaneuraOuLegalMoveSemanticsTests: XCTestCase {
    func testBishopNonPromotionCreatesLegalAllThreeVsLegalTwoBoundary() throws {
        let snapshot = BoardSnapshot(
            squares: [
                BoardCoordinate(file: 4, rank: 4): BoardPieceState(side: .black, kind: .bishop),
                BoardCoordinate(file: 5, rank: 9): BoardPieceState(side: .black, kind: .king),
            ],
            hands: [.black: [:], .white: [:]],
            sideToMove: .black
        )
        let legalAll = ["4d3c+", "4d3c", "5i5h"]

        let searchRoots = try YaneuraOuLegalMoveSemantics.searchRootMoves(
            snapshot: snapshot,
            legalAllMoves: legalAll
        )

        XCTAssertEqual(legalAll.count, 3)
        XCTAssertEqual(searchRoots, ["4d3c+", "5i5h"])
        XCTAssertEqual(searchRoots.count, 2)
    }

    func testPawnNonPromotionIntoPromotionZoneIsOmitted() throws {
        let snapshot = BoardSnapshot(
            squares: [
                BoardCoordinate(file: 5, rank: 4): BoardPieceState(side: .black, kind: .pawn),
            ],
            hands: [.black: [:], .white: [:]],
            sideToMove: .black
        )

        XCTAssertFalse(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "5d5c"))
        XCTAssertTrue(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "5d5c+"))
    }

    func testSecondRankLanceNonPromotionIsOmittedButThirdRankIsKept() throws {
        let snapshot = BoardSnapshot(
            squares: [
                BoardCoordinate(file: 9, rank: 4): BoardPieceState(side: .black, kind: .lance),
            ],
            hands: [.black: [:], .white: [:]],
            sideToMove: .black
        )

        XCTAssertFalse(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "9d9b"))
        XCTAssertTrue(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "9d9c"))
        XCTAssertTrue(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "9d9b+"))
    }

    func testWhitePromotionZoneIsMirrored() throws {
        let snapshot = BoardSnapshot(
            squares: [
                BoardCoordinate(file: 4, rank: 6): BoardPieceState(side: .white, kind: .rook),
            ],
            hands: [.black: [:], .white: [:]],
            sideToMove: .white
        )

        XCTAssertFalse(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "4f4g"))
        XCTAssertTrue(try YaneuraOuLegalMoveSemantics.isSearchRootMove(snapshot: snapshot, usi: "4f4g+"))
    }
}
