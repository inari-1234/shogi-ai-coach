import Foundation

#if targetEnvironment(simulator)
import Darwin

enum VE1ASimulatorPreflight {
    private static var reportURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ve1a-runtime.txt")
    }

    private static func write(_ lines: [String]) {
        let text = lines.joined(separator: "\n") + "\n"
        try? text.write(to: reportURL, atomically: true, encoding: .utf8)
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ve1a-runtime-smoke") else {
            return
        }

        try? FileManager.default.removeItem(at: reportURL)
        write(["stage=started", "ve1a_status=RUNNING"])

        do {
            // This control must execute before any qualified FV_SCALE=24 session in this
            // process. YaneuraOu's embedded runtime retains option state across local
            // sessions, so running C1 first would make an omitted FV_SCALE inherit 24.
            let missingScale = try await EngineRuntimeVerifier.shared
                .runMissingFVScaleNegativeControl()
            let wrongNNUEActualSHA = try await EngineRuntimeVerifier.shared
                .runWrongNNUEIdentityNegativeControl()
            let c1 = try await EngineRuntimeVerifier.shared.runC1KnownAnswer()
            let gitCommit = Bundle.main.object(
                forInfoDictionaryKey: "GitCommit"
            ) as? String ?? "unknown"

            let lines = [
                "stage=complete",
                "ve1a_status=PASS",
                "platform=simulator",
                "git_commit=\(gitCommit)",
                "c1_position=position startpos",
                "c1_go=go depth 1",
                "c1_threads=1",
                "c1_multipv=1",
                "c1_fv_scale=\(c1.fvScale.map(String.init) ?? "nil")",
                "c1_cp=\(c1.cp)",
                "c1_bestmove=\(c1.bestMove)",
                "c1_depth=\(c1.depth.map(String.init) ?? "nil")",
                "nnue_sha256=\(c1.nnueSHA256)",
                "negative_missing_fv_scale_status=PASS",
                "negative_missing_fv_scale_cp=\(missingScale.cp)",
                "negative_missing_fv_scale_bestmove=\(missingScale.bestMove)",
                "negative_wrong_nnue_status=PASS",
                "negative_wrong_nnue_actual_sha256=\(wrongNNUEActualSHA)",
                "missing_fv_scale_transcript_begin",
                missingScale.transcript.joined(separator: "\n"),
                "missing_fv_scale_transcript_end",
                "c1_transcript_begin",
                c1.transcript.joined(separator: "\n"),
                "c1_transcript_end"
            ]
            write(lines)
            fflush(stdout)
            exit(0)
        } catch {
            write([
                "stage=failed",
                "ve1a_status=FAIL",
                "error=\(error.localizedDescription)"
            ])
            fflush(stdout)
            exit(70)
        }
    }
}
#else
enum VE1ASimulatorPreflight {
    static func runIfRequested() async {}
}
#endif
