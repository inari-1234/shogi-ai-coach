import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var kif = KIFImportViewModel()
    @StateObject private var shallow = ShallowAnalysisViewModel()
    @StateObject private var deep = DeepAnalysisViewModel()
    @StateObject private var boardReview = BoardReviewViewModel()
    @StateObject private var reason = ReasonAnalysisViewModel()
    @StateObject private var continuation = ContinuationSimulationViewModel()
    @StateObject private var phaseReview = PhaseReviewViewModel()

    @State private var showingKIFImporter = false
    @State private var showingContinuationSimulation = false
    @State private var showingPhaseReview = false
    @State private var isAnalyzing = false
    @State private var analysisStatus = "未解析"

    private var diagnosticURL: URL? {
        phaseReview.diagnosticURL
            ?? continuation.diagnosticURL
            ?? reason.diagnosticURL
            ?? boardReview.diagnosticURL
            ?? deep.diagnosticURL
            ?? shallow.diagnosticURL
    }

    private var diagnosticError: String? {
        phaseReview.diagnosticError
            ?? continuation.diagnosticError
            ?? reason.diagnosticError
            ?? boardReview.diagnosticError
            ?? deep.diagnosticError
            ?? shallow.diagnosticError
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("棋譜") {
                    Button("KIFを読み込む") {
                        showingKIFImporter = true
                    }
                    .disabled(isAnalyzing)

                    Text(kif.status)
                    if !kif.summary.isEmpty {
                        Text(kif.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("解析") {
                    Text("全局面を浅く確認し、重要局面だけを深掘りして、最善手・盤面差分・理由候補まで一括で作成します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button(isAnalyzing ? "解析中…" : "棋譜を解析") {
                        guard let game = kif.game else { return }
                        Task { @MainActor in
                            isAnalyzing = true
                            defer { isAnalyzing = false }

                            shallow.reset()
                            deep.reset()
                            boardReview.reset()
                            reason.reset()
                            continuation.reset()
                            phaseReview.reset()

                            analysisStatus = "全局面を浅く解析中"
                            await shallow.analyze(
                                game: game,
                                fileName: kif.importedFileName
                            )
                            guard shallow.status == "浅解析 PASS" else {
                                analysisStatus = shallow.status
                                return
                            }

                            analysisStatus = "重要局面を深掘り中"
                            await deep.analyze(
                                game: game,
                                shallowEntries: shallow.entries,
                                diagnosticURL: shallow.diagnosticURL
                            )
                            guard deep.status == "深掘り PASS" else {
                                analysisStatus = deep.status
                                return
                            }

                            analysisStatus = "盤面を再構築中"
                            boardReview.prepare(
                                game: game,
                                deepEntries: deep.entries,
                                diagnosticURL: deep.diagnosticURL ?? shallow.diagnosticURL
                            )
                            guard boardReview.status == "盤面表示 PASS" else {
                                analysisStatus = boardReview.status
                                return
                            }

                            analysisStatus = "理由を整理中"
                            reason.prepare(
                                game: game,
                                deepEntries: deep.entries,
                                diagnosticURL: boardReview.diagnosticURL
                                    ?? deep.diagnosticURL
                                    ?? shallow.diagnosticURL
                            )
                            guard reason.status == "理由解析 PASS" else {
                                analysisStatus = reason.status
                                return
                            }

                            analysisStatus = "推奨展開を組み立て中"
                            continuation.prepare(
                                game: game,
                                deepEntries: deep.entries,
                                reasonEntries: reason.entries,
                                diagnosticURL: reason.diagnosticURL
                                    ?? boardReview.diagnosticURL
                                    ?? deep.diagnosticURL
                                    ?? shallow.diagnosticURL
                            )
                            guard continuation.status == "展開シミュレーション PASS" else {
                                analysisStatus = continuation.status
                                return
                            }

                            analysisStatus = "対局フェーズを整理中"
                            phaseReview.prepare(
                                game: game,
                                shallowEntries: shallow.entries,
                                deepEntries: deep.entries,
                                reasonEntries: reason.entries,
                                continuationEntries: continuation.entries,
                                diagnosticURL: continuation.diagnosticURL
                                    ?? reason.diagnosticURL
                                    ?? boardReview.diagnosticURL
                                    ?? deep.diagnosticURL
                                    ?? shallow.diagnosticURL
                            )
                            analysisStatus = phaseReview.status == "フェーズ別振り返り PASS"
                                ? "解析 PASS"
                                : phaseReview.status
                        }
                    }
                    .disabled(kif.game == nil || isAnalyzing)

                    if isAnalyzing {
                        ProgressView()
                    }

                    Text(analysisStatus)
                        .font(.headline)

                    if analysisStatus == "解析 PASS" {
                        Text("重要局面を\(continuation.entries.count)件抽出しました。推奨手と実戦手を盤面で動かして比較できます。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if analysisStatus == "解析 PASS" {
                    Section("振り返り") {
                        Button {
                            showingContinuationSimulation = true
                        } label: {
                            Label("重要局面を盤面で振り返る", systemImage: "play.rectangle")
                        }

                        Button {
                            showingPhaseReview = true
                        } label: {
                            Label("対局全体の流れを盤面で振り返る", systemImage: "square.split.2x1")
                        }
                    }

                    Section("詳細") {
                        Text("エンジンの根拠一覧は通常の振り返りには表示せず、診断JSONに保持しています。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if let diagnosticURL {
                            ShareLink(item: diagnosticURL) {
                                Label("診断JSONを共有", systemImage: "square.and.arrow.up")
                            }
                        }

                        if let diagnosticError {
                            Text("診断JSON 未出力: \(diagnosticError)")
                                .font(.footnote)
                        }
                    }
                }
            }
            .navigationTitle("将棋AIコーチ")
            .fileImporter(
                isPresented: $showingKIFImporter,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { @MainActor in
                        shallow.reset()
                        deep.reset()
                        boardReview.reset()
                        reason.reset()
                        continuation.reset()
                        phaseReview.reset()
                        analysisStatus = "未解析"
                        await kif.importFile(url)
                    }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showingContinuationSimulation) {
                ContinuationSimulationScreen(entries: continuation.entries)
            }
            .sheet(isPresented: $showingPhaseReview) {
                PhaseReviewScreen(
                    sections: phaseReview.sections,
                    continuationEntries: continuation.entries
                )
            }
        }
    }
}
