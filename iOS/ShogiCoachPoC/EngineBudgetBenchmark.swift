import Foundation
import ShogiCoachCore

struct EngineBudgetAdaptiveBaseline {
    let bestMove: String
    let scoreText: String
    let depthText: String
    let nodesText: String
    let pvLength: Int
    let pvMoves: [String]
    let stable: Bool
    let attempts: Int
    let finalMovetimeMs: Int
    let totalElapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
}

struct EngineBudgetBenchmarkSample {
    let label: String
    let sourcePly: Int
    let nodeBudget: Int
    let bestMove: String
    let scoreText: String
    let depth: Int?
    let searchedNodes: UInt64
    let nps: UInt64?
    let pvLength: Int
    let pvMoves: [String]
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let budgetReached: Bool
    let terminationReason: String

    var nodeRatioPercent: Int {
        guard nodeBudget > 0 else { return 0 }
        return Int((Double(searchedNodes) / Double(nodeBudget) * 100.0).rounded())
    }
}

struct EngineBudgetBenchmarkResult {
    let label: String
    let sourcePly: Int
    let adaptiveBaseline: EngineBudgetAdaptiveBaseline
    let samples: [EngineBudgetBenchmarkSample]

    var stableFromEightHundredKToTwoMillion: Bool? {
        stableBestMove(from: 800_000, to: 2_000_000)
    }

    var stableFromTwoMillionToFourMillion: Bool? {
        stableBestMove(from: 2_000_000, to: 4_000_000)
    }

    var scoreDeltaEightHundredKToTwoMillion: Int? {
        scoreDelta(from: 800_000, to: 2_000_000)
    }

    var scoreDeltaTwoMillionToFourMillion: Int? {
        scoreDelta(from: 2_000_000, to: 4_000_000)
    }

    var commonPVPrefixEightHundredKToTwoMillion: Int? {
        commonPVPrefix(from: 800_000, to: 2_000_000)
    }

    var commonPVPrefixTwoMillionToFourMillion: Int? {
        commonPVPrefix(from: 2_000_000, to: 4_000_000)
    }

    var commonPVPrefixAdaptiveToFourMillion: Int? {
        guard let four = samples.first(where: { $0.nodeBudget == 4_000_000 }) else {
            return nil
        }
        return Self.commonPrefixCount(adaptiveBaseline.pvMoves, four.pvMoves)
    }

    private func stableBestMove(from leftBudget: Int, to rightBudget: Int) -> Bool? {
        guard let left = samples.first(where: { $0.nodeBudget == leftBudget }),
              let right = samples.first(where: { $0.nodeBudget == rightBudget }) else {
            return nil
        }
        return left.bestMove == right.bestMove
    }

    private func scoreDelta(from leftBudget: Int, to rightBudget: Int) -> Int? {
        guard let left = samples.first(where: { $0.nodeBudget == leftBudget }),
              let right = samples.first(where: { $0.nodeBudget == rightBudget }) else {
            return nil
        }
        return Self.centipawn(left.scoreText).flatMap { leftCP in
            Self.centipawn(right.scoreText).map { abs(leftCP - $0) }
        }
    }

    private func commonPVPrefix(from leftBudget: Int, to rightBudget: Int) -> Int? {
        guard let left = samples.first(where: { $0.nodeBudget == leftBudget }),
              let right = samples.first(where: { $0.nodeBudget == rightBudget }) else {
            return nil
        }
        return Self.commonPrefixCount(left.pvMoves, right.pvMoves)
    }

    private static func commonPrefixCount(_ lhs: [String], _ rhs: [String]) -> Int {
        var count = 0
        for pair in zip(lhs, rhs) {
            guard pair.0 == pair.1 else { break }
            count += 1
        }
        return count
    }

    private static func centipawn(_ text: String) -> Int? {
        let pieces = text.split(separator: " ")
        guard pieces.count == 2, pieces[0] == "cp" else { return nil }
        return Int(pieces[1])
    }
}

enum EngineBudgetBenchmark {
    static let nodeBudgets = [800_000, 2_000_000, 4_000_000]

    static func run(
        positions: [(label: String, ply: Int, command: String, actualMove: String)],
        multiPV: Int = 3
    ) async throws -> [EngineBudgetBenchmarkResult] {
        var results: [EngineBudgetBenchmarkResult] = []
        results.reserveCapacity(positions.count)

        for position in positions {
            let adaptiveBaseline = try await runAdaptiveBaseline(
                command: position.command,
                actualMove: position.actualMove,
                multiPV: multiPV
            )
            var samples: [EngineBudgetBenchmarkSample] = []

            for budget in nodeBudgets {
                let session = EngineUSISession()
                try await session.beginAnalysis(multiPV: multiPV)
                do {
                    let sample = try await session.analyzePosition(
                        command: position.command,
                        nodes: budget,
                        multiPV: multiPV
                    )
                    await session.endAnalysis()

                    guard let primary = sample.result.principalVariations.first,
                          let score = primary.score,
                          let bestMove = primary.pv.first,
                          let searchedNodes = primary.nodes,
                          !primary.pv.isEmpty else {
                        throw EngineUSISession.ProbeError.protocolError(
                            "node benchmark missing primary PV/nodes"
                        )
                    }

                    let budgetReached = searchedNodes >= UInt64(budget * 9 / 10)
                    let terminationReason = Self.terminationReason(
                        score: score,
                        bestMove: sample.result.bestMove.move,
                        budgetReached: budgetReached
                    )

                    if !budgetReached && terminationReason == "early_non_mate" {
                        throw EngineUSISession.ProbeError.protocolError(
                            "node benchmark unexplained early stop: \(position.label) ply=\(position.ply) target=\(budget) actual=\(searchedNodes)"
                        )
                    }

                    samples.append(
                        .init(
                            label: position.label,
                            sourcePly: position.ply,
                            nodeBudget: budget,
                            bestMove: bestMove,
                            scoreText: AdaptiveComparisonAnalyzer.scoreText(score),
                            depth: primary.depth,
                            searchedNodes: searchedNodes,
                            nps: primary.nps,
                            pvLength: primary.pv.count,
                            pvMoves: primary.pv,
                            elapsedMs: sample.elapsedMs,
                            thermalBefore: sample.thermalBefore,
                            thermalAfter: sample.thermalAfter,
                            budgetReached: budgetReached,
                            terminationReason: terminationReason
                        )
                    )
                } catch {
                    await session.endAnalysis()
                    throw error
                }
            }

            results.append(
                EngineBudgetBenchmarkResult(
                    label: position.label,
                    sourcePly: position.ply,
                    adaptiveBaseline: adaptiveBaseline,
                    samples: samples
                )
            )
        }
        return results
    }

    static func reportLines(
        _ results: [EngineBudgetBenchmarkResult]
    ) -> [String] {
        let samples = results.flatMap(\.samples)
        let reachedCount = samples.filter(\.budgetReached).count
        let naturalEarlyCount = samples.filter {
            !$0.budgetReached && $0.terminationReason != "early_non_mate"
        }.count
        let unexplainedEarlyCount = samples.filter {
            $0.terminationReason == "early_non_mate"
        }.count

        var lines = [
            "budget_benchmark_status=PASS",
            "budget_benchmark_positions=\(results.count)",
            "budget_benchmark_adaptive_baselines=\(results.count)",
            "budget_benchmark_samples=\(samples.count)",
            "budget_benchmark_multipv=3",
            "budget_benchmark_budget_reached_samples=\(reachedCount)",
            "budget_benchmark_natural_early_samples=\(naturalEarlyCount)",
            "budget_benchmark_early_non_mate_samples=\(unexplainedEarlyCount)"
        ]

        for result in results {
            lines.append("budget_\(result.label)_source_ply=\(result.sourcePly)")
            let baselinePrefix = "budget_\(result.label)_adaptive"
            let baseline = result.adaptiveBaseline
            lines.append("\(baselinePrefix)_bestmove=\(baseline.bestMove)")
            lines.append("\(baselinePrefix)_score=\(baseline.scoreText)")
            lines.append("\(baselinePrefix)_depth=\(baseline.depthText)")
            lines.append("\(baselinePrefix)_nodes=\(baseline.nodesText)")
            lines.append("\(baselinePrefix)_pv_plies=\(baseline.pvLength)")
            lines.append("\(baselinePrefix)_pv=\(baseline.pvMoves.joined(separator: " "))")
            lines.append("\(baselinePrefix)_stable=\(baseline.stable)")
            lines.append("\(baselinePrefix)_attempts=\(baseline.attempts)")
            lines.append("\(baselinePrefix)_final_movetime_ms=\(baseline.finalMovetimeMs)")
            lines.append("\(baselinePrefix)_elapsed_ms=\(baseline.totalElapsedMs)")
            lines.append("\(baselinePrefix)_thermal_before=\(baseline.thermalBefore)")
            lines.append("\(baselinePrefix)_thermal_after=\(baseline.thermalAfter)")

            for sample in result.samples {
                let prefix = "budget_\(result.label)_\(sample.nodeBudget)"
                lines.append("\(prefix)_bestmove=\(sample.bestMove)")
                lines.append("\(prefix)_score=\(sample.scoreText)")
                lines.append("\(prefix)_depth=\(sample.depth.map(String.init) ?? "-")")
                lines.append("\(prefix)_nodes=\(sample.searchedNodes)")
                lines.append("\(prefix)_node_ratio_pct=\(sample.nodeRatioPercent)")
                lines.append("\(prefix)_budget_reached=\(sample.budgetReached)")
                lines.append("\(prefix)_termination=\(sample.terminationReason)")
                lines.append("\(prefix)_nps=\(sample.nps.map(String.init) ?? "-")")
                lines.append("\(prefix)_pv_plies=\(sample.pvLength)")
                lines.append("\(prefix)_pv=\(sample.pvMoves.joined(separator: " "))")
                lines.append("\(prefix)_elapsed_ms=\(sample.elapsedMs)")
                lines.append("\(prefix)_thermal_before=\(sample.thermalBefore)")
                lines.append("\(prefix)_thermal_after=\(sample.thermalAfter)")
            }

            if let stable = result.stableFromEightHundredKToTwoMillion {
                lines.append(
                    "budget_\(result.label)_800k_2m_bestmove_stable=\(stable)"
                )
            }
            if let stable = result.stableFromTwoMillionToFourMillion {
                lines.append(
                    "budget_\(result.label)_2m_4m_bestmove_stable=\(stable)"
                )
            }
            lines.append(
                "budget_\(result.label)_800k_2m_score_delta_cp="
                    + (result.scoreDeltaEightHundredKToTwoMillion.map(String.init) ?? "-")
            )
            lines.append(
                "budget_\(result.label)_2m_4m_score_delta_cp="
                    + (result.scoreDeltaTwoMillionToFourMillion.map(String.init) ?? "-")
            )
            lines.append(
                "budget_\(result.label)_800k_2m_common_pv_prefix="
                    + (result.commonPVPrefixEightHundredKToTwoMillion.map(String.init) ?? "-")
            )
            lines.append(
                "budget_\(result.label)_2m_4m_common_pv_prefix="
                    + (result.commonPVPrefixTwoMillionToFourMillion.map(String.init) ?? "-")
            )
            lines.append(
                "budget_\(result.label)_adaptive_4m_common_pv_prefix="
                    + (result.commonPVPrefixAdaptiveToFourMillion.map(String.init) ?? "-")
            )
        }
        return lines
    }

    private static func runAdaptiveBaseline(
        command: String,
        actualMove: String,
        multiPV: Int
    ) async throws -> EngineBudgetAdaptiveBaseline {
        let session = EngineUSISession()
        try await session.beginAnalysis(multiPV: multiPV)
        do {
            let result = try await AdaptiveComparisonAnalyzer.analyze(
                session: session,
                command: command,
                actualMove: actualMove,
                baseMovetimeMs: 800,
                candidateCount: multiPV
            )
            await session.endAnalysis()

            let final = result.finalAttempt
            return EngineBudgetAdaptiveBaseline(
                bestMove: final.bestLine.move,
                scoreText: final.bestLine.scoreText,
                depthText: final.bestLine.depthText,
                nodesText: final.bestLine.nodesText,
                pvLength: final.bestLine.pvMoves.count,
                pvMoves: final.bestLine.pvMoves,
                stable: result.stable,
                attempts: result.attempts.count,
                finalMovetimeMs: result.finalMovetimeMs,
                totalElapsedMs: result.totalElapsedMs,
                thermalBefore: result.attempts.first?.thermalBefore ?? "unknown",
                thermalAfter: final.thermalAfter
            )
        } catch {
            await session.endAnalysis()
            throw error
        }
    }

    private static func terminationReason(
        score: USIScore,
        bestMove: String,
        budgetReached: Bool
    ) -> String {
        if budgetReached {
            return "budget_reached"
        }
        if case .mate = score {
            return "mate"
        }
        if ["resign", "win", "none"].contains(bestMove) {
            return "special_bestmove"
        }
        return "early_non_mate"
    }
}
