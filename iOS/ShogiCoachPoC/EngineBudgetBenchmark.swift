import Foundation
import ShogiCoachCore

struct EngineBudgetBenchmarkSample {
    let label: String
    let nodeBudget: Int
    let bestMove: String
    let scoreText: String
    let depth: Int?
    let searchedNodes: UInt64?
    let nps: UInt64?
    let pvLength: Int
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
}

struct EngineBudgetBenchmarkResult {
    let label: String
    let samples: [EngineBudgetBenchmarkSample]

    var stableFromTwoMillionToFourMillion: Bool? {
        guard let two = samples.first(where: { $0.nodeBudget == 2_000_000 }),
              let four = samples.first(where: { $0.nodeBudget == 4_000_000 }) else {
            return nil
        }
        return two.bestMove == four.bestMove
    }

    var scoreDeltaTwoMillionToFourMillion: Int? {
        guard let two = samples.first(where: { $0.nodeBudget == 2_000_000 }),
              let four = samples.first(where: { $0.nodeBudget == 4_000_000 }) else {
            return nil
        }
        return Self.centipawn(two.scoreText).flatMap { left in
            Self.centipawn(four.scoreText).map { abs(left - $0) }
        }
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
        positions: [(label: String, command: String)],
        multiPV: Int = 3
    ) async throws -> [EngineBudgetBenchmarkResult] {
        var results: [EngineBudgetBenchmarkResult] = []
        results.reserveCapacity(positions.count)

        for position in positions {
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
                          !primary.pv.isEmpty else {
                        throw EngineUSISession.ProbeError.protocolError(
                            "node benchmark missing primary PV"
                        )
                    }

                    if let searchedNodes = primary.nodes,
                       searchedNodes < UInt64(budget * 9 / 10) {
                        throw EngineUSISession.ProbeError.protocolError(
                            "node benchmark stopped early: \(position.label) target=\(budget) actual=\(searchedNodes)"
                        )
                    }

                    samples.append(
                        .init(
                            label: position.label,
                            nodeBudget: budget,
                            bestMove: bestMove,
                            scoreText: AdaptiveComparisonAnalyzer.scoreText(score),
                            depth: primary.depth,
                            searchedNodes: primary.nodes,
                            nps: primary.nps,
                            pvLength: primary.pv.count,
                            elapsedMs: sample.elapsedMs,
                            thermalBefore: sample.thermalBefore,
                            thermalAfter: sample.thermalAfter
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
                    samples: samples
                )
            )
        }
        return results
    }

    static func reportLines(
        _ results: [EngineBudgetBenchmarkResult]
    ) -> [String] {
        var lines = [
            "budget_benchmark_status=PASS",
            "budget_benchmark_positions=\(results.count)",
            "budget_benchmark_samples=\(results.reduce(0) { $0 + $1.samples.count })",
            "budget_benchmark_multipv=3"
        ]

        for result in results {
            for sample in result.samples {
                let prefix = "budget_\(result.label)_\(sample.nodeBudget)"
                lines.append("\(prefix)_bestmove=\(sample.bestMove)")
                lines.append("\(prefix)_score=\(sample.scoreText)")
                lines.append("\(prefix)_depth=\(sample.depth.map(String.init) ?? "-")")
                lines.append("\(prefix)_nodes=\(sample.searchedNodes.map(String.init) ?? "-")")
                lines.append("\(prefix)_nps=\(sample.nps.map(String.init) ?? "-")")
                lines.append("\(prefix)_pv_plies=\(sample.pvLength)")
                lines.append("\(prefix)_elapsed_ms=\(sample.elapsedMs)")
                lines.append("\(prefix)_thermal_before=\(sample.thermalBefore)")
                lines.append("\(prefix)_thermal_after=\(sample.thermalAfter)")
            }

            if let stable = result.stableFromTwoMillionToFourMillion {
                lines.append(
                    "budget_\(result.label)_2m_4m_bestmove_stable=\(stable)"
                )
            }
            lines.append(
                "budget_\(result.label)_2m_4m_score_delta_cp="
                    + (result.scoreDeltaTwoMillionToFourMillion.map(String.init) ?? "-")
            )
        }
        return lines
    }
}
