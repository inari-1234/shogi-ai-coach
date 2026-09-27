import Foundation

public enum USIParser {
    public static func parseInfo(_ line: String) -> USIInfo? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.first == "info" else { return nil }

        var result = USIInfo()
        var i = 1

        while i < tokens.count {
            switch tokens[i] {
            case "depth":
                if i + 1 < tokens.count { result.depth = Int(tokens[i + 1]); i += 2 } else { i += 1 }
            case "seldepth":
                if i + 1 < tokens.count { result.selDepth = Int(tokens[i + 1]); i += 2 } else { i += 1 }
            case "multipv":
                if i + 1 < tokens.count { result.multipv = Int(tokens[i + 1]) ?? 1; i += 2 } else { i += 1 }
            case "nodes":
                if i + 1 < tokens.count { result.nodes = UInt64(tokens[i + 1]); i += 2 } else { i += 1 }
            case "nps":
                if i + 1 < tokens.count { result.nps = UInt64(tokens[i + 1]); i += 2 } else { i += 1 }
            case "time":
                if i + 1 < tokens.count { result.timeMs = UInt64(tokens[i + 1]); i += 2 } else { i += 1 }
            case "score":
                guard i + 2 < tokens.count else { i += 1; continue }
                let kind = tokens[i + 1]
                guard let raw = Int(tokens[i + 2]) else { i += 3; continue }
                var bound: USIScore.Bound?
                var advance = 3
                if i + 3 < tokens.count {
                    if tokens[i + 3] == "lowerbound" { bound = .lower; advance = 4 }
                    if tokens[i + 3] == "upperbound" { bound = .upper; advance = 4 }
                }
                if kind == "cp" { result.score = .centipawn(raw, bound: bound) }
                if kind == "mate" { result.score = .mate(raw, bound: bound) }
                i += advance
            case "pv":
                result.pv = Array(tokens.dropFirst(i + 1))
                i = tokens.count
            case "string":
                i = tokens.count
            default:
                i += 1
            }
        }

        return result
    }

    public static func parseBestMove(_ line: String) -> USIBestMove? {
        let tokens = line.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 2, tokens[0] == "bestmove" else { return nil }
        let ponder: String?
        if let p = tokens.firstIndex(of: "ponder"), p + 1 < tokens.count {
            ponder = tokens[p + 1]
        } else {
            ponder = nil
        }
        return USIBestMove(move: tokens[1], ponder: ponder)
    }
}
