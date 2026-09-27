import Foundation
import ShogiCoachCore

struct ShogiDiagnosticDocument: Codable {
    struct AppInfo: Codable {
        let version: String
        let build: String
        let gitCommit: String
    }

    struct DeviceInfo: Codable {
        let model: String
        let osVersion: String
        let thermalState: String
    }

    struct GameInfo: Codable {
        let fileName: String
        let moveCount: Int
        let sente: String
        let gote: String
        let termination: String
    }

    struct AnalysisInfo: Codable {
        let status: String
        let requestedMoveTimeMs: Int
        let completedPositions: Int
        let expectedPositions: Int
        let totalElapsedMs: Int
        let medianElapsedMs: Int?
        let bestMoveMatchCount: Int
        let centipawnScoreCount: Int
    }

    struct PositionInfo: Codable {
        let ply: Int
        let actualMove: String
        let bestMove: String
        let score: String
        let blackPerspectiveCp: Int?
        let depth: String
        let nodes: String
        let nps: String
        let pv: String
        let elapsedMs: Int
        let thermalBefore: String
        let thermalAfter: String
        let matchesBestMove: Bool
    }

    struct DeepCandidateInfo: Codable {
        let rank: Int
        let move: String
        let score: String
        let centipawn: Int?
        let depth: String
        let nodes: String
        let nps: String
        let pv: String
        let opponentReply: String
    }

    struct DeepPositionInfo: Codable {
        let ply: Int
        let actualMove: String
        let shallowBestMove: String
        let shallowEstimatedLossCp: Int?
        let bestMove: String
        let bestScore: String
        let actualScore: String
        let actualLossCp: Int?
        let actualPV: String
        let actualAnalysisSource: String
        let opponentBestReply: String
        let candidates: [DeepCandidateInfo]
        let elapsedMs: Int
        let thermalBefore: String
        let thermalAfter: String
    }

    struct DeepAnalysisInfo: Codable {
        let status: String
        let requestedMoveTimeMs: Int
        let multiPV: Int
        let selectedPositions: Int
        let completedPositions: Int
        let totalElapsedMs: Int
        let focus: String
        let positions: [DeepPositionInfo]
        let error: String?
    }

    var schemaVersion: Int
    var generatedAt: Date
    let app: AppInfo
    let device: DeviceInfo
    let game: GameInfo
    let analysis: AnalysisInfo
    let positions: [PositionInfo]
    var deepAnalysis: DeepAnalysisInfo?
    let error: String?
}

enum DiagnosticExporter {
    static func write(
        game: KIFGame,
        fileName: String?,
        entries: [ShallowAnalysisEntry],
        status: String,
        requestedMoveTimeMs: Int,
        totalElapsedMs: Int,
        error: String?
    ) throws -> URL {
        let elapsed = entries.map(\.elapsedMs).sorted()
        let median = elapsed.isEmpty ? nil : elapsed[elapsed.count / 2]
        let bundle = Bundle.main
        let process = ProcessInfo.processInfo

        let document = ShogiDiagnosticDocument(
            schemaVersion: 1,
            generatedAt: Date(),
            app: .init(
                version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "PoC",
                build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-",
                gitCommit: bundle.object(forInfoDictionaryKey: "GitCommit") as? String ?? "unknown"
            ),
            device: .init(
                model: process.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? hardwareModel(),
                osVersion: process.operatingSystemVersionString,
                thermalState: thermalText(process.thermalState)
            ),
            game: .init(
                fileName: fileName ?? "unknown.kif",
                moveCount: game.moves.count,
                sente: game.metadata["先手"] ?? "-",
                gote: game.metadata["後手"] ?? "-",
                termination: game.termination ?? "-"
            ),
            analysis: .init(
                status: status,
                requestedMoveTimeMs: requestedMoveTimeMs,
                completedPositions: entries.count,
                expectedPositions: game.moves.count,
                totalElapsedMs: totalElapsedMs,
                medianElapsedMs: median,
                bestMoveMatchCount: entries.filter(\.matchesBestMove).count,
                centipawnScoreCount: entries.compactMap(\.blackPerspectiveCp).count
            ),
            positions: entries.map {
                .init(
                    ply: $0.ply,
                    actualMove: $0.actualMove,
                    bestMove: $0.bestMove,
                    score: $0.scoreText,
                    blackPerspectiveCp: $0.blackPerspectiveCp,
                    depth: $0.depthText,
                    nodes: $0.nodesText,
                    nps: $0.npsText,
                    pv: $0.pv,
                    elapsedMs: $0.elapsedMs,
                    thermalBefore: $0.thermalBefore,
                    thermalAfter: $0.thermalAfter,
                    matchesBestMove: $0.matchesBestMove
                )
            },
            deepAnalysis: nil,
            error: error
        )

        return try encode(document)
    }

    static func augmentWithDeepAnalysis(
        url: URL,
        deepAnalysis: ShogiDiagnosticDocument.DeepAnalysisInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 2
        document.generatedAt = Date()
        document.deepAnalysis = deepAnalysis
        return try encode(document, url: url)
    }

    private static func encode(
        _ document: ShogiDiagnosticDocument,
        url: URL? = nil
    ) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)

        let outputURL: URL
        if let url {
            outputURL = url
        } else {
            let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            outputURL = directory.appendingPathComponent("shogi-ai-coach-diagnostic.json")
        }
        try data.write(to: outputURL, options: .atomic)
        return outputURL
    }

    private static func thermalText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func hardwareModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
