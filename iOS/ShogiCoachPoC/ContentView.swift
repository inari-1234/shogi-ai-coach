import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var probe = EngineProbe()
    @StateObject private var kif = KIFImportViewModel()
    @StateObject private var shallow = ShallowAnalysisViewModel()
    @StateObject private var deep = DeepAnalysisViewModel()
    @StateObject private var boardReview = BoardReviewViewModel()
    @StateObject private var reason = ReasonAnalysisViewModel()
    @State private var showingKIFImporter = false
    @State private var showingBoardReview = false
    @State private var showingReasonAnalysis = false

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
                    .disabled(probe.status.contains("解析中") || shallow.isRunning || deep.isRunning)
                }

                Section("工程2 KIF取込") {
                    Text("平手KIFを読み込み、各手をUSI指し手と解析用局面列へ変換します。")
                    Button("KIFを読み込む") {
                        showingKIFImporter = true
                    }
                    .disabled(shallow.isRunning || deep.isRunning)

                    Text(kif.status)
                    if !kif.summary.isEmpty {
                        Text(kif.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("工程3 全局面の浅い解析") {
                    Text("読み込んだ棋譜の全局面を1局面150msで順に解析し、評価値・bestmove・実際の指し手を保存します。")

                    Button("全局面を浅く解析") {
                        guard let game = kif.game else { return }
                        deep.reset()
                        boardReview.reset()
                        reason.reset()
                        Task { await shallow.analyze(game: game, fileName: kif.importedFileName) }
                    }
                    .disabled(kif.game == nil || shallow.isRunning || deep.isRunning)

                    Text(shallow.status)
                    if !shallow.summary.isEmpty {
                        Text(shallow.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("工程4 重要局面の深掘り") {
                    Text("浅解析から重要3〜5局面を抽出し、MultiPV 3の深い解析と実戦手限定解析を比較します。")

                    Button("重要局面を深掘り解析") {
                        guard let game = kif.game else { return }
                        boardReview.reset()
                        reason.reset()
                        Task {
                            await deep.analyze(
                                game: game,
                                shallowEntries: shallow.entries,
                                diagnosticURL: shallow.diagnosticURL
                            )
                        }
                    }
                    .disabled(
                        shallow.status != "浅解析 PASS"
                            || shallow.isRunning
                            || deep.isRunning
                    )

                    Text(deep.status)
                    if !deep.summary.isEmpty {
                        Text(deep.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }
                }

                Section("工程5 盤面上の最善手表示") {
                    Text("重要局面を実際の将棋盤に戻し、最善手の移動元と移動先を盤面上で直接示します。")

                    Button("盤面で最善手を見る") {
                        guard let game = kif.game else { return }
                        boardReview.prepare(
                            game: game,
                            deepEntries: deep.entries,
                            diagnosticURL: deep.diagnosticURL ?? shallow.diagnosticURL
                        )
                        if boardReview.status == "盤面表示 PASS" {
                            showingBoardReview = true
                        }
                    }
                    .disabled(
                        deep.status != "深掘り PASS"
                            || shallow.isRunning
                            || deep.isRunning
                    )

                    Text(boardReview.status)
                    if !boardReview.summary.isEmpty {
                        Text(boardReview.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    if let diagnosticURL = boardReview.diagnosticURL
                        ?? deep.diagnosticURL
                        ?? shallow.diagnosticURL {
                        ShareLink(item: diagnosticURL) {
                            Label("診断JSONを共有", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let diagnosticError = boardReview.diagnosticError
                        ?? deep.diagnosticError
                        ?? shallow.diagnosticError {
                        Text("診断JSON 未出力: \(diagnosticError)")
                            .font(.footnote)
                    }
                }

                Section("工程6 理由解析") {
                    Text("実戦手と最善候補の評価・PV・盤面変化を比較し、確認事実と解釈候補を分離して理由を整理します。")

                    Button("重要局面の理由を解析") {
                        guard let game = kif.game else { return }
                        if boardReview.status != "盤面表示 PASS" {
                            boardReview.prepare(
                                game: game,
                                deepEntries: deep.entries,
                                diagnosticURL: deep.diagnosticURL ?? shallow.diagnosticURL
                            )
                        }
                        reason.prepare(
                            game: game,
                            deepEntries: deep.entries,
                            diagnosticURL: boardReview.diagnosticURL
                                ?? deep.diagnosticURL
                                ?? shallow.diagnosticURL
                        )
                        if reason.status == "理由解析 PASS" {
                            showingReasonAnalysis = true
                        }
                    }
                    .disabled(
                        deep.status != "深掘り PASS"
                            || shallow.isRunning
                            || deep.isRunning
                    )

                    Text(reason.status)
                    if !reason.summary.isEmpty {
                        Text(reason.summary)
                            .font(.system(.footnote, design: .monospaced))
                            .textSelection(.enabled)
                    }

                    if let diagnosticURL = reason.diagnosticURL
                        ?? boardReview.diagnosticURL
                        ?? deep.diagnosticURL
                        ?? shallow.diagnosticURL {
                        ShareLink(item: diagnosticURL) {
                            Label("診断JSONを共有", systemImage: "square.and.arrow.up")
                        }
                    }
                    if let diagnosticError = reason.diagnosticError
                        ?? boardReview.diagnosticError
                        ?? deep.diagnosticError
                        ?? shallow.diagnosticError {
                        Text("診断JSON 未出力: \(diagnosticError)")
                            .font(.footnote)
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
                    Task {
                        shallow.reset()
                        deep.reset()
                        boardReview.reset()
                        reason.reset()
                        await kif.importFile(url)
                    }
                case .failure:
                    break
                }
            }
            .sheet(isPresented: $showingBoardReview) {
                BoardReviewScreen(entries: boardReview.entries)
            }
            .sheet(isPresented: $showingReasonAnalysis) {
                ReasonAnalysisScreen(entries: reason.entries)
            }
        }
    }
}
