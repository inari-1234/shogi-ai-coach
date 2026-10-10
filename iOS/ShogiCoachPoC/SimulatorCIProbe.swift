import Foundation
import ShogiCoachCore

enum SimulatorStage {
    #if targetEnvironment(simulator)
    private static let lock = NSLock()

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-stage.txt")
    }

    static func reset() {
        lock.lock()
        defer { lock.unlock() }
        try? FileManager.default.removeItem(at: url)
    }

    static func mark(_ value: String) {
        lock.lock()
        defer { lock.unlock() }

        let safe = value
            .replacingOccurrences(of: "\n", with: " ")
            .prefix(240)
        let line = "\(Date().timeIntervalSince1970) \(safe)\n"
        let data = Data(line.utf8)

        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func latest() -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return text.split(separator: "\n").last.map(String.init)
    }
    #else
    static func reset() {}
    static func mark(_ value: String) {}
    static func latest() -> String? { nil }
    #endif
}

#if targetEnvironment(simulator)
import Darwin
@MainActor
final class EngineProbe: ObservableObject {
    @Published private(set) var status = "未実行"
    @Published private(set) var resultText = ""

    private let session = EngineUSISession()

    init() {
        if let previous = SimulatorStage.latest() {
            resultText = "前回の最終到達点:\n\(previous)"
        }
    }

    func runDefaultProbe() async {
        SimulatorStage.reset()
        SimulatorStage.mark("default_button_pressed")
        status = "解析中"
        resultText = ""
        do {
            let sfen = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
            let result = try await session.run(sfen: sfen, movetimeMs: 1500, multiPV: 1)
            SimulatorStage.mark("default_probe_complete")
            resultText = Self.format(result)
            status = "PASS候補"
        } catch {
            SimulatorStage.mark("default_probe_error_\(error.localizedDescription)")
            status = "未PASS"
            resultText = error.localizedDescription
        }
    }

    func runTenProbe() async {
        SimulatorStage.reset()
        SimulatorStage.mark("ten_probe_button_pressed")
        status = "10回連続解析中"
        resultText = ""
        let sfen = "lnsgkgsnl/1r5b1/ppppppppp/9/9/9/PPPPPPPPP/1B5R1/LNSGKGSNL b - 1"
        var samples: [ProbeSample] = []
        do {
            for i in 1...10 {
                let sample = try await session.run(sfen: sfen, movetimeMs: 1500, multiPV: 1)
                samples.append(sample)
                status = "10回連続解析中 \(i)/10"
            }
            let elapsed = samples.map(\.elapsedMs).sorted()
            let median = elapsed[elapsed.count / 2]
            let maxMemory = samples.compactMap(\.memoryBytesAfter).max()
            let last = samples.last!
            resultText = [
                "10/10 completed",
                "median elapsed: \(median) ms",
                "last bestmove: \(last.result.bestMove.move)",
                "last nps: \(last.result.principalVariations.first?.nps.map(String.init) ?? "-")",
                "max footprint: \(maxMemory.map(Self.byteText) ?? "-")",
                "thermal: \(samples.first?.thermalBefore ?? "-") -> \(last.thermalAfter)"
            ].joined(separator: "\n")
            SimulatorStage.mark("ten_probe_complete")
            status = last.thermalAfter == "critical" ? "未PASS" : "実機PASS候補"
        } catch {
            SimulatorStage.mark("ten_probe_error_\(error.localizedDescription)")
            status = "未PASS"
            resultText = "\(samples.count)/10 completed\n\(error.localizedDescription)"
        }
    }

    private static func format(_ sample: ProbeSample) -> String {
        let primary = sample.result.principalVariations.first
        return [
            "bestmove: \(sample.result.bestMove.move)",
            "score: \(scoreText(primary?.score))",
            "depth: \(primary?.depth.map(String.init) ?? "-")",
            "nodes: \(primary?.nodes.map(String.init) ?? "-")",
            "nps: \(primary?.nps.map(String.init) ?? "-")",
            "pv: \(primary?.pv.joined(separator: " ") ?? "-")",
            "elapsed: \(sample.elapsedMs) ms",
            "footprint: \(sample.memoryBytesAfter.map(byteText) ?? "-")",
            "thermal: \(sample.thermalBefore) -> \(sample.thermalAfter)"
        ].joined(separator: "\n")
    }

    private static func scoreText(_ score: USIScore?) -> String {
        guard let score else { return "-" }
        switch score {
        case .centipawn(let value, _): return "cp \(value)"
        case .mate(let value, _): return "mate \(value)"
        }
    }

    private static func byteText(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .memory)
    }
}



@MainActor
enum SimulatorCIProbe {
    private static func writeReport(_ text: String) {
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-probe.txt")
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }

    private static func runKIFSelfTest() throws -> KIFGame {
        let sample = """
        手合割：平手
        1 ７六歩(77)
        2 ８四歩(83)
        3 ２六歩(27)
        4 ８五歩(84)
        5 ７七角(88)
        6 投了
        """
        let game = try KIFParser.parse(sample)
        guard game.moves.map(\.usi) == ["7g7f", "8c8d", "2g2f", "8d8e", "8h7g"],
              game.termination == "投了" else {
            throw NSError(
                domain: "ShogiCoach.KIFCI",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "KIF self-test mismatch"]
            )
        }
        return game
    }

    private static func makeTerminalRegression() -> (KIFGame, [ShallowAnalysisEntry]) {
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
            moves.append(
                KIFMove(
                    ply: ply,
                    notation: usi,
                    usi: usi,
                    positionBefore: positionBefore
                )
            )

            let isFinal = ply == 81
            let bestMove = isFinal ? "S*2b" : usi
            shallow.append(
                ShallowAnalysisEntry(
                    id: ply,
                    ply: ply,
                    actualMove: usi,
                    bestMove: bestMove,
                    scoreText: isFinal ? "mate 1" : "cp 0",
                    blackPerspectiveCp: isFinal ? nil : 0,
                    depthText: "-",
                    nodesText: "-",
                    npsText: "-",
                    pv: bestMove,
                    elapsedMs: 1,
                    thermalBefore: "nominal",
                    thermalAfter: "nominal"
                )
            )
            prefix.append(usi)
        }

        let game = KIFGame(
            metadata: [
                "手合割": "平手",
                "先手": "あなた",
                "後手": "CPU"
            ],
            moves: moves,
            termination: "詰み"
        )
        return (game, shallow)
    }

    private static func makeHDSRegression() -> (KIFGame, [ShallowAnalysisEntry]) {
        let (game, base) = makeTerminalRegression()
        let blackPerspective: [Int: Int] = [
            41: 1_200,
            42: 0,
            49: 2_400,
            50: 0,
            69: 3_600,
            70: 0
        ]
        let shallow = base.map { entry in
            ShallowAnalysisEntry(
                id: entry.id,
                ply: entry.ply,
                actualMove: entry.actualMove,
                bestMove: entry.actualMove,
                scoreText: "cp 0",
                blackPerspectiveCp: blackPerspective[entry.ply] ?? 0,
                depthText: entry.depthText,
                nodesText: entry.nodesText,
                npsText: entry.npsText,
                pv: entry.actualMove,
                elapsedMs: entry.elapsedMs,
                thermalBefore: entry.thermalBefore,
                thermalAfter: entry.thermalAfter
            )
        }
        return (game, shallow)
    }

    // Frozen from the user-reviewed 2026-10-07 diagnostic. These entries preserve the
    // exact 41/49/69 comparison pairs while the live engine replay remains free to vary
    // within its time-limited search budget.
    private static func makeFrozenHDSSemanticEntries() -> [DeepAnalysisEntry] {
        [
            DeepAnalysisEntry(
                id: 41,
                ply: 41,
                actualMove: "1i1h",
                shallowBestMove: "4g5f",
                shallowEstimatedLossCp: 322,
                bestMove: "4g4f",
                bestScoreText: "cp -566",
                actualScoreText: "cp -752",
                actualLossCp: 186,
                bestPV: "4g4f 3d3e 4i4h 2c3d 3g3f 3e3f 4f3f P*3e 3f4f 5b4b 3h2g 7c7d P*3g 3c4e 4f4g 4c4d",
                actualPV: "1i1h 3c4e 5g5f 3a2b 3h2g 4c4d 4i3h 5b4c 3g3f 2b2a B*6f 9c9d 9g9f",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "3d3e",
                candidates: [],
                elapsedMs: 4_800,
                thermalBefore: "nominal",
                thermalAfter: "nominal",
                comparisonStable: true,
                instabilityReasons: [],
                continuationStable: true,
                continuationInstabilityReasons: [],
                analysisAttempts: 2,
                finalMovetimeMs: 1_600,
                adaptiveTriggered: true,
                topCandidateGapCp: 154
            ),
            DeepAnalysisEntry(
                id: 49,
                ply: 49,
                actualMove: "4i3h",
                shallowBestMove: "3g2e",
                shallowEstimatedLossCp: 1_174,
                bestMove: "3g2e",
                bestScoreText: "cp 1126",
                actualScoreText: "cp -141",
                actualLossCp: 1_267,
                bestPV: "3g2e 3c2e 2g2f P*2d 2h3i 7c7d 5g5f 5d5e 5f5e 8a7c B*4f 2b2a 2f2e 2d2e",
                actualPV: "4i3h 5b4b 6h6i 2c2d 6i6h 4c4d 2g2f 2e2f 4e4d P*4e P*2g 2f2g+ 3h2g 5c4d",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "3c2e",
                candidates: [],
                elapsedMs: 1_600,
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
            DeepAnalysisEntry(
                id: 69,
                ply: 69,
                actualMove: "1f1e",
                shallowBestMove: "2g3h",
                shallowEstimatedLossCp: 807,
                bestMove: "2g3h",
                bestScoreText: "cp 5367",
                actualScoreText: "cp 3368",
                actualLossCp: nil,
                bestPV: "2g3h 2b3a 4f2d 5b4b 3d3c+ 4b3c 2d3e 4c4d P*2d P*2h 2i2h 2c1c 4e4d 5c4d 3e4d 3c4d 2d2c+ 1c2c 2h2c+",
                actualPV: "1f1e 1a1e 1h1e 2d1e 3d3c+ 2c3c 2g3h P*2h 2i2h P*2f 3f2f L*2d P*2e 1e2f 2h2f G*1e",
                actualAnalysisSource: "equal-condition",
                opponentBestReply: "2b3a",
                candidates: [],
                elapsedMs: 9_605,
                thermalBefore: "nominal",
                thermalAfter: "nominal",
                comparisonStable: false,
                instabilityReasons: ["loss_changed"],
                continuationStable: false,
                continuationInstabilityReasons: ["actual_pv_changed", "best_pv_changed"],
                analysisAttempts: 3,
                finalMovetimeMs: 2_400,
                adaptiveTriggered: true,
                topCandidateGapCp: 730
            )
        ]
    }

    private static func hdsStatusText(_ status: RecommendationDecisionPresentation.Status) -> String {
        switch status {
        case .matched: return "matched"
        case .recommended: return "recommended"
        case .provisional: return "provisional"
        }
    }

    private static func writeHDSMachineReport(
        _ report: RecommendationDecisionHDSAudit.Report,
        entries: [ContinuationSimulationEntry]
    ) throws {
        let byPly = Dictionary(uniqueKeysWithValues: entries.map { ($0.ply, $0) })
        let payload: [[String: Any]] = report.positions.map { position in
            let entry = byPly[position.ply]
            let presentation = entry.map(RecommendationDecisionPresentation.make(entry:))
            return [
                "ply": position.ply,
                "passed": position.passed,
                "status": hdsStatusText(position.status),
                "headline": presentation?.headline ?? "",
                "meaning": presentation?.meaning ?? "",
                "difference": presentation?.difference ?? "",
                "horizon": presentation?.horizon ?? "",
                "confidenceTitle": presentation?.confidenceTitle ?? "",
                "confidenceDetail": presentation?.confidenceDetail ?? "",
                "learningCue": presentation?.learningCue ?? "",
                "gates": position.gates.map { gate in
                    [
                        "gate": gate.gate.rawValue,
                        "passed": gate.passed,
                        "detail": gate.detail
                    ] as [String: Any]
                }
            ] as [String: Any]
        }
        let root: [String: Any] = [
            "schema": "HDS-M-2.0",
            "passed": report.passed,
            "positions": payload
        ]
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ci-hds-m.json")
        try data.write(to: url, options: .atomic)
    }

    private struct AnalysisQualityGateResult {
        let normalStable: Bool
        let normalComparisonStable: Bool
        let normalContinuationStable: Bool
        let normalAttempts: Int
        let closeGapCp: Int?
        let closeAttempts: Int
        let terminalStable: Bool
        let terminalComparisonStable: Bool
        let terminalContinuationStable: Bool
        let terminalAttempts: Int
        let terminalBestMove: String
    }

    private static func runAnalysisQualityGate(
        terminalGame: KIFGame
    ) async throws -> AnalysisQualityGateResult {
        guard terminalGame.moves.count >= 81,
              let terminalMove = terminalGame.moves.last else {
            throw EngineUSISession.ProbeError.protocolError("quality gate positions missing")
        }

        // Calibration-only Simulator budget. The gate validates VE1-B mechanics,
        // not production node authority; B6 owns the production policy decision.
        let policy = VE1BNodeSearchPolicy(
            candidateDiscoveryNodes: 10_000,
            candidateDiscoveryNodeTiers: [10_000, 20_000, 40_000],
            confirmationNodeTiers: [10_000, 20_000, 40_000],
            safetyCeilingMs: 15_000,
            authorityStatus: "SIMULATOR_QUALITY_GATE_CALIBRATION_UNFROZEN"
        )
        try policy.validate()

        let session = EngineUSISession()
        try await session.beginAnalysis(multiPV: 3)
        do {
            func validateContract(_ result: VE1BNodeComparisonResult, label: String) throws {
                guard result.attempts.map(\.nodeBudget) == policy.confirmationNodeTiers,
                      result.discoveryTierEvidence.count == policy.candidateDiscoveryNodeTiers.count,
                      result.evidenceRecords.count == 9,
                      result.finalNodeBudget == 40_000 else {
                    throw EngineUSISession.ProbeError.protocolError(
                        "\(label) VE1-B tier/evidence contract mismatch"
                    )
                }
            }

            let normalMove = terminalGame.moves[40]
            let normal = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: normalMove.positionBefore,
                actualMove: normalMove.usi,
                candidateCount: 3,
                policy: policy
            )
            try validateContract(normal, label: "normal")
            let normalFinal = normal.finalAttempt
            let normalPVUsable = normal.confirmedBestPV.count >= 3
                && normal.confirmedActualPV.count >= 2
            let normalExplicitlyUnstableForPV = !normal.continuationStable
                && !normal.continuationInstabilityReasons.isEmpty
            guard !normalFinal.bestLine.pvMoves.isEmpty,
                  !normalFinal.actualLine.pvMoves.isEmpty,
                  normalPVUsable || normalExplicitlyUnstableForPV else {
                throw EngineUSISession.ProbeError.protocolError(
                    "normal quality position lacks confirmed PV or instability evidence"
                )
            }

            let close = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: "position startpos",
                actualMove: "7g7f",
                candidateCount: 3,
                policy: policy
            )
            try validateContract(close, label: "candidate")
            guard close.candidateLines.count >= 2,
                  close.attempts.count == policy.confirmationNodeTiers.count else {
                throw EngineUSISession.ProbeError.protocolError(
                    "candidate comparison did not execute the full fixed-node confirmation series"
                )
            }

            let terminal = try await VE1BNodeComparisonAnalyzer.analyze(
                session: session,
                command: terminalMove.positionBefore,
                actualMove: terminalMove.usi,
                candidateCount: 3,
                policy: policy
            )
            try validateContract(terminal, label: "terminal")
            let terminalFinal = terminal.finalAttempt
            guard terminalMove.usi == "G*1b",
                  terminalFinal.actualLine.move == terminalMove.usi,
                  terminalFinal.actualLine.pvMoves.first == terminalMove.usi,
                  !terminalFinal.bestLine.pvMoves.isEmpty else {
                throw EngineUSISession.ProbeError.protocolError(
                    "terminal/drop quality position regression"
                )
            }

            await session.endAnalysis()
            return AnalysisQualityGateResult(
                normalStable: normal.comparisonStable && normal.continuationStable,
                normalComparisonStable: normal.comparisonStable,
                normalContinuationStable: normal.continuationStable,
                normalAttempts: normal.attempts.count,
                closeGapCp: close.topCandidateGapCp,
                closeAttempts: close.attempts.count,
                terminalStable: terminal.comparisonStable && terminal.continuationStable,
                terminalComparisonStable: terminal.comparisonStable,
                terminalContinuationStable: terminal.continuationStable,
                terminalAttempts: terminal.attempts.count,
                terminalBestMove: terminalFinal.bestLine.move
            )
        } catch {
            await session.endAnalysis()
            throw error
        }
    }

    private static func deepCompletionContractPass(
        state: DeepAnalysisRunState,
        expectedPositions: Int,
        entryCount: Int,
        attemptCounts: [Int],
        evidenceCounts: [Int]
    ) -> Bool {
        guard case .completed(let counts) = state,
              counts.total == expectedPositions,
              entryCount == expectedPositions,
              attemptCounts.count == expectedPositions,
              evidenceCounts.count == expectedPositions,
              attemptCounts.allSatisfy({ $0 == 9 }),
              evidenceCounts.allSatisfy({ $0 == 9 }) else {
            return false
        }
        return true
    }

    private static func deepCompletionNegativeContractPasses() -> Bool {
        let abortRejected = !deepCompletionContractPass(
            state: .incomplete(
                reason: "safety_aborted",
                completedPositions: 2,
                expectedPositions: 3
            ),
            expectedPositions: 3,
            entryCount: 2,
            attemptCounts: [9, 9],
            evidenceCounts: [9, 9]
        )
        let missingEvidenceRejected = !deepCompletionContractPass(
            state: .completed(.init(stable: 1, unstable: 1, unconfirmed: 1)),
            expectedPositions: 3,
            entryCount: 3,
            attemptCounts: [9, 9, 9],
            evidenceCounts: [9, 8, 9]
        )
        let countMismatchRejected = !deepCompletionContractPass(
            state: .completed(.init(stable: 1, unstable: 1, unconfirmed: 0)),
            expectedPositions: 3,
            entryCount: 3,
            attemptCounts: [9, 9, 9],
            evidenceCounts: [9, 9, 9]
        )
        return abortRejected && missingEvidenceRejected && countMismatchRejected
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains("--ci-smoke") else { return }

        SimulatorStage.reset()
        writeReport("stage=started\n")
        SimulatorStage.mark("probe_started")

        let kifGame: KIFGame
        do {
            kifGame = try runKIFSelfTest()
            SimulatorStage.mark("kif_pass")
        } catch {
            writeReport([
                "stage=kif_failed",
                "kif_status=FAIL",
                "kif_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("kif_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(2)
        }

        let shallow = ShallowAnalysisViewModel()
        await shallow.analyze(game: kifGame, fileName: "ci-sample.kif", movetimeMs: 80)
        let shallowStatus = shallow.status
        let shallowCount = shallow.entries.count
        let shallowValid = shallow.entries.allSatisfy {
            !$0.bestMove.isEmpty
                && !$0.scoreText.isEmpty
                && !$0.pv.isEmpty
                && !$0.actualMove.isEmpty
        }
        guard shallowStatus == "浅解析 PASS",
              shallowCount == kifGame.moves.count,
              shallowValid else {
            writeReport([
                "stage=shallow_failed",
                "kif_status=PASS",
                "kif_moves=\(kifGame.moves.count)",
                "shallow_status=FAIL",
                "shallow_count=\(shallowCount)",
                "shallow_summary_begin",
                shallow.summary,
                "shallow_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("shallow_failed")
            fflush(stdout)
            exit(3)
        }
        guard let diagnosticURL = shallow.diagnosticURL,
              let diagnosticData = try? Data(contentsOf: diagnosticURL),
              let diagnostic = try? JSONDecoder.iso8601.decode(ShogiDiagnosticDocument.self, from: diagnosticData),
              diagnostic.schemaVersion == 1,
              diagnostic.game.fileName == "ci-sample.kif",
              diagnostic.analysis.completedPositions == kifGame.moves.count,
              diagnostic.positions.count == kifGame.moves.count,
              diagnostic.positions.allSatisfy({ !$0.pv.isEmpty && !$0.bestMove.isEmpty }),
              diagnostic.app.version == "0.8.3",
              diagnostic.app.build == "16",
              diagnostic.app.gitCommit != "unknown" else {
            writeReport([
                "stage=diagnostic_failed",
                "kif_status=PASS",
                "shallow_status=PASS",
                "diagnostic_status=FAIL"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("diagnostic_failed")
            fflush(stdout)
            exit(4)
        }
        SimulatorStage.mark("diagnostic_pass")

        let deep = DeepAnalysisViewModel()
        await deep.analyze(
            game: kifGame,
            shallowEntries: shallow.entries,
            diagnosticURL: shallow.diagnosticURL,
            deepMovetimeMs: 200,
            multiPV: 3,
            maxPositions: 3
        )
        let deepStatus = deep.status
        let deepCount = deep.entries.count
        let deepValid = deep.entries.allSatisfy {
            $0.candidates.count == 3
                && !$0.bestMove.isEmpty
                && !$0.actualMove.isEmpty
                && !$0.referenceBestPV.isEmpty
                && !$0.referenceActualPV.isEmpty
                && ($0.comparisonStable
                    ? (!$0.confirmedBestPV.isEmpty && !$0.confirmedActualPV.isEmpty)
                    : ($0.confirmedBestPV.isEmpty && $0.confirmedActualPV.isEmpty))
                && $0.actualAnalysisSource.hasPrefix("node-equal-condition")
                && $0.analysisAttempts == 9
                && $0.finalMovetimeMs == 0
                && $0.nodePolicyAuthorityStatus == "UNFROZEN_CALIBRATION"
                && $0.candidateDiscoveryNodes == 50_000
                && $0.confirmationNodeTiers == [50_000, 100_000, 200_000]
                && $0.finalNodeBudget == 200_000
                && $0.searchEvidence.count == 9
                && $0.candidates.allSatisfy { !$0.pv.isEmpty && !$0.move.isEmpty }
        }
        let deepCompletionValid = deepCompletionContractPass(
            state: deep.runState,
            expectedPositions: 3,
            entryCount: deepCount,
            attemptCounts: deep.entries.map(\.analysisAttempts),
            evidenceCounts: deep.entries.map { $0.searchEvidence.count }
        )
        let deepNegativeContractValid = deepCompletionNegativeContractPasses()
        let nonStableDeepEntries = deep.entries.filter { $0.stabilityState != VE1BStabilityState.stable.rawValue }
        let nonStableSuppressionValid = nonStableDeepEntries.allSatisfy {
            !$0.comparisonStable && $0.actualLossCp == nil
        }
        guard deepCompletionValid,
              deepNegativeContractValid,
              deepCount == 3,
              deepValid,
              nonStableSuppressionValid,
              let deepDiagnosticURL = deep.diagnosticURL,
              let deepDiagnosticData = try? Data(contentsOf: deepDiagnosticURL),
              let deepDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: deepDiagnosticData
              ),
              deepDiagnostic.schemaVersion == 2,
              deepDiagnostic.app.version == "0.8.3",
              deepDiagnostic.app.build == "16",
              deepDiagnostic.deepAnalysis?.status == "深掘り PASS",
              deepDiagnostic.deepAnalysis?.multiPV == 3,
              deepDiagnostic.deepAnalysis?.adaptivePolicy == "ve1b-node-UNFROZEN_CALIBRATION",
              deepDiagnostic.deepAnalysis?.completedPositions == 3,
              deepDiagnostic.deepAnalysis?.positions.count == 3,
              deepDiagnostic.deepAnalysis?.positions.allSatisfy({ position in
                  guard let source = deep.entries.first(where: { $0.ply == position.ply }) else {
                      return false
                  }
                  return position.actualAnalysisSource.hasPrefix("node-equal-condition")
                      && position.bestPV == source.confirmedBestPV
                      && position.actualPV == source.confirmedActualPV
                      && (source.comparisonStable
                          ? (!position.bestPV.isEmpty && !position.actualPV.isEmpty)
                          : (position.bestPV.isEmpty && position.actualPV.isEmpty))
                      && position.analysisAttempts >= 1
              }) == true else {
            writeReport([
                "stage=deep_failed",
                "kif_status=PASS",
                "shallow_status=PASS",
                "diagnostic_status=PASS",
                "deep_status=FAIL",
                "deep_count=\(deepCount)",
                "deep_summary_begin",
                deep.summary,
                "deep_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("deep_failed")
            fflush(stdout)
            exit(5)
        }
        SimulatorStage.mark("deep_pass")

        let boardReview = BoardReviewViewModel()
        boardReview.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            diagnosticURL: deep.diagnosticURL
        )
        let boardDisplayStatus = boardReview.status
        let boardDisplayCount = boardReview.entries.count
        let boardDisplayValid = boardReview.entries.allSatisfy {
            !$0.bestMoveText.isEmpty
                && !$0.actualMoveText.isEmpty
                && (1...9).contains($0.bestMove.destination.file)
                && (1...9).contains($0.bestMove.destination.rank)
                && ($0.bestMove.isDrop || $0.bestMove.source != nil)
        }
        guard boardDisplayStatus == "盤面表示 PASS",
              boardDisplayCount == deep.entries.count,
              boardDisplayValid,
              boardReview.entries.contains(where: { !$0.bestMove.isDrop }),
              let boardDiagnosticURL = boardReview.diagnosticURL,
              let boardDiagnosticData = try? Data(contentsOf: boardDiagnosticURL),
              let boardDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: boardDiagnosticData
              ),
              boardDiagnostic.schemaVersion == 3,
              boardDiagnostic.app.version == "0.8.3",
              boardDiagnostic.app.build == "16",
              boardDiagnostic.boardDisplay?.status == "盤面表示 PASS",
              boardDiagnostic.boardDisplay?.completedPositions == deep.entries.count,
              boardDiagnostic.boardDisplay?.positions.count == deep.entries.count else {
            writeReport([
                "stage=board_display_failed",
                "board_display_status=FAIL",
                "board_display_count=\(boardDisplayCount)",
                "board_display_summary_begin",
                boardReview.summary,
                "board_display_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("board_display_failed")
            fflush(stdout)
            exit(8)
        }
        let boardCarriesNonStable = Set(boardReview.entries.map(\.ply)).isSuperset(
            of: Set(nonStableDeepEntries.map(\.ply))
        )
        guard boardCarriesNonStable else {
            writeReport([
                "stage=board_display_failed",
                "board_display_status=FAIL",
                "board_display_error=non-stable positions were dropped"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("board_display_nonstable_dropped")
            fflush(stdout)
            exit(8)
        }
        SimulatorStage.mark("board_display_pass")

        let reason = ReasonAnalysisViewModel()
        reason.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            diagnosticURL: boardReview.diagnosticURL
        )
        let reasonStatus = reason.status
        let reasonCount = reason.entries.count
        let reasonValid = reason.entries.allSatisfy { entry in
            guard let source = deep.entries.first(where: { $0.ply == entry.ply }) else {
                return false
            }
            let factIDs = Set(entry.facts.map(\.id))
            let validLevels = entry.facts.allSatisfy {
                $0.level == .engineConfirmed || $0.level == .pvObserved
            }
            let linkedInterpretation = !entry.interpretation.evidenceFactIDs.isEmpty
                && entry.interpretation.evidenceFactIDs.allSatisfy { factIDs.contains($0) }
            return entry.facts.count >= 4
                && validLevels
                && linkedInterpretation
                && entry.bestPV == source.confirmedBestPV
                && entry.actualPV == source.confirmedActualPV
        }
        guard reasonStatus == "理由解析 PASS",
              reasonCount == deep.entries.count,
              reasonValid,
              let reasonDiagnosticURL = reason.diagnosticURL,
              let reasonDiagnosticData = try? Data(contentsOf: reasonDiagnosticURL),
              let reasonDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: reasonDiagnosticData
              ),
              reasonDiagnostic.schemaVersion == 4,
              reasonDiagnostic.app.version == "0.8.3",
              reasonDiagnostic.app.build == "16",
              reasonDiagnostic.reasonAnalysis?.status == "理由解析 PASS",
              reasonDiagnostic.reasonAnalysis?.completedPositions == deep.entries.count,
              reasonDiagnostic.reasonAnalysis?.positions.count == deep.entries.count,
              reasonDiagnostic.reasonAnalysis?.positions.allSatisfy({
                  !$0.facts.isEmpty
                      && !$0.interpretation.text.isEmpty
                      && !$0.interpretation.evidenceFactIDs.isEmpty
              }) == true else {
            writeReport([
                "stage=reason_analysis_failed",
                "reason_status=FAIL",
                "reason_count=\(reasonCount)",
                "reason_summary_begin",
                reason.summary,
                "reason_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_analysis_failed")
            fflush(stdout)
            exit(10)
        }
        let reasonNonStableValid = nonStableDeepEntries.allSatisfy { deepEntry in
            guard let reasonEntry = reason.entries.first(where: { $0.ply == deepEntry.ply }) else { return false }
            return reasonEntry.actualLossCp == nil
                && reasonEntry.facts.contains(where: {
                    $0.kind == "score_comparison"
                        && $0.text.contains("評価損失は断定しない")
                })
        }
        guard reasonNonStableValid else {
            writeReport([
                "stage=reason_analysis_failed",
                "reason_status=FAIL",
                "reason_error=non-stable loss suppression/provisional wording missing"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_nonstable_contract_failed")
            fflush(stdout)
            exit(10)
        }
        SimulatorStage.mark("reason_analysis_pass")

        let continuation = ContinuationSimulationViewModel()
        continuation.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            reasonEntries: reason.entries,
            diagnosticURL: reason.diagnosticURL
        )
        let continuationStatus = continuation.status
        let continuationCount = continuation.entries.count
        let continuationValid = continuation.entries.allSatisfy { entry in
            guard let source = deep.entries.first(where: { $0.ply == entry.ply }) else {
                return false
            }
            let recommendedRouteValid: Bool
            if source.confirmedBestPV.isEmpty {
                recommendedRouteValid = entry.recommended.moves.isEmpty
                    && entry.recommended.developmentBlocks.isEmpty
            } else {
                recommendedRouteValid = entry.recommended.moves.first?.usi == source.bestMove
                    && !entry.recommended.developmentBlocks.isEmpty
            }
            let actualRouteValid: Bool
            if source.confirmedActualPV.isEmpty {
                actualRouteValid = entry.actual.moves.isEmpty
                    && entry.actual.developmentBlocks.isEmpty
            } else {
                actualRouteValid = entry.actual.moves.first?.usi == source.actualMove
                    && !entry.actual.developmentBlocks.isEmpty
            }
            return recommendedRouteValid
                && actualRouteValid
                && entry.recommended.moves.count <= 10
                && entry.actual.moves.count <= 10
                && !entry.recommended.summary.isEmpty
                && !entry.actual.summary.isEmpty
                && entry.recommended.moves.allSatisfy {
                    !$0.label.isEmpty
                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))
                        && !$0.factText.isEmpty
                        && !$0.coachText.isEmpty
                        && $0.factText != $0.coachText
                }
                && entry.actual.moves.allSatisfy {
                    !$0.label.isEmpty
                        && ($0.label.hasPrefix("▲") || $0.label.hasPrefix("△"))
                        && !$0.factText.isEmpty
                        && !$0.coachText.isEmpty
                        && $0.factText != $0.coachText
                }
                && !entry.recommended.targetShapeSummary.isEmpty
                && !entry.actual.targetShapeSummary.isEmpty
        }
        guard continuationStatus == "展開シミュレーション PASS",
              continuationCount == deep.entries.count,
              continuationValid,
              let continuationDiagnosticURL = continuation.diagnosticURL,
              let continuationDiagnosticData = try? Data(contentsOf: continuationDiagnosticURL),
              let continuationDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: continuationDiagnosticData
              ),
              continuationDiagnostic.schemaVersion == 5,
              continuationDiagnostic.app.version == "0.8.3",
              continuationDiagnostic.app.build == "16",
              continuationDiagnostic.continuationSimulation?.status == "展開シミュレーション PASS",
              continuationDiagnostic.continuationSimulation?.completedPositions == deep.entries.count,
              continuationDiagnostic.continuationSimulation?.positions.count == deep.entries.count,
              continuationDiagnostic.continuationSimulation?.positions.allSatisfy({ position in
                  guard let source = deep.entries.first(where: { $0.ply == position.ply }) else {
                      return false
                  }
                  let recommendedBoundary = source.confirmedBestPV.isEmpty
                      ? position.recommended.moves.isEmpty
                      : !position.recommended.moves.isEmpty
                  let actualBoundary = source.confirmedActualPV.isEmpty
                      ? position.actual.moves.isEmpty
                      : !position.actual.moves.isEmpty
                  return recommendedBoundary
                      && actualBoundary
                      && !position.recommended.targetShapeSummary.isEmpty
                      && !position.actual.targetShapeSummary.isEmpty
              }) == true,
              (try? RecommendationDecisionPolicyAudit.validate(entries: continuation.entries)) != nil else {
            writeReport([
                "stage=continuation_simulation_failed",
                "continuation_status=FAIL",
                "continuation_count=\(continuationCount)",
                "continuation_summary_begin",
                continuation.summary,
                "continuation_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("continuation_simulation_failed")
            fflush(stdout)
            exit(15)
        }
        let continuationNonStableValid = nonStableDeepEntries.allSatisfy { deepEntry in
            guard let item = continuation.entries.first(where: { $0.ply == deepEntry.ply }) else { return false }
            let presentation = RecommendationDecisionPresentation.make(entry: item)
            return !item.comparisonStable
                && deepEntry.referenceBestPV.isEmpty == false
                && deepEntry.referenceActualPV.isEmpty == false
                && deepEntry.confirmedBestPV.isEmpty
                && deepEntry.confirmedActualPV.isEmpty
                && item.recommended.moves.isEmpty
                && item.actual.moves.isEmpty
                && presentation.status == .provisional
                && presentation.status.badgeText == "比較保留"
                && presentation.headline.contains("暫定候補")
        }
        guard continuationNonStableValid else {
            writeReport([
                "stage=continuation_simulation_failed",
                "continuation_status=FAIL",
                "continuation_error=non-stable provisional presentation missing"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("continuation_nonstable_contract_failed")
            fflush(stdout)
            exit(15)
        }
        SimulatorStage.mark("continuation_simulation_pass")

        let phaseReview = PhaseReviewViewModel()
        phaseReview.prepare(
            game: kifGame,
            shallowEntries: shallow.entries,
            deepEntries: deep.entries,
            reasonEntries: reason.entries,
            continuationEntries: continuation.entries,
            diagnosticURL: continuation.diagnosticURL
        )
        let phaseStatus = phaseReview.status
        let phaseKinds = Set(phaseReview.sections.map(\.kind))
        guard phaseStatus == "フェーズ別振り返り PASS",
              phaseReview.sections.count == 1,
              phaseKinds == Set([GamePhaseKind.opening]),
              phaseReview.sections.allSatisfy({
                  !$0.themeTitle.isEmpty
                      && !$0.themeDetail.isEmpty
                      && !$0.nextCheckText.isEmpty
                      && !$0.takeawayText.isEmpty
                      && !$0.points.isEmpty
                      && $0.points.filter { $0.kind == .important }.count <= 1
                      && $0.points.allSatisfy { $0.snapshot.pieceCount > 0 }
              }),
              let phaseDiagnosticURL = phaseReview.diagnosticURL,
              let phaseDiagnosticData = try? Data(contentsOf: phaseDiagnosticURL),
              let phaseDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: phaseDiagnosticData
              ),
              phaseDiagnostic.schemaVersion == 7,
              phaseDiagnostic.app.version == "0.8.3",
              phaseDiagnostic.app.build == "16",
              phaseDiagnostic.phaseAnalysis?.status == "フェーズ別振り返り PASS",
              phaseDiagnostic.phaseAnalysis?.usedAdditionalEngineSearch == false,
              phaseDiagnostic.phaseAnalysis?.sections.count == 1,
              phaseDiagnostic.phaseAnalysis?.sections.first?.kind == "opening" else {
            writeReport([
                "stage=phase_review_failed",
                "phase_status=FAIL",
                "phase_summary_begin",
                phaseReview.summary,
                "phase_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("phase_review_failed")
            fflush(stdout)
            exit(17)
        }
        SimulatorStage.mark("phase_review_pass")

        let contextReview = ContextAnalysisViewModel()
        await contextReview.prepare(
            game: kifGame,
            deepEntries: deep.entries,
            diagnosticURL: phaseReview.diagnosticURL
        )
        let contextStatus = contextReview.status
        let contextCount = contextReview.entries.count
        guard contextStatus == "局面文脈解析 PASS",
              contextCount == kifGame.moves.count,
              let contextDiagnosticURL = contextReview.diagnosticURL,
              let contextDiagnosticData = try? Data(contentsOf: contextDiagnosticURL),
              let contextDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: contextDiagnosticData
              ),
              contextDiagnostic.schemaVersion == 8,
              contextDiagnostic.app.version == "0.8.3",
              contextDiagnostic.app.build == "16",
              contextDiagnostic.contextAnalysis?.status == "局面文脈解析 PASS",
              contextDiagnostic.contextAnalysis?.refinementPolicy == ContextAnalysisViewModel.refinementPolicy,
              contextDiagnostic.contextAnalysis?.completedPositions == kifGame.moves.count,
              contextDiagnostic.contextAnalysis?.positions.count == kifGame.moves.count else {
            writeReport([
                "stage=context_analysis_failed",
                "context_status=FAIL",
                "context_count=\(contextCount)",
                "context_summary_begin",
                contextReview.summary,
                "context_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_analysis_failed")
            fflush(stdout)
            exit(22)
        }

        let contextAuditURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("ci-context-main.json")
        do {
            try contextDiagnosticData.write(to: contextAuditURL, options: .atomic)
        } catch {
            writeReport([
                "stage=context_diagnostic_copy_failed",
                "context_status=FAIL",
                "context_diagnostic_copy_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_diagnostic_copy_failed")
            fflush(stdout)
            exit(26)
        }

        let contextEngine = MoveContextEngine()
        guard let rookPawnRegression = try? contextEngine.analyze(
                positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
                move: "8h7g"
              ),
              rookPawnRegression.selectedIntent == .rookPawnResponse,
              rookPawnRegression.confidence == .high,
              rookPawnRegression.evidence.contains(where: {
                  $0.kind == .previousMoveCausality
                      && $0.supportedIntent == .rookPawnResponse
              }),
              rookPawnRegression.selectedIntent != .attackPreparation,
              let bishopLineRegression = try? contextEngine.analyze(
                positionCommand: "position startpos moves 7g7f 3c3d",
                move: "8h2b+"
              ),
              bishopLineRegression.selectedIntent == .bishopLineResponse,
              let geometryRegression = try? contextEngine.analyze(
                positionCommand: "position startpos moves 7g7f 3c3d",
                move: "6i7h"
              ),
              geometryRegression.selectedIntent != .attackPreparation else {
            writeReport([
                "stage=context_semantics_failed",
                "context_status=\(contextStatus)",
                "context_semantics_status=FAIL"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_semantics_failed")
            fflush(stdout)
            exit(23)
        }

        let diagnosticRecommendedCount = contextDiagnostic.contextAnalysis?.positions.filter {
            $0.recommendedMove != nil && $0.recommendedExplanation != nil
        }.count ?? 0

        let knowledgeRuntime = ContextKnowledgeStore.load()
        guard knowledgeRuntime.loadStatus == "PASS",
              knowledgeRuntime.recordCount == 1281,
              knowledgeRuntime.sourceIDs == ["denryusen:dr4-hardware2:2024"],
              let knowledgeRookRegression = try? knowledgeRuntime.engine.analyze(
                positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
                move: "8h7g"
              ),
              knowledgeRookRegression.selectedIntent == .rookPawnResponse,
              knowledgeRookRegression.confidence == .high,
              let precedentEvidence = knowledgeRookRegression.evidence.first(where: {
                  $0.kind == .precedent && $0.supportedIntent == .rookPawnResponse
              }),
              precedentEvidence.detail.contains("observations=12"),
              precedentEvidence.detail.contains("raw_knowledge_reinforces=rook_pawn_response"),
              contextDiagnostic.contextAnalysis?.knowledgeLoadStatus == "PASS",
              contextDiagnostic.contextAnalysis?.knowledgeSourceIDs == ["denryusen:dr4-hardware2:2024"],
              contextDiagnostic.contextAnalysis?.knowledgeRecordCount == 1281,
              contextReview.recommendedExplanations.count == deep.entries.count,
              diagnosticRecommendedCount == deep.entries.count,
              let targetContextPosition = contextDiagnostic.contextAnalysis?.positions.first(where: {
                  $0.analysis.move == "8h7g" && $0.analysis.previousMove == "8d8e"
              }),
              targetContextPosition.explanation.confidence == .high,
              targetContextPosition.explanation.tone == .assertive,
              targetContextPosition.explanation.conclusion.contains("飛車先"),
              targetContextPosition.explanation.whyNow.contains("直前"),
              targetContextPosition.explanation.evidenceText.contains("前例12件"),
              !targetContextPosition.explanation.conclusion.contains("相手玉側"),
              !targetContextPosition.explanation.conclusion.contains("攻めに参加") else {
            writeReport([
                "stage=context_knowledge_failed",
                "context_status=\(contextStatus)",
                "context_knowledge_status=FAIL",
                "context_knowledge_load=\(knowledgeRuntime.loadStatus)",
                "context_knowledge_records=\(knowledgeRuntime.recordCount)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_knowledge_failed")
            fflush(stdout)
            exit(24)
        }
        let refinementGame = KIFGame(
            metadata: ["手合割": "平手", "先手": "あなた", "後手": "CPU"],
            moves: [
                KIFMove(
                    ply: 1,
                    notation: "7g7f",
                    usi: "7g7f",
                    positionBefore: "position startpos"
                )
            ],
            termination: nil
        )
        let refinementDeep = DeepAnalysisEntry(
            id: 1,
            ply: 1,
            actualMove: "7g7f",
            shallowBestMove: "2g2f",
            shallowEstimatedLossCp: nil,
            bestMove: "2g2f",
            bestScoreText: "cp 0",
            actualScoreText: "cp 0",
            actualLossCp: nil,
            bestPV: "2g2f 8c8d 2f2e",
            actualPV: "7g7f 3c3d 2g2f",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "8c8d",
            candidates: [],
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: false,
            instabilityReasons: ["fixture_unstable"],
            continuationStable: false,
            continuationInstabilityReasons: ["fixture_unstable"],
            analysisAttempts: 1,
            finalMovetimeMs: 800,
            adaptiveTriggered: false,
            topCandidateGapCp: nil
        )
        let refinementDiagnosticURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("ci-context-refinement.json")
        do {
            try contextDiagnosticData.write(to: refinementDiagnosticURL, options: .atomic)
        } catch {
            writeReport([
                "stage=context_refinement_fixture_copy_failed",
                "context_selective_refinement_status=FAIL",
                "context_refinement_fixture_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_refinement_fixture_copy_failed")
            fflush(stdout)
            exit(27)
        }

        let refinementReview = ContextAnalysisViewModel()
        await refinementReview.prepare(
            game: refinementGame,
            deepEntries: [refinementDeep],
            diagnosticURL: refinementDiagnosticURL
        )
        guard refinementReview.status == "局面文脈解析 PASS",
              !refinementReview.usedAdditionalEngineSearch,
              refinementReview.refinementCandidatePlies == [1],
              refinementReview.refinementCompletedPlies == [1],
              refinementReview.entries.first?.analysis.selectedIntent == .unresolved,
              refinementReview.entries.first?.analysis.confidence == .unresolved else {
            writeReport([
                "stage=context_selective_refinement_failed",
                "context_selective_refinement_status=FAIL",
                "context_selective_candidates=\(refinementReview.refinementCandidatePlies)",
                "context_selective_completed=\(refinementReview.refinementCompletedPlies)",
                "context_selective_summary=\(refinementReview.summary)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("context_selective_refinement_failed")
            fflush(stdout)
            exit(25)
        }
        SimulatorStage.mark("context_selective_refinement_pass")
        SimulatorStage.mark("context_analysis_pass")

        let (unstableGame, _) = makeTerminalRegression()
        let unstableDeepEntry = DeepAnalysisEntry(
            id: 75,
            ply: 75,
            actualMove: "B*1d",
            shallowBestMove: "2d2c+",
            shallowEstimatedLossCp: 980,
            bestMove: "2d2c+",
            bestScoreText: "cp 4814",
            actualScoreText: "cp 5442",
            actualLossCp: nil,
            bestPV: "2d2c+ 2b3a",
            actualPV: "B*1d G*2a",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "2b3a",
            candidates: [
                DeepCandidateLine(
                    id: 1,
                    rank: 1,
                    move: "2d2c+",
                    scoreText: "cp 4814",
                    centipawn: 4814,
                    depthText: "15",
                    nodesText: "1",
                    npsText: "1",
                    pv: "2d2c+ 2b3a",
                    opponentReply: "2b3a"
                )
            ],
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: false,
            instabilityReasons: ["comparison_inversion"],
            continuationStable: false,
            continuationInstabilityReasons: ["best_pv_short", "actual_pv_short"],
            analysisAttempts: 3,
            finalMovetimeMs: 2400,
            adaptiveTriggered: true,
            topCandidateGapCp: 18
        )
        let unstableReason = ReasonAnalysisViewModel()
        unstableReason.prepare(
            game: unstableGame,
            deepEntries: [unstableDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard unstableReason.status == "理由解析 PASS",
              unstableReason.entries.count == 1,
              let unstableEntry = unstableReason.entries.first,
              unstableEntry.interpretation.text.contains("判定を保留"),
              unstableEntry.interpretation.text.contains("断定"),
              !unstableEntry.interpretation.text.contains("評価差の理由候補"),
              unstableEntry.facts.contains(where: {
                  $0.kind == "score_comparison"
                      && $0.text.contains("評価損失は断定しない")
              }) else {
            writeReport([
                "stage=reason_unstable_failed",
                "reason_unstable_status=FAIL",
                "reason_unstable_summary_begin",
                unstableReason.summary,
                "reason_unstable_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_unstable_failed")
            fflush(stdout)
            exit(12)
        }
        let unstableContinuation = ContinuationSimulationViewModel()
        unstableContinuation.prepare(
            game: unstableGame,
            deepEntries: [unstableDeepEntry],
            reasonEntries: unstableReason.entries,
            diagnosticURL: unstableReason.diagnosticURL
        )
        guard unstableContinuation.status == "展開シミュレーション PASS",
              let unstableContinuationEntry = unstableContinuation.entries.first,
              !unstableContinuationEntry.comparisonStable else {
            writeReport([
                "stage=reason_unstable_failed",
                "reason_unstable_status=FAIL",
                "reason_unstable_error=unstable continuation was dropped or promoted"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_unstable_continuation_failed")
            fflush(stdout)
            exit(12)
        }
        let unstablePresentation = RecommendationDecisionPresentation.make(entry: unstableContinuationEntry)
        let unstableHDSReport = RecommendationDecisionHDSAudit.evaluate(entries: unstableContinuation.entries)
        guard unstablePresentation.status == .provisional,
              unstablePresentation.status.badgeText == "比較保留",
              unstablePresentation.headline.contains("暫定候補"),
              unstableHDSReport.passed else {
            writeReport([
                "stage=reason_unstable_failed",
                "reason_unstable_status=FAIL",
                "reason_unstable_error=provisional/HDS contract missing"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_unstable_hds_failed")
            fflush(stdout)
            exit(12)
        }
        SimulatorStage.mark("reason_unstable_pass")

        let recaptureDeepEntry = DeepAnalysisEntry(
            id: 49,
            ply: 49,
            actualMove: "4i3h",
            shallowBestMove: "3g2e",
            shallowEstimatedLossCp: 1232,
            bestMove: "3g2e",
            bestScoreText: "cp 1103",
            actualScoreText: "cp -103",
            actualLossCp: 1206,
            bestPV: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
            actualPV: "4i3h 5b4b B*6f",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "3c2e",
            candidates: [
                DeepCandidateLine(
                    id: 1,
                    rank: 1,
                    move: "3g2e",
                    scoreText: "cp 1103",
                    centipawn: 1103,
                    depthText: "15",
                    nodesText: "1",
                    npsText: "1",
                    pv: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
                    opponentReply: "3c2e"
                )
            ],
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
        )
        let recaptureReason = ReasonAnalysisViewModel()
        recaptureReason.prepare(
            game: unstableGame,
            deepEntries: [recaptureDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard recaptureReason.status == "理由解析 PASS",
              recaptureReason.entries.count == 1,
              let recaptureEntry = recaptureReason.entries.first,
              recaptureEntry.interpretation.text.contains("取り返されます"),
              recaptureEntry.interpretation.text.contains("単純な駒取り"),
              !recaptureEntry.interpretation.text.contains("この機会を逃した") else {
            writeReport([
                "stage=reason_immediate_recapture_failed",
                "reason_immediate_recapture_status=FAIL",
                "reason_immediate_recapture_summary_begin",
                recaptureReason.summary,
                "reason_immediate_recapture_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_immediate_recapture_failed")
            fflush(stdout)
            exit(14)
        }
        SimulatorStage.mark("reason_immediate_recapture_pass")

        let continuationUnstableDeepEntry = DeepAnalysisEntry(
            id: 49,
            ply: 49,
            actualMove: "4i3h",
            shallowBestMove: "3g2e",
            shallowEstimatedLossCp: 1232,
            bestMove: "3g2e",
            bestScoreText: "cp 1103",
            actualScoreText: "cp -103",
            actualLossCp: 1206,
            bestPV: "3g2e 3c2e 2g2f 3b3c 2h3i P*2d",
            actualPV: "4i3h 5b4b B*6f",
            actualAnalysisSource: "equal-condition",
            opponentBestReply: "3c2e",
            candidates: recaptureDeepEntry.candidates,
            elapsedMs: 1,
            thermalBefore: "nominal",
            thermalAfter: "nominal",
            comparisonStable: true,
            instabilityReasons: [],
            continuationStable: false,
            continuationInstabilityReasons: ["best_pv_changed"],
            analysisAttempts: 2,
            finalMovetimeMs: 1600,
            adaptiveTriggered: true,
            topCandidateGapCp: 782
        )
        let continuationUnstableReason = ReasonAnalysisViewModel()
        continuationUnstableReason.prepare(
            game: unstableGame,
            deepEntries: [continuationUnstableDeepEntry],
            diagnosticURL: boardReview.diagnosticURL
        )
        guard continuationUnstableReason.status == "理由解析 PASS",
              let continuationUnstableReasonEntry = continuationUnstableReason.entries.first,
              continuationUnstableReasonEntry.actualLossCp == 1206,
              continuationUnstableReasonEntry.interpretation.text.contains("1206cp"),
              continuationUnstableReasonEntry.interpretation.text.contains("読み筋"),
              continuationUnstableReasonEntry.interpretation.text.contains("断定しません"),
              !continuationUnstableReasonEntry.interpretation.text.contains("取り返されます"),
              continuationUnstableReasonEntry.facts.contains(where: {
                  $0.kind == "continuation_stability"
              }) else {
            writeReport([
                "stage=reason_continuation_unstable_failed",
                "reason_continuation_unstable_status=FAIL",
                "reason_continuation_unstable_summary_begin",
                continuationUnstableReason.summary,
                "reason_continuation_unstable_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("reason_continuation_unstable_failed")
            fflush(stdout)
            exit(20)
        }
        SimulatorStage.mark("reason_continuation_unstable_pass")

        let continuationSplit = ContinuationSimulationViewModel()
        continuationSplit.prepare(
            game: unstableGame,
            deepEntries: [continuationUnstableDeepEntry],
            reasonEntries: continuationUnstableReason.entries,
            diagnosticURL: continuationUnstableReason.diagnosticURL
        )
        guard continuationSplit.status == "展開シミュレーション PASS",
              let continuationSplitEntry = continuationSplit.entries.first,
              continuationSplitEntry.comparisonStable,
              !continuationSplitEntry.continuationStable,
              !continuationSplitEntry.recommended.stable,
              !continuationSplitEntry.actual.stable,
              !continuationSplitEntry.recommended.summary.isEmpty,
              continuationSplitEntry.actual.summary.contains("1206cp"),
              continuationSplitEntry.recommended.moves.allSatisfy({
                  !$0.factText.isEmpty && !$0.coachText.isEmpty
              }),
              continuationSplitEntry.actual.moves.allSatisfy({
                  !$0.factText.isEmpty && !$0.coachText.isEmpty
              }),
              let continuationSplitURL = continuationSplit.diagnosticURL,
              let continuationSplitData = try? Data(contentsOf: continuationSplitURL),
              let continuationSplitDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: continuationSplitData
              ),
              continuationSplitDiagnostic.schemaVersion == 5,
              continuationSplitDiagnostic.continuationSimulation?.positions.first?.comparisonStable == true,
              continuationSplitDiagnostic.continuationSimulation?.positions.first?.continuationStable == false else {
            writeReport([
                "stage=continuation_stability_split_failed",
                "continuation_stability_split_status=FAIL",
                "continuation_stability_split_summary_begin",
                continuationSplit.summary,
                "continuation_stability_split_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("continuation_stability_split_failed")
            fflush(stdout)
            exit(21)
        }
        SimulatorStage.mark("continuation_stability_split_pass")

        let (terminalGame, terminalShallow) = makeTerminalRegression()
        let terminalDiagnosticURL: URL
        do {
            terminalDiagnosticURL = try DiagnosticExporter.write(
                game: terminalGame,
                fileName: "terminal-81-regression.kif",
                entries: terminalShallow,
                status: "浅解析 PASS",
                requestedMoveTimeMs: 150,
                totalElapsedMs: 81,
                error: nil
            )
        } catch {
            writeReport([
                "stage=terminal_regression_failed",
                "terminal_deep_status=FAIL",
                "terminal_error=diagnostic \(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            fflush(stdout)
            exit(6)
        }

        let terminalDeep = DeepAnalysisViewModel()
        await terminalDeep.analyze(
            game: terminalGame,
            shallowEntries: terminalShallow,
            diagnosticURL: terminalDiagnosticURL,
            deepMovetimeMs: 200,
            multiPV: 3,
            maxPositions: 1
        )
        guard terminalDeep.runState.isCompleted,
              terminalDeep.entries.count == 1,
              let terminalEntry = terminalDeep.entries.first,
              terminalEntry.ply == 81,
              terminalEntry.actualMove == "G*1b",
              terminalEntry.actualAnalysisSource.hasPrefix("node-equal-condition"),
              terminalEntry.candidates.contains(where: { $0.move == "G*1b" }),
              !terminalEntry.actualPV.isEmpty else {
            writeReport([
                "stage=terminal_regression_failed",
                "terminal_deep_status=FAIL",
                "terminal_summary_begin",
                terminalDeep.summary,
                "terminal_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_regression_failed")
            fflush(stdout)
            exit(6)
        }
        let terminalActualSource = terminalEntry.actualAnalysisSource
        SimulatorStage.mark("terminal_regression_pass")

        let terminalBoardReview = BoardReviewViewModel()
        terminalBoardReview.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            diagnosticURL: terminalDeep.diagnosticURL
        )
        guard terminalBoardReview.status == "盤面表示 PASS",
              terminalBoardReview.entries.count == 1,
              let terminalBoardEntry = terminalBoardReview.entries.first,
              terminalBoardEntry.ply == 81,
              terminalBoardEntry.bestMove.isDrop,
              terminalBoardEntry.bestMove.source == nil,
              terminalBoardEntry.bestMove.dropPiece != nil,
              terminalBoardEntry.snapshot.sideToMove == .black,
              terminalBoardEntry.bestPiece == terminalBoardEntry.bestMove.dropPiece,
              let terminalBoardDiagnosticURL = terminalBoardReview.diagnosticURL,
              let terminalBoardData = try? Data(contentsOf: terminalBoardDiagnosticURL),
              let terminalBoardDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalBoardData
              ),
              terminalBoardDiagnostic.schemaVersion == 3,
              terminalBoardDiagnostic.boardDisplay?.status == "盤面表示 PASS",
              terminalBoardDiagnostic.boardDisplay?.completedPositions == 1 else {
            writeReport([
                "stage=terminal_board_failed",
                "terminal_board_status=FAIL",
                "terminal_board_summary_begin",
                terminalBoardReview.summary,
                "terminal_board_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_board_failed")
            fflush(stdout)
            exit(9)
        }
        let terminalBoardDestination = terminalBoardEntry.bestMove.destination.usi
        SimulatorStage.mark("terminal_board_pass")

        let terminalReason = ReasonAnalysisViewModel()
        terminalReason.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            diagnosticURL: terminalBoardReview.diagnosticURL
        )
        guard terminalReason.status == "理由解析 PASS",
              terminalReason.entries.count == 1,
              let terminalReasonEntry = terminalReason.entries.first,
              terminalReasonEntry.ply == 81,
              terminalReasonEntry.actualMove == "G*1b",
              !terminalReasonEntry.facts.isEmpty,
              !terminalReasonEntry.interpretation.text.isEmpty,
              let terminalReasonDiagnosticURL = terminalReason.diagnosticURL,
              let terminalReasonData = try? Data(contentsOf: terminalReasonDiagnosticURL),
              let terminalReasonDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalReasonData
              ),
              terminalReasonDiagnostic.schemaVersion == 4,
              terminalReasonDiagnostic.reasonAnalysis?.status == "理由解析 PASS",
              terminalReasonDiagnostic.reasonAnalysis?.completedPositions == 1 else {
            writeReport([
                "stage=terminal_reason_failed",
                "terminal_reason_status=FAIL",
                "terminal_reason_summary_begin",
                terminalReason.summary,
                "terminal_reason_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_reason_failed")
            fflush(stdout)
            exit(11)
        }
        SimulatorStage.mark("terminal_reason_pass")

        let terminalContinuation = ContinuationSimulationViewModel()
        terminalContinuation.prepare(
            game: terminalGame,
            deepEntries: terminalDeep.entries,
            reasonEntries: terminalReason.entries,
            diagnosticURL: terminalReason.diagnosticURL
        )
        guard terminalContinuation.status == "展開シミュレーション PASS",
              terminalContinuation.entries.count == 1,
              let terminalContinuationEntry = terminalContinuation.entries.first,
              let terminalActualFirst = terminalContinuationEntry.actual.moves.first,
              terminalActualFirst.usi == "G*1b",
              terminalActualFirst.effect.isDrop,
              terminalActualFirst.effect.source == nil,
              terminalActualFirst.effect.destination.usi == "1b",
              !terminalContinuationEntry.actual.targetShapeSummary.isEmpty else {
            writeReport([
                "stage=terminal_continuation_failed",
                "terminal_continuation_status=FAIL",
                "terminal_continuation_summary_begin",
                terminalContinuation.summary,
                "terminal_continuation_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_continuation_failed")
            fflush(stdout)
            exit(16)
        }
        SimulatorStage.mark("terminal_continuation_pass")

        let terminalPhaseReview = PhaseReviewViewModel()
        terminalPhaseReview.prepare(
            game: terminalGame,
            shallowEntries: terminalShallow,
            deepEntries: terminalDeep.entries,
            reasonEntries: terminalReason.entries,
            continuationEntries: terminalContinuation.entries,
            diagnosticURL: terminalContinuation.diagnosticURL
        )
        let terminalPhaseKinds = Set(terminalPhaseReview.sections.map(\.kind))
        let terminalPhaseAllThree = terminalPhaseKinds
            == Set([GamePhaseKind.opening, .middlegame, .endgame])
        guard terminalPhaseReview.status == "フェーズ別振り返り PASS",
              terminalPhaseAllThree,
              terminalPhaseReview.sections.count == 3,
              terminalPhaseReview.sections[0].kind == .opening,
              terminalPhaseReview.sections[1].kind == .middlegame,
              terminalPhaseReview.sections[2].kind == .endgame,
              terminalPhaseReview.sections[0].endPly < terminalPhaseReview.sections[1].startPly,
              terminalPhaseReview.sections[1].endPly < terminalPhaseReview.sections[2].startPly,
              terminalPhaseReview.sections.allSatisfy({
                  !$0.themeTitle.isEmpty
                      && !$0.themeDetail.isEmpty
                      && !$0.nextCheckText.isEmpty
                      && $0.points.filter { $0.kind == .important }.count <= 1
              }),
              let terminalPhaseURL = terminalPhaseReview.diagnosticURL,
              let terminalPhaseData = try? Data(contentsOf: terminalPhaseURL),
              let terminalPhaseDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: terminalPhaseData
              ),
              terminalPhaseDiagnostic.schemaVersion == 7,
              terminalPhaseDiagnostic.phaseAnalysis?.usedAdditionalEngineSearch == false else {
            writeReport([
                "stage=terminal_phase_failed",
                "terminal_phase_status=FAIL",
                "terminal_phase_summary_begin",
                terminalPhaseReview.summary,
                "terminal_phase_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("terminal_phase_failed")
            fflush(stdout)
            exit(18)
        }
        SimulatorStage.mark("terminal_phase_pass")

        let dropSearchSession = EngineUSISession()
        var dropSearchStatus = "FAIL"
        do {
            try await dropSearchSession.beginAnalysis(multiPV: 1)
            guard let finalMove = terminalGame.moves.last else {
                throw EngineUSISession.ProbeError.protocolError("terminal move missing")
            }
            let dropSample = try await dropSearchSession.analyzePosition(
                command: finalMove.positionBefore,
                movetimeMs: 200,
                searchMoves: [finalMove.usi]
            )
            await dropSearchSession.endAnalysis()
            guard finalMove.usi == "G*1b",
                  dropSample.result.bestMove.move == finalMove.usi,
                  let dropPV = dropSample.result.principalVariations.first,
                  !dropPV.pv.isEmpty,
                  dropPV.pv.first == finalMove.usi else {
                throw EngineUSISession.ProbeError.protocolError(
                    "drop searchmoves was not enforced"
                )
            }
            dropSearchStatus = "PASS"
            SimulatorStage.mark("drop_searchmoves_pass")
        } catch {
            await dropSearchSession.endAnalysis()
            writeReport([
                "stage=drop_searchmoves_failed",
                "drop_searchmoves_status=FAIL",
                "drop_searchmoves_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("drop_searchmoves_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(7)
        }

        let qualityGate: AnalysisQualityGateResult
        do {
            qualityGate = try await runAnalysisQualityGate(terminalGame: terminalGame)
            SimulatorStage.mark("analysis_quality_gate_pass")
        } catch {
            writeReport([
                "stage=analysis_quality_gate_failed",
                "analysis_quality_gate_status=FAIL",
                "analysis_quality_gate_error=\(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("analysis_quality_gate_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(13)
        }

        let (hdsGame, hdsShallow) = makeHDSRegression()
        let hdsDiagnosticURL: URL
        do {
            hdsDiagnosticURL = try DiagnosticExporter.write(
                game: hdsGame,
                fileName: "hds-41-49-69-regression.kif",
                entries: hdsShallow,
                status: "浅解析 PASS",
                requestedMoveTimeMs: 1,
                totalElapsedMs: 81,
                error: nil
            )
        } catch {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=diagnostic \(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_diagnostic_failed")
            fflush(stdout)
            exit(30)
        }

        let hdsDeep = DeepAnalysisViewModel()
        await hdsDeep.analyze(
            game: hdsGame,
            shallowEntries: hdsShallow,
            diagnosticURL: hdsDiagnosticURL,
            deepMovetimeMs: 800,
            multiPV: 3,
            maxPositions: 3
        )
        let hdsPlies = hdsDeep.entries.map(\.ply)
        guard hdsDeep.status == "深掘り PASS",
              hdsPlies == [41, 49, 69] else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=real-position selection mismatch",
                "hds_m_deep_status=\(hdsDeep.status)",
                "hds_m_plies=\(hdsPlies.map(String.init).joined(separator: ","))",
                "hds_m_deep_summary_begin",
                hdsDeep.summary,
                "hds_m_deep_summary_end"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_deep_failed")
            fflush(stdout)
            exit(31)
        }

        let hdsBoard = BoardReviewViewModel()
        hdsBoard.prepare(
            game: hdsGame,
            deepEntries: hdsDeep.entries,
            diagnosticURL: hdsDeep.diagnosticURL
        )
        guard hdsBoard.status == "盤面表示 PASS" else {
            writeReport(["stage=hds_m_failed", "hds_m_status=FAIL", "hds_m_error=board review"].joined(separator: "\n") + "\n") 
            SimulatorStage.mark("hds_m_board_failed")
            fflush(stdout)
            exit(32)
        }

        let hdsReason = ReasonAnalysisViewModel()
        hdsReason.prepare(
            game: hdsGame,
            deepEntries: hdsDeep.entries,
            diagnosticURL: hdsBoard.diagnosticURL
        )
        guard hdsReason.status == "理由解析 PASS" else {
            writeReport(["stage=hds_m_failed", "hds_m_status=FAIL", "hds_m_error=reason analysis"].joined(separator: "\n") + "\n") 
            SimulatorStage.mark("hds_m_reason_failed")
            fflush(stdout)
            exit(33)
        }

        let hdsContinuation = ContinuationSimulationViewModel()
        hdsContinuation.prepare(
            game: hdsGame,
            deepEntries: hdsDeep.entries,
            reasonEntries: hdsReason.entries,
            diagnosticURL: hdsReason.diagnosticURL
        )
        guard hdsContinuation.status == "展開シミュレーション PASS",
              hdsContinuation.entries.map(\.ply) == [41, 49, 69] else {
            writeReport(["stage=hds_m_failed", "hds_m_status=FAIL", "hds_m_error=continuation simulation"].joined(separator: "\n") + "\n") 
            SimulatorStage.mark("hds_m_continuation_failed")
            fflush(stdout)
            exit(34)
        }

        let hdsLiveNonStablePlies = Set(
            hdsDeep.entries.filter { !$0.comparisonStable }.map(\.ply)
        )
        let hdsLiveNonStableValid = hdsLiveNonStablePlies.allSatisfy { ply in
            guard let deepEntry = hdsDeep.entries.first(where: { $0.ply == ply }),
                  let item = hdsContinuation.entries.first(where: { $0.ply == ply }) else { return false }
            let presentation = RecommendationDecisionPresentation.make(entry: item)
            return deepEntry.actualLossCp == nil
                && !item.comparisonStable
                && presentation.status == .provisional
        }
        guard hdsLiveNonStableValid else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=live unstable propagation"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_live_unstable_propagation_failed")
            fflush(stdout)
            exit(35)
        }

        // Live replay verifies that the real positions can flow through the current engine
        // and all HDS gates. Exact best moves are intentionally not frozen because a
        // time-limited search can legitimately return a different top candidate.
        let hdsLiveReport = RecommendationDecisionHDSAudit.evaluate(entries: hdsContinuation.entries)
        do {
            try RecommendationDecisionPolicyAudit.validate(entries: hdsContinuation.entries)
        } catch {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=live policy \(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_live_policy_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(35)
        }
        guard hdsLiveReport.passed else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=live gate result"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_live_gate_failed")
            fflush(stdout)
            exit(36)
        }

        // Frozen semantic evidence is sourced from the user-reviewed 2026-10-07
        // diagnostic. It guarantees regression coverage for the exact 41/49/69
        // corrective cases independently of live-search ordering noise.
        let hdsFrozenDeep = makeFrozenHDSSemanticEntries()
        let hdsFrozenReason = ReasonAnalysisViewModel()
        hdsFrozenReason.prepare(
            game: hdsGame,
            deepEntries: hdsFrozenDeep,
            diagnosticURL: hdsDiagnosticURL
        )
        guard hdsFrozenReason.status == "理由解析 PASS" else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=frozen reason analysis"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_frozen_reason_failed")
            fflush(stdout)
            exit(38)
        }

        let hdsFrozenContinuation = ContinuationSimulationViewModel()
        hdsFrozenContinuation.prepare(
            game: hdsGame,
            deepEntries: hdsFrozenDeep,
            reasonEntries: hdsFrozenReason.entries,
            diagnosticURL: hdsFrozenReason.diagnosticURL
        )
        guard hdsFrozenContinuation.status == "展開シミュレーション PASS",
              hdsFrozenContinuation.entries.map(\.ply) == [41, 49, 69] else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=frozen continuation simulation"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_frozen_continuation_failed")
            fflush(stdout)
            exit(39)
        }

        let hdsReport = RecommendationDecisionHDSAudit.evaluate(entries: hdsFrozenContinuation.entries)
        do {
            try writeHDSMachineReport(hdsReport, entries: hdsFrozenContinuation.entries)
            try RecommendationDecisionPolicyAudit.validate(entries: hdsFrozenContinuation.entries)
        } catch {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=frozen policy \(error.localizedDescription)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_frozen_policy_failed_\(error.localizedDescription)")
            fflush(stdout)
            exit(40)
        }

        guard hdsReport.passed,
              let hds41 = hdsFrozenContinuation.entries.first(where: { $0.ply == 41 }),
              let hds49 = hdsFrozenContinuation.entries.first(where: { $0.ply == 49 }),
              let hds69 = hdsFrozenContinuation.entries.first(where: { $0.ply == 69 }) else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=frozen gate result"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_frozen_gate_failed")
            fflush(stdout)
            exit(41)
        }

        let hds41Presentation = RecommendationDecisionPresentation.make(entry: hds41)
        let hds49Presentation = RecommendationDecisionPresentation.make(entry: hds49)
        let hds69Presentation = RecommendationDecisionPresentation.make(entry: hds69)
        guard hds41.recommended.moves.first?.usi == "4g4f",
              hds41Presentation.status == .recommended,
              hds41Presentation.difference.contains("実戦"),
              !hds41Presentation.meaning.contains("この手単独では狙いを断定できません"),
              hds49.recommended.moves.first?.usi == "3g2e",
              hds49Presentation.status == .recommended,
              hds49Presentation.meaning.contains("取り返され"),
              hds49Presentation.meaning.contains("角"),
              hds69.recommended.moves.first?.usi == "2g3h",
              !hds69.comparisonStable,
              hds69Presentation.status == .provisional,
              hds69Presentation.headline.contains("暫定候補"),
              !hds69Presentation.headline.contains("推奨") else {
            writeReport([
                "stage=hds_m_failed",
                "hds_m_status=FAIL",
                "hds_m_error=frozen target semantic regression",
                "hds_m_41_best=\(hds41.recommended.moves.first?.usi ?? "-")",
                "hds_m_49_best=\(hds49.recommended.moves.first?.usi ?? "-")",
                "hds_m_69_best=\(hds69.recommended.moves.first?.usi ?? "-")",
                "hds_m_69_comparison_stable=\(hds69.comparisonStable)"
            ].joined(separator: "\n") + "\n")
            SimulatorStage.mark("hds_m_frozen_target_semantics_failed")
            fflush(stdout)
            exit(42)
        }
        SimulatorStage.mark("hds_m_live_and_frozen_pass_41_49_69")

        let probe = EngineProbe()
        await probe.runDefaultProbe()
        let defaultStatus = probe.status
        let defaultResult = probe.resultText
        writeReport([
            "stage=default_done",
            "default_status=\(defaultStatus)",
            "default_result_begin",
            defaultResult,
            "default_result_end"
        ].joined(separator: "\n") + "\n")

        await probe.runTenProbe()
        let tenStatus = probe.status
        let tenResult = probe.resultText

        let report = [
            "stage=complete",
            "kif_status=PASS",
            "kif_moves=\(kifGame.moves.count)",
            "shallow_status=PASS",
            "shallow_count=\(shallowCount)",
            "diagnostic_status=PASS",
            "diagnostic_schema=\(diagnostic.schemaVersion)",
            "diagnostic_positions=\(diagnostic.positions.count)",
            "diagnostic_version=\(diagnostic.app.version)",
            "diagnostic_build=\(diagnostic.app.build)",
            "diagnostic_git=\(diagnostic.app.gitCommit)",
            "deep_status=\(deepStatus)",
            "deep_display_status=\(deep.displayStatus)",
            "deep_count=\(deepCount)",
            "deep_stable_count=\(deep.runState.completionCounts?.stable ?? -1)",
            "deep_unstable_count=\(deep.runState.completionCounts?.unstable ?? -1)",
            "deep_unconfirmed_count=\(deep.runState.completionCounts?.unconfirmed ?? -1)",
            "deep_negative_contract_status=PASS",
            "deep_nonstable_suppression_status=PASS",
            "deep_stability_by_ply=\(deep.entries.map { "#\($0.ply):\($0.stabilityState):\($0.instabilityReasons.joined(separator: ","))" }.joined(separator: ";"))",
            "deep_multipv=\(deepDiagnostic.deepAnalysis?.multiPV ?? 0)",
            "deep_adaptive_policy=\(deepDiagnostic.deepAnalysis?.adaptivePolicy ?? "-")",
            "deep_diagnostic_schema=\(deepDiagnostic.schemaVersion)",
            "board_display_status=\(boardDisplayStatus)",
            "board_display_count=\(boardDisplayCount)",
            "board_display_schema=\(boardDiagnostic.schemaVersion)",
            "reason_status=\(reasonStatus)",
            "reason_count=\(reasonCount)",
            "reason_schema=\(reasonDiagnostic.schemaVersion)",
            "reason_unstable_status=PASS",
            "reason_immediate_recapture_status=PASS",
            "reason_continuation_unstable_status=PASS",
            "continuation_stability_split_status=PASS",
            "board_first_review_status=PASS",
            "coaching_semantics_status=PASS",
            "phase_coaching_status=PASS",
            "continuation_status=\(continuationStatus)",
            "continuation_count=\(continuationCount)",
            "continuation_schema=5",
            "phase_status=\(phaseStatus)",
            "phase_schema=7",
            "phase_additional_engine=false",
            "context_status=\(contextStatus)",
            "context_count=\(contextCount)",
            "context_schema=\(contextDiagnostic.schemaVersion)",
            "context_additional_engine=\(contextReview.usedAdditionalEngineSearch)",
            "context_refinement_policy=\(ContextAnalysisViewModel.refinementPolicy)",
            "context_refinement_candidates=\(contextReview.refinementCandidatePlies.count)",
            "context_refinement_completed=\(contextReview.refinementCompletedPlies.count)",
            "context_refinement_confidence_changed=\(contextReview.refinementConfidenceChangedCount)",
            "context_refinement_intent_changed=\(contextReview.refinementIntentChangedCount)",
            "context_selective_refinement_status=PASS",
            "context_selective_refinement_unresolved=true",
            "context_semantics_status=PASS",
            "context_rook_pawn_intent=\(rookPawnRegression.selectedIntent.rawValue)",
            "context_bishop_line_intent=\(bishopLineRegression.selectedIntent.rawValue)",
            "context_geometry_primary=\(geometryRegression.selectedIntent == .attackPreparation)",
            "context_knowledge_status=PASS",
            "context_knowledge_load=\(knowledgeRuntime.loadStatus)",
            "context_knowledge_source=\(knowledgeRuntime.sourceIDs.joined(separator: ","))",
            "context_knowledge_records=\(knowledgeRuntime.recordCount)",
            "context_knowledge_target_observations=12",
            "context_knowledge_target_intent=\(knowledgeRookRegression.selectedIntent.rawValue)",
            "context_knowledge_target_precedent=true",
            "context_explanation_status=PASS",
            "context_explanation_target_conclusion=\(targetContextPosition.explanation.conclusion)",
            "context_explanation_target_confidence=\(targetContextPosition.explanation.confidence.rawValue)",
            "context_explanation_target_tone=\(targetContextPosition.explanation.tone.rawValue)",
            "context_explanation_geometry_language=false",
            "context_recommended_explanation_status=PASS",
            "context_recommended_explanation_count=\(contextReview.recommendedExplanations.count)",
            "terminal_deep_status=\(terminalDeep.status)",
            "terminal_deep_ply=\(terminalEntry.ply)",
            "terminal_actual_source=\(terminalActualSource)",
            "terminal_board_status=\(terminalBoardReview.status)",
            "terminal_board_is_drop=\(terminalBoardEntry.bestMove.isDrop)",
            "terminal_board_destination=\(terminalBoardDestination)",
            "terminal_reason_status=\(terminalReason.status)",
            "terminal_reason_ply=\(terminalReasonEntry.ply)",
            "terminal_continuation_status=\(terminalContinuation.status)",
            "terminal_continuation_drop=\(terminalContinuationEntry.actual.moves.first?.effect.isDrop ?? false)",
            "terminal_phase_status=\(terminalPhaseReview.status)",
            "terminal_phase_all_three=\(terminalPhaseAllThree)",
            "drop_searchmoves_status=\(dropSearchStatus)",
            "analysis_quality_gate_status=PASS",
            "quality_normal_stable=\(qualityGate.normalStable)",
            "quality_normal_comparison_stable=\(qualityGate.normalComparisonStable)",
            "quality_normal_continuation_stable=\(qualityGate.normalContinuationStable)",
            "quality_normal_attempts=\(qualityGate.normalAttempts)",
            "quality_close_gap_cp=\(qualityGate.closeGapCp.map(String.init) ?? "-")",
            "quality_close_attempts=\(qualityGate.closeAttempts)",
            "quality_terminal_stable=\(qualityGate.terminalStable)",
            "quality_terminal_comparison_stable=\(qualityGate.terminalComparisonStable)",
            "quality_terminal_continuation_stable=\(qualityGate.terminalContinuationStable)",
            "quality_terminal_attempts=\(qualityGate.terminalAttempts)",
            "quality_terminal_bestmove=\(qualityGate.terminalBestMove)",
            "hds_live_status=PASS",
            "hds_live_41_best=\(hdsContinuation.entries.first(where: { $0.ply == 41 })?.recommended.moves.first?.usi ?? "-")",
            "hds_live_49_best=\(hdsContinuation.entries.first(where: { $0.ply == 49 })?.recommended.moves.first?.usi ?? "-")",
            "hds_live_69_best=\(hdsContinuation.entries.first(where: { $0.ply == 69 })?.recommended.moves.first?.usi ?? "-")",
            "hds_m_status=PASS",
            "hds_m_schema=HDS-M-2.0",
            "hds_m_positions=41,49,69",
            "hds_m_41_status=\(hdsStatusText(hds41Presentation.status))",
            "hds_m_41_best=\(hds41.recommended.moves.first?.usi ?? "-")",
            "hds_m_49_status=\(hdsStatusText(hds49Presentation.status))",
            "hds_m_49_best=\(hds49.recommended.moves.first?.usi ?? "-")",
            "hds_m_69_status=\(hdsStatusText(hds69Presentation.status))",
            "hds_m_69_best=\(hds69.recommended.moves.first?.usi ?? "-")",
            "hds_m_69_comparison_stable=\(hds69.comparisonStable)",
            "deep_summary_begin",
            deep.summary,
            "deep_summary_end",
            "shallow_summary_begin",
            shallow.summary,
            "shallow_summary_end",
            "default_status=\(defaultStatus)",
            "default_result_begin",
            defaultResult,
            "default_result_end",
            "ten_status=\(tenStatus)",
            "ten_result_begin",
            tenResult,
            "ten_result_end"
        ].joined(separator: "\n") + "\n"

        writeReport(report)
        SimulatorStage.mark("probe_complete")
        fflush(stdout)
        exit(0)
    }
}
#else
enum SimulatorCIProbe {
    static func runIfRequested() async {}
}
#endif


private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
