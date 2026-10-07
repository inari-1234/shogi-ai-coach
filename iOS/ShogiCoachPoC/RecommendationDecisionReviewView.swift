import SwiftUI
import ShogiCoachCore

struct RecommendationDecisionReviewScreen: View {
    let entries: [ContinuationSimulationEntry]
    let contextEntries: [ContextAnalysisEntry]
    let recommendedExplanations: [Int: ContextMoveExplanation]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(entries) { entry in
                    RecommendationDecisionPage(
                        entry: entry,
                        contextEntry: contextEntries.first { $0.ply == entry.ply },
                        recommendedExplanation: recommendedExplanations[entry.ply]
                    )
                    .padding(.horizontal)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            .navigationTitle("重要局面の判断理由")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct RecommendationDecisionPage: View {
    let entry: ContinuationSimulationEntry
    let contextEntry: ContextAnalysisEntry?
    let recommendedExplanation: ContextMoveExplanation?

    @State private var selectedKind: ContinuationRouteKind = .recommended
    @State private var currentStep = 0
    @State private var isPlaying = false

    private var decision: RecommendationDecisionPresentation {
        .make(entry: entry)
    }

    private var route: ContinuationRoute {
        selectedKind == .recommended ? entry.recommended : entry.actual
    }

    private var snapshot: BoardSnapshot {
        guard currentStep > 0, currentStep <= route.moves.count else {
            return route.initialSnapshot
        }
        return route.moves[currentStep - 1].snapshotAfter
    }

    private var currentMove: ContinuationMoveStep? {
        guard currentStep > 0, currentStep <= route.moves.count else { return nil }
        return route.moves[currentStep - 1]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header
                decisionCard
                routePicker
                routeOverview

                ShogiBoardPanel(
                    snapshot: snapshot,
                    orientation: entry.orientation,
                    move: currentMove
                )
                .frame(maxWidth: 430)

                controlBar
                moveExplanationCard
                moveStrip
                detailDisclosure
            }
            .padding(.bottom, 26)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("\(entry.ply)手目")
                .font(.headline)
            Spacer()
            Label(decision.status.badgeText, systemImage: statusSystemImage)
                .font(.caption.bold())
                .foregroundStyle(decision.status == .provisional ? .orange : .secondary)
        }
    }

    private var decisionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(decision.headline)
                .font(.title3.bold())

            decisionSection(title: "この手の意味", text: decision.meaning)

            Divider()

            decisionSection(title: "実戦手との違い", text: decision.difference)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("判断の確かさ")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(decision.confidenceTitle)
                    .font(.subheadline.weight(.semibold))
                Text(decision.confidenceDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func decisionSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }

    private var routePicker: some View {
        Picker("ルート", selection: $selectedKind) {
            ForEach(ContinuationRouteKind.allCases, id: \.self) { kind in
                Text(decision.routeLabel(for: kind)).tag(kind)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedKind) { _ in
            isPlaying = false
            currentStep = 0
        }
    }

    private var routeOverview: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(decision.routeMeaningTitle(for: selectedKind))
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(route.scoreText)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Text(decision.sanitizedRouteSummary(route))
                .font(.subheadline)

            if selectedKind == .recommended && !entry.continuationStable {
                Label("長い読み筋は参考扱いです", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }

    private var moveExplanationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let move = currentMove {
                Text(move.label)
                    .font(.headline)

                Text("盤面で起きたこと")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(move.factText)
                    .font(.subheadline)

                if let supplement = singleMoveSupplement(for: move) {
                    Divider()
                    Text("この手だけを見た補足")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(supplement)
                        .font(.subheadline)
                }

                HStack(spacing: 8) {
                    if move.effect.capturedPiece != nil {
                        eventBadge("駒取り", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                    if move.effect.promotes {
                        eventBadge("成り", systemImage: "arrow.up.circle")
                    }
                    if move.effect.isDrop {
                        eventBadge("駒打ち", systemImage: "plus.circle")
                    }
                    if move.givesCheck {
                        eventBadge("王手", systemImage: "bolt")
                    }
                }
            } else {
                Text("盤面を動かすと、上の判断理由がどの手順から生じるかを確認できます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func singleMoveSupplement(for move: ContinuationMoveStep) -> String? {
        guard currentStep == 1 else {
            return usefulCoachText(move.coachText)
        }

        let explanation = selectedKind == .actual
            ? contextEntry?.presentedExplanation
            : recommendedExplanation

        if let explanation,
           explanation.confidence != .unresolved,
           !explanation.conclusion.contains("断定できません") {
            if explanation.whyNow.isEmpty {
                return explanation.conclusion
            }
            return explanation.conclusion + " " + explanation.whyNow
        }

        return usefulCoachText(move.coachText)
    }

    private func usefulCoachText(_ text: String) -> String? {
        if text.contains("この1手だけでは狙いを断定せず")
            || text.contains("この一手だけでは狙いを断定せず") {
            return nil
        }
        return text
    }

    private var controlBar: some View {
        HStack(spacing: 12) {
            Button {
                isPlaying = false
                currentStep = 0
            } label: {
                Image(systemName: "backward.end.fill")
            }
            .disabled(currentStep == 0)

            Button {
                isPlaying = false
                currentStep = max(0, currentStep - 1)
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(currentStep == 0)

            Button {
                togglePlayback()
            } label: {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
            }
            .disabled(route.moves.isEmpty || currentStep >= route.moves.count)

            Button {
                isPlaying = false
                currentStep = min(route.moves.count, currentStep + 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(currentStep >= route.moves.count)

            Button {
                isPlaying = false
                currentStep = route.moves.count
            } label: {
                Image(systemName: "forward.end.fill")
            }
            .disabled(currentStep >= route.moves.count)
        }
        .buttonStyle(.bordered)
        .accessibilityElement(children: .contain)
    }

    private var moveStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button("開始") {
                    isPlaying = false
                    currentStep = 0
                }
                .buttonStyle(.bordered)
                .tint(currentStep == 0 ? .accentColor : nil)

                ForEach(route.moves) { move in
                    Button {
                        isPlaying = false
                        currentStep = move.index
                    } label: {
                        Text("\(move.index). \(move.label)")
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .buttonStyle(.bordered)
                    .tint(currentStep == move.index ? .accentColor : nil)
                }
            }
        }
    }

    private var detailDisclosure: some View {
        DisclosureGroup("この展開を詳しく見る") {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(route.developmentBlocks) { block in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(block.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(block.summary)
                            .font(.subheadline)
                    }
                }

                Divider()

                Text(route.stable ? "PVの到達形" : "参考到達形")
                    .font(.headline)
                Text(decision.sanitizedTargetShape(route))
                    .font(.subheadline)
                Text(
                    route.stable
                        ? "エンジンPVから再構築した範囲だけを表示しています。"
                        : "継続手順が安定していないため、この到達形は参考として表示します。"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
        }
    }

    private func eventBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }

    private var statusSystemImage: String {
        switch decision.status {
        case .matched: return "checkmark.circle"
        case .recommended: return "checkmark.seal"
        case .provisional: return "exclamationmark.triangle"
        }
    }

    private func togglePlayback() {
        guard !route.moves.isEmpty else { return }
        if isPlaying {
            isPlaying = false
            return
        }

        if currentStep >= route.moves.count {
            currentStep = 0
        }
        isPlaying = true
        let routeCount = route.moves.count

        Task { @MainActor in
            while isPlaying && currentStep < routeCount {
                try? await Task.sleep(for: .milliseconds(650))
                guard isPlaying else { break }
                currentStep = min(routeCount, currentStep + 1)
            }
            isPlaying = false
        }
    }
}
