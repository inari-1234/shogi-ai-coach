import Foundation

public struct BoardCoordinate: Hashable, Equatable, Sendable {
    public let file: Int
    public let rank: Int

    public init(file: Int, rank: Int) {
        self.file = file
        self.rank = rank
    }

    public var usi: String {
        guard (1...9).contains(file), (1...9).contains(rank) else { return "??" }
        let ranks = Array("abcdefghi")
        return "\(file)\(ranks[rank - 1])"
    }
}

public enum BoardPieceKind: String, Hashable, Equatable, Sendable {
    case pawn = "P"
    case lance = "L"
    case knight = "N"
    case silver = "S"
    case gold = "G"
    case bishop = "B"
    case rook = "R"
    case king = "K"
    case promotedPawn = "+P"
    case promotedLance = "+L"
    case promotedKnight = "+N"
    case promotedSilver = "+S"
    case horse = "+B"
    case dragon = "+R"

    public init?(kifName: String) {
        switch kifName {
        case "歩": self = .pawn
        case "香": self = .lance
        case "桂": self = .knight
        case "銀": self = .silver
        case "金": self = .gold
        case "角": self = .bishop
        case "飛": self = .rook
        case "玉", "王": self = .king
        case "と": self = .promotedPawn
        case "成香": self = .promotedLance
        case "成桂": self = .promotedKnight
        case "成銀": self = .promotedSilver
        case "馬": self = .horse
        case "龍", "竜": self = .dragon
        default: return nil
        }
    }

    public var kifName: String { kanji }

    public var isPromoted: Bool { self != base }

    public var isPromotable: Bool {
        switch self {
        case .pawn, .lance, .knight, .silver, .bishop, .rook:
            return true
        default:
            return false
        }
    }

    public var kanji: String {
        switch self {
        case .pawn: return "歩"
        case .lance: return "香"
        case .knight: return "桂"
        case .silver: return "銀"
        case .gold: return "金"
        case .bishop: return "角"
        case .rook: return "飛"
        case .king: return "玉"
        case .promotedPawn: return "と"
        case .promotedLance: return "成香"
        case .promotedKnight: return "成桂"
        case .promotedSilver: return "成銀"
        case .horse: return "馬"
        case .dragon: return "龍"
        }
    }

    public var base: BoardPieceKind {
        switch self {
        case .promotedPawn: return .pawn
        case .promotedLance: return .lance
        case .promotedKnight: return .knight
        case .promotedSilver: return .silver
        case .horse: return .bishop
        case .dragon: return .rook
        default: return self
        }
    }

    public var promoted: BoardPieceKind? {
        switch self {
        case .pawn: return .promotedPawn
        case .lance: return .promotedLance
        case .knight: return .promotedKnight
        case .silver: return .promotedSilver
        case .bishop: return .horse
        case .rook: return .dragon
        default: return nil
        }
    }

    public static func fromUSIDropLetter(_ character: Character) -> BoardPieceKind? {
        switch character {
        case "P": return .pawn
        case "L": return .lance
        case "N": return .knight
        case "S": return .silver
        case "G": return .gold
        case "B": return .bishop
        case "R": return .rook
        default: return nil
        }
    }
}

public struct BoardPieceState: Equatable, Sendable {
    public let side: ShogiSide
    public let kind: BoardPieceKind

    public init(side: ShogiSide, kind: BoardPieceKind) {
        self.side = side
        self.kind = kind
    }
}

public struct BoardSnapshot: Equatable, Sendable {
    public let squares: [BoardCoordinate: BoardPieceState]
    public let hands: [ShogiSide: [BoardPieceKind: Int]]
    public let sideToMove: ShogiSide

    public init(
        squares: [BoardCoordinate: BoardPieceState],
        hands: [ShogiSide: [BoardPieceKind: Int]],
        sideToMove: ShogiSide
    ) {
        self.squares = squares
        self.hands = hands
        self.sideToMove = sideToMove
    }

    public func piece(at coordinate: BoardCoordinate) -> BoardPieceState? {
        squares[coordinate]
    }

    public func handCount(side: ShogiSide, kind: BoardPieceKind) -> Int {
        hands[side]?[kind.base, default: 0] ?? 0
    }

    public var pieceCount: Int { squares.count }

    public func totalHandCount(side: ShogiSide) -> Int {
        (hands[side] ?? [:]).values.reduce(0, +)
    }
}

public struct USIMoveVisual: Equatable, Sendable {
    public let source: BoardCoordinate?
    public let destination: BoardCoordinate
    public let dropPiece: BoardPieceKind?
    public let promotes: Bool

    public init(
        source: BoardCoordinate?,
        destination: BoardCoordinate,
        dropPiece: BoardPieceKind?,
        promotes: Bool
    ) {
        self.source = source
        self.destination = destination
        self.dropPiece = dropPiece
        self.promotes = promotes
    }

    public var isDrop: Bool { source == nil && dropPiece != nil }

    public static func parse(_ usi: String) throws -> USIMoveVisual {
        let chars = Array(usi)
        if chars.count == 4, chars[1] == "*" {
            guard let kind = BoardPieceKind.fromUSIDropLetter(chars[0]),
                  let destination = BoardSnapshotResolver.coordinate(
                    file: chars[2],
                    rank: chars[3]
                  ) else {
                throw BoardSnapshotError.invalidMove(usi)
            }
            return USIMoveVisual(
                source: nil,
                destination: destination,
                dropPiece: kind,
                promotes: false
            )
        }

        guard chars.count == 4 || chars.count == 5,
              let source = BoardSnapshotResolver.coordinate(file: chars[0], rank: chars[1]),
              let destination = BoardSnapshotResolver.coordinate(file: chars[2], rank: chars[3]),
              chars.count == 4 || chars[4] == "+" else {
            throw BoardSnapshotError.invalidMove(usi)
        }

        return USIMoveVisual(
            source: source,
            destination: destination,
            dropPiece: nil,
            promotes: chars.count == 5
        )
    }
}

public enum BoardSnapshotError: Error, LocalizedError, Equatable, Sendable {
    case unsupportedPosition(String)
    case invalidMove(String)
    case sourcePieceMissing(String)
    case wrongSide(String)
    case occupiedDrop(String)
    case missingHandPiece(String)
    case invalidPromotion(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedPosition(let value):
            return "未対応の局面指定です: \(value)"
        case .invalidMove(let value):
            return "USI指し手が不正です: \(value)"
        case .sourcePieceMissing(let value):
            return "移動元に駒がありません: \(value)"
        case .wrongSide(let value):
            return "手番と駒の向きが一致しません: \(value)"
        case .occupiedDrop(let value):
            return "駒打ち先が空いていません: \(value)"
        case .missingHandPiece(let value):
            return "持駒が不足しています: \(value)"
        case .invalidPromotion(let value):
            return "成れない駒の成り指定です: \(value)"
        }
    }
}

public enum BoardSnapshotResolver {
    public static var startpos: BoardSnapshot {
        MutableBoard.startpos.snapshot
    }

    public static func resolve(positionCommand: String) throws -> BoardSnapshot {
        let tokens = positionCommand.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 2, tokens[0] == "position", tokens[1] == "startpos" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }

        var state = MutableBoard.startpos
        if tokens.count == 2 {
            return state.snapshot
        }

        guard tokens.count >= 4, tokens[2] == "moves" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }

        for move in tokens.dropFirst(3) {
            try state.applyUSI(move)
        }
        return state.snapshot
    }

    static func coordinate(file: Character, rank: Character) -> BoardCoordinate? {
        guard let fileValue = file.wholeNumberValue, (1...9).contains(fileValue) else {
            return nil
        }
        let ranks = Array("abcdefghi")
        guard let index = ranks.firstIndex(of: rank) else { return nil }
        return BoardCoordinate(file: fileValue, rank: index + 1)
    }

    private struct MutableBoard {
        var squares: [BoardCoordinate: BoardPieceState]
        var hands: [ShogiSide: [BoardPieceKind: Int]]
        var sideToMove: ShogiSide

        static var startpos: MutableBoard {
            var board = MutableBoard(
                squares: [:],
                hands: [.black: [:], .white: [:]],
                sideToMove: .black
            )
            let back: [BoardPieceKind] = [
                .lance, .knight, .silver, .gold, .king, .gold, .silver, .knight, .lance
            ]

            for file in 1...9 {
                board.squares[BoardCoordinate(file: file, rank: 9)] =
                    BoardPieceState(side: .black, kind: back[file - 1])
                board.squares[BoardCoordinate(file: file, rank: 7)] =
                    BoardPieceState(side: .black, kind: .pawn)
                board.squares[BoardCoordinate(file: file, rank: 1)] =
                    BoardPieceState(side: .white, kind: back[file - 1])
                board.squares[BoardCoordinate(file: file, rank: 3)] =
                    BoardPieceState(side: .white, kind: .pawn)
            }

            board.squares[BoardCoordinate(file: 8, rank: 8)] =
                BoardPieceState(side: .black, kind: .bishop)
            board.squares[BoardCoordinate(file: 2, rank: 8)] =
                BoardPieceState(side: .black, kind: .rook)
            board.squares[BoardCoordinate(file: 2, rank: 2)] =
                BoardPieceState(side: .white, kind: .bishop)
            board.squares[BoardCoordinate(file: 8, rank: 2)] =
                BoardPieceState(side: .white, kind: .rook)
            return board
        }

        var snapshot: BoardSnapshot {
            BoardSnapshot(squares: squares, hands: hands, sideToMove: sideToMove)
        }

        mutating func applyUSI(_ usi: String) throws {
            let visual = try USIMoveVisual.parse(usi)

            if visual.isDrop {
                guard let kind = visual.dropPiece else {
                    throw BoardSnapshotError.invalidMove(usi)
                }
                guard squares[visual.destination] == nil else {
                    throw BoardSnapshotError.occupiedDrop(usi)
                }
                let count = hands[sideToMove]?[kind, default: 0] ?? 0
                guard count > 0 else {
                    throw BoardSnapshotError.missingHandPiece(usi)
                }
                hands[sideToMove, default: [:]][kind] = count - 1
                squares[visual.destination] = BoardPieceState(side: sideToMove, kind: kind)
                sideToMove = opponent(of: sideToMove)
                return
            }

            guard let sourceCoordinate = visual.source,
                  let source = squares[sourceCoordinate] else {
                throw BoardSnapshotError.sourcePieceMissing(usi)
            }
            guard source.side == sideToMove else {
                throw BoardSnapshotError.wrongSide(usi)
            }

            if let captured = squares[visual.destination] {
                guard captured.side != sideToMove else {
                    throw BoardSnapshotError.invalidMove(usi)
                }
                let base = captured.kind.base
                if base != .king {
                    hands[sideToMove, default: [:]][base, default: 0] += 1
                }
            }

            let resultKind: BoardPieceKind
            if visual.promotes {
                guard let promoted = source.kind.promoted else {
                    throw BoardSnapshotError.invalidPromotion(usi)
                }
                resultKind = promoted
            } else {
                resultKind = source.kind
            }

            squares.removeValue(forKey: sourceCoordinate)
            squares[visual.destination] = BoardPieceState(side: sideToMove, kind: resultKind)
            sideToMove = opponent(of: sideToMove)
        }

        private func opponent(of side: ShogiSide) -> ShogiSide {
            side == .black ? .white : .black
        }
    }
}
