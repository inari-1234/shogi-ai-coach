import Foundation

private func scoreObject(_ score: USIScore?) -> Any {
    guard let score else { return NSNull() }
    switch score {
    case .centipawn(let value, let bound):
        return ["type": "cp", "value": value, "bound": bound?.rawValue ?? NSNull()] as [String: Any]
    case .mate(let value, let bound):
        return ["type": "mate", "value": value, "bound": bound?.rawValue ?? NSNull()] as [String: Any]
    }
}

private func infoObject(_ info: USIInfo) -> [String: Any] {
    return [
        "multipv": info.multipv,
        "score": scoreObject(info.score),
        "depth": info.depth ?? NSNull(),
        "seldepth": info.selDepth ?? NSNull(),
        "nodes": info.nodes ?? NSNull(),
        "nps": info.nps ?? NSNull(),
        "time": info.timeMs ?? NSNull(),
        "pv": info.pv
    ]
}

@main
struct SwiftParityProbe {
    static func main() throws {
        guard CommandLine.arguments.count == 2 else {
            fputs("usage: swift-parity-probe RAW_LOG\n", stderr)
            exit(2)
        }
        let raw = try String(contentsOfFile: CommandLine.arguments[1], encoding: .utf8)
        var accumulator = USIAccumulator()
        var final: EngineProbeResult?
        for rawLine in raw.split(whereSeparator: { $0.isNewline }) {
            let line = String(rawLine).trimmingCharacters(in: .newlines)
            if let result = accumulator.consume(line) {
                final = result
                break
            }
        }
        guard let result = final else {
            let data = try JSONSerialization.data(withJSONObject: ["bestmove": NSNull(), "ponder": NSNull(), "principalVariations": []], options: [.sortedKeys])
            print(String(decoding: data, as: UTF8.self))
            return
        }
        let object: [String: Any] = [
            "bestmove": result.bestMove.move,
            "ponder": result.bestMove.ponder ?? NSNull(),
            "principalVariations": result.principalVariations.map(infoObject)
        ]
        let data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }
}
