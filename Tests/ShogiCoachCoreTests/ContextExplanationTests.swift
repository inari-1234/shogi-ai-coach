import XCTest
@testable import ShogiCoachCore

final class ContextExplanationTests: XCTestCase {
    func testRookPawnResponseProducesCausalExplanationWithoutGeometryLanguage() throws {
        let position = "position startpos moves 7g7f 8c8d 2g2f 8d8e"
        let key = try NormalizedPositionKey.make(positionCommand: position)
        let provider = CompactMoveContextKnowledgeProvider(records: [
            .init(positionKey: key, move: "8h7g", sourceKind: .precedent, sourceID: "fixture", observationCount: 12, intent: .unresolved, detail: "precedent fixture")
        ])
        let analysis = try MoveContextEngine(knowledgeProvider: provider).analyze(positionCommand: position, move: "8h7g")
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertEqual(explanation.confidence, .high)
        XCTAssertEqual(explanation.tone, .assertive)
        XCTAssertTrue(explanation.conclusion.contains("飛車先"))
        XCTAssertTrue(explanation.whyNow.contains("直前"))
        XCTAssertTrue(explanation.evidenceText.contains("前例12件"))
        XCTAssertFalse(explanation.conclusion.contains("相手玉側"))
        XCTAssertFalse(explanation.conclusion.contains("攻めに参加"))
        XCTAssertFalse(explanation.whyNow.contains("相手玉側"))
    }

    func testBishopLineResponseExplainsWhyNow() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)
        XCTAssertEqual(analysis.selectedIntent, .bishopLineResponse)
        XCTAssertTrue(explanation.conclusion.contains("角筋"))
        XCTAssertTrue(explanation.whyNow.contains("直前"))
    }

    func testLowConfidenceUsesTentativeLanguage() {
        let analysis = MoveContextAnalysis(
            move: "7g7f",
            previousMove: nil,
            facts: [],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .development, score: 38, evidenceIDs: ["dev"])],
            selectedIntent: .development,
            confidence: .low,
            evidence: [.init(id: "dev", kind: .boardEffect, detail: "fixture", supportedIntent: .development, weight: 38)]
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)
        XCTAssertEqual(explanation.tone, .tentative)
        XCTAssertTrue(explanation.conclusion.contains("候補"))
        XCTAssertTrue(explanation.whyNow.hasPrefix("現時点では"))
    }

    func testUnresolvedNeverInventsReason() {
        let analysis = MoveContextAnalysis(
            move: "7g7f",
            previousMove: nil,
            facts: [],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [],
            selectedIntent: .unresolved,
            confidence: .unresolved,
            evidence: []
        )
        let explanation = ContextExplanationGenerator.make(analysis: analysis)
        XCTAssertEqual(explanation.tone, .unresolved)
        XCTAssertTrue(explanation.conclusion.contains("断定できません"))
        XCTAssertTrue(explanation.evidenceText.contains("非幾何学的根拠"))
    }
}
