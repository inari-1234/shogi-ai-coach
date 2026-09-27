import SwiftUI

struct ReasonAnalysisScreen: View {
    let entries: [ReasonAnalysisEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(entries) { entry in
                Section {
                    HStack {
                        Text("\(entry.ply)手目")
                            .font(.headline)
                        Spacer()
                        Text(entry.actualMove == entry.bestMove ? "最善手一致" : "要確認")
                            .font(.caption.bold())
                            .foregroundStyle(entry.actualMove == entry.bestMove ? .green : .orange)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("最善手 \(entry.bestMove) / 実戦手 \(entry.actualMove)")
                            .font(.system(.subheadline, design: .monospaced))
                        Text("最善 \(entry.bestScore) / 実戦 \(entry.actualScore)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(entry.facts) { fact in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(fact.level == .engineConfirmed ? "エンジン確認" : "PV観測")
                                .font(.caption2.bold())
                                .foregroundStyle(
                                    fact.level == .engineConfirmed ? .blue : .purple
                                )
                            Text(fact.text)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("解釈候補")
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                        Text(entry.interpretation.text)
                            .font(.subheadline)
                        Text("※ 根拠に結び付いた候補であり、確認事実とは分離しています。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("なぜこの手が重要か")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
