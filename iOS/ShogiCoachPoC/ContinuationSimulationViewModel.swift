import Foundation
import ShogiCoachCore

enum ContinuationRouteKind: String, Codable, CaseIterable, Hashable {
    case recommended
    case actual

    var title: String {
        switch self {
        case .recommended: return "推奨"
        case .actual: return "実戦"
        }
    }
}

struct ContinuationMoveStep: Identifiable {
    let id: Int
    let index: Int
    let usi: String
    let side: ShogiSide
    let snapshotBefore: BoardSnapshot
    let snapshotAfter: BoardSnapshot
    let effect: MoveEffect
    let givesCheck: Bool
    let label: String
    let coachText: String
}

struct ContinuationDevelopmentBlock: Identifiable {
    let id: Int
    let startIndex: Int
    let endIndex: Int
    let title: String
    let summary: String
}

struct ContinuationRoute {
    let kind: ContinuationRouteKind
    let scoreText: String
    let stable: Bool
    let initialSnapshot: BoardSnapshot
    let moves: [ContinuationMoveStep]
    let developmentBlocks: [ContinuationDevelopmentBlock]
    let targetShapeSummary: String
}

struct ContinuationSimulationEntry: Identifiable {
    let id: Int
    let ply: Int
    let orientation: ShogiSide
    let comparisonStable: Bool
    let continuationStable: Bool
    let actualLossCp: Int?
    let recommended: ContinuationRoute
    let actual: ContinuationRoute
    let reasonSummary: String
}

@MainActor
final class ContinuationSimulationViewModel: ObservableObject {
    @Published private(set) var status = "未準備"
    @Published private(set) var summary = ""
    @Published private(set) var entries: [ContinuationSimulationEntry] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    func reset() {
        status = "未準備"
        summary = ""
        entries = []
        diagnosticURL = nil
        diagnosticError = nil
    }

    func prepare(
        game: KIFGame,
        deepEntries: [DeepAnalysisEntry],
        reasonEntries: [ReasonAnalysisEntry],
        diagnosticURL sourceDiagnosticURL: URL?
    ) {
        reset()

        guard !deepEntries.isEmpty else {
            status = "展開シミュレーション 未PASS"
            summary = "重要局面がありません"
            return
        }
        guard let sourceDiagnosticURL else {
            status = "展開シミュレーション 未PASS"
            summary = "理由解析後の診断JSONがありません"
            return
        }

        let reasonByPly = Dictionary(uniqueKeysWithValues: reasonEntries.map { ($0.ply, $0) })
        let orientation = Self.userOrientation(game: game)
        var resolved: [ContinuationSimulationEntry] = []
        var diagnosticPositions: [ShogiDiagnosticDocument.ContinuationPositionInfo] = []

        do {
            for deep in deepEntries {
                guard deep.ply >= 1, deep.ply <= game.moves.count else {
                    throw ContinuationSimulationError.invalidPly(deep.ply)
                }
                let kifMove = game.moves[deep.ply - 1]
                let initialSnapshot = try BoardSnapshotResolver.resolve(
                    positionCommand: kifMove.positionBefore
                )

                let recommendedMoves = try Self.normalizedPVMoves(
                    pv: deep.bestPV,
                    expectedFirstMove: deep.bestMove,
                    scoreText: deep.bestScoreText
                )
                let actualMoves = try Self.normalizedPVMoves(
                    pv: deep.actualPV,
                    expectedFirstMove: deep.actualMove,
                    scoreText: deep.actualScoreText
                )

                let recommended = try Self.makeRoute(
                    kind: .recommended,
                    scoreText: deep.bestScoreText,
                    stable: deep.continuationStable,
                    initialPositionCommand: kifMove.positionBefore,
                    initialSnapshot: initialSnapshot,
                    moves: recommendedMoves,
                    userSide: orientation
                )
                let actual = try Self.makeRoute(
                    kind: .actual,
                    scoreText: deep.actualScoreText,
                    stable: deep.continuationStable,
                    initialPositionCommand: kifMove.positionBefore,
                    initialSnapshot: initialSnapshot,
                    moves: actualMoves,
                    userSide: orientation
                )

                let reasonSummary = reasonByPly[deep.ply]?.interpretation.text
                    ?? "この局面はエンジンPVを盤面で比較します。"

                let entry = ContinuationSimulationEntry(
                    id: deep.ply,
                    ply: deep.ply,
                    orientation: orientation,
                    comparisonStable: deep.comparisonStable,
                    continuationStable: deep.continuationStable,
                    actualLossCp: deep.actualLossCp,
                    recommended: recommended,
                    actual: actual,
                    reasonSummary: reasonSummary
                )
                resolved.append(entry)

                diagnosticPositions.append(
                    .init(
                        ply: deep.ply,
                        comparisonStable: deep.comparisonStable,
                        continuationStable: deep.continuationStable,
                        actualLossCp: deep.actualLossCp,
                        recommended: Self.diagnosticRoute(recommended),
                        actual: Self.diagnosticRoute(actual),
                        reasonSummary: reasonSummary
                    )
                )
            }

            entries = resolved
            status = "展開シミュレーション PASS"
            let stableComparisonCount = resolved.filter(\.comparisonStable).count
            let stableContinuationCount = resolved.filter(\.continuationStable).count
            let recommendedPlies = resolved.reduce(0) { $0 + $1.recommended.moves.count }
            let actualPlies = resolved.reduce(0) { $0 + $1.actual.moves.count }
            summary = [
                "important positions: \(resolved.count)/\(deepEntries.count)",
                "stable comparisons: \(stableComparisonCount)/\(resolved.count)",
                "stable continuations: \(stableContinuationCount)/\(resolved.count)",
                "recommended continuation plies: \(recommendedPlies)",
                "actual continuation plies: \(actualPlies)",
                "target shape: PV-derived only"
            ].joined(separator: "\n")

            let info = ShogiDiagnosticDocument.ContinuationSimulationInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: nil
            )
            diagnosticURL = try DiagnosticExporter.augmentWithContinuationSimulation(
                url: sourceDiagnosticURL,
                continuationSimulation: info
            )
            SimulatorStage.mark("continuation_simulation_complete_\(resolved.count)")
        } catch {
            let message = error.localizedDescription
            entries = resolved
            status = "展開シミュレーション 未PASS"
            summary = [
                "completed: \(resolved.count)/\(deepEntries.count)",
                message
            ].joined(separator: "\n")

            let info = ShogiDiagnosticDocument.ContinuationSimulationInfo(
                status: status,
                expectedPositions: deepEntries.count,
                completedPositions: resolved.count,
                positions: diagnosticPositions,
                error: message
            )
            do {
                diagnosticURL = try DiagnosticExporter.augmentWithContinuationSimulation(
                    url: sourceDiagnosticURL,
                    continuationSimulation: info
                )
            } catch {
                diagnosticError = error.localizedDescription
            }
            SimulatorStage.mark("continuation_simulation_error_\(message)")
        }
    }

    private static func normalizedPVMoves(
        pv: String,
        expectedFirstMove: String,
        scoreText: String
    ) throws -> [String] {
        let parsed = pv.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let first = parsed.first else {
            throw ContinuationSimulationError.emptyPV(expectedFirstMove)
        }
        guard first == expectedFirstMove else {
            throw ContinuationSimulationError.pvFirstMoveMismatch(
                expected: expectedFirstMove,
                actual: first
            )
        }

        let limit = scoreText.hasPrefix("mate ") ? 16 : 10
        return Array(parsed.prefix(limit))
    }

    private static func makeRoute(
        kind: ContinuationRouteKind,
        scoreText: String,
        stable: Bool,
        initialPositionCommand: String,
        initialSnapshot: BoardSnapshot,
        moves: [String],
        userSide: ShogiSide
    ) throws -> ContinuationRoute {
        var command = initialPositionCommand
        var currentSnapshot = initialSnapshot
        var steps: [ContinuationMoveStep] = []

        for (zeroBased, move) in moves.enumerated() {
            let effect = try MoveEffectResolver.resolve(
                positionCommand: command,
                move: move
            )
            let nextCommand = try MoveEffectResolver.appending(move: move, to: command)
            let nextSnapshot = try BoardSnapshotResolver.resolve(positionCommand: nextCommand)
            let givesCheck = Self.isKingInCheck(
                snapshot: nextSnapshot,
                checkedSide: Self.opponent(of: effect.side)
            )
            let label = Self.eventLabel(effect: effect, givesCheck: givesCheck)
            let coachText = Self.coachText(
                effect: effect,
                givesCheck: givesCheck,
                routeKind: kind
            )

            steps.append(
                ContinuationMoveStep(
                    id: zeroBased + 1,
                    index: zeroBased + 1,
                    usi: move,
                    side: effect.side,
                    snapshotBefore: currentSnapshot,
                    snapshotAfter: nextSnapshot,
                    effect: effect,
                    givesCheck: givesCheck,
                    label: label,
                    coachText: coachText
                )
            )
            command = nextCommand
            currentSnapshot = nextSnapshot
        }

        let blocks = Self.makeDevelopmentBlocks(steps)
        let targetShape = Self.makeTargetShapeSummary(
            routeKind: kind,
            initial: initialSnapshot,
            final: currentSnapshot,
            moves: steps,
            userSide: userSide
        )

        return ContinuationRoute(
            kind: kind,
            scoreText: scoreText,
            stable: stable,
            initialSnapshot: initialSnapshot,
            moves: steps,
            developmentBlocks: blocks,
            targetShapeSummary: targetShape
        )
    }

    private static func makeDevelopmentBlocks(
        _ moves: [ContinuationMoveStep]
    ) -> [ContinuationDevelopmentBlock] {
        guard !moves.isEmpty else { return [] }
        var result: [ContinuationDevelopmentBlock] = []
        var start = 0
        while start < moves.count {
            let end = min(start + 1, moves.count - 1)
            let slice = Array(moves[start...end])
            let title = slice.count == 1
                ? "\(slice[0].index)手目"
                : "\(slice[0].index)〜\(slice[slice.count - 1].index)手目"
            let summary = slice.map { step in
                let actor = step.side == .black ? "先手" : "後手"
                return "\(actor) \(step.label)"
            }.joined(separator: " → ")
            result.append(
                .init(
                    id: result.count + 1,
                    startIndex: slice[0].index,
                    endIndex: slice[slice.count - 1].index,
                    title: title,
                    summary: summary
                )
            )
            start = end + 1
        }
        return result
    }

    private static func makeTargetShapeSummary(
        routeKind: ContinuationRouteKind,
        initial: BoardSnapshot,
        final: BoardSnapshot,
        moves: [ContinuationMoveStep],
        userSide: ShogiSide
    ) -> String {
        let kingSquare = final.squares.first {
            $0.value.side == userSide && $0.value.kind == .king
        }?.key
        let initialKingSquare = initial.squares.first {
            $0.value.side == userSide && $0.value.kind == .king
        }?.key
        let captures = moves.filter { $0.effect.capturedPiece != nil }.count
        let drops = moves.filter { $0.effect.isDrop }.count
        let promotions = moves.filter { $0.effect.promotes }.count
        let checks = moves.filter(\.givesCheck).count

        var parts: [String] = []
        if let kingSquare {
            if kingSquare != initialKingSquare {
                parts.append("PV終点で自玉は\(kingSquare.usi)")
            } else {
                parts.append("PV終点まで自玉は\(kingSquare.usi)を維持")
            }
        }
        if captures > 0 { parts.append("駒取り\(captures)回") }
        if drops > 0 { parts.append("駒打ち\(drops)回") }
        if promotions > 0 { parts.append("成り\(promotions)回") }
        if checks > 0 { parts.append("王手\(checks)回") }
        if parts.isEmpty {
            parts.append("PV終点まで大きなイベントなし")
        }

        let prefix = routeKind == .recommended ? "推奨PVの到達形" : "実戦PVの到達形"
        return prefix + "： " + parts.joined(separator: "、") + "。"
    }

    private static func eventLabel(
        effect: MoveEffect,
        givesCheck: Bool
    ) -> String {
        var label: String
        if effect.isDrop {
            label = "\(effect.pieceBefore.kanji)打 \(effect.destination.usi)"
        } else if let captured = effect.capturedPiece {
            label = "\(effect.pieceBefore.kanji)で\(captured.kanji)を取る \(effect.destination.usi)"
        } else if effect.pieceBefore == .king {
            label = "玉を\(effect.destination.usi)へ"
        } else {
            label = "\(effect.pieceBefore.kanji) \(effect.destination.usi)へ"
        }

        if effect.promotes {
            label += "・\(effect.pieceAfter.kanji)に成る"
        }
        if givesCheck {
            label += "・王手"
        }
        return label
    }

    private static func coachText(
        effect: MoveEffect,
        givesCheck: Bool,
        routeKind: ContinuationRouteKind
    ) -> String {
        let route = routeKind == .recommended ? "推奨ルート" : "実戦ルート"
        var facts: [String] = []

        if effect.isDrop {
            facts.append("持駒の\(effect.pieceBefore.kanji)を\(effect.destination.usi)へ打ちます")
        } else {
            facts.append("\(effect.pieceBefore.kanji)を\(effect.source?.usi ?? "-")から\(effect.destination.usi)へ動かします")
        }
        if let captured = effect.capturedPiece {
            facts.append("\(captured.kanji)を取ります")
        }
        if effect.promotes {
            facts.append("\(effect.pieceAfter.kanji)に成ります")
        }
        if givesCheck {
            facts.append("相手玉への王手です")
        }

        return route + "： " + facts.joined(separator: "。") + "。"
    }

    private static func diagnosticRoute(
        _ route: ContinuationRoute
    ) -> ShogiDiagnosticDocument.ContinuationRouteInfo {
        .init(
            kind: route.kind.rawValue,
            score: route.scoreText,
            stable: route.stable,
            moves: route.moves.map {
                .init(
                    index: $0.index,
                    usi: $0.usi,
                    side: $0.side.rawValue,
                    source: $0.effect.source?.usi,
                    destination: $0.effect.destination.usi,
                    piece: $0.effect.pieceBefore.kanji,
                    capturedPiece: $0.effect.capturedPiece?.kanji,
                    isDrop: $0.effect.isDrop,
                    promotes: $0.effect.promotes,
                    givesCheck: $0.givesCheck,
                    label: $0.label,
                    coachText: $0.coachText
                )
            },
            developmentBlocks: route.developmentBlocks.map {
                .init(
                    startIndex: $0.startIndex,
                    endIndex: $0.endIndex,
                    title: $0.title,
                    summary: $0.summary
                )
            },
            targetShapeSummary: route.targetShapeSummary
        )
    }

    private static func userOrientation(game: KIFGame) -> ShogiSide {
        let sente = game.metadata["先手"] ?? ""
        let gote = game.metadata["後手"] ?? ""
        if gote.contains("あなた"), !sente.contains("あなた") {
            return .white
        }
        return .black
    }

    private static func opponent(of side: ShogiSide) -> ShogiSide {
        side == .black ? .white : .black
    }

    private static func isKingInCheck(
        snapshot: BoardSnapshot,
        checkedSide: ShogiSide
    ) -> Bool {
        guard let king = snapshot.squares.first(where: {
            $0.value.side == checkedSide && $0.value.kind == .king
        })?.key else {
            return false
        }

        let attacker = opponent(of: checkedSide)
        return snapshot.squares.contains { coordinate, piece in
            guard piece.side == attacker else { return false }
            return attacks(
                from: coordinate,
                piece: piece,
                target: king,
                snapshot: snapshot
            )
        }
    }

    private static func attacks(
        from source: BoardCoordinate,
        piece: BoardPieceState,
        target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let df = target.file - source.file
        let dr = target.rank - source.rank
        let forward = piece.side == .black ? -1 : 1

        switch piece.kind {
        case .pawn:
            return df == 0 && dr == forward
        case .lance:
            guard df == 0, dr * forward > 0 else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .knight:
            return abs(df) == 1 && dr == 2 * forward
        case .silver:
            return (abs(df) == 1 && dr == forward)
                || (abs(df) == 1 && dr == -forward)
                || (df == 0 && dr == forward)
        case .gold, .promotedPawn, .promotedLance, .promotedKnight, .promotedSilver:
            return (dr == forward && abs(df) <= 1)
                || (dr == 0 && abs(df) == 1)
                || (df == 0 && dr == -forward)
        case .bishop:
            guard abs(df) == abs(dr), df != 0 else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .rook:
            guard (df == 0) != (dr == 0) else { return false }
            return clearLine(from: source, to: target, snapshot: snapshot)
        case .king:
            return max(abs(df), abs(dr)) == 1
        case .horse:
            if abs(df) == abs(dr), df != 0 {
                return clearLine(from: source, to: target, snapshot: snapshot)
            }
            return (abs(df) + abs(dr) == 1)
        case .dragon:
            if (df == 0) != (dr == 0) {
                return clearLine(from: source, to: target, snapshot: snapshot)
            }
            return abs(df) == 1 && abs(dr) == 1
        }
    }

    private static func clearLine(
        from source: BoardCoordinate,
        to target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let stepFile = target.file == source.file ? 0 : (target.file > source.file ? 1 : -1)
        let stepRank = target.rank == source.rank ? 0 : (target.rank > source.rank ? 1 : -1)

        var file = source.file + stepFile
        var rank = source.rank + stepRank
        while file != target.file || rank != target.rank {
            if snapshot.piece(at: BoardCoordinate(file: file, rank: rank)) != nil {
                return false
            }
            file += stepFile
            rank += stepRank
        }
        return true
    }
}

enum ContinuationSimulationError: Error, LocalizedError {
    case invalidPly(Int)
    case emptyPV(String)
    case pvFirstMoveMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .invalidPly(let ply):
            return "\(ply)手目が棋譜範囲外です"
        case .emptyPV(let move):
            return "\(move) から始まるPVが空です"
        case .pvFirstMoveMismatch(let expected, let actual):
            return "PV先頭が不一致です（期待 \(expected)、実際 \(actual)）"
        }
    }
}
