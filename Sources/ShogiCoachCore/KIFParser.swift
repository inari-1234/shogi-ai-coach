import Foundation

public enum ShogiSide: String, Equatable, Sendable {
    case black
    case white
    var opponent: ShogiSide { self == .black ? .white : .black }
}

public struct KIFMove: Equatable, Sendable {
    public let ply: Int
    public let notation: String
    public let usi: String
    public let positionBefore: String

    public init(ply: Int, notation: String, usi: String, positionBefore: String) {
        self.ply = ply
        self.notation = notation
        self.usi = usi
        self.positionBefore = positionBefore
    }
}

public struct KIFGame: Equatable, Sendable {
    public let metadata: [String: String]
    public let moves: [KIFMove]
    public let termination: String?

    public init(metadata: [String: String], moves: [KIFMove], termination: String?) {
        self.metadata = metadata
        self.moves = moves
        self.termination = termination
    }

    public var finalPositionCommand: String {
        guard !moves.isEmpty else { return "position startpos" }
        return "position startpos moves " + moves.map(\.usi).joined(separator: " ")
    }
}

public enum KIFParseError: Error, LocalizedError, Equatable, Sendable {
    case empty
    case unsupportedInitialPosition(String)
    case malformedMove(line: Int, text: String)
    case unexpectedPly(line: Int, expected: Int, actual: Int)
    case missingPreviousDestination(line: Int)
    case invalidSquare(line: Int, text: String)
    case missingOrigin(line: Int, text: String)
    case sourcePieceMissing(line: Int, square: String)
    case sourcePieceMismatch(line: Int, expected: String, actual: String)
    case wrongSide(line: Int)
    case occupiedByOwnPiece(line: Int, square: String)
    case illegalPseudoMove(line: Int, move: String)
    case illegalPromotion(line: Int, move: String)
    case missingHandPiece(line: Int, piece: String)
    case illegalDrop(line: Int, move: String)
    case unsupportedEncoding

    public var errorDescription: String? {
        switch self {
        case .empty:
            return "KIFに指し手がありません"
        case .unsupportedInitialPosition(let value):
            return "未対応の開始局面です: \(value)"
        case .malformedMove(let line, let text):
            return "KIF \(line)行目の指し手を解釈できません: \(text)"
        case .unexpectedPly(let line, let expected, let actual):
            return "KIF \(line)行目の手数が不連続です（期待 \(expected)、実際 \(actual)）"
        case .missingPreviousDestination(let line):
            return "KIF \(line)行目の「同」の参照先がありません"
        case .invalidSquare(let line, let text):
            return "KIF \(line)行目のマス表記が不正です: \(text)"
        case .missingOrigin(let line, let text):
            return "KIF \(line)行目に移動元がありません: \(text)"
        case .sourcePieceMissing(let line, let square):
            return "KIF \(line)行目の移動元 \(square) に駒がありません"
        case .sourcePieceMismatch(let line, let expected, let actual):
            return "KIF \(line)行目の駒種が局面と一致しません（棋譜 \(expected)、局面 \(actual)）"
        case .wrongSide(let line):
            return "KIF \(line)行目の手番が局面と一致しません"
        case .occupiedByOwnPiece(let line, let square):
            return "KIF \(line)行目の移動先 \(square) に自駒があります"
        case .illegalPseudoMove(let line, let move):
            return "KIF \(line)行目の駒の動きが不正です: \(move)"
        case .illegalPromotion(let line, let move):
            return "KIF \(line)行目の成りが不正です: \(move)"
        case .missingHandPiece(let line, let piece):
            return "KIF \(line)行目で持っていない \(piece) を打とうとしています"
        case .illegalDrop(let line, let move):
            return "KIF \(line)行目の駒打ちが不正です: \(move)"
        case .unsupportedEncoding:
            return "KIFの文字コードを判定できません"
        }
    }
}

public enum KIFTextDecoder {
    public static func decode(_ data: Data) throws -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]),
           let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) { return text }
        for encoding in [String.Encoding.shiftJIS, .japaneseEUC, .iso2022JP] {
            if let text = String(data: data, encoding: encoding) { return text }
        }
        throw KIFParseError.unsupportedEncoding
    }
}

public enum KIFParser {
    fileprivate struct ParsedMove {
        let destination: BoardCoordinate
        let origin: BoardCoordinate?
        let piece: BoardPieceKind
        let promotes: Bool
        let drop: Bool
        let notation: String
    }

    public static func parse(data: Data) throws -> KIFGame {
        try parse(KIFTextDecoder.decode(data))
    }

    public static func parse(_ text: String) throws -> KIFGame {
        var metadata: [String: String] = [:]
        var board = Board.startpos
        var side: ShogiSide = .black
        var previousDestination: BoardCoordinate?
        var usiMoves: [String] = []
        var moves: [KIFMove] = []
        var termination: String?
        var sawMoveSection = false

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)

        for (zeroBased, rawLine) in lines.enumerated() {
            let lineNumber = zeroBased + 1
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }

            if line.hasPrefix("#") || line.hasPrefix("*") || line.hasPrefix("&") { continue }
            if line.hasPrefix("手数----") || line.hasPrefix("手数－－－－") {
                sawMoveSection = true
                continue
            }
            if line.hasPrefix("まで") { continue }
            if line.hasPrefix("変化：") || line.hasPrefix("変化:") { break }

            if let header = parseHeader(line), !sawMoveSection, !startsWithPly(line) {
                metadata[header.key] = header.value
                if header.key == "手合割", header.value != "平手" {
                    throw KIFParseError.unsupportedInitialPosition(header.value)
                }
                continue
            }

            guard let numbered = splitNumberedLine(line) else {
                if !sawMoveSection,
                   line.contains("|") || line.hasPrefix("先手の持駒") || line.hasPrefix("後手の持駒") {
                    throw KIFParseError.unsupportedInitialPosition("盤面指定")
                }
                continue
            }
            sawMoveSection = true

            let expectedPly = moves.count + 1
            guard numbered.ply == expectedPly else {
                throw KIFParseError.unexpectedPly(
                    line: lineNumber,
                    expected: expectedPly,
                    actual: numbered.ply
                )
            }

            let body = stripTimeSuffix(numbered.body)
            if isTermination(body) {
                termination = body
                break
            }

            let parsed = try parseMoveBody(
                body,
                previousDestination: previousDestination,
                line: lineNumber
            )
            let positionBefore = usiMoves.isEmpty
                ? "position startpos"
                : "position startpos moves " + usiMoves.joined(separator: " ")

            let usi = try board.apply(parsed, side: side, line: lineNumber)
            moves.append(
                KIFMove(
                    ply: numbered.ply,
                    notation: body,
                    usi: usi,
                    positionBefore: positionBefore
                )
            )
            usiMoves.append(usi)
            previousDestination = parsed.destination
            side = side.opponent
        }

        guard !moves.isEmpty else { throw KIFParseError.empty }
        return KIFGame(metadata: metadata, moves: moves, termination: termination)
    }

    private static func startsWithPly(_ line: String) -> Bool {
        line.first?.isNumber == true
    }

    private static func parseHeader(_ line: String) -> (key: String, value: String)? {
        let separator = line.firstIndex(of: "：") ?? line.firstIndex(of: ":")
        guard let separator else { return nil }
        let key = line[..<separator].trimmingCharacters(in: .whitespaces)
        let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }
        return (String(key), String(value))
    }

    private static func splitNumberedLine(_ line: String) -> (ply: Int, body: String)? {
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber {
            index = line.index(after: index)
        }
        guard index > line.startIndex, let ply = Int(line[..<index]) else { return nil }
        guard index < line.endIndex, line[index].isWhitespace else { return nil }
        while index < line.endIndex, line[index].isWhitespace {
            index = line.index(after: index)
        }
        guard index < line.endIndex else { return nil }
        return (ply, String(line[index...]).trimmingCharacters(in: .whitespaces))
    }

    private static func stripTimeSuffix(_ body: String) -> String {
        let pattern = #"\s+\(\s*\d+:\d+(?:/\s*\d+:\d+:\d+)?\s*\)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return body }
        let range = NSRange(body.startIndex..<body.endIndex, in: body)
        guard let match = regex.firstMatch(in: body, range: range),
              let swiftRange = Range(match.range, in: body) else {
            return body
        }
        return String(body[..<swiftRange.lowerBound]).trimmingCharacters(in: .whitespaces)
    }

    private static let terminations: Set<String> = [
        "投了", "中断", "千日手", "持将棋", "詰み", "不詰", "切れ負け", "時間切れ",
        "反則勝ち", "反則負け", "入玉勝ち", "勝宣言", "不戦勝", "不戦敗", "引き分け"
    ]

    private static func isTermination(_ text: String) -> Bool {
        terminations.contains(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func parseMoveBody(
        _ body: String,
        previousDestination: BoardCoordinate?,
        line: Int
    ) throws -> ParsedMove {
        var rest = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination: BoardCoordinate

        if rest.hasPrefix("同") {
            guard let previousDestination else {
                throw KIFParseError.missingPreviousDestination(line: line)
            }
            destination = previousDestination
            rest.removeFirst()
            rest = rest.trimmingCharacters(in: .whitespaces)
        } else {
            guard rest.count >= 2 else {
                throw KIFParseError.malformedMove(line: line, text: body)
            }
            let first = rest.removeFirst()
            let second = rest.removeFirst()
            guard let file = fileNumber(first), let rank = rankNumber(second) else {
                throw KIFParseError.invalidSquare(line: line, text: "\(first)\(second)")
            }
            destination = BoardCoordinate(file: file, rank: rank)
            rest = rest.trimmingCharacters(in: .whitespaces)
        }

        let names = [
            "成香", "成桂", "成銀", "龍", "竜", "馬", "と",
            "歩", "香", "桂", "銀", "金", "角", "飛", "玉", "王"
        ]
        guard let name = names.first(where: { rest.hasPrefix($0) }),
              let piece = BoardPieceKind(kifName: name) else {
            throw KIFParseError.malformedMove(line: line, text: body)
        }
        rest.removeFirst(name.count)

        var origin: BoardCoordinate?
        let originPattern = #"\(([0-9])([0-9])\)\s*$"#
        if let regex = try? NSRegularExpression(pattern: originPattern),
           let match = regex.firstMatch(
            in: rest,
            range: NSRange(rest.startIndex..<rest.endIndex, in: rest)
           ),
           match.numberOfRanges == 3,
           let whole = Range(match.range(at: 0), in: rest),
           let fileRange = Range(match.range(at: 1), in: rest),
           let rankRange = Range(match.range(at: 2), in: rest),
           let file = Int(rest[fileRange]),
           let rank = Int(rest[rankRange]),
           ((file == 0 && rank == 0) || ((1...9).contains(file) && (1...9).contains(rank))) {
            origin = BoardCoordinate(file: file, rank: rank)
            rest.removeSubrange(whole)
        }

        let suffix = rest
            .replacingOccurrences(of: "　", with: "")
            .replacingOccurrences(of: " ", with: "")
        let drop = suffix.contains("打")

        if origin == BoardCoordinate(file: 0, rank: 0) { origin = nil }
        if origin == nil && !drop {
            throw KIFParseError.missingOrigin(line: line, text: body)
        }
        if drop, origin != nil {
            throw KIFParseError.illegalDrop(line: line, move: body)
        }

        let promotes = !piece.isPromoted
            && suffix.contains("成")
            && !suffix.contains("不成")

        return ParsedMove(
            destination: destination,
            origin: origin,
            piece: piece,
            promotes: promotes,
            drop: drop,
            notation: body
        )
    }

    private static func fileNumber(_ character: Character) -> Int? {
        let map: [Character: Int] = [
            "１":1, "２":2, "３":3, "４":4, "５":5, "６":6, "７":7, "８":8, "９":9,
            "1":1, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9
        ]
        return map[character]
    }

    private static func rankNumber(_ character: Character) -> Int? {
        let map: [Character: Int] = [
            "一":1, "二":2, "三":3, "四":4, "五":5, "六":6, "七":7, "八":8, "九":9,
            "１":1, "２":2, "３":3, "４":4, "５":5, "６":6, "７":7, "８":8, "９":9,
            "1":1, "2":2, "3":3, "4":4, "5":5, "6":6, "7":7, "8":8, "9":9
        ]
        return map[character]
    }
}

fileprivate struct Board: Sendable {
    var squares: [BoardCoordinate: BoardPieceState]
    var hands: [ShogiSide: [BoardPieceKind: Int]]

    static var startpos: Board {
        let snapshot = BoardSnapshotResolver.startpos
        return Board(squares: snapshot.squares, hands: snapshot.hands)
    }

    mutating func apply(
        _ move: KIFParser.ParsedMove,
        side: ShogiSide,
        line: Int
    ) throws -> String {
        if move.drop {
            return try applyDrop(move, side: side, line: line)
        }

        guard let origin = move.origin else {
            throw KIFParseError.missingOrigin(line: line, text: move.notation)
        }
        guard let source = squares[origin] else {
            throw KIFParseError.sourcePieceMissing(line: line, square: origin.usi)
        }
        guard source.side == side else {
            throw KIFParseError.wrongSide(line: line)
        }
        guard source.kind == move.piece else {
            throw KIFParseError.sourcePieceMismatch(
                line: line,
                expected: move.piece.kifName,
                actual: source.kind.kifName
            )
        }
        if let target = squares[move.destination], target.side == side {
            throw KIFParseError.occupiedByOwnPiece(line: line, square: move.destination.usi)
        }
        guard pseudoLegal(source.kind, from: origin, to: move.destination, side: side) else {
            throw KIFParseError.illegalPseudoMove(line: line, move: move.notation)
        }

        if move.promotes {
            guard source.kind.isPromotable,
                  inPromotionZone(origin, side: side) || inPromotionZone(move.destination, side: side),
                  source.kind.promoted != nil else {
                throw KIFParseError.illegalPromotion(line: line, move: move.notation)
            }
        } else if mustPromote(source.kind, at: move.destination, side: side) {
            throw KIFParseError.illegalPromotion(line: line, move: move.notation)
        }

        if let captured = squares[move.destination] {
            let base = captured.kind.base
            hands[side, default: [:]][base, default: 0] += 1
        }

        squares.removeValue(forKey: origin)
        let newKind = move.promotes ? (source.kind.promoted ?? source.kind) : source.kind
        squares[move.destination] = BoardPieceState(side: side, kind: newKind)
        return origin.usi + move.destination.usi + (move.promotes ? "+" : "")
    }

    private mutating func applyDrop(
        _ move: KIFParser.ParsedMove,
        side: ShogiSide,
        line: Int
    ) throws -> String {
        let piece = move.piece.base
        guard !piece.isPromoted, piece != .king else {
            throw KIFParseError.illegalDrop(line: line, move: move.notation)
        }
        guard squares[move.destination] == nil else {
            throw KIFParseError.illegalDrop(line: line, move: move.notation)
        }
        guard hands[side]?[piece, default: 0] ?? 0 > 0 else {
            throw KIFParseError.missingHandPiece(line: line, piece: piece.kifName)
        }
        if mustPromote(piece, at: move.destination, side: side) {
            throw KIFParseError.illegalDrop(line: line, move: move.notation)
        }

        if piece == .pawn {
            for (square, occupant) in squares {
                if square.file == move.destination.file,
                   occupant.side == side,
                   occupant.kind == .pawn {
                    throw KIFParseError.illegalDrop(line: line, move: move.notation)
                }
            }
        }

        hands[side]?[piece, default: 0] -= 1
        squares[move.destination] = BoardPieceState(side: side, kind: piece)
        return piece.rawValue + "*" + move.destination.usi
    }

    private func inPromotionZone(_ square: BoardCoordinate, side: ShogiSide) -> Bool {
        side == .black ? square.rank <= 3 : square.rank >= 7
    }

    private func mustPromote(_ kind: BoardPieceKind, at destination: BoardCoordinate, side: ShogiSide) -> Bool {
        switch kind {
        case .pawn, .lance:
            return side == .black ? destination.rank == 1 : destination.rank == 9
        case .knight:
            return side == .black ? destination.rank <= 2 : destination.rank >= 8
        default:
            return false
        }
    }

    private func pseudoLegal(
        _ kind: BoardPieceKind,
        from: BoardCoordinate,
        to: BoardCoordinate,
        side: ShogiSide
    ) -> Bool {
        let dx = to.file - from.file
        let dy = to.rank - from.rank
        guard dx != 0 || dy != 0 else { return false }

        let forward = side == .black ? -dy : dy
        let ax = abs(dx)

        switch kind {
        case .pawn:
            return dx == 0 && forward == 1
        case .lance:
            return dx == 0 && forward > 0 && clearPath(from: from, to: to)
        case .knight:
            return ax == 1 && forward == 2
        case .silver:
            return (forward == 1 && ax <= 1) || (forward == -1 && ax == 1)
        case .gold, .promotedPawn, .promotedLance, .promotedKnight, .promotedSilver:
            return (forward == 1 && ax <= 1)
                || (forward == 0 && ax == 1)
                || (forward == -1 && dx == 0)
        case .king:
            return ax <= 1 && abs(dy) <= 1
        case .bishop:
            return ax == abs(dy) && clearPath(from: from, to: to)
        case .rook:
            return (dx == 0 || dy == 0) && clearPath(from: from, to: to)
        case .horse:
            if ax == abs(dy) { return clearPath(from: from, to: to) }
            return (ax == 1 && dy == 0) || (dx == 0 && abs(dy) == 1)
        case .dragon:
            if dx == 0 || dy == 0 { return clearPath(from: from, to: to) }
            return ax == 1 && abs(dy) == 1
        }
    }

    private func clearPath(from: BoardCoordinate, to: BoardCoordinate) -> Bool {
        let stepFile = (to.file - from.file).signum()
        let stepRank = (to.rank - from.rank).signum()
        var current = BoardCoordinate(file: from.file + stepFile, rank: from.rank + stepRank)

        while current != to {
            if squares[current] != nil { return false }
            current = BoardCoordinate(
                file: current.file + stepFile,
                rank: current.rank + stepRank
            )
        }
        return true
    }
}
