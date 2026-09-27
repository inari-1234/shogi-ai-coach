import Foundation
import ShogiCoachCore

enum SimulatorStage {
    private static let lock = NSLock()

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engine-stage.txt")
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
}

#if targetEnvironment(simulator)
import Darwin

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
              diagnostic.app.version == "0.4.0",
              diagnostic.app.build == "4",
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
                && !$0.actualPV.isEmpty
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
              deepDiagnostic.app.version == "0.4.0",
              deepDiagnostic.app.build == "4",
              deepDiagnostic.deepAnalysis?.status == "深掘り PASS",
              deepDiagnostic.deepAnalysis?.multiPV == 3,
              deepDiagnostic.deepAnalysis?.completedPositions == 3,
              deepDiagnostic.deepAnalysis?.positions.count == 3 else {
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

        var terminalProbeText = "not-run"
        do {
            let terminal = EngineUSISession()
            try await terminal.beginAnalysis(multiPV: 3)
            let command = "position startpos moves 7g7f 3c3d 2g2f 8c8d 6g6f 2b3c 2h6h 3a3b 5i4h 6a5b 4h3h 5a4b 3h2h 7a6b 1g1f 8d8e 8h7g 3c4d 2h2g 2a3c 3i3h 2c2d 7i7h 8b8d 6i5h 3b2c 9i9h 5c5d 6f6e 8d8b 4g4f 1c1d 5h4g 4b3a 2g2h 6b5c 4f4e 4d7g+ 7h7g 4a3b 1i1h B*3e 3g3f 3e2f 3h2g 2d2e 2i3g 3a2b 4i3h 9c9d 6h6i 8a9c 6i2i 2c2d B*4f 3d3e 3f3e 3b2c 4g3f P*3d 2g2f 2e2f 3e3d S*2g 3h2g 2f2g+ 2h2g 1d1e 1f1e 1a1e P*2e 2c3d 2e2d 1e1h+ B*1d G*1c S*2c 1c2c 1d2c+ 2b1a"
            let unrestricted = try await terminal.analyzePosition(
                command: command,
                movetimeMs: 200
            )
            let restricted = try await terminal.analyzePosition(
                command: command,
                movetimeMs: 200,
                searchMoves: ["G*1b"]
            )
            await terminal.endAnalysis()

            let candidateMoves = unrestricted.result.principalVariations
                .prefix(3)
                .compactMap { $0.pv.first }
                .joined(separator: ",")
            let restrictedPV = restricted.result.principalVariations.first?.pv
                .joined(separator: " ") ?? "-"
            terminalProbeText = [
                "unrestricted_best=\(unrestricted.result.bestMove.move)",
                "unrestricted_candidates=\(candidateMoves)",
                "restricted_best=\(restricted.result.bestMove.move)",
                "restricted_pv=\(restrictedPV)"
            ].joined(separator: " | ")
            SimulatorStage.mark("terminal_probe_\(terminalProbeText)")
        } catch {
            terminalProbeText = "error=\(error.localizedDescription)"
            SimulatorStage.mark("terminal_probe_error_\(error.localizedDescription)")
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
            "terminal_probe=\(terminalProbeText)",
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
