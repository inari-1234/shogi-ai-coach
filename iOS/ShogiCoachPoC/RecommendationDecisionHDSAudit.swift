import Foundation

enum RecommendationDecisionHDSAudit {
    enum Gate: String, CaseIterable {
        case choice = "G1_CHOICE"
        case contrast = "G2_CONTRAST"
        case mechanism = "G3_MECHANISM"
        case horizon = "G4_HORIZON"
        case evidence = "G5_EVIDENCE"
        case uncertainty = "G6_UNCERTAINTY"
        case learning = "G7_LEARNING"
    }

    struct GateResult {
        let gate: Gate
        let passed: Bool
        let detail: String
    }

    struct PositionResult {
        let ply: Int
        let status: RecommendationDecisionPresentation.Status
        let gates: [GateResult]

        var passed: Bool { gates.allSatisfy(\.passed) }
        var failedGates: [Gate] { gates.filter { !$0.passed }.map(\.gate) }
    }

    struct Report {
        let positions: [PositionResult]
        var passed: Bool { !positions.isEmpty && positions.allSatisfy(\.passed) }
    }

    enum AuditError: Error, LocalizedError {
        case violation(String)

        var errorDescription: String? {
            switch self {
            case .violation(let message): return message
            }
        }
    }

    static func evaluate(entries: [ContinuationSimulationEntry]) -> Report {
        Report(positions: entries.map(evaluate(entry:)))
    }

    static func validate(entries: [ContinuationSimulationEntry]) throws {
        let report = evaluate(entries: entries)
        guard !report.positions.isEmpty else {
            throw AuditError.violation("HDS-M: 評価対象局面がありません")
        }
        for position in report.positions where !position.passed {
            let failed = position.failedGates.map(\.rawValue).joined(separator: ",")
            let details = position.gates
                .filter { !$0.passed }
                .map { "\($0.gate.rawValue)=\($0.detail)" }
                .joined(separator: " / ")
            throw AuditError.violation("\(position.ply)手目 HDS-M FAIL [\(failed)]: \(details)")
        }
    }

    private static func evaluate(entry: ContinuationSimulationEntry) -> PositionResult {
        let presentation = RecommendationDecisionPresentation.make(entry: entry)
        let firstRecommended = entry.recommended.moves.first
        let firstActual = entry.actual.moves.first
        let sameMove = firstRecommended?.usi == firstActual?.usi
        let recommendedLabel = firstRecommended?.label ?? ""
        let actualLabel = firstActual?.label ?? ""

        let choicePass: Bool
        if !entry.comparisonStable {
            choicePass = presentation.status == .provisional
                && presentation.headline.contains("暫定候補")
                && !presentation.headline.contains("推奨")
        } else if sameMove {
            choicePass = presentation.status == .matched
        } else {
            choicePass = presentation.status == .recommended
                && presentation.headline.contains("推奨")
        }

        let contrastHasBoth = sameMove
            ? presentation.difference.contains(recommendedLabel)
            : presentation.difference.contains(recommendedLabel)
                && presentation.difference.contains(actualLabel)
        let contrastPass = !presentation.difference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && contrastHasBoth
            && !isScoreOnly(presentation.difference)

        let unresolvedPhrases = [
            "この手単独では狙いを断定できません",
            "この1手だけでは狙いを断定せず",
            "この一手だけでは狙いを断定せず"
        ]
        let mechanismPass = !presentation.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !unresolvedPhrases.contains(where: { presentation.meaning.contains($0) })
            && (recommendedLabel.isEmpty || presentation.meaning.contains(recommendedLabel) || hasConcreteMechanism(presentation.meaning))
            && !isScoreOnly(presentation.meaning)

        let horizonPass: Bool
        if !entry.comparisonStable {
            horizonPass = presentation.horizon.contains("確定しません")
                || presentation.horizon.contains("安定していない")
        } else if entry.continuationStable {
            horizonPass = !presentation.horizon.isEmpty
                && !presentation.horizon.contains("確定しません")
        } else {
            horizonPass = presentation.horizon.contains("未安定")
                && (presentation.horizon.contains("直後") || presentation.horizon.contains("最初"))
        }

        let combinedClaims = [
            presentation.meaning,
            presentation.difference,
            presentation.horizon
        ].joined(separator: " ")
        let absoluteOverclaim = ["必ず", "絶対", "確実に"].contains { combinedClaims.contains($0) }
        let provisionalOverclaim = !entry.comparisonStable
            && (presentation.headline.contains("推奨")
                || presentation.difference.contains("推奨候補")
                || presentation.recommendedRouteLabel == "推奨")
        let evidencePass = !absoluteOverclaim
            && !provisionalOverclaim
            && !isScoreOnly(presentation.difference)

        let uncertaintyPass: Bool
        if !entry.comparisonStable {
            uncertaintyPass = presentation.status == .provisional
                && presentation.confidenceTitle == "比較判定を保留"
                && (presentation.confidenceDetail.contains("安定していません")
                    || presentation.confidenceDetail.contains("未安定"))
        } else {
            uncertaintyPass = presentation.status != .provisional
                && presentation.confidenceTitle != "比較判定を保留"
        }

        let learningPass = !presentation.learningCue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ["確認", "読む", "読み", "比較", "候補"].contains { presentation.learningCue.contains($0) }
            && !isMoveAnswerOnly(presentation.learningCue, recommendedLabel: recommendedLabel)

        let results = [
            GateResult(gate: .choice, passed: choicePass, detail: choicePass ? "decision status is actionable" : "推奨/暫定/一致の状態が比較安定性と一致しません"),
            GateResult(gate: .contrast, passed: contrastPass, detail: contrastPass ? "recommended/actual contrast is explicit" : "実戦手との比較が明示されていないか評価値だけです"),
            GateResult(gate: .mechanism, passed: mechanismPass, detail: mechanismPass ? "concrete move mechanism is present" : "その手が何をするかを具体的に説明できていません"),
            GateResult(gate: .horizon, passed: horizonPass, detail: horizonPass ? "difference horizon matches stability" : "差がいつ現れるかとPV安定性の関係が不十分です"),
            GateResult(gate: .evidence, passed: evidencePass, detail: evidencePass ? "claims stay within evidence boundary" : "根拠を超える断定または評価値依存があります"),
            GateResult(gate: .uncertainty, passed: uncertaintyPass, detail: uncertaintyPass ? "uncertainty is calibrated" : "比較不安定性と表示上の確信度が一致しません"),
            GateResult(gate: .learning, passed: learningPass, detail: learningPass ? "transfer cue is present" : "次の類似局面で使える判断ルールがありません")
        ]
        return PositionResult(ply: entry.ply, status: presentation.status, gates: results)
    }

    private static func hasConcreteMechanism(_ text: String) -> Bool {
        let tokens = [
            "取", "交換", "取り返", "王手", "打", "成", "前へ", "後に", "その後", "直後", "PV", "手順", "盤面差"
        ]
        return tokens.contains { text.contains($0) }
    }

    private static func isScoreOnly(_ text: String) -> Bool {
        guard text.contains("評価") || text.contains("cp") || text.contains("点") else { return false }
        return !hasConcreteMechanism(text)
            && !text.contains("実戦")
            && !text.contains("応手")
            && !text.contains("形")
    }

    private static func isMoveAnswerOnly(_ text: String, recommendedLabel: String) -> Bool {
        guard !recommendedLabel.isEmpty, text.contains(recommendedLabel) else { return false }
        let transferTokens = ["確認", "読む", "読み", "比較", "候補", "とき", "場合"]
        return !transferTokens.contains { text.contains($0) }
    }
}
