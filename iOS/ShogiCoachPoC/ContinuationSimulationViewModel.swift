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
    let factText: String
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
    let summary: String
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

                let reasonSummary = reasonByPly[deep.ply]?.interpretation.text
                    ?? "この局面はエンジンPVを盤面で比較します。"
                let recommendedMoves = try Self.normalizedPVMoves(
                    pv: deep.confirmedBestPV,
                    expectedFirstMove: deep.bestMove,
                    scoreText: deep.bestScoreText,
                    allowEmptyWhenUnconfirmed: !deep.continuationStable
                )
                let actualMoves = try Self.normalizedPVMoves(
                    pv: deep.confirmedActualPV,
                    expectedFirstMove: deep.actualMove,
                    scoreText: deep.actualScoreText,
                    allowEmptyWhenUnconfirmed: !deep.continuationStable
                )

                let recommended = try Self.makeRoute(
                    kind: .recommended,
                    scoreText: deep.bestScoreText,
                    stable: deep.continuationStable,
                    initialPositionCommand: kifMove.positionBefore,
                    initialSnapshot: initialSnapshot,
                    moves: recommendedMoves,
                    userSide: orientation,
                    comparisonStable: deep.comparisonStable,
                    actualLossCp: deep.actualLossCp,
                    reasonSummary: reasonSummary
                )
                let actual = try Self.makeRoute(
                    kind: .actual,
                    scoreText: deep.actualScoreText,
                    stable: deep.continuationStable,
                    initialPositionCommand: kifMove.positionBefore,
                    initialSnapshot: initialSnapshot,
                    moves: actualMoves,
                    userSide: orientation,
                    comparisonStable: deep.comparisonStable,
                    actualLossCp: deep.actualLossCp,
                    reasonSummary: reasonSummary
                )

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
        scoreText: String,
        allowEmptyWhenUnconfirmed: Bool
    ) throws -> [String] {
        let parsed = pv.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard let first = parsed.first else {
            if allowEmptyWhenUnconfirmed { return [] }
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
        userSide: ShogiSide,
        comparisonStable: Bool,
        actualLossCp: Int?,
        reasonSummary: String
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
            let label = Self.japaneseMoveLabel(effect: effect)
            let factText = Self.factText(
                effect: effect,
                givesCheck: givesCheck,
                userSide: userSide
            )
            let coachText = Self.coachText(
                effect: effect,
                givesCheck: givesCheck,
                userSide: userSide,
                snapshotBefore: currentSnapshot,
                snapshotAfter: nextSnapshot
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
                    factText: factText,
                    coachText: coachText
                )
            )
            command = nextCommand
            currentSnapshot = nextSnapshot
        }

        let blocks = Self.makeDevelopmentBlocks(steps)
        let routeSummary = Self.makeRouteSummary(
            kind: kind,
            initial: initialSnapshot,
            final: currentSnapshot,
            moves: steps,
            userSide: userSide,
            comparisonStable: comparisonStable,
            actualLossCp: actualLossCp,
            reasonSummary: reasonSummary
        )
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
            summary: routeSummary,
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
        guard !moves.isEmpty else {
            return routeKind == .recommended
                ? "推奨側の確認済み読み筋はありません（未確認の参考読み筋は説明に使用しません）。"
                : "実戦側の確認済み読み筋はありません（未確認の参考読み筋は説明に使用しません）。"
        }
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

    private static func japaneseMoveLabel(
        effect: MoveEffect
    ) -> String {
        let marker = effect.side == .black ? "▲" : "△"
        let destination = japaneseCoordinate(effect.destination)
        var suffix = effect.pieceAfter.kanji
        if effect.isDrop {
            suffix += "打"
        } else if effect.promotes {
            suffix += "成"
        }
        return marker + destination + suffix
    }

    private static func japaneseCoordinate(_ coordinate: BoardCoordinate) -> String {
        let files = ["", "１", "２", "３", "４", "５", "６", "７", "８", "９"]
        let ranks = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        guard (1...9).contains(coordinate.file),
              (1...9).contains(coordinate.rank) else {
            return coordinate.usi
        }
        return files[coordinate.file] + ranks[coordinate.rank]
    }

    private static func factText(
        effect: MoveEffect,
        givesCheck: Bool,
        userSide: ShogiSide
    ) -> String {
        let actor = effect.side == userSide ? "あなた側" : "相手側"
        var facts: [String] = []

        if effect.isDrop {
            facts.append("持駒の\(effect.pieceBefore.kanji)を\(japaneseCoordinate(effect.destination))へ打つ")
        } else {
            facts.append("\(effect.pieceBefore.kanji)を\(japaneseCoordinate(effect.destination))へ移動")
        }
        if let captured = effect.capturedPiece {
            facts.append("\(captured.kanji)を取る")
        }
        if effect.promotes {
            facts.append("\(effect.pieceAfter.kanji)に成る")
        }
        if givesCheck {
            facts.append("王手")
        }
        return actor + "： " + facts.joined(separator: "・")
    }

    private static func coachText(
        effect: MoveEffect,
        givesCheck: Bool,
        userSide: ShogiSide,
        snapshotBefore: BoardSnapshot,
        snapshotAfter: BoardSnapshot
    ) -> String {
        let mover = effect.side
        let checkedSide = opponent(of: mover)

        let attackBefore = kingZoneAttackerCount(
            snapshot: snapshotBefore,
            checkedSide: checkedSide
        )
        let attackAfter = kingZoneAttackerCount(
            snapshot: snapshotAfter,
            checkedSide: checkedSide
        )
        let dangerBefore = kingZoneAttackerCount(
            snapshot: snapshotBefore,
            checkedSide: mover
        )
        let dangerAfter = kingZoneAttackerCount(
            snapshot: snapshotAfter,
            checkedSide: mover
        )
        let defendersBefore = kingZoneDefenderCount(
            snapshot: snapshotBefore,
            side: mover
        )
        let defendersAfter = kingZoneDefenderCount(
            snapshot: snapshotAfter,
            side: mover
        )

        let ownKing = kingSquare(snapshot: snapshotAfter, side: mover)
        let opponentKing = kingSquare(snapshot: snapshotAfter, side: checkedSide)
        let nearOwnKing = ownKing.map {
            chebyshevDistance(effect.destination, $0) <= 2
        } ?? false
        let nearOpponentKing = opponentKing.map {
            chebyshevDistance(effect.destination, $0) <= 2
        } ?? false

        var meanings: [String] = []

        if givesCheck {
            meanings.append("相手玉に直接迫り、応手を求める手です")
        }
        if attackAfter > attackBefore {
            meanings.append("相手玉周辺へ利く駒を増やし、攻めを続けやすい形にします")
        }
        if dangerAfter < dangerBefore {
            meanings.append("自玉周辺への相手の圧力を減らします")
        }
        if defendersAfter > defendersBefore {
            meanings.append("自玉の近くに守り駒を増やします")
        }

        if effect.isDrop {
            if nearOpponentKing {
                meanings.append("持駒を相手玉の近くへ投入します")
            } else if nearOwnKing {
                meanings.append("持駒を自玉の近くへ投入します")
            } else {
                meanings.append("持駒を盤上へ投入します")
            }
        }

        if effect.pieceBefore == .king {
            if dangerAfter < dangerBefore {
                meanings.append("玉を相手の利きが少ない側へ動かし、安全度を上げます")
            } else {
                meanings.append("玉の位置を変えます")
            }
        } else if effect.capturedPiece != nil {
            if nearOpponentKing {
                meanings.append("駒を取りながら相手玉の近くへ移動します")
            } else {
                meanings.append("駒を取り、盤上の駒配置を変えます")
            }
        }

        if effect.promotes {
            meanings.append("成ることで駒の働きを強めます")
        }

        if meanings.isEmpty {
            meanings.append("この1手だけでは狙いを断定せず、続く手順と盤面変化を確認します")
        }

        return meanings.prefix(2).joined(separator: "。") + "。"
    }

    private static func makeRouteSummary(
        kind: ContinuationRouteKind,
        initial: BoardSnapshot,
        final: BoardSnapshot,
        moves: [ContinuationMoveStep],
        userSide: ShogiSide,
        comparisonStable: Bool,
        actualLossCp: Int?,
        reasonSummary: String
    ) -> String {
        guard let first = moves.first else {
            return "確認済みの読み筋はありません。未確認の参考読み筋は説明根拠には使用しません。"
        }

        if kind == .recommended,
           moves.count >= 2,
           let captured = first.effect.capturedPiece,
           moves[1].effect.capturedPiece == first.effect.pieceAfter,
           moves[1].effect.destination == first.effect.destination {
            return "最初に\(captured.kanji)を取りますが、直後に動かした\(first.effect.pieceAfter.kanji)が取り返されます。単純な駒得ではなく、交換後の形と次の手まで含めて評価された展開です。"
        }

        let opponentSide = opponent(of: userSide)
        let ownDangerBefore = kingZoneAttackerCount(
            snapshot: initial,
            checkedSide: userSide
        )
        let ownDangerAfter = kingZoneAttackerCount(
            snapshot: final,
            checkedSide: userSide
        )
        let attackBefore = kingZoneAttackerCount(
            snapshot: initial,
            checkedSide: opponentSide
        )
        let attackAfter = kingZoneAttackerCount(
            snapshot: final,
            checkedSide: opponentSide
        )
        let userChecks = moves.filter {
            $0.side == userSide && $0.givesCheck
        }.count
        let userCaptures = moves.filter {
            $0.side == userSide && $0.effect.capturedPiece != nil
        }.count
        let userDrops = moves.filter {
            $0.side == userSide && $0.effect.isDrop
        }.count

        var sentences: [String] = []
        if kind == .recommended {
            sentences.append("推奨ルートは \(first.label) から始まります。")
        } else {
            sentences.append("実戦ルートは \(first.label) から始まります。")
        }

        if attackAfter > attackBefore {
            sentences.append("相手玉周辺への攻撃参加が増える展開です。")
        } else if ownDangerAfter < ownDangerBefore {
            sentences.append("自玉周辺への圧力を減らす展開です。")
        } else if userChecks > 0 {
            sentences.append("王手を\(userChecks)回含み、相手玉へ直接迫ります。")
        } else if userCaptures >= 2 {
            sentences.append("駒交換を重ね、交換後の配置で差を作る展開です。")
        } else if userDrops > 0 {
            sentences.append("持駒を盤上へ投入して次の攻防を作ります。")
        } else {
            sentences.append("駒の配置を変えながら、次の攻防へつなぐ展開です。")
        }

        if kind == .actual {
            if comparisonStable, let loss = actualLossCp, loss > 0 {
                sentences.append("同条件比較では推奨手との差は\(loss)cpです。盤面を動かして、どこで差が広がるか確認します。")
            } else if !comparisonStable {
                sentences.append("推奨手との評価比較は未安定なので、評価値ではなく盤面変化を中心に確認します。")
            }
        } else if sentences.count == 1 {
            sentences.append(reasonSummary)
        }

        return sentences.joined()
    }

    private static func kingSquare(
        snapshot: BoardSnapshot,
        side: ShogiSide
    ) -> BoardCoordinate? {
        snapshot.squares.first {
            $0.value.side == side && $0.value.kind == .king
        }?.key
    }

    private static func chebyshevDistance(
        _ lhs: BoardCoordinate,
        _ rhs: BoardCoordinate
    ) -> Int {
        max(abs(lhs.file - rhs.file), abs(lhs.rank - rhs.rank))
    }

    private static func kingZoneDefenderCount(
        snapshot: BoardSnapshot,
        side: ShogiSide
    ) -> Int {
        guard let king = kingSquare(snapshot: snapshot, side: side) else { return 0 }
        return snapshot.squares.reduce(into: 0) { count, item in
            guard item.value.side == side, item.value.kind != .king else { return }
            if chebyshevDistance(item.key, king) <= 1 {
                count += 1
            }
        }
    }

    private static func kingZoneAttackerCount(
        snapshot: BoardSnapshot,
        checkedSide: ShogiSide
    ) -> Int {
        guard let king = kingSquare(snapshot: snapshot, side: checkedSide) else {
            return 0
        }
        let targets = (max(1, king.file - 1)...min(9, king.file + 1)).flatMap { file in
            (max(1, king.rank - 1)...min(9, king.rank + 1)).map {
                BoardCoordinate(file: file, rank: $0)
            }
        }
        let attacker = opponent(of: checkedSide)
        return snapshot.squares.reduce(into: 0) { count, item in
            guard item.value.side == attacker else { return }
            if targets.contains(where: {
                attacks(from: item.key, piece: item.value, target: $0, snapshot: snapshot)
            }) {
                count += 1
            }
        }
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
