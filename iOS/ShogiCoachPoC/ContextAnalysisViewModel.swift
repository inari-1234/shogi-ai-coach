import Foundation
import ShogiCoachCore

struct ContextAnalysisEntry: Identifiable {
    let id: Int
    let ply: Int
    let analysis: MoveContextAnalysis
}

@MainActor
final class ContextAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ContextAnalysisEntry] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    private let engine = MoveContextEngine()

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
        var resolved: [ContextAnalysisEntry] = []

        do {
            for move in game.moves {
                let engineEvidence: MoveContextEngineEvidence?
                if let deep = deepByPly[move.ply] {
                    engineEvidence = MoveContextEngineEvidence(
                        bestMove: deep.bestMove,
                        actualMove: deep.actualMove,
                        comparisonStable: deep.comparisonStable,
                        continuationStable: deep.continuationStable,
                        bestPV: deep.bestPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
                        actualPV: deep.actualPV.split(whereSeparator: { $0.isWhitespace }).map(String.init),
                        actualLossCp: deep.actualLossCp,
                        actualMate: Self.isPositiveMate(deep.actualScoreText)
                    )
                } else {
                    engineEvidence = nil
                }

                let analysis = try engine.analyze(
                    positionCommand: move.positionBefore,
                    move: move.usi,
                    engineEvidence: engineEvidence
                )
                resolved.append(
                    ContextAnalysisEntry(
                        id: move.ply,
                        ply: move.ply,
                        analysis: analysis
                    )
                )
            }

            let high = resolved.filter { $0.analysis.confidence == .high }.count
            let medium = resolved.filter { $0.analysis.confidence == .medium }.count
            let low = resolved.filter { $0.analysis.confidence == .low }.count
            let unresolved = resolved.filter { $0.analysis.confidence == .unresolved }.count

            let diagnostic = ShogiDiagnosticDocument.ContextAnalysisInfo(
                status: "局面文脈解析 PASS",
                usedAdditionalEngineSearch: false,
                expectedPositions: game.moves.count,
                completedPositions: resolved.count,
                positions: resolved.map {
                    .init(ply: $0.ply, analysis: $0.analysis)
                },
                error: nil
            )
            let outputURL = try DiagnosticExporter.augmentWithContextAnalysis(
                url: sourceDiagnosticURL,
                contextAnalysis: diagnostic
            )

            entries = resolved
            diagnosticURL = outputURL
            status = "局面文脈解析 PASS"
            summary = [
                "全\(resolved.count)局面",
                "HIGH \(high)",
                "MEDIUM \(medium)",
                "LOW \(low)",
                "UNRESOLVED \(unresolved)",
                "追加エンジン探索なし"
            ].joined(separator: " / ")
        } catch {
            entries = resolved
            status = "局面文脈解析 未PASS"
            summary = error.localizedDescription
            diagnosticError = error.localizedDescription
        }
    }

    private static func isPositiveMate(_ text: String) -> Bool {
        let parts = text.split(whereSeparator: { $0.isWhitespace })
        guard parts.count >= 2,
              parts[0].lowercased() == "mate",
              let value = Int(parts[1]) else { return false }
        return value > 0
    }
}
