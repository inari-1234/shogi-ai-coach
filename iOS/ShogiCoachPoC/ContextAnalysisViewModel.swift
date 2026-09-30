import Foundation
import ShogiCoachCore

@MainActor
final class ContextAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [MoveContextAnalysis] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    func reset() {
        status = "未解析"
        summary = ""
        entries = []
        diagnosticURL = nil
        diagnosticError = nil
    }

    func prepare(
        game: KIFGame,
        deepEntries: [DeepAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?
    ) {
        reset()
        guard let sourceDiagnosticURL else {
            status = "局面文脈 未PASS"
            summary = "診断JSONがありません"
            return
        }

        let deepByPly = Dictionary(uniqueKeysWithValues: deepEntries.map { ($0.ply, $0) })
        var resolved: [MoveContextAnalysis] = []
        resolved.reserveCapacity(game.moves.count)

        do {
            for move in game.moves {
                let engineEvidence = deepByPly[move.ply].map(Self.makeEngineEvidence)
                let analysis = try MoveContextEngine.analyze(
                    positionCommand: move.positionBefore,
                    move: move.usi,
                    knowledgeProvider: nil,
                    engineEvidence: engineEvidence
                )
                resolved.append(analysis)
            }

            entries = resolved
            status = "局面文脈 PASS"
            let high = resolved.filter { $0.confidence == .high }.count
            let medium = resolved.filter { $0.confidence == .medium }.count
            let low = resolved.filter { $0.confidence == .low }.count
            let unresolved = resolved.filter { $0.confidence == .unresolved }.count
            let counterfactual = resolved.filter { $0.engineEvidence?.counterfactual != nil }.count
            summary = [
                "positions: \(resolved.count)/\(game.moves.count)",
                "confidence: HIGH \(high) / MEDIUM \(medium) / LOW \(low) / UNRESOLVED \(unresolved)",
                "counterfactual evidence: \(counterfactual)",
                "model: deterministic-context-v1"
            ].joined(separator: "\n")

            let info = ShogiDiagnosticDocument.ContextAnalysisInfo(
                status: status,
                modelVersion: 1,
                completedPositions: resolved.count,
                positions: resolved,
                error: nil
            )
            diagnosticURL = try DiagnosticExporter.augmentWithContextAnalysis(
                url: sourceDiagnosticURL,
                contextAnalysis: info
            )
            SimulatorStage.mark("context_analysis_complete_\(resolved.count)")
        } catch {
            entries = resolved
            status = "局面文脈 未PASS"
            summary = "completed: \(resolved.count)/\(game.moves.count)\n\(error.localizedDescription)"
            let info = ShogiDiagnosticDocument.ContextAnalysisInfo(
                status: status,
                modelVersion: 1,
                completedPositions: resolved.count,
                positions: resolved,
                error: error.localizedDescription
            )
            do {
                diagnosticURL = try DiagnosticExporter.augmentWithContextAnalysis(
                    url: sourceDiagnosticURL,
                    contextAnalysis: info
                )
            } catch {
                diagnosticError = error.localizedDescription
            }
            SimulatorStage.mark("context_analysis_error_\(error.localizedDescription)")
        }
    }

    private static func makeEngineEvidence(_ deep: DeepAnalysisEntry) -> ContextEngineEvidence {
        var semanticTags: [EngineSemanticTag] = []
        let actualScore = deep.actualScoreText.lowercased()
        if actualScore.hasPrefix("mate ") || actualScore == "mate" {
            semanticTags.append(.forcedMate)
        }

        let counterfactual: ContextCounterfactualEvidence?
        if deep.bestMove != deep.actualMove {
            counterfactual = ContextCounterfactualEvidence(
                alternativeMove: deep.bestMove,
                evaluationDeltaCp: deep.actualLossCp,
                opponentReply: deep.opponentBestReply == "-" ? nil : deep.opponentBestReply,
                stable: deep.comparisonStable,
                tags: []
            )
        } else {
            counterfactual = nil
        }

        return ContextEngineEvidence(
            bestMove: deep.bestMove,
            actualMove: deep.actualMove,
            actualLossCp: deep.actualLossCp,
            comparisonStable: deep.comparisonStable,
            continuationStable: deep.continuationStable,
            bestPV: splitPV(deep.bestPV),
            actualPV: splitPV(deep.actualPV),
            semanticTags: semanticTags,
            counterfactual: counterfactual
        )
    }

    private static func splitPV(_ value: String) -> [String] {
        value.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
}
