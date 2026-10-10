import Foundation

#if targetEnvironment(simulator)
@MainActor
enum VE1BSimulatorCIProbe {
    private static var documentsURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func writeReport(_ lines: [String]) {
        let url = documentsURL.appendingPathComponent("ve1b-ci-probe.txt")
        try? (lines.joined(separator: "\n") + "\n")
            .write(to: url, atomically: true, encoding: .utf8)
    }

    private static func sampleGame() throws -> KIFGame {
        let sample = """
        手合割：平手
        1 ７六歩(77)
        2 ８四歩(83)
        3 ２六歩(27)
        4 ８五歩(84)
        5 ７七角(88)
        6 投了
        """
        return try KIFParser.parse(sample)
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ve1b-ci-smoke") else { return }
        SimulatorStage.reset()
        SimulatorStage.mark("ve1b_ci_started")
        writeReport(["stage=started"])

        do {
            let game = try sampleGame()
            guard game.moves.count == 5 else {
                throw EngineUSISession.ProbeError.protocolError("VE1-B CI KIF move-count mismatch")
            }

            let shallow = ShallowAnalysisViewModel()
            await shallow.analyze(game: game, fileName: "ve1b-ci-sample.kif", movetimeMs: 80)
            guard shallow.status == "浅解析 PASS",
                  shallow.entries.count == game.moves.count,
                  shallow.diagnosticURL != nil else {
                throw EngineUSISession.ProbeError.protocolError("VE1-B CI shallow analysis failed")
            }

            let policy: VE1BNodeSearchPolicy = .calibrationUnfrozen
            let deep = DeepAnalysisViewModel()
            await deep.analyze(
                game: game,
                shallowEntries: shallow.entries,
                diagnosticURL: shallow.diagnosticURL,
                deepMovetimeMs: 200,
                multiPV: 3,
                maxPositions: 3,
                nodePolicy: policy
            )

            guard deep.status == "深掘り PASS",
                  deep.entries.count == 3,
                  deep.searchEvidenceURL != nil else {
                throw EngineUSISession.ProbeError.protocolError(
                    "VE1-B CI deep analysis did not complete normally: \(deep.status)"
                )
            }

            for entry in deep.entries {
                guard entry.nodePolicyAuthorityStatus == "UNFROZEN_CALIBRATION",
                      entry.analysisAttempts == 6,
                      entry.searchEvidence.count == 6,
                      entry.candidates.count == 3,
                      !entry.bestMove.isEmpty,
                      !entry.actualMove.isEmpty,
                      entry.finalMovetimeMs == 0 else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI evidence-shape mismatch at ply \(entry.ply)"
                    )
                }

                let discovery = Array(entry.searchEvidence.prefix(3))
                let comparison = Array(entry.searchEvidence.suffix(3))
                guard discovery.map(\.role) == Array(repeating: "candidate_discovery", count: 3),
                      discovery.map(\.nodeBudget) == policy.candidateDiscoveryNodeTiers,
                      discovery.allSatisfy({ $0.multiPV == 3 && $0.searchMoves.isEmpty }),
                      Set(discovery.map(\.ttGeneration)).count == 3,
                      comparison.map(\.role) == ["direct_comparison", "confirmation", "confirmation"],
                      comparison.map(\.nodeBudget) == policy.confirmationNodeTiers,
                      Set(comparison.map(\.ttGeneration)).count == 1,
                      discovery.last!.ttGeneration < comparison.first!.ttGeneration,
                      entry.searchEvidence.allSatisfy({
                          $0.completion == "node_budget_reached"
                              && $0.issuedGoCommand.contains("go nodes ")
                              && $0.maxObservedNodes >= UInt64($0.nodeBudget)
                      }) else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI TT/role/node contract mismatch at ply \(entry.ply)"
                    )
                }

                if !entry.comparisonStable {
                    guard entry.actualLossCp == nil else {
                        throw EngineUSISession.ProbeError.protocolError(
                            "unstable comparison exposed cp loss at ply \(entry.ply)"
                        )
                    }
                }
                if entry.stabilityState != "stable" {
                    guard entry.topCandidateGapCp == nil else {
                        throw EngineUSISession.ProbeError.protocolError(
                            "unconfirmed candidate ranking exposed top gap at ply \(entry.ply)"
                        )
                    }
                }
            }

            guard let evidenceURL = deep.searchEvidenceURL,
                  let data = try? Data(contentsOf: evidenceURL),
                  let document = try? JSONDecoder().decode(VE1BSearchEvidenceDocument.self, from: data),
                  document.schemaVersion == 2,
                  document.status == "深掘り PASS",
                  document.policyAuthorityStatus == "UNFROZEN_CALIBRATION",
                  document.candidateDiscoveryNodeTiers == policy.candidateDiscoveryNodeTiers,
                  document.confirmationNodeTiers == policy.confirmationNodeTiers,
                  document.positions.count == 3,
                  document.incompleteAttempts.isEmpty else {
                throw EngineUSISession.ProbeError.protocolError("VE1-B CI evidence export mismatch")
            }

            let stableCount = deep.entries.filter(\.comparisonStable).count
            let withheldLossCount = deep.entries.filter {
                !$0.comparisonStable && $0.actualLossCp == nil
            }.count
            let withheldGapCount = deep.entries.filter {
                $0.stabilityState != "stable" && $0.topCandidateGapCp == nil
            }.count
            writeReport([
                "stage=complete",
                "ve1b_status=PASS",
                "shallow_status=PASS",
                "deep_status=PASS",
                "deep_count=\(deep.entries.count)",
                "node_policy=\(policy.authorityStatus)",
                "discovery_tiers=\(policy.candidateDiscoveryNodeTiers.map(String.init).joined(separator: ","))",
                "confirmation_tiers=\(policy.confirmationNodeTiers.map(String.init).joined(separator: ","))",
                "stable_count=\(stableCount)",
                "withheld_unstable_loss_count=\(withheldLossCount)",
                "withheld_unconfirmed_gap_count=\(withheldGapCount)",
                "evidence_schema=2",
                "evidence_positions=\(document.positions.count)",
                "incomplete_attempts=\(document.incompleteAttempts.count)"
            ])
            SimulatorStage.mark("ve1b_ci_complete")
        } catch {
            writeReport([
                "stage=failed",
                "ve1b_status=FAIL",
                "error=\(error.localizedDescription)"
            ])
            SimulatorStage.mark("ve1b_ci_failed_\(error.localizedDescription)")
        }
    }
}
#endif
