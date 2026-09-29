import Foundation
import ShogiCoachCore

enum ReasonEvidenceLevel: String {
    case engineConfirmed = "engine_confirmed"
    case pvObserved = "pv_observed"
}

struct ReasonFact: Identifiable {
    let id: String
    let level: ReasonEvidenceLevel
    let kind: String
    let text: String
    let evidenceMoves: [String]
}

struct ReasonInterpretation {
    let text: String
    let evidenceFactIDs: [String]
}

struct ReasonAnalysisEntry: Identifiable {
    let id: Int
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
    let facts: [ReasonFact]
    let interpretation: ReasonInterpretation
}

@MainActor
final class ReasonAnalysisViewModel: ObservableObject {
    @Published private(set) var status = "未解析"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ReasonAnalysisEntry] = []
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

        guard !deepEntries.isEmpty else {
            status = "理由解析 未PASS"
            summary = "工程4の重要局面がありません"
            return
        }
        guard let sourceDiagnosticURL else {
            status = "理由解析 未PASS"
            summary = "診断JSONがありません"
            return
        }

        var resolved: [ReasonAnalysisEntry] = []
        var diagnosticPositions: [ShogiDiagnosticDocument.ReasonPositionInfo] = []

        do {
            for deep in deepEntries {
                guard deep.ply >= 1, deep.ply <= game.moves.count else {
                    throw ReasonAnalysisError.invalidPly(deep.ply)
                }
                let kifMove = game.moves[deep.ply - 1]
                let bestPV = deep.bestPV
                let bestMoves = Self.pvMoves(bestPV)
                let actualMoves = Self.pvMoves(deep.actualPV)
                let bestReply = bestMoves.dropFirst().first ?? "-"
                let actualReply = actualMoves.dropFirst().first ?? "-"

                let bestEffect = try MoveEffectResolver.resolve(
                    positionCommand: kifMove.positionBefore,
                    move: deep.bestMove
                )
                let actualEffect = try MoveEffectResolver.resolve(
                    positionCommand: kifMove.positionBefore,
                    move: deep.actualMove
                )
                let bestReplyEffect = try Self.replyEffect(
                    firstMove: deep.bestMove,
                    reply: bestReply,
                    positionCommand: kifMove.positionBefore
                )
                let actualReplyEffect = try Self.replyEffect(
                    firstMove: deep.actualMove,
                    reply: actualReply,
                    positionCommand: kifMove.positionBefore
                )

                var facts: [ReasonFact] = []
                facts.append(
                    .init(
                        id: "p\(deep.ply)-engine-moves",
                        level: .engineConfirmed,
                        kind: "move_comparison",
                        text: deep.bestMove == deep.actualMove
                            ? "実戦手 \(deep.actualMove) はエンジン最善手と一致"
                            : "エンジン最善手は \(deep.bestMove)、実戦手は \(deep.actualMove)",
                        evidenceMoves: [deep.bestMove, deep.actualMove]
                    )
                )

                let scoreText: String
                if !deep.comparisonStable {
                    let reasons = deep.instabilityReasons.isEmpty
                        ? "unknown"
                        : deep.instabilityReasons.joined(separator: ",")
                    scoreText = "最善候補 \(deep.bestScoreText) / 実戦手 \(deep.actualScoreText) / 同条件比較が未安定（\(reasons)）のため評価損失は断定しない"
                } else if let loss = deep.actualLossCp {
                    if loss > 0 {
                        scoreText = "最善手 \(deep.bestScoreText) / 実戦手 \(deep.actualScoreText) / 同条件比較の評価損失 \(loss)cp"
                    } else {
                        scoreText = "最善手 \(deep.bestScoreText) / 実戦手 \(deep.actualScoreText) / 同条件比較で正の評価損失は未確認"
                    }
                } else {
                    scoreText = "最善手 \(deep.bestScoreText) / 実戦手 \(deep.actualScoreText)"
                }
                facts.append(
                    .init(
                        id: "p\(deep.ply)-engine-score",
                        level: .engineConfirmed,
                        kind: "score_comparison",
                        text: scoreText,
                        evidenceMoves: [deep.bestMove, deep.actualMove]
                    )
                )

                if deep.comparisonStable && !deep.continuationStable {
                    let reasons = deep.continuationInstabilityReasons.isEmpty
                        ? "unknown"
                        : deep.continuationInstabilityReasons.joined(separator: ",")
                    facts.append(
                        .init(
                            id: "p\(deep.ply)-continuation-stability",
                            level: .engineConfirmed,
                            kind: "continuation_stability",
                            text: "同条件比較は安定。ただし継続PVは未安定（\(reasons)）のため、長い読み筋は参考扱い",
                            evidenceMoves: [deep.bestMove, deep.actualMove]
                        )
                    )
                }

                facts.append(
                    .init(
                        id: "p\(deep.ply)-best-effect",
                        level: .pvObserved,
                        kind: "best_move_effect",
                        text: "最善手の盤面変化: " + Self.effectText(bestEffect),
                        evidenceMoves: [deep.bestMove]
                    )
                )
                facts.append(
                    .init(
                        id: "p\(deep.ply)-actual-effect",
                        level: .pvObserved,
                        kind: "actual_move_effect",
                        text: "実戦手の盤面変化: " + Self.effectText(actualEffect),
                        evidenceMoves: [deep.actualMove]
                    )
                )

                if bestReply != "-" {
                    facts.append(
                        .init(
                            id: "p\(deep.ply)-best-reply",
                            level: .pvObserved,
                            kind: "best_reply",
                            text: "最善手PVでの相手の最善応手は \(bestReply)"
                                + (bestReplyEffect.map { "（\(Self.effectText($0))）" } ?? ""),
                            evidenceMoves: [deep.bestMove, bestReply]
                        )
                    )
                }
                if actualReply != "-" {
                    facts.append(
                        .init(
                            id: "p\(deep.ply)-actual-reply",
                            level: .pvObserved,
                            kind: "actual_reply",
                            text: "実戦手PVでの相手の最善応手は \(actualReply)"
                                + (actualReplyEffect.map { "（\(Self.effectText($0))）" } ?? ""),
                            evidenceMoves: [deep.actualMove, actualReply]
                        )
                    )
                }

                let interpretation = Self.makeInterpretation(
                    deep: deep,
                    bestEffect: bestEffect,
                    actualEffect: actualEffect,
                    bestReplyEffect: bestReplyEffect,
                    actualReplyEffect: actualReplyEffect,
                    facts: facts
                )

                let entry = ReasonAnalysisEntry(
                    id: deep.ply,
                    ply: deep.ply,
                    actualMove: deep.actualMove,
                    bestMove: deep.bestMove,
                    bestScore: deep.bestScoreText,
                    actualScore: deep.actualScoreText,
                    actualLossCp: deep.actualLossCp,
                    bestPV: bestPV,
                    actualPV: deep.actualPV,
                    bestReply: bestReply,
                    actualReply: actualReply,
                    facts: facts,
                    interpretation: interpretation
                )
                resolved.append(entry)

                diagnosticPositions.append(
                    .init(
                        ply: entry.ply,
                        actualMove: entry.actualMove,
                        bestMove: entry.bestMove,
                        bestScore: entry.bestScore,
                        actualScore: entry.actualScore,
                        actualLossCp: entry.actualLossCp,
                        bestPV: entry.bestPV,
                        actualPV: entry.actualPV,
                        bestReply: entry.bestReply,
                        actualReply: entry.actualReply,
                        facts: entry.facts.map {
                            .init(
                                id: $0.id,
                                level: $0.level.rawValue,
                                kind: $0.kind,
                                text: $0.text,
                                evidenceMoves: $0.evidenceMoves
                            )
                        },
                        interpretation: .init(
                            text: entry.interpretation.text,
                            evidenceFactIDs: entry.interpretation.evidenceFactIDs
                        )
                    )
                )
            }

            entries = resolved
            status = "理由解析 PASS"
            let matched = resolved.filter { $0.actualMove == $0.bestMove }.count
            let withLoss = resolved.compactMap(\.actualLossCp).filter { $0 > 0 }.count
            summary = [
                "important positions: \(resolved.count)/\(deepEntries.count)",
                "bestmove matched: \(matched)/\(resolved.count)",
                "cp loss observed: \(withLoss)",
                "evidence: engine_confirmed + pv_observed",
                "interpretation: evidence-linked candidate only"
            ].joined(separator: "\n")

            let info = ShogiDiagnosticDocument.ReasonAnalysisInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: nil
            )
            diagnosticURL = try DiagnosticExporter.augmentWithReasonAnalysis(
                url: sourceDiagnosticURL,
                reasonAnalysis: info
            )
            SimulatorStage.mark("reason_analysis_complete_\(resolved.count)")
        } catch {
            let message = error.localizedDescription
            entries = resolved
            status = "理由解析 未PASS"
            summary = [
                "completed: \(resolved.count)/\(deepEntries.count)",
                message
            ].joined(separator: "\n")

            let info = ShogiDiagnosticDocument.ReasonAnalysisInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: message
            )
            do {
                diagnosticURL = try DiagnosticExporter.augmentWithReasonAnalysis(
                    url: sourceDiagnosticURL,
                    reasonAnalysis: info
                )
            } catch {
                diagnosticError = error.localizedDescription
            }
            SimulatorStage.mark("reason_analysis_error_\(message)")
        }
    }

    private static func pvMoves(_ pv: String) -> [String] {
        pv.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }

    private static func replyEffect(
        firstMove: String,
        reply: String,
        positionCommand: String
    ) throws -> MoveEffect? {
        guard reply != "-" else { return nil }
        let afterFirst = try MoveEffectResolver.appending(
            move: firstMove,
            to: positionCommand
        )
        return try MoveEffectResolver.resolve(
            positionCommand: afterFirst,
            move: reply
        )
    }

    private static func effectText(_ effect: MoveEffect) -> String {
        var pieces: [String] = []
        if effect.isDrop {
            pieces.append("\(effect.pieceBefore.kanji)を\(effect.destination.usi)へ打つ")
        } else {
            pieces.append(
                "\(effect.pieceBefore.kanji)を\(effect.source?.usi ?? "-")→\(effect.destination.usi)"
            )
        }
        if let captured = effect.capturedPiece {
            pieces.append("\(captured.kanji)を取る")
        }
        if effect.promotes {
            pieces.append("\(effect.pieceAfter.kanji)に成る")
        }
        return pieces.joined(separator: "、")
    }

    private static func makeInterpretation(
        deep: DeepAnalysisEntry,
        bestEffect: MoveEffect,
        actualEffect: MoveEffect,
        bestReplyEffect: MoveEffect?,
        actualReplyEffect: MoveEffect?,
        facts: [ReasonFact]
    ) -> ReasonInterpretation {
        let moveFact = "p\(deep.ply)-engine-moves"
        let scoreFact = "p\(deep.ply)-engine-score"
        let bestEffectFact = "p\(deep.ply)-best-effect"
        let actualReplyFact = "p\(deep.ply)-actual-reply"
        let continuationFact = "p\(deep.ply)-continuation-stability"

        if deep.actualMove == deep.bestMove {
            return .init(
                text: "実戦手は最善手と一致しています。この解析結果からは、この手自体を評価低下の原因とは扱いません。",
                evidenceFactIDs: [moveFact, scoreFact]
            )
        }

        if !deep.comparisonStable {
            return .init(
                text: "最善候補と実戦手は同じ探索条件で比較しましたが、再解析後も評価順序または評価差が安定していません。この局面では評価損失や失敗理由を断定せず、比較判定を保留します。",
                evidenceFactIDs: [moveFact, scoreFact]
            )
        }

        if deep.bestScoreText.hasPrefix("mate "),
           !deep.actualScoreText.hasPrefix("mate ") {
            return .init(
                text: "最善手では詰みが確認されていますが、実戦手では同じ詰み評価が確認されていません。詰みを逃したことが評価差の理由候補です。",
                evidenceFactIDs: [moveFact, scoreFact]
            )
        }

        if let loss = deep.actualLossCp, loss <= 0 {
            return .init(
                text: "候補手と実戦手の盤面変化は異なりますが、同条件比較では正の評価損失を確認できていません。探索では評価順序が接近することがあるため、この局面では成り・駒取りなどの違いを評価低下の原因とは扱いません。",
                evidenceFactIDs: [moveFact, scoreFact]
            )
        }

        if !deep.continuationStable {
            let reasons = deep.continuationInstabilityReasons.isEmpty
                ? "unknown"
                : deep.continuationInstabilityReasons.joined(separator: ",")
            let prefix = deep.actualLossCp.map {
                "同条件比較では\($0)cpの評価差を確認できます。"
            } ?? "同条件比較自体は安定しています。"
            return .init(
                text: prefix + " ただし、その後の読み筋は安定していません（\(reasons)）。このため、駒取りや成りなど一つの盤面イベントだけを評価差の原因とは断定しません。",
                evidenceFactIDs: [moveFact, scoreFact, continuationFact]
            )
        }

        if let captured = bestEffect.capturedPiece,
           actualEffect.capturedPiece == nil {
            let isImmediatelyRecaptured = bestReplyEffect?.destination == bestEffect.destination
                && bestReplyEffect?.capturedPiece == bestEffect.pieceAfter
            if isImmediatelyRecaptured {
                let bestReplyFact = "p\(deep.ply)-best-reply"
                return .init(
                    text: "最善手では直ちに\(captured.kanji)を取りますが、PVではその直後に動かした\(bestEffect.pieceAfter.kanji)が取り返されます。単純な駒取りの得だけでは評価差を説明できないため、この交換を含む読み筋全体の差として扱います。",
                    evidenceFactIDs: [scoreFact, bestEffectFact, bestReplyFact]
                )
            }
            return .init(
                text: "最善手では直ちに\(captured.kanji)を取れますが、実戦手ではその即時の駒取りがありません。この機会を逃したことが評価差の理由候補です。",
                evidenceFactIDs: [scoreFact, bestEffectFact]
            )
        }

        if bestEffect.promotes && !actualEffect.promotes {
            return .init(
                text: "最善手では成りが発生しますが、実戦手では発生しません。成りによる駒の働きの差が評価差の理由候補です。",
                evidenceFactIDs: [scoreFact, bestEffectFact]
            )
        }

        if let captured = actualReplyEffect?.capturedPiece,
           bestReplyEffect?.capturedPiece != captured {
            return .init(
                text: "実戦手後のPVでは相手の最善応手で\(captured.kanji)を取られます。最善手側の直後PVとは異なるため、この駒取りを許すことが評価差の理由候補です。",
                evidenceFactIDs: [scoreFact, actualReplyFact]
            )
        }

        if let loss = deep.actualLossCp, loss > 0 {
            return .init(
                text: "エンジン評価では\(loss)cpの差があります。ただし短いPVと即時の盤面変化だけでは、単一の戦術的理由までは断定できません。候補手と実戦手で読み筋が分岐したことまでを確認事実とします。",
                evidenceFactIDs: facts.map(\.id)
            )
        }

        return .init(
            text: "候補手と実戦手の読み筋は比較できますが、このデータだけでは評価差の理由を断定しません。",
            evidenceFactIDs: facts.map(\.id)
        )
    }
}

enum ReasonAnalysisError: Error, LocalizedError {
    case invalidPly(Int)

    var errorDescription: String? {
        switch self {
        case .invalidPly(let ply):
            return "\(ply)手目が棋譜範囲外です"
        }
    }
}
