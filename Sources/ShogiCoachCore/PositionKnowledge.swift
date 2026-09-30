import Foundation

public enum NormalizedPositionKey {
    public static func make(from snapshot: BoardSnapshot) -> String {
        let board = (1...9).map { rank in
            var row = ""
            var empty = 0
            for file in stride(from: 9, through: 1, by: -1) {
                let square = BoardCoordinate(file: file, rank: rank)
                guard let piece = snapshot.piece(at: square) else {
                    empty += 1
                    continue
                }
                if empty > 0 {
                    row += String(empty)
                    empty = 0
                }
                row += sfenToken(piece)
            }
            if empty > 0 { row += String(empty) }
            return row
        }.joined(separator: "/")

        let side = snapshot.sideToMove == .black ? "b" : "w"
        let hands = handText(snapshot)
        return "\(board) \(side) \(hands)"
    }

    public static func make(positionCommand: String) throws -> String {
        make(from: try BoardSnapshotResolver.resolve(positionCommand: positionCommand))
    }

    private static func sfenToken(_ piece: BoardPieceState) -> String {
        let base: String
        let promoted: Bool
        switch piece.kind {
        case .pawn: base = "P"; promoted = false
        case .lance: base = "L"; promoted = false
        case .knight: base = "N"; promoted = false
        case .silver: base = "S"; promoted = false
        case .gold: base = "G"; promoted = false
        case .bishop: base = "B"; promoted = false
        case .rook: base = "R"; promoted = false
        case .king: base = "K"; promoted = false
        case .promotedPawn: base = "P"; promoted = true
        case .promotedLance: base = "L"; promoted = true
        case .promotedKnight: base = "N"; promoted = true
        case .promotedSilver: base = "S"; promoted = true
        case .horse: base = "B"; promoted = true
        case .dragon: base = "R"; promoted = true
        }

        let sided = piece.side == .black ? base : base.lowercased()
        return promoted ? "+" + sided : sided
    }

    private static func handText(_ snapshot: BoardSnapshot) -> String {
        let order: [(BoardPieceKind, String)] = [
            (.rook, "R"), (.bishop, "B"), (.gold, "G"), (.silver, "S"),
            (.knight, "N"), (.lance, "L"), (.pawn, "P")
        ]
        var result = ""
        for side in [ShogiSide.black, .white] {
            for (kind, token) in order {
                let count = snapshot.handCount(side: side, kind: kind)
                guard count > 0 else { continue }
                if count > 1 { result += String(count) }
                result += side == .black ? token : token.lowercased()
            }
        }
        return result.isEmpty ? "-" : result
    }
}

public struct ContextKnowledgeSourceManifest: Codable, Equatable, Sendable {
    public let sourceID: String
    public let title: String
    public let sourceURL: String
    public let rightsNote: String
    public let retrievedDate: String

    public init(sourceID: String, title: String, sourceURL: String, rightsNote: String, retrievedDate: String) {
        self.sourceID = sourceID
        self.title = title
        self.sourceURL = sourceURL
        self.rightsNote = rightsNote
        self.retrievedDate = retrievedDate
    }
}

public struct ContextKnowledgeBuildStatistics: Codable, Equatable, Sendable {
    public let parsedGames: Int
    public let skippedGames: Int
    public let aggregatedMoves: Int
    public let emittedRecords: Int
    public let maxPly: Int
    public let minObservations: Int

    public init(parsedGames: Int, skippedGames: Int, aggregatedMoves: Int, emittedRecords: Int, maxPly: Int, minObservations: Int) {
        self.parsedGames = parsedGames
        self.skippedGames = skippedGames
        self.aggregatedMoves = aggregatedMoves
        self.emittedRecords = emittedRecords
        self.maxPly = maxPly
        self.minObservations = minObservations
    }
}

public struct CompactPositionKnowledgeRecord: Codable, Equatable, Sendable {
    public let positionKey: String
    public let move: String
    public let sourceKind: ContextEvidenceKind
    public let sourceID: String
    public let observationCount: Int
    public let intent: MoveIntent
    public let detail: String

    public init(
        positionKey: String,
        move: String,
        sourceKind: ContextEvidenceKind,
        sourceID: String,
        observationCount: Int,
        intent: MoveIntent,
        detail: String
    ) {
        self.positionKey = positionKey
        self.move = move
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.observationCount = max(1, observationCount)
        self.intent = intent
        self.detail = detail
    }
}

public struct ContextKnowledgeDocument: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let sources: [ContextKnowledgeSourceManifest]
    public let records: [CompactPositionKnowledgeRecord]
    public let statistics: ContextKnowledgeBuildStatistics

    public init(schemaVersion: Int = 1, sources: [ContextKnowledgeSourceManifest], records: [CompactPositionKnowledgeRecord], statistics: ContextKnowledgeBuildStatistics) {
        self.schemaVersion = schemaVersion
        self.sources = sources
        self.records = records
        self.statistics = statistics
    }
}

public enum ContextKnowledgeDecodeError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
}

public struct CompactMoveContextKnowledgeProvider: MoveContextKnowledgeProvider {
    private let records: [String: [CompactPositionKnowledgeRecord]]

    public init(document: ContextKnowledgeDocument) {
        self.init(records: document.records)
    }

    public init(data: Data) throws {
        let document = try JSONDecoder().decode(ContextKnowledgeDocument.self, from: data)
        guard document.schemaVersion == 1 else {
            throw ContextKnowledgeDecodeError.unsupportedSchema(document.schemaVersion)
        }
        self.init(document: document)
    }

    public init(records: [CompactPositionKnowledgeRecord]) {
        var grouped: [String: [CompactPositionKnowledgeRecord]] = [:]
        for record in records
        where record.sourceKind == .openingBook || record.sourceKind == .precedent {
            grouped[record.positionKey, default: []].append(record)
        }
        self.records = grouped
    }

    public func evidence(positionCommand: String, move: String) -> [MoveContextKnowledgeEvidence] {
        guard let key = try? NormalizedPositionKey.make(positionCommand: positionCommand) else {
            return []
        }
        return (records[key] ?? [])
            .filter { $0.move == move }
            .map {
                MoveContextKnowledgeEvidence(
                    kind: $0.sourceKind,
                    sourceID: $0.sourceID,
                    intent: $0.intent,
                    weight: Self.weight(kind: $0.sourceKind, observations: $0.observationCount),
                    detail: "\($0.detail);observations=\($0.observationCount)"
                )
            }
    }

    private static func weight(kind: ContextEvidenceKind, observations: Int) -> Int {
        let base = kind == .openingBook ? 45 : 40
        let bonus: Int
        switch observations {
        case 1000...: bonus = 30
        case 100...: bonus = 25
        case 20...: bonus = 18
        case 5...: bonus = 10
        default: bonus = 0
        }
        return min(80, base + bonus)
    }
}
