import SwiftUI
import ShogiCoachCore

struct BoardReviewScreen: View {
    let entries: [BoardReviewEntry]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(entries) { entry in
                    VStack(spacing: 14) {
                        HStack {
                            Text("\(entry.ply)手目")
                                .font(.headline)
                            Spacer()
                            Text(entry.bestMoveText)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        BoardBestMoveView(entry: entry)
                            .frame(maxWidth: 430)

                        HStack(spacing: 18) {
                            Label("移動元", systemImage: "circle.fill")
                                .foregroundStyle(.orange)
                            Label("移動先", systemImage: "circle.fill")
                                .foregroundStyle(.green)
                            if entry.isDrop {
                                Label("駒打ち", systemImage: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .font(.caption)

                        Spacer(minLength: 0)
                    }
                    .padding()
                }
            }
            .tabViewStyle(.page(indexDisplayMode: entries.count > 1 ? .automatic : .never))
            .navigationTitle("最善手を盤面で確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}

struct BoardBestMoveView: View {
    let entry: BoardReviewEntry

    private var files: [Int] {
        entry.orientation == .black ? Array((1...9).reversed()) : Array(1...9)
    }

    private var ranks: [Int] {
        entry.orientation == .black ? Array(1...9) : Array((1...9).reversed())
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

                if let source = entry.bestMove.source {
                    moveArrow(
                        from: center(of: source, cell: cell),
                        to: center(of: entry.bestMove.destination, cell: cell),
                        cell: cell
                    )
                } else {
                    dropOverlay(cell: cell)
                }
            }
            .frame(width: side, height: side)
            .background(Color.brown.opacity(0.13))
            .overlay(
                Rectangle()
                    .stroke(Color.primary.opacity(0.75), lineWidth: 1.5)
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("将棋盤。最善手 \(entry.bestMoveText)")
    }

    @ViewBuilder
    private func squareView(coordinate: BoardCoordinate) -> some View {
        ZStack {
            Rectangle()
                .fill(highlightColor(for: coordinate))
            Rectangle()
                .stroke(Color.primary.opacity(0.55), lineWidth: 0.5)

            if let piece = entry.snapshot.piece(at: coordinate) {
                Text(piece.kind.kanji)
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .minimumScaleFactor(0.55)
                    .rotationEffect(
                        piece.side == entry.orientation ? .degrees(0) : .degrees(180)
                    )
            }
        }
    }

    private func highlightColor(for coordinate: BoardCoordinate) -> Color {
        if coordinate == entry.bestMove.destination {
            return .green.opacity(0.34)
        }
        if coordinate == entry.bestMove.source {
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
        .shadow(radius: 1)
    }

    @ViewBuilder
    private func dropOverlay(cell: CGFloat) -> some View {
        let point = center(of: entry.bestMove.destination, cell: cell)

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
            Text(entry.bestPiece.kanji)
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
        .accessibilityLabel("\(entry.bestPiece.kanji)を\(entry.bestMove.destination.usi)へ打つ")
    }
}
