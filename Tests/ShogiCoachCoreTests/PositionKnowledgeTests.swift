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

    func testRawPrecedentReinforcesDetectedIntentWithoutInventingOne() throws {
        let causalPosition = "position startpos moves 7g7f 8c8d 2g2f 8d8e"
        let causalKey = try NormalizedPositionKey.make(positionCommand: causalPosition)
        let provider = CompactMoveContextKnowledgeProvider(records: [
            .init(positionKey: causalKey, move: "8h7g", sourceKind: .precedent, sourceID: "fixture:raw:causal", observationCount: 120, intent: .unresolved, detail: "raw precedent")
        ])
        let causal = try MoveContextEngine(knowledgeProvider: provider).analyze(positionCommand: causalPosition, move: "8h7g")
        XCTAssertEqual(causal.selectedIntent, .rookPawnResponse)
        XCTAssertTrue(causal.evidence.contains {
            $0.kind == .precedent && $0.supportedIntent == .rookPawnResponse && $0.detail.contains("raw_knowledge_reinforces=rook_pawn_response")
        })

        let startKey = try NormalizedPositionKey.make(positionCommand: "position startpos")
        let noAnchorProvider = CompactMoveContextKnowledgeProvider(records: [
            .init(positionKey: startKey, move: "7g7f", sourceKind: .precedent, sourceID: "fixture:raw:no-anchor", observationCount: 5000, intent: .unresolved, detail: "raw precedent must not invent intent")
        ])
        let noAnchor = try MoveContextEngine(knowledgeProvider: noAnchorProvider).analyze(positionCommand: "position startpos", move: "7g7f")
        XCTAssertEqual(noAnchor.selectedIntent, .unresolved)
        XCTAssertFalse(noAnchor.evidence.contains { $0.kind == .precedent })
    }

    func testKnowledgeDocumentRoundTripAndSchemaGuard() throws {
        let key = try NormalizedPositionKey.make(positionCommand: "position startpos")
        let record = CompactPositionKnowledgeRecord(positionKey: key, move: "7g7f", sourceKind: .precedent, sourceID: "fixture:source", observationCount: 8, intent: .unresolved, detail: "fixture")
        let document = ContextKnowledgeDocument(
            sources: [.init(sourceID: "fixture:source", title: "Fixture", sourceURL: "https://example.invalid/fixture", rightsNote: "test only", retrievedDate: "2026-10-01")],
            records: [record],
            statistics: .init(parsedGames: 2, skippedGames: 0, aggregatedMoves: 12, emittedRecords: 1, maxPly: 80, minObservations: 2)
        )
        let data = try JSONEncoder().encode(document)
        let provider = try CompactMoveContextKnowledgeProvider(data: data)
        XCTAssertEqual(provider.evidence(positionCommand: "position startpos", move: "7g7f").first?.intent, .unresolved)

        let unsupported = ContextKnowledgeDocument(schemaVersion: 2, sources: document.sources, records: document.records, statistics: document.statistics)
        let unsupportedData = try JSONEncoder().encode(unsupported)
        XCTAssertThrowsError(try CompactMoveContextKnowledgeProvider(data: unsupportedData)) { error in
            XCTAssertEqual(error as? ContextKnowledgeDecodeError, .unsupportedSchema(2))
        }
    }

}
