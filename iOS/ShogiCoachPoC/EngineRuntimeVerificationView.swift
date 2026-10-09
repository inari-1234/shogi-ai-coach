import SwiftUI
import UIKit
import Darwin

private enum VE1ADeviceEvidenceEnvironment {
    static var platform: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "device"
        #endif
    }

    static var hardwareModelIdentifier: String {
        #if targetEnvironment(simulator)
        if let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !identifier.isEmpty {
            return identifier
        }
        #endif

        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else {
            return UIDevice.current.model
        }
        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(bitPattern: value)))
        }
    }

    static var osVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    static var gitCommit: String {
        Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
    }
}

@MainActor
final class EngineRuntimeVerificationViewModel: ObservableObject {
    @Published private(set) var status = "未実行"
    @Published private(set) var detail = ""
    @Published private(set) var isRunning = false
    @Published private(set) var reportURL: URL?

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        status = "検証中"
        detail = ""
        reportURL = nil
        defer { isRunning = false }

        do {
            let suite = try await EngineRuntimeVerifier.shared.runPhysicalDeviceEvidenceSuite()
            let mismatches = evidenceMismatches(for: suite)
            let evidenceStatus = mismatches.isEmpty ? "PASS" : "HOLD"
            let report = makeReport(
                suite: suite,
                evidenceStatus: evidenceStatus,
                mismatches: mismatches
            )
            try persist(report: report)
            detail = report
            status = evidenceStatus
        } catch {
            let report = makeFailureReport(error: error)
            try? persist(report: report)
            detail = report
            status = "HOLD"
        }
    }

    private func evidenceMismatches(
        for suite: EngineRuntimePhysicalEvidenceSuite
    ) -> [String] {
        var mismatches: [String] = []

        if VE1ADeviceEvidenceEnvironment.platform != "device" {
            mismatches.append("physical-device evidence requires platform=device")
        }
        if VE1ADeviceEvidenceEnvironment.gitCommit == "unknown" {
            mismatches.append("GitCommit provenance is missing")
        }
        if VE1ADeviceEvidenceEnvironment.appVersion == "unknown" {
            mismatches.append("app version provenance is missing")
        }
        if VE1ADeviceEvidenceEnvironment.appBuild == "unknown" {
            mismatches.append("app build provenance is missing")
        }

        appendKnownAnswerMismatches(
            result: suite.startpos,
            label: "startpos",
            expectedCp: EngineRuntimeAuthority.c1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.c1ExpectedBestMove,
            to: &mismatches
        )
        appendKnownAnswerMismatches(
            result: suite.correctedC1,
            label: "corrected_c1",
            expectedCp: EngineRuntimeAuthority.correctedC1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.correctedC1ExpectedBestMove,
            to: &mismatches
        )

        return mismatches
    }

    private func appendKnownAnswerMismatches(
        result: EngineRuntimeVerificationResult,
        label: String,
        expectedCp: Int,
        expectedBestMove: String,
        to mismatches: inout [String]
    ) {
        if result.fvScale != EngineRuntimeAuthority.fvScale {
            mismatches.append(
                "\(label) FV_SCALE expected=\(EngineRuntimeAuthority.fvScale) actual=\(result.fvScale.map(String.init) ?? "nil")"
            )
        }
        if result.depth != EngineRuntimeAuthority.c1Depth {
            mismatches.append(
                "\(label) depth expected=\(EngineRuntimeAuthority.c1Depth) actual=\(result.depth.map(String.init) ?? "nil")"
            )
        }
        if result.cp != expectedCp {
            mismatches.append("\(label) cp expected=\(expectedCp) actual=\(result.cp)")
        }
        if result.bestMove != expectedBestMove {
            mismatches.append(
                "\(label) bestmove expected=\(expectedBestMove) actual=\(result.bestMove)"
            )
        }
        if result.nnueSHA256 != EngineRuntimeAuthority.expectedNNUESHA256 {
            mismatches.append(
                "\(label) nnue_sha256 expected=\(EngineRuntimeAuthority.expectedNNUESHA256) actual=\(result.nnueSHA256)"
            )
        }
    }

    private func makeReport(
        suite: EngineRuntimePhysicalEvidenceSuite,
        evidenceStatus: String,
        mismatches: [String]
    ) -> String {
        var lines = environmentLines(status: evidenceStatus)
        lines.append("evidence_scope=VE1-A physical iPhone known-answer verification")
        lines.append("expected_values_mutable_on_mismatch=false")
        lines.append("nnue_bundle_path=\(suite.startpos.nnuePath)")
        lines.append("nnue_sha256=\(suite.startpos.nnueSHA256)")

        if mismatches.isEmpty {
            lines.append("mismatch_count=0")
        } else {
            lines.append("mismatch_count=\(mismatches.count)")
            for mismatch in mismatches {
                lines.append("mismatch=\(mismatch)")
            }
        }

        appendProbe(
            label: "startpos",
            result: suite.startpos,
            expectedCp: EngineRuntimeAuthority.c1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.c1ExpectedBestMove,
            to: &lines
        )
        appendProbe(
            label: "corrected_c1",
            result: suite.correctedC1,
            expectedCp: EngineRuntimeAuthority.correctedC1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.correctedC1ExpectedBestMove,
            to: &lines
        )

        return lines.joined(separator: "\n") + "\n"
    }

    private func appendProbe(
        label: String,
        result: EngineRuntimeVerificationResult,
        expectedCp: Int,
        expectedBestMove: String,
        to lines: inout [String]
    ) {
        lines.append("\(label)_position=\(result.positionCommand)")
        lines.append("\(label)_go=go depth \(EngineRuntimeAuthority.c1Depth)")
        lines.append("\(label)_threads=1")
        lines.append("\(label)_multipv=1")
        lines.append("\(label)_fv_scale=\(result.fvScale.map(String.init) ?? "nil")")
        lines.append("\(label)_expected_cp=\(expectedCp)")
        lines.append("\(label)_actual_cp=\(result.cp)")
        lines.append("\(label)_expected_bestmove=\(expectedBestMove)")
        lines.append("\(label)_actual_bestmove=\(result.bestMove)")
        lines.append("\(label)_actual_depth=\(result.depth.map(String.init) ?? "nil")")
        lines.append("\(label)_transcript_begin")
        lines.append(contentsOf: result.transcript)
        lines.append("\(label)_transcript_end")
    }

    private func makeFailureReport(error: Error) -> String {
        var lines = environmentLines(status: "HOLD")
        lines.append("evidence_scope=VE1-A physical iPhone known-answer verification")
        lines.append("expected_values_mutable_on_mismatch=false")
        lines.append("failure=\(singleLine(error.localizedDescription))")
        lines.append("action=retain expected 108/157 and investigate runtime provenance/input")
        return lines.joined(separator: "\n") + "\n"
    }

    private func environmentLines(status: String) -> [String] {
        [
            "ve1a_status=\(status)",
            "platform=\(VE1ADeviceEvidenceEnvironment.platform)",
            "device_model_identifier=\(VE1ADeviceEvidenceEnvironment.hardwareModelIdentifier)",
            "os_version=\(VE1ADeviceEvidenceEnvironment.osVersion)",
            "app_version=\(VE1ADeviceEvidenceEnvironment.appVersion)",
            "app_build=\(VE1ADeviceEvidenceEnvironment.appBuild)",
            "git_commit=\(VE1ADeviceEvidenceEnvironment.gitCommit)"
        ]
    }

    private func singleLine(_ value: String) -> String {
        value.replacingOccurrences(of: "\n", with: " ")
    }

    private func persist(report: String) throws {
        let url = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("ve1a-physical-device-runtime.txt")
        try report.write(to: url, atomically: true, encoding: .utf8)
        reportURL = url
    }
}

struct EngineRuntimeVerificationView: View {
    @StateObject private var model = EngineRuntimeVerificationViewModel()

    var body: some View {
        Form {
            Section("VE1-A 実機エンジン整合性") {
                Text("平手初期局面とVE1-Q訂正SFENを Threads 1 / MultiPV 1 / FV_SCALE 24 / depth 1 で解析し、cp 108・7g7f と cp 157・2b7g+、指定NNUE SHA、実機 provenance を1つの証拠ログに保存します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(model.isRunning ? "検証中…" : "実機証拠診断を実行") {
                    Task { await model.run() }
                }
                .disabled(model.isRunning)

                if model.isRunning {
                    ProgressView()
                }

                Text(model.status)
                    .font(.headline)

                if !model.detail.isEmpty {
                    Text(model.detail)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }

                if let reportURL = model.reportURL {
                    ShareLink(item: reportURL) {
                        Label("実機証拠ログを共有", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle("VE1-A実機診断")
    }
}

struct VE1ARootView: View {
    @State private var showingVerification = false

    var body: some View {
        ContentView()
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingVerification = true
                } label: {
                    Label("VE1-A", systemImage: "stethoscope")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding()
                .accessibilityLabel("VE1-A実機エンジン整合性診断")
            }
            .sheet(isPresented: $showingVerification) {
                NavigationStack {
                    EngineRuntimeVerificationView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("閉じる") {
                                    showingVerification = false
                                }
                            }
                        }
                }
            }
    }
}
