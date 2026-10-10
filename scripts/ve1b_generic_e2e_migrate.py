#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected exactly one match, got {count}")
    return text.replace(old, new, 1)

# 1) Context must reuse authoritative Deep VE1-B evidence; no second movetime search.
context_path = ROOT / "iOS/ShogiCoachPoC/ContextAnalysisViewModel.swift"
context = context_path.read_text()
context = replace_once(
    context,
    '    static let refinementPolicy = "selective-low-unresolved-v1"',
    '    static let refinementPolicy = "ve1b-deep-authority-reuse-v2"',
    "context policy",
)
context = replace_once(
    context,
    '    private let refinementSession = EngineUSISession()\n',
    '',
    "context legacy refinement session",
)
start_marker = '            if !refinementCandidatePlies.isEmpty {\n'
end_marker = '\n            resolved = Self.applyingConceptRepetitionPolicy(to: resolved)'
start = context.index(start_marker)
end = context.index(end_marker, start)
context = (
    context[:start]
    + '            if !refinementCandidatePlies.isEmpty {\n'
      '                // DeepAnalysisViewModel has already produced the sole VE1-B engine authority.\n'
      '                // Re-evaluate the context contract from that evidence; never launch a\n'
      '                // second movetime search with a competing stability definition.\n'
      '                refinementCompletedPlies = refinementCandidatePlies\n'
      '            }\n'
    + context[end:]
)
context = replace_once(
    context,
    '            usedAdditionalEngineSearch = !refinementCompletedPlies.isEmpty',
    '            usedAdditionalEngineSearch = false',
    "context additional search flag",
)
context = replace_once(
    context,
    '                ? "追加探索対象なし"\n                : "追加探索 \\(refinementCompletedPlies.count)/\\(refinementCandidatePlies.count)"',
    '                ? "VE1-B証拠再利用対象なし"\n                : "VE1-B証拠再利用 \\(refinementCompletedPlies.count)/\\(refinementCandidatePlies.count)"',
    "context summary",
)
context = replace_once(
    context,
    '                  !deep.comparisonStable\n                    || !deep.continuationStable\n                    || deep.finalMovetimeMs < 2400 else {',
    '                  (!deep.comparisonStable || !deep.continuationStable) else {',
    "context refinement candidates",
)
context = replace_once(
    context,
    '            await refinementSession.endAnalysis()\n',
    '',
    "context outer legacy session cleanup",
)
context_path.write_text(context)

# 2) Generic Simulator gate must validate the node contract, not stale movetime state.
probe_path = ROOT / "iOS/ShogiCoachPoC/SimulatorCIProbe.swift"
probe = probe_path.read_text()
probe = replace_once(
    probe,
    '                && $0.analysisAttempts >= 1\n                && $0.finalMovetimeMs == 200\n                && $0.candidates.allSatisfy { !$0.pv.isEmpty && !$0.move.isEmpty }',
    '                && $0.analysisAttempts == 9\n                && $0.finalMovetimeMs == 0\n                && $0.nodePolicyAuthorityStatus == "UNFROZEN_CALIBRATION"\n                && $0.candidateDiscoveryNodes == 50_000\n                && $0.confirmationNodeTiers == [50_000, 100_000, 200_000]\n                && $0.finalNodeBudget == 200_000\n                && $0.searchEvidence.count == 9\n                && $0.candidates.allSatisfy { !$0.pv.isEmpty && !$0.move.isEmpty }',
    "generic deep node assertions",
)
probe = replace_once(
    probe,
    '              refinementReview.usedAdditionalEngineSearch,',
    '              !refinementReview.usedAdditionalEngineSearch,',
    "context refinement no-second-search assertion",
)
q_start = probe.index('    private static func runAnalysisQualityGate(\n')
q_end = probe.index('\n    static func runIfRequested() async {', q_start)
new_gate = r'''    private static func runAnalysisQualityGate(
        terminalGame: KIFGame
    ) async throws -> AnalysisQualityGateResult {
        guard terminalGame.moves.count >= 81,
              let terminalMove = terminalGame.moves.last else {
            throw EngineUSISession.ProbeError.protocolError("quality gate positions missing")
        }

        // Calibration-only Simulator budget. The gate validates VE1-B mechanics,
        // not production node authority; B6 owns the production policy decision.
        let policy = VE1BNodeSearchPolicy(
            candidateDiscoveryNodes: 10_000,
            candidateDiscoveryNodeTiers: [10_000, 20_000, 40_000],
            confirmationNodeTiers: [10_000, 20_000, 40_000],
            safetyCeilingMs: 15_000,
            authorityStatus: "SIMULATOR_QUALITY_GATE_CALIBRATION_UNFROZEN"
        )
        try policy.validate()

        let session = EngineUSISession()
        try await session.beginAnalysis(multiPV: 3)
        do {
            func validateContract(_ result: VE1BNodeComparisonResult, label: String) throws {
                guard result.attempts.map(\.nodeBudget) == policy.confirmationNodeTiers,
                      result.discoveryTierEvidence.count == policy.candidateDiscoveryNodeTiers.count,
                      result.evidenceRecords.count == 9,
                      result.finalNodeBudget == 40_000 else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "\(label) VE1-B tier/evidence contract mismatch"
                    )
                }
            }

            let normalMove = terminalGame.moves[40]
            let normal = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: normalMove.positionBefore,
                actualMove: normalMove.usi,
                candidateCount: 3,
                policy: policy
            )
            try validateContract(normal, label: "normal")
            let normalFinal = normal.finalAttempt
            let normalPVUsable = normal.confirmedBestPV.count >= 3
                && normal.confirmedActualPV.count >= 2
            let normalExplicitlyUnstableForPV = !normal.continuationStable
                && !normal.continuationInstabilityReasons.isEmpty
            guard !normalFinal.bestLine.pvMoves.isEmpty,
                  !normalFinal.actualLine.pvMoves.isEmpty,
                  normalPVUsable || normalExplicitlyUnstableForPV else {
                throw EngineUSISession.ProbeError.protocolError(
                    "normal quality position lacks confirmed PV or instability evidence"
                )
            }

            let close = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: "position startpos",
                actualMove: "7g7f",
                candidateCount: 3,
                policy: policy
            )
            try validateContract(close, label: "candidate")
            guard close.candidateLines.count >= 2,
                  close.attempts.count == policy.confirmationNodeTiers.count else {
                throw EngineUSISession.ProbeError.protocolError(
                    "candidate comparison did not execute the full fixed-node confirmation series"
                )
            }

            let terminal = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: terminalMove.positionBefore,
                actualMove: terminalMove.usi,
                candidateCount: 3,
                policy: policy
            )
            try validateContract(terminal, label: "terminal")
            let terminalFinal = terminal.finalAttempt
            guard terminalMove.usi == "G*1b",
                  terminalFinal.actualLine.move == terminalMove.usi,
                  terminalFinal.actualLine.pvMoves.first == terminalMove.usi,
                  !terminalFinal.bestLine.pvMoves.isEmpty else {
                throw EngineUSISession.ProbeError.protocolError(
                    "terminal/drop quality position regression"
                )
            }

            await session.endAnalysis()
            return AnalysisQualityGateResult(
                normalStable: normal.comparisonStable && normal.continuationStable,
                normalComparisonStable: normal.comparisonStable,
                normalContinuationStable: normal.continuationStable,
                normalAttempts: normal.attempts.count,
                closeGapCp: close.topCandidateGapCp,
                closeAttempts: close.attempts.count,
                terminalStable: terminal.comparisonStable && terminal.continuationStable,
                terminalComparisonStable: terminal.comparisonStable,
                terminalContinuationStable: terminal.continuationStable,
                terminalAttempts: terminal.attempts.count,
                terminalBestMove: terminalFinal.bestLine.move
            )
        } catch {
            await session.endAnalysis()
            throw error
        }
    }
'''
probe = probe[:q_start] + new_gate + probe[q_end:]
probe_path.write_text(probe)

# 3) Guard against reintroducing old production analyzer calls.
violations = []
for path in (ROOT / "iOS/ShogiCoachPoC").glob("*.swift"):
    if path.name == "AdaptiveComparisonAnalyzer.swift":
        continue
    text = path.read_text()
    if "AdaptiveComparisonAnalyzer.analyze(" in text:
        violations.append(str(path.relative_to(ROOT)))
if violations:
    raise SystemExit("legacy production analyzer call remains: " + ", ".join(violations))

print("VE1-B generic E2E/context migration applied")
