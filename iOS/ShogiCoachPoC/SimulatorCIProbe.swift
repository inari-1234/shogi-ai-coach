import Foundation
import ShogiCoachCore

enum SimulatorStage {
    #if targetEnvironment(simulator)
    private static let lock = NSLock()

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-stage.txt")
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url)
    }

    static func mark(_ value: String) {
        lock.lock()
        defer { lock.unlock() }

        let safe = value
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(240)
        let line = "\(Date().timeIntervalSince1970) \(safe)\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func latest() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text.split(separator: "\n").last.map(String.init)
    }
    #else
    static func reset() {}
    static func mark(_ value: String) {}
    static func latest() -> String? { nil }
    #endif
}

#if targetEnvironment(simulator)
import Darwin
@MainActor
final class EngineProbe: ObservableObject {
    @Published private(set) var status = "未実行"
    @Published private(set) var resultText = ""

    private let session = EngineUSISession()

    init() {
        if let previous = SimulatorStage.latest() {
            resultText = "前回の最終到達点:\n\(previous)"
        }
    }

    func runDefaultProbe() async {
        SimulatorStage.reset()
        SimulatorStage.mark("default_button_pressed")
        status = "解析中"
        resultText = ""
        do {
            let sfen = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
            let result = try await session.run(sfen: sfen, movetimeMs: 1500, multiPV: 1)
            SimulatorStage.mark("default_probe_complete")
            resultText = Self.format(result)
            status = "PASS候補"
        } catch {
            SimulatorStage.mark("default_probe_error_\(error.localizedDescription)")
            status = "未PASS"
            resultText = error.localizedDescription
        }
    }

    func runTenProbe() async {
        SimulatorStage.reset()
        SimulatorStage.mark("ten_probe_button_pressed")
        status = "10回連続解析中"
        resultText = ""
        let sfen = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
        var samples: [ProbeSample] = []
        do {
            for i in 1...10 {
                let sample = try await session.run(sfen: sfen, movetimeMs: 1500, multiPV: 1)
                samples.append(sample)
                status = "10回連続解析中 \(i)/10"
            }
            let elapsed = samples.map(\.elapsedMs).sorted()
            let median = elapsed[elapsed.count / 2]
            let maxMemory = samples.compactMap(\.memoryBytesAfter).max()
            let last = samples.last!
            resultText = [
                "10/10 completed",
                "median elapsed: \(median) ms",
                "last bestmove: \(last.result.bestMove.move)",
                "last nps: \(last.result.principalVariations.first?.nps.map(String.init) ?? "-")",
                "max footprint: \(maxMemory.map(Self.byteText) ?? "-")",
                "thermal: \(samples.first?.thermalBefore ?? "-") -> \(last.thermalAfter)"
            ].joined(separator: "\n")
            SimulatorStage.mark("ten_probe_complete")
            status = last.thermalAfter == "critical" ? "未PASS" : "実機PASS候補"
        } catch {
            SimulatorStage.mark("ten_probe_error_\(error.localizedDescription)")
            status = "未PASS"
            resultText = "\(samples.count)/10 completed\n\(error.localizedDescription)"
        }
    }

    private static func format(_ sample: ProbeSample) -> String {
        let primary = sample.result.principalVariations.first
        return [
            "bestmove: \(sample.result.bestMove.move)",
            "score: \(scoreText(primary?.score))",
            "depth: \(primary?.depth.map(String.init) ?? "-")",
            "nodes: \(primary?.nodes.map(String.init) ?? "-")",
            "nps: \(primary?.nps.map(String.init) ?? "-")",
            "pv: \(primary?.pv.joined(separator: " ") ?? "-")",
            "elapsed: \(sample.elapsedMs) ms",
            "footprint: \(sample.memoryBytesAfter.map(byteText) ?? "-")",
            "thermal: \(sample.thermalBefore) -> \(sample.thermalAfter)"
        ].joined(separator: "\n")
    }

    private static func scoreText(_ score: USIScore?) -> String {
        guard let score else { return "-" }
        switch score {
        case .centipawn(let value, _): return "cp \(value)"
        case .mate(let value, _): return "mate \(value)"
        }
    }

    private static func byteText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}



@MainActor
enum SimulatorCIProbe {
    private static func writeReport(_ text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-probe.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func runKIFSelfTest() throws -> KIFGame {
        let sample = """
        手合割：平手
        1 ７六歩(77)
        2 ３四歩(33)
        3 ２六歩(27)
        4 ８四歩(83)
        5 投了
        """
        let game = try KIFParser.parse(sample)
        guard game.moves.map(\.usi) == ["7g7f", "3c3d", "2g2f", "8c8d"],
              game.termination == "投了" else {
            throw NSError(
                domain: "ShogiCoach.KIFCI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "KIF self-test mismatch"]
            )
        }
        return game
    }

    private static func makeTerminalRegression() -> (KIFGame, [ShallowAnalysisEntry]) {
        let moveText = "7g7f 3c3d 2g2f 8c8d 6g6f 2b3c 2h6h 3a3b 5i4h 6a5b 4h3h 5a4b 3h2h 7a6b 1g1f 8d8e 8h7g 3c4d 2h2g 2a3c 3i3h 2c2d 7i7h 8b8d 6i5h 3b2c 9i9h 5c5d 6f6e 8d8b 4g4f 1c1d 5h4g 4b3a 2g2h 6b5c 4f4e 4d7g+ 7h7g 4a3b 1i1h B*3e 3g3f 3e2f 3h2g 2d2e 2i3g 3a2b 4i3h 9c9d 6h6i 8a9c 6i2i 2c2d B*4f 3d3e 3f3e 3b2c 4g3f P*3d 2g2f 2e2f 3e3d S*2g 3h2g 2f2g+ 2h2g 1d1e 1f1e 1a1e P*2e 2c3d 2e2d 1e1h+ B*1d G*1c S*2c 1c2c 1d2c+ 2b1a G*1b"
        let usiMoves = moveText.split(separator: " ").map(String.init)
        var prefix: [String] = []
        var moves: [KIFMove] = []
        var shallow: [ShallowAnalysisEntry] = []

        for (index, usi) in usiMoves.enumerated() {
            let ply = index + 1
            let positionBefore = prefix.isEmpty
                ? "position startpos"
                : "position startpos moves " + prefix.joined(separator: " ")
            moves.append(
                KIFMove(
                    ply: ply,
                    notation: usi,
                    usi: usi,
                    positionBefore: positionBefore
                )
            )

            let isFinal = ply == 81
            let bestMove = isFinal ? "S*2b" : usi
            shallow.append(
                ShallowAnalysisEntry(
                    id: ply,
                    ply: ply,
                    actualMove: usi,
                    bestMove: bestMove,
                    scoreText: isFinal ? "mate 1" : "cp 0",
                    blackPerspectiveCp: isFinal ? nil : 0,
                    depthText: "-",
                    nodesText: "-",
                    npsText: "-",
                    pv: bestMove,
                    elapsedMs: 1,
                    thermalBefore: "nominal",
                    thermalAfter: "nominal"
                )
            )
            prefix.append(usi)
        }

        let game = KIFGame(
            metadata: [
                "手合割": "平手",
                "先手": "あなた",
                "後手": "CPU"
            ],
            moves: moves,
            termination: "詰み"
        )
        return (game, shallow)
    }

    private struct AnalysisQualityGateResult {
        let normalStable: Bool
        let normalComparisonStable: Bool
        let normalContinuationStable: Bool
        let normalAttempts: Int
        let closeGapCp: Int?
        let closeAttempts: Int
        let terminalStable: Bool
        let terminalComparisonStable: Bool
        let terminalContinuationStable: Bool
        let terminalAttempts: Int
        let terminalBestMove: String
    }

    private static func runAnalysisQualityGate(
        terminalGame: KIFGame
    ) async throws -> AnalysisQualityGateResult {
        guard AdaptiveComparisonAnalyzer.analysisTiers(baseMovetimeMs: 800) == [800, 1600, 2400] else {
            throw EngineUSISession.ProbeError.protocolError("adaptive tier policy mismatch")
        }
        guard terminalGame.moves.count >= 81,
              let terminalMove = terminalGame.moves.last else {
            throw EngineUSISession.ProbeError.protocolError("quality gate positions missing")
        }

        let session = EngineUSISession()
        try await session.beginAnalysis(multiPV: 3)
        do {
            let normalMove = terminalGame.moves[40]
            let normal = try await AdaptiveComparisonAnalyzer.analyze(
                session: session,
                command: normalMove.positionBefore,
                actualMove: normalMove.usi,
                baseMovetimeMs: 800,
                candidateCount: 3
            )
            let normalFinal = normal.finalAttempt
            let normalPVUsable = normalFinal.bestLine.pvMoves.count >= 4
                && normalFinal.actualLine.pvMoves.count >= 3
            let normalExplicitlyUnstableForPV = normal.continuationInstabilityReasons.contains("best_pv_short")
                || normal.continuationInstabilityReasons.contains("actual_pv_short")
            guard !normalFinal.bestLine.pvMoves.isEmpty,
                  !normalFinal.actualLine.pvMoves.isEmpty,
                  normalPVUsable || normalExplicitlyUnstableForPV else {
                throw EngineUSISession.ProbeError.protocolError(
                    "normal quality position lacks usable PV without instability flag"
                )
            }

            let close = try await AdaptiveComparisonAnalyzer.analyze(
                session: session,
                command: "position startpos",
                actualMove: "7g7f",
                baseMovetimeMs: 800,
                candidateCount: 3
            )
            if let gap = close.attempts.first?.topGapCp,
               gap <= 40,
               close.attempts.count < 2 {
                throw EngineUSISession.ProbeError.protocolError(
                    "close candidates did not trigger adaptive extension"
                )
            }

            let terminal = try await AdaptiveComparisonAnalyzer.analyze(
                session: session,
                command: terminalMove.positionBefore,
                actualMove: terminalMove.usi,
                baseMovetimeMs: 800,
                candidateCount: 3
            )
            let terminalFinal = terminal.finalAttempt
            guard terminalMove.usi == "G*1b",
                  terminalFinal.actualLine.move == terminalMove.usi,
                  terminalFinal.actualLine.pvMoves.first == terminalMove.usi,
                  !terminalFinal.bestLine.pvMoves.isEmpty else {
                throw EngineUSISession.ProbeError.protocolError(
                    "terminal/drop quality position regression"
                )
            }

            await session.endAnalysis()
            return AnalysisQualityGateResult(
                normalStable: normal.stable,
                normalComparisonStable: normal.comparisonStable,
                normalContinuationStable: normal.continuationStable,
                normalAttempts: normal.attempts.count,
                closeGapCp: close.attempts.first?.topGapCp,
                closeAttempts: close.attempts.count,
                terminalStable: terminal.stable,
                terminalComparisonStable: terminal.comparisonStable,
                terminalContinuationStable: terminal.continuationStable,
                terminalAttempts: terminal.attempts.count,
                terminalBestMove: terminalFinal.bestLine.move
            )
        } catch {
            await session.endAnalysis()
            throw error
        }
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ci-smoke") else { return }

        SimulatorStage.reset()
        writeReport("stage=started\n")
        SimulatorStage.mark("probe_started")

        let kifGame: KIFGame
        do {
            kifGame = try runKIFSelfTest()
            SimulatorStage.mark("kif_pass")
        } catch {
            writeReport([
                "stage=kif_failed",
                "kif_status=FAIL",
                "kif_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("kif_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(2)
        }

        let shallow = ShallowAnalysisViewModel()
        await shallow.analyze(game: kifGame, fileName: "ci-sample.kif", movetimeMs: 80)
        let shallowStatus = shallow.status
        let shallowCount = shallow.entries.count
        let shallowValid = shallow.entries.allSatisfy {
            !$0.bestMove.isEmpty
                && !$0.scoreText.isEmpty
                && !$0.pv.isEmpty
                && !$0.actualMove.isEmpty
        }
        guard shallowStatus == "浅解析 PASS",
              shallowCount == kifGame.moves.count,
              shallowValid else {
            writeReport([
                "stage=shallow_failed",
                "kif_status=PASS",
                "kif_moves=\(kifGame.moves.count)",
                "shallow_status=FAIL",
                "shallow_count=\(shallowCount)",
                "shallow_summary_begin",
                shallow.summary,
                "shallow_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("shallow_failed")
            fflush(stdout)
            exit(3)
        }
        guard let diagnosticURL = shallow.diagnosticURL,
              let diagnosticData = try? Data(contentsOf: diagnosticURL),
              let diagnostic = try? JSONDecoder.iso8601.decode(ShogiDiagnosticDocument.self, from: diagnosticData),
              diagnostic.schemaVersion == 1,
              diagnostic.game.fileName == "ci-sample.kif",
              diagnostic.analysis.completedPositions == kifGame.moves.count,
              diagnostic.positions.count == kifGame.moves.count,
              diagnostic.positions.allSatisfy({ !$0.pv.isEmpty && !$0.bestMove.isEmpty }),
              diagnostic.app.version == "0.8.1",
              diagnostic.app.build == "13",
              diagnostic.app.gitCommit != "unknown" else {
            writeReport([
                "stage=diagnostic_failed",
                "kif_status=PASS",
                "shallow_status=PASS",
                "diagnostic_status=FAIL"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("diagnostic_failed")
            fflush(stdout)
            exit(4)
        }
        SimulatorStage.mark("diagnostic_pass")

        let deep = DeepAnalysisViewModel()
        await deep.analyze(
            game: kifGame,
            shallowEntries: shallow.entries,
            diagnosticURL: shallow.diagnosticURL,
            deepMovetimeMs: 200,
            multiPV: 3,
            maxPositions: 3
        )
        let deepStatus = deep.status
        let deepCount = deep.entries.count
        let deepValid = deep.entries.allSatisfy {
            $0.candidates.count == 3
                && !$0.bestMove.isEmpty
                && !$0.actualMove.isEmpty
                && !$0.bestPV.isEmpty
                && !$0.actualPV.isEmpty
                && $0.actualAnalysisSource.hasPrefix("equal-condition")
                && $0.analysisAttempts >= 1
                && $0.finalMovetimeMs == 200
                && $0.candidates.allSatisfy { !$0.pv.isEmpty && !$0.move.isEmpty }
        }
        guard deepStatus == "深掘り PASS",
              deepCount == 3,
              deepValid,
              let deepDiagnosticURL = deep.diagnosticURL,
              let deepDiagnosticData = try? Data(contentsOf: deepDiagnosticURL),
              let deepDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: deepDiagnosticData
              ),
              deepDiagnostic.schemaVersion == 2,
              deepDiagnostic.app.version == "0.8.1",
              deepDiagnostic.app.build == "13",
              deepDiagnostic.deepAnalysis?.status == "深掘り PASS",
              deepDiagnostic.deepAnalysis?.multiPV == 3,
              deepDiagnostic.deepAnalysis?.adaptivePolicy == "adaptive-v2",
              deepDiagnostic.deepAnalysis?.completedPositions == 3,
              deepDiagnostic.deepAnalysis?.positions.count == 3,
              deepDiagnostic.deepAnalysis?.positions.allSatisfy({
                  $0.actualAnalysisSource.hasPrefix("equal-condition")
                      && !$0.bestPV.isEmpty
                      && !$0.actualPV.isEmpty
                      && $0.analysisAttempts >= 1
              }) == true else {
            writeReport([
                "stage=deep_failed",
                "kif_status=PASS",
                "shallow_status=PASS",
                "diagnostic_status=PASS",
                "deep_status=FAIL",
                "deep_count=\(deepCount)",
                "deep_summary_begin",
                deep.summary,
                "deep_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("deep_failed")
            fflush(stdout)
            exit(5)
        }
        SimulatorStage.mark("deep_pass")

        let boardReview = BoardReviewViewModel()
        boardReview.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            diagnosticURL: deep.diagnosticURL
        )
        let boardDisplayStatus = boardReview.status
        let boardDisplayCount = boardReview.entries.count
        let boardDisplayValid = boardReview.entries.allSatisfy {
            !$0.bestMoveText.isEmpty
                && !$0.actualMoveText.isEmpty
                && (1...9).contains($0.bestMove.destination.file)
                && (1...9).contains($0.bestMove.destination.rank)
                && ($0.bestMove.isDrop || $0.bestMove.source != nil)
        }
        guard boardDisplayStatus == "盤面表示 PASS",
              boardDisplayCount == deep.entries.count,
              boardDisplayValid,
              boardReview.entries.contains(where: { !$0.bestMove.isDrop }),
              let boardDiagnosticURL = boardReview.diagnosticURL,
              let boardDiagnosticData = try? Data(contentsOf: boardDiagnosticURL),
              let boardDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: boardDiagnosticData
              ),
              boardDiagnostic.schemaVersion == 3,
              boardDiagnostic.app.version == "0.8.1",
              boardDiagnostic.app.build == "13",
              boardDiagnostic.boardDisplay?.status == "盤面表示 PASS",
              boardDiagnostic.boardDisplay?.completedPositions == deep.entries.count,
              boardDiagnostic.boardDisplay?.positions.count == deep.entries.count else {
            writeReport([
                "stage=board_display_failed",
                "board_display_status=FAIL",
                "board_display_count=\(boardDisplayCount)",
                "board_display_summary_begin",
                boardReview.summary,
                "board_display_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("board_display_failed")
            fflush(stdout)
            exit(8)
        }
        SimulatorStage.mark("board_display_pass")

        let reason = ReasonAnalysisViewModel()
        reason.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            diagnosticURL: boardReview.diagnosticURL
        )
        let reasonStatus = reason.status
        let reasonCount = reason.entries.count
        let reasonValid = reason.entries.allSatisfy { entry in
            let factIDs = Set(entry.facts.map(\.id))
            let validLevels = entry.facts.allSatisfy {
                $0.level == .engineConfirmed || $0.level == .pvObserved
            }
            let linkedInterpretation = !entry.interpretation.evidenceFactIDs.isEmpty
                && entry.interpretation.evidenceFactIDs.allSatisfy { factIDs.contains($0) }
            return entry.facts.count >= 4
                && validLevels
                && linkedInterpretation
                && !entry.bestPV.isEmpty
                && !entry.actualPV.isEmpty
        }
        guard reasonStatus == "理由解析 PASS",
              reasonCount == deep.entries.count,
              reasonValid,
              let reasonDiagnosticURL = reason.diagnosticURL,
              let reasonDiagnosticData = try? Data(contentsOf: reasonDiagnosticURL),
              let reasonDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: reasonDiagnosticData
              ),
              reasonDiagnostic.schemaVersion == 4,
              reasonDiagnostic.app.version == "0.8.1",
              reasonDiagnostic.app.build == "13",
              reasonDiagnostic.reasonAnalysis?.status == "理由解析 PASS",
              reasonDiagnostic.reasonAnalysis?.completedPositions == deep.entries.count,
              reasonDiagnostic.reasonAnalysis?.positions.count == deep.entries.count,
              reasonDiagnostic.reasonAnalysis?.positions.allSatisfy({
                  !$0.facts.isEmpty
                      && !$0.interpretation.text.isEmpty
                      && !$0.interpretation.evidenceFactIDs.isEmpty
              }) == true else {
            writeReport([
                "stage=reason_analysis_failed",
                "reason_status=FAIL",
                "reason_count=\(reasonCount)",
                "reason_summary_begin",
                reason.summary,
                "reason_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_analysis_failed")
            fflush(stdout)
            exit(10)
        }
        SimulatorStage.mark("reason_analysis_pass")

        let continuation = ContinuationSimulationViewModel()
        continuation.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            reasonEntries: reason.entries,
            diagnosticURL: reason.diagnosticURL
        )
        let continuationStatus = continuation.status
        let continuationCount = continuation.entries.count
        let continuationValid = continuation.entries.allSatisfy { entry in
            guard let recommendedFirst = entry.recommended.moves.first,
                  let actualFirst = entry.actual.moves.first else {
                return false
            }
            return recommendedFirst.usi == deep.entries.first(where: { $0.ply == entry.ply })?.bestMove
                && actualFirst.usi == deep.entries.first(where: { $0.ply == entry.ply })?.actualMove
                && entry.recommended.moves.count <= 10
                && entry.actual.moves.count <= 10
                && !entry.recommended.developmentBlocks.isEmpty
                && !entry.actual.developmentBlocks.isEmpty
                && !entry.recommended.targetShapeSummary.isEmpty
                && !entry.actual.targetShapeSummary.isEmpty
        }
        guard continuationStatus == "展開シミュレーション PASS",
              continuationCount == deep.entries.count,
              continuationValid,
              let continuationDiagnosticURL = continuation.diagnosticURL,
              let continuationDiagnosticData = try? Data(contentsOf: continuationDiagnosticURL),
              let continuationDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: continuationDiagnosticData
              ),
              continuationDiagnostic.schemaVersion == 5,
              continuationDiagnostic.app.version == "0.8.1",
              continuationDiagnostic.app.build == "13",
              continuationDiagnostic.continuationSimulation?.status == "展開シミュレーション PASS",
              continuationDiagnostic.continuationSimulation?.completedPositions == deep.entries.count,
              continuationDiagnostic.continuationSimulation?.positions.count == deep.entries.count,
              continuationDiagnostic.continuationSimulation?.positions.allSatisfy({
                  !$0.recommended.moves.isEmpty
                      && !$0.actual.moves.isEmpty
                      && !$0.recommended.targetShapeSummary.isEmpty
                      && !$0.actual.targetShapeSummary.isEmpty
              }) == true else {
            writeReport([
                "stage=continuation_simulation_failed",
                "continuation_status=FAIL",
                "continuation_count=\(continuationCount)",
                "continuation_summary_begin",
                continuation.summary,
                "continuation_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("continuation_simulation_failed")
            fflush(stdout)
            exit(15)
        }
        SimulatorStage.mark("continuation_simulation_pass")

        let phaseReview = PhaseReviewViewModel()
        phaseReview.prepare(
            game: kifGame,
            shallowEntries: shallow.entries,
            deepEntries: deep.entries,
            reasonEntries: reason.entries,
            continuationEntries: continuation.entries,
            diagnosticURL: continuation.diagnosticURL
        )
        let phaseStatus = phaseReview.status
        let phaseKinds = Set(phaseReview.sections.map(\.kind))
        guard phaseStatus == "フェーズ別振り返り PASS",
              phaseReview.sections.count == 1,
              phaseKinds == Set([GamePhaseKind.opening]),
              let phaseDiagnosticURL = phaseReview.diagnosticURL,
              let phaseDiagnosticData = try? Data(contentsOf: phaseDiagnosticURL),
              let phaseDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: phaseDiagnosticData
              ),
              phaseDiagnostic.schemaVersion == 7,
              phaseDiagnostic.app.version == "0.8.1",
              phaseDiagnostic.app.build == "13",
              phaseDiagnostic.phaseAnalysis?.status == "フェーズ別振り返り PASS",
              phaseDiagnostic.phaseAnalysis?.usedAdditionalEngineSearch == false,
              phaseDiagnostic.phaseAnalysis?.sections.count == 1,
              phaseDiagnostic.phaseAnalysis?.sections.first?.kind == "opening" else {
            writeReport([
                "stage=phase_review_failed",
                "phase_status=FAIL",
                "phase_summary_begin",
                phaseReview.summary,
                "phase_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("phase_review_failed")
            fflush(stdout)
            exit(17)
        }
        SimulatorStage.mark("phase_review_pass")

        let (unstableGame, _) = makeTerminalRegression()
        let unstableDeepEntry = DeepAnalysisEntry(
            id: 75,
            ply: 75,
            actualMove: "B*1d",
            shallowBestMove: "2d2c+",
            shallowEstimatedLossCp: 980,
            bestMove: "2d2c+",
            bestScoreText: "cp 4814",
            actualScoreText: "cp 5442",
            actualLossCp: nil,
            bestPV: "2d2c+ 2b3a",
            actualPV: "B*1d G*2a",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "2b3a",
            candidates: [
                DeepCandidateLine(
                    id: 1,
                    rank: 1,
                    move: "2d2c+",
                    scoreText: "cp 4814",
                    centipawn: 4814,
                    depthText: "14",
                    nodesText: "1",
                    npsText: "1",
                    pv: "2d2c+ 2b3a",
                    opponentReply: "2b3a"
                )
            ],
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: false,
            instabilityReasons: ["comparison_inversion"],
            continuationStable: false,
            continuationInstabilityReasons: ["best_pv_short", "actual_pv_short"],
            analysisAttempts: 3,
            finalMovetimeMs: 2400,
            adaptiveTriggered: true,
            topCandidateGapCp: 18
        )
        let unstableReason = ReasonAnalysisViewModel()
        unstableReason.prepare(
            game: unstableGame,
            deepEntries: [unstableDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard unstableReason.status == "理由解析 PASS",
              unstableReason.entries.count == 1,
              let unstableEntry = unstableReason.entries.first,
              unstableEntry.interpretation.text.contains("判定を保留"),
              unstableEntry.interpretation.text.contains("断定"),
              !unstableEntry.interpretation.text.contains("評価差の理由候補"),
              unstableEntry.facts.contains(where: {
                  $0.kind == "score_comparison"
                      && $0.text.contains("評価損失は断定しない")
              }) else {
            writeReport([
                "stage=reason_unstable_failed",
                "reason_unstable_status=FAIL",
                "reason_unstable_summary_begin",
                unstableReason.summary,
                "reason_unstable_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_unstable_failed")
            fflush(stdout)
            exit(12)
        }
        SimulatorStage.mark("reason_unstable_pass")

        let recaptureDeepEntry = DeepAnalysisEntry(
            id: 49,
            ply: 49,
            actualMove: "4i3h",
            shallowBestMove: "3g2e",
            shallowEstimatedLossCp: 1232,
            bestMove: "3g2e",
            bestScoreText: "cp 1103",
            actualScoreText: "cp -103",
            actualLossCp: 1206,
            bestPV: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
            actualPV: "4i3h 5b4b B*6f",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "3c2e",
            candidates: [
                DeepCandidateLine(
                    id: 1,
                    rank: 1,
                    move: "3g2e",
                    scoreText: "cp 1103",
                    centipawn: 1103,
                    depthText: "13",
                    nodesText: "1",
                    npsText: "1",
                    pv: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
                    opponentReply: "3c2e"
                )
            ],
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: true,
            instabilityReasons: [],
            continuationStable: true,
            continuationInstabilityReasons: [],
            analysisAttempts: 1,
            finalMovetimeMs: 800,
            adaptiveTriggered: false,
            topCandidateGapCp: 782
        )
        let recaptureReason = ReasonAnalysisViewModel()
        recaptureReason.prepare(
            game: unstableGame,
            deepEntries: [recaptureDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard recaptureReason.status == "理由解析 PASS",
              recaptureReason.entries.count == 1,
              let recaptureEntry = recaptureReason.entries.first,
              recaptureEntry.interpretation.text.contains("取り返されます"),
              recaptureEntry.interpretation.text.contains("単純な駒取り"),
              !recaptureEntry.interpretation.text.contains("この機会を逃した") else {
            writeReport([
                "stage=reason_immediate_recapture_failed",
                "reason_immediate_recapture_status=FAIL",
                "reason_immediate_recapture_summary_begin",
                recaptureReason.summary,
                "reason_immediate_recapture_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_immediate_recapture_failed")
            fflush(stdout)
            exit(14)
        }
        SimulatorStage.mark("reason_immediate_recapture_pass")

        let continuationUnstableDeepEntry = DeepAnalysisEntry(
            id: 49,
            ply: 49,
            actualMove: "4i3h",
            shallowBestMove: "3g2e",
            shallowEstimatedLossCp: 1232,
            bestMove: "3g2e",
            bestScoreText: "cp 1103",
            actualScoreText: "cp -103",
            actualLossCp: 1206,
            bestPV: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
            actualPV: "4i3h 5b4b B*6f",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "3c2e",
            candidates: recaptureDeepEntry.candidates,
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: true,
            instabilityReasons: [],
            continuationStable: false,
            continuationInstabilityReasons: ["best_pv_changed"],
            analysisAttempts: 2,
            finalMovetimeMs: 1600,
            adaptiveTriggered: true,
            topCandidateGapCp: 782
        )
        let continuationUnstableReason = ReasonAnalysisViewModel()
        continuationUnstableReason.prepare(
            game: unstableGame,
            deepEntries: [continuationUnstableDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard continuationUnstableReason.status == "理由解析 PASS",
              let continuationUnstableReasonEntry = continuationUnstableReason.entries.first,
              continuationUnstableReasonEntry.actualLossCp == 1206,
              continuationUnstableReasonEntry.interpretation.text.contains("1206cp"),
              continuationUnstableReasonEntry.interpretation.text.contains("読み筋"),
              continuationUnstableReasonEntry.interpretation.text.contains("断定しません"),
              !continuationUnstableReasonEntry.interpretation.text.contains("取り返されます"),
              continuationUnstableReasonEntry.facts.contains(where: {
                  $0.kind == "continuation_stability"
              }) else {
            writeReport([
                "stage=reason_continuation_unstable_failed",
                "reason_continuation_unstable_status=FAIL",
                "reason_continuation_unstable_summary_begin",
                continuationUnstableReason.summary,
                "reason_continuation_unstable_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_continuation_unstable_failed")
            fflush(stdout)
            exit(20)
        }
        SimulatorStage.mark("reason_continuation_unstable_pass")

        let continuationSplit = ContinuationSimulationViewModel()
        continuationSplit.prepare(
            game: unstableGame,
            deepEntries: [continuationUnstableDeepEntry],
            reasonEntries: continuationUnstableReason.entries,
            diagnosticURL: continuationUnstableReason.diagnosticURL
        )
        guard continuationSplit.status == "展開シミュレーション PASS",
              let continuationSplitEntry = continuationSplit.entries.first,
              continuationSplitEntry.comparisonStable,
              !continuationSplitEntry.continuationStable,
              !continuationSplitEntry.recommended.stable,
              !continuationSplitEntry.actual.stable,
              let continuationSplitURL = continuationSplit.diagnosticURL,
              let continuationSplitData = try? Data(contentsOf: continuationSplitURL),
              let continuationSplitDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: continuationSplitData
              ),
              continuationSplitDiagnostic.schemaVersion == 5,
              continuationSplitDiagnostic.continuationSimulation?.positions.first?.comparisonStable == true,
              continuationSplitDiagnostic.continuationSimulation?.positions.first?.continuationStable == false else {
            writeReport([
                "stage=continuation_stability_split_failed",
                "continuation_stability_split_status=FAIL",
                "continuation_stability_split_summary_begin",
                continuationSplit.summary,
                "continuation_stability_split_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("continuation_stability_split_failed")
            fflush(stdout)
            exit(21)
        }
        SimulatorStage.mark("continuation_stability_split_pass")

        let (terminalGame, terminalShallow) = makeTerminalRegression()
        let terminalDiagnosticURL: URL
        do {
            terminalDiagnosticURL = try DiagnosticExporter.write(
                game: terminalGame,
                fileName: "terminal-81-regression.kif",
                entries: terminalShallow,
                status: "浅解析 PASS",
                requestedMoveTimeMs: 150,
                totalElapsedMs: 81,
                error: nil
            )
        } catch {
            writeReport([
                "stage=terminal_regression_failed",
                "terminal_deep_status=FAIL",
                "terminal_error=diagnostic \(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            fflush(stdout)
            exit(6)
        }

        let terminalDeep = DeepAnalysisViewModel()
        await terminalDeep.analyze(
            game: terminalGame,
            shallowEntries: terminalShallow,
            diagnosticURL: terminalDiagnosticURL,
            deepMovetimeMs: 200,
            multiPV: 3,
            maxPositions: 1
        )
        guard terminalDeep.status == "深掘り PASS",
              terminalDeep.entries.count == 1,
              let terminalEntry = terminalDeep.entries.first,
              terminalEntry.ply == 81,
              terminalEntry.actualMove == "G*1b",
              terminalEntry.actualAnalysisSource.hasPrefix("equal-condition"),
              terminalEntry.candidates.contains(where: { $0.move == "G*1b" }),
              !terminalEntry.actualPV.isEmpty else {
            writeReport([
                "stage=terminal_regression_failed",
                "terminal_deep_status=FAIL",
                "terminal_summary_begin",
                terminalDeep.summary,
                "terminal_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_regression_failed")
            fflush(stdout)
            exit(6)
        }
        let terminalActualSource = terminalEntry.actualAnalysisSource
        SimulatorStage.mark("terminal_regression_pass")

        let terminalBoardReview = BoardReviewViewModel()
        terminalBoardReview.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            diagnosticURL: terminalDeep.diagnosticURL
        )
        guard terminalBoardReview.status == "盤面表示 PASS",
              terminalBoardReview.entries.count == 1,
              let terminalBoardEntry = terminalBoardReview.entries.first,
              terminalBoardEntry.ply == 81,
              terminalBoardEntry.bestMove.isDrop,
              terminalBoardEntry.bestMove.source == nil,
              terminalBoardEntry.bestMove.dropPiece != nil,
              terminalBoardEntry.snapshot.sideToMove == .black,
              terminalBoardEntry.bestPiece == terminalBoardEntry.bestMove.dropPiece,
              let terminalBoardDiagnosticURL = terminalBoardReview.diagnosticURL,
              let terminalBoardData = try? Data(contentsOf: terminalBoardDiagnosticURL),
              let terminalBoardDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalBoardData
              ),
              terminalBoardDiagnostic.schemaVersion == 3,
              terminalBoardDiagnostic.boardDisplay?.status == "盤面表示 PASS",
              terminalBoardDiagnostic.boardDisplay?.completedPositions == 1 else {
            writeReport([
                "stage=terminal_board_failed",
                "terminal_board_status=FAIL",
                "terminal_board_summary_begin",
                terminalBoardReview.summary,
                "terminal_board_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_board_failed")
            fflush(stdout)
            exit(9)
        }
        let terminalBoardDestination = terminalBoardEntry.bestMove.destination.usi
        SimulatorStage.mark("terminal_board_pass")

        let terminalReason = ReasonAnalysisViewModel()
        terminalReason.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            diagnosticURL: terminalBoardReview.diagnosticURL
        )
        guard terminalReason.status == "理由解析 PASS",
              terminalReason.entries.count == 1,
              let terminalReasonEntry = terminalReason.entries.first,
              terminalReasonEntry.ply == 81,
              terminalReasonEntry.actualMove == "G*1b",
              !terminalReasonEntry.facts.isEmpty,
              !terminalReasonEntry.interpretation.text.isEmpty,
              let terminalReasonDiagnosticURL = terminalReason.diagnosticURL,
              let terminalReasonData = try? Data(contentsOf: terminalReasonDiagnosticURL),
              let terminalReasonDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalReasonData
              ),
              terminalReasonDiagnostic.schemaVersion == 4,
              terminalReasonDiagnostic.reasonAnalysis?.status == "理由解析 PASS",
              terminalReasonDiagnostic.reasonAnalysis?.completedPositions == 1 else {
            writeReport([
                "stage=terminal_reason_failed",
                "terminal_reason_status=FAIL",
                "terminal_reason_summary_begin",
                terminalReason.summary,
                "terminal_reason_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_reason_failed")
            fflush(stdout)
            exit(11)
        }
        SimulatorStage.mark("terminal_reason_pass")

        let terminalContinuation = ContinuationSimulationViewModel()
        terminalContinuation.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            reasonEntries: terminalReason.entries,
            diagnosticURL: terminalReason.diagnosticURL
        )
        guard terminalContinuation.status == "展開シミュレーション PASS",
              terminalContinuation.entries.count == 1,
              let terminalContinuationEntry = terminalContinuation.entries.first,
              let terminalActualFirst = terminalContinuationEntry.actual.moves.first,
              terminalActualFirst.usi == "G*1b",
              terminalActualFirst.effect.isDrop,
              terminalActualFirst.effect.source == nil,
              terminalActualFirst.effect.destination.usi == "1b",
              !terminalContinuationEntry.actual.targetShapeSummary.isEmpty else {
            writeReport([
                "stage=terminal_continuation_failed",
                "terminal_continuation_status=FAIL",
                "terminal_continuation_summary_begin",
                terminalContinuation.summary,
                "terminal_continuation_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_continuation_failed")
            fflush(stdout)
            exit(16)
        }
        SimulatorStage.mark("terminal_continuation_pass")

        let terminalPhaseReview = PhaseReviewViewModel()
        terminalPhaseReview.prepare(
            game: terminalGame,
            shallowEntries: terminalShallow,
            deepEntries: terminalDeep.entries,
            reasonEntries: terminalReason.entries,
            continuationEntries: terminalContinuation.entries,
            diagnosticURL: terminalContinuation.diagnosticURL
        )
        let terminalPhaseKinds = Set(terminalPhaseReview.sections.map(\.kind))
        let terminalPhaseAllThree = terminalPhaseKinds
            == Set([GamePhaseKind.opening, .middlegame, .endgame])
        guard terminalPhaseReview.status == "フェーズ別振り返り PASS",
              terminalPhaseAllThree,
              terminalPhaseReview.sections.count == 3,
              terminalPhaseReview.sections[0].kind == .opening,
              terminalPhaseReview.sections[1].kind == .middlegame,
              terminalPhaseReview.sections[2].kind == .endgame,
              terminalPhaseReview.sections[0].endPly < terminalPhaseReview.sections[1].startPly,
              terminalPhaseReview.sections[1].endPly < terminalPhaseReview.sections[2].startPly,
              let terminalPhaseURL = terminalPhaseReview.diagnosticURL,
              let terminalPhaseData = try? Data(contentsOf: terminalPhaseURL),
              let terminalPhaseDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalPhaseData
              ),
              terminalPhaseDiagnostic.schemaVersion == 7,
              terminalPhaseDiagnostic.phaseAnalysis?.usedAdditionalEngineSearch == false else {
            writeReport([
                "stage=terminal_phase_failed",
                "terminal_phase_status=FAIL",
                "terminal_phase_summary_begin",
                terminalPhaseReview.summary,
                "terminal_phase_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_phase_failed")
            fflush(stdout)
            exit(18)
        }
        SimulatorStage.mark("terminal_phase_pass")

        let dropSearchSession = EngineUSISession()
        var dropSearchStatus = "FAIL"
        do {
            try await dropSearchSession.beginAnalysis(multiPV: 1)
            guard let finalMove = terminalGame.moves.last else {
                throw EngineUSISession.ProbeError.protocolError("terminal move missing")
            }
            let dropSample = try await dropSearchSession.analyzePosition(
                command: finalMove.positionBefore,
                movetimeMs: 200,
                searchMoves: [finalMove.usi]
            )
            await dropSearchSession.endAnalysis()
            guard finalMove.usi == "G*1b",
                  dropSample.result.bestMove.move == finalMove.usi,
                  let dropPV = dropSample.result.principalVariations.first,
                  !dropPV.pv.isEmpty,
                  dropPV.pv.first == finalMove.usi else {
                throw EngineUSISession.ProbeError.protocolError(
                    "drop searchmoves was not enforced"
                )
            }
            dropSearchStatus = "PASS"
            SimulatorStage.mark("drop_searchmoves_pass")
        } catch {
            await dropSearchSession.endAnalysis()
            writeReport([
                "stage=drop_searchmoves_failed",
                "drop_searchmoves_status=FAIL",
                "drop_searchmoves_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("drop_searchmoves_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(7)
        }

        let qualityGate: AnalysisQualityGateResult
        do {
            qualityGate = try await runAnalysisQualityGate(terminalGame: terminalGame)
            SimulatorStage.mark("analysis_quality_gate_pass")
        } catch {
            writeReport([
                "stage=analysis_quality_gate_failed",
                "analysis_quality_gate_status=FAIL",
                "analysis_quality_gate_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("analysis_quality_gate_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(13)
        }

        let probe = EngineProbe()
        await probe.runDefaultProbe()
        let defaultStatus = probe.status
        let defaultResult = probe.resultText
        writeReport([
            "stage=default_done",
            "default_status=\(defaultStatus)",
            "default_result_begin",
            defaultResult,
            "default_result_end"
        ].joined(separator: "\n") + "\n")

        await probe.runTenProbe()
        let tenStatus = probe.status
        let tenResult = probe.resultText

        let report = [
            "stage=complete",
            "kif_status=PASS",
            "kif_moves=\(kifGame.moves.count)",
            "shallow_status=PASS",
            "shallow_count=\(shallowCount)",
            "diagnostic_status=PASS",
            "diagnostic_schema=\(diagnostic.schemaVersion)",
            "diagnostic_positions=\(diagnostic.positions.count)",
            "diagnostic_version=\(diagnostic.app.version)",
            "diagnostic_build=\(diagnostic.app.build)",
            "diagnostic_git=\(diagnostic.app.gitCommit)",
            "deep_status=\(deepStatus)",
            "deep_count=\(deepCount)",
            "deep_multipv=\(deepDiagnostic.deepAnalysis?.multiPV ?? 0)",
            "deep_diagnostic_schema=\(deepDiagnostic.schemaVersion)",
            "board_display_status=\(boardDisplayStatus)",
            "board_display_count=\(boardDisplayCount)",
            "board_display_schema=\(boardDiagnostic.schemaVersion)",
            "reason_status=\(reasonStatus)",
            "reason_count=\(reasonCount)",
            "reason_schema=\(reasonDiagnostic.schemaVersion)",
            "reason_unstable_status=PASS",
            "reason_immediate_recapture_status=PASS",
            "reason_continuation_unstable_status=PASS",
            "continuation_stability_split_status=PASS",
            "continuation_status=\(continuationStatus)",
            "continuation_count=\(continuationCount)",
            "continuation_schema=5",
            "phase_status=\(phaseStatus)",
            "phase_schema=7",
            "phase_additional_engine=false",
            "terminal_deep_status=\(terminalDeep.status)",
            "terminal_deep_ply=\(terminalEntry.ply)",
            "terminal_actual_source=\(terminalActualSource)",
            "terminal_board_status=\(terminalBoardReview.status)",
            "terminal_board_is_drop=\(terminalBoardEntry.bestMove.isDrop)",
            "terminal_board_destination=\(terminalBoardDestination)",
            "terminal_reason_status=\(terminalReason.status)",
            "terminal_reason_ply=\(terminalReasonEntry.ply)",
            "terminal_continuation_status=\(terminalContinuation.status)",
            "terminal_continuation_drop=\(terminalContinuationEntry.actual.moves.first?.effect.isDrop ?? false)",
            "terminal_phase_status=\(terminalPhaseReview.status)",
            "terminal_phase_all_three=\(terminalPhaseAllThree)",
            "drop_searchmoves_status=\(dropSearchStatus)",
            "analysis_quality_gate_status=PASS",
            "quality_normal_stable=\(qualityGate.normalStable)",
            "quality_normal_comparison_stable=\(qualityGate.normalComparisonStable)",
            "quality_normal_continuation_stable=\(qualityGate.normalContinuationStable)",
            "quality_normal_attempts=\(qualityGate.normalAttempts)",
            "quality_close_gap_cp=\(qualityGate.closeGapCp.map(String.init) ?? "-")",
            "quality_close_attempts=\(qualityGate.closeAttempts)",
            "quality_terminal_stable=\(qualityGate.terminalStable)",
            "quality_terminal_comparison_stable=\(qualityGate.terminalComparisonStable)",
            "quality_terminal_continuation_stable=\(qualityGate.terminalContinuationStable)",
            "quality_terminal_attempts=\(qualityGate.terminalAttempts)",
            "quality_terminal_bestmove=\(qualityGate.terminalBestMove)",
            "deep_summary_begin",
            deep.summary,
            "deep_summary_end",
            "shallow_summary_begin",
            shallow.summary,
            "shallow_summary_end",
            "default_status=\(defaultStatus)",
            "default_result_begin",
            defaultResult,
            "default_result_end",
            "ten_status=\(tenStatus)",
            "ten_result_begin",
            tenResult,
            "ten_result_end"
        ].joined(separator: "\n") + "\n"

        writeReport(report)
        SimulatorStage.mark("probe_complete")
        fflush(stdout)
        exit(0)
    }
}
#else
enum SimulatorCIProbe {
    static func runIfRequested() async {}
}
#endif


private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
