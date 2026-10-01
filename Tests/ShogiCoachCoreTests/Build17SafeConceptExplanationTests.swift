import XCTest
@testable import ShogiCoachCore

final class Build17SafeConceptExplanationTests: XCTestCase {
    func testPieceMobilityAppearsOnlyAsSupplementToPrimaryIntent() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .bishopLineResponse)
        XCTAssertTrue(analysis.effects.contains { $0.id == "piece_mobility" })
        XCTAssertTrue(analysis.effects.contains { $0.id == "attack_attacker" })
        XCTAssertTrue(explanation.conclusion.contains("角筋"))
        XCTAssertEqual(explanation.conceptSupplement?.conceptID, "piece_mobility")
        XCTAssertTrue(explanation.conceptSupplement?.text.contains("6から13") == true)
    }

    func testPieceMobilitySupplementNeverClaimsPurpose() {
        let analysis = fixture(
            intent: .rookPawnResponse,
            confidence: .high,
            effects: [.init(id: "piece_mobility", detail: "attack_squares:3->6")]
        )
        let text = ContextExplanationGenerator.make(analysis: analysis).conceptSupplement?.text ?? ""

        XCTAssertFalse(text.contains("ための手"))
        XCTAssertFalse(text.contains("狙い"))
        XCTAssertFalse(text.contains("目的"))
    }

    func testEscapeRouteControlDoesNotOverwriteAttackContinuation() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: "B*3c"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .attackContinuation)
        XCTAssertTrue(explanation.conclusion.contains("攻めを継続"))
        XCTAssertEqual(explanation.conceptSupplement?.conceptID, "escape_route_control")
        XCTAssertTrue(explanation.conceptSupplement?.text.contains("1つ減っています") == true)
    }

    func testEscapeRouteControlDoesNotInventMatePurpose() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: "B*3c"
        )
        let text = ContextExplanationGenerator.make(analysis: analysis).conceptSupplement?.text ?? ""

        XCTAssertFalse(text.contains("詰ませるため"))
        XCTAssertFalse(text.contains("詰み"))
        XCTAssertFalse(text.contains("目的"))
    }

    func testAttackAttackerPreservesCaptureThreatResponse() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "8f8e"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .captureThreatResponse)
        XCTAssertTrue(explanation.conclusion.contains("駒取りの脅威"))
        XCTAssertEqual(explanation.conceptSupplement?.conceptID, "attack_attacker")
        XCTAssertTrue(explanation.conceptSupplement?.text.contains("相手駒そのもの") == true)
    }

    func testTenukiDoesNotShowAttackAttackerSupplement() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 8g8f 8c8d 7g7f 8d8e",
            move: "2g2f"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .tenuki)
        XCTAssertNil(explanation.conceptSupplement)
    }

    func testLockedRegressionKeepsRookPawnResponseAsPrimaryExplanation() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertEqual(analysis.confidence, .high)
        XCTAssertTrue(explanation.conclusion.contains("飛車先"))
        XCTAssertFalse(explanation.conclusion.contains("可動"))
        XCTAssertFalse(explanation.conclusion.contains("働きを広げる"))
    }

    func testNoConceptProducesNoSupplement() {
        let analysis = fixture(
            intent: .rookPawnResponse,
            confidence: .high,
            effects: []
        )
        XCTAssertNil(ContextExplanationGenerator.make(analysis: analysis).conceptSupplement)
    }

    func testMultipleConceptsAreCappedAtOneSupplement() {
        let analysis = fixture(
            intent: .captureThreatResponse,
            confidence: .high,
            effects: [
                .init(id: "piece_mobility", detail: "attack_squares:3->7"),
                .init(id: "escape_route_control", detail: "opponent_escape_squares:3->2"),
                .init(id: "attack_attacker", detail: "8e")
            ]
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(explanation.conceptSupplement?.conceptID, "attack_attacker")
        XCTAssertFalse(explanation.conceptSupplement?.text.contains("逃げ場所") == true)
        XCTAssertFalse(explanation.conceptSupplement?.text.contains("利かせられる") == true)
    }

    func testSuppressionHidesImmediateRepeatedConcept() {
        let analysis = fixture(
            intent: .rookPawnResponse,
            confidence: .high,
            effects: [.init(id: "piece_mobility", detail: "attack_squares:3->6")]
        )

        XCTAssertNotNil(ContextExplanationGenerator.make(analysis: analysis).conceptSupplement)
        XCTAssertNil(
            ContextExplanationGenerator.make(
                analysis: analysis,
                suppressingConceptIDs: ["piece_mobility"]
            ).conceptSupplement
        )
    }

    func testConceptSupplementDoesNotChangeConfidence() {
        let analysis = fixture(
            intent: .attackContinuation,
            confidence: .medium,
            effects: [.init(id: "escape_route_control", detail: "opponent_escape_squares:4->2")]
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(explanation.confidence, .medium)
        XCTAssertEqual(analysis.selectedIntent, .attackContinuation)
        XCTAssertEqual(explanation.conceptSupplement?.conceptID, "escape_route_control")
    }

    func testLowConfidenceDoesNotEmitConceptSupplement() {
        let analysis = fixture(
            intent: .rookPawnResponse,
            confidence: .low,
            effects: [.init(id: "piece_mobility", detail: "attack_squares:3->6")]
        )
        XCTAssertNil(ContextExplanationGenerator.make(analysis: analysis).conceptSupplement)
    }

    func testPieceActivationDoesNotRepeatMobilityAsRedundantSupplement() {
        let analysis = fixture(
            intent: .pieceActivation,
            confidence: .high,
            effects: [.init(id: "piece_mobility", detail: "attack_squares:2->7")]
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertTrue(explanation.conclusion.contains("駒の働き"))
        XCTAssertNil(explanation.conceptSupplement)
    }

    func testEscapeRouteControlIsSuppressedForUnrelatedPrimaryIntent() {
        let analysis = fixture(
            intent: .development,
            confidence: .high,
            effects: [.init(id: "escape_route_control", detail: "opponent_escape_squares:3->2")]
        )
        XCTAssertNil(ContextExplanationGenerator.make(analysis: analysis).conceptSupplement)
    }

    private func fixture(
        intent: MoveIntent,
        confidence: ContextConfidence,
        effects: [ContextSignal]
    ) -> MoveContextAnalysis {
        MoveContextAnalysis(
            move: "7g7f",
            previousMove: "3c3d",
            facts: [],
            contextChanges: [],
            effects: effects,
            outcomes: [],
            intentCandidates: [.init(intent: intent, score: 120, evidenceIDs: ["fixture"])],
            selectedIntent: intent,
            confidence: confidence,
            evidence: [
                .init(
                    id: "fixture",
                    kind: .previousMoveCausality,
                    detail: "fixture",
                    supportedIntent: intent,
                    weight: 120
                )
            ]
        )
    }
}
