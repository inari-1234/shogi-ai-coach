import XCTest
@testable import ShogiCoachCore

final class ContextEngineTests: XCTestCase {
    func testRookPawnAdvanceResponseBeatsGeometry() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g"
        )

        XCTAssertEqual(analysis.previousMove, "8d8e")
        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertEqual(analysis.confidence, .high)
        XCTAssertTrue(
            analysis.evidence.contains {
                $0.kind == .previousMoveCausality
                    && $0.supportedIntent == .rookPawnResponse
            }
        )
        XCTAssertNotEqual(analysis.selectedIntent, .attackPreparation)
    }

    func testOpenedBishopLineResponseUsesPreviousMoveCausality() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )

        XCTAssertEqual(analysis.selectedIntent, .bishopLineResponse)
        XCTAssertTrue(
            analysis.facts.contains {
                $0.kind == .newlyAttackedPiece && $0.detail == "8h"
            }
        )
    }

    func testKingEscapeDetectedFromCheckResolution() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 5c5d 2g2f 5d5e 2f2e 5e5f 2e2d 5f5g+ 2d2c+ 5g5h",
            move: "5i5h"
        )

        XCTAssertEqual(analysis.selectedIntent, .kingEscape)
        XCTAssertEqual(analysis.confidence, .high)
        XCTAssertTrue(analysis.facts.contains { $0.kind == .sideInCheck })
    }

    func testDropIsDeploymentIntent() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 8b2b",
            move: "B*5e"
        )

        XCTAssertEqual(analysis.selectedIntent, .handPieceDeployment)
        XCTAssertTrue(analysis.facts.contains { $0.kind == .drop })
    }

    func testGeometryAloneCannotBecomePrimaryIntent() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "6i7h"
        )

        XCTAssertNotEqual(analysis.selectedIntent, .attackPreparation)
    }

    func testStableEngineComparisonAddsPVAndCounterfactualEvidence() throws {
        let engine = MoveContextEngine()
        let analysis = try engine.analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g",
            engineEvidence: .init(
                bestMove: "7g7f",
                actualMove: "8h7g",
                comparisonStable: true,
                continuationStable: true,
                bestPV: ["7g7f", "3c3d"],
                actualPV: ["8h7g", "3c3d"],
                actualLossCp: 18
            )
        )

        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertTrue(analysis.evidence.contains { $0.kind == .enginePV })
        XCTAssertTrue(analysis.evidence.contains { $0.kind == .counterfactual })
    }

    func testConfidenceUsesIndependentEvidenceKindsAndEngineCannotInventIntent() {
        let lowEvidence = [
            ContextEvidence(
                id: "board",
                kind: .boardEffect,
                detail: "fixture",
                supportedIntent: .development,
                weight: 38
            )
        ]
        let low = ContextIntentResolver.resolve(evidence: lowEvidence)
        XCTAssertEqual(low.selectedIntent, .development)
        XCTAssertEqual(low.confidence, .low)

        let reinforced = ContextIntentResolver.resolve(
            evidence: lowEvidence + [
                ContextEvidence(
                    id: "engine",
                    kind: .enginePV,
                    detail: "stable line",
                    supportedIntent: .development,
                    weight: 12
                )
            ]
        )
        XCTAssertEqual(reinforced.selectedIntent, .development)
        XCTAssertEqual(reinforced.confidence, .medium)

        XCTAssertNil(
            ContextIntentResolver.strongestEngineAnchor(
                from: [
                    ContextEvidence(
                        id: "geometry",
                        kind: .geometry,
                        detail: "closer to king",
                        supportedIntent: .attackPreparation,
                        weight: 10
                    )
                ]
            )
        )
    }

}
