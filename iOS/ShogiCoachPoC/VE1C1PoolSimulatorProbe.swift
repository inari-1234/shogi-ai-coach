import Foundation
import CryptoKit
import Darwin
import ShogiCoachCore

#if targetEnvironment(simulator)
@MainActor
enum VE1C1PoolSimulatorProbe {
    private static let argument = "--ci-ve1c1-production-pool"
    private static let inputDirectoryName = "ve1c1-pool-input"
    private static let outputFileName = "ve1c1-production-pool.json"
    private static let errorFileName = "ve1c1-production-pool-error.txt"
    private static let inputSchema = "ve1c1-swift-pool-input-v1"
    private static let outputSchema = "ve1c1-pilot-pool-v1"
    private static let samplingKey = "VE1-C1-SAMPLING-v1"
    private static let authorityCommit = "8daf78caa2bd5919cc911da21bae80fa3d12a248"
    private static let minimumContributingGames = 4
    private static let targetPositions = 16
    private static let perGameCap = 4
    private static let productionZeroCandidateMessage = "重要局面候補を抽出できません"

    private struct PoolInput: Decodable {
        let schemaVersion: String
        let samplingKey: String
        let corpusManifestSHA256: String
        let seededPlanSHA256: String
        let gameCount: Int
        let games: [InputGame]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case samplingKey = "sampling_key"
            case corpusManifestSHA256 = "corpus_manifest_sha256"
            case seededPlanSHA256 = "seeded_plan_sha256"
            case gameCount = "game_count"
            case games
        }
    }

    private struct InputGame: Decodable {
        let rank: Int
        let fileName: String
        let archiveMember: String
        let gameSHA256: String
        let gameSamplingSHA256: String
        let sourceID: String

        enum CodingKeys: String, CodingKey {
            case rank
            case fileName = "file_name"
            case archiveMember = "archive_member"
            case gameSHA256 = "game_sha256"
            case gameSamplingSHA256 = "game_sampling_sha256"
            case sourceID = "source_id"
        }
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let inputDirectory = documents.appendingPathComponent(inputDirectoryName, isDirectory: true)
            let inputURL = inputDirectory.appendingPathComponent("pool-input.json")
            let inputData = try Data(contentsOf: inputURL)
            let input = try JSONDecoder().decode(PoolInput.self, from: inputData)
            guard input.schemaVersion == inputSchema,
                  input.samplingKey == samplingKey,
                  input.gameCount == input.games.count,
                  input.games.map(\.rank) == Array(1...input.games.count) else {
                throw poolError(1, "invalid or non-contiguous pool input")
            }

            var poolGames: [[String: Any]] = []
            var trace: [[String: Any]] = []
            var contributingGames = 0
            var cappedPositionCount = 0

            for item in input.games {
                let fileURL = inputDirectory
                    .appendingPathComponent("games", isDirectory: true)
                    .appendingPathComponent(item.fileName)
                let raw = try Data(contentsOf: fileURL)
                guard sha256(raw) == item.gameSHA256 else {
                    throw poolError(2, "raw game SHA mismatch at rank \(item.rank)")
                }
                let game = try KIFParser.parse(data: raw)
                guard !game.moves.isEmpty else {
                    throw poolError(3, "parsed game has zero moves at rank \(item.rank)")
                }

                let shallow = ShallowAnalysisViewModel()
                await shallow.analyze(game: game, fileName: item.fileName)
                guard shallow.status == "浅解析 PASS",
                      shallow.entries.count == game.moves.count,
                      let shallowDiagnostic = shallow.diagnosticURL else {
                    throw poolError(4, "production shallow failed at rank \(item.rank): \(shallow.status)")
                }

                let deep = DeepAnalysisViewModel()
                await deep.analyze(
                    game: game,
                    shallowEntries: shallow.entries,
                    diagnosticURL: shallowDiagnostic,
                    deepMovetimeMs: 800,
                    multiPV: 3,
                    maxPositions: 5,
                    nodePolicy: .calibrationUnfrozen
                )

                let positions: [[String: Any]]
                let selectorOutcome: String
                switch deep.runState {
                case .completed:
                    guard deep.status == "深掘り PASS" else {
                        throw poolError(5, "production deep selector completed with unexpected status at rank \(item.rank): \(deep.status)")
                    }
                    positions = try deep.entries.map { entry in
                        guard let move = game.moves.first(where: { $0.ply == entry.ply }) else {
                            throw poolError(6, "selected ply missing from parsed game: \(entry.ply)")
                        }
                        return [
                            "ply": entry.ply,
                            "position_command": move.positionBefore,
                            "actual_move": move.usi,
                            "selected_by_production_deep_selector": true,
                            "selector_best_move": entry.bestMove,
                            "selector_stability_state": entry.stabilityState,
                            "selector_final_node_budget": entry.finalNodeBudget
                        ]
                    }
                    selectorOutcome = positions.isEmpty ? "NO_ELIGIBLE_POSITIONS" : "CANDIDATES_AVAILABLE"

                case .error(let message)
                    where message == productionZeroCandidateMessage && deep.entries.isEmpty:
                    // The frozen production view model represents a provisional-selector
                    // empty result as this exact error state. For the preregistered pool
                    // contract this is a valid zero-candidate game, not an engine failure.
                    positions = []
                    selectorOutcome = "NO_ELIGIBLE_POSITIONS"

                default:
                    throw poolError(5, "production deep selector failed at rank \(item.rank): \(deep.displayStatus)")
                }

                if !positions.isEmpty {
                    poolGames.append([
                        "game_sha256": item.gameSHA256,
                        "source_id": item.sourceID,
                        "archive_member": item.archiveMember,
                        "seed_rank": item.rank,
                        "game_sampling_sha256": item.gameSamplingSHA256,
                        "parsed_move_count": game.moves.count,
                        "positions": positions
                    ])
                    contributingGames += 1
                    cappedPositionCount += min(perGameCap, positions.count)
                }

                trace.append([
                    "seed_rank": item.rank,
                    "game_sha256": item.gameSHA256,
                    "parsed_move_count": game.moves.count,
                    "shallow_status": shallow.status,
                    "deep_status": deep.status,
                    "selector_outcome": selectorOutcome,
                    "production_selected_count": positions.count,
                    "production_selected_plies": positions.compactMap { $0["ply"] as? Int },
                    "per_game_capped_contribution": min(perGameCap, positions.count)
                ])

                if contributingGames >= minimumContributingGames,
                   cappedPositionCount >= targetPositions {
                    break
                }
            }

            guard contributingGames >= minimumContributingGames,
                  cappedPositionCount >= targetPositions else {
                throw poolError(
                    7,
                    "seeded corpus exhausted before 16-position eligibility: games=\(contributingGames) capped=\(cappedPositionCount)"
                )
            }

            let payload: [String: Any] = [
                "schema_version": outputSchema,
                "authority_commit": authorityCommit,
                "sampling_key": samplingKey,
                "corpus_manifest_sha256": input.corpusManifestSHA256,
                "seeded_plan_sha256": input.seededPlanSHA256,
                "selector_implementation": "actual_ShallowAnalysisViewModel_to_DeepAnalysisViewModel_to_DeepImportanceSelector",
                "production_selection_deep_movetime_compatibility_value": 800,
                "max_final_positions_per_game": 5,
                "stop_policy": "shortest_seeded_prefix_with_at_least_4_contributing_games_and_16_positions_after_cap4",
                "processed_game_count": trace.count,
                "candidate_producing_game_count": poolGames.count,
                "capped_eligible_position_count": cappedPositionCount,
                "games": poolGames,
                "selector_trace": trace
            ]
            let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: documents.appendingPathComponent(outputFileName), options: .atomic)
            SimulatorStage.mark("ve1c1_production_pool_complete_games_\(trace.count)_contributors_\(poolGames.count)_capped_\(cappedPositionCount)")
        } catch {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? (error.localizedDescription + "\n").write(
                to: documents.appendingPathComponent(errorFileName),
                atomically: true,
                encoding: .utf8
            )
            SimulatorStage.mark("ve1c1_production_pool_error_\(error.localizedDescription)")
            fflush(stdout)
            exit(42)
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func poolError(_ code: Int, _ message: String) -> NSError {
        NSError(
            domain: "ShogiCoach.VE1C1ProductionPool",
            code: code,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }
}
#endif
