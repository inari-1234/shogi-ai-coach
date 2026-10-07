import Foundation

enum RecommendationDecisionPolicyAudit {
    enum AuditError: Error, LocalizedError {
        case violation(String)

        var errorDescription: String? {
            switch self {
            case .violation(let message): return message
            }
        }
    }

    static func validate(entries: [ContinuationSimulationEntry]) throws {
        for entry in entries {
            guard let firstRecommended = entry.recommended.moves.first,
                  let firstActual = entry.actual.moves.first else {
                throw AuditError.violation("\(entry.ply)手目: 比較ルートの先頭手がありません")
            }

            let presentation = RecommendationDecisionPresentation.make(entry: entry)
            let sameMove = firstRecommended.usi == firstActual.usi

            if !entry.comparisonStable {
                guard presentation.status == .provisional else {
                    throw AuditError.violation("\(entry.ply)手目: 未安定比較を推奨扱いしています")
                }
                guard presentation.headline.contains("暫定候補"),
                      !presentation.headline.contains("推奨") else {
                    throw AuditError.violation("\(entry.ply)手目: 比較保留時の見出しが不適切です")
                }
                guard presentation.recommendedRouteLabel == "暫定候補" else {
                    throw AuditError.violation("\(entry.ply)手目: 比較保留時に推奨ルート表記が残っています")
                }
            } else if sameMove {
                guard presentation.status == .matched else {
                    throw AuditError.violation("\(entry.ply)手目: 実戦手一致を正しく表示できません")
                }
            } else {
                guard presentation.status == .recommended else {
                    throw AuditError.violation("\(entry.ply)手目: 安定比較を推奨として提示できません")
                }
            }

            if presentation.status == .recommended || presentation.status == .matched {
                let forbidden = [
                    "この手単独では狙いを断定できません",
                    "この1手だけでは狙いを断定せず",
                    "この一手だけでは狙いを断定せず"
                ]
                if forbidden.contains(where: { presentation.meaning.contains($0) }) {
                    throw AuditError.violation("\(entry.ply)手目: 推奨判断の主説明に単手UNRESOLVED文言が残っています")
                }
            }

            guard !presentation.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !presentation.difference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !presentation.confidenceDetail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw AuditError.violation("\(entry.ply)手目: 判断に必要な説明項目が欠けています")
            }

            if entry.comparisonStable && !entry.continuationStable,
               !presentation.confidenceDetail.contains("参考") {
                throw AuditError.violation("\(entry.ply)手目: 継続PV未安定の注意が表示されません")
            }

            if entry.recommended.moves.count >= 2,
               let captured = firstRecommended.effect.capturedPiece,
               entry.recommended.moves[1].effect.capturedPiece == firstRecommended.effect.pieceAfter,
               entry.recommended.moves[1].effect.destination == firstRecommended.effect.destination {
                guard presentation.meaning.contains(captured.kanji),
                      presentation.meaning.contains("取り返され") else {
                    throw AuditError.violation("\(entry.ply)手目: 即時取り返しを交換手順として説明できません")
                }
            }
        }
        try RecommendationDecisionHDSAudit.validate(entries: entries)
    }
}
