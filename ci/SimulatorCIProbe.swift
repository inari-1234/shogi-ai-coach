import Foundation
import ShogiCoachCore

enum SimulatorStage {
    private static let lock = NSLock()

    private static var url: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("engine-stage.txt")
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
}

#if targetEnvironment(simulator)
import Darwin

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
        2 ３四歩(33)
        3 ２六歩(27)
        4 ８四歩(83)
        5 投了
        """
        let game = try KIFParser.parse(sample)
        guard game.moves.map(\.usi) == ["7g7f", "3c3d", "2g2f", "8c8d"],
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
              diagnostic.app.version == "0.6.0",
              diagnostic.app.build == "8",
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
                && !$0.actualPV.isEmpty
                && $0.candidates.allSatisfy { !$0.pv.isEmpty && !$0.move.isEmpty }
        }
        guard deepStatus == "深掘り PASS",
              deepCount == 3,
              deepValid,
              let deepDiagnosticURL = deep.diagnosticURL,
              let deepDiagnosticData = try? Data(contentsOf: deepDiagnosticURL),
              let deepDiagnostic = try? JSONDecoder.iso8601.decode(
                ShogiDiagnosticDocument.self,
                from: deepDiagnosticData
              ),
              deepDiagnostic.schemaVersion == 2,
              deepDiagnostic.app.version == "0.6.0",
              deepDiagnostic.app.build == "8",
              deepDiagnostic.deepAnalysis?.status == "深掘り PASS",
              deepDiagnostic.deepAnalysis?.multiPV == 3,
              deepDiagnostic.deepAnalysis?.completedPositions == 3,
              deepDiagnostic.deepAnalysis?.positions.count == 3 else {
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
              boardDiagnostic.app.version == "0.6.0",
              boardDiagnostic.app.build == "8",
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
            let factIDs = Set(entry.facts.map(\.id))
            let validLevels = entry.facts.allSatisfy {
                $0.level == .engineConfirmed || $0.level == .pvObserved
            }
            let linkedInterpretation = !entry.interpretation.evidenceFactIDs.isEmpty
                && entry.interpretation.evidenceFactIDs.allSatisfy { factIDs.contains($0) }
            return entry.facts.count >= 4
                && validLevels
                && linkedInterpretation
                && !entry.bestPV.isEmpty
                && !entry.actualPV.isEmpty
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
              reasonDiagnostic.app.version == "0.6.0",
              reasonDiagnostic.app.build == "8",
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
        SimulatorStage.mark("reason_analysis_pass")

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
        guard terminalDeep.status == "深掘り PASS",
              terminalDeep.entries.count == 1,
              let terminalEntry = terminalDeep.entries.first,
              terminalEntry.ply == 81,
              terminalEntry.actualMove == "G*1b",
              terminalEntry.actualAnalysisSource == "multipv",
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
            "deep_count=\(deepCount)",
            "deep_multipv=\(deepDiagnostic.deepAnalysis?.multiPV ?? 0)",
            "deep_diagnostic_schema=\(deepDiagnostic.schemaVersion)",
            "board_display_status=\(boardDisplayStatus)",
            "board_display_count=\(boardDisplayCount)",
            "board_display_schema=\(boardDiagnostic.schemaVersion)",
            "reason_status=\(reasonStatus)",
            "reason_count=\(reasonCount)",
            "reason_schema=\(reasonDiagnostic.schemaVersion)",
            "terminal_deep_status=\(terminalDeep.status)",
            "terminal_deep_ply=\(terminalEntry.ply)",
            "terminal_actual_source=\(terminalActualSource)",
            "terminal_board_status=\(terminalBoardReview.status)",
            "terminal_board_is_drop=\(terminalBoardEntry.bestMove.isDrop)",
            "terminal_board_destination=\(terminalBoardDestination)",
            "terminal_reason_status=\(terminalReason.status)",
            "terminal_reason_ply=\(terminalReasonEntry.ply)",
            "drop_searchmoves_status=\(dropSearchStatus)",
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
