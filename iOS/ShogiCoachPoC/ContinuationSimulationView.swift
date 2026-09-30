import SwiftUI
import ShogiCoachCore

struct ContinuationSimulationScreen: View {
    let entries: [ContinuationSimulationEntry]
    let contextEntries: [ContextAnalysisEntry]
    let recommendedExplanations: [Int: ContextMoveExplanation]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(entries) { entry in
                    ContinuationPositionPage(
                        entry: entry,
                        contextEntry: contextEntries.first { $0.ply == entry.ply },
                        recommendedExplanation: recommendedExplanations[entry.ply]
                    )
                    .padding(.horizontal)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            .navigationTitle("重要局面を盤面で振り返る")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

private struct ContinuationPositionPage: View {
    let entry: ContinuationSimulationEntry
    let contextEntry: ContextAnalysisEntry?
    let recommendedExplanation: ContextMoveExplanation?

    @State private var selectedKind: ContinuationRouteKind = .recommended
    @State private var currentStep = 0
    @State private var isPlaying = false

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
                HStack {
                    Text("\(entry.ply)手目")
                        .font(.headline)
                    Spacer()
                    if entry.comparisonStable {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(entry.actualLossCp.map { "同条件差 \($0)cp" } ?? "同条件比較")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if !entry.continuationStable {
                                Label("読み筋は参考", systemImage: "exclamationmark.triangle")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                    } else {
                        Label("比較判定保留", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Picker("ルート", selection: $selectedKind) {
                    ForEach(ContinuationRouteKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedKind) { _ in
                    isPlaying = false
                    currentStep = 0
                }

                HStack {
                    Text(route.scoreText)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(currentStep == 0
                         ? "開始局面"
                         : "\(currentStep)/\(route.moves.count)手")
                        .font(.caption.monospacedDigit())
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(selectedKind == .recommended ? "推奨ルートの意味" : "実戦ルートの意味")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(route.summary)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                ShogiBoardPanel(
                    snapshot: snapshot,
                    orientation: entry.orientation,
                    move: currentMove
                )
                .frame(maxWidth: 430)

                controlBar

                VStack(alignment: .leading, spacing: 8) {
                    if let move = currentMove {
                        Text(move.label)
                            .font(.headline)

                        Text("盤面で起きたこと")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                        Text(move.factText)
                            .font(.subheadline)

                        Divider()

                        if currentStep == 1,
                           let explanation = selectedKind == .actual
                               ? contextEntry?.explanation
                               : recommendedExplanation {
                            ContextExplanationCard(explanation: explanation)
                        } else {
                            Text("この手で確認できる変化")
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            Text(move.coachText)
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
                        Text("盤面を動かすと、各手の事実と意味をここに表示します。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))

                moveStrip

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
                        Text(route.targetShapeSummary)
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
                .padding(.bottom, 26)
            }
        }
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

    private func eventBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
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

private struct ContextExplanationCard: View {
    let explanation: ContextMoveExplanation

    private var confidenceText: String {
        switch explanation.confidence {
        case .high: return "確度 HIGH"
        case .medium: return "確度 MEDIUM"
        case .low: return "確度 LOW"
        case .unresolved: return "判定保留"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("この手の意味")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(confidenceText)
                    .font(.caption2.bold())
                    .foregroundStyle(
                        explanation.tone == .unresolved || explanation.tone == .tentative
                            ? .orange
                            : .secondary
                    )
            }

            Text(explanation.conclusion)
                .font(.subheadline.weight(.semibold))

            Text("なぜ今")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(explanation.whyNow)
                .font(.subheadline)

            Text("根拠")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(explanation.evidenceText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ShogiBoardPanel: View {
    let snapshot: BoardSnapshot
    let orientation: ShogiSide
    let move: ContinuationMoveStep?

    private var opponentSide: ShogiSide {
        orientation == .black ? .white : .black
    }

    var body: some View {
        VStack(spacing: 6) {
            ShogiHandStrip(
                snapshot: snapshot,
                side: opponentSide,
                label: "相手の持駒",
                alignLeading: false
            )

            ContinuationBoardView(
                snapshot: snapshot,
                orientation: orientation,
                move: move
            )

            ShogiHandStrip(
                snapshot: snapshot,
                side: orientation,
                label: "自分の持駒",
                alignLeading: true
            )
        }
    }
}

private struct ShogiHandStrip: View {
    let snapshot: BoardSnapshot
    let side: ShogiSide
    let label: String
    let alignLeading: Bool

    private let kinds: [BoardPieceKind] = [
        .rook, .bishop, .gold, .silver, .knight, .lance, .pawn
    ]

    private var items: [(BoardPieceKind, Int)] {
        kinds.compactMap { kind in
            let count = snapshot.handCount(side: side, kind: kind)
            return count > 0 ? (kind, count) : nil
        }
    }

    var body: some View {
        VStack(alignment: alignLeading ? .leading : .trailing, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)

            if items.isEmpty {
                Text("なし")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: alignLeading ? .leading : .trailing)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 2) {
                            Text(item.0.kanji)
                                .font(.system(.caption, design: .serif).weight(.semibold))
                            if item.1 > 1 {
                                Text("×\(item.1)")
                                    .font(.caption2.monospacedDigit())
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: alignLeading ? .leading : .trailing)
            }
        }
        .foregroundStyle(.primary)
    }
}

private struct ShogiPieceShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.minY + rect.height * 0.18))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.04, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.04, y: rect.maxY - rect.height * 0.04))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.12, y: rect.minY + rect.height * 0.18))
        path.closeSubpath()
        return path
    }
}

struct ContinuationBoardView: View {
    let snapshot: BoardSnapshot
    let orientation: ShogiSide
    let move: ContinuationMoveStep?

    private var files: [Int] {
        orientation == .black ? Array((1...9).reversed()) : Array(1...9)
    }

    private var ranks: [Int] {
        orientation == .black ? Array(1...9) : Array((1...9).reversed())
    }

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9.0

            ZStack {
                VStack(spacing: 0) {
                    ForEach(Array(ranks.enumerated()), id: \.offset) { _, rank in
                        HStack(spacing: 0) {
                            ForEach(Array(files.enumerated()), id: \.offset) { _, file in
                                squareView(
                                    coordinate: BoardCoordinate(file: file, rank: rank)
                                )
                                .frame(width: cell, height: cell)
                            }
                        }
                    }
                }

                if let move, let source = move.effect.source {
                    moveArrow(
                        from: center(of: source, cell: cell),
                        to: center(of: move.effect.destination, cell: cell),
                        cell: cell
                    )
                } else if let move, move.effect.isDrop {
                    dropOverlay(move: move, cell: cell)
                }
            }
            .frame(width: side, height: side)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.84, green: 0.67, blue: 0.39),
                        Color(red: 0.76, green: 0.55, blue: 0.28)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Rectangle()
                    .stroke(Color(red: 0.25, green: 0.16, blue: 0.08), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(move.map { "将棋盤。\($0.label)" } ?? "将棋盤。開始局面")
    }

    @ViewBuilder
    private func squareView(coordinate: BoardCoordinate) -> some View {
        ZStack {
            Rectangle()
                .fill(highlightColor(for: coordinate))
            Rectangle()
                .stroke(
                    Color(red: 0.28, green: 0.18, blue: 0.08).opacity(0.9),
                    lineWidth: 0.55
                )

            if let piece = snapshot.piece(at: coordinate) {
                ZStack {
                    ShogiPieceShape()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.84, blue: 0.60),
                                    Color(red: 0.88, green: 0.69, blue: 0.39)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .overlay(
                            ShogiPieceShape()
                                .stroke(
                                    Color(red: 0.34, green: 0.21, blue: 0.08),
                                    lineWidth: 0.8
                                )
                        )
                        .shadow(color: .black.opacity(0.18), radius: 0.8, y: 0.7)

                    Text(piece.kind.kanji)
                        .font(.system(size: piece.kind.kanji.count > 1 ? 11 : 17, weight: .bold, design: .serif))
                        .minimumScaleFactor(0.55)
                        .foregroundStyle(
                            piece.kind.isPromoted
                                ? Color(red: 0.62, green: 0.08, blue: 0.05)
                                : Color(red: 0.10, green: 0.07, blue: 0.04)
                        )
                }
                .padding(3)
                .rotationEffect(piece.side == orientation ? .degrees(0) : .degrees(180))
            }
        }
    }

    private func highlightColor(for coordinate: BoardCoordinate) -> Color {
        guard let move else { return .clear }
        if coordinate == move.effect.destination {
            return move.effect.capturedPiece == nil
                ? Color(red: 0.32, green: 0.60, blue: 0.30).opacity(0.42)
                : Color(red: 0.70, green: 0.20, blue: 0.16).opacity(0.40)
        }
        if coordinate == move.effect.source {
            return Color(red: 0.82, green: 0.48, blue: 0.12).opacity(0.42)
        }
        return .clear
    }

    private func center(of coordinate: BoardCoordinate, cell: CGFloat) -> CGPoint {
        let column = CGFloat(files.firstIndex(of: coordinate.file) ?? 0)
        let row = CGFloat(ranks.firstIndex(of: coordinate.rank) ?? 0)
        return CGPoint(
            x: column * cell + cell / 2,
            y: row * cell + cell / 2
        )
    }

    @ViewBuilder
    private func moveArrow(from start: CGPoint, to end: CGPoint, cell: CGFloat) -> some View {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(sqrt(dx * dx + dy * dy), 1)
        let ux = dx / length
        let uy = dy / length
        let inset = min(cell * 0.23, length * 0.18)
        let arrowStart = CGPoint(x: start.x + ux * inset, y: start.y + uy * inset)
        let arrowEnd = CGPoint(x: end.x - ux * inset, y: end.y - uy * inset)
        let head = min(cell * 0.28, 13)
        let left = CGPoint(
            x: arrowEnd.x - ux * head - uy * head * 0.58,
            y: arrowEnd.y - uy * head + ux * head * 0.58
        )
        let right = CGPoint(
            x: arrowEnd.x - ux * head + uy * head * 0.58,
            y: arrowEnd.y - uy * head - ux * head * 0.58
        )

        Path { path in
            path.move(to: arrowStart)
            path.addLine(to: arrowEnd)
            path.move(to: arrowEnd)
            path.addLine(to: left)
            path.move(to: arrowEnd)
            path.addLine(to: right)
        }
        .stroke(
            Color.white.opacity(0.92),
            style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round)
        )
        .overlay {
            Path { path in
                path.move(to: arrowStart)
                path.addLine(to: arrowEnd)
                path.move(to: arrowEnd)
                path.addLine(to: left)
                path.move(to: arrowEnd)
                path.addLine(to: right)
            }
            .stroke(
                Color.blue,
                style: StrokeStyle(lineWidth: 3.3, lineCap: .round, lineJoin: .round)
            )
        }
    }

    @ViewBuilder
    private func dropOverlay(move: ContinuationMoveStep, cell: CGFloat) -> some View {
        let point = center(of: move.effect.destination, cell: cell)

        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 3)
                .stroke(
                    Color.blue,
                    style: StrokeStyle(lineWidth: 2.5, dash: [5, 3])
                )
            Image(systemName: "plus")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(3)
                .background(Circle().fill(Color.blue))
                .offset(x: cell * 0.12, y: -cell * 0.12)
        }
        .frame(width: cell * 0.78, height: cell * 0.78)
        .position(point)
    }
}
