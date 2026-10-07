import Foundation

#if targetEnvironment(simulator)
@MainActor
enum RecommendationDecisionHDSRealGameProbe {
    static func runPreflightIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ci-smoke") else { return }
        do {
            let audit = try run()
            try write(audit)
            for line in audit.split(separator: "\n") {
                NSLog("VR1A_HDS %@", String(line))
            }
        } catch {
            let text = "hds_status=FAIL\nhds_error=\(error.localizedDescription)\n"
            try? write(text)
            NSLog("VR1A_HDS hds_status=FAIL")
            NSLog("VR1A_HDS hds_error=%@", error.localizedDescription)
            fflush(stdout)
            exit(31)
        }
    }

    private static func run() throws -> String {
        let (game, shallow) = makeRealGame()
        let diagnosticURL = try DiagnosticExporter.write(
            game: game,
            fileName: "build19-vr1a-real-game.kif",
            entries: shallow,
            status: "浅解析 PASS",
            requestedMoveTimeMs: 1,
            totalElapsedMs: shallow.count,
            error: nil
        )

        let deepEntries = makeDeepAnchors()
        guard deepEntries.map(\.ply) == [41, 49, 69],
              deepEntries.allSatisfy({ $0.ply <= game.moves.count }) else {
            throw ProbeError.anchorMismatch("real-game anchor plies missing")
        }
        guard game.moves[40].usi == "1i1h",
              game.moves[48].usi == "4i3h",
              game.moves[68].usi == "1f1e" else {
            throw ProbeError.anchorMismatch("real-game played moves do not match frozen anchors")
        }

        let reason = ReasonAnalysisViewModel()
        reason.prepare(
            game: game,
            deepEntries: deepEntries,
            diagnosticURL: diagnosticURL
        )
        guard reason.status == "理由解析 PASS",
              reason.entries.map(\.ply) == [41, 49, 69] else {
            throw ProbeError.pipeline("reason analysis: \(reason.summary)")
        }

        let continuation = ContinuationSimulationViewModel()
        continuation.prepare(
            game: game,
            deepEntries: deepEntries,
            reasonEntries: reason.entries,
            diagnosticURL: reason.diagnosticURL
        )
        guard continuation.status == "展開シミュレーション PASS",
              continuation.entries.map(\.ply) == [41, 49, 69] else {
            throw ProbeError.pipeline("continuation: \(continuation.summary)")
        }

        let reports = try RecommendationDecisionPolicyAudit.validate(entries: continuation.entries)
        guard reports.count == 3,
              reports.allSatisfy({ $0.passed && $0.candidateLevel == "HDS-2-candidate" }) else {
            throw ProbeError.pipeline("HDS reports did not reach HDS-2-candidate")
        }

        let byPly = Dictionary(uniqueKeysWithValues: continuation.entries.map { ($0.ply, $0) })
        guard let p41 = byPly[41], let p49 = byPly[49], let p69 = byPly[69] else {
            throw ProbeError.anchorMismatch("continuation anchors missing")
        }
        let v41 = RecommendationDecisionPresentation.make(entry: p41)
        let v49 = RecommendationDecisionPresentation.make(entry: p49)
        let v69 = RecommendationDecisionPresentation.make(entry: p69)

        guard v41.status == .recommended,
              v41.headline.contains("▲４六金"),
              v41.meaning.contains("▲３六金"),
              v41.meaning.contains("同じ駒"),
              v41.difference.contains("実戦手"),
              v41.differenceHorizon.contains("7手目"),
              !v41.meaning.contains("この手単独では狙いを断定できません") else {
            throw ProbeError.semantic("41手目 HDS意味・比較・horizonが不足: \(v41.meaning) / \(v41.difference)")
        }

        guard v49.status == .recommended,
              v49.headline.contains("▲２五桂"),
              v49.meaning.contains("取り返され"),
              v49.meaning.contains("▲２六銀"),
              v49.meaning.contains("角"),
              v49.differenceHorizon.contains("3手目"),
              v49.learningCue.contains("交換全体") else {
            throw ProbeError.semantic("49手目 交換全体を説明できていません: \(v49.meaning)")
        }

        guard v69.status == .provisional,
              v69.headline.contains("暫定候補"),
              v69.headline.contains("▲３八玉"),
              !v69.headline.contains("推奨"),
              v69.confidenceTitle == "比較判定を保留",
              v69.differenceHorizon.contains("断定しません"),
              v69.learningCue.contains("決めつけず") else {
            throw ProbeError.semantic("69手目 比較保留が不十分: \(v69.headline) / \(v69.confidenceDetail)")
        }

        let reportByPly = Dictionary(uniqueKeysWithValues: reports.map { ($0.ply, $0) })
        return [
            "hds_status=PASS",
            "hds_version=2.0",
            "hds_real_game_plies=41,49,69",
            reportByPly[41]?.summaryLine ?? "ply=41 missing",
            "hds_41_headline=\(v41.headline)",
            "hds_41_meaning=\(v41.meaning)",
            "hds_41_difference=\(v41.difference)",
            "hds_41_horizon=\(v41.differenceHorizon)",
            "hds_41_evidence=\(v41.evidenceBasis)",
            "hds_41_learning=\(v41.learningCue)",
            reportByPly[49]?.summaryLine ?? "ply=49 missing",
            "hds_49_headline=\(v49.headline)",
            "hds_49_meaning=\(v49.meaning)",
            "hds_49_difference=\(v49.difference)",
            "hds_49_horizon=\(v49.differenceHorizon)",
            "hds_49_evidence=\(v49.evidenceBasis)",
            "hds_49_learning=\(v49.learningCue)",
            reportByPly[69]?.summaryLine ?? "ply=69 missing",
            "hds_69_headline=\(v69.headline)",
            "hds_69_meaning=\(v69.meaning)",
            "hds_69_difference=\(v69.difference)",
            "hds_69_horizon=\(v69.differenceHorizon)",
            "hds_69_evidence=\(v69.evidenceBasis)",
            "hds_69_learning=\(v69.learningCue)",
            "hds_h_required=true",
            "hds_3_claimed=false"
        ].joined(separator: "\n") + "\n"
    }

    private static func write(_ text: String) throws {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-hds.txt")
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func makeRealGame() -> (KIFGame, [ShallowAnalysisEntry]) {
        let moveText = "7g7f 3c3d 2g2f 8c8d 6g6f 2b3c 2h6h 3a3b 5i4h 6a5b 4h3h 5a4b 3h2h 7a6b 1g1f 8d8e 8h7g 3c4d 2h2g 2a3c 3i3h 2c2d 7i7h 8b8d 6i5h 3b2c 9i9h 5c5d 6f6e 8d8b 4g4f 1c1d 5h4g 4b3a 2g2h 6b5c 4f4e 4d7g+ 7h7g 4a3b 1i1h B*3e 3g3f 3e2f 3h2g 2d2e 2i3g 3a2b 4i3h 9c9d 6h6i 8a9c 6i2i 2c2d B*4f 3d3e 3f3e 3b2c 4g3f P*3d 2g2f 2e2f 3e3d S*2g 3h2g 2f2g+ 2h2g 1d1e 1f1e 1a1e P*2e 2c3d 2e2d 1e1h+ B*1d G*1c S*2c 1c2c 1d2c+ 2b1a G*1b"
        let usiMoves = moveText.split(separator: " ").map(String.init)
        var prefix: [String] = []
        var moves: [KIFMove] = []
        var shallow: [ShallowAnalysisEntry] = []

        for (index, usi) in usiMoves.enumerated() {
            let ply = index + 1
            let positionBefore = prefix.isEmpty
                ? "position startpos"
                : "position startpos moves " + prefix.joined(separator: " ")
            moves.append(.init(ply: ply, notation: usi, usi: usi, positionBefore: positionBefore))
            shallow.append(
                .init(
                    id: ply,
                    ply: ply,
                    actualMove: usi,
                    bestMove: usi,
                    scoreText: "cp 0",
                    blackPerspectiveCp: 0,
                    depthText: "-",
                    nodesText: "-",
                    npsText: "-",
                    pv: usi,
                    elapsedMs: 1,
                    thermalBefore: "nominal",
                    thermalAfter: "nominal"
                )
            )
            prefix.append(usi)
        }

        return (
            KIFGame(
                metadata: ["手合割": "平手", "先手": "あなた", "後手": "CPU"],
                moves: moves,
                termination: "詰み"
            ),
            shallow
        )
    }

    private static func makeDeepAnchors() -> [DeepAnalysisEntry] {
        [
            .init(
                id: 41,
                ply: 41,
                actualMove: "1i1h",
                shallowBestMove: "4g4f",
                shallowEstimatedLossCp: 186,
                bestMove: "4g4f",
                bestScoreText: "cp -566",
                actualScoreText: "cp -752",
                actualLossCp: 186,
                bestPV: "4g4f 3d3e 4i4h 2c3d 3g3f 3e3f 4f3f P*3e 3f4f 5b4b 3h2g 7c7d P*3g 3c4e 4f4g 4c4d",
                actualPV: "1i1h 3c4e 5g5f 3a2b 3h2g 4c4d 4i3h 5b4c 3g3f 2b2a B*6f 9c9d 9g9f",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "3d3e",
                candidates: [],
                elapsedMs: 1,
                thermalBefore: "nominal",
                thermalAfter: "nominal",
                comparisonStable: true,
                instabilityReasons: [],
                continuationStable: true,
                continuationInstabilityReasons: [],
                analysisAttempts: 2,
                finalMovetimeMs: 1600,
                adaptiveTriggered: true,
                topCandidateGapCp: 154
            ),
            .init(
                id: 49,
                ply: 49,
                actualMove: "4i3h",
                shallowBestMove: "3g2e",
                shallowEstimatedLossCp: 1267,
                bestMove: "3g2e",
                bestScoreText: "cp 1126",
                actualScoreText: "cp -141",
                actualLossCp: 1267,
                bestPV: "3g2e 3c2e 2g2f P*2d 2h3i 7c7d 5g5f 5d5e 5f5e 8a7c B*4f 2b2a 2f2e 2d2e",
                actualPV: "4i3h 5b4b 6h6i 2c2d 6i6h 4c4d 2g2f 2e2f 4e4d P*4e P*2g 2f2g+ 3h2g 5c4d",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "3c2e",
                candidates: [],
                elapsedMs: 1,
                thermalBefore: "nominal",
                thermalAfter: "nominal",
                comparisonStable: true,
                instabilityReasons: [],
                continuationStable: true,
                continuationInstabilityReasons: [],
                analysisAttempts: 1,
                finalMovetimeMs: 800,
                adaptiveTriggered: false,
                topCandidateGapCp: 782
            ),
            .init(
                id: 69,
                ply: 69,
                actualMove: "1f1e",
                shallowBestMove: "2g3h",
                shallowEstimatedLossCp: nil,
                bestMove: "2g3h",
                bestScoreText: "cp 5367",
                actualScoreText: "cp 3368",
                actualLossCp: nil,
                bestPV: "2g3h 2b3a 4f2d 5b4b 3d3c+ 4b3c 2d3e 4c4d P*2d P*2h 2i2h 2c1c 4e4d 5c4d 3e4d 3c4d 2d2c+ 1c2c 2h2c+",
                actualPV: "1f1e 1a1e 1h1e 2d1e 3d3c+ 2c3c 2g3h P*2h 2i2h P*2f 3f2f L*2d P*2e 1e2f 2h2f G*1e",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "2b3a",
                candidates: [],
                elapsedMs: 1,
                thermalBefore: "nominal",
                thermalAfter: "nominal",
                comparisonStable: false,
                instabilityReasons: ["loss_changed"],
                continuationStable: false,
                continuationInstabilityReasons: ["actual_pv_changed", "best_pv_changed"],
                analysisAttempts: 3,
                finalMovetimeMs: 2400,
                adaptiveTriggered: true,
                topCandidateGapCp: 730
            )
        ]
    }

    private enum ProbeError: Error, LocalizedError {
        case anchorMismatch(String)
        case pipeline(String)
        case semantic(String)

        var errorDescription: String? {
            switch self {
            case .anchorMismatch(let message): return "anchor mismatch: \(message)"
            case .pipeline(let message): return "pipeline: \(message)"
            case .semantic(let message): return "semantic: \(message)"
            }
        }
    }
}
#endif
