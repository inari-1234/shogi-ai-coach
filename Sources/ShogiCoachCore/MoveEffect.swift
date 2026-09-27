import Foundation

public struct MoveEffect: Equatable, Sendable {
    public let move: String
    public let side: ShogiSide
    public let source: BoardCoordinate?
    public let destination: BoardCoordinate
    public let pieceBefore: BoardPieceKind
    public let pieceAfter: BoardPieceKind
    public let capturedPiece: BoardPieceKind?
    public let isDrop: Bool
    public let promotes: Bool

    public init(
        move: String,
        side: ShogiSide,
        source: BoardCoordinate?,
        destination: BoardCoordinate,
        pieceBefore: BoardPieceKind,
        pieceAfter: BoardPieceKind,
        capturedPiece: BoardPieceKind?,
        isDrop: Bool,
        promotes: Bool
    ) {
        self.move = move
        self.side = side
        self.source = source
        self.destination = destination
        self.pieceBefore = pieceBefore
        self.pieceAfter = pieceAfter
        self.capturedPiece = capturedPiece
        self.isDrop = isDrop
        self.promotes = promotes
    }
}

public enum MoveEffectResolver {
    public static func resolve(
        positionCommand: String,
        move: String
    ) throws -> MoveEffect {
        let snapshot = try BoardSnapshotResolver.resolve(positionCommand: positionCommand)
        let visual = try USIMoveVisual.parse(move)
        let side = snapshot.sideToMove

        if visual.isDrop {
            guard let dropPiece = visual.dropPiece else {
                throw BoardSnapshotError.invalidMove(move)
            }
            guard snapshot.handCount(side: side, kind: dropPiece) > 0 else {
                throw BoardSnapshotError.missingHandPiece(move)
            }
            guard snapshot.piece(at: visual.destination) == nil else {
                throw BoardSnapshotError.occupiedDrop(move)
            }
            return MoveEffect(
                move: move,
                side: side,
                source: nil,
                destination: visual.destination,
                pieceBefore: dropPiece,
                pieceAfter: dropPiece,
                capturedPiece: nil,
                isDrop: true,
                promotes: false
            )
        }

        guard let sourceCoordinate = visual.source,
              let sourcePiece = snapshot.piece(at: sourceCoordinate) else {
            throw BoardSnapshotError.sourcePieceMissing(move)
        }
        guard sourcePiece.side == side else {
            throw BoardSnapshotError.wrongSide(move)
        }

        let captured = snapshot.piece(at: visual.destination)
        if captured?.side == side {
            throw BoardSnapshotError.invalidMove(move)
        }

        let pieceAfter: BoardPieceKind
        if visual.promotes {
            guard let promoted = sourcePiece.kind.promoted else {
                throw BoardSnapshotError.invalidPromotion(move)
            }
            pieceAfter = promoted
        } else {
            pieceAfter = sourcePiece.kind
        }

        return MoveEffect(
            move: move,
            side: side,
            source: sourceCoordinate,
            destination: visual.destination,
            pieceBefore: sourcePiece.kind,
            pieceAfter: pieceAfter,
            capturedPiece: captured?.kind,
            isDrop: false,
            promotes: visual.promotes
        )
    }

    public static func appending(
        move: String,
        to positionCommand: String
    ) throws -> String {
        _ = try resolve(positionCommand: positionCommand, move: move)
        let tokens = positionCommand.split(whereSeparator: { $0.isWhitespace })
        guard tokens.count >= 2,
              tokens[0] == "position",
              tokens[1] == "startpos" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }
        if tokens.count == 2 {
            return positionCommand + " moves " + move
        }
        guard tokens.count >= 4, tokens[2] == "moves" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }
        return positionCommand + " " + move
    }
}
