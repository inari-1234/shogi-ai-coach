import Foundation
import ShogiCoachCore

struct ContextAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let analysis: MoveContextAnalysis
    let suppressedConceptIDs: Set<String>
    let presentation: ContextExplanationPresentation

    init(
        id: Int,
        ply: Int,
        analysis: MoveContextAnalysis,
        suppressedConceptIDs: Set<String> = [],
        presentation: ContextExplanationPresentation? = nil
    ) {
        self.id = id
        self.ply = ply
        self.analysis = analysis
        self.suppressedConceptIDs = suppressedConceptIDs
        if let presentation {
            self.presentation = presentation
        } else {
            var state = ContextExplanationRepetitionState()
            self.presentation = state.present(
                analysis: analysis,
                suppressingConceptIDs: suppressedConceptIDs
            )
        }
    }

    var explanation: ContextMoveExplanation {
        presentation.semanticExplanation
    }

    var presentedExplanation: ContextMoveExplanation? {
        presentation.displayedExplanation
    }
}

@MainActor
final class ContextAnalysisViewModel: ObservableObject {
    static let refinementPolicy = "ve1b-deep-authority-reuse-v2"

    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ContextAnalysisEntry] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?
    @Published private(set) var usedAdditionalEngineSearch = false
    @Published private(set) var refinementCandidatePlies: [Int] = []
    @Published private(set) var refinementCompletedPlies: [Int] = []
    @Published private(set) var refinementConfidenceChangedCount = 0
    @Published private(set) var refinementIntentChangedCount = 0
    @Published private(set) var refinementError: String?
    @Published private(set) var recommendedExplanations: [Int: ContextMoveExplanation] = [:]

    private let engine: MoveContextEngine
    let knowledgeLoadStatus: String
    let knowledgeSourceIDs: [String]
    let knowledgeRecordCount: Int

    init(bundle: Bundle = .main) {
        let knowledge = ContextKnowledgeStore.load(bundle: bundle)
        engine = knowledge.engine
        knowledgeLoadStatus = knowledge.loadStatus
        knowledgeSourceIDs = knowledge.sourceIDs
        knowledgeRecordCount = knowledge.recordCount
    }

    func reset() {
        status = "未解析"
        summary = ""
        entries = []
        diagnosticURL = nil
        diagnosticError = nil
        usedAdditionalEngineSearch = false
        refinementCandidatePlies = []
        refinementCompletedPlies = []
        refinementConfidenceChangedCount = 0
        refinementIntentChangedCount = 0
        refinementError = nil
        recommendedExplanations = [:]
    }

    func prepare(
        game: KIFGame,
        deepEntries: [DeepAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?
    ) async {
        reset()

        guard !game.moves.isEmpty else {
            status = "局面文脈解析 未PASS"
            summary = "解析対象の指し手がありません"
            return
        }
        guard let sourceDiagnosticURL else {
            status = "局面文脈解析 未PASS"
            summary = "診断JSONがありません"
            return
        }

        let deepByPly = Dictionary(uniqueKeysWithValues: deepEntries.map { ($0.ply, $0) })
        let moveByPly = Dictionary(uniqueKeysWithValues: game.moves.map { ($0.ply, $0) })
        var resolved: [ContextAnalysisEntry] = []

        do {
            for move in game.moves {
                let analysis = try engine.analyze(
                    positionCommand: move.positionBefore,
                    move: move.usi,
                    engineEvidence: deepByPly[move.ply].map(Self.engineEvidence)
                )
                resolved.append(
                    ContextAnalysisEntry(id: move.ply, ply: move.ply, analysis: analysis)
                )
            }

            refinementCandidatePlies = Self.refinementCandidates(
                entries: resolved,
                deepByPly: deepByPly
            )

            if !refinementCandidatePlies.isEmpty {
                // DeepAnalysisViewModel has already produced the sole VE1-B engine authority.
                // Re-evaluate the context contract from that evidence; never launch a
                // second movetime search with a competing stability definition.
                refinementCompletedPlies = refinementCandidatePlies
            }

            resolved = Self.applyingConceptRepetitionPolicy(to: resolved)
            usedAdditionalEngineSearch = false

            var recommended: [Int: ContextMoveExplanation] = [:]
            for deep in deepEntries {
                guard let move = moveByPly[deep.ply],
                      let actualEntry = resolved.first(where: { $0.ply == deep.ply }) else {
                    continue
                }

                if deep.bestMove == deep.actualMove {
                    recommended[deep.ply] = actualEntry.explanation
                    continue
                }

                let bestEvidence = MoveContextEngineEvidence(
                    bestMove: deep.bestMove,
                    actualMove: deep.bestMove,
                    comparisonStable: deep.comparisonStable,
                    continuationStable: deep.continuationStable,
                    bestPV: deep.confirmedBestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
                    actualPV: deep.confirmedBestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
                    actualLossCp: 0,
                    actualMate: Self.isPositiveMate(deep.bestScoreText)
                )
                let bestAnalysis = try engine.analyze(
                    positionCommand: move.positionBefore,
                    move: deep.bestMove,
                    engineEvidence: bestEvidence
                )
                recommended[deep.ply] = ContextExplanationGenerator.make(analysis: bestAnalysis)
            }
            recommendedExplanations = recommended

            let high = resolved.filter { $0.analysis.confidence == .high }.count
            let medium = resolved.filter { $0.analysis.confidence == .medium }.count
            let low = resolved.filter { $0.analysis.confidence == .low }.count
            let unresolved = resolved.filter { $0.analysis.confidence == .unresolved }.count
            let knowledgeMatchedPositions = resolved.filter { entry in
                entry.analysis.evidence.contains {
                    $0.kind == .openingBook || $0.kind == .precedent
                }
            }.count

            let diagnostic = ShogiDiagnosticDocument.ContextAnalysisInfo(
                status: "局面文脈解析 PASS",
                usedAdditionalEngineSearch: usedAdditionalEngineSearch,
                expectedPositions: game.moves.count,
                completedPositions: resolved.count,
                positions: resolved.map {
                    .init(
                        ply: $0.ply,
                        analysis: $0.analysis,
                        explanation: $0.explanation,
                        presentationMode: $0.presentation.mode,
                        presentedExplanation: $0.presentedExplanation,
                        explanationWhyNowSuppressedAsRepeatedGeneric: $0.presentation.whyNowSuppressedAsRepeatedGeneric,
                        explanationEquivalentRunLength: $0.presentation.equivalentRunLength,
                        explanationResetReasons: $0.presentation.resetReasons,
                        recommendedMove: deepByPly[$0.ply]?.bestMove,
                        recommendedExplanation: recommended[$0.ply]
                    )
                },
                knowledgeLoadStatus: knowledgeLoadStatus,
                knowledgeSourceIDs: knowledgeSourceIDs,
                knowledgeRecordCount: knowledgeRecordCount,
                knowledgeMatchedPositions: knowledgeMatchedPositions,
                refinementPolicy: Self.refinementPolicy,
                refinementCandidatePlies: refinementCandidatePlies,
                refinementCompletedPlies: refinementCompletedPlies,
                refinementConfidenceChangedCount: refinementConfidenceChangedCount,
                refinementIntentChangedCount: refinementIntentChangedCount,
                refinementUnresolvedAfterCount: unresolved,
                refinementError: refinementError,
                error: nil
            )
            let outputURL = try DiagnosticExporter.augmentWithContextAnalysis(
                url: sourceDiagnosticURL,
                contextAnalysis: diagnostic
            )

            entries = resolved.sorted { $0.ply < $1.ply }
            diagnosticURL = outputURL
            status = "局面文脈解析 PASS"
            let refinementText = refinementCandidatePlies.isEmpty
                ? "VE1-B証拠再利用対象なし"
                : "VE1-B証拠再利用 \(refinementCompletedPlies.count)/\(refinementCandidatePlies.count)"
            summary = [
                "全\(resolved.count)局面",
                "HIGH \(high)",
                "MEDIUM \(medium)",
                "LOW \(low)",
                "UNRESOLVED \(unresolved)",
                refinementText,
                "推奨手説明 \(recommended.count)/\(deepEntries.count)"
            ].joined(separator: " / ")
        } catch {
            entries = resolved.sorted { $0.ply < $1.ply }
            status = "局面文脈解析 未PASS"
            summary = error.localizedDescription
            diagnosticError = error.localizedDescription
        }
    }

    private static func applyingConceptRepetitionPolicy(
        to entries: [ContextAnalysisEntry]
    ) -> [ContextAnalysisEntry] {
        var previousCandidateConceptID: String?
        var repetitionState = ContextExplanationRepetitionState()
        var previousPly: Int?

        return entries.map { entry in
            let unsuppressed = ContextExplanationGenerator.make(analysis: entry.analysis)
            let candidateConceptID = unsuppressed.conceptSupplement?.conceptID
            var suppressed: Set<String> = []

            if let candidateConceptID,
               candidateConceptID == previousCandidateConceptID {
                suppressed.insert(candidateConceptID)
            }

            if let previousPly, entry.ply != previousPly + 1 {
                repetitionState.reset()
            }
            let presentation = repetitionState.present(
                analysis: entry.analysis,
                suppressingConceptIDs: suppressed
            )

            previousCandidateConceptID = candidateConceptID
            previousPly = entry.ply
            return ContextAnalysisEntry(
                id: entry.id,
                ply: entry.ply,
                analysis: entry.analysis,
                suppressedConceptIDs: suppressed,
                presentation: presentation
            )
        }
    }

    private static func refinementCandidates(
        entries: [ContextAnalysisEntry],
        deepByPly: [Int: DeepAnalysisEntry]
    ) -> [Int] {
        entries.compactMap { entry in
            guard entry.analysis.confidence == .low || entry.analysis.confidence == .unresolved,
                  let deep = deepByPly[entry.ply],
                  (!deep.comparisonStable || !deep.continuationStable) else {
                return nil
            }
            return entry.ply
        }.sorted()
    }

    private static func engineEvidence(_ deep: DeepAnalysisEntry) -> MoveContextEngineEvidence {
        MoveContextEngineEvidence(
            bestMove: deep.bestMove,
            actualMove: deep.actualMove,
            comparisonStable: deep.comparisonStable,
            continuationStable: deep.continuationStable,
            bestPV: deep.confirmedBestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
            actualPV: deep.confirmedActualPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
            actualLossCp: deep.actualLossCp,
            actualMate: isPositiveMate(deep.actualScoreText)
        )
    }

    private static func isPositiveMate(_ text: String) -> Bool {
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2,
              parts[0].lowercased() == "mate",
              let value = Int(parts[1]) else { return false }
        return value > 0
    }
}
