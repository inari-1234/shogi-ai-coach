import XCTest
@testable import ShogiCoachCore

final class ContextIntentResolutionMatrixTests: XCTestCase {
    func testResolverContractMatrixCoversRemainingBuild16IntentFamilies() {
        struct Fixture {
            let name: String
            let intent: MoveIntent
            let evidence: [ContextEvidence]
            let confidence: ContextConfidence
        }

        let fixtures: [Fixture] = [
            .init(
                name: "piece defense",
                intent: .pieceDefense,
                evidence: [.init(id: "e", kind: .previousMoveCausality, detail: "fixture", supportedIntent: .pieceDefense, weight: 92)],
                confidence: .medium
            ),
            .init(
                name: "exchange preparation",
                intent: .exchangePreparation,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .exchangePreparation, weight: 62)],
                confidence: .medium
            ),
            .init(
                name: "attack preparation",
                intent: .attackPreparation,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .attackPreparation, weight: 75)],
                confidence: .medium
            ),
            .init(
                name: "king safety",
                intent: .kingSafety,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .kingSafety, weight: 70)],
                confidence: .medium
            ),
            .init(
                name: "development",
                intent: .development,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .development, weight: 38)],
                confidence: .low
            ),
            .init(
                name: "piece activation",
                intent: .pieceActivation,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .pieceActivation, weight: 40)],
                confidence: .low
            ),
            .init(
                name: "major piece activation",
                intent: .majorPieceActivation,
                evidence: [.init(id: "e", kind: .boardEffect, detail: "fixture", supportedIntent: .majorPieceActivation, weight: 55)],
                confidence: .low
            ),
            .init(
                name: "unresolved geometry only",
                intent: .unresolved,
                evidence: [.init(id: "g", kind: .geometry, detail: "fixture", supportedIntent: .attackPreparation, weight: 10)],
                confidence: .unresolved
            )
        ]

        for fixture in fixtures {
            let resolution = ContextIntentResolver.resolve(evidence: fixture.evidence)
            XCTAssertEqual(resolution.selectedIntent, fixture.intent, fixture.name)
            XCTAssertEqual(resolution.confidence, fixture.confidence, fixture.name)
        }
    }

    func testGeometryCannotOutrankConcreteLowConfidenceBoardIntent() {
        let resolution = ContextIntentResolver.resolve(
            evidence: [
                .init(id: "geometry", kind: .geometry, detail: "fixture", supportedIntent: .attackPreparation, weight: 10),
                .init(id: "board", kind: .boardEffect, detail: "fixture", supportedIntent: .development, weight: 38)
            ]
        )
        XCTAssertEqual(resolution.selectedIntent, .development)
        XCTAssertEqual(resolution.confidence, .low)
    }
    func testSingleHighAuthorityCandidateAtOrAbove100IsHighWithoutOverflow() {
        let resolution = ContextIntentResolver.resolve(
            evidence: [
                .init(
                    id: "single-high-authority",
                    kind: .previousMoveCausality,
                    detail: "fixture",
                    supportedIntent: .pieceDefense,
                    weight: 110
                )
            ]
        )

        XCTAssertEqual(resolution.candidates.count, 1)
        XCTAssertEqual(resolution.selectedIntent, .pieceDefense)
        XCTAssertEqual(resolution.confidence, .high)
    }

    func testScoreGapBoundaryPreservesFifteenPointThreshold() {
        let gap14 = ContextIntentResolver.resolve(
            evidence: [
                .init(
                    id: "top",
                    kind: .previousMoveCausality,
                    detail: "fixture",
                    supportedIntent: .pieceDefense,
                    weight: 110
                ),
                .init(
                    id: "runner-up",
                    kind: .boardEffect,
                    detail: "fixture",
                    supportedIntent: .attackPreparation,
                    weight: 96
                )
            ]
        )
        XCTAssertEqual(gap14.selectedIntent, .pieceDefense)
        XCTAssertEqual(gap14.confidence, .medium)

        let gap15 = ContextIntentResolver.resolve(
            evidence: [
                .init(
                    id: "top",
                    kind: .previousMoveCausality,
                    detail: "fixture",
                    supportedIntent: .pieceDefense,
                    weight: 110
                ),
                .init(
                    id: "runner-up",
                    kind: .boardEffect,
                    detail: "fixture",
                    supportedIntent: .attackPreparation,
                    weight: 95
                )
            ]
        )
        XCTAssertEqual(gap15.selectedIntent, .pieceDefense)
        XCTAssertEqual(gap15.confidence, .high)
    }

    func testBuild17_6RealGamePly59CompletesWithoutTrap() throws {
        let position = "position startpos moves 2h7h 3c3d 7i6h 2c2d 7g7f 9c9d 1g1f 6c6d 5g5f 8b3b 5i4h 2d2e 4h3h 3a4b 6i5h 6a7b 6g6f 7a6b 6h5g 2b3c 3i2h 3b2b 8h7g 2e2f 2g2f 2b2f P*2g 2f2b 9g9f 4a5b 9f9e 9d9e 9i9e P*9c 7h9h 6b6c 4i4h 5a6b 3g3f 6b7a 6f6e 6d6e 9e9c+ 8a9c 9h9e P*9d 9e9d 7a8b P*6d 6c5d 9d9e P*9d 9e9h 9c8e 7g3c+ 4b3c 8g8f B*8g"

        let analysis = try MoveContextEngine().analyze(
            positionCommand: position,
            move: "9h8h"
        )

        XCTAssertEqual(analysis.move, "9h8h")
        XCTAssertEqual(analysis.previousMove, "B*8g")
        XCTAssertFalse(analysis.intentCandidates.isEmpty)
    }

}
