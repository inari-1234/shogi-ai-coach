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
        let bestPV: String
        let actualPV: String
        let actualAnalysisSource: String
        let opponentBestReply: String
        let candidates: [DeepCandidateInfo]
        let elapsedMs: Int
        let thermalBefore: String
        let thermalAfter: String
        let comparisonStable: Bool
        let instabilityReasons: [String]
        let continuationStable: Bool
        let continuationInstabilityReasons: [String]
        let analysisAttempts: Int
        let finalMovetimeMs: Int
        let adaptiveTriggered: Bool
        let topCandidateGapCp: Int?
    }

    struct DeepAnalysisInfo: Codable {
        let status: String
        let requestedMoveTimeMs: Int
        let multiPV: Int
        let selectedPositions: Int
        let completedPositions: Int
        let totalElapsedMs: Int
        let focus: String
        let adaptivePolicy: String
        let positions: [DeepPositionInfo]
        let error: String?
    }

    struct BoardDisplayPositionInfo: Codable {
        let ply: Int
        let sideToMove: String
        let orientation: String
        let bestMove: String
        let source: String?
        let destination: String
        let isDrop: Bool
        let piece: String
        let promotes: Bool
        let actualMove: String
        let actualSource: String?
        let actualDestination: String
        let squarePieceCount: Int
        let blackHandCount: Int
        let whiteHandCount: Int
    }

    struct BoardDisplayInfo: Codable {
        let status: String
        let expectedPositions: Int
        let completedPositions: Int
        let positions: [BoardDisplayPositionInfo]
        let error: String?
    }

    struct ReasonFactInfo: Codable {
        let id: String
        let level: String
        let kind: String
        let text: String
        let evidenceMoves: [String]
    }

    struct ReasonInterpretationInfo: Codable {
        let text: String
        let evidenceFactIDs: [String]
    }

    struct ReasonPositionInfo: Codable {
        let ply: Int
        let actualMove: String
        let bestMove: String
        let bestScore: String
        let actualScore: String
        let actualLossCp: Int?
        let bestPV: String
        let actualPV: String
        let bestReply: String
        let actualReply: String
        let facts: [ReasonFactInfo]
        let interpretation: ReasonInterpretationInfo
    }

    struct ReasonAnalysisInfo: Codable {
        let status: String
        let expectedPositions: Int
        let completedPositions: Int
        let positions: [ReasonPositionInfo]
        let error: String?
    }

    struct ContinuationMoveInfo: Codable {
        let index: Int
        let usi: String
        let side: String
        let source: String?
        let destination: String
        let piece: String
        let capturedPiece: String?
        let isDrop: Bool
        let promotes: Bool
        let givesCheck: Bool
        let label: String
        let coachText: String
    }

    struct ContinuationBlockInfo: Codable {
        let startIndex: Int
        let endIndex: Int
        let title: String
        let summary: String
    }

    struct ContinuationRouteInfo: Codable {
        let kind: String
        let score: String
        let stable: Bool
        let moves: [ContinuationMoveInfo]
        let developmentBlocks: [ContinuationBlockInfo]
        let targetShapeSummary: String
    }

    struct ContinuationPositionInfo: Codable {
        let ply: Int
        let comparisonStable: Bool
        let continuationStable: Bool
        let actualLossCp: Int?
        let recommended: ContinuationRouteInfo
        let actual: ContinuationRouteInfo
        let reasonSummary: String
    }

    struct ContinuationSimulationInfo: Codable {
        let status: String
        let expectedPositions: Int
        let completedPositions: Int
        let positions: [ContinuationPositionInfo]
        let error: String?
    }

    struct PhasePointInfo: Codable {
        let ply: Int
        let title: String
        let detail: String
        let evidence: [String]
        let source: String
        let continuationSummary: String?
    }

    struct PhaseSectionInfo: Codable {
        let kind: String
        let title: String
        let startPly: Int
        let endPly: Int
        let summary: String
        let focusText: String
        let points: [PhasePointInfo]
    }

    struct PhaseTransitionInfo: Codable {
        let ply: Int
        let phase: String
        let cumulativeCaptures: Int
        let totalHandPieces: Int
        let promotedPieces: Int
        let enemyCampPieces: Int
        let majorPieceContacts: Int
        let recentChecks: Int
        let kingPressure: Int
        let evaluationSwingCp: Int?
        let mateSignal: Bool
        let sideToMoveInCheck: Bool
    }

    struct PhaseAnalysisInfo: Codable {
        let status: String
        let usedAdditionalEngineSearch: Bool
        let sections: [PhaseSectionInfo]
        let transitions: [PhaseTransitionInfo]
        let error: String?
    }

    struct ContextPositionInfo: Codable {
        let ply: Int
        let analysis: MoveContextAnalysis
        let explanation: ContextMoveExplanation
        let presentationMode: ContextExplanationPresentationMode
        let presentedExplanation: ContextMoveExplanation?
        let explanationEquivalentRunLength: Int
        let explanationResetReasons: [String]
        let recommendedMove: String?
        let recommendedExplanation: ContextMoveExplanation?
    }

    struct ContextAnalysisInfo: Codable {
        let status: String
        let usedAdditionalEngineSearch: Bool
        let expectedPositions: Int
        let completedPositions: Int
        let positions: [ContextPositionInfo]
        let knowledgeLoadStatus: String?
        let knowledgeSourceIDs: [String]?
        let knowledgeRecordCount: Int?
        let knowledgeMatchedPositions: Int?
        let refinementPolicy: String?
        let refinementCandidatePlies: [Int]?
        let refinementCompletedPlies: [Int]?
        let refinementConfidenceChangedCount: Int?
        let refinementIntentChangedCount: Int?
        let refinementUnresolvedAfterCount: Int?
        let refinementError: String?
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
    var boardDisplay: BoardDisplayInfo?
    var reasonAnalysis: ReasonAnalysisInfo?
    var continuationSimulation: ContinuationSimulationInfo?
    var phaseAnalysis: PhaseAnalysisInfo?
    var contextAnalysis: ContextAnalysisInfo?
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
            boardDisplay: nil,
            reasonAnalysis: nil,
            continuationSimulation: nil,
            phaseAnalysis: nil,
            contextAnalysis: nil,
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

    static func augmentWithBoardDisplay(
        url: URL,
        boardDisplay: ShogiDiagnosticDocument.BoardDisplayInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 3
        document.generatedAt = Date()
        document.boardDisplay = boardDisplay
        return try encode(document, url: url)
    }

    static func augmentWithReasonAnalysis(
        url: URL,
        reasonAnalysis: ShogiDiagnosticDocument.ReasonAnalysisInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 4
        document.generatedAt = Date()
        document.reasonAnalysis = reasonAnalysis
        return try encode(document, url: url)
    }

    static func augmentWithContinuationSimulation(
        url: URL,
        continuationSimulation: ShogiDiagnosticDocument.ContinuationSimulationInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 5
        document.generatedAt = Date()
        document.continuationSimulation = continuationSimulation
        return try encode(document, url: url)
    }

    static func augmentWithPhaseAnalysis(
        url: URL,
        phaseAnalysis: ShogiDiagnosticDocument.PhaseAnalysisInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 7
        document.generatedAt = Date()
        document.phaseAnalysis = phaseAnalysis
        return try encode(document, url: url)
    }

    static func augmentWithContextAnalysis(
        url: URL,
        contextAnalysis: ShogiDiagnosticDocument.ContextAnalysisInfo
    ) throws -> URL {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var document = try decoder.decode(ShogiDiagnosticDocument.self, from: data)
        document.schemaVersion = 8
        document.generatedAt = Date()
        document.contextAnalysis = contextAnalysis
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
