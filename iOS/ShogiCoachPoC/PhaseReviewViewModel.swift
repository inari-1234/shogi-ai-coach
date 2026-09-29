import Foundation
import ShogiCoachCore

enum GamePhaseKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case opening
    case middlegame
    case endgame

    var id: String { rawValue }

    var title: String {
        switch self {
        case .opening: return "序盤"
        case .middlegame: return "中盤"
        case .endgame: return "終盤"
        }
    }

    var focusText: String {
        switch self {
        case .opening:
            return "玉の安全、駒組み、飛角の働き、銀桂の活用、歩の形、仕掛けの準備を確認します。"
        case .middlegame:
            return "駒交換後の攻めと受け、手抜きの可否、大駒の働き、形勢変化、攻めの継続性を確認します。"
        case .endgame:
            return "王の安全、寄せ、詰み・詰めろ、受け、勝ち筋を、王手や王周辺の攻撃密度とエンジンPVから確認します。"
        }
    }
}

struct PhaseFeatureSnapshot {
    let ply: Int
    let snapshot: BoardSnapshot
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

enum PhaseCoachPointKind: String {
    case transition
    case important
    case endpoint
}

struct PhaseCoachPoint: Identifiable {
    let id: String
    let kind: PhaseCoachPointKind
    let ply: Int
    let snapshot: BoardSnapshot
    let title: String
    let detail: String
    let evidence: [String]
    let source: String
    let continuationSummary: String?
    let continuationPly: Int?
}

struct PhaseReviewSection: Identifiable {
    let id: GamePhaseKind
    let kind: GamePhaseKind
    let orientation: ShogiSide
    let startPly: Int
    let endPly: Int
    let summary: String
    let focusText: String
    let takeawayText: String
    let points: [PhaseCoachPoint]
}

@MainActor
final class PhaseReviewViewModel: ObservableObject {
    @Published private(set) var status = "未準備"
    @Published private(set) var summary = ""
    @Published private(set) var sections: [PhaseReviewSection] = []
    @Published private(set) var diagnosticURL: URL?
    @Published private(set) var diagnosticError: String?

    func reset() {
        status = "未準備"
        summary = ""
        sections = []
        diagnosticURL = nil
        diagnosticError = nil
    }

    func prepare(
        game: KIFGame,
        shallowEntries: [ShallowAnalysisEntry],
        deepEntries: [DeepAnalysisEntry],
        reasonEntries: [ReasonAnalysisEntry],
        continuationEntries: [ContinuationSimulationEntry],
        diagnosticURL sourceDiagnosticURL: URL?
    ) {
        reset()

        guard game.moves.count == shallowEntries.count, !game.moves.isEmpty else {
            status = "フェーズ別振り返り 未PASS"
            summary = "全局面の浅解析結果が揃っていません"
            return
        }
        guard let sourceDiagnosticURL else {
            status = "フェーズ別振り返り 未PASS"
            summary = "工程7までの診断JSONがありません"
            return
        }

        do {
            let features = try Self.makeFeatures(game: game, shallowEntries: shallowEntries)
            let assignments = Self.assignPhases(features: features)
            let orientation = Self.userOrientation(game: game)
            let resolved = Self.makeSections(
                features: features,
                assignments: assignments,
                deepEntries: deepEntries,
                reasonEntries: reasonEntries,
                continuationEntries: continuationEntries,
                orientation: orientation
            )
            guard !resolved.isEmpty else {
                throw PhaseReviewError.noSections
            }

            sections = resolved
            status = "フェーズ別振り返り PASS"
            summary = resolved.map {
                "\($0.kind.title): \($0.startPly)〜\($0.endPly)手 / \($0.points.count)ポイント"
            }.joined(separator: "\n")

            let diagnostic = ShogiDiagnosticDocument.PhaseAnalysisInfo(
                status: status,
                usedAdditionalEngineSearch: false,
                sections: resolved.map { section in
                    .init(
                        kind: section.kind.rawValue,
                        title: section.kind.title,
                        startPly: section.startPly,
                        endPly: section.endPly,
                        summary: section.summary,
                        focusText: section.focusText,
                        points: section.points.map { point in
                            .init(
                                ply: point.ply,
                                title: point.title,
                                detail: point.detail,
                                evidence: point.evidence,
                                source: point.source,
                                continuationSummary: point.continuationSummary
                            )
                        }
                    )
                },
                transitions: Self.transitionDiagnostics(features: features, assignments: assignments),
                error: nil
            )
            diagnosticURL = try DiagnosticExporter.augmentWithPhaseAnalysis(
                url: sourceDiagnosticURL,
                phaseAnalysis: diagnostic
            )
            SimulatorStage.mark("phase_review_complete_\(resolved.count)")
        } catch {
            let message = error.localizedDescription
            status = "フェーズ別振り返り 未PASS"
            summary = message
            let diagnostic = ShogiDiagnosticDocument.PhaseAnalysisInfo(
                status: status,
                usedAdditionalEngineSearch: false,
                sections: [],
                transitions: [],
                error: message
            )
            do {
                diagnosticURL = try DiagnosticExporter.augmentWithPhaseAnalysis(
                    url: sourceDiagnosticURL,
                    phaseAnalysis: diagnostic
                )
            } catch {
                diagnosticError = error.localizedDescription
            }
            SimulatorStage.mark("phase_review_error_\(message)")
        }
    }

    private static func makeFeatures(
        game: KIFGame,
        shallowEntries: [ShallowAnalysisEntry]
    ) throws -> [PhaseFeatureSnapshot] {
        var cumulativeCaptures = 0
        var recentChecks: [Bool] = []
        var previousCP: Int?
        var result: [PhaseFeatureSnapshot] = []
        result.reserveCapacity(game.moves.count)

        for index in game.moves.indices {
            let move = game.moves[index]
            let shallow = shallowEntries[index]
            let snapshot = try BoardSnapshotResolver.resolve(positionCommand: move.positionBefore)
            let currentCP = shallow.blackPerspectiveCp
            let evaluationSwing = currentCP.flatMap { current in
                previousCP.map { abs(current - $0) }
            }

            result.append(
                PhaseFeatureSnapshot(
                    ply: move.ply,
                    snapshot: snapshot,
                    cumulativeCaptures: cumulativeCaptures,
                    totalHandPieces: snapshot.totalHandCount(side: .black)
                        + snapshot.totalHandCount(side: .white),
                    promotedPieces: snapshot.squares.values.filter { $0.kind.isPromoted }.count,
                    enemyCampPieces: enemyCampPieceCount(snapshot),
                    majorPieceContacts: majorPieceContactCount(snapshot),
                    recentChecks: recentChecks.filter { $0 }.count,
                    kingPressure: max(
                        kingZoneAttackerCount(snapshot: snapshot, checkedSide: .black),
                        kingZoneAttackerCount(snapshot: snapshot, checkedSide: .white)
                    ),
                    evaluationSwingCp: evaluationSwing,
                    mateSignal: shallow.scoreText.hasPrefix("mate "),
                    sideToMoveInCheck: isKingInCheck(
                        snapshot: snapshot,
                        checkedSide: snapshot.sideToMove
                    )
                )
            )

            let effect = try MoveEffectResolver.resolve(
                positionCommand: move.positionBefore,
                move: move.usi
            )
            if effect.capturedPiece != nil {
                cumulativeCaptures += 1
            }
            let nextCommand = try MoveEffectResolver.appending(
                move: move.usi,
                to: move.positionBefore
            )
            let nextSnapshot = try BoardSnapshotResolver.resolve(positionCommand: nextCommand)
            let gaveCheck = isKingInCheck(
                snapshot: nextSnapshot,
                checkedSide: opponent(of: effect.side)
            )
            recentChecks.append(gaveCheck)
            if recentChecks.count > 8 {
                recentChecks.removeFirst(recentChecks.count - 8)
            }
            previousCP = currentCP ?? previousCP
        }
        return result
    }

    private static func assignPhases(features: [PhaseFeatureSnapshot]) -> [GamePhaseKind] {
        var current: GamePhaseKind = .opening
        var middleStreak = 0
        var endStreak = 0
        var result: [GamePhaseKind] = []
        result.reserveCapacity(features.count)

        for feature in features {
            let middle = middleScore(feature)
            let end = endScore(feature)

            switch current {
            case .opening:
                if feature.mateSignal || end >= 8 {
                    current = .endgame
                    middleStreak = 0
                } else {
                    middleStreak = middle >= 4 ? middleStreak + 1 : 0
                    if middle >= 6 || middleStreak >= 2 {
                        current = .middlegame
                        endStreak = 0
                    }
                }
            case .middlegame:
                if feature.mateSignal || end >= 8 {
                    current = .endgame
                } else {
                    endStreak = end >= 4 ? endStreak + 1 : 0
                    if endStreak >= 3 {
                        current = .endgame
                    }
                }
            case .endgame:
                break
            }
            result.append(current)
        }
        return result
    }

    private static func middleScore(_ f: PhaseFeatureSnapshot) -> Int {
        var score = 0
        if f.cumulativeCaptures >= 2 { score += 2 }
        if f.totalHandPieces >= 2 { score += 2 }
        if f.promotedPieces >= 1 { score += 1 }
        if f.enemyCampPieces >= 1 { score += 1 }
        if f.cumulativeCaptures >= 1 && f.majorPieceContacts >= 1 { score += 1 }
        if f.recentChecks >= 1 { score += 1 }
        if f.kingPressure >= 2 { score += 1 }
        if (f.evaluationSwingCp ?? 0) >= 200 { score += 1 }
        if f.sideToMoveInCheck { score += 1 }
        return score
    }

    private static func endScore(_ f: PhaseFeatureSnapshot) -> Int {
        var score = f.mateSignal ? 5 : 0
        if f.recentChecks >= 2 { score += 2 }
        else if f.recentChecks == 1 { score += 1 }
        if f.kingPressure >= 2 { score += 2 }
        if f.promotedPieces >= 2 { score += 1 }
        if f.totalHandPieces >= 6 { score += 1 }
        if f.enemyCampPieces >= 2 { score += 1 }
        if f.cumulativeCaptures >= 10 { score += 1 }
        if (f.evaluationSwingCp ?? 0) >= 350 { score += 1 }
        if f.sideToMoveInCheck { score += 2 }
        return score
    }

    private static func makeSections(
        features: [PhaseFeatureSnapshot],
        assignments: [GamePhaseKind],
        deepEntries: [DeepAnalysisEntry],
        reasonEntries: [ReasonAnalysisEntry],
        continuationEntries: [ContinuationSimulationEntry],
        orientation: ShogiSide
    ) -> [PhaseReviewSection] {
        guard features.count == assignments.count else { return [] }
        let reasons = Dictionary(uniqueKeysWithValues: reasonEntries.map { ($0.ply, $0) })
        let continuations = Dictionary(uniqueKeysWithValues: continuationEntries.map { ($0.ply, $0) })
        let featuresByPly = Dictionary(uniqueKeysWithValues: features.map { ($0.ply, $0) })

        return GamePhaseKind.allCases.compactMap { kind in
            let indices = assignments.indices.filter { assignments[$0] == kind }
            guard let firstIndex = indices.first, let lastIndex = indices.last else { return nil }
            let start = features[firstIndex]
            let end = features[lastIndex]
            var points: [PhaseCoachPoint] = []

            points.append(
                PhaseCoachPoint(
                    id: "\(kind.rawValue)-start-\(start.ply)",
                    kind: .transition,
                    ply: start.ply,
                    snapshot: start.snapshot,
                    title: kind == .opening ? "序盤の盤面" : "\(kind.title)へ移った局面",
                    detail: transitionNarrative(kind: kind, feature: start),
                    evidence: humanEvidenceTexts(start),
                    source: "phase_state",
                    continuationSummary: nil,
                    continuationPly: nil
                )
            )

            let deepInPhase = deepEntries
                .filter { $0.ply >= start.ply && $0.ply <= end.ply }
                .sorted {
                    let left = $0.actualLossCp ?? ($0.comparisonStable ? 0 : 10_000)
                    let right = $1.actualLossCp ?? ($1.comparisonStable ? 0 : 10_000)
                    if left != right { return left > right }
                    return $0.ply < $1.ply
                }
                .prefix(2)

            for deep in deepInPhase {
                let reason = reasons[deep.ply]?.interpretation.text
                    ?? "この局面はエンジンの最善手・実戦手・PVを比較して確認します。"
                var evidence = ["最善手 \(deep.bestMove) / 実戦手 \(deep.actualMove)"]
                if deep.comparisonStable, let loss = deep.actualLossCp {
                    evidence.append("同条件比較の評価損失 \(loss)cp")
                } else if !deep.comparisonStable {
                    evidence.append("同条件比較は未安定のため評価損失を断定しない")
                } else {
                    evidence.append("最善手 \(deep.bestScoreText) / 実戦手 \(deep.actualScoreText)")
                }
                let continuation = continuations[deep.ply]
                if continuation?.continuationStable == false {
                    evidence.append("継続PVは未安定のため到達形は参考扱い")
                }
                guard let feature = featuresByPly[deep.ply] else { continue }
                points.append(
                    PhaseCoachPoint(
                        id: "\(kind.rawValue)-deep-\(deep.ply)",
                        kind: .important,
                        ply: deep.ply,
                        snapshot: feature.snapshot,
                        title: "\(deep.ply)手目：この対局のポイント",
                        detail: reason,
                        evidence: evidence,
                        source: "engine_important_position",
                        continuationSummary: continuation?.continuationStable == true
                            ? continuation?.recommended.targetShapeSummary
                            : nil,
                        continuationPly: continuation == nil ? nil : deep.ply
                    )
                )
            }

            if end.ply != start.ply && points.count < 4 {
                points.append(
                    PhaseCoachPoint(
                        id: "\(kind.rawValue)-end-\(end.ply)",
                        kind: .endpoint,
                        ply: end.ply,
                        snapshot: end.snapshot,
                        title: "\(kind.title)の終わり",
                        detail: endpointNarrative(kind: kind, feature: end),
                        evidence: humanEvidenceTexts(end),
                        source: "phase_state",
                        continuationSummary: nil,
                        continuationPly: nil
                    )
                )
            }

            let clipped = Array(points.prefix(4))
            let importantPly = clipped.first(where: { $0.kind == .important })?.ply
            return PhaseReviewSection(
                id: kind,
                kind: kind,
                orientation: orientation,
                startPly: start.ply,
                endPly: end.ply,
                summary: phaseSummary(kind: kind, start: start, end: end),
                focusText: kind.focusText,
                takeawayText: takeawayText(kind: kind, importantPly: importantPly),
                points: clipped
            )
        }
    }

    private static func phaseSummary(
        kind: GamePhaseKind,
        start: PhaseFeatureSnapshot,
        end: PhaseFeatureSnapshot
    ) -> String {
        switch kind {
        case .opening:
            return "駒を整えながら、どこから仕掛けるかを作っていく区間です。大きな分岐がある局面だけ盤面で確認します。"
        case .middlegame:
            return "駒交換が進み、攻めるか受けるかの判断で盤面が大きく変わる区間です。重要局面は推奨手と実戦手を動かして比較します。"
        case .endgame:
            return "玉周辺の攻防が中心になり、1手ごとの寄せと受けが結果に直結しやすい区間です。王手や詰みに近い局面を盤面で確認します。"
        }
    }

    private static func transitionNarrative(
        kind: GamePhaseKind,
        feature: PhaseFeatureSnapshot
    ) -> String {
        switch kind {
        case .opening:
            return "まだ大きな駒交換は少なく、駒の配置を整えるところから始まっています。"
        case .middlegame:
            if feature.majorPieceContacts > 0 {
                return "飛車・角が相手駒へ働き始め、駒組み中心の局面から具体的な攻防へ移っています。"
            }
            return "駒交換と持駒が生まれ、駒組み中心の局面から具体的な攻めと受けへ移っています。"
        case .endgame:
            if feature.recentChecks > 0 || feature.kingPressure >= 2 {
                return "王手や玉周辺の攻防が増え、駒得よりも寄せと受けの速度が重要な局面へ移っています。"
            }
            return "持駒と敵陣への進出が増え、玉を直接狙う終盤の判断が中心になっています。"
        }
    }

    private static func endpointNarrative(
        kind: GamePhaseKind,
        feature: PhaseFeatureSnapshot
    ) -> String {
        switch kind {
        case .opening:
            return "ここまでで駒組みが進み、次は実際に駒がぶつかる局面へ進みます。盤面の配置がどう変わったかを確認します。"
        case .middlegame:
            return "駒交換後の形が固まり、ここからは玉周辺の攻防がより重要になります。次の局面へ入る前の形を確認します。"
        case .endgame:
            return "終局に近い盤面です。王手・受け・持駒の使い方がどのように結果へつながったかを確認します。"
        }
    }

    private static func takeawayText(
        kind: GamePhaseKind,
        importantPly: Int?
    ) -> String {
        if let importantPly {
            return "このフェーズでは、\(importantPly)手目の分岐を盤面で動かし、推奨手と実戦手で何が変わるかを確認するのが中心です。"
        }
        switch kind {
        case .opening:
            return "この対局では序盤に大きな分岐は検出されませんでした。駒組みがどう進んだかを盤面で確認します。"
        case .middlegame:
            return "この対局では中盤に明確な重要局面を追加抽出していません。駒交換後の盤面変化を確認します。"
        case .endgame:
            return "この対局では終盤に明確な重要局面を追加抽出していません。玉周辺の攻防の変化を確認します。"
        }
    }

    private static func humanEvidenceTexts(_ f: PhaseFeatureSnapshot) -> [String] {
        var result: [String] = []
        if f.cumulativeCaptures >= 2 {
            result.append("駒交換が進み、盤上の形が変わっています")
        }
        if f.totalHandPieces >= 2 {
            result.append("持駒が生まれ、駒を打つ手が選択肢に入っています")
        }
        if f.majorPieceContacts > 0 {
            result.append("飛車・角が相手駒へ直接働く局面です")
        }
        if f.recentChecks > 0 || f.kingPressure >= 2 {
            result.append("玉周辺の攻防が強まっています")
        }
        if let swing = f.evaluationSwingCp, swing >= 200 {
            result.append("直前から評価が大きく動いた局面です")
        }
        if f.mateSignal {
            result.append("エンジンは詰みに関わる読みを検出しています")
        }
        if result.isEmpty {
            result.append("大きな駒交換はまだ少なく、駒の配置が中心です")
        }
        return Array(result.prefix(3))
    }

    private static func transitionDiagnostics(
        features: [PhaseFeatureSnapshot],
        assignments: [GamePhaseKind]
    ) -> [ShogiDiagnosticDocument.PhaseTransitionInfo] {
        guard features.count == assignments.count else { return [] }
        var result: [ShogiDiagnosticDocument.PhaseTransitionInfo] = []
        for index in assignments.indices where index == 0 || assignments[index] != assignments[index - 1] {
            let f = features[index]
            result.append(
                .init(
                    ply: f.ply,
                    phase: assignments[index].rawValue,
                    cumulativeCaptures: f.cumulativeCaptures,
                    totalHandPieces: f.totalHandPieces,
                    promotedPieces: f.promotedPieces,
                    enemyCampPieces: f.enemyCampPieces,
                    majorPieceContacts: f.majorPieceContacts,
                    recentChecks: f.recentChecks,
                    kingPressure: f.kingPressure,
                    evaluationSwingCp: f.evaluationSwingCp,
                    mateSignal: f.mateSignal,
                    sideToMoveInCheck: f.sideToMoveInCheck
                )
            )
        }
        return result
    }

    private static func enemyCampPieceCount(_ snapshot: BoardSnapshot) -> Int {
        snapshot.squares.reduce(into: 0) { count, item in
            let coordinate = item.key
            let piece = item.value
            guard piece.kind != .king else { return }
            if piece.side == .black, coordinate.rank <= 3 { count += 1 }
            if piece.side == .white, coordinate.rank >= 7 { count += 1 }
        }
    }

    private static func majorPieceContactCount(_ snapshot: BoardSnapshot) -> Int {
        snapshot.squares.reduce(into: 0) { count, item in
            let coordinate = item.key
            let piece = item.value
            guard piece.kind.base == .bishop || piece.kind.base == .rook else { return }
            let touchesEnemy = snapshot.squares.contains { target, other in
                other.side != piece.side
                    && attacks(from: coordinate, piece: piece, target: target, snapshot: snapshot)
            }
            if touchesEnemy { count += 1 }
        }
    }

    private static func kingZoneAttackerCount(
        snapshot: BoardSnapshot,
        checkedSide: ShogiSide
    ) -> Int {
        guard let king = snapshot.squares.first(where: {
            $0.value.side == checkedSide && $0.value.kind == .king
        })?.key else { return 0 }

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

    private static func isKingInCheck(
        snapshot: BoardSnapshot,
        checkedSide: ShogiSide
    ) -> Bool {
        guard let king = snapshot.squares.first(where: {
            $0.value.side == checkedSide && $0.value.kind == .king
        })?.key else { return false }
        let attacker = opponent(of: checkedSide)
        return snapshot.squares.contains { coordinate, piece in
            piece.side == attacker
                && attacks(from: coordinate, piece: piece, target: king, snapshot: snapshot)
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
            return df == 0 && dr * forward > 0
                && clearLine(from: source, to: target, snapshot: snapshot)
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
            return abs(df) == abs(dr) && df != 0
                && clearLine(from: source, to: target, snapshot: snapshot)
        case .rook:
            return ((df == 0) != (dr == 0))
                && clearLine(from: source, to: target, snapshot: snapshot)
        case .king:
            return max(abs(df), abs(dr)) == 1
        case .horse:
            if abs(df) == abs(dr), df != 0 {
                return clearLine(from: source, to: target, snapshot: snapshot)
            }
            return abs(df) + abs(dr) == 1
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
        let fileStep = target.file == source.file ? 0 : (target.file > source.file ? 1 : -1)
        let rankStep = target.rank == source.rank ? 0 : (target.rank > source.rank ? 1 : -1)
        var file = source.file + fileStep
        var rank = source.rank + rankStep
        while file != target.file || rank != target.rank {
            if snapshot.piece(at: BoardCoordinate(file: file, rank: rank)) != nil {
                return false
            }
            file += fileStep
            rank += rankStep
        }
        return true
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
}

enum PhaseReviewError: Error, LocalizedError {
    case noSections

    var errorDescription: String? {
        switch self {
        case .noSections:
            return "フェーズ区間を構成できません"
        }
    }
}
