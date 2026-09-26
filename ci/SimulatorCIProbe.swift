import Foundation

#if targetEnvironment(simulator)
import Darwin

@MainActor
enum SimulatorCIProbe {
    private static func writeReport(_ text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-probe.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ci-smoke") else { return }

        writeReport("stage=started\n")

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
        fflush(stdout)
        exit(0)
    }
}
#else
enum SimulatorCIProbe {
    static func runIfRequested() async {}
}
#endif
