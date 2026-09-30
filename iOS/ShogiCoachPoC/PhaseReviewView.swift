import SwiftUI
import ShogiCoachCore

struct PhaseReviewScreen: View {
    let sections: [PhaseReviewSection]
    let continuationEntries: [ContinuationSimulationEntry]
    let contextEntries: [ContextAnalysisEntry]
    let recommendedExplanations: [Int: ContextMoveExplanation]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhase: GamePhaseKind = .opening
    @State private var selectedPointID: String?
    @State private var selectedContinuation: ContinuationSimulationEntry?

    private var selectedSection: PhaseReviewSection? {
        sections.first { $0.kind == selectedPhase }
    }

    private var representativePoint: PhaseCoachPoint? {
        selectedSection?.points.first { $0.kind == .important }
    }

    private var selectedBoardPoint: PhaseCoachPoint? {
        guard let section = selectedSection else { return nil }
        if let selectedPointID,
           let selected = section.points.first(where: { $0.id == selectedPointID }) {
            return selected
        }
        return representativePoint ?? section.points.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("フェーズ", selection: $selectedPhase) {
                    ForEach(GamePhaseKind.allCases) { phase in
                        Text(phase.title).tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .onChange(of: selectedPhase) { _ in
                    selectedPointID = nil
                }

                ScrollView {
                    if let section = selectedSection {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(section.kind.title)
                                    .font(.title3.bold())
                                Text("\(section.startPly)〜\(section.endPly)手")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }

                            coachingTheme(section)

                            if let point = representativePoint {
                                representativeCard(point, section: section)
                            } else if let point = selectedBoardPoint {
                                noMajorIssueCard(point, section: section)
                            }

                            nextCheckCard(section)

                            DisclosureGroup("開始・終了の盤面も確認") {
                                VStack(alignment: .leading, spacing: 10) {
                                    supportPointStrip(section)

                                    if let point = selectedBoardPoint {
                                        Text(supportTitle(point))
                                            .font(.subheadline.bold())

                                        ShogiBoardPanel(
                                            snapshot: point.snapshot,
                                            orientation: section.orientation,
                                            move: nil
                                        )
                                        .frame(maxWidth: 360)
                                        .frame(maxWidth: .infinity)

                                        if point.kind != .important {
                                            Text(point.detail)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    } else {
                        emptyState
                    }
                }
            }
            .navigationTitle("対局の流れを盤面で振り返る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
            .sheet(item: $selectedContinuation) { entry in
                ContinuationSimulationScreen(
                    entries: [entry],
                    contextEntries: contextEntries,
                    recommendedExplanations: recommendedExplanations
                )
            }
        }
    }

    private func coachingTheme(_ section: PhaseReviewSection) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("このフェーズのテーマ")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(section.themeTitle)
                .font(.title3.bold())
            Text(section.themeDetail)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func representativeCard(
        _ point: PhaseCoachPoint,
        section: PhaseReviewSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("代表局面")
                    .font(.headline)
                Spacer()
                Text("\(point.ply)手目")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ShogiBoardPanel(
                snapshot: point.snapshot,
                orientation: section.orientation,
                move: nil
            )
            .frame(maxWidth: 390)
            .frame(maxWidth: .infinity)

            Text(point.detail)
                .font(.body)

            if !point.evidence.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    Text("この局面で確認できたこと")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    ForEach(Array(point.evidence.enumerated()), id: \.offset) { _, evidence in
                        Label(evidence, systemImage: "checkmark.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let continuationPly = point.continuationPly,
               let continuation = continuationEntries.first(where: {
                   $0.ply == continuationPly
               }) {
                Button {
                    selectedContinuation = continuation
                } label: {
                    Label(
                        "推奨手と実戦手を動かして比較",
                        systemImage: "play.rectangle"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 2)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func noMajorIssueCard(
        _ point: PhaseCoachPoint,
        section: PhaseReviewSection
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("大きな改善ポイントは追加抽出されていません", systemImage: "checkmark.circle")
                .font(.headline)

            Text("このフェーズは最善手一覧として増やさず、盤面の流れだけ確認できます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ShogiBoardPanel(
                snapshot: point.snapshot,
                orientation: section.orientation,
                move: nil
            )
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    private func nextCheckCard(_ section: PhaseReviewSection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("次回この場面で確認すること")
                .font(.headline)
            Text(section.nextCheckText)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func supportPointStrip(_ section: PhaseReviewSection) -> some View {
        HStack(spacing: 8) {
            ForEach(section.points.filter { $0.kind != .important }) { point in
                Button {
                    selectedPointID = point.id
                } label: {
                    Text(point.kind == .transition ? "開始 \(point.ply)手" : "終了 \(point.ply)手")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(selectedBoardPoint?.id == point.id ? .accentColor : nil)
            }

            if let representative = representativePoint {
                Button {
                    selectedPointID = representative.id
                } label: {
                    Text("代表 \(representative.ply)手")
                        .font(.caption.bold())
                }
                .buttonStyle(.bordered)
                .tint(selectedBoardPoint?.id == representative.id ? .accentColor : nil)
            }
        }
    }

    private func supportTitle(_ point: PhaseCoachPoint) -> String {
        switch point.kind {
        case .transition:
            return "フェーズ開始時の盤面"
        case .important:
            return "代表局面"
        case .endpoint:
            return "フェーズ終了時の盤面"
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "square.split.2x1")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("明確な\(selectedPhase.title)区間なし")
                .font(.headline)
            Text("この対局では、盤面状態から独立した\(selectedPhase.title)区間を検出しませんでした。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .padding(.top, 40)
    }
}
