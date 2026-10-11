from pathlib import Path

path = Path("iOS/ShogiCoachPoC/VE1BPhysicalQualificationView.swift")
text = path.read_text()


def replace_once(old: str, new: str, label: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"{label}: expected one match, got {count}")
    text = text.replace(old, new, 1)

replace_once(
'''    let shallowReproducibilityPassed: Bool
    let shallowSemanticEqualityPassed: Bool
    let fullSelectionDeterminismPassed: Bool
    let standardEvidenceIntegrityPassed: Bool''',
'''    let shallowReproducibilityPassed: Bool
    let shallowSemanticEqualityPassed: Bool
    let fullSelectionDeterminismPassed: Bool
    let shallowDeterminismStatus: String
    let shallowDeterminismFirstDifference: String?
    let standardEvidenceIntegrityPassed: Bool''',
"report fields",
)

replace_once(
'''        let shallowSemanticEqualityPassed = Self.shallowSemanticsEqual(runs: state.standardRuns)
        let shallowPassed = state.standardRuns.count == standardRunTarget''',
'''        let shallowDeterminismFirstDifference = Self.firstShallowSemanticDifference(
            runs: state.standardRuns,
            expectedRunCount: standardRunTarget
        )
        let shallowSemanticEqualityPassed = state.standardRuns.count == standardRunTarget
            && shallowDeterminismFirstDifference == nil
        let shallowPassed = state.standardRuns.count == standardRunTarget''',
"determinism calculation",
)

replace_once(
'''            && fullSelectionDeterminismPassed
            && shallowSemanticEqualityPassed

        let standardEvidenceIntegrityPassed''',
'''            && fullSelectionDeterminismPassed
            && shallowSemanticEqualityPassed
        let shallowDeterminismStatus = shallowPassed
            ? "SHALLOW_DETERMINISM_PASS"
            : "SHALLOW_DETERMINISM_FAIL"

        let standardEvidenceIntegrityPassed''',
"determinism status",
)

replace_once(
'''            schemaVersion: 2,
            generatedAt: Date(),''',
'''            schemaVersion: 3,
            generatedAt: Date(),''',
"report schema",
)

replace_once(
'''            shallowReproducibilityPassed: shallowPassed,
            shallowSemanticEqualityPassed: shallowSemanticEqualityPassed,
            fullSelectionDeterminismPassed: fullSelectionDeterminismPassed,
            standardEvidenceIntegrityPassed: standardEvidenceIntegrityPassed,''',
'''            shallowReproducibilityPassed: shallowPassed,
            shallowSemanticEqualityPassed: shallowSemanticEqualityPassed,
            fullSelectionDeterminismPassed: fullSelectionDeterminismPassed,
            shallowDeterminismStatus: shallowDeterminismStatus,
            shallowDeterminismFirstDifference: shallowDeterminismFirstDifference,
            standardEvidenceIntegrityPassed: standardEvidenceIntegrityPassed,''',
"report initializer",
)

replace_once(
'''            "shallow_semantic_equal=\\(report.shallowSemanticEqualityPassed) full_selection_equal=\\(report.fullSelectionDeterminismPassed)",''',
'''            "shallow_semantic_equal=\\(report.shallowSemanticEqualityPassed) full_selection_equal=\\(report.fullSelectionDeterminismPassed)",
            "shallow_determinism=\\(report.shallowDeterminismStatus) first_diff=\\(report.shallowDeterminismFirstDifference ?? "-")",''',
"summary",
)

old_helpers = '''    private static func shallowSemanticsEqual(runs: [VE1BB6RunRecord]) -> Bool {
        guard runs.count == 5, let first = runs.first else { return false }
        let baseline = first.shallowSamples.map(shallowSemanticSignature)
        guard !baseline.isEmpty else { return false }
        return runs.dropFirst().allSatisfy {
            $0.shallowSamples.map(shallowSemanticSignature) == baseline
        }
    }

    private static func shallowSemanticSignature(_ sample: VE1BB6ShallowSample) -> String {
        [
            String(sample.ply),
            sample.positionCommand,
            sample.actualMove,
            sample.bestMove,
            sample.blackPerspectiveCp.map(String.init) ?? "nil",
            String(sample.nodeBudget),
            String(sample.ttGeneration),
            String(sample.multiPV),
            sample.completion,
            sample.selectedNodes.map(String.init) ?? "nil",
            sample.selectedDepth.map(String.init) ?? "nil",
            sample.selectedSelDepth.map(String.init) ?? "nil",
            sample.selectedBoundKind ?? "nil",
            sample.selectedScoreKind ?? "nil",
            sample.selectedScoreValue.map(String.init) ?? "nil",
            sample.selectedPV.joined(separator: " "),
            sample.bestMoveConsistency ?? "nil",
            String(sample.matchesBestMove),
            String(sample.focusEligible),
            sample.estimatedLossCp.map(String.init) ?? "nil",
            sample.importance.map(String.init) ?? "nil",
            sample.selectedRank.map(String.init) ?? "nil"
        ].joined(separator: "|")
    }
'''

new_helpers = '''    private static func firstShallowSemanticDifference(
        runs: [VE1BB6RunRecord],
        expectedRunCount: Int
    ) -> String? {
        guard runs.count == expectedRunCount else {
            return "run_count expected=\\(expectedRunCount) actual=\\(runs.count)"
        }
        guard let baselineRun = runs.first, !baselineRun.shallowSamples.isEmpty else {
            return "baseline_shallow_samples_missing"
        }

        for run in runs.dropFirst() {
            guard run.shallowSamples.count == baselineRun.shallowSamples.count else {
                return "run=\\(run.ordinal) field=sample_count baseline=\\(baselineRun.shallowSamples.count) current=\\(run.shallowSamples.count)"
            }
            for index in baselineRun.shallowSamples.indices {
                let baseline = baselineRun.shallowSamples[index]
                let current = run.shallowSamples[index]
                let baselineFields = shallowSemanticFields(baseline)
                let currentFields = shallowSemanticFields(current)
                for fieldIndex in baselineFields.indices {
                    let baselineField = baselineFields[fieldIndex]
                    let currentField = currentFields[fieldIndex]
                    if baselineField.1 != currentField.1 {
                        return [
                            "run=\\(run.ordinal)",
                            "ply=\\(baseline.ply)",
                            "field=\\(baselineField.0)",
                            "baseline=\\(baselineField.1)",
                            "current=\\(currentField.1)",
                            "baselineRaw=\\(baseline.selectedRawUSI ?? "-")",
                            "currentRaw=\\(current.selectedRawUSI ?? "-")"
                        ].joined(separator: " ")
                    }
                }
            }
        }
        return nil
    }

    private static func shallowSemanticFields(
        _ sample: VE1BB6ShallowSample
    ) -> [(String, String)] {
        [
            ("ply", String(sample.ply)),
            ("positionCommand", sample.positionCommand),
            ("actualMove", sample.actualMove),
            ("bestMove", sample.bestMove),
            ("blackPerspectiveCp", sample.blackPerspectiveCp.map(String.init) ?? "nil"),
            ("nodeBudget", String(sample.nodeBudget)),
            ("ttGeneration", String(sample.ttGeneration)),
            ("multiPV", String(sample.multiPV)),
            ("completion", sample.completion),
            ("selectedNodes", sample.selectedNodes.map(String.init) ?? "nil"),
            ("selectedDepth", sample.selectedDepth.map(String.init) ?? "nil"),
            ("selectedSelDepth", sample.selectedSelDepth.map(String.init) ?? "nil"),
            ("selectedBoundKind", sample.selectedBoundKind ?? "nil"),
            ("selectedScoreKind", sample.selectedScoreKind ?? "nil"),
            ("selectedScoreValue", sample.selectedScoreValue.map(String.init) ?? "nil"),
            ("selectedPV", sample.selectedPV.joined(separator: " ")),
            ("bestMoveConsistency", sample.bestMoveConsistency ?? "nil"),
            ("matchesBestMove", String(sample.matchesBestMove)),
            ("focusEligible", String(sample.focusEligible)),
            ("estimatedLossCp", sample.estimatedLossCp.map(String.init) ?? "nil"),
            ("importance", sample.importance.map(String.init) ?? "nil"),
            ("selectedRank", sample.selectedRank.map(String.init) ?? "nil")
        ]
    }
'''

replace_once(old_helpers, new_helpers, "determinism helpers")

path.write_text(text)
print("patched shallow determinism report diagnostics")
