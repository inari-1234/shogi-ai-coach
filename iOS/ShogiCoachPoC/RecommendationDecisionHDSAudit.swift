import Foundation

struct RecommendationDecisionHDSGateResult: Equatable {
    let code: String
    let name: String
    let passed: Bool
    let detail: String
}

struct RecommendationDecisionHDSReport: Equatable {
    let ply: Int
    let gates: [RecommendationDecisionHDSGateResult]
    let candidateLevel: String

    var passed: Bool { gates.allSatisfy(\.passed) }

    var failedCodes: [String] {
        gates.filter { !$0.passed }.map(\.code)
    }

    var summaryLine: String {
        let state = passed ? "PASS" : "FAIL"
        let failures = failedCodes.isEmpty ? "none" : failedCodes.joined(separator: ",")
        return "ply=\(ply) hds_m=\(state) level=\(candidateLevel) failed=\(failures)"
    }
}

enum RecommendationDecisionHDSAudit {
    enum AuditError: Error, LocalizedError {
        case violation(String)

        var errorDescription: String? {
            switch self {
            case .violation(let message): return message
            }
        }
    }

    static func evaluate(entry: ContinuationSimulationEntry) -> RecommendationDecisionHDSReport {
        let presentation = RecommendationDecisionPresentation.make(entry: entry)
        let firstRecommended = entry.recommended.moves.first
        let firstActual = entry.actual.moves.first
        let sameMove = firstRecommended?.usi == firstActual?.usi

        let g1 = gate(
            "G1",
            "Choice",
            choiceIsConsistent(
                entry: entry,
                presentation: presentation,
                sameMove: sameMove
            ),
            "推奨・一致・比較保留の状態が比較安定性と一致する"
        )

        let contrastOK: Bool
        if presentation.status == .matched {
            contrastOK = sameMove == true && presentation.headline.contains("一致")
        } else if presentation.status == .provisional {
            contrastOK = containsAny(
                presentation.difference,
                ["保留", "未安定", "安定していません", "断定"]
            )
        } else {
            contrastOK = !presentation.difference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && containsAny(presentation.difference, ["実戦", "最善", "候補", "比較", "PV"])
                && !isScoreOnly(presentation.difference)
        }
        let g2 = gate(
            "G2",
            "Contrast",
            contrastOK,
            "実戦手・別候補との差、または比較保留の理由を具体的に説明する"
        )

        let primary = presentation.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        let forbiddenUnresolved = [
            "この手単独では狙いを断定できません",
            "この1手だけでは狙いを断定せず",
            "この一手だけでは狙いを断定せず"
        ]
        let mechanismOK = !primary.isEmpty
            && !forbiddenUnresolved.contains(where: { primary.contains($0) })
            && containsAny(
                primary,
                ["取", "交換", "前へ", "移動", "王手", "守", "攻", "PV", "手順", "盤面", "応手", "同じ駒"]
            )
        let g3 = gate(
            "G3",
            "Mechanism",
            mechanismOK,
            "評価値ではなく盤面変化・交換・手順などの具体的機構を示す"
        )

        let horizonText = presentation.differenceHorizon.trimmingCharacters(in: .whitespacesAndNewlines)
        let horizonOK = !horizonText.isEmpty
            && (entry.continuationStable
                || presentation.status == .provisional
                || containsAny(horizonText, ["参考", "短い", "確定", "未安定"]))
        let g4 = gate(
            "G4",
            "Horizon",
            horizonOK,
            "意味のある差が現れる範囲を示し、未安定PVを越えて断定しない"
        )

        let evidenceText = presentation.evidenceBasis.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidenceOK = !evidenceText.isEmpty
            && !isScoreOnly(presentation.difference)
            && containsAny(evidenceText, ["比較", "PV", "盤面", "理由解析", "根拠"])
        let g5 = gate(
            "G5",
            "Evidence",
            evidenceOK,
            "ReasonAnalysis/PVの根拠範囲内に留まり、score-onlyを因果理由にしない"
        )

        let combined = [
            presentation.headline,
            presentation.meaning,
            presentation.difference,
            presentation.confidenceDetail,
            presentation.differenceHorizon
        ].joined(separator: " ")
        let forcedOverclaim = containsAny(combined, ["必ずこの応手", "必ず応じ", "強制的にこの手", "相手は必ず"])
        let uncertaintyOK = choiceIsConsistent(
            entry: entry,
            presentation: presentation,
            sameMove: sameMove
        )
            && !forcedOverclaim
            && (entry.comparisonStable || presentation.status == .provisional)
            && (entry.continuationStable
                || containsAny(presentation.confidenceDetail + " " + horizonText, ["参考", "保留", "未安定", "確定しません"]))
        let g6 = gate(
            "G6",
            "Uncertainty",
            uncertaintyOK,
            "不安定比較を推奨と断定せず、観測PVの相手応手を強制手と過剰表現しない"
        )

        let learning = presentation.learningCue.trimmingCharacters(in: .whitespacesAndNewlines)
        let learningOK = !learning.isEmpty
            && !learning.hasPrefix("この手を覚")
            && !learning.hasPrefix("推奨手を覚")
            && containsAny(learning, ["確認", "読む", "比較", "候補", "見る", "確かめ"])
        let g7 = gate(
            "G7",
            "Learning",
            learningOK,
            "手そのものの暗記ではなく、次の類似局面で使える確認手順を残す"
        )

        let gates = [g1, g2, g3, g4, g5, g6, g7]
        let firstSixPass = gates.prefix(6).allSatisfy(\.passed)
        let level: String
        if gates.allSatisfy(\.passed) {
            level = "HDS-2-candidate"
        } else if firstSixPass {
            level = "HDS-1-candidate"
        } else {
            level = "HDS-0-only"
        }

        return .init(ply: entry.ply, gates: gates, candidateLevel: level)
    }

    static func validate(entries: [ContinuationSimulationEntry]) throws -> [RecommendationDecisionHDSReport] {
        let reports = entries.map(evaluate)
        if let failed = reports.first(where: { !$0.passed }) {
            throw AuditError.violation(
                "\(failed.ply)手目: HDS-M \(failed.failedCodes.joined(separator: ",")) FAIL"
            )
        }
        return reports
    }

    private static func gate(
        _ code: String,
        _ name: String,
        _ passed: Bool,
        _ detail: String
    ) -> RecommendationDecisionHDSGateResult {
        .init(code: code, name: name, passed: passed, detail: detail)
    }

    private static func choiceIsConsistent(
        entry: ContinuationSimulationEntry,
        presentation: RecommendationDecisionPresentation,
        sameMove: Bool?
    ) -> Bool {
        if !entry.comparisonStable {
            return presentation.status == .provisional
                && presentation.headline.contains("暫定候補")
                && !presentation.headline.contains("推奨")
        }
        if sameMove == true {
            return presentation.status == .matched
        }
        return presentation.status == .recommended
    }

    private static func isScoreOnly(_ text: String) -> Bool {
        let scoreSignals = containsAny(text, ["cp", "評価値", "評価差", "評価損失", "スコア"])
        guard scoreSignals else { return false }
        let mechanismSignals = containsAny(
            text,
            ["PV", "実戦", "最善", "応手", "取", "交換", "手順", "盤面", "許", "展開", "一致", "保留", "安定"]
        )
        return !mechanismSignals
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains(where: { text.contains($0) })
    }
}
