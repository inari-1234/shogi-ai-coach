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

    func testBuild18_6R1_T1RepeatedUnresolvedUsesContinuityThenSuppression() {
        let analysis = unresolvedAnalysis()
        var state = ContextExplanationRepetitionState()

        let first = state.present(analysis: analysis)
        let second = state.present(analysis: analysis)
        let third = state.present(analysis: analysis)

        XCTAssertEqual(first.mode, .standard)
        XCTAssertEqual(second.mode, .continuity)
        XCTAssertEqual(third.mode, .suppressedDuplicate)
        XCTAssertNotNil(first.displayedExplanation)
        XCTAssertNotNil(second.displayedExplanation)
        XCTAssertNil(third.displayedExplanation)
        XCTAssertNotEqual(first.displayedExplanation?.conclusion, second.displayedExplanation?.conclusion)
    }

    func testBuild18_6R1_T2IntentChangeResetsSuppression() {
        var state = ContextExplanationRepetitionState()
        _ = state.present(analysis: lowAnalysis(intent: .development, evidenceDetail: "same"))
        _ = state.present(analysis: lowAnalysis(intent: .development, evidenceDetail: "same"))

        let changed = state.present(analysis: lowAnalysis(intent: .defense, evidenceDetail: "same"))
        XCTAssertEqual(changed.mode, .standardWhyNowSuppressed)
        XCTAssertNotNil(changed.displayedExplanation)
        XCTAssertTrue(changed.resetReasons.contains("SELECTED_INTENT_CHANGED"))
    }

    func testBuild18_6R1_T3ConfidenceChangeResetsSuppression() {
        var state = ContextExplanationRepetitionState()
        let low = lowAnalysis(intent: .development, evidenceDetail: "same")
        let medium = MoveContextAnalysis(
            move: "6i7h",
            previousMove: nil,
            facts: [],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .development, score: 70, evidenceIDs: ["e"])],
            selectedIntent: .development,
            confidence: .medium,
            evidence: [.init(id: "e", kind: .boardEffect, detail: "same", supportedIntent: .development, weight: 70)]
        )
        _ = state.present(analysis: low)
        _ = state.present(analysis: low)

        let changed = state.present(analysis: medium)
        XCTAssertEqual(changed.mode, .standard)
        XCTAssertTrue(changed.resetReasons.contains("CONFIDENCE_CHANGED"))
    }

    func testBuild18_6R1_T4WhyNowTriggerChangeResetsSuppression() {
        let base = MoveContextAnalysis(
            move: "5i5h",
            previousMove: "5g5h",
            facts: [],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .kingEscape, score: 70, evidenceIDs: ["board"])],
            selectedIntent: .kingEscape,
            confidence: .medium,
            evidence: [.init(id: "board", kind: .boardEffect, detail: "same", supportedIntent: .kingEscape, weight: 70)]
        )
        let threat = MoveContextAnalysis(
            move: "5i5h",
            previousMove: "5g5h",
            facts: [.init(id: "side_in_check", kind: .sideInCheck, detail: "5i")],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: base.intentCandidates,
            selectedIntent: base.selectedIntent,
            confidence: base.confidence,
            evidence: base.evidence
        )
        var state = ContextExplanationRepetitionState()
        _ = state.present(analysis: base)
        _ = state.present(analysis: base)

        let changed = state.present(analysis: threat)
        XCTAssertEqual(changed.mode, .standard)
        XCTAssertTrue(changed.resetReasons.contains("WHY_NOW_TRIGGER_CHANGED"))
    }

    func testBuild18_6R1_T5EvidenceChangeResetsSuppression() {
        var state = ContextExplanationRepetitionState()
        let a = lowAnalysis(intent: .development, evidenceDetail: "A")
        let b = lowAnalysis(intent: .development, evidenceDetail: "B")
        _ = state.present(analysis: a)
        _ = state.present(analysis: a)

        let changed = state.present(analysis: b)
        XCTAssertEqual(changed.mode, .standardWhyNowSuppressed)
        XCTAssertNotNil(changed.displayedExplanation)
        XCTAssertTrue(changed.resetReasons.contains("SUPPORTING_EVIDENCE_CHANGED"))
    }

    func testBuild18_6R1_T6FactOrContextChangeCanRestoreFullDisplay() {
        var state = ContextExplanationRepetitionState()
        let base = unresolvedAnalysis()
        _ = state.present(analysis: base)
        _ = state.present(analysis: base)

        let changed = MoveContextAnalysis(
            move: "2g2f",
            previousMove: nil,
            facts: [.init(id: "capture", kind: .capture, detail: "2f")],
            contextChanges: [.init(id: "material_change", detail: "capture_on_2f")],
            effects: [],
            outcomes: [],
            intentCandidates: [],
            selectedIntent: .unresolved,
            confidence: .unresolved,
            evidence: []
        )
        let presentation = state.present(analysis: changed)
        XCTAssertEqual(presentation.mode, .standardWhyNowSuppressed)
        XCTAssertNotNil(presentation.displayedExplanation)
        XCTAssertTrue(
            presentation.resetReasons.contains("FACT_CHANGED")
                || presentation.resetReasons.contains("CONTEXT_CHANGE_CHANGED")
        )
        XCTAssertNotNil(presentation.displayedExplanation)
    }

    func testBuild18_6R1_T7RepetitionPolicyDoesNotGenerateUnsupportedPurpose() {
        var state = ContextExplanationRepetitionState()
        let analysis = unresolvedAnalysis()
        _ = state.present(analysis: analysis)
        let continuity = state.present(analysis: analysis)

        XCTAssertEqual(continuity.semanticExplanation.conclusion, "この手単独では狙いを断定できません。")
        XCTAssertEqual(continuity.mode, .continuity)
        XCTAssertFalse(continuity.displayedExplanation?.conclusion.contains("攻めを狙") ?? true)
        XCTAssertFalse(continuity.displayedExplanation?.conclusion.contains("目的") ?? true)
    }

    func testBuild18_6R1_T8LowUnresolvedNeverBecomesAssertive() {
        var state = ContextExplanationRepetitionState()
        let analysis = unresolvedAnalysis()
        _ = state.present(analysis: analysis)
        let continuity = state.present(analysis: analysis)

        XCTAssertEqual(continuity.semanticExplanation.tone, .unresolved)
        XCTAssertEqual(continuity.displayedExplanation?.tone, .unresolved)
        XCTAssertEqual(continuity.displayedExplanation?.confidence, .unresolved)
    }

    func testBuild18_6R1_T9HeldConceptTermsAreNotIntroduced() {
        let heldTerms = ["急戦", "さばき", "捌き", "複数の狙い", "テンポ管理"]
        var state = ContextExplanationRepetitionState()
        let analysis = unresolvedAnalysis()
        let presentations = [
            state.present(analysis: analysis),
            state.present(analysis: analysis),
            state.present(analysis: analysis)
        ]

        for item in presentations {
            let text = [
                item.semanticExplanation.conclusion,
                item.semanticExplanation.whyNow,
                item.displayedExplanation?.conclusion ?? "",
                item.displayedExplanation?.whyNow ?? ""
            ].joined(separator: " ")
            XCTAssertFalse(heldTerms.contains(where: text.contains))
        }
    }

    func testBuild18_6R1_T10SafeConceptSupplementIsPreservedOnStandardDisplay() {
        let analysis = MoveContextAnalysis(
            move: "5e5d",
            previousMove: nil,
            facts: [],
            contextChanges: [],
            effects: [.init(id: "escape_route_control", detail: "opponent_escape_squares:4->3")],
            outcomes: [],
            intentCandidates: [.init(intent: .attackContinuation, score: 100, evidenceIDs: ["board"])],
            selectedIntent: .attackContinuation,
            confidence: .high,
            evidence: [.init(id: "board", kind: .boardEffect, detail: "attack continues", supportedIntent: .attackContinuation, weight: 100)]
        )
        var state = ContextExplanationRepetitionState()
        let first = state.present(analysis: analysis)

        XCTAssertEqual(first.mode, .standard)
        XCTAssertEqual(first.semanticExplanation.conceptSupplement?.conceptID, "escape_route_control")
        XCTAssertEqual(first.displayedExplanation?.conceptSupplement?.conceptID, "escape_route_control")
    }

    func testBuild18_6R1_T11IntentResetKeepsNewConclusionButSuppressesRepeatedGenericWhyNow() {
        var state = ContextExplanationRepetitionState()
        let first = lowAnalysis(intent: .development, evidenceDetail: "A")
        let second = lowAnalysis(intent: .defense, evidenceDetail: "B")

        let initial = state.present(analysis: first)
        let changed = state.present(analysis: second)

        XCTAssertEqual(initial.mode, .standard)
        XCTAssertEqual(changed.mode, .standardWhyNowSuppressed)
        XCTAssertTrue(changed.resetReasons.contains("SELECTED_INTENT_CHANGED"))
        XCTAssertEqual(changed.semanticExplanation.whyNow, initial.semanticExplanation.whyNow)
        XCTAssertNotEqual(changed.displayedExplanation?.conclusion, initial.displayedExplanation?.conclusion)
        XCTAssertEqual(changed.displayedExplanation?.whyNow, "")
        XCTAssertEqual(changed.displayedExplanation?.tone, .tentative)
        XCTAssertEqual(changed.displayedExplanation?.confidence, .low)
    }

    private func unresolvedAnalysis() -> MoveContextAnalysis {
        MoveContextAnalysis(
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
    }

    private func lowAnalysis(intent: MoveIntent, evidenceDetail: String) -> MoveContextAnalysis {
        MoveContextAnalysis(
            move: "7g7f",
            previousMove: nil,
            facts: [],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: intent, score: 38, evidenceIDs: ["e"])],
            selectedIntent: intent,
            confidence: .low,
            evidence: [.init(id: "e", kind: .boardEffect, detail: evidenceDetail, supportedIntent: intent, weight: 38)]
        )
    }

}
