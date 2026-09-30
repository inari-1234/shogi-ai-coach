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
}
