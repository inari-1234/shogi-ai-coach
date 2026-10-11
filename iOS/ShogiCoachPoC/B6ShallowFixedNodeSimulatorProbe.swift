import Foundation
import Darwin
import ShogiCoachCore

#if targetEnvironment(simulator)
@MainActor
enum B6ShallowFixedNodeSimulatorProbe {
    static let testName = "B6ShallowFixedNodeProductionDeterminismProbe"
    private static let proofFileName = "b6-shallow-fixed-node-runtime.json"

    static func runIfRequested() async {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ci-smoke") || arguments.contains("--ci-b6-shallow-fixed") else { return }

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

            let first = try await runProductionShallow(game: game, label: "a")
            let second = try await runProductionShallow(game: game, label: "b")

            let firstSignatures = try first.map(semanticSignature)
            let secondSignatures = try second.map(semanticSignature)
            guard firstSignatures == secondSignatures else {
                let index = zip(firstSignatures, secondSignatures).firstIndex { $0 != $1 }
                throw NSError(
                    domain: "ShogiCoach.B6ShallowFixedNodeProbe",
                    code: 4,
                    userInfo: [
                        NSLocalizedDescriptionKey:
                            "fixed-node shallow semantic mismatch at index \(index.map(String.init) ?? "unknown")"
                    ]
                )
            }

            let payload: [String: Any] = [
                "schemaVersion": 1,
                "testName": testName,
                "result": "PASS",
                "nodeBudget": ShallowAnalysisAuthority.productionNodeBudget,
                "safetyCeilingMs": ShallowAnalysisAuthority.productionSafetyCeilingMs,
                "multiPV": ShallowAnalysisAuthority.productionMultiPV,
                "authorityStatus": ShallowAnalysisAuthority.authorityStatus,
                "positionCount": first.count,
                "semanticEquality": true,
                "allCompleted": first.allSatisfy { entry in
                    guard let evidence = entry.fixedNodeEvidence else { return false }
                    return evidence.completion == "node_budget_reached"
                        || evidence.completion == "proven_mate_termination"
                },
                "selectedRawUSIMappable": first.allSatisfy(hasSelectedRawUSI)
            ]
            let data = try JSONSerialization.data(
                withJSONObject: payload,
                options: [.prettyPrinted, .sortedKeys]
            )
            try data.write(to: proofURL, options: .atomic)
            SimulatorStage.mark("b6_shallow_fixed_node_determinism_probe_pass")
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
            SimulatorStage.mark("b6_shallow_fixed_node_determinism_probe_fail_\(error.localizedDescription)")
            fflush(stdout)
            exit(31)
        }
    }

    private static func runProductionShallow(
        game: KIFGame,
        label: String
    ) async throws -> [ShallowAnalysisEntry] {
        let shallow = ShallowAnalysisViewModel()
        await shallow.analyze(game: game, fileName: "b6-shallow-fixed-node-\(label).kif")
        guard shallow.status == "浅解析 PASS",
              shallow.entries.count == game.moves.count,
              shallow.entries.allSatisfy({ $0.fixedNodeEvidence != nil }) else {
            throw NSError(
                domain: "ShogiCoach.B6ShallowFixedNodeProbe",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "production fixed-node shallow did not complete"]
            )
        }
        return shallow.entries
    }

    private static func semanticSignature(_ entry: ShallowAnalysisEntry) throws -> String {
        guard let evidence = entry.fixedNodeEvidence else {
            throw NSError(
                domain: "ShogiCoach.B6ShallowFixedNodeProbe",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "missing fixed-node evidence at ply \(entry.ply)"]
            )
        }
        guard evidence.nodeBudget == ShallowAnalysisAuthority.productionNodeBudget,
              evidence.multiPV == ShallowAnalysisAuthority.productionMultiPV,
              evidence.searchMoves.isEmpty,
              evidence.selectedBoundKind == "exact",
              hasSelectedRawUSI(entry) else {
            throw NSError(
                domain: "ShogiCoach.B6ShallowFixedNodeProbe",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "fixed-node evidence contract failed at ply \(entry.ply)"]
            )
        }

        return [
            String(entry.ply),
            entry.actualMove,
            entry.bestMove,
            entry.scoreText,
            entry.blackPerspectiveCp.map(String.init) ?? "nil",
            entry.depthText,
            entry.nodesText,
            entry.pv,
            String(entry.matchesBestMove),
            evidence.positionCommand,
            String(evidence.nodeBudget),
            String(evidence.ttGeneration),
            String(evidence.multiPV),
            evidence.completion,
            evidence.selectedNodes.map(String.init) ?? "nil",
            evidence.selectedDepth.map(String.init) ?? "nil",
            evidence.selectedSelDepth.map(String.init) ?? "nil",
            evidence.selectedBoundKind ?? "nil",
            evidence.selectedScoreKind ?? "nil",
            evidence.selectedScoreValue.map(String.init) ?? "nil",
            evidence.selectedPV.joined(separator: " "),
            evidence.bestMoveConsistency ?? "nil"
        ].joined(separator: "|")
    }

    private static func hasSelectedRawUSI(_ entry: ShallowAnalysisEntry) -> Bool {
        guard let evidence = entry.fixedNodeEvidence else { return false }
        return evidence.observations.contains { observation in
            observation.multipv == 1
                && observation.boundKind == evidence.selectedBoundKind
                && observation.depth == evidence.selectedDepth
                && observation.nodes == evidence.selectedNodes
                && observation.pv == evidence.selectedPV
                && !observation.rawUSI.isEmpty
        }
    }

    private static var proofURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(proofFileName)
    }
}
#endif
