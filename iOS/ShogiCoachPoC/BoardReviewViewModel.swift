import Foundation
import ShogiCoachCore

struct BoardReviewEntry: Identifiable {
    let id: Int
    let ply: Int
    let snapshot: BoardSnapshot
    let orientation: ShogiSide
    let bestMoveText: String
    let bestMove: USIMoveVisual
    let bestPiece: BoardPieceKind
    let actualMoveText: String
    let actualMove: USIMoveVisual

    var isDrop: Bool { bestMove.isDrop }
}

@MainActor
final class BoardReviewViewModel: ObservableObject {
    @Published private(set) var status = "未準備"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [BoardReviewEntry] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    func reset() {
        status = "未準備"
        summary = ""
        entries = []
        diagnosticURL = nil
        diagnosticError = nil
    }

    func prepare(
        game: KIFGame,
        deepEntries: [DeepAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?
    ) {
        reset()

        guard !deepEntries.isEmpty else {
            status = "盤面表示 未PASS"
            summary = "工程4の重要局面がありません"
            return
        }

        guard let sourceDiagnosticURL else {
            status = "盤面表示 未PASS"
            summary = "工程4の診断JSONがありません"
            return
        }

        let orientation = Self.userOrientation(game: game)
        var resolved: [BoardReviewEntry] = []
        var diagnosticPositions: [ShogiDiagnosticDocument.BoardDisplayPositionInfo] = []

        do {
            for deepEntry in deepEntries {
                guard deepEntry.ply >= 1, deepEntry.ply <= game.moves.count else {
                    throw BoardReviewError.invalidPly(deepEntry.ply)
                }
                let kifMove = game.moves[deepEntry.ply - 1]
                let snapshot = try BoardSnapshotResolver.resolve(
                    positionCommand: kifMove.positionBefore
                )
                let expectedSide: ShogiSide = deepEntry.ply.isMultiple(of: 2) ? .white : .black
                guard snapshot.sideToMove == expectedSide else {
                    throw BoardReviewError.sideMismatch(deepEntry.ply)
                }

                let best = try USIMoveVisual.parse(deepEntry.bestMove)
                let actual = try USIMoveVisual.parse(deepEntry.actualMove)
                let bestPiece = try Self.resolveBestPiece(
                    visual: best,
                    snapshot: snapshot,
                    ply: deepEntry.ply
                )

                let item = BoardReviewEntry(
                    id: deepEntry.ply,
                    ply: deepEntry.ply,
                    snapshot: snapshot,
                    orientation: orientation,
                    bestMoveText: deepEntry.bestMove,
                    bestMove: best,
                    bestPiece: bestPiece,
                    actualMoveText: deepEntry.actualMove,
                    actualMove: actual
                )
                resolved.append(item)

                diagnosticPositions.append(
                    .init(
                        ply: deepEntry.ply,
                        sideToMove: snapshot.sideToMove.rawValue,
                        orientation: orientation.rawValue,
                        bestMove: deepEntry.bestMove,
                        source: best.source?.usi,
                        destination: best.destination.usi,
                        isDrop: best.isDrop,
                        piece: bestPiece.kanji,
                        promotes: best.promotes,
                        actualMove: deepEntry.actualMove,
                        actualSource: actual.source?.usi,
                        actualDestination: actual.destination.usi,
                        squarePieceCount: snapshot.pieceCount,
                        blackHandCount: snapshot.totalHandCount(side: .black),
                        whiteHandCount: snapshot.totalHandCount(side: .white)
                    )
                )
            }

            entries = resolved
            status = "盤面表示 PASS"
            summary = [
                "important positions: \(resolved.count)/\(deepEntries.count)",
                "orientation: \(orientation == .black ? "先手" : "後手")",
                "best moves resolved: \(resolved.count)/\(resolved.count)",
                "drops: \(resolved.filter(\.isDrop).count)"
            ].joined(separator: "\n")

            let boardInfo = ShogiDiagnosticDocument.BoardDisplayInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: nil
            )
            diagnosticURL = try DiagnosticExporter.augmentWithBoardDisplay(
                url: sourceDiagnosticURL,
                boardDisplay: boardInfo
            )
            SimulatorStage.mark("board_display_complete_\(resolved.count)")
        } catch {
            let message = error.localizedDescription
            status = "盤面表示 未PASS"
            summary = [
                "completed: \(resolved.count)/\(deepEntries.count)",
                message
            ].joined(separator: "\n")
            entries = resolved

            let boardInfo = ShogiDiagnosticDocument.BoardDisplayInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: message
            )
            do {
                diagnosticURL = try DiagnosticExporter.augmentWithBoardDisplay(
                    url: sourceDiagnosticURL,
                    boardDisplay: boardInfo
                )
            } catch {
                diagnosticError = error.localizedDescription
            }
            SimulatorStage.mark("board_display_error_\(message)")
        }
    }

    private static func userOrientation(game: KIFGame) -> ShogiSide {
        let sente = game.metadata["先手"] ?? ""
        let gote = game.metadata["後手"] ?? ""
        if gote.contains("あなた"), !sente.contains("あなた") {
            return .white
        }
        return .black
    }

    private static func resolveBestPiece(
        visual: USIMoveVisual,
        snapshot: BoardSnapshot,
        ply: Int
    ) throws -> BoardPieceKind {
        if let dropPiece = visual.dropPiece {
            guard snapshot.handCount(side: snapshot.sideToMove, kind: dropPiece) > 0 else {
                throw BoardReviewError.missingDropPiece(ply, dropPiece.rawValue)
            }
            return dropPiece
        }

        guard let source = visual.source,
              let piece = snapshot.piece(at: source) else {
            throw BoardReviewError.missingSource(ply, visual.source?.usi ?? "-")
        }
        guard piece.side == snapshot.sideToMove else {
            throw BoardReviewError.sideMismatch(ply)
        }

        if visual.promotes {
            guard let promoted = piece.kind.promoted else {
                throw BoardReviewError.invalidPromotion(ply)
            }
            return promoted
        }
        return piece.kind
    }
}

enum BoardReviewError: Error, LocalizedError {
    case invalidPly(Int)
    case sideMismatch(Int)
    case missingSource(Int, String)
    case missingDropPiece(Int, String)
    case invalidPromotion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPly(let ply):
            return "\(ply)手目が棋譜範囲外です"
        case .sideMismatch(let ply):
            return "\(ply)手目の手番が盤面と一致しません"
        case .missingSource(let ply, let source):
            return "\(ply)手目の最善手の移動元 \(source) に駒がありません"
        case .missingDropPiece(let ply, let piece):
            return "\(ply)手目の最善手で持駒 \(piece) が不足しています"
        case .invalidPromotion(let ply):
            return "\(ply)手目の最善手の成り指定が不正です"
        }
    }
}
