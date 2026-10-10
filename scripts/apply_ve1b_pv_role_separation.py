#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(path: str, old: str, new: str) -> None:
    text = read(path)
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{path}: expected one match, found {count}: {old[:120]!r}")
    write(path, text.replace(old, new, 1))


# 1. Reason/explanation boundary: only confirmed PV is allowed downstream.
path = "iOS/ShogiCoachPoC/ReasonAnalysisViewModel.swift"
replace_once(path, "                let bestPV = deep.bestPV\n", "                let bestPV = deep.confirmedBestPV\n")
replace_once(path, "                let actualMoves = Self.pvMoves(deep.actualPV)\n", "                let actualMoves = Self.pvMoves(deep.confirmedActualPV)\n")
replace_once(path, "                    actualPV: deep.actualPV,\n", "                    actualPV: deep.confirmedActualPV,\n")

# 2. Continuation layer: empty confirmed PV is a valid non-stable state.
path = "iOS/ShogiCoachPoC/ContinuationSimulationViewModel.swift"
replace_once(
    path,
    '''                let recommendedMoves = try Self.normalizedPVMoves(\n                    pv: deep.bestPV,\n                    expectedFirstMove: deep.bestMove,\n                    scoreText: deep.bestScoreText\n                )\n                let actualMoves = try Self.normalizedPVMoves(\n                    pv: deep.actualPV,\n                    expectedFirstMove: deep.actualMove,\n                    scoreText: deep.actualScoreText\n                )\n''',
    '''                let recommendedMoves = try Self.normalizedPVMoves(\n                    pv: deep.confirmedBestPV,\n                    expectedFirstMove: deep.bestMove,\n                    scoreText: deep.bestScoreText,\n                    allowEmptyWhenUnconfirmed: !deep.continuationStable\n                )\n                let actualMoves = try Self.normalizedPVMoves(\n                    pv: deep.confirmedActualPV,\n                    expectedFirstMove: deep.actualMove,\n                    scoreText: deep.actualScoreText,\n                    allowEmptyWhenUnconfirmed: !deep.continuationStable\n                )\n'''
)
replace_once(
    path,
    '''    private static func normalizedPVMoves(\n        pv: String,\n        expectedFirstMove: String,\n        scoreText: String\n    ) throws -> [String] {\n        let parsed = pv.split(whereSeparator: { $0.isWhitespace }).map(String.init)\n        guard let first = parsed.first else {\n            throw ContinuationSimulationError.emptyPV(expectedFirstMove)\n        }\n''',
    '''    private static func normalizedPVMoves(\n        pv: String,\n        expectedFirstMove: String,\n        scoreText: String,\n        allowEmptyWhenUnconfirmed: Bool\n    ) throws -> [String] {\n        let parsed = pv.split(whereSeparator: { $0.isWhitespace }).map(String.init)\n        guard let first = parsed.first else {\n            if allowEmptyWhenUnconfirmed { return [] }\n            throw ContinuationSimulationError.emptyPV(expectedFirstMove)\n        }\n'''
)
replace_once(
    path,
    '''        guard !moves.isEmpty else { return [] }\n''',
    '''        guard !moves.isEmpty else { return [] }\n'''
) if False else None
replace_once(
    path,
    '''        guard let first = moves.first else {\n            return "読み筋を取得できませんでした。"\n        }\n''',
    '''        guard let first = moves.first else {\n            return "確認済みの読み筋はありません。未確認の参考読み筋は説明根拠には使用しません。"\n        }\n'''
)
needle = '''    private static func makeTargetShapeSummary(\n        routeKind: ContinuationRouteKind,\n        initial: BoardSnapshot,\n        final: BoardSnapshot,\n        moves: [ContinuationMoveStep],\n        userSide: ShogiSide\n    ) -> String {\n'''
replacement = needle + '''        guard !moves.isEmpty else {\n            return routeKind == .recommended\n                ? "推奨側の確認済み読み筋はありません（未確認の参考読み筋は説明に使用しません）。"\n                : "実戦側の確認済み読み筋はありません（未確認の参考読み筋は説明に使用しません）。"\n        }\n'''
replace_once(path, needle, replacement)

# 3. Presentation: nil/nil routes must never be interpreted as a match.
path = "iOS/ShogiCoachPoC/RecommendationDecisionPresentation.swift"
text = read(path)
same_start = text.index("        if sameMove {\n")
unstable_start = text.index("        if !entry.comparisonStable {\n", same_start)
after_unstable = text.index("\n\n        let label =", unstable_start)
same_block = text[same_start:unstable_start].rstrip()
unstable_block = text[unstable_start:after_unstable].rstrip()
text = text[:same_start] + unstable_block + "\n\n" + same_block + text[after_unstable:]
write(path, text)

# 4. Policy audit: missing confirmed routes are legal only for non-stable comparisons.
path = "iOS/ShogiCoachPoC/RecommendationDecisionPolicyAudit.swift"
replace_once(
    path,
    '''        for entry in entries {\n            guard let firstRecommended = entry.recommended.moves.first,\n                  let firstActual = entry.actual.moves.first else {\n                throw AuditError.violation("\\(entry.ply)手目: 比較ルートの先頭手がありません")\n            }\n\n            let presentation = RecommendationDecisionPresentation.make(entry: entry)\n            let sameMove = firstRecommended.usi == firstActual.usi\n\n            if !entry.comparisonStable {\n                guard presentation.status == .provisional else {\n                    throw AuditError.violation("\\(entry.ply)手目: 未安定比較を推奨扱いしています")\n                }\n                guard presentation.headline.contains("暫定候補"),\n                      !presentation.headline.contains("推奨") else {\n                    throw AuditError.violation("\\(entry.ply)手目: 比較保留時の見出しが不適切です")\n                }\n                guard presentation.recommendedRouteLabel == "暫定候補" else {\n                    throw AuditError.violation("\\(entry.ply)手目: 比較保留時に推奨ルート表記が残っています")\n                }\n            } else if sameMove {\n                guard presentation.status == .matched else {\n                    throw AuditError.violation("\\(entry.ply)手目: 実戦手一致を正しく表示できません")\n                }\n            } else {\n                guard presentation.status == .recommended else {\n                    throw AuditError.violation("\\(entry.ply)手目: 安定比較を推奨として提示できません")\n                }\n            }\n''',
    '''        for entry in entries {\n            let firstRecommended = entry.recommended.moves.first\n            let firstActual = entry.actual.moves.first\n            let presentation = RecommendationDecisionPresentation.make(entry: entry)\n\n            if !entry.comparisonStable {\n                guard presentation.status == .provisional else {\n                    throw AuditError.violation("\\(entry.ply)手目: 未安定比較を推奨扱いしています")\n                }\n                guard presentation.headline.contains("暫定候補"),\n                      !presentation.headline.contains("推奨") else {\n                    throw AuditError.violation("\\(entry.ply)手目: 比較保留時の見出しが不適切です")\n                }\n                guard presentation.recommendedRouteLabel == "暫定候補" else {\n                    throw AuditError.violation("\\(entry.ply)手目: 比較保留時に推奨ルート表記が残っています")\n                }\n            } else {\n                guard let firstRecommended, let firstActual else {\n                    throw AuditError.violation("\\(entry.ply)手目: 安定比較なのに確認済み比較ルートの先頭手がありません")\n                }\n                if firstRecommended.usi == firstActual.usi {\n                    guard presentation.status == .matched else {\n                        throw AuditError.violation("\\(entry.ply)手目: 実戦手一致を正しく表示できません")\n                    }\n                } else {\n                    guard presentation.status == .recommended else {\n                        throw AuditError.violation("\\(entry.ply)手目: 安定比較を推奨として提示できません")\n                    }\n                }\n            }\n'''
)
replace_once(
    path,
    '''            if entry.recommended.moves.count >= 2,\n               let captured = firstRecommended.effect.capturedPiece,\n''',
    '''            if let firstRecommended,\n               entry.recommended.moves.count >= 2,\n               let captured = firstRecommended.effect.capturedPiece,\n'''
)

# 5. Generic Simulator E2E: encode the confirmed/reference boundary as a negative contract.
path = "iOS/ShogiCoachPoC/SimulatorCIProbe.swift"
replace_once(
    path,
    '''                && !$0.bestPV.isEmpty\n                && !$0.actualPV.isEmpty\n                && $0.actualAnalysisSource.hasPrefix("node-equal-condition")\n''',
    '''                && !$0.referenceBestPV.isEmpty\n                && !$0.referenceActualPV.isEmpty\n                && ($0.comparisonStable\n                    ? (!$0.confirmedBestPV.isEmpty && !$0.confirmedActualPV.isEmpty)\n                    : ($0.confirmedBestPV.isEmpty && $0.confirmedActualPV.isEmpty))\n                && $0.actualAnalysisSource.hasPrefix("node-equal-condition")\n'''
)
replace_once(
    path,
    '''              deepDiagnostic.deepAnalysis?.positions.allSatisfy({\n                  $0.actualAnalysisSource.hasPrefix("node-equal-condition")\n                      && !$0.bestPV.isEmpty\n                      && !$0.actualPV.isEmpty\n                      && $0.analysisAttempts >= 1\n              }) == true else {\n''',
    '''              deepDiagnostic.deepAnalysis?.positions.allSatisfy({ position in\n                  guard let source = deep.entries.first(where: { $0.ply == position.ply }) else {\n                      return false\n                  }\n                  return position.actualAnalysisSource.hasPrefix("node-equal-condition")\n                      && position.bestPV == source.confirmedBestPV\n                      && position.actualPV == source.confirmedActualPV\n                      && (source.comparisonStable\n                          ? (!position.bestPV.isEmpty && !position.actualPV.isEmpty)\n                          : (position.bestPV.isEmpty && position.actualPV.isEmpty))\n                      && position.analysisAttempts >= 1\n              }) == true else {\n'''
)
replace_once(
    path,
    '''        let reasonValid = reason.entries.allSatisfy { entry in\n            let factIDs = Set(entry.facts.map(\\.id))\n''',
    '''        let reasonValid = reason.entries.allSatisfy { entry in\n            guard let source = deep.entries.first(where: { $0.ply == entry.ply }) else {\n                return false\n            }\n            let factIDs = Set(entry.facts.map(\\.id))\n'''
)
replace_once(
    path,
    '''                && validLevels\n                && linkedInterpretation\n                && !entry.bestPV.isEmpty\n                && !entry.actualPV.isEmpty\n''',
    '''                && validLevels\n                && linkedInterpretation\n                && entry.bestPV == source.confirmedBestPV\n                && entry.actualPV == source.confirmedActualPV\n'''
)
replace_once(
    path,
    '''        let continuationValid = continuation.entries.allSatisfy { entry in\n            guard let recommendedFirst = entry.recommended.moves.first,\n                  let actualFirst = entry.actual.moves.first else {\n                return false\n            }\n            return recommendedFirst.usi == deep.entries.first(where: { $0.ply == entry.ply })?.bestMove\n                && actualFirst.usi == deep.entries.first(where: { $0.ply == entry.ply })?.actualMove\n                && entry.recommended.moves.count <= 10\n                && entry.actual.moves.count <= 10\n                && !entry.recommended.developmentBlocks.isEmpty\n                && !entry.actual.developmentBlocks.isEmpty\n                && !entry.recommended.summary.isEmpty\n                && !entry.actual.summary.isEmpty\n                && entry.recommended.moves.allSatisfy {\n                    !$0.label.isEmpty\n                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))\n                        && !$0.factText.isEmpty\n                        && !$0.coachText.isEmpty\n                        && $0.factText != $0.coachText\n                }\n                && entry.actual.moves.allSatisfy {\n                    !$0.label.isEmpty\n                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))\n                        && !$0.factText.isEmpty\n                        && !$0.coachText.isEmpty\n                        && $0.factText != $0.coachText\n                }\n                && !entry.recommended.targetShapeSummary.isEmpty\n                && !entry.actual.targetShapeSummary.isEmpty\n        }\n''',
    '''        let continuationValid = continuation.entries.allSatisfy { entry in\n            guard let source = deep.entries.first(where: { $0.ply == entry.ply }) else {\n                return false\n            }\n            let recommendedRouteValid: Bool\n            if source.confirmedBestPV.isEmpty {\n                recommendedRouteValid = entry.recommended.moves.isEmpty\n                    && entry.recommended.developmentBlocks.isEmpty\n            } else {\n                recommendedRouteValid = entry.recommended.moves.first?.usi == source.bestMove\n                    && !entry.recommended.developmentBlocks.isEmpty\n            }\n            let actualRouteValid: Bool\n            if source.confirmedActualPV.isEmpty {\n                actualRouteValid = entry.actual.moves.isEmpty\n                    && entry.actual.developmentBlocks.isEmpty\n            } else {\n                actualRouteValid = entry.actual.moves.first?.usi == source.actualMove\n                    && !entry.actual.developmentBlocks.isEmpty\n            }\n            return recommendedRouteValid\n                && actualRouteValid\n                && entry.recommended.moves.count <= 10\n                && entry.actual.moves.count <= 10\n                && !entry.recommended.summary.isEmpty\n                && !entry.actual.summary.isEmpty\n                && entry.recommended.moves.allSatisfy {\n                    !$0.label.isEmpty\n                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))\n                        && !$0.factText.isEmpty\n                        && !$0.coachText.isEmpty\n                        && $0.factText != $0.coachText\n                }\n                && entry.actual.moves.allSatisfy {\n                    !$0.label.isEmpty\n                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))\n                        && !$0.factText.isEmpty\n                        && !$0.coachText.isEmpty\n                        && $0.factText != $0.coachText\n                }\n                && !entry.recommended.targetShapeSummary.isEmpty\n                && !entry.actual.targetShapeSummary.isEmpty\n        }\n'''
)
replace_once(
    path,
    '''              continuationDiagnostic.continuationSimulation?.positions.allSatisfy({\n                  !$0.recommended.moves.isEmpty\n                      && !$0.actual.moves.isEmpty\n                      && !$0.recommended.targetShapeSummary.isEmpty\n                      && !$0.actual.targetShapeSummary.isEmpty\n              }) == true else {\n''',
    '''              continuationDiagnostic.continuationSimulation?.positions.allSatisfy({ position in\n                  guard let source = deep.entries.first(where: { $0.ply == position.ply }) else {\n                      return false\n                  }\n                  let recommendedBoundary = source.confirmedBestPV.isEmpty\n                      ? position.recommended.moves.isEmpty\n                      : !position.recommended.moves.isEmpty\n                  let actualBoundary = source.confirmedActualPV.isEmpty\n                      ? position.actual.moves.isEmpty\n                      : !position.actual.moves.isEmpty\n                  return recommendedBoundary\n                      && actualBoundary\n                      && !position.recommended.targetShapeSummary.isEmpty\n                      && !position.actual.targetShapeSummary.isEmpty\n              }) == true,\n              (try? RecommendationDecisionPolicyAudit.validate(entries: continuation.entries)) != nil else {\n'''
)
replace_once(
    path,
    '''            return !item.comparisonStable\n                && presentation.status == .provisional\n                && presentation.status.badgeText == "比較保留"\n                && presentation.headline.contains("暫定候補")\n''',
    '''            return !item.comparisonStable\n                && deepEntry.referenceBestPV.isEmpty == false\n                && deepEntry.referenceActualPV.isEmpty == false\n                && deepEntry.confirmedBestPV.isEmpty\n                && deepEntry.confirmedActualPV.isEmpty\n                && item.recommended.moves.isEmpty\n                && item.actual.moves.isEmpty\n                && presentation.status == .provisional\n                && presentation.status.badgeText == "比較保留"\n                && presentation.headline.contains("暫定候補")\n'''
)

# Syntax/static boundary checks performed before any commit is produced.
checks = {
    "iOS/ShogiCoachPoC/ReasonAnalysisViewModel.swift": ["deep.confirmedBestPV", "deep.confirmedActualPV"],
    "iOS/ShogiCoachPoC/ContinuationSimulationViewModel.swift": ["allowEmptyWhenUnconfirmed", "deep.confirmedBestPV", "deep.confirmedActualPV"],
    "iOS/ShogiCoachPoC/SimulatorCIProbe.swift": ["referenceBestPV", "referenceActualPV", "confirmedBestPV", "confirmedActualPV"],
}
for file, needles in checks.items():
    text = read(file)
    for needle in needles:
        if needle not in text:
            raise SystemExit(f"{file}: missing post-patch marker {needle}")

print("VE1-B PV role separation patch applied")
