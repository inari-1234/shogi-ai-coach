import Foundation
import ShogiCoachCore

private enum BuilderError: Error, LocalizedError {
    case missingArgument(String)
    case invalidInteger(String, String)
    case noKIF(String)
    case noParsedGames
    case noRecords

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name): return "missing required argument: \(name)"
        case .invalidInteger(let name, let value): return "invalid integer for \(name): \(value)"
        case .noKIF(let path): return "no .kif files found under: \(path)"
        case .noParsedGames: return "no KIF game could be parsed"
        case .noRecords: return "no compact knowledge record met the threshold"
        }
    }
}

private struct Options {
    let inputDir: String
    let output: String
    let maxPly: Int
    let minObservations: Int
    let sourceID: String
    let sourceTitle: String
    let sourceURL: String
    let rightsNote: String
    let retrievedDate: String

    init(arguments: [String]) throws {
        func value(_ flag: String) throws -> String {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else { throw BuilderError.missingArgument(flag) }
            return arguments[i + 1]
        }
        func integer(_ flag: String, default defaultValue: Int) throws -> Int {
            guard let i = arguments.firstIndex(of: flag) else { return defaultValue }
            guard i + 1 < arguments.count else { throw BuilderError.missingArgument(flag) }
            let raw = arguments[i + 1]
            guard let parsed = Int(raw), parsed > 0 else { throw BuilderError.invalidInteger(flag, raw) }
            return parsed
        }
        inputDir = try value("--input-dir")
        output = try value("--output")
        maxPly = try integer("--max-ply", default: 80)
        minObservations = try integer("--min-observations", default: 2)
        sourceID = try value("--source-id")
        sourceTitle = try value("--source-title")
        sourceURL = try value("--source-url")
        rightsNote = try value("--rights-note")
        retrievedDate = try value("--retrieved-date")
    }
}

private struct AggregateKey: Hashable {
    let positionKey: String
    let move: String
}

private func stderr(_ message: String) {
    if let data = (message + "\n").data(using: .utf8) {
        try? FileHandle.standardError.write(contentsOf: data)
    }
}

private func run() throws {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let inputURL = URL(fileURLWithPath: options.inputDir, isDirectory: true)
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: inputURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
        throw BuilderError.noKIF(options.inputDir)
    }

    var kifURLs: [URL] = []
    for case let url as URL in enumerator where url.pathExtension.lowercased() == "kif" {
        kifURLs.append(url)
    }
    kifURLs.sort { $0.path < $1.path }
    guard !kifURLs.isEmpty else { throw BuilderError.noKIF(options.inputDir) }

    var counts: [AggregateKey: Int] = [:]
    var parsedGames = 0
    var skippedGames = 0
    var aggregatedMoves = 0

    for url in kifURLs {
        do {
            let game = try KIFParser.parse(data: Data(contentsOf: url))
            parsedGames += 1
            for move in game.moves where move.ply <= options.maxPly {
                let key = try NormalizedPositionKey.make(positionCommand: move.positionBefore)
                counts[AggregateKey(positionKey: key, move: move.usi), default: 0] += 1
                aggregatedMoves += 1
            }
        } catch {
            skippedGames += 1
            stderr("skip \(url.lastPathComponent): \(error.localizedDescription)")
        }
    }

    guard parsedGames > 0 else { throw BuilderError.noParsedGames }

    let records = counts
        .filter { $0.value >= options.minObservations }
        .map {
            CompactPositionKnowledgeRecord(
                positionKey: $0.key.positionKey,
                move: $0.key.move,
                sourceKind: .precedent,
                sourceID: options.sourceID,
                observationCount: $0.value,
                intent: .unresolved,
                detail: "official precedent aggregation"
            )
        }
        .sorted {
            if $0.positionKey == $1.positionKey { return $0.move < $1.move }
            return $0.positionKey < $1.positionKey
        }

    guard !records.isEmpty else { throw BuilderError.noRecords }

    let document = ContextKnowledgeDocument(
        sources: [.init(sourceID: options.sourceID, title: options.sourceTitle, sourceURL: options.sourceURL, rightsNote: options.rightsNote, retrievedDate: options.retrievedDate)],
        records: records,
        statistics: .init(parsedGames: parsedGames, skippedGames: skippedGames, aggregatedMoves: aggregatedMoves, emittedRecords: records.count, maxPly: options.maxPly, minObservations: options.minObservations)
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(document)
    let outputURL = URL(fileURLWithPath: options.output)
    try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try data.write(to: outputURL, options: .atomic)

    print("context_knowledge_status=PASS")
    print("context_knowledge_source=\(options.sourceID)")
    print("context_knowledge_parsed_games=\(parsedGames)")
    print("context_knowledge_skipped_games=\(skippedGames)")
    print("context_knowledge_aggregated_moves=\(aggregatedMoves)")
    print("context_knowledge_records=\(records.count)")
}

do {
    try run()
} catch {
    stderr("context_knowledge_status=FAIL")
    stderr(error.localizedDescription)
    fatalError(error.localizedDescription)
}
