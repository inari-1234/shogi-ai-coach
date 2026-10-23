import Foundation

public enum YaneuraOuLegalMoveSemanticsError: Error, LocalizedError, Equatable, Sendable {
    case sourcePieceMissing(String)
    case wrongSide(String)

    public var errorDescription: String? {
        switch self {
        case .sourcePieceMissing(let move):
            return "LEGAL_ALL の移動元に駒がありません: \(move)"
        case .wrongSide(let move):
            return "LEGAL_ALL の移動元が手番側の駒ではありません: \(move)"
        }
    }
}

/// Reconstructs YaneuraOu's default root-search move universe (`MoveList<LEGAL>`)
/// from an independently obtained `MoveList<LEGAL_ALL>` enumeration.
///
/// Pinned authority: YaneuraOu a5ee2786c0030edc7d4a1cdfe94b04dffec55493,
/// `movegen.cpp` with `All == false`.
///
/// This intentionally does not generate shogi legal moves. The engine remains the
/// authority for legality through LEGAL_ALL; Swift independently applies only the
/// search-specific non-promotion omissions that distinguish LEGAL from LEGAL_ALL.
public enum YaneuraOuLegalMoveSemantics {
    public static func searchRootMoves(
        snapshot: BoardSnapshot,
        legalAllMoves: [String]
    ) throws -> [String] {
        var result: [String] = []
        result.reserveCapacity(legalAllMoves.count)
        for move in legalAllMoves {
            if try isSearchRootMove(snapshot: snapshot, usi: move) {
                result.append(move)
            }
        }
        return result
    }

    public static func isSearchRootMove(
        snapshot: BoardSnapshot,
        usi: String
    ) throws -> Bool {
        let visual = try USIMoveVisual.parse(usi)
        if visual.isDrop || visual.promotes {
            return true
        }

        guard let sourceCoordinate = visual.source,
              let source = snapshot.piece(at: sourceCoordinate) else {
            throw YaneuraOuLegalMoveSemanticsError.sourcePieceMissing(usi)
        }
        guard source.side == snapshot.sideToMove else {
            throw YaneuraOuLegalMoveSemanticsError.wrongSide(usi)
        }

        switch source.kind {
        case .pawn:
            // In the pinned generator, a pawn move into the promotion zone is
            // generated as promotion-only for LEGAL. LEGAL_ALL additionally emits
            // the non-promotion variant except on the mandatory-promotion last rank.
            return !isPromotionZone(rank: visual.destination.rank, side: source.side)

        case .lance:
            // LEGAL omits the optional non-promotion on the second rank. The last
            // rank non-promotion is illegal and therefore absent from LEGAL_ALL too.
            let omittedRank = source.side == .black ? 2 : 8
            return visual.destination.rank != omittedRank

        case .bishop, .rook:
            // For bishop/rook, LEGAL emits promotion-only whenever promotion is
            // available from either the origin or destination square.
            return !(isPromotionZone(rank: sourceCoordinate.rank, side: source.side)
                || isPromotionZone(rank: visual.destination.rank, side: source.side))

        default:
            return true
        }
    }

    private static func isPromotionZone(rank: Int, side: ShogiSide) -> Bool {
        switch side {
        case .black:
            return (1...3).contains(rank)
        case .white:
            return (7...9).contains(rank)
        }
    }
}
