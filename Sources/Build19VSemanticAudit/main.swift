import Foundation
import ShogiCoachCore

private struct ProbeDocument: Decodable {
    let schemaVersion: Int
    let stage: String
    let requirementRecordCount: Int
    let continuityRecordCount: Int
    let records: [ProbeRecord]
}

private struct ProbeRecord: Decodable {
    let id: String
    let group: String
    let gameID: String
    let ply: Int
    let position: String
    let currentMove: String
    let phase: String?
    let build18Intent: String?
    let build18Confidence: String?
    let build18Trigger: String?
    let gapCategory: String
    let evidenceProfile: String
    let pairKind: String
    let search: ProbeSearch
    let comparisonStable: Bool
    let continuationStable: Bool
    let candidateA: ProbeCandidate
    let candidateB: ProbeCandidate
}

private struct ProbeSearch: Decodable {
    let engineContextID: String
    let searchConditionID: String
    let lowMoveTimeMs: Int
    let highMoveTimeMs: Int
    let threads: Int
    let hashMB: Int
    let scorePerspective: String
}

private struct ProbeCandidate: Decodable {
    let candidateID: String
    let rank: Int
    let move: String
    let branchType: String
    let score: ProbeScore
    let lowScore: ProbeScore
    let pv: [String]
    let lowPV: [String]
    let continuationStable: Bool
}

private struct ProbeScore: Decodable {
    let kind: String
    let value: Int
    let bound: String?

    func toUSIScore() throws -> USIScore {
        let parsedBound: USIScore.Bound?
        switch bound {
        case "lower": parsedBound = .lower
        case "upper": parsedBound = .upper
        case nil: parsedBound = nil
        default: throw AuditError.invalidScoreBound(bound ?? "")
        }
        switch kind {
        case "cp": return .centipawn(value, bound: parsedBound)
        case "mate": return .mate(value, bound: parsedBound)
        default: throw AuditError.invalidScoreKind(kind)
        }
    }
}

private struct OutputDocument: Encodable {
    let schemaVersion: Int
    let stage: String
    let generatedAtUTC: String
    let requirementRecordCount: Int
    let continuityRecordCount: Int
    let summary: OutputSummary
    let records: [OutputRecord]
}

private struct OutputSummary: Encodable {
    let totalRecords: Int
    let pairKindCounts: [String: Int]
    let comparisonStableCount: Int
    let continuationStableCount: Int
    let confidenceCounts: [String: Int]
    let wordingStrengthCounts: [String: Int]
    let toneCounts: [String: Int]
    let presentationModeCounts: [String: Int]
    let unresolvedCount: Int
    let scoreOnlyCausalUsageCount: Int
    let holdTermLeakageCount: Int
    let forcedReplyOverclaimCount: Int
}

private struct OutputSection: Encodable {
    let kind: String
    let text: String
    let evidenceIDs: [String]
    let confidence: String
    let causalWordingUsed: Bool
}

private struct OutputRecord: Encodable {
    let id: String
    let group: String
    let gameID: String
    let ply: Int
    let phase: String?
    let actualMove: String
    let pairKind: String
    let build18Intent: String?
    let build18Confidence: String?
    let build18Trigger: String?
    let gapCategory: String
    let evidenceProfile: String
    let candidateAMove: String
    let candidateBMove: String
    let candidateAScore: String
    let candidateBScore: String
    let comparisonStable: Bool
    let continuationStable: Bool
    let stableHorizonPly: Int
    let sequenceStable: Bool
    let differenceKinds: [String]
    let dominantDifferenceKind: String?
    let usedEvidenceIDs: [String]
    let usedEvidenceKinds: [String]
    let withheldEvidenceIDs: [String]
    let comparisonConfidence: String
    let wordingStrength: String
    let tone: String
    let headline: String
    let primaryReason: String
    let alternativeOutcome: String?
    let differenceTiming: String?
    let opponentOpportunity: String?
    let exchangeAfter: String?
    let confidenceNote: String
    let sections: [OutputSection]
    let causalSectionCount: Int
    let presentationMode: String?
    let presentationRunLength: Int?
    let presentationResetReasons: [String]
    let displayedHeadline: String?
    let displayedPrimaryReason: String?
    let warnings: [String]
}

private enum AuditError: Error, LocalizedError {
    case missingArgument(String)
    case invalidScoreKind(String)
    case invalidScoreBound(String)
    case invalidBranchType(String)
    case invalidPairKind(String)
    case comparisonIDMismatch(String)

    var errorDescription: String? {
        switch self {
        case .missingArgument(let value): return "missing argument \(value)"
        case .invalidScoreKind(let value): return "invalid score kind \(value)"
        case .invalidScoreBound(let value): return "invalid score bound \(value)"
        case .invalidBranchType(let value): return "invalid branch type \(value)"
        case .invalidPairKind(let value): return "invalid pair kind \(value)"
        case .comparisonIDMismatch(let value): return "comparison id mismatch \(value)"
        }
    }
}

private func argument(_ name: String) throws -> String {
    let args = CommandLine.arguments
    guard let index = args.firstIndex(of: name), index + 1 < args.count else {
        throw AuditError.missingArgument(name)
    }
    return args[index + 1]
}

private func branchType(_ raw: String) throws -> CandidateBranchType {
    switch raw {
    case "recommended": return .recommended
    case "actual": return .actual
    case "alternative": return .alternative
    case "rankedCandidate": return .rankedCandidate
    default: throw AuditError.invalidBranchType(raw)
    }
}

private func pairKind(_ raw: String) throws -> CandidatePairKind {
    switch raw {
    case "BEST_VS_ACTUAL": return .bestVsActual
    case "TOP1_VS_TOP2": return .top1VsTop2
    case "CUSTOM": return .custom
    default: throw AuditError.invalidPairKind(raw)
    }
}

private func makeCandidate(
    record: ProbeRecord,
    candidate: ProbeCandidate,
    label: String
) throws -> CandidateAnalysis {
    let evidence = CandidateSourceEvidence(
        id: "\(record.id)-engine-\(label)",
        kind: "PINNED_ENGINE_CANDIDATE_PV",
        sourceMoves: Array(candidate.pv.prefix(5))
    )
    let context = EngineComparisonContext(
        engineContextID: record.search.engineContextID,
        searchConditionID: record.search.searchConditionID,
        scorePerspective: record.search.scorePerspective,
        requestedMoveTimeMs: record.search.highMoveTimeMs,
        requestedDepth: nil
    )
    return try CandidateAnalysisResolver.resolve(
        .init(
            candidateID: candidate.candidateID,
            rank: candidate.rank,
            move: candidate.move,
            score: try candidate.score.toUSIScore(),
            pv: candidate.pv,
            comparisonStable: record.comparisonStable,
            continuationStable: candidate.continuationStable,
            positionCommand: record.position,
            sourceEvidence: [evidence],
            analysisWarnings: [],
            engineContext: context,
            branchType: try branchType(candidate.branchType)
        )
    )
}

private let holdTerms = [
    "respond_to_rapid_attack", "sabai", "trade_to_transform", "multi_threat", "tempo_management",
    "急戦", "さばき", "捌き", "局面を変えるための交換", "複数の狙い", "テンポ管理"
]

private let forcedOverclaimTerms = ["唯一の応手", "この手しか", "必然の応手", "強制された応手"]

private func combinedVisibleText(_ explanation: CandidateComparisonCoachingExplanation) -> String {
    [
        explanation.headline,
        explanation.primaryReason,
        explanation.alternativeOutcome ?? "",
        explanation.differenceTiming ?? "",
        explanation.opponentOpportunity ?? "",
        explanation.exchangeAfter ?? "",
        explanation.confidenceNote
    ].joined(separator: " ")
}

private func run() throws {
    let inputPath = try argument("--input")
    let outputPath = try argument("--output")
    let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
    let input = try JSONDecoder().decode(ProbeDocument.self, from: data)

    var outputs: [OutputRecord] = []
    var repetitionState = ComparisonCoachingExplanationRepetitionState()
    var previousContinuityGame: String?
    var previousContinuityPly: Int?

    for record in input.records {
        let a = try makeCandidate(record: record, candidate: record.candidateA, label: "A")
        let b = try makeCandidate(record: record, candidate: record.candidateB, label: "B")
        let comparison = CandidateComparisonResolver.compare(
            comparisonID: record.id,
            pairKind: try pairKind(record.pairKind),
            candidateA: a,
            candidateB: b
        )
        let sequence = SequenceCounterfactualEvidenceResolver.resolve(comparison: comparison, maxPlies: 5)
        let confidence = ComparisonConfidenceResolver.resolve(comparison: comparison, sequence: sequence)
        let semantic = ComparisonCoachingExplanationResolver.resolve(
            comparison: comparison,
            confidence: confidence,
            sequence: sequence
        )
        guard semantic.comparisonID == record.id else {
            throw AuditError.comparisonIDMismatch(record.id)
        }

        var presentationMode: String?
        var presentationRunLength: Int?
        var presentationResetReasons: [String] = []
        var displayedHeadline: String?
        var displayedPrimaryReason: String?

        if record.group == "continuity" {
            if previousContinuityGame != record.gameID || previousContinuityPly.map({ record.ply != $0 + 1 }) == true {
                repetitionState.reset()
            }
            let presentation = repetitionState.present(
                comparison: comparison,
                confidence: confidence,
                sequence: sequence
            )
            presentationMode = presentation.mode.rawValue
            presentationRunLength = presentation.equivalentRunLength
            presentationResetReasons = presentation.resetReasons
            displayedHeadline = presentation.displayedExplanation?.headline
            displayedPrimaryReason = presentation.displayedExplanation?.primaryReason
            previousContinuityGame = record.gameID
            previousContinuityPly = record.ply
        }

        let evidenceByID = Dictionary(uniqueKeysWithValues: comparison.differenceEvidence.map { ($0.id, $0) })
        let usedKinds = semantic.usedEvidenceIDs.compactMap { evidenceByID[$0]?.kind.rawValue }.sorted()
        let sections = semantic.sections.map {
            OutputSection(
                kind: $0.kind.rawValue,
                text: $0.text,
                evidenceIDs: $0.evidenceIDs,
                confidence: $0.confidence.rawValue,
                causalWordingUsed: $0.causalWordingUsed
            )
        }

        outputs.append(
            OutputRecord(
                id: record.id,
                group: record.group,
                gameID: record.gameID,
                ply: record.ply,
                phase: record.phase,
                actualMove: record.currentMove,
                pairKind: comparison.pairKind.rawValue,
                build18Intent: record.build18Intent,
                build18Confidence: record.build18Confidence,
                build18Trigger: record.build18Trigger,
                gapCategory: record.gapCategory,
                evidenceProfile: record.evidenceProfile,
                candidateAMove: a.move,
                candidateBMove: b.move,
                candidateAScore: a.engineScore.text,
                candidateBScore: b.engineScore.text,
                comparisonStable: comparison.comparisonStable,
                continuationStable: comparison.continuationStable,
                stableHorizonPly: sequence.stableHorizonPly,
                sequenceStable: sequence.sequenceStable,
                differenceKinds: comparison.differenceEvidence.map { $0.kind.rawValue },
                dominantDifferenceKind: comparison.dominantDifferenceCandidate?.kind.rawValue,
                usedEvidenceIDs: semantic.usedEvidenceIDs,
                usedEvidenceKinds: usedKinds,
                withheldEvidenceIDs: semantic.withheldEvidenceIDs,
                comparisonConfidence: confidence.level.rawValue,
                wordingStrength: confidence.wordingStrength.rawValue,
                tone: semantic.tone.rawValue,
                headline: semantic.headline,
                primaryReason: semantic.primaryReason,
                alternativeOutcome: semantic.alternativeOutcome,
                differenceTiming: semantic.differenceTiming,
                opponentOpportunity: semantic.opponentOpportunity,
                exchangeAfter: semantic.exchangeAfter,
                confidenceNote: semantic.confidenceNote,
                sections: sections,
                causalSectionCount: sections.filter(\.causalWordingUsed).count,
                presentationMode: presentationMode,
                presentationRunLength: presentationRunLength,
                presentationResetReasons: presentationResetReasons,
                displayedHeadline: displayedHeadline,
                displayedPrimaryReason: displayedPrimaryReason,
                warnings: Array(Set(semantic.warnings + confidence.warnings + sequence.warnings)).sorted()
            )
        )
    }

    func count(_ key: (OutputRecord) -> String) -> [String: Int] {
        var result: [String: Int] = [:]
        for record in outputs { result[key(record), default: 0] += 1 }
        return result
    }

    let scoreOnlyCausalUsageCount = outputs.filter {
        $0.usedEvidenceKinds.contains(DifferenceKind.scoreDifference.rawValue) && $0.causalSectionCount > 0
    }.count
    let holdTermLeakageCount = outputs.filter {
        let text = [$0.headline, $0.primaryReason, $0.alternativeOutcome ?? "", $0.differenceTiming ?? "", $0.opponentOpportunity ?? "", $0.exchangeAfter ?? ""].joined(separator: " ")
        return holdTerms.contains { text.contains($0) }
    }.count
    let forcedReplyOverclaimCount = outputs.filter {
        let text = [$0.headline, $0.primaryReason, $0.alternativeOutcome ?? "", $0.opponentOpportunity ?? ""].joined(separator: " ")
        return forcedOverclaimTerms.contains { text.contains($0) }
    }.count

    let summary = OutputSummary(
        totalRecords: outputs.count,
        pairKindCounts: count(\.pairKind),
        comparisonStableCount: outputs.filter(\.comparisonStable).count,
        continuationStableCount: outputs.filter(\.continuationStable).count,
        confidenceCounts: count(\.comparisonConfidence),
        wordingStrengthCounts: count(\.wordingStrength),
        toneCounts: count(\.tone),
        presentationModeCounts: outputs.reduce(into: [:]) { partial, record in
            if let mode = record.presentationMode { partial[mode, default: 0] += 1 }
        },
        unresolvedCount: outputs.filter { $0.comparisonConfidence == ComparisonConfidenceLevel.unresolved.rawValue }.count,
        scoreOnlyCausalUsageCount: scoreOnlyCausalUsageCount,
        holdTermLeakageCount: holdTermLeakageCount,
        forcedReplyOverclaimCount: forcedReplyOverclaimCount
    )

    let formatter = ISO8601DateFormatter()
    let document = OutputDocument(
        schemaVersion: 1,
        stage: "Build19-V Independent Real-game / Semantic Validation",
        generatedAtUTC: formatter.string(from: Date()),
        requirementRecordCount: input.requirementRecordCount,
        continuityRecordCount: input.continuityRecordCount,
        summary: summary,
        records: outputs
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let encoded = try encoder.encode(document)
    try encoded.write(to: URL(fileURLWithPath: outputPath))

    print("BUILD19_V_CORE_PROJECTION_PASS records=\(outputs.count)")
    print("requirement_records=\(input.requirementRecordCount)")
    print("continuity_records=\(input.continuityRecordCount)")
    print("confidence_counts=\(summary.confidenceCounts)")
    print("presentation_modes=\(summary.presentationModeCounts)")
}

try run()
