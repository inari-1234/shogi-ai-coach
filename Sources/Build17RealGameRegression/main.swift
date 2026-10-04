import Foundation
import ShogiCoachCore

private enum AuditError: Error, LocalizedError {
    case missingArgument(String)
    case invalidInteger(String, String)
    case noKIF(String)
    case insufficientGames(Int, Int)
    case insufficientPositions(Int, Int)
    case mandatoryRegression(String)
    case blockingIssues(Int)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let name):
            return "missing required argument: \(name)"
        case .invalidInteger(let name, let value):
            return "invalid integer for \(name): \(value)"
        case .noKIF(let path):
            return "no .kif files found under: \(path)"
        case .insufficientGames(let actual, let required):
            return "insufficient parsed games: \(actual) < \(required)"
        case .insufficientPositions(let actual, let required):
            return "insufficient audited positions: \(actual) < \(required)"
        case .mandatoryRegression(let detail):
            return "mandatory regression failed: \(detail)"
        case .blockingIssues(let count):
            return "blocking false-explanation issues: \(count)"
        }
    }
}

private struct Options {
    let inputDir: String
    let outputJSON: String
    let outputMarkdown: String
    let targetPositions: Int
    let maxPositionsPerGame: Int
    let minGames: Int
    let maxPly: Int
    let sourceID: String
    let sourceTitle: String
    let sourceURL: String
    let rightsNote: String
    let retrievedDate: String
    let gameSamplingPolicy: String
    let positionSamplingPolicy: String

    init(arguments: [String]) throws {
        func value(_ flag: String) throws -> String {
            guard let i = arguments.firstIndex(of: flag), i + 1 < arguments.count else {
                throw AuditError.missingArgument(flag)
            }
            return arguments[i + 1]
        }
        func integer(_ flag: String, default defaultValue: Int) throws -> Int {
            guard let i = arguments.firstIndex(of: flag) else { return defaultValue }
            guard i + 1 < arguments.count else { throw AuditError.missingArgument(flag) }
            let raw = arguments[i + 1]
            guard let parsed = Int(raw), parsed > 0 else {
                throw AuditError.invalidInteger(flag, raw)
            }
            return parsed
        }
        func optionalValue(_ flag: String, default defaultValue: String) throws -> String {
            guard let i = arguments.firstIndex(of: flag) else { return defaultValue }
            guard i + 1 < arguments.count else { throw AuditError.missingArgument(flag) }
            return arguments[i + 1]
        }

        inputDir = try value("--input-dir")
        outputJSON = try value("--output-json")
        outputMarkdown = try value("--output-markdown")
        targetPositions = try integer("--target-positions", default: 240)
        maxPositionsPerGame = try integer("--max-positions-per-game", default: 60)
        minGames = try integer("--min-games", default: 4)
        maxPly = try integer("--max-ply", default: 100)
        sourceID = try value("--source-id")
        sourceTitle = try value("--source-title")
        sourceURL = try value("--source-url")
        rightsNote = try value("--rights-note")
        retrievedDate = try value("--retrieved-date")
        gameSamplingPolicy = try optionalValue("--game-sampling-policy", default: "lexical-v1")
        positionSamplingPolicy = try optionalValue("--position-sampling-policy", default: "sequential-v1")
    }
}

private struct SourceInfo: Codable {
    let sourceID: String
    let title: String
    let sourceURL: String
    let rightsNote: String
    let retrievedDate: String
    let usage: String
}

private struct MandatoryRegressionResult: Codable {
    let id: String
    let passed: Bool
    let primaryIntent: String
    let confidence: String
    let primaryExplanation: String
    let conceptID: String?
    let geometryPrimary: Bool?
    let details: [String]
}

private struct AuditRecord: Codable {
    let gameID: String
    let ply: Int
    let position: String
    let previousMove: String?
    let currentMove: String
    let primaryIntent: String
    let confidence: String
    let phase: String
    let intentCandidateCount: Int
    let primaryExplanation: String
    let whyNow: String
    let rawPrimaryExplanation: String
    let rawWhyNow: String
    let rawConceptSupplementText: String?
    let presentationMode: String
    let whyNowSuppressedAsRepeatedGeneric: Bool
    let repetitionSemanticSignature: String
    let repetitionEquivalentRunLength: Int
    let repetitionResetReasons: [String]
    let whyNowTrigger: String
    let whyNowAuthority: String
    let whyNowVerbalizationMode: String
    let whyNowClaimTypes: [String]
    let whyNowSourceEvidenceIDs: [String]
    let whyNowSourceSignalIDs: [String]
    let whyNowMissingEvidence: [String]
    let whyNowCompatibleIntent: String?
    let selectedIntentEvidenceIDs: [String]
    let selectedIntentEvidenceKinds: [String]
    let selectedIntentNonGeometryEvidenceCount: Int
    let forcingPosition: Bool
    let quietOrAmbiguous: Bool
    let shikenbishaHeuristic: Bool
    let heldConceptLeakage: Bool
    let candidateConceptID: String?
    let supplementSuppressed: Bool
    let conceptSupplementPresent: Bool
    let conceptID: String?
    let conceptSupplementText: String?
    let falseExplanationCategories: [String]
    let overExplanationReview: Bool
    let beginnerReadabilityReview: Bool
    let notes: [String]
}

private struct FrequencySummary: Codable {
    let totalExplanations: Int
    let supplementCount: Int
    let supplementRate: Double
    let pieceMobilityCount: Int
    let escapeRouteControlCount: Int
    let attackAttackerCount: Int
    let candidateImmediateRepeatCount: Int
    let suppressedImmediateRepeatCount: Int
    let residualConsecutiveRepeatCount: Int
    let sameConceptShownWithin3PlyCount: Int
}

private struct GameAuditMetadata: Codable {
    let gameID: String
    let sourceFile: String
    let sourceType: String
    let sourceID: String
    let parsedComplete: Bool
    let totalMoves: Int
    let availablePlyMin: Int?
    let availablePlyMax: Int?
    let auditedPlyMin: Int?
    let auditedPlyMax: Int?
    let auditedPositions: Int
    let shikenbishaHeuristic: Bool
}

private struct AuditSummary: Codable {
    let verdict: String
    let parsedGames: Int
    let skippedGames: Int
    let auditedGames: Int
    let auditedPositions: Int
    let blockingIssueCount: Int
    let blockingCategoryCounts: [String: Int]
    let intentCounts: [String: Int]
    let confidenceCounts: [String: Int]
    let frequency: FrequencySummary
    let mandatoryRegressions: [MandatoryRegressionResult]
    let beginnerReadabilityReviewCandidateCount: Int
    let overExplanationReviewCandidateCount: Int
}

private struct AuditDocument: Codable {
    let schemaVersion: Int
    let stage: String
    let generatedAtUTC: String
    let source: SourceInfo
    let configuration: [String: Int]
    let samplingPolicy: [String: String]
    let games: [GameAuditMetadata]
    let summary: AuditSummary
    let records: [AuditRecord]
    let skippedFiles: [String]
}

private func stderr(_ message: String) {
    if let data = (message + "\n").data(using: .utf8) {
        try? FileHandle.standardError.write(contentsOf: data)
    }
}

private func mandatoryRegressions() throws -> [MandatoryRegressionResult] {
    stderr("checkpoint=mandatory_start")
    let engine = MoveContextEngine()

    stderr("checkpoint=regression_C_ply59_before_analyze")
    let positionC = "position startpos moves 2h7h 3c3d 7i6h 2c2d 7g7f 9c9d 1g1f 6c6d 5g5f 8b3b 5i4h 2d2e 4h3h 3a4b 6i5h 6a7b 6g6f 7a6b 6h5g 2b3c 3i2h 3b2b 8h7g 2e2f 2g2f 2b2f P*2g 2f2b 9g9f 4a5b 9f9e 9d9e 9i9e P*9c 7h9h 6b6c 4i4h 5a6b 3g3f 6b7a 6f6e 6d6e 9e9c+ 8a9c 9h9e P*9d 9e9d 7a8b P*6d 6c5d 9d9e P*9d 9e9h 9c8e 7g3c+ 4b3c 8g8f B*8g"
    let analysisC = try engine.analyze(
        positionCommand: positionC,
        move: "9h8h"
    )
    let explanationC = ContextExplanationGenerator.make(analysis: analysisC)
    let passC = analysisC.previousMove == "B*8g"
    let resultC = MandatoryRegressionResult(
        id: "C_build16_r1_ply59_overflow",
        passed: passC,
        primaryIntent: analysisC.selectedIntent.rawValue,
        confidence: analysisC.confidence.rawValue,
        primaryExplanation: explanationC.conclusion,
        conceptID: explanationC.conceptSupplement?.conceptID,
        geometryPrimary: nil,
        details: [
            "previous_move=B*8g",
            "move=9h8h",
            "completion=no_trap"
        ]
    )
    guard passC else { throw AuditError.mandatoryRegression(resultC.id) }

    stderr("checkpoint=mandatory_A_before_analyze")
    let analysisA = try engine.analyze(
        positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
        move: "8h7g"
    )
    let explanationA = ContextExplanationGenerator.make(analysis: analysisA)
    let geometryPrimaryA = analysisA.evidence.contains {
        $0.kind == .geometry && $0.supportedIntent == analysisA.selectedIntent && $0.weight > 0
    }
    let expectedTextA = "相手の飛車先の歩の前進に備える手です。"
    let passA = analysisA.selectedIntent == .rookPawnResponse
        && analysisA.confidence == .high
        && explanationA.conclusion == expectedTextA
        && !geometryPrimaryA

    let resultA = MandatoryRegressionResult(
        id: "A_locked_rook_pawn_response",
        passed: passA,
        primaryIntent: analysisA.selectedIntent.rawValue,
        confidence: analysisA.confidence.rawValue,
        primaryExplanation: explanationA.conclusion,
        conceptID: explanationA.conceptSupplement?.conceptID,
        geometryPrimary: geometryPrimaryA,
        details: [
            "position=startpos 7g7f 8c8d 2g2f 8d8e",
            "move=8h7g"
        ]
    )
    guard passA else { throw AuditError.mandatoryRegression(resultA.id) }

    stderr("checkpoint=mandatory_B_before_analyze")
    let analysisB = try engine.analyze(
        positionCommand: "position startpos moves 7g7f 3c3d",
        move: "8h2b+"
    )
    let explanationB = ContextExplanationGenerator.make(analysis: analysisB)
    let effectsB = Set(analysisB.effects.map(\.id))
    let passB = analysisB.selectedIntent == .bishopLineResponse
        && effectsB.contains("piece_mobility")
        && effectsB.contains("attack_attacker")
        && explanationB.conceptSupplement?.conceptID == "piece_mobility"

    let resultB = MandatoryRegressionResult(
        id: "B_bishop_line_multi_concept_priority",
        passed: passB,
        primaryIntent: analysisB.selectedIntent.rawValue,
        confidence: analysisB.confidence.rawValue,
        primaryExplanation: explanationB.conclusion,
        conceptID: explanationB.conceptSupplement?.conceptID,
        geometryPrimary: nil,
        details: [
            "position=startpos 7g7f 3c3d",
            "move=8h2b+",
            "effects=" + effectsB.sorted().joined(separator: ",")
        ]
    )
    guard passB else { throw AuditError.mandatoryRegression(resultB.id) }

    return [resultC, resultA, resultB]
}

private func structuralIssues(
    analysis: MoveContextAnalysis,
    explanation: ContextMoveExplanation
) -> [String] {
    var issues: [String] = []
    let supplement = explanation.conceptSupplement

    if explanation.confidence != analysis.confidence {
        issues.append("A_INTENT_OVERRIDE_CONFIDENCE_CHANGED")
    }
    if (analysis.confidence == .low || analysis.confidence == .unresolved), supplement != nil {
        issues.append("F_LOW_UNRESOLVED_SUPPLEMENT")
    }

    if let supplement {
        let displayText = [explanation.conclusion, explanation.whyNow, supplement.text].joined(separator: " ")
        for internalID in ["piece_mobility", "escape_route_control", "attack_attacker"] {
            if displayText.contains(internalID) {
                issues.append("H_INTERNAL_CONCEPT_ID_EXPOSED")
                break
            }
        }

        for forbidden in ["ための手", "目的", "狙い"] where supplement.text.contains(forbidden) {
            issues.append("B_PURPOSE_HALLUCINATION")
            break
        }

        if supplement.conceptID == "escape_route_control", supplement.text.contains("詰") {
            issues.append("C_MATE_HALLUCINATION")
        }
        if analysis.selectedIntent == .tenuki, supplement.conceptID == "attack_attacker" {
            issues.append("D_WRONG_CONTEXT_TENUKI_ATTACK_ATTACKER")
        }

        let permitted: Bool
        switch supplement.conceptID {
        case "attack_attacker":
            permitted = [
                MoveIntent.captureThreatResponse,
                .pieceDefense,
                .defense,
                .bishopLineResponse,
                .neutralizeThreat
            ].contains(analysis.selectedIntent)
        case "escape_route_control":
            permitted = [
                MoveIntent.attackContinuation,
                .attackPreparation,
                .matingAttack,
                .threatmate,
                .controlAddition,
                .outpostCreation
            ].contains(analysis.selectedIntent)
        case "piece_mobility":
            permitted = ![
                MoveIntent.unresolved,
                .pieceActivation,
                .majorPieceActivation,
                .development,
                .castling,
                .handPieceDeployment
            ].contains(analysis.selectedIntent)
        default:
            permitted = false
        }
        if !permitted {
            issues.append("G_PRIMARY_SUPPLEMENT_CONFLICT")
        }
    }

    return Array(Set(issues)).sorted()
}

private func makeMarkdown(
    document: AuditDocument,
    sampleLimit: Int = 80
) -> String {
    let s = document.summary
    let f = s.frequency
    var lines: [String] = [
        "# Build17-6R Real-game E2E / False Explanation Regression — Restart after Build16-R1",
        "",
        "- verdict: **\(s.verdict)**",
        "- audited games: \(s.auditedGames)",
        "- audited positions: \(s.auditedPositions)",
        "- concept supplement: \(f.supplementCount) / \(f.totalExplanations) (\(String(format: "%.2f", f.supplementRate * 100))%)",
        "- piece_mobility: \(f.pieceMobilityCount)",
        "- escape_route_control: \(f.escapeRouteControlCount)",
        "- attack_attacker: \(f.attackAttackerCount)",
        "- candidate immediate repeats: \(f.candidateImmediateRepeatCount)",
        "- suppressed immediate repeats: \(f.suppressedImmediateRepeatCount)",
        "- residual consecutive shown repeats: \(f.residualConsecutiveRepeatCount)",
        "- same concept shown within 3 ply: \(f.sameConceptShownWithin3PlyCount)",
        "- blocking false-explanation issues: \(s.blockingIssueCount)",
        "- beginner-readability review candidates: \(s.beginnerReadabilityReviewCandidateCount)",
        "- over-explanation review candidates: \(s.overExplanationReviewCandidateCount)",
        "",
        "## Mandatory regressions",
        ""
    ]
    for item in s.mandatoryRegressions {
        lines.append("- \(item.id): \(item.passed ? "PASS" : "FAIL") / intent=\(item.primaryIntent) / confidence=\(item.confidence) / concept=\(item.conceptID ?? "-")")
    }

    lines += [
        "",
        "## Source / rights",
        "",
        "- source: \(document.source.title)",
        "- source_id: \(document.source.sourceID)",
        "- source_url: \(document.source.sourceURL)",
        "- rights_note: \(document.source.rightsNote)",
        "- usage: \(document.source.usage)",
        "",
        "## Supplemented-position review sample",
        "",
        "| game | ply | intent | confidence | concept | primary | supplement | review |",
        "|---|---:|---|---|---|---|---|---|"
    ]

    let samples = document.records
        .filter { $0.conceptSupplementPresent || !$0.falseExplanationCategories.isEmpty || $0.beginnerReadabilityReview || $0.overExplanationReview }
        .prefix(sampleLimit)
    for item in samples {
        func cell(_ value: String) -> String {
            value.replacingOccurrences(of: "|", with: "\\|").replacingOccurrences(of: "\n", with: " ")
        }
        let review = item.falseExplanationCategories.isEmpty
            ? ((item.beginnerReadabilityReview || item.overExplanationReview) ? "MANUAL_REVIEW" : "")
            : item.falseExplanationCategories.joined(separator: ",")
        lines.append("| \(cell(item.gameID)) | \(item.ply) | \(item.primaryIntent) | \(item.confidence) | \(item.conceptID ?? "-") | \(cell(item.primaryExplanation)) | \(cell(item.conceptSupplementText ?? "-")) | \(cell(review)) |")
    }

    lines += [
        "",
        "## Human-audit guidance",
        "",
        "Review the full JSON records for semantic correctness. Automated gates cover Intent/confidence immutability, LOW/UNRESOLVED suppression, internal-ID exposure, purpose/mate hallucination markers, tenuki attack_attacker misuse, permitted Intent/Concept pairings, and repetition policy. Human review remains authoritative for naturalness, subtle semantic conflict, over-explanation, and beginner confusion.",
        ""
    ]
    return lines.joined(separator: "\n")
}

private func stableFNV1a64(_ value: String) -> UInt64 {
    var hash: UInt64 = 1469598103934665603
    for byte in value.utf8 {
        hash ^= UInt64(byte)
        hash &*= 1099511628211
    }
    return hash
}

private func auditPhase(for ply: Int) -> String {
    if ply <= 30 { return "OPENING" }
    if ply <= 70 { return "MIDDLEGAME" }
    return "ENDGAME"
}

private func hasHeldConceptLeakage(_ text: String) -> Bool {
    let heldTokens = [
        "respond_to_rapid_attack",
        "sabai",
        "trade_to_transform",
        "multi_threat",
        "tempo_management",
        "急戦",
        "さばき",
        "捌き",
        "局面を変えるための交換",
        "複数の狙い",
        "テンポ管理"
    ]
    return heldTokens.contains { text.contains($0) }
}

private func run() throws {
    let options = try Options(arguments: Array(CommandLine.arguments.dropFirst()))
    let mandatory = try mandatoryRegressions()

    let fm = FileManager.default
    let inputURL = URL(fileURLWithPath: options.inputDir, isDirectory: true)
    guard let enumerator = fm.enumerator(
        at: inputURL,
        includingPropertiesForKeys: [.isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else {
        throw AuditError.noKIF(options.inputDir)
    }

    var kifURLs: [URL] = []
    for case let url as URL in enumerator where url.pathExtension.lowercased() == "kif" {
        kifURLs.append(url)
    }
    kifURLs.sort { $0.path < $1.path }
    if options.gameSamplingPolicy == "deterministic-hash-v1" {
        kifURLs.sort {
            let lhs = stableFNV1a64($0.lastPathComponent)
            let rhs = stableFNV1a64($1.lastPathComponent)
            if lhs == rhs { return $0.path < $1.path }
            return lhs < rhs
        }
    }
    guard !kifURLs.isEmpty else { throw AuditError.noKIF(options.inputDir) }

    let engine = MoveContextEngine()
    var records: [AuditRecord] = []
    var skippedFiles: [String] = []
    var parsedGames = 0
    var skippedGames = 0
    var auditedGames = 0
    var intentCounts: [String: Int] = [:]
    var confidenceCounts: [String: Int] = [:]
    var supplementCounts = [
        "piece_mobility": 0,
        "escape_route_control": 0,
        "attack_attacker": 0
    ]
    var categoryCounts: [String: Int] = [:]
    var candidateImmediateRepeatCount = 0
    var suppressedImmediateRepeatCount = 0
    var residualConsecutiveRepeatCount = 0
    var sameConceptShownWithin3PlyCount = 0
    var beginnerReviewCount = 0
    var overExplanationReviewCount = 0
    var gameMetadata: [GameAuditMetadata] = []

    for url in kifURLs {
        if records.count >= options.targetPositions, auditedGames >= options.minGames { break }

        let game: KIFGame
        stderr("checkpoint=parse_game file=\(url.lastPathComponent)")
        do {
            game = try KIFParser.parse(data: Data(contentsOf: url))
            parsedGames += 1
        } catch {
            skippedGames += 1
            skippedFiles.append("\(url.lastPathComponent): \(error.localizedDescription)")
            continue
        }

        var shikenbishaHeuristic = false
        var blackRookSquare = "2h"
        var whiteRookSquare = "8b"
        for openingMove in game.moves where openingMove.ply <= 30 {
            let usi = openingMove.usi
            guard !usi.contains("*"), usi.count >= 4 else { continue }
            let source = String(usi.prefix(2))
            let destination = String(usi.dropFirst(2).prefix(2))
            if openingMove.ply % 2 == 1, source == blackRookSquare {
                blackRookSquare = destination
                if destination.first != "2" { shikenbishaHeuristic = true }
            } else if openingMove.ply % 2 == 0, source == whiteRookSquare {
                whiteRookSquare = destination
                if destination.first != "8" { shikenbishaHeuristic = true }
            }
        }

        var gameRecords = 0
        var auditedPlies: [Int] = []
        var previousCandidateConceptID: String?
        var previousShownConceptID: String?
        var lastShownPlyByConcept: [String: Int] = [:]
        var explanationRepetitionState = ContextExplanationRepetitionState()
        var previousAuditedPly: Int?

        let eligibleMoves = game.moves.filter { $0.ply <= options.maxPly }
        var movesToAudit = eligibleMoves
        if options.positionSamplingPolicy == "evenly-spaced-v1",
           eligibleMoves.count > options.maxPositionsPerGame {
            let count = options.maxPositionsPerGame
            movesToAudit = (0..<count).map { index in
                let denominator = max(1, count - 1)
                let sourceIndex = index * (eligibleMoves.count - 1) / denominator
                return eligibleMoves[sourceIndex]
            }
        }

        for move in movesToAudit {
            if gameRecords >= options.maxPositionsPerGame { break }
            if records.count >= options.targetPositions, auditedGames + 1 >= options.minGames { break }

            let analysis: MoveContextAnalysis
            stderr("checkpoint=analyze file=\(url.lastPathComponent) ply=\(move.ply) move=\(move.usi)")
            do {
                analysis = try engine.analyze(
                    positionCommand: move.positionBefore,
                    move: move.usi
                )
            } catch {
                skippedFiles.append("\(url.lastPathComponent)#ply\(move.ply): analysis error: \(error.localizedDescription)")
                continue
            }

            let grounded = GroundedExplanationProjector.make(analysis: analysis)
            let selectedEvidence = analysis.evidence.filter {
                $0.supportedIntent == analysis.selectedIntent && $0.weight > 0
            }
            let candidateExplanation = ContextExplanationGenerator.make(analysis: analysis)
            let candidateConceptID = candidateExplanation.conceptSupplement?.conceptID
            var suppression: Set<String> = []

            if let candidateConceptID, candidateConceptID == previousCandidateConceptID {
                candidateImmediateRepeatCount += 1
                suppression.insert(candidateConceptID)
            }

            if let previousAuditedPly, move.ply != previousAuditedPly + 1 {
                explanationRepetitionState.reset()
            }
            let presentation = explanationRepetitionState.present(
                analysis: analysis,
                suppressingConceptIDs: suppression
            )
            let explanation = presentation.semanticExplanation
            let displayedExplanation = presentation.displayedExplanation
            let shownConceptID = displayedExplanation?.conceptSupplement?.conceptID

            if !suppression.isEmpty, shownConceptID == nil {
                suppressedImmediateRepeatCount += 1
            }
            if let shownConceptID, shownConceptID == previousShownConceptID {
                residualConsecutiveRepeatCount += 1
            }
            if let shownConceptID, let lastPly = lastShownPlyByConcept[shownConceptID], move.ply - lastPly <= 3 {
                sameConceptShownWithin3PlyCount += 1
            }
            if let shownConceptID {
                lastShownPlyByConcept[shownConceptID] = move.ply
            }

            let issues = structuralIssues(analysis: analysis, explanation: explanation)
            for issue in issues { categoryCounts[issue, default: 0] += 1 }

            let supplementLength = displayedExplanation?.conceptSupplement?.text.count ?? 0
            let primaryLength = (displayedExplanation?.conclusion.count ?? 0)
                + (displayedExplanation?.whyNow.count ?? 0)
            let overExplanation = supplementLength > 0 && supplementLength > primaryLength
            let beginnerReview = displayedExplanation?.conceptSupplement != nil && (
                supplementLength >= 45
                || (displayedExplanation?.conclusion.contains("詰み") ?? false)
                || (displayedExplanation?.whyNow.contains("反実仮想") ?? false)
            )
            if overExplanation { overExplanationReviewCount += 1 }
            if beginnerReview { beginnerReviewCount += 1 }

            var notes: [String] = []
            if !suppression.isEmpty { notes.append("immediate repeated candidate suppressed") }
            notes.append("explanation_presentation_mode=\(presentation.mode.rawValue)")
            if !presentation.resetReasons.isEmpty {
                notes.append("explanation_reset=" + presentation.resetReasons.joined(separator: ","))
            }
            if analysis.effects.count > 1 {
                let conceptEffects = analysis.effects
                    .map(\.id)
                    .filter { ["piece_mobility", "escape_route_control", "attack_attacker"].contains($0) }
                if conceptEffects.count > 1 {
                    notes.append("multiple concepts observed: " + conceptEffects.joined(separator: ","))
                }
            }

            let combinedExplanation = [
                explanation.conclusion,
                explanation.whyNow,
                explanation.conceptSupplement?.text ?? ""
            ].joined(separator: " ")
            let forcingPosition = [
                GroundedWhyNowTrigger.immediateThreat,
                .forcingTactic,
                .exchangeSequence
            ].contains(grounded.trigger)
                || analysis.facts.contains(where: { $0.kind == .sideInCheck || $0.kind == .check })
            let quietOrAmbiguous = grounded.trigger == .noneIdentified
                && !forcingPosition
                && (analysis.confidence == .low
                    || analysis.confidence == .unresolved
                    || analysis.intentCandidates.count > 1)

            let record = AuditRecord(
                gameID: url.deletingPathExtension().lastPathComponent,
                ply: move.ply,
                position: move.positionBefore,
                previousMove: analysis.previousMove,
                currentMove: move.usi,
                primaryIntent: analysis.selectedIntent.rawValue,
                confidence: analysis.confidence.rawValue,
                phase: auditPhase(for: move.ply),
                intentCandidateCount: analysis.intentCandidates.count,
                primaryExplanation: displayedExplanation?.conclusion ?? "",
                whyNow: displayedExplanation?.whyNow ?? "",
                rawPrimaryExplanation: explanation.conclusion,
                rawWhyNow: explanation.whyNow,
                rawConceptSupplementText: explanation.conceptSupplement?.text,
                presentationMode: presentation.mode.rawValue,
                whyNowSuppressedAsRepeatedGeneric: presentation.whyNowSuppressedAsRepeatedGeneric,
                repetitionSemanticSignature: presentation.semanticSignature,
                repetitionEquivalentRunLength: presentation.equivalentRunLength,
                repetitionResetReasons: presentation.resetReasons,
                whyNowTrigger: grounded.trigger.rawValue,
                whyNowAuthority: grounded.authorityKind.rawValue,
                whyNowVerbalizationMode: grounded.verbalizationMode.rawValue,
                whyNowClaimTypes: grounded.claimTypes.map(\.rawValue),
                whyNowSourceEvidenceIDs: grounded.sourceEvidenceIDs,
                whyNowSourceSignalIDs: grounded.sourceSignalIDs,
                whyNowMissingEvidence: grounded.missingEvidence.map(\.rawValue),
                whyNowCompatibleIntent: grounded.compatibleIntent?.rawValue,
                selectedIntentEvidenceIDs: selectedEvidence.map(\.id).sorted(),
                selectedIntentEvidenceKinds: selectedEvidence.map { $0.kind.rawValue }.sorted(),
                selectedIntentNonGeometryEvidenceCount: selectedEvidence.filter { $0.kind != .geometry }.count,
                forcingPosition: forcingPosition,
                quietOrAmbiguous: quietOrAmbiguous,
                shikenbishaHeuristic: shikenbishaHeuristic,
                heldConceptLeakage: hasHeldConceptLeakage(combinedExplanation),
                candidateConceptID: candidateConceptID,
                supplementSuppressed: !suppression.isEmpty,
                conceptSupplementPresent: displayedExplanation?.conceptSupplement != nil,
                conceptID: shownConceptID,
                conceptSupplementText: displayedExplanation?.conceptSupplement?.text,
                falseExplanationCategories: issues,
                overExplanationReview: overExplanation,
                beginnerReadabilityReview: beginnerReview,
                notes: notes
            )
            records.append(record)
            gameRecords += 1
            auditedPlies.append(move.ply)
            intentCounts[analysis.selectedIntent.rawValue, default: 0] += 1
            confidenceCounts[analysis.confidence.rawValue, default: 0] += 1
            if let shownConceptID { supplementCounts[shownConceptID, default: 0] += 1 }

            previousCandidateConceptID = candidateConceptID
            previousShownConceptID = shownConceptID
            previousAuditedPly = move.ply
        }

        if gameRecords > 0 {
            auditedGames += 1
            let availablePlies = game.moves.map(\.ply)
            gameMetadata.append(GameAuditMetadata(
                gameID: url.deletingPathExtension().lastPathComponent,
                sourceFile: url.lastPathComponent,
                sourceType: "official_kif",
                sourceID: options.sourceID,
                parsedComplete: true,
                totalMoves: game.moves.count,
                availablePlyMin: availablePlies.min(),
                availablePlyMax: availablePlies.max(),
                auditedPlyMin: auditedPlies.min(),
                auditedPlyMax: auditedPlies.max(),
                auditedPositions: gameRecords,
                shikenbishaHeuristic: shikenbishaHeuristic
            ))
        }
    }

    guard auditedGames >= options.minGames else {
        throw AuditError.insufficientGames(auditedGames, options.minGames)
    }
    guard records.count >= options.targetPositions else {
        throw AuditError.insufficientPositions(records.count, options.targetPositions)
    }

    let blockingCount = categoryCounts.values.reduce(0, +) + residualConsecutiveRepeatCount
    let supplementCount = supplementCounts.values.reduce(0, +)
    let frequency = FrequencySummary(
        totalExplanations: records.count,
        supplementCount: supplementCount,
        supplementRate: records.isEmpty ? 0 : Double(supplementCount) / Double(records.count),
        pieceMobilityCount: supplementCounts["piece_mobility", default: 0],
        escapeRouteControlCount: supplementCounts["escape_route_control", default: 0],
        attackAttackerCount: supplementCounts["attack_attacker", default: 0],
        candidateImmediateRepeatCount: candidateImmediateRepeatCount,
        suppressedImmediateRepeatCount: suppressedImmediateRepeatCount,
        residualConsecutiveRepeatCount: residualConsecutiveRepeatCount,
        sameConceptShownWithin3PlyCount: sameConceptShownWithin3PlyCount
    )
    let verdict = blockingCount == 0 ? "AUTOMATED PASS — HUMAN AUDIT REQUIRED" : "FAIL — CORRECTION REQUIRED"

    let summary = AuditSummary(
        verdict: verdict,
        parsedGames: parsedGames,
        skippedGames: skippedGames,
        auditedGames: auditedGames,
        auditedPositions: records.count,
        blockingIssueCount: blockingCount,
        blockingCategoryCounts: categoryCounts,
        intentCounts: intentCounts,
        confidenceCounts: confidenceCounts,
        frequency: frequency,
        mandatoryRegressions: mandatory,
        beginnerReadabilityReviewCandidateCount: beginnerReviewCount,
        overExplanationReviewCandidateCount: overExplanationReviewCount
    )

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    let document = AuditDocument(
        schemaVersion: 1,
        stage: "Build17-6R Real-game E2E / False Explanation Regression — Restart after Build16-R1",
        generatedAtUTC: formatter.string(from: Date()),
        source: SourceInfo(
            sourceID: options.sourceID,
            title: options.sourceTitle,
            sourceURL: options.sourceURL,
            rightsNote: options.rightsNote,
            retrievedDate: options.retrievedDate,
            usage: "regression fixture / E2E input only; not persisted as training data"
        ),
        configuration: [
            "targetPositions": options.targetPositions,
            "maxPositionsPerGame": options.maxPositionsPerGame,
            "minGames": options.minGames,
            "maxPly": options.maxPly
        ],
        samplingPolicy: [
            "game": options.gameSamplingPolicy,
            "position": options.positionSamplingPolicy
        ],
        games: gameMetadata,
        summary: summary,
        records: records,
        skippedFiles: skippedFiles
    )

    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let jsonData = try encoder.encode(document)

    let jsonURL = URL(fileURLWithPath: options.outputJSON)
    let markdownURL = URL(fileURLWithPath: options.outputMarkdown)
    try fm.createDirectory(at: jsonURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try fm.createDirectory(at: markdownURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try jsonData.write(to: jsonURL, options: .atomic)
    try makeMarkdown(document: document).write(to: markdownURL, atomically: true, encoding: .utf8)

    print("build17_6r_automated_status=\(blockingCount == 0 ? "PASS" : "FAIL")")
    print("build17_6r_games=\(auditedGames)")
    print("build17_6r_positions=\(records.count)")
    print("build17_6r_supplements=\(supplementCount)")
    print("build17_6r_supplement_rate=\(String(format: "%.4f", frequency.supplementRate))")
    print("build17_6r_piece_mobility=\(frequency.pieceMobilityCount)")
    print("build17_6r_escape_route_control=\(frequency.escapeRouteControlCount)")
    print("build17_6r_attack_attacker=\(frequency.attackAttackerCount)")
    print("build17_6r_residual_repetition=\(residualConsecutiveRepeatCount)")
    print("build17_6r_blocking_issues=\(blockingCount)")

    if blockingCount > 0 {
        throw AuditError.blockingIssues(blockingCount)
    }
}

do {
    try run()
} catch {
    stderr("build17_6r_automated_status=FAIL")
    stderr(error.localizedDescription)
    exit(1)
}
