import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var probe = EngineProbe()
    @StateObject private var kif = KIFImportViewModel()
    @State private var showingKIFImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("工程1-C") {
                    Text("固定SFENをやねうら王+NNUEで1.5秒解析します。")
                    Button("1局面を解析") {
                        Task { await probe.runDefaultProbe() }
                    }
                    Button("10回連続テスト") {
                        Task { await probe.runTenProbe() }
                    }
                    .disabled(probe.status.contains("解析中"))
                }

                Section("工程2 KIF取込") {
                    Text("平手KIFを読み込み、各手をUSI指し手と解析用局面列へ変換します。")
                    Button("KIFを読み込む") {
                        showingKIFImporter = true
                    }
                    Text(kif.status)
                    if !kif.summary.isEmpty {
                        Text(kif.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("エンジン状態") {
                    Text(probe.status)
                    if !probe.resultText.isEmpty {
                        Text(probe.resultText)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }
            }
            .navigationTitle("Shogi Coach PoC")
            .fileImporter(
                isPresented: $showingKIFImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await kif.importFile(url) }
                case .failure:
                    break
                }
            }
        }
    }
}
