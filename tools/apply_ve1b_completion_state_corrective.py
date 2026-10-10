#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly 1 match, found {count}")
    return text.replace(old, new, 1)


def patch(path: str, transform) -> None:
    p = ROOT / path
    text = p.read_text(encoding="utf-8")
    updated = transform(text)
    if updated == text:
        raise SystemExit(f"{path}: no change")
    p.write_text(updated, encoding="utf-8")


def patch_deep(text: str) -> str:
    marker = """@MainActor\nfinal class DeepAnalysisViewModel: ObservableObject {\n"""
    types = r'''struct DeepAnalysisCompletionCounts: Equatable, Sendable {
    let stable: Int
    let unstable: Int
    let unconfirmed: Int

    var total: Int { stable + unstable + unconfirmed }

    static func classify(_ entries: [DeepAnalysisEntry]) -> Self {
        var stable = 0
        var unstable = 0
        var unconfirmed = 0
        for entry in entries {
            switch entry.stabilityState {
            case VE1BStabilityState.stable.rawValue:
                stable += 1
            case VE1BStabilityState.unstable.rawValue:
                unstable += 1
            case VE1BStabilityState.unconfirmed.rawValue,
                 VE1BStabilityState.unknown.rawValue:
                unconfirmed += 1
            default:
                // An unknown future label must never disappear from the accounting.
                unconfirmed += 1
            }
        }
        return .init(stable: stable, unstable: unstable, unconfirmed: unconfirmed)
    }
}

enum DeepAnalysisRunState: Equatable, Sendable {
    case idle
    case running
    case completed(DeepAnalysisCompletionCounts)
    case incomplete(reason: String, completedPositions: Int, expectedPositions: Int)
    case error(message: String)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }

    var completionCounts: DeepAnalysisCompletionCounts? {
        if case .completed(let counts) = self { return counts }
        return nil
    }

    var displayText: String {
        switch self {
        case .idle:
            return "深掘り 未解析"
        case .running:
            return "深掘り 解析中"
        case .completed(let counts):
            return "深掘り 完了（安定 \(counts.stable) / 不安定 \(counts.unstable) / 未確認 \(counts.unconfirmed)）"
        case .incomplete(_, let completed, let expected):
            return "深掘り 未完了（\(completed)/\(expected)局面）"
        case .error(let message):
            return "深掘り エラー: \(message)"
        }
    }
}

@MainActor
final class DeepAnalysisViewModel: ObservableObject {
'''
    text = replace_once(text, marker, types, "deep state types")

    old = '''    @Published private(set) var status = "未解析"\n    @Published private(set) var summary = ""\n'''
    new = '''    @Published private(set) var status = "未解析"\n    @Published private(set) var runState: DeepAnalysisRunState = .idle\n    @Published private(set) var summary = ""\n\n    var displayStatus: String { runState.displayText }\n'''
    text = replace_once(text, old, new, "deep published state")

    old = '''        status = "未解析"\n        summary = ""\n'''
    new = '''        status = "未解析"\n        runState = .idle\n        summary = ""\n'''
    text = replace_once(text, old, new, "deep reset")

    old = '''            status = "深掘り 未PASS"\n            summary = "工程3の全局面解析結果が揃っていません"\n            return\n'''
    new = '''            status = "深掘り 未PASS"\n            let message = "工程3の全局面解析結果が揃っていません"\n            runState = .error(message: message)\n            summary = message\n            return\n'''
    text = replace_once(text, old, new, "deep missing shallow")

    old = '''            status = "深掘り 未PASS"\n            summary = "工程3の診断JSONがありません"\n            return\n'''
    new = '''            status = "深掘り 未PASS"\n            let message = "工程3の診断JSONがありません"\n            runState = .error(message: message)\n            summary = message\n            return\n'''
    text = replace_once(text, old, new, "deep missing diagnostic")

    old = '''            status = "深掘り 未PASS"\n            summary = "重要局面候補を抽出できません"\n            return\n'''
    new = '''            status = "深掘り 未PASS"\n            let message = "重要局面候補を抽出できません"\n            runState = .error(message: message)\n            summary = message\n            return\n'''
    text = replace_once(text, old, new, "deep no selection")

    old = '''        status = "深掘り 準備中"\n        SimulatorStage.mark("deep_start_count_\\(selection.items.count)")\n'''
    new = '''        status = "深掘り 準備中"\n        runState = .running\n        SimulatorStage.mark("deep_start_count_\\(selection.items.count)")\n'''
    text = replace_once(text, old, new, "deep running")

    old = '''            status = "深掘り PASS"\n        } catch {\n'''
    new = '''            let counts = DeepAnalysisCompletionCounts.classify(entries)\n            guard counts.total == entries.count else {\n                throw EngineUSISession.ProbeError.protocolError(\n                    "深掘り状態件数不整合: stable+unstable+unconfirmed=\\(counts.total), entries=\\(entries.count)"\n                )\n            }\n            runState = .completed(counts)\n            status = "深掘り PASS"\n        } catch {\n'''
    text = replace_once(text, old, new, "deep completed")

    old = '''            if let failure = error as? VE1BNodeComparisonFailure {\n                incompleteSearchEvidence = failure.evidence\n                status = "深掘り 未PASS（解析未完了）"\n            } else {\n                status = "深掘り 未PASS"\n            }\n'''
    new = '''            if let failure = error as? VE1BNodeComparisonFailure {\n                incompleteSearchEvidence = failure.evidence\n                status = "深掘り 未PASS（解析未完了）"\n                runState = .incomplete(\n                    reason: error.localizedDescription,\n                    completedPositions: analyzedEntries.count,\n                    expectedPositions: selection.items.count\n                )\n            } else {\n                status = "深掘り 未PASS"\n                runState = .error(message: error.localizedDescription)\n            }\n'''
    text = replace_once(text, old, new, "deep catch classification")

    old = '''            status = "深掘り 未PASS"\n            SimulatorStage.mark("ve1b_search_evidence_json_error_\\(error.localizedDescription)")\n'''
    new = '''            status = "深掘り 未PASS"\n            runState = .error(message: evidenceError)\n            SimulatorStage.mark("ve1b_search_evidence_json_error_\\(error.localizedDescription)")\n'''
    text = replace_once(text, old, new, "deep evidence export error")

    old = '''            status = "深掘り 未PASS"\n            summary += "\\n診断JSON更新失敗: \\(message)"\n            SimulatorStage.mark("deep_diagnostic_json_error_\\(message)")\n'''
    new = '''            status = "深掘り 未PASS"\n            runState = .error(message: "診断JSON更新失敗: \\(message)")\n            summary += "\\n診断JSON更新失敗: \\(message)"\n            SimulatorStage.mark("deep_diagnostic_json_error_\\(message)")\n'''
    text = replace_once(text, old, new, "deep diagnostic export error")

    old = '''        if status == "深掘り PASS" {\n            SimulatorStage.mark("deep_complete_\\(entries.count)")\n        }\n'''
    new = '''        if case .completed(let counts) = runState {\n            SimulatorStage.mark(\n                "deep_complete_\\(entries.count)_stable_\\(counts.stable)_unstable_\\(counts.unstable)_unconfirmed_\\(counts.unconfirmed)"\n            )\n        }\n'''
    text = replace_once(text, old, new, "deep completion marker")

    old = '''        let stable = entries.filter(\\.comparisonStable).count\n        let continuationStable = entries.filter(\\.continuationStable).count\n'''
    new = '''        let counts = DeepAnalysisCompletionCounts.classify(entries)\n        let continuationStable = entries.filter(\\.continuationStable).count\n'''
    text = replace_once(text, old, new, "deep summary counts")

    old = '''            "search series: cold MultiPV each discovery tier -> cold searchmoves -> warm fixed-pair increasing tiers",\n            "comparison stable: \\(stable)/\\(entries.count)",\n            "continuation stable: \\(continuationStable)/\\(entries.count)",\n'''
    new = '''            "search series: cold MultiPV each discovery tier -> independent cold MultiPV1 searchmoves for recommended and actual at every tier",\n            "comparison stable: \\(counts.stable)/\\(entries.count)",\n            "comparison unstable: \\(counts.unstable)/\\(entries.count)",\n            "comparison unconfirmed: \\(counts.unconfirmed)/\\(entries.count)",\n            "continuation stable: \\(continuationStable)/\\(entries.count)",\n'''
    text = replace_once(text, old, new, "deep summary wording")
    return text


def patch_content(text: str) -> str:
    old = '''                            guard deep.status == "深掘り PASS" else {\n                                analysisStatus = deep.status\n                                return\n                            }\n'''
    new = '''                            guard deep.runState.isCompleted else {\n                                analysisStatus = deep.displayStatus\n                                return\n                            }\n'''
    text = replace_once(text, old, new, "content deep gate")

    old = '''                    Text(analysisStatus)\n                        .font(.headline)\n\n                    if let searchEvidenceURL = deep.searchEvidenceURL {\n'''
    new = '''                    Text(analysisStatus)\n                        .font(.headline)\n\n                    if deep.runState != .idle {\n                        Text(deep.displayStatus)\n                            .font(.footnote)\n                            .foregroundStyle(.secondary)\n                    }\n\n                    if let searchEvidenceURL = deep.searchEvidenceURL {\n'''
    text = replace_once(text, old, new, "content deep display")
    return text


def patch_simulator(text: str) -> str:
    marker = '''    static func runIfRequested() async {\n'''
    helpers = r'''    private static func deepCompletionContractPass(
        state: DeepAnalysisRunState,
        expectedPositions: Int,
        entryCount: Int,
        attemptCounts: [Int],
        evidenceCounts: [Int]
    ) -> Bool {
        guard case .completed(let counts) = state,
              counts.total == expectedPositions,
              entryCount == expectedPositions,
              attemptCounts.count == expectedPositions,
              evidenceCounts.count == expectedPositions,
              attemptCounts.allSatisfy({ $0 == 9 }),
              evidenceCounts.allSatisfy({ $0 == 9 }) else {
            return false
        }
        return true
    }

    private static func deepCompletionNegativeContractPasses() -> Bool {
        let abortRejected = !deepCompletionContractPass(
            state: .incomplete(
                reason: "safety_aborted",
                completedPositions: 2,
                expectedPositions: 3
            ),
            expectedPositions: 3,
            entryCount: 2,
            attemptCounts: [9, 9],
            evidenceCounts: [9, 9]
        )
        let missingEvidenceRejected = !deepCompletionContractPass(
            state: .completed(.init(stable: 1, unstable: 1, unconfirmed: 1)),
            expectedPositions: 3,
            entryCount: 3,
            attemptCounts: [9, 9, 9],
            evidenceCounts: [9, 8, 9]
        )
        let countMismatchRejected = !deepCompletionContractPass(
            state: .completed(.init(stable: 1, unstable: 1, unconfirmed: 0)),
            expectedPositions: 3,
            entryCount: 3,
            attemptCounts: [9, 9, 9],
            evidenceCounts: [9, 9, 9]
        )
        return abortRejected && missingEvidenceRejected && countMismatchRejected
    }

    static func runIfRequested() async {
'''
    text = replace_once(text, marker, helpers, "simulator completion helpers")

    old = '''                && $0.actualAnalysisSource.hasPrefix("equal-condition")\n'''
    new = '''                && $0.actualAnalysisSource.hasPrefix("node-equal-condition")\n'''
    # The main deep validity block has one occurrence; later fixtures intentionally retain legacy strings.
    text = replace_once(text, old, new, "simulator main node source")

    old = '''        guard deepStatus == "深掘り PASS",\n              deepCount == 3,\n              deepValid,\n'''
    new = '''        let deepCompletionValid = deepCompletionContractPass(\n            state: deep.runState,\n            expectedPositions: 3,\n            entryCount: deepCount,\n            attemptCounts: deep.entries.map(\\.analysisAttempts),\n            evidenceCounts: deep.entries.map { $0.searchEvidence.count }\n        )\n        let deepNegativeContractValid = deepCompletionNegativeContractPasses()\n        let nonStableDeepEntries = deep.entries.filter { $0.stabilityState != VE1BStabilityState.stable.rawValue }\n        let nonStableSuppressionValid = nonStableDeepEntries.allSatisfy {\n            !$0.comparisonStable && $0.actualLossCp == nil\n        }\n        guard deepCompletionValid,\n              deepNegativeContractValid,\n              deepCount == 3,\n              deepValid,\n              nonStableSuppressionValid,\n'''
    text = replace_once(text, old, new, "simulator deep structured gate")

    old = '''                      && $0.actualAnalysisSource.hasPrefix("equal-condition")\n'''
    new = '''                      && $0.actualAnalysisSource.hasPrefix("node-equal-condition")\n'''
    text = replace_once(text, old, new, "simulator diagnostic node source")

    old = '''        SimulatorStage.mark("board_display_pass")\n\n        let reason = ReasonAnalysisViewModel()\n'''
    new = '''        let boardCarriesNonStable = Set(boardReview.entries.map(\\.ply)).isSuperset(\n            of: Set(nonStableDeepEntries.map(\\.ply))\n        )\n        guard boardCarriesNonStable else {\n            writeReport([\n                "stage=board_display_failed",\n                "board_display_status=FAIL",\n                "board_display_error=non-stable positions were dropped"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("board_display_nonstable_dropped")\n            fflush(stdout)\n            exit(8)\n        }\n        SimulatorStage.mark("board_display_pass")\n\n        let reason = ReasonAnalysisViewModel()\n'''
    text = replace_once(text, old, new, "simulator board nonstable propagation")

    old = '''        SimulatorStage.mark("reason_analysis_pass")\n\n        let continuation = ContinuationSimulationViewModel()\n'''
    new = '''        let reasonNonStableValid = nonStableDeepEntries.allSatisfy { deepEntry in\n            guard let reasonEntry = reason.entries.first(where: { $0.ply == deepEntry.ply }) else { return false }\n            return reasonEntry.actualLossCp == nil\n                && reasonEntry.facts.contains(where: {\n                    $0.kind == "score_comparison"\n                        && $0.text.contains("評価損失は断定しない")\n                })\n        }\n        guard reasonNonStableValid else {\n            writeReport([\n                "stage=reason_analysis_failed",\n                "reason_status=FAIL",\n                "reason_error=non-stable loss suppression/provisional wording missing"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("reason_nonstable_contract_failed")\n            fflush(stdout)\n            exit(10)\n        }\n        SimulatorStage.mark("reason_analysis_pass")\n\n        let continuation = ContinuationSimulationViewModel()\n'''
    text = replace_once(text, old, new, "simulator reason nonstable propagation")

    old = '''        SimulatorStage.mark("continuation_simulation_pass")\n\n        let phaseReview = PhaseReviewViewModel()\n'''
    new = '''        let continuationNonStableValid = nonStableDeepEntries.allSatisfy { deepEntry in\n            guard let item = continuation.entries.first(where: { $0.ply == deepEntry.ply }) else { return false }\n            let presentation = RecommendationDecisionPresentation.make(entry: item)\n            return !item.comparisonStable\n                && presentation.status == .provisional\n                && presentation.badgeText == "比較保留"\n                && presentation.headline.contains("暫定候補")\n        }\n        guard continuationNonStableValid else {\n            writeReport([\n                "stage=continuation_simulation_failed",\n                "continuation_status=FAIL",\n                "continuation_error=non-stable provisional presentation missing"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("continuation_nonstable_contract_failed")\n            fflush(stdout)\n            exit(15)\n        }\n        SimulatorStage.mark("continuation_simulation_pass")\n\n        let phaseReview = PhaseReviewViewModel()\n'''
    text = replace_once(text, old, new, "simulator continuation nonstable propagation")

    old = '''        SimulatorStage.mark("reason_unstable_pass")\n\n        let recaptureDeepEntry = DeepAnalysisEntry(\n'''
    new = '''        let unstableContinuation = ContinuationSimulationViewModel()\n        unstableContinuation.prepare(\n            game: unstableGame,\n            deepEntries: [unstableDeepEntry],\n            reasonEntries: unstableReason.entries,\n            diagnosticURL: unstableReason.diagnosticURL\n        )\n        guard unstableContinuation.status == "展開シミュレーション PASS",\n              let unstableContinuationEntry = unstableContinuation.entries.first,\n              !unstableContinuationEntry.comparisonStable else {\n            writeReport([\n                "stage=reason_unstable_failed",\n                "reason_unstable_status=FAIL",\n                "reason_unstable_error=unstable continuation was dropped or promoted"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("reason_unstable_continuation_failed")\n            fflush(stdout)\n            exit(12)\n        }\n        let unstablePresentation = RecommendationDecisionPresentation.make(entry: unstableContinuationEntry)\n        let unstableHDSReport = RecommendationDecisionHDSAudit.evaluate(entries: unstableContinuation.entries)\n        guard unstablePresentation.status == .provisional,\n              unstablePresentation.badgeText == "比較保留",\n              unstablePresentation.headline.contains("暫定候補"),\n              unstableHDSReport.passed else {\n            writeReport([\n                "stage=reason_unstable_failed",\n                "reason_unstable_status=FAIL",\n                "reason_unstable_error=provisional/HDS contract missing"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("reason_unstable_hds_failed")\n            fflush(stdout)\n            exit(12)\n        }\n        SimulatorStage.mark("reason_unstable_pass")\n\n        let recaptureDeepEntry = DeepAnalysisEntry(\n'''
    text = replace_once(text, old, new, "simulator unstable HDS path")

    old = '''        guard terminalDeep.status == "深掘り PASS",\n              terminalDeep.entries.count == 1,\n'''
    new = '''        guard terminalDeep.runState.isCompleted,\n              terminalDeep.entries.count == 1,\n'''
    text = replace_once(text, old, new, "simulator terminal structured state")

    old = '''              terminalEntry.actualAnalysisSource.hasPrefix("equal-condition"),\n'''
    new = '''              terminalEntry.actualAnalysisSource.hasPrefix("node-equal-condition"),\n'''
    text = replace_once(text, old, new, "simulator terminal source")

    # HDS live must preserve any unstable/unconfirmed positions without making a ply identity a truth label.
    old = '''        // Live replay verifies that the real positions can flow through the current engine\n'''
    new = '''        let hdsLiveNonStablePlies = Set(\n            hdsDeep.entries.filter { !$0.comparisonStable }.map(\\.ply)\n        )\n        let hdsLiveNonStableValid = hdsLiveNonStablePlies.allSatisfy { ply in\n            guard let deepEntry = hdsDeep.entries.first(where: { $0.ply == ply }),\n                  let item = hdsContinuation.entries.first(where: { $0.ply == ply }) else { return false }\n            let presentation = RecommendationDecisionPresentation.make(entry: item)\n            return deepEntry.actualLossCp == nil\n                && !item.comparisonStable\n                && presentation.status == .provisional\n        }\n        guard hdsLiveNonStableValid else {\n            writeReport([\n                "stage=hds_m_failed",\n                "hds_m_status=FAIL",\n                "hds_m_error=live unstable propagation"\n            ].joined(separator: "\\n") + "\\n")\n            SimulatorStage.mark("hds_m_live_unstable_propagation_failed")\n            fflush(stdout)\n            exit(35)\n        }\n\n        // Live replay verifies that the real positions can flow through the current engine\n'''
    text = replace_once(text, old, new, "simulator hds live nonstable")

    old = '''            "deep_status=\\(deepStatus)",\n            "deep_count=\\(deepCount)",\n'''
    new = '''            "deep_status=\\(deepStatus)",\n            "deep_display_status=\\(deep.displayStatus)",\n            "deep_count=\\(deepCount)",\n            "deep_stable_count=\\(deep.runState.completionCounts?.stable ?? -1)",\n            "deep_unstable_count=\\(deep.runState.completionCounts?.unstable ?? -1)",\n            "deep_unconfirmed_count=\\(deep.runState.completionCounts?.unconfirmed ?? -1)",\n            "deep_negative_contract_status=PASS",\n            "deep_nonstable_suppression_status=PASS",\n            "deep_stability_by_ply=\\(deep.entries.map { "#\\($0.ply):\\($0.stabilityState):\\($0.instabilityReasons.joined(separator: ","))" }.joined(separator: ";"))",\n'''
    text = replace_once(text, old, new, "simulator report structured state")
    return text


def patch_migration_doc(text: str) -> str:
    addition = r'''

## Completed / incomplete / error state contract

Generic E2E and the app UI must not use a semantic stability label as an execution-success label.
`DeepAnalysisViewModel` therefore exposes a structured run state:

- `completed`: all selected searches/evidence completed. The state carries separate `stable`, `unstable`, and `unconfirmed` counts; their sum must equal the completed-position count.
- `incomplete`: an operational search did not complete (for example safety abort or missing completed evidence). This is never accepted as a successful E2E completion.
- `error`: input/protocol/export/diagnostic failure.

A completed `unstable` or `unconfirmed` position is not dropped. It must continue through board review, reason analysis, continuation simulation and HDS presentation. `actualLossCp` remains suppressed and the decision presentation remains provisional/hold. Generic E2E records per-ply state/reason codes for audit but does not require any particular historical ply to be `stable`.

The generic E2E contains explicit negative structural checks proving that the completion gate rejects: (1) incomplete/aborted state, (2) fewer than 9 search-evidence records for any expected position, and (3) state-count totals that do not equal the expected position count. These are structural failures, not semantic expected labels.
'''
    if "## Completed / incomplete / error state contract" in text:
        raise SystemExit("migration doc already patched")
    return text.rstrip() + addition + "\n"


def patch_b6_doc(text: str) -> str:
    old = '''- fixed-pair confirmation: `50,000 -> 100,000 -> 200,000` nodes, fresh cold boundary before the series, then the documented within-series TT policy;\n- nine search invocations per analyzed position under the current comparison design;\n'''
    new = '''- independent comparison: at each `50,000 -> 100,000 -> 200,000` tier, measure the recommended move and actual move separately with MultiPV 1, one `searchmoves` move, and a fresh cold TT boundary before **each** invocation; no warm pair series is permitted;\n- nine search invocations per analyzed position under the current comparison design (3 cold unrestricted discovery + 3 cold recommended + 3 cold actual);\n'''
    return replace_once(text, old, new, "B6 current cold comparison contract")


patch("iOS/ShogiCoachPoC/DeepAnalysisViewModel.swift", patch_deep)
patch("iOS/ShogiCoachPoC/ContentView.swift", patch_content)
patch("iOS/ShogiCoachPoC/SimulatorCIProbe.swift", patch_simulator)
patch("Build19/BUILD19_VE1_B_GENERIC_E2E_MIGRATION_20261010.md", patch_migration_doc)
patch("Build19/BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md", patch_b6_doc)

print("VE1-B completion-state corrective patch applied")
