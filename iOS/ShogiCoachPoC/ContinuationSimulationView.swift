import SwiftUI
import ShogiCoachCore

struct ContinuationSimulationScreen: View {
    let entries: [ContinuationSimulationEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(entries) { entry in
                    ContinuationPositionPage(entry: entry)
                        .padding(.horizontal)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            .navigationTitle("推奨展開シミュレーション")
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
                        Text(entry.actualLossCp.map { "同条件差 \($0)cp" } ?? "同条件比較")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("探索未安定", systemImage: "exclamationmark.triangle")
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

                ContinuationBoardView(
                    snapshot: snapshot,
                    orientation: entry.orientation,
                    move: currentMove
                )
                .frame(maxWidth: 430)

                controlBar

                if let move = currentMove {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(move.label)
                            .font(.headline)
                        Text(move.coachText)
                            .font(.subheadline)

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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                } else {
                    Text(entry.reasonSummary)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                moveStrip

                VStack(alignment: .leading, spacing: 8) {
                    Text("展開のまとまり")
                        .font(.headline)
                    ForEach(route.developmentBlocks) { block in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(block.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(block.summary)
                                .font(.subheadline)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    Text("このPVの到達形")
                        .font(.headline)
                    Text(route.targetShapeSummary)
                        .font(.subheadline)
                    Text("エンジンPVから再構築した到達形だけを表示し、PVにない理想形は補っていません。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text("\(move.index). \(move.usi)")
                            .font(.system(.caption, design: .monospaced))
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

private struct ContinuationBoardView: View {
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
            .background(Color.brown.opacity(0.13))
            .overlay(Rectangle().stroke(Color.primary.opacity(0.75), lineWidth: 1.5))
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
                .stroke(Color.primary.opacity(0.55), lineWidth: 0.5)

            if let piece = snapshot.piece(at: coordinate) {
                Text(piece.kind.kanji)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.55)
                    .rotationEffect(piece.side == orientation ? .degrees(0) : .degrees(180))
            }
        }
    }

    private func highlightColor(for coordinate: BoardCoordinate) -> Color {
        guard let move else { return .clear }
        if coordinate == move.effect.destination {
            return move.effect.capturedPiece == nil ? .green.opacity(0.34) : .red.opacity(0.28)
        }
        if coordinate == move.effect.source {
            return .orange.opacity(0.34)
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
            Color.blue,
            style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
        )
    }

    @ViewBuilder
    private func dropOverlay(move: ContinuationMoveStep, cell: CGFloat) -> some View {
        let point = center(of: move.effect.destination, cell: cell)

        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.18))
                .overlay(
                    Circle()
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 3, dash: [5, 3])
                        )
                )
            Text(move.effect.pieceBefore.kanji)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(.blue)
            Image(systemName: "plus")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(3)
                .background(Circle().fill(Color.blue))
                .offset(x: cell * 0.28, y: -cell * 0.28)
        }
        .frame(width: cell * 0.82, height: cell * 0.82)
        .position(point)
    }
}
