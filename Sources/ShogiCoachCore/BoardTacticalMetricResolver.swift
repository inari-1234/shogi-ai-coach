import Foundation

public enum BoardTacticalMetricResolver {
    public static func isKingInCheck(snapshot: BoardSnapshot, checkedSide: ShogiSide) -> Bool {
        guard let king = kingSquare(snapshot: snapshot, side: checkedSide) else { return false }
        let attacker = opponent(of: checkedSide)
        return snapshot.squares.contains { coordinate, piece in
            guard piece.side == attacker else { return false }
            return attacks(from: coordinate, piece: piece, target: king, snapshot: snapshot)
        }
    }

    public static func kingZoneDefenderCount(snapshot: BoardSnapshot, side: ShogiSide) -> Int {
        guard let king = kingSquare(snapshot: snapshot, side: side) else { return 0 }
        return snapshot.squares.reduce(into: 0) { count, item in
            guard item.value.side == side, item.value.kind != .king else { return }
            if chebyshevDistance(item.key, king) <= 1 { count += 1 }
        }
    }

    public static func kingZoneAttackerCount(snapshot: BoardSnapshot, checkedSide: ShogiSide) -> Int {
        guard let king = kingSquare(snapshot: snapshot, side: checkedSide) else { return 0 }
        let files = max(1, king.file - 1)...min(9, king.file + 1)
        let ranks = max(1, king.rank - 1)...min(9, king.rank + 1)
        let targets = files.flatMap { file in
            ranks.map { BoardCoordinate(file: file, rank: $0) }
        }
        let attacker = opponent(of: checkedSide)
        return snapshot.squares.reduce(into: 0) { count, item in
            guard item.value.side == attacker else { return }
            if targets.contains(where: {
                attacks(from: item.key, piece: item.value, target: $0, snapshot: snapshot)
            }) {
                count += 1
            }
        }
    }

    private static func opponent(of side: ShogiSide) -> ShogiSide {
        side == .black ? .white : .black
    }

    private static func kingSquare(snapshot: BoardSnapshot, side: ShogiSide) -> BoardCoordinate? {
        snapshot.squares.first {
            $0.value.side == side && $0.value.kind == .king
        }?.key
    }

    private static func chebyshevDistance(_ lhs: BoardCoordinate, _ rhs: BoardCoordinate) -> Int {
        max(abs(lhs.file - rhs.file), abs(lhs.rank - rhs.rank))
    }

    private static func attacks(
        from source: BoardCoordinate,
        piece: BoardPieceState,
        target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let df = target.file - source.file
        let dr = target.rank - source.rank
        let forward = piece.side == .black ? -1 : 1

        switch piece.kind {
        case .pawn:
            return df == 0 && dr == forward
        case .lance:
            guard df == 0, dr * forward > 0 else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .knight:
            return abs(df) == 1 && dr == 2 * forward
        case .silver:
            return (abs(df) == 1 && dr == forward)
                || (abs(df) == 1 && dr == -forward)
                || (df == 0 && dr == forward)
        case .gold, .promotedPawn, .promotedLance, .promotedKnight, .promotedSilver:
            return (dr == forward && abs(df) <= 1)
                || (dr == 0 && abs(df) == 1)
                || (df == 0 && dr == -forward)
        case .bishop:
            guard abs(df) == abs(dr), df != 0 else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .rook:
            guard (df == 0) != (dr == 0) else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .king:
            return max(abs(df), abs(dr)) == 1
        case .horse:
            if abs(df) == abs(dr), df != 0 {
                return clearLine(from: source, to: target, snapshot: snapshot)
            }
            return abs(df) + abs(dr) == 1
        case .dragon:
            if (df == 0) != (dr == 0) {
                return clearLine(from: source, to: target, snapshot: snapshot)
            }
            return abs(df) == 1 && abs(dr) == 1
        }
    }

    private static func clearLine(
        from source: BoardCoordinate,
        to target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let stepFile = target.file == source.file ? 0 : (target.file > source.file ? 1 : -1)
        let stepRank = target.rank == source.rank ? 0 : (target.rank > source.rank ? 1 : -1)
        var file = source.file + stepFile
        var rank = source.rank + stepRank
        while file != target.file || rank != target.rank {
            if snapshot.piece(at: BoardCoordinate(file: file, rank: rank)) != nil { return false }
            file += stepFile
            rank += stepRank
        }
        return true
    }
}
