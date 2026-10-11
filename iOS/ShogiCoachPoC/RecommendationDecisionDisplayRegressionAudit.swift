import Foundation

enum RecommendationDecisionDisplayRegressionAudit {
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
            try validatePromotionLabels(entry: entry)
            try validateCoachTextBinding(entry: entry)
        }
    }

    private static func validatePromotionLabels(
        entry: ContinuationSimulationEntry
    ) throws {
        let moves = entry.recommended.moves + entry.actual.moves
        for move in moves where move.effect.promotes {
            let expectedSuffix = move.effect.pieceBefore.kanji + "成"
            guard move.label.hasSuffix(expectedSuffix) else {
                throw AuditError.violation(
                    "\(entry.ply)手目 DISPLAY_REGRESSION: 成り手の表記が不正です（\(move.usi): \(move.label)、期待末尾 \(expectedSuffix)）"
                )
            }

            if move.effect.pieceAfter != move.effect.pieceBefore {
                let invalidSuffix = move.effect.pieceAfter.kanji + "成"
                guard !move.label.hasSuffix(invalidSuffix) else {
                    throw AuditError.violation(
                        "\(entry.ply)手目 DISPLAY_REGRESSION: 成った後の駒名に『成』を重ねています（\(move.label)）"
                    )
                }
            }
        }
    }

    private static func validateCoachTextBinding(
        entry: ContinuationSimulationEntry
    ) throws {
        guard let first = entry.recommended.moves.first else { return }
        let presentation = RecommendationDecisionPresentation.make(entry: entry)
        guard !isGenericCoachText(first.coachText),
              presentation.meaning.contains(first.coachText) else {
            return
        }

        guard presentation.meaning.contains(first.label) else {
            throw AuditError.violation(
                "\(entry.ply)手目 DISPLAY_REGRESSION: coachText由来の意味説明に候補手名がありません（\(first.label)）"
            )
        }
    }

    private static func isGenericCoachText(_ text: String) -> Bool {
        text.contains("この1手だけでは狙いを断定せず")
            || text.contains("この一手だけでは狙いを断定せず")
    }
}
