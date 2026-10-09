import SwiftUI

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
            let result = try await EngineRuntimeVerifier.shared.runC1KnownAnswer()
            let platform: String
            #if targetEnvironment(simulator)
            platform = "simulator"
            #else
            platform = "device"
            #endif
            let gitCommit = Bundle.main.object(
                forInfoDictionaryKey: "GitCommit"
            ) as? String ?? "unknown"

            let lines = [
                "ve1a_status=PASS",
                "platform=\(platform)",
                "git_commit=\(gitCommit)",
                "c1_position=position startpos",
                "c1_go=go depth 1",
                "c1_threads=1",
                "c1_multipv=1",
                "c1_fv_scale=\(result.fvScale.map(String.init) ?? "nil")",
                "c1_cp=\(result.cp)",
                "c1_bestmove=\(result.bestMove)",
                "c1_depth=\(result.depth.map(String.init) ?? "nil")",
                "nnue_sha256=\(result.nnueSHA256)",
                "transcript_begin",
                result.transcript.joined(separator: "\n"),
                "transcript_end"
            ]
            let report = lines.joined(separator: "\n") + "\n"
            let url = FileManager.default.urls(
                for: .documentDirectory,
                in: .userDomainMask
            )[0].appendingPathComponent("ve1a-device-runtime.txt")
            try report.write(to: url, atomically: true, encoding: .utf8)
            reportURL = url
            detail = report
            status = "PASS"
        } catch {
            status = "FAIL"
            detail = error.localizedDescription
        }
    }
}

struct EngineRuntimeVerificationView: View {
    @StateObject private var model = EngineRuntimeVerificationViewModel()

    var body: some View {
        Form {
            Section("VE1-A エンジン整合性") {
                Text("平手初期局面を Threads 1 / MultiPV 1 / FV_SCALE 24 / depth 1 で解析し、cp 108・7g7f・指定NNUE SHAと一致するか確認します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button(model.isRunning ? "検証中…" : "自己診断を実行") {
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
                        Label("検証ログを共有", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .navigationTitle("VE1-A自己診断")
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
                .accessibilityLabel("VE1-Aエンジン整合性診断")
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
