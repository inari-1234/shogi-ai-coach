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
