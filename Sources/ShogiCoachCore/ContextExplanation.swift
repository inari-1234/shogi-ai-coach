import Foundation

public enum ContextExplanationTone: String, Codable, Equatable, Sendable {
    case assertive
    case measured
    case tentative
    case unresolved
}

public struct ContextMoveExplanation: Codable, Equatable, Sendable {
    public let conclusion: String
    public let whyNow: String
    public let evidenceText: String
    public let confidence: ContextConfidence
    public let tone: ContextExplanationTone

    public init(
        conclusion: String,
        whyNow: String,
        evidenceText: String,
        confidence: ContextConfidence,
        tone: ContextExplanationTone
    ) {
        self.conclusion = conclusion
        self.whyNow = whyNow
        self.evidenceText = evidenceText
        self.confidence = confidence
        self.tone = tone
    }
}

public enum ContextExplanationGenerator {
    public static func make(analysis: MoveContextAnalysis) -> ContextMoveExplanation {
        guard analysis.selectedIntent != .unresolved,
              analysis.confidence != .unresolved else {
            return ContextMoveExplanation(
                conclusion: "この手単独では狙いを断定できません。",
                whyNow: "直前手との因果関係や具体的な盤面効果が十分に確定していないため、続く手順も含めて確認します。",
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

        let why = whyNowText(for: analysis.selectedIntent)
        let whyNow = analysis.confidence == .low ? "現時点では、\(why)" : why

        return ContextMoveExplanation(
            conclusion: conclusion,
            whyNow: whyNow,
            evidenceText: evidenceSummary(analysis),
            confidence: analysis.confidence,
            tone: tone
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

    private static func whyNowText(for intent: MoveIntent) -> String {
        switch intent {
        case .rookPawnResponse:
            return "直前に相手が飛車先の歩を進めたため、その歩がさらに前へ進む筋への対応が必要になった局面です。"
        case .bishopLineResponse:
            return "直前の手で新しく角の利きが通り、その筋への対応が必要になった局面です。"
        case .pieceDefense:
            return "直前の手で自軍の駒が新しく狙われたため、その駒の安全を確保する必要が生じています。"
        case .captureThreatResponse:
            return "直前の手で具体的な駒取りが発生し得る形になったため、その脅威への対応が必要です。"
        case .exchangePreparation:
            return "盤上で駒がぶつかる形になり、次の交換後まで見据える必要がある局面です。"
        case .attackContinuation:
            return "すでに相手玉側への具体的な働きがあり、それを切らさず続ける局面です。"
        case .attackPreparation:
            return "相手玉側への具体的な働きを増やせる形になっており、次の攻めを準備する局面です。"
        case .defense:
            return "自玉側への相手の働きが強まっており、まず危険を減らす必要がある局面です。"
        case .kingSafety:
            return "この先の攻防に備え、自玉周辺の守りを整える価値が高い局面です。"
        case .castling:
            return "まだ序盤で玉を安全な位置へ移し、囲いを進められる局面です。"
        case .development:
            return "まだ駒組みの段階で、未活用の駒を働かせる価値がある局面です。"
        case .pieceActivation:
            return "この手で駒の可動域や働きを増やせる局面です。"
        case .majorPieceActivation:
            return "この手で飛車・角の利きを広げ、盤面への影響を増やせる局面です。"
        case .tenuki:
            return "直前の局所的な変化へ直接応じず、離れた場所で別の価値を優先しています。"
        case .neutralizeThreat:
            return "相手に具体的な次の狙いがあり、それを先に消す必要がある局面です。"
        case .handPieceDeployment:
            return "持駒を使うことで、盤上に新しい働きを作れる局面です。"
        case .outpostCreation:
            return "前線に安定して使えるマスがあり、そこを拠点化できる局面です。"
        case .matingAttack:
            return "エンジンの読みで詰みにつながる手順が確認されている局面です。"
        case .threatmate:
            return "次の一手で詰みを狙える形を作れることが確認されている局面です。"
        case .threatmateDefense:
            return "相手の詰めろがあり、この手でその脅威を外せることが確認されている局面です。"
        case .kingEscape:
            return "自玉が王手を受けており、まず王手を解消する必要がある局面です。"
        case .controlAddition:
            return "重要なマスへの利きを増やすことで、次の攻防を進めやすくする局面です。"
        case .controlBlock:
            return "相手の利きが通っており、その線を遮ることが必要な局面です。"
        case .postExchangeImprovement:
            return "直前に駒の取り合いが起き、交換後の配置を整える局面です。"
        case .unresolved:
            return "十分な因果関係を確認できていません。"
        }
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
