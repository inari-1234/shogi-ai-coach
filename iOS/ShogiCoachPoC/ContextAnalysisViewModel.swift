import Foundation
import ShogiCoachCore

struct ContextAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let analysis: MoveContextAnalysis
    let suppressedConceptIDs: Set<String>

    init(
        id: Int,
        ply: Int,
        analysis: MoveContextAnalysis,
        suppressedConceptIDs: Set<String> = []
    ) {
        self.id = id
        self.ply = ply
        self.analysis = analysis
        self.suppressedConceptIDs = suppressedConceptIDs
    }

    var explanation: ContextMoveExplanation {
        ContextExplanationGenerator.make(
            analysis: analysis,
            suppressingConceptIDs: suppressedConceptIDs
        )
    }
}

@MainActor
final class ContextAnalysisViewModel: ObservableObject {
    static let refinementPolicy = "selective-low-unresolved-v1"

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
    private let refinementSession = EngineUSISession()
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
                do {
                    try await refinementSession.beginAnalysis(multiPV: 4)
                    for ply in refinementCandidatePlies {
                        guard let move = moveByPly[ply],
                              let deep = deepByPly[ply],
                              let index = resolved.firstIndex(where: { $0.ply == ply }) else {
                            continue
                        }

                        let initial = resolved[index].analysis
                        let baseMs = deep.finalMovetimeMs < 1600 ? 1600 : 2400
                        let comparison = try await AdaptiveComparisonAnalyzer.analyze(
                            session: refinementSession,
                            command: move.positionBefore,
                            actualMove: move.usi,
                            baseMovetimeMs: baseMs,
                            candidateCount: max(4, deep.candidates.count)
                        )
                        let final = comparison.finalAttempt
                        let refinedEvidence = MoveContextEngineEvidence(
                            bestMove: final.bestLine.move,
                            actualMove: move.usi,
                            comparisonStable: comparison.comparisonStable,
                            continuationStable: comparison.continuationStable,
                            bestPV: final.bestLine.pvMoves,
                            actualPV: final.actualLine.pvMoves,
                            actualLossCp: comparison.comparisonStable ? final.lossCp : nil,
                            actualMate: Self.isPositiveMate(final.actualLine.scoreText)
                        )
                        let refined = try engine.analyze(
                            positionCommand: move.positionBefore,
                            move: move.usi,
                            engineEvidence: refinedEvidence
                        )

                        if refined.confidence != initial.confidence {
                            refinementConfidenceChangedCount += 1
                        }
                        if refined.selectedIntent != initial.selectedIntent {
                            refinementIntentChangedCount += 1
                        }
                        resolved[index] = ContextAnalysisEntry(id: ply, ply: ply, analysis: refined)
                        refinementCompletedPlies.append(ply)

                        if final.thermalAfter == "critical" {
                            throw EngineUSISession.ProbeError.protocolError(
                                "context refinement thermal critical at ply \(ply)"
                            )
                        }
                    }
                    await refinementSession.endAnalysis()
                } catch {
                    await refinementSession.endAnalysis()
                    refinementError = error.localizedDescription
                }
            }

            resolved = Self.applyingConceptRepetitionPolicy(to: resolved)
            usedAdditionalEngineSearch = !refinementCompletedPlies.isEmpty

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
                    bestPV: deep.bestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
                    actualPV: deep.bestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
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
                ? "追加探索対象なし"
                : "追加探索 \(refinementCompletedPlies.count)/\(refinementCandidatePlies.count)"
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
            await refinementSession.endAnalysis()
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

        return entries.map { entry in
            let unsuppressed = ContextExplanationGenerator.make(analysis: entry.analysis)
            let candidateConceptID = unsuppressed.conceptSupplement?.conceptID
            var suppressed: Set<String> = []

            if let candidateConceptID,
               candidateConceptID == previousCandidateConceptID {
                suppressed.insert(candidateConceptID)
            }

            previousCandidateConceptID = candidateConceptID
            return ContextAnalysisEntry(
                id: entry.id,
                ply: entry.ply,
                analysis: entry.analysis,
                suppressedConceptIDs: suppressed
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
                  !deep.comparisonStable
                    || !deep.continuationStable
                    || deep.finalMovetimeMs < 2400 else {
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
            bestPV: deep.bestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
            actualPV: deep.actualPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
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
