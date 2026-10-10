import Foundation
import ShogiCoachCore

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
                      entry.analysisAttempts == 9,
                      entry.searchEvidence.count == 9,
                      entry.candidates.count == 3,
                      !entry.bestMove.isEmpty,
                      !entry.actualMove.isEmpty,
                      entry.finalMovetimeMs == 0 else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI evidence-shape mismatch at ply \(entry.ply)"
                    )
                }

                let discovery = Array(entry.searchEvidence.prefix(3))
                let comparison = Array(entry.searchEvidence.suffix(6))
                let expectedComparisonBudgets = policy.confirmationNodeTiers.flatMap { [$0, $0] }
                let expectedRoles = [
                    "direct_comparison", "direct_comparison",
                    "confirmation", "confirmation",
                    "confirmation", "confirmation"
                ]
                let expectedTargets = [
                    "recommended_move", "actual_move",
                    "recommended_move", "actual_move",
                    "recommended_move", "actual_move"
                ]

                guard discovery.map(\.role) == Array(repeating: "candidate_discovery", count: 3),
                      discovery.map(\.measurementTarget) == Array(repeating: "candidate_discovery", count: 3),
                      discovery.map(\.nodeBudget) == policy.candidateDiscoveryNodeTiers,
                      discovery.allSatisfy({
                          $0.multiPV == 3
                              && $0.searchMoves.isEmpty
                              && $0.pvIntervalMs == 0
                              && $0.observationCount == $0.observations.count
                              && !$0.observations.isEmpty
                              && $0.selectedBoundKind == "exact"
                              && $0.selectedDepth != nil
                      }),
                      Set(discovery.map(\.ttGeneration)).count == 3,
                      comparison.map(\.role) == expectedRoles,
                      comparison.map(\.measurementTarget) == expectedTargets,
                      comparison.map(\.nodeBudget) == expectedComparisonBudgets,
                      comparison.allSatisfy({
                          $0.multiPV == 1
                              && $0.searchMoves.count == 1
                              && $0.pvIntervalMs == 0
                              && $0.observationCount == $0.observations.count
                              && $0.selectedMove == $0.searchMoves.first
                              && $0.selectedScoreKind != nil
                              && $0.selectedBoundKind == "exact"
                              && $0.selectedDepth != nil
                              && $0.selectedNodes != nil
                      }),
                      Set(comparison.map(\.ttGeneration)).count == 6,
                      Set(entry.searchEvidence.map(\.ttGeneration)).count == 9,
                      discovery.last!.ttGeneration < comparison.first!.ttGeneration,
                      entry.searchEvidence.allSatisfy({
                          $0.completion == "node_budget_reached"
                              && $0.issuedGoCommand.contains("go nodes ")
                              && $0.maxObservedNodes >= UInt64($0.nodeBudget)
                      }) else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI independent-cold TT/role/node/completed-iteration contract mismatch at ply \(entry.ply)"
                    )
                }
            }

            let evidenceDecoder = JSONDecoder()
            evidenceDecoder.dateDecodingStrategy = .iso8601
            guard let evidenceURL = deep.searchEvidenceURL,
                  let data = try? Data(contentsOf: evidenceURL),
                  let document = try? evidenceDecoder.decode(VE1BSearchEvidenceDocument.self, from: data),
                  document.schemaVersion == 4,
                  document.status == "深掘り PASS",
                  document.policyAuthorityStatus == "UNFROZEN_CALIBRATION",
                  document.stabilityRules.lossSwingThresholdCp == 120,
                  document.stabilityRules.authorityStatus == "UNFROZEN_VE1C_CALIBRATION",
                  document.pvIntervalMs == 0,
                  document.measurementDefinition == "deepest_fully_completed_exact_iteration",
                  document.candidateDiscoveryNodeTiers == policy.candidateDiscoveryNodeTiers,
                  document.confirmationNodeTiers == policy.confirmationNodeTiers,
                  document.positions.count == 3,
                  document.incompleteAttempts.isEmpty else {
                throw EngineUSISession.ProbeError.protocolError("VE1-B CI evidence export mismatch")
            }

            var reclassifiedMatches = 0
            for position in document.positions {
                guard position.attempts.count == 9,
                      position.stabilityEvidenceTiers.count == 3,
                      position.attempts.allSatisfy({
                          $0.pvIntervalMs == 0
                              && $0.selectedBoundKind == "exact"
                              && $0.selectedDepth != nil
                      }) else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI persisted completed-iteration evidence missing at ply \(position.ply)"
                    )
                }
                let recomputed = VE1BStabilityReclassifier.assess(
                    evidence: position.stabilityEvidenceTiers,
                    rules: document.stabilityRules
                )
                guard recomputed.assessment.state.rawValue == position.stabilityState,
                      recomputed.comparisonInstabilityReasons == position.stabilityReasons else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "VE1-B CI evidence-only reclassification mismatch at ply \(position.ply)"
                    )
                }
                reclassifiedMatches += 1
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
                "comparison_method=independent_cold_single_move_multipv1",
                "nodes_semantics=per_move",
                "pv_interval_ms=0",
                "measurement=deepest_fully_completed_exact_iteration",
                "discovery_tiers=\(policy.candidateDiscoveryNodeTiers.map(String.init).joined(separator: ","))",
                "confirmation_tiers=\(policy.confirmationNodeTiers.map(String.init).joined(separator: ","))",
                "attempts_per_position=9",
                "stable_count=\(stableCount)",
                "withheld_unstable_loss_count=\(withheldLossCount)",
                "withheld_unconfirmed_gap_count=\(withheldGapCount)",
                "evidence_schema=4",
                "evidence_positions=\(document.positions.count)",
                "evidence_only_reclassification_matches=\(reclassifiedMatches)",
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
