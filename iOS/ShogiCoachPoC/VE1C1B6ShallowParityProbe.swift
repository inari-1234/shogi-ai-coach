import Foundation
import Darwin
import ShogiCoachCore

#if targetEnvironment(simulator)
@MainActor
enum VE1C1B6ShallowParityProbe {
    private static let argument = "--ci-ve1c1-b6-shallow-parity"
    private static let inputFileName = "ve1c1_b6_shallow_physical_digest.json"
    private static let outputFileName = "ve1c1-b6-swift-shallow-output.json"
    private static let errorFileName = "ve1c1-b6-swift-shallow-error.txt"
    private static let expectedPhysicalSHA = "fe63385d97293ae8cb7a577618ae66d7592d57b2960dcc899bcf93b51ff4a2a9"
    private static let expectedFixtureSHA = "ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102"

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fixtureURL = documents.appendingPathComponent(inputFileName)
            let data = try Data(contentsOf: fixtureURL)
            guard let fixture = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  fixture["schema_version"] as? String == "ve1c1-b6-shallow-physical-digest-v1",
                  let source = fixture["source"] as? [String: Any],
                  source["sha256"] as? String == expectedPhysicalSHA,
                  source["fixture_sha256"] as? String == expectedFixtureSHA,
                  source["shallow_node_budget"] as? Int == ShallowAnalysisAuthority.productionNodeBudget,
                  let actualMoves = fixture["actual_moves"] as? [String],
                  actualMoves.count == 81 else {
                throw NSError(
                    domain: "ShogiCoach.VE1C1B6ShallowParity",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "invalid physical B6 digest fixture"]
                )
            }

            let moves = actualMoves.enumerated().map { index, usi in
                let ply = index + 1
                let before = actualMoves.prefix(index)
                let command = before.isEmpty
                    ? "position startpos"
                    : "position startpos moves " + before.joined(separator: " ")
                return KIFMove(
                    ply: ply,
                    notation: usi,
                    usi: usi,
                    positionBefore: command
                )
            }
            let game = KIFGame(
                metadata: ["先手": "あなた", "後手": "CPU"],
                moves: moves,
                termination: nil
            )

            let shallow = ShallowAnalysisViewModel()
            await shallow.analyze(game: game, fileName: "CPU対局 81手.kif")
            guard shallow.status == "浅解析 PASS",
                  shallow.entries.count == 81 else {
                throw NSError(
                    domain: "ShogiCoach.VE1C1B6ShallowParity",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "production shallow did not complete 81/81: \(shallow.status) \(shallow.entries.count)"]
                )
            }

            let records: [[String: Any]] = try shallow.entries.map { entry in
                guard let evidence = entry.fixedNodeEvidence,
                      evidence.nodeBudget == ShallowAnalysisAuthority.productionNodeBudget,
                      evidence.multiPV == ShallowAnalysisAuthority.productionMultiPV,
                      evidence.searchMoves.isEmpty,
                      evidence.selectedBoundKind == "exact",
                      let scoreKind = evidence.selectedScoreKind,
                      let scoreValue = evidence.selectedScoreValue else {
                    throw NSError(
                        domain: "ShogiCoach.VE1C1B6ShallowParity",
                        code: 3,
                        userInfo: [NSLocalizedDescriptionKey: "invalid fixed-node evidence at ply \(entry.ply)"]
                    )
                }
                var record: [String: Any] = [
                    "actualMove": entry.actualMove,
                    "bestMove": entry.bestMove,
                    "completion": evidence.completion,
                    "nodeBudget": evidence.nodeBudget,
                    "ply": entry.ply,
                    "positionCommand": evidence.positionCommand,
                    "scoreKind": scoreKind,
                    "scoreValue": scoreValue
                ]
                record["blackPerspectiveCp"] = entry.blackPerspectiveCp ?? NSNull()
                return record
            }

            let payload: [String: Any] = [
                "schema_version": "ve1c1-b6-swift-shallow-output-v1",
                "architecture": ProcessInfo.processInfo.machineArchitecture,
                "authority_status": ShallowAnalysisAuthority.authorityStatus,
                "node_budget": ShallowAnalysisAuthority.productionNodeBudget,
                "multi_pv": ShallowAnalysisAuthority.productionMultiPV,
                "record_count": records.count,
                "records": records
            ]
            let output = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try output.write(to: documents.appendingPathComponent(outputFileName), options: .atomic)
            SimulatorStage.mark("ve1c1_b6_swift_shallow_output_81")
        } catch {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? (error.localizedDescription + "\n").write(
                to: documents.appendingPathComponent(errorFileName),
                atomically: true,
                encoding: .utf8
            )
            SimulatorStage.mark("ve1c1_b6_swift_shallow_error_\(error.localizedDescription)")
            fflush(stdout)
            exit(41)
        }
    }
}

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }
}
#endif
