import Foundation
import Darwin
import ShogiCoachCore

#if targetEnvironment(simulator)
@MainActor
enum B6IncompleteStateSimulatorProbe {
    static let testName = "B6IncompleteStateProductionAbortProbe"
    private static let proofFileName = "b6-incomplete-state-runtime.json"

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ci-smoke") else { return }
        do {
            let game = try KIFParser.parse("""
            手合割：平手
            先手：あなた
            後手：CPU
            1 ７六歩(77)
            2 ８四歩(83)
            3 ２六歩(27)
            4 ８五歩(84)
            5 ７七角(88)
            6 投了
            """)

            let shallow = ShallowAnalysisViewModel()
            await shallow.analyze(
                game: game,
                fileName: "b6-incomplete-state-probe.kif",
                movetimeMs: 80
            )
            guard shallow.status == "浅解析 PASS",
                  let diagnosticURL = shallow.diagnosticURL else {
                throw NSError(
                    domain: "ShogiCoach.B6IncompleteProbe",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "shallow preparation failed"]
                )
            }

            let abortPolicy = VE1BNodeSearchPolicy(
                candidateDiscoveryNodes: 50_000_000,
                candidateDiscoveryNodeTiers: [50_000_000, 100_000_000, 200_000_000],
                confirmationNodeTiers: [50_000_000, 100_000_000, 200_000_000],
                safetyCeilingMs: 1,
                authorityStatus: "SIMULATOR_B6_INCOMPLETE_STATE_PROBE"
            )
            try abortPolicy.validate()

            let deep = DeepAnalysisViewModel()
            await deep.analyze(
                game: game,
                shallowEntries: shallow.entries,
                diagnosticURL: diagnosticURL,
                deepMovetimeMs: 800,
                multiPV: 3,
                maxPositions: 1,
                nodePolicy: abortPolicy
            )

            guard case .incomplete(_, let completed, let expected) = deep.runState,
                  completed < expected,
                  deep.displayStatus == "深掘り 未完了（\(completed)/\(expected)局面）",
                  deep.entries.isEmpty,
                  let evidenceURL = deep.searchEvidenceURL,
                  FileManager.default.fileExists(atPath: evidenceURL.path) else {
                throw NSError(
                    domain: "ShogiCoach.B6IncompleteProbe",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "production incomplete-state/UI suppression contract failed"]
                )
            }

            let evidenceData = try Data(contentsOf: evidenceURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let evidence = try decoder.decode(VE1BSearchEvidenceDocument.self, from: evidenceData)
            let completionStates = evidence.incompleteAttempts.map(\.completion)
            guard !evidence.incompleteAttempts.isEmpty,
                  completionStates.contains("safety_aborted"),
                  completionStates.allSatisfy({
                      $0 != "node_budget_reached" && $0 != "proven_mate_termination"
                  }) else {
                throw NSError(
                    domain: "ShogiCoach.B6IncompleteProbe",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "incomplete raw evidence was not preserved as safety_aborted"]
                )
            }

            let payload: [String: Any] = [
                "schemaVersion": 1,
                "testName": testName,
                "runState": "incomplete",
                "displayStatus": deep.displayStatus,
                "completedPositions": completed,
                "expectedPositions": expected,
                "recommendationSuppressed": deep.entries.isEmpty,
                "lossSuppressed": deep.entries.allSatisfy { $0.actualLossCp == nil },
                "evidenceSaved": true,
                "evidenceFileName": evidenceURL.lastPathComponent,
                "incompleteAttemptCount": evidence.incompleteAttempts.count,
                "completionStates": completionStates,
                "result": "PASS"
            ]
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: proofURL, options: .atomic)
            SimulatorStage.mark("b6_incomplete_state_production_abort_probe_pass")
        } catch {
            let payload: [String: Any] = [
                "schemaVersion": 1,
                "testName": testName,
                "result": "FAIL",
                "error": error.localizedDescription
            ]
            if let data = try? JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            ) {
                try? data.write(to: proofURL, options: .atomic)
            }
            SimulatorStage.mark("b6_incomplete_state_production_abort_probe_fail_\(error.localizedDescription)")
            fflush(stdout)
            exit(29)
        }
    }

    private static var proofURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(proofFileName)
    }
}
#endif
