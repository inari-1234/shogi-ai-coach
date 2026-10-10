#!/usr/bin/env python3
from pathlib import Path

p = Path('iOS/ShogiCoachPoC/SimulatorCIProbe.swift')
t = p.read_text(encoding='utf-8')
start = t.index('        guard continuationStatus == "展開シミュレーション PASS",')
end_marker = '        let continuationNonStableValid = nonStableDeepEntries.allSatisfy { deepEntry in\n'
end = t.index(end_marker, start)
old = t[start:end]
new = '''        let continuationStatusOK = continuationStatus == "展開シミュレーション PASS"
        let continuationCountOK = continuationCount == deep.entries.count
        let continuationDiagnosticURLValue = continuation.diagnosticURL
        let continuationDiagnosticDataValue = continuationDiagnosticURLValue.flatMap {
            try? Data(contentsOf: $0)
        }
        let continuationDiagnosticValue = continuationDiagnosticDataValue.flatMap {
            try? JSONDecoder.iso8601.decode(ShogiDiagnosticDocument.self, from: $0)
        }
        let continuationDiagnosticDecoded = continuationDiagnosticValue != nil
        let continuationSchemaOK = continuationDiagnosticValue?.schemaVersion == 5
        let continuationAppVersionOK = continuationDiagnosticValue?.app.version == "0.8.3"
        let continuationAppBuildOK = continuationDiagnosticValue?.app.build == "16"
        let continuationDiagnosticStatusOK = continuationDiagnosticValue?.continuationSimulation?.status == "展開シミュレーション PASS"
        let continuationDiagnosticCompletedOK = continuationDiagnosticValue?.continuationSimulation?.completedPositions == deep.entries.count
        let continuationDiagnosticCountOK = continuationDiagnosticValue?.continuationSimulation?.positions.count == deep.entries.count
        let continuationDiagnosticBoundaryOK = continuationDiagnosticValue?.continuationSimulation?.positions.allSatisfy({ position in
            guard let source = deep.entries.first(where: { $0.ply == position.ply }) else {
                return false
            }
            let recommendedBoundary = source.confirmedBestPV.isEmpty
                ? position.recommended.moves.isEmpty
                : !position.recommended.moves.isEmpty
            let actualBoundary = source.confirmedActualPV.isEmpty
                ? position.actual.moves.isEmpty
                : !position.actual.moves.isEmpty
            return recommendedBoundary
                && actualBoundary
                && !position.recommended.targetShapeSummary.isEmpty
                && !position.actual.targetShapeSummary.isEmpty
        }) == true
        var continuationPolicyAuditError: String?
        do {
            try RecommendationDecisionPolicyAudit.validate(entries: continuation.entries)
        } catch {
            continuationPolicyAuditError = error.localizedDescription
        }
        let continuationPolicyOK = continuationPolicyAuditError == nil
        let continuationCompositeOK = continuationStatusOK
            && continuationCountOK
            && continuationValid
            && continuationDiagnosticURLValue != nil
            && continuationDiagnosticDataValue != nil
            && continuationDiagnosticDecoded
            && continuationSchemaOK
            && continuationAppVersionOK
            && continuationAppBuildOK
            && continuationDiagnosticStatusOK
            && continuationDiagnosticCompletedOK
            && continuationDiagnosticCountOK
            && continuationDiagnosticBoundaryOK
            && continuationPolicyOK
        guard continuationCompositeOK else {
            writeReport([
                "stage=continuation_simulation_failed",
                "continuation_status=\\(continuationStatus)",
                "continuation_count=\\(continuationCount)",
                "check_status=\\(continuationStatusOK)",
                "check_count=\\(continuationCountOK)",
                "check_entry_valid=\\(continuationValid)",
                "check_diag_url=\\(continuationDiagnosticURLValue != nil)",
                "check_diag_data=\\(continuationDiagnosticDataValue != nil)",
                "check_diag_decoded=\\(continuationDiagnosticDecoded)",
                "check_schema=\\(continuationSchemaOK)",
                "check_app_version=\\(continuationAppVersionOK)",
                "check_app_build=\\(continuationAppBuildOK)",
                "check_diag_status=\\(continuationDiagnosticStatusOK)",
                "check_diag_completed=\\(continuationDiagnosticCompletedOK)",
                "check_diag_count=\\(continuationDiagnosticCountOK)",
                "check_diag_boundary=\\(continuationDiagnosticBoundaryOK)",
                "check_policy=\\(continuationPolicyOK)",
                "policy_error=\\(continuationPolicyAuditError ?? \"none\")",
                "continuation_summary_begin",
                continuation.summary,
                "continuation_summary_end"
            ].joined(separator: "\\n") + "\\n")
            SimulatorStage.mark("continuation_simulation_failed")
            fflush(stdout)
            exit(15)
        }
'''
p.write_text(t[:start] + new + t[end:], encoding='utf-8')
print(f'instrumented bytes: {len(old)} -> {len(new)}')
