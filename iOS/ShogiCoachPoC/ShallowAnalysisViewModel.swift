import Foundation
import ShogiCoachCore

struct ShallowAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let actualMove: String
    let bestMove: String
    let scoreText: String
    let blackPerspectiveCp: Int?
    let depthText: String
    let nodesText: String
    let npsText: String
    let pv: String
    let elapsedMs: Int

    var matchesBestMove: Bool { actualMove == bestMove }
}

@MainActor
final class ShallowAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ShallowAnalysisEntry] = []
    @Published private(set) var isRunning = false

    private let session = EngineUSISession()

    func reset() {
        status = "未解析"
        summary = ""
        entries = []
        isRunning = false
    }

    func analyze(game: KIFGame, movetimeMs: Int = 150) async {
        guard !game.moves.isEmpty else {
            status = "浅解析 未PASS"
            summary = "解析対象局面がありません"
            return
        }

        isRunning = true
        entries = []
        summary = ""
        status = "浅解析 準備中"
        SimulatorStage.reset()
        SimulatorStage.mark("shallow_start_count_\(game.moves.count)")

        let totalStarted = ContinuousClock.now

        do {
            try await session.beginAnalysis(multiPV: 1)

            var collected: [ShallowAnalysisEntry] = []
            collected.reserveCapacity(game.moves.count)

            for (index, move) in game.moves.enumerated() {
                let completed = index + 1
                status = "浅解析 \(completed)/\(game.moves.count)"
                SimulatorStage.mark("shallow_ply_\(move.ply)_start")

                let sample = try await session.analyzePosition(
                    command: move.positionBefore,
                    movetimeMs: movetimeMs
                )

                guard let primary = sample.result.principalVariations.first,
                      let score = primary.score,
                      !primary.pv.isEmpty else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "\(move.ply)手目のscore/PVが不足"
                    )
                }

                let scoreInfo = Self.scoreInfo(score, ply: move.ply)
                let entry = ShallowAnalysisEntry(
                    id: move.ply,
                    ply: move.ply,
                    actualMove: move.usi,
                    bestMove: sample.result.bestMove.move,
                    scoreText: scoreInfo.text,
                    blackPerspectiveCp: scoreInfo.blackCp,
                    depthText: primary.depth.map(String.init) ?? "-",
                    nodesText: primary.nodes.map(String.init) ?? "-",
                    npsText: primary.nps.map(String.init) ?? "-",
                    pv: primary.pv.joined(separator: " "),
                    elapsedMs: sample.elapsedMs
                )
                collected.append(entry)
                entries = collected

                SimulatorStage.mark(
                    "shallow_ply_\(move.ply)_done_best_\(entry.bestMove)_actual_\(entry.actualMove)"
                )

                if sample.thermalAfter == "critical" {
                    throw EngineUSISession.ProbeError.protocolError(
                        "thermal critical at ply \(move.ply)"
                    )
                }
            }

            await session.endAnalysis()

            let totalElapsedMs = Self.elapsedMilliseconds(
                from: totalStarted,
                to: ContinuousClock.now
            )
            let elapsed = collected.map(\.elapsedMs).sorted()
            let medianElapsed = elapsed[elapsed.count / 2]
            let bestMatchCount = collected.filter(\.matchesBestMove).count
            let cpCount = collected.compactMap(\.blackPerspectiveCp).count

            summary = [
                "positions: \(collected.count)/\(game.moves.count)",
                "shallow: \(movetimeMs) ms/position",
                "total elapsed: \(totalElapsedMs) ms",
                "median elapsed: \(medianElapsed) ms",
                "bestmove match: \(bestMatchCount)/\(collected.count)",
                "cp scores: \(cpCount)/\(collected.count)",
                "first: #\(collected.first?.ply ?? 0) \(collected.first?.scoreText ?? "-")",
                "last: #\(collected.last?.ply ?? 0) \(collected.last?.scoreText ?? "-")"
            ].joined(separator: "\n")

            SimulatorStage.mark("shallow_complete_\(collected.count)")
            status = "浅解析 PASS"
        } catch {
            await session.endAnalysis()
            SimulatorStage.mark("shallow_error_\(error.localizedDescription)")
            status = "浅解析 未PASS"
            summary = [
                "completed: \(entries.count)/\(game.moves.count)",
                error.localizedDescription
            ].joined(separator: "\n")
        }

        isRunning = false
    }

    private static func scoreInfo(_ score: USIScore, ply: Int) -> (text: String, blackCp: Int?) {
        switch score {
        case .centipawn(let value, _):
            let blackValue = ply.isMultiple(of: 2) ? -value : value
            return ("cp \(value)", blackValue)
        case .mate(let value, _):
            return ("mate \(value)", nil)
        }
    }

    private static func elapsedMilliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Int {
        let components = start.duration(to: end).components
        return Int(components.seconds * 1000)
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }
}
