import Foundation

public enum ContextExplanationTone: String, Codable, Equatable, Sendable {
    case assertive
    case measured
    case tentative
    case unresolved
}

public struct ContextConceptSupplement: Codable, Equatable, Sendable {
    public let conceptID: String
    public let text: String
    public let evidenceText: String

    public init(conceptID: String, text: String, evidenceText: String) {
        self.conceptID = conceptID
        self.text = text
        self.evidenceText = evidenceText
    }
}

public struct ContextMoveExplanation: Codable, Equatable, Sendable {
    public let conclusion: String
    public let whyNow: String
    public let evidenceText: String
    public let confidence: ContextConfidence
    public let tone: ContextExplanationTone
    public let conceptSupplement: ContextConceptSupplement?

    public init(
        conclusion: String,
        whyNow: String,
        evidenceText: String,
        confidence: ContextConfidence,
        tone: ContextExplanationTone,
        conceptSupplement: ContextConceptSupplement? = nil
    ) {
        self.conclusion = conclusion
        self.whyNow = whyNow
        self.evidenceText = evidenceText
        self.confidence = confidence
        self.tone = tone
        self.conceptSupplement = conceptSupplement
    }
}


public enum ContextExplanationPresentationMode: String, Codable, Equatable, Sendable {
    case standard = "STANDARD"
    case continuity = "CONTINUITY"
    case suppressedDuplicate = "SUPPRESSED_DUPLICATE"
}

public struct ContextExplanationPresentation: Codable, Equatable, Sendable {
    public let mode: ContextExplanationPresentationMode
    public let semanticExplanation: ContextMoveExplanation
    public let displayedExplanation: ContextMoveExplanation?
    public let semanticSignature: String
    public let equivalentRunLength: Int
    public let resetReasons: [String]

    public init(
        mode: ContextExplanationPresentationMode,
        semanticExplanation: ContextMoveExplanation,
        displayedExplanation: ContextMoveExplanation?,
        semanticSignature: String,
        equivalentRunLength: Int,
        resetReasons: [String]
    ) {
        self.mode = mode
        self.semanticExplanation = semanticExplanation
        self.displayedExplanation = displayedExplanation
        self.semanticSignature = semanticSignature
        self.equivalentRunLength = equivalentRunLength
        self.resetReasons = resetReasons
    }
}

/// Presentation-only repetition control.
///
/// This state never changes MoveIntent, confidence, evidence, GroundedExplanationContext,
/// or Concept semantics. It only decides whether already-generated explanation text should
/// be shown in full, condensed once as continuity, or omitted on further equivalent plies.
public struct ContextExplanationRepetitionState: Sendable {
    private struct Signature: Equatable, Sendable {
        let selectedIntent: String
        let confidence: String
        let trigger: String
        let authority: String
        let sourceEvidence: [String]
        let sourceSignals: [String]
        let supportingEvidence: [String]
        let observableFacts: [String]
        let contextChanges: [String]
        let observedChange: String
        let causalPreviousMove: String
        let forcingState: [String]
        let conceptID: String

        var serialized: String {
            [
                "intent=\(selectedIntent)",
                "confidence=\(confidence)",
                "trigger=\(trigger)",
                "authority=\(authority)",
                "sourceEvidence=\(sourceEvidence.joined(separator: ","))",
                "sourceSignals=\(sourceSignals.joined(separator: ","))",
                "supportingEvidence=\(supportingEvidence.joined(separator: ","))",
                "facts=\(observableFacts.joined(separator: ","))",
                "contextChanges=\(contextChanges.joined(separator: ","))",
                "observedChange=\(observedChange)",
                "causalPreviousMove=\(causalPreviousMove)",
                "forcing=\(forcingState.joined(separator: ","))",
                "concept=\(conceptID)"
            ].joined(separator: "|")
        }

        func resetReasons(comparedWith previous: Signature) -> [String] {
            var reasons: [String] = []
            if selectedIntent != previous.selectedIntent { reasons.append("SELECTED_INTENT_CHANGED") }
            if confidence != previous.confidence { reasons.append("CONFIDENCE_CHANGED") }
            if trigger != previous.trigger { reasons.append("WHY_NOW_TRIGGER_CHANGED") }
            if authority != previous.authority { reasons.append("WHY_NOW_AUTHORITY_CHANGED") }
            if sourceEvidence != previous.sourceEvidence || supportingEvidence != previous.supportingEvidence {
                reasons.append("SUPPORTING_EVIDENCE_CHANGED")
            }
            if sourceSignals != previous.sourceSignals { reasons.append("SOURCE_SIGNAL_CHANGED") }
            if observableFacts != previous.observableFacts { reasons.append("FACT_CHANGED") }
            if contextChanges != previous.contextChanges || observedChange != previous.observedChange {
                reasons.append("CONTEXT_CHANGE_CHANGED")
            }
            if causalPreviousMove != previous.causalPreviousMove {
                reasons.append("PREVIOUS_MOVE_CAUSALITY_CHANGED")
            }
            if forcingState != previous.forcingState { reasons.append("FORCING_STATE_CHANGED") }
            if conceptID != previous.conceptID { reasons.append("CONCEPT_SUPPLEMENT_CHANGED") }
            return reasons
        }
    }

    private var previousSignature: Signature?
    private var equivalentRunLength = 0

    public init() {}

    public mutating func reset() {
        previousSignature = nil
        equivalentRunLength = 0
    }

    public mutating func present(
        analysis: MoveContextAnalysis,
        suppressingConceptIDs: Set<String> = []
    ) -> ContextExplanationPresentation {
        // Keep the unsuppressed candidate only for the repetition signature so that the
        // existing Concept repetition policy does not masquerade as a semantic reset.
        let rawExplanation = ContextExplanationGenerator.make(analysis: analysis)
        let semanticExplanation = ContextExplanationGenerator.make(
            analysis: analysis,
            suppressingConceptIDs: suppressingConceptIDs
        )
        let grounded = GroundedExplanationProjector.make(analysis: analysis)
        let signature = Self.signature(
            analysis: analysis,
            grounded: grounded,
            candidateConceptID: rawExplanation.conceptSupplement?.conceptID
        )

        let mode: ContextExplanationPresentationMode
        let displayedExplanation: ContextMoveExplanation?
        let resetReasons: [String]

        if let previousSignature, previousSignature == signature {
            equivalentRunLength += 1
            resetReasons = []
            if equivalentRunLength == 2 {
                mode = .continuity
                displayedExplanation = Self.continuityExplanation(from: semanticExplanation)
            } else {
                mode = .suppressedDuplicate
                displayedExplanation = nil
            }
        } else {
            resetReasons = previousSignature.map { signature.resetReasons(comparedWith: $0) } ?? ["INITIAL"]
            previousSignature = signature
            equivalentRunLength = 1
            mode = .standard
            displayedExplanation = semanticExplanation
        }

        return ContextExplanationPresentation(
            mode: mode,
            semanticExplanation: semanticExplanation,
            displayedExplanation: displayedExplanation,
            semanticSignature: signature.serialized,
            equivalentRunLength: equivalentRunLength,
            resetReasons: resetReasons
        )
    }

    private static func signature(
        analysis: MoveContextAnalysis,
        grounded: GroundedExplanationContext,
        candidateConceptID: String?
    ) -> Signature {
        let supportingEvidence = analysis.evidence
            .filter { $0.supportedIntent == analysis.selectedIntent && $0.weight > 0 }
            .map {
                "\($0.id):\($0.kind.rawValue):\($0.weight):\($0.detail)"
            }
            .sorted()

        // current_move and previous_move naturally change every ply. They are not treated
        // as new explanatory information by themselves. Previous-move identity is included
        // only when the grounded trigger actually claims previous-move causality.
        let observableFacts = analysis.facts
            .filter { $0.kind != .currentMove && $0.kind != .previousMove }
            .map { "\($0.id):\($0.kind.rawValue):\($0.detail)" }
            .sorted()

        let contextChanges = analysis.contextChanges
            .map { "\($0.id):\($0.detail)" }
            .sorted()

        let causalPreviousMove: String
        switch grounded.trigger {
        case .directPreviousMove, .exchangeSequence:
            causalPreviousMove = grounded.previousMove ?? "-"
        default:
            causalPreviousMove = "-"
        }

        var forcingState: [String] = []
        if analysis.facts.contains(where: { $0.kind == .sideInCheck }) {
            forcingState.append("SIDE_IN_CHECK")
        }
        if analysis.facts.contains(where: { $0.kind == .check }) {
            forcingState.append("CHECK_FACT")
        }
        if analysis.effects.contains(where: { $0.id == "gives_check" }) {
            forcingState.append("GIVES_CHECK")
        }
        for id in ["ev_forced_mate", "ev_threatmate", "ev_threatmate_defense", "ev_check_defense", "ev_king_escape"]
            where analysis.evidence.contains(where: { $0.id == id && $0.weight > 0 }) {
            forcingState.append(id)
        }

        return Signature(
            selectedIntent: analysis.selectedIntent.rawValue,
            confidence: analysis.confidence.rawValue,
            trigger: grounded.trigger.rawValue,
            authority: grounded.authorityKind.rawValue,
            sourceEvidence: grounded.sourceEvidenceIDs.sorted(),
            sourceSignals: grounded.sourceSignalIDs.sorted(),
            supportingEvidence: supportingEvidence,
            observableFacts: observableFacts,
            contextChanges: contextChanges,
            observedChange: grounded.observedChange ?? "-",
            causalPreviousMove: causalPreviousMove,
            forcingState: forcingState.sorted(),
            conceptID: candidateConceptID ?? "-"
        )
    }

    private static func continuityExplanation(
        from semantic: ContextMoveExplanation
    ) -> ContextMoveExplanation {
        let conclusion: String
        if semantic.tone == .unresolved {
            conclusion = "前の手と同様、狙いを断定できる新しい根拠はありません。"
        } else {
            conclusion = "前の手と同じ根拠状態が続いています。"
        }

        return ContextMoveExplanation(
            conclusion: conclusion,
            whyNow: "",
            evidenceText: semantic.evidenceText,
            confidence: semantic.confidence,
            tone: semantic.tone,
            conceptSupplement: nil
        )
    }
}

public enum ContextExplanationGenerator {
    public static func make(
        analysis: MoveContextAnalysis,
        suppressingConceptIDs: Set<String> = []
    ) -> ContextMoveExplanation {
        let grounded = GroundedExplanationProjector.make(analysis: analysis)

        guard analysis.selectedIntent != .unresolved,
              analysis.confidence != .unresolved else {
            return ContextMoveExplanation(
                conclusion: "この手単独では狙いを断定できません。",
                whyNow: grounded.detail,
                evidenceText: evidenceSummary(analysis),
                confidence: .unresolved,
                tone: .unresolved
            )
        }

        let action = actionText(for: analysis.selectedIntent)
        let conclusion: String
        let tone: ContextExplanationTone
        switch analysis.confidence {
        case .high:
            conclusion = "\(action)手です。"
            tone = .assertive
        case .medium:
            conclusion = "\(action)意味が強い手です。"
            tone = .measured
        case .low:
            conclusion = "\(action)狙いが候補です。"
            tone = .tentative
        case .unresolved:
            conclusion = "この手単独では狙いを断定できません。"
            tone = .unresolved
        }

        let whyNow = grounded.detail

        return ContextMoveExplanation(
            conclusion: conclusion,
            whyNow: whyNow,
            evidenceText: evidenceSummary(analysis),
            confidence: analysis.confidence,
            tone: tone,
            conceptSupplement: conceptSupplement(
                for: analysis,
                suppressingConceptIDs: suppressingConceptIDs
            )
        )
    }

    private static func actionText(for intent: MoveIntent) -> String {
        switch intent {
        case .rookPawnResponse: return "相手の飛車先の歩の前進に備える"
        case .bishopLineResponse: return "直前に通った角筋へ対応する"
        case .pieceDefense: return "狙われた駒を守る"
        case .captureThreatResponse: return "直前に生じた駒取りの脅威へ対応する"
        case .exchangePreparation: return "次の駒交換に備える"
        case .attackContinuation: return "攻めを継続する"
        case .attackPreparation: return "次の攻めに向けた形を整える"
        case .defense: return "相手の攻めを受ける"
        case .kingSafety: return "自玉の安全を高める"
        case .castling: return "玉の囲いを進める"
        case .development: return "序盤の駒組みを進める"
        case .pieceActivation: return "駒の働きを広げる"
        case .majorPieceActivation: return "飛車・角の働きを広げる"
        case .tenuki: return "直前の局所戦に直接応じず、別の場所を優先する"
        case .neutralizeThreat: return "相手の具体的な脅威を消す"
        case .handPieceDeployment: return "持駒を盤上へ投入する"
        case .outpostCreation: return "前線に駒の拠点を作る"
        case .matingAttack: return "詰みにつながる攻めを進める"
        case .threatmate: return "次に詰みを狙える形を作る"
        case .threatmateDefense: return "相手の詰めろを外す"
        case .kingEscape: return "王手から玉を逃がす"
        case .controlAddition: return "重要なマスへの利きを増やす"
        case .controlBlock: return "相手の利きを遮る"
        case .postExchangeImprovement: return "駒交換後の形を整える"
        case .unresolved: return "狙いを確認する"
        }
    }

    private static func conceptSupplement(
        for analysis: MoveContextAnalysis,
        suppressingConceptIDs: Set<String>
    ) -> ContextConceptSupplement? {
        switch analysis.confidence {
        case .high, .medium:
            break
        case .low, .unresolved:
            return nil
        }

        let candidates: [String]
        switch analysis.selectedIntent {
        case .captureThreatResponse, .pieceDefense, .defense, .neutralizeThreat:
            candidates = ["attack_attacker", "piece_mobility", "escape_route_control"]
        case .attackContinuation, .attackPreparation, .matingAttack, .threatmate, .controlAddition, .outpostCreation:
            candidates = ["escape_route_control", "piece_mobility", "attack_attacker"]
        default:
            candidates = ["piece_mobility", "attack_attacker", "escape_route_control"]
        }

        for conceptID in candidates where !suppressingConceptIDs.contains(conceptID) {
            switch conceptID {
            case "attack_attacker":
                guard let effect = analysis.effects.first(where: { $0.id == conceptID }),
                      permitsAttackAttackerSupplement(for: analysis.selectedIntent) else {
                    continue
                }
                return ContextConceptSupplement(
                    conceptID: effect.id,
                    text: "同時に、直前に攻撃を作った相手駒そのものにも対応しています。",
                    evidenceText: "attacker_squares:\(effect.detail)"
                )

            case "escape_route_control":
                guard let effect = analysis.effects.first(where: { $0.id == conceptID }),
                      permitsEscapeRouteSupplement(for: analysis.selectedIntent) else {
                    continue
                }
                let text: String
                if let counts = transitionCounts(
                    from: effect.detail,
                    prefix: "opponent_escape_squares:"
                ), counts.before > counts.after {
                    let reduced = counts.before - counts.after
                    text = "同時に、相手玉の安全な逃げ場所が\(reduced)つ減っています。"
                } else {
                    text = "同時に、相手玉の安全な逃げ場所も減っています。"
                }
                return ContextConceptSupplement(
                    conceptID: effect.id,
                    text: text,
                    evidenceText: effect.detail
                )

            case "piece_mobility":
                guard let effect = analysis.effects.first(where: { $0.id == conceptID }),
                      permitsPieceMobilitySupplement(for: analysis.selectedIntent) else {
                    continue
                }
                let text: String
                if let counts = transitionCounts(
                    from: effect.detail,
                    prefix: "attack_squares:"
                ), counts.after > counts.before {
                    text = "同時に、この手で動かした駒が利かせられるマスも\(counts.before)から\(counts.after)に増えています。"
                } else {
                    text = "同時に、この手で動かした駒の利かせられるマスも増えています。"
                }
                return ContextConceptSupplement(
                    conceptID: effect.id,
                    text: text,
                    evidenceText: effect.detail
                )

            default:
                continue
            }
        }

        return nil
    }

    private static func permitsAttackAttackerSupplement(for intent: MoveIntent) -> Bool {
        switch intent {
        case .captureThreatResponse, .pieceDefense, .defense, .bishopLineResponse, .neutralizeThreat:
            return true
        default:
            return false
        }
    }

    private static func permitsEscapeRouteSupplement(for intent: MoveIntent) -> Bool {
        switch intent {
        case .attackContinuation, .attackPreparation, .matingAttack, .threatmate, .controlAddition, .outpostCreation:
            return true
        default:
            return false
        }
    }

    private static func permitsPieceMobilitySupplement(for intent: MoveIntent) -> Bool {
        switch intent {
        case .unresolved, .pieceActivation, .majorPieceActivation, .development, .castling, .handPieceDeployment:
            return false
        default:
            return true
        }
    }

    private static func transitionCounts(
        from detail: String,
        prefix: String
    ) -> (before: Int, after: Int)? {
        guard detail.hasPrefix(prefix) else { return nil }
        let values = detail.dropFirst(prefix.count).split(separator: "->")
        guard values.count == 2,
              let before = Int(values[0]),
              let after = Int(values[1]) else {
            return nil
        }
        return (before, after)
    }

    private static func evidenceSummary(_ analysis: MoveContextAnalysis) -> String {
        let supported = analysis.evidence.filter {
            $0.supportedIntent == analysis.selectedIntent
                && $0.kind != .geometry
                && $0.weight > 0
        }
        var parts: [String] = []

        if supported.contains(where: { $0.kind == .previousMoveCausality }) {
            parts.append("直前手との因果関係")
        }
        if supported.contains(where: { $0.kind == .boardEffect }) {
            parts.append("具体的な盤面変化")
        }
        if supported.contains(where: { $0.kind == .openingBook }) {
            parts.append("定跡情報")
        }
        let precedentCounts = supported
            .filter { $0.kind == .precedent }
            .compactMap { observations(from: $0.detail) }
        if let count = precedentCounts.max() {
            parts.append("同局面・同手の前例\(count)件")
        } else if supported.contains(where: { $0.kind == .precedent }) {
            parts.append("同局面・同手の前例")
        }
        if supported.contains(where: { $0.kind == .enginePV }) {
            parts.append("安定したエンジンPV")
        }
        if supported.contains(where: { $0.kind == .counterfactual }) {
            parts.append("推奨手との反実仮想比較")
        }

        if parts.isEmpty {
            return "十分な非幾何学的根拠は確認できていません。"
        }
        return parts.joined(separator: "・") + "を根拠にしています。"
    }

    private static func observations(from detail: String) -> Int? {
        for field in detail.split(separator: ";") {
            let token = field.trimmingCharacters(in: .whitespaces)
            guard token.hasPrefix("observations=") else { continue }
            return Int(token.dropFirst("observations=".count))
        }
        return nil
    }
}
