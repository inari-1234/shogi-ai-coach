import Foundation

struct RecommendationDecisionPresentation {
    enum Status: Equatable {
        case matched
        case recommended
        case provisional

        var badgeText: String {
            switch self {
            case .matched: return "実戦手と一致"
            case .recommended: return "推奨"
            case .provisional: return "比較保留"
            }
        }
    }

    let status: Status
    let headline: String
    let meaning: String
    let difference: String
    let confidenceTitle: String
    let confidenceDetail: String
    let recommendedRouteLabel: String
    let recommendedRouteMeaningTitle: String

    static func make(entry: ContinuationSimulationEntry) -> Self {
        let firstRecommended = entry.recommended.moves.first
        let firstActual = entry.actual.moves.first
        let sameMove = firstRecommended?.usi == firstActual?.usi

        if sameMove {
            let label = firstRecommended?.label ?? "候補手"
            return .init(
                status: .matched,
                headline: "実戦手 \(label) は最善候補と一致",
                meaning: concreteMeaning(entry: entry, allowRecommendationClaim: true),
                difference: entry.reasonSummary,
                confidenceTitle: entry.continuationStable ? "一致を確認" : "一致・読み筋は参考",
                confidenceDetail: entry.continuationStable
                    ? "同条件比較で実戦手と最善候補が一致し、継続PVも安定しています。"
                    : "実戦手と最善候補は一致していますが、長い継続PVは参考として確認します。",
                recommendedRouteLabel: "最善＝実戦",
                recommendedRouteMeaningTitle: "最善手と実戦手の意味"
            )
        }

        if !entry.comparisonStable {
            let label = firstRecommended?.label ?? "候補手"
            return .init(
                status: .provisional,
                headline: "暫定候補 \(label)",
                meaning: concreteMeaning(entry: entry, allowRecommendationClaim: false),
                difference: entry.reasonSummary,
                confidenceTitle: "比較判定を保留",
                confidenceDetail: "再解析後も評価順序または評価差が安定していません。この手は上位候補として確認できますが、推奨手とは確定しません。",
                recommendedRouteLabel: "暫定候補",
                recommendedRouteMeaningTitle: "暫定候補ルートで確認できること"
            )
        }

        let label = firstRecommended?.label ?? "候補手"
        return .init(
            status: .recommended,
            headline: "推奨 \(label)",
            meaning: concreteMeaning(entry: entry, allowRecommendationClaim: true),
            difference: entry.reasonSummary,
            confidenceTitle: entry.continuationStable ? "比較根拠あり" : "候補順位は安定・読み筋は参考",
            confidenceDetail: entry.continuationStable
                ? "同じ探索条件での比較と継続PVの両方が安定しています。上の比較理由を判断材料として扱えます。"
                : "同じ探索条件での候補順位は安定していますが、継続PVは安定していません。最初の盤面差と短い手順を判断材料にします。",
            recommendedRouteLabel: "推奨",
            recommendedRouteMeaningTitle: "推奨ルートで確認できること"
        )
    }

    private static func concreteMeaning(
        entry: ContinuationSimulationEntry,
        allowRecommendationClaim: Bool
    ) -> String {
        let moves = entry.recommended.moves
        guard let first = moves.first else {
            return "候補手の読み筋を取得できていません。"
        }

        if moves.count >= 2,
           let captured = first.effect.capturedPiece,
           moves[1].effect.capturedPiece == first.effect.pieceAfter,
           moves[1].effect.destination == first.effect.destination {
            var text = "\(first.label)で\(captured.kanji)を取りますが、直後に\(moves[1].label)で動かした\(first.effect.pieceAfter.kanji)が取り返されます。"
            if moves.count >= 3,
               moves[2].side == first.side,
               let nextCaptured = moves[2].effect.capturedPiece {
                text += "その後\(moves[2].label)で\(nextCaptured.kanji)を取る手順へ続きます。"
            }
            text += allowRecommendationClaim
                ? "最初の駒得だけでなく、この交換後の形まで含めて評価された手です。"
                : "この交換手順は候補PVで確認できますが、比較自体が未安定なので優劣は確定しません。"
            return text
        }

        if let later = firstPieceFollowUp(first: first, moves: moves) {
            let capturedText = later.effect.capturedPiece.map { "\($0.kanji)を取る" } ?? "次の攻防に参加する"
            let tail = allowRecommendationClaim
                ? "一手だけの配置変更ではなく、この継続まで含めて評価された手です。"
                : "この継続は候補PVで確認できますが、比較自体が未安定なので優劣は確定しません。"
            return "\(first.label)で\(first.effect.pieceAfter.kanji)を前へ出し、PVでは同じ駒が後に\(later.label)で\(capturedText)展開になります。\(tail)"
        }

        if !isGenericCoachText(first.coachText) {
            let tail = allowRecommendationClaim
                ? "この盤面変化を、実戦手との比較と合わせて判断します。"
                : "ただし比較が未安定なため、この意味だけで推奨とは確定しません。"
            return first.coachText + tail
        }

        let sequence = moves.prefix(4).map(\.label).joined(separator: " → ")
        if sequence.isEmpty {
            return "候補手の意味は、実戦手との盤面差と合わせて確認します。"
        }

        return allowRecommendationClaim
            ? "この一手だけで狙いを決めつけるのではなく、安定PVでは \(sequence) と進みます。この手順で生じる盤面差まで含めて推奨理由を判断します。"
            : "候補PVでは \(sequence) と進みます。ただし比較が未安定なため、この手順は参考であり推奨理由とは確定しません。"
    }

    private static func firstPieceFollowUp(
        first: ContinuationMoveStep,
        moves: [ContinuationMoveStep]
    ) -> ContinuationMoveStep? {
        guard !first.effect.isDrop else { return nil }
        var currentSquare = first.effect.destination

        for move in moves.dropFirst() {
            guard move.side == first.side else { continue }
            if move.effect.source == currentSquare,
               move.effect.pieceBefore == first.effect.pieceAfter {
                currentSquare = move.effect.destination
                if move.effect.capturedPiece != nil || move.givesCheck {
                    return move
                }
            }
        }
        return nil
    }

    private static func isGenericCoachText(_ text: String) -> Bool {
        text.contains("この1手だけでは狙いを断定せず")
            || text.contains("この一手だけでは狙いを断定せず")
    }

    func routeLabel(for kind: ContinuationRouteKind) -> String {
        kind == .recommended ? recommendedRouteLabel : "実戦"
    }

    func routeMeaningTitle(for kind: ContinuationRouteKind) -> String {
        kind == .recommended ? recommendedRouteMeaningTitle : "実戦ルートで確認できること"
    }

    func sanitizedRouteSummary(_ route: ContinuationRoute) -> String {
        guard status == .provisional, route.kind == .recommended else {
            return route.summary
        }
        return route.summary
            .replacingOccurrences(of: "推奨ルート", with: "暫定候補ルート")
            .replacingOccurrences(of: "推奨手", with: "暫定候補")
    }

    func sanitizedTargetShape(_ route: ContinuationRoute) -> String {
        guard status == .provisional, route.kind == .recommended else {
            return route.targetShapeSummary
        }
        return route.targetShapeSummary
            .replacingOccurrences(of: "推奨PV", with: "候補PV")
            .replacingOccurrences(of: "推奨", with: "候補")
    }
}
