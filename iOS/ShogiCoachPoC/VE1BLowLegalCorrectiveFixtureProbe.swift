import Foundation

#if targetEnvironment(simulator)

enum VE1BLowLegalCorrectiveFixtureProbe {
    private static let argument = "--ci-ve1b-low-legal-corrective-fixture"

    private struct Input: Decodable {
        let schemaVersion: Int
        let authorityParent: String
        let configuredMultiPV: Int
        let nodeBudget: Int
        let safetyCeilingMs: Int
        let rootMoveGenerator: String
        let fixtures: [Fixture]

        enum CodingKeys: String, CodingKey {
            case schemaVersion = "schema_version"
            case authorityParent = "authority_parent"
            case configuredMultiPV = "configured_multi_pv"
            case nodeBudget = "node_budget"
            case safetyCeilingMs = "safety_ceiling_ms"
            case rootMoveGenerator = "root_move_generator"
            case fixtures
        }
    }

    private struct Fixture: Decodable {
        let id: String
        let positionCommand: String
        let expectedLegalRootMoveCount: Int
        let expectedLegalAllMoveCount: Int
        let expectedEffectiveRequiredMultiPV: Int

        enum CodingKeys: String, CodingKey {
            case id
            case positionCommand = "position_command"
            case expectedLegalRootMoveCount = "expected_legal_root_move_count"
            case expectedLegalAllMoveCount = "expected_legal_all_move_count"
            case expectedEffectiveRequiredMultiPV = "expected_effective_required_multi_pv"
        }
    }

    private struct FixtureResult: Codable {
        let id: String
        let positionCommand: String
        let configuredMultiPV: Int
        let expectedLegalRootMoveCount: Int
        let legalRootMoveCount: Int?
        let expectedEffectiveRequiredMultiPV: Int
        let effectiveRequiredMultiPV: Int
        let completion: String
        let adoptedSnapshotRankCount: Int
        let adoptedSnapshotRanks: [Int]
        let selectedDepth: Int?
        let maxObservedNodes: UInt64
        let nodeBudget: Int
        let issuedGoCommand: String
        let rawUSIInfoLines: [String]
        let terminalBestMove: String?
        let terminalPonderMove: String?
        let passed: Bool
        let failureReasons: [String]
    }

    private struct Report: Codable {
        let schemaVersion: Int
        let status: String
        let authorityParent: String
        let rootMoveGenerator: String
        let configuredMultiPV: Int
        let nodeBudget: Int
        let safetyCeilingMs: Int
        let fixtureCount: Int
        let fixtures: [FixtureResult]
        let failureReasons: [String]
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inputURL = directory.appendingPathComponent("ve1b-low-legal-corrective-fixture-input.json")
        let outputURL = directory.appendingPathComponent("ve1b-low-legal-corrective-fixture.json")
        let errorURL = directory.appendingPathComponent("ve1b-low-legal-corrective-fixture-error.txt")

        do {
            let input = try JSONDecoder().decode(Input.self, from: Data(contentsOf: inputURL))
            guard input.schemaVersion == 1,
                  input.authorityParent == "8daf78caa2bd5919cc911da21bae80fa3d12a248",
                  input.configuredMultiPV == 3,
                  input.nodeBudget == 50000,
                  input.safetyCeilingMs == 10000,
                  input.rootMoveGenerator == "YaneuraOu MoveList<LEGAL>",
                  input.fixtures.count == 4 else {
                throw EngineUSISession.ProbeError.protocolError("corrective fixture input contract mismatch")
            }

            let session = EngineUSISession()
            try await session.beginAnalysis(multiPV: input.configuredMultiPV)
            var results: [FixtureResult] = []
            var allFailures: [String] = []

            do {
                for (index, fixture) in input.fixtures.enumerated() {
                    _ = try await session.resetForColdSeries(reason: "low_legal_fixture_\(index + 1)")
                    let sample = try await session.analyzePositionNodes(
                        command: fixture.positionCommand,
                        nodeBudget: input.nodeBudget,
                        safetyCeilingMs: input.safetyCeilingMs,
                        role: .diagnostic,
                        searchMoves: [],
                        multiPV: input.configuredMultiPV
                    )

                    var reasons: [String] = []
                    if sample.configuredMultiPV != input.configuredMultiPV {
                        reasons.append("CONFIGURED_MULTIPV_\(sample.configuredMultiPV)")
                    }
                    if sample.legalRootMoveCount != fixture.expectedLegalRootMoveCount {
                        reasons.append("LEGAL_ROOT_\(sample.legalRootMoveCount.map(String.init) ?? "nil")")
                    }
                    if sample.effectiveRequiredMultiPV != fixture.expectedEffectiveRequiredMultiPV {
                        reasons.append("EFFECTIVE_REQUIRED_\(sample.effectiveRequiredMultiPV)")
                    }
                    if sample.completion != .nodeBudgetReached {
                        reasons.append("COMPLETION_\(sample.completion.rawValue)")
                    }
                    let snapshot = sample.result?.principalVariations ?? []
                    let snapshotRanks = snapshot.map(\.multipv).sorted()
                    let expectedRanks = Array(1...sample.effectiveRequiredMultiPV)
                    if snapshot.count != sample.effectiveRequiredMultiPV {
                        reasons.append("SNAPSHOT_RANK_COUNT_\(snapshot.count)")
                    }
                    if snapshotRanks != expectedRanks {
                        reasons.append("SNAPSHOT_RANKS_\(snapshotRanks.map(String.init).joined(separator: "_"))")
                    }
                    if sample.maxObservedNodes < UInt64(input.nodeBudget) {
                        reasons.append("MAX_NODES_\(sample.maxObservedNodes)")
                    }

                    let rawInfoLines = sample.observations.compactMap(\.rawLine)
                    if rawInfoLines.isEmpty {
                        reasons.append("RAW_USI_INFO_EMPTY")
                    }
                    if sample.terminalResult == nil {
                        reasons.append("TERMINAL_BESTMOVE_MISSING")
                    }

                    let prefixed = reasons.map { "\(fixture.id):\($0)" }
                    allFailures.append(contentsOf: prefixed)
                    results.append(
                        FixtureResult(
                            id: fixture.id,
                            positionCommand: fixture.positionCommand,
                            configuredMultiPV: sample.configuredMultiPV,
                            expectedLegalRootMoveCount: fixture.expectedLegalRootMoveCount,
                            legalRootMoveCount: sample.legalRootMoveCount,
                            expectedEffectiveRequiredMultiPV: fixture.expectedEffectiveRequiredMultiPV,
                            effectiveRequiredMultiPV: sample.effectiveRequiredMultiPV,
                            completion: sample.completion.rawValue,
                            adoptedSnapshotRankCount: snapshot.count,
                            adoptedSnapshotRanks: snapshotRanks,
                            selectedDepth: snapshot.first?.depth,
                            maxObservedNodes: sample.maxObservedNodes,
                            nodeBudget: sample.nodeBudget,
                            issuedGoCommand: sample.issuedGoCommand,
                            rawUSIInfoLines: rawInfoLines,
                            terminalBestMove: sample.terminalResult?.bestMove.move,
                            terminalPonderMove: sample.terminalResult?.bestMove.ponder,
                            passed: reasons.isEmpty,
                            failureReasons: reasons
                        )
                    )
                }
                await session.endAnalysis()
            } catch {
                await session.endAnalysis()
                throw error
            }

            let report = Report(
                schemaVersion: 1,
                status: allFailures.isEmpty ? "PASS" : "FAIL",
                authorityParent: input.authorityParent,
                rootMoveGenerator: input.rootMoveGenerator,
                configuredMultiPV: input.configuredMultiPV,
                nodeBudget: input.nodeBudget,
                safetyCeilingMs: input.safetyCeilingMs,
                fixtureCount: results.count,
                fixtures: results,
                failureReasons: allFailures
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(report).write(to: outputURL, options: .atomic)
            if report.status != "PASS" {
                try allFailures.joined(separator: "\n").write(to: errorURL, atomically: true, encoding: .utf8)
            }
        } catch {
            try? String(describing: error).write(to: errorURL, atomically: true, encoding: .utf8)
        }
    }
}

#endif
