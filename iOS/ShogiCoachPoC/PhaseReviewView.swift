import SwiftUI

struct PhaseReviewScreen: View {
    let sections: [PhaseReviewSection]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhase: GamePhaseKind = .opening

    private var selectedSection: PhaseReviewSection? {
        sections.first { $0.kind == selectedPhase }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("フェーズ", selection: $selectedPhase) {
                    ForEach(GamePhaseKind.allCases) { phase in
                        Text(phase.title).tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                ScrollView {
                    if let section = selectedSection {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(section.startPly)〜\(section.endPly)手")
                                    .font(.headline)
                                Text(section.summary)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }

                            GroupBox("この段階で考えること") {
                                Text(section.focusText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            ForEach(section.points) { point in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(point.title)
                                            .font(.headline)
                                        Spacer()
                                        Text("\(point.ply)手目")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(point.detail)
                                        .font(.body)

                                    ForEach(Array(point.evidence.enumerated()), id: \.offset) { _, evidence in
                                        Label(evidence, systemImage: "checkmark.circle")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }

                                    if let continuationSummary = point.continuationSummary {
                                        Divider()
                                        Text(continuationSummary)
                                            .font(.footnote)
                                    }
                                }
                                .padding(12)
                                .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    } else {
                        VStack(spacing: 10) {
                            Image(systemName: "square.split.2x1")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("明確な\(selectedPhase.title)区間なし")
                                .font(.headline)
                            Text("この対局では盤面状態から独立した\(selectedPhase.title)区間を検出しませんでした。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal)
                        .padding(.top, 40)
                    }
                }
            }
            .navigationTitle("フェーズ別振り返り")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
