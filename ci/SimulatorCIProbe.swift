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
        await shallow.analyze(game: kifGame, movetimeMs: 80)
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
        SimulatorStage.mark("shallow_pass")

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
