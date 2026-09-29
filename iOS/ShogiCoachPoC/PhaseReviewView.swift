import SwiftUI
import ShogiCoachCore

struct PhaseReviewScreen: View {
    let sections: [PhaseReviewSection]
    let continuationEntries: [ContinuationSimulationEntry]

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhase: GamePhaseKind = .opening
    @State private var selectedPointID: String?
    @State private var selectedContinuation: ContinuationSimulationEntry?

    private var selectedSection: PhaseReviewSection? {
        sections.first { $0.kind == selectedPhase }
    }

    private var selectedPoint: PhaseCoachPoint? {
        guard let section = selectedSection else { return nil }
        if let selectedPointID,
           let point = section.points.first(where: { $0.id == selectedPointID }) {
            return point
        }
        return section.points.first
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
                    if let section = selectedSection, let point = selectedPoint {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("\(section.kind.title)　\(section.startPly)〜\(section.endPly)手")
                                    .font(.headline)
                                Text(section.summary)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            pointStrip(section)

                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(point.title)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(point.ply)手目")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                ContinuationBoardView(
                                    snapshot: point.snapshot,
                                    orientation: section.orientation,
                                    move: nil
                                )
                                .frame(maxWidth: 390)
                                .frame(maxWidth: .infinity)

                                Text(point.detail)
                                    .font(.body)

                                ForEach(Array(point.evidence.enumerated()), id: \.offset) { _, evidence in
                                    Label(evidence, systemImage: "checkmark.circle")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                if let continuationPly = point.continuationPly,
                                   let continuation = continuationEntries.first(where: {
                                       $0.ply == continuationPly
                                   }) {
                                    Button {
                                        selectedContinuation = continuation
                                    } label: {
                                        Label(
                                            "この局面を動かして見る",
                                            systemImage: "play.rectangle"
                                        )
                                        .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .padding(.top, 4)
                                }
                            }
                            .padding(12)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("このフェーズで覚えること")
                                    .font(.headline)
                                Text(section.takeawayText)
                                    .font(.subheadline)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
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
                ContinuationSimulationScreen(entries: [entry])
            }
        }
    }

    private func pointStrip(_ section: PhaseReviewSection) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(section.points) { point in
                    Button {
                        selectedPointID = point.id
                    } label: {
                        Text(pointLabel(point))
                            .font(.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedPoint?.id == point.id ? .accentColor : nil)
                }
            }
        }
    }

    private func pointLabel(_ point: PhaseCoachPoint) -> String {
        switch point.kind {
        case .transition:
            return "開始 \(point.ply)"
        case .important:
            return "重要 \(point.ply)"
        case .endpoint:
            return "終点 \(point.ply)"
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
