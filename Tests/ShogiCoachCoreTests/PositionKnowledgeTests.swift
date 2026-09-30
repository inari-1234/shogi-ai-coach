import XCTest
@testable import ShogiCoachCore

final class PositionKnowledgeTests: XCTestCase {
    func testStartposNormalizedKeyMatchesSFENWithoutMoveNumber() throws {
        XCTAssertEqual(
            try NormalizedPositionKey.make(positionCommand: "position startpos"),
            "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b -"
        )
    }

    func testTransposedMoveOrdersShareNormalizedKey() throws {
        let a = try NormalizedPositionKey.make(
            positionCommand: "position startpos moves 7g7f 3c3d 2g2f 8c8d"
        )
        let b = try NormalizedPositionKey.make(
            positionCommand: "position startpos moves 2g2f 8c8d 7g7f 3c3d"
        )
        XCTAssertEqual(a, b)
    }

    func testCompactProviderFindsRecordThroughNormalizedPosition() throws {
        let sourcePosition = "position startpos moves 7g7f 3c3d 2g2f 8c8d"
        let transposedPosition = "position startpos moves 2g2f 8c8d 7g7f 3c3d"
        let key = try NormalizedPositionKey.make(positionCommand: sourcePosition)
        let provider = CompactMoveContextKnowledgeProvider(
            records: [
                .init(
                    positionKey: key,
                    move: "8h7g",
                    sourceKind: .precedent,
                    sourceID: "fixture:precedent:001",
                    observationCount: 120,
                    intent: .bishopLineResponse,
                    detail: "validated fixture"
                )
            ]
        )

        let evidence = provider.evidence(positionCommand: transposedPosition, move: "8h7g")
        XCTAssertEqual(evidence.count, 1)
        XCTAssertEqual(evidence.first?.kind, .precedent)
        XCTAssertEqual(evidence.first?.intent, .bishopLineResponse)
        XCTAssertGreaterThanOrEqual(evidence.first?.weight ?? 0, 60)
    }

    func testProviderRejectsUnsupportedKnowledgeKind() throws {
        let key = try NormalizedPositionKey.make(positionCommand: "position startpos")
        let provider = CompactMoveContextKnowledgeProvider(
            records: [
                .init(
                    positionKey: key,
                    move: "7g7f",
                    sourceKind: .geometry,
                    sourceID: "invalid",
                    observationCount: 999,
                    intent: .attackPreparation,
                    detail: "must not enter knowledge provider"
                )
            ]
        )
        XCTAssertTrue(provider.evidence(positionCommand: "position startpos", move: "7g7f").isEmpty)
    }
}
