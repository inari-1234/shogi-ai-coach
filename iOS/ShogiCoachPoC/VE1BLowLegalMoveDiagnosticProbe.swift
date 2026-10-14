import Foundation
import ShogiCoachCore

#if targetEnvironment(simulator)

enum VE1BLowLegalMoveDiagnosticProbe {
    private static let argument = "--ci-ve1b-low-legal-move-diagnostic"
    private static let expectedGameSHA256 = "a3ea21dba4d3395d569d846b8cb119452fad0cedbf690eb72a29976918a8702a"
    private static let failedPly = 126
    private static let nodeBudget = 50_000
    private static let configuredMultiPV = 3

    private struct Report: Codable {
        let schemaVersion: Int
        let status: String
        let authorityBase: String
        let gameSHA256: String
        let ply: Int
        let actualMove: String
        let positionCommand: String
        let configuredMultiPV: Int
        let legalRootMoveCount: Int
        let maxObservedNodes: UInt64
        let bestmoveLine: String?
        let scoredPVBearingMultiPV3Count: Int
        let observedMultiPVRanks: [Int]
        let frozenRequired3SnapshotExists: Bool
        let frozenCompletion: String
        let rawUSI: [String]
        let failureReasons: [String]
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inputURL = directory
            .appendingPathComponent("ve1b-low-legal-move-diagnostic", isDirectory: true)
            .appendingPathComponent("rank2.kif")
        let outputURL = directory.appendingPathComponent("ve1b-low-legal-move-diagnostic.json")
        let errorURL = directory.appendingPathComponent("ve1b-low-legal-move-diagnostic-error.txt")

        do {
            // The workflow independently verifies the physical KIF SHA-256 before
            // installing it into the Simulator container. Keep the expected digest
            // in the report to bind this diagnostic to that preverified fixture.
            let input = try Data(contentsOf: inputURL)
            let game = try KIFParser.parse(data: input)
            guard let failedMove = game.moves.first(where: { $0.ply == failedPly }) else {
                throw EngineUSISession.ProbeError.protocolError("failed ply 126 not found")
            }

            let link = LocalUSITransport()
            try await link.start()
            defer { Task { await link.close() } }

            let verifiedNNUE = try EngineRuntimeIdentity.verifyBundledNNUE()
            let evalURL = verifiedNNUE.url

            try await link.send("usi")
            _ = try await link.readUntil({ $0 == "usiok" }, timeoutSeconds: 5, label: "diag-usiok")
            try await link.send("setoption name Threads value 1")
            try await link.send("setoption name USI_Hash value 64")
            try await link.send("setoption name MultiPV value 3")
            try await link.send("setoption name FV_SCALE value \(EngineRuntimeAuthority.fvScale)")
            try await link.send("setoption name PvInterval value \(VE1BEngineEvidenceAuthority.pvIntervalMs)")
            try await link.send("setoption name BookFile value no_book")
            try await link.send("setoption name EvalDir value \(evalURL.deletingLastPathComponent().path)")
            try await link.send("isready")
            _ = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "diag-readyok-initial")
            try await link.send("usinewgame")

            // Match the frozen candidate-discovery cold logical boundary.
            try await link.send("isready")
            _ = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "diag-readyok-cold")
            try await link.send("usinewgame")
            try await link.send(failedMove.positionBefore)

            // Deterministic position-derived count from YaneuraOu MoveList<LEGAL>.
            try await link.send("ve1b_legal_move_count")
            let legalLine = try await link.readUntil(
                { $0.hasPrefix("info string ve1b_legal_move_count ") },
                timeoutSeconds: 2,
                label: "diag-legal-count"
            )
            guard let legalRootMoveCount = Int(legalLine.split(separator: " ").last ?? "") else {
                throw EngineUSISession.ProbeError.protocolError("invalid legal-count response: \(legalLine)")
            }

            try await link.send("go nodes \(nodeBudget)")
            var rawUSI: [String] = []
            var observations: [USIInfo] = []
            var maxObservedNodes: UInt64 = 0
            var bestmoveLine: String?
            let deadline = ContinuousClock.now.advanced(by: .seconds(20))

            while ContinuousClock.now < deadline {
                let remaining = ContinuousClock.now.duration(to: deadline)
                let line = try await link.nextLine(timeout: remaining, label: "diag-bestmove")
                rawUSI.append(line)
                if let info = USIParser.parseInfo(line), !line.hasPrefix("info string ") {
                    observations.append(info)
                    if let nodes = info.nodes {
                        maxObservedNodes = max(maxObservedNodes, nodes)
                    }
                }
                if line.hasPrefix("bestmove ") {
                    bestmoveLine = line
                    break
                }
            }

            guard bestmoveLine != nil else {
                throw EngineUSISession.ProbeError.timeout("diag-bestmove")
            }

            let scoredPVBearingMultiPV3Count = observations.filter {
                $0.multipv == 3 && $0.score != nil && !$0.pv.isEmpty
            }.count
            let observedRanks = Array(Set(observations.compactMap { info -> Int? in
                guard info.score != nil, !info.pv.isEmpty else { return nil }
                return info.multipv
            })).sorted()
            let snapshot = USICompletedIterationSelector.deepestExactSnapshot(
                observations: observations,
                requiredMultiPV: configuredMultiPV
            )

            var reasons: [String] = []
            if legalRootMoveCount >= configuredMultiPV {
                reasons.append("FAILED_POSITION_HAS_AT_LEAST_CONFIGURED_MULTIPV_LEGAL_MOVES")
            }
            if scoredPVBearingMultiPV3Count != 0 {
                reasons.append("RAW_USI_CONTAINS_MULTIPV3")
            }
            if maxObservedNodes < UInt64(nodeBudget) {
                reasons.append("NODE_BUDGET_NOT_REACHED")
            }
            if snapshot != nil {
                reasons.append("FROZEN_REQUIRED3_SNAPSHOT_EXISTS")
            }

            let frozenCompletion = maxObservedNodes >= UInt64(nodeBudget) && snapshot == nil
                ? EngineNodeSearchCompletion.noCompletedExactIteration.rawValue
                : "other"
            let report = Report(
                schemaVersion: 1,
                status: reasons.isEmpty ? "PASS" : "FAIL",
                authorityBase: "8daf78caa2bd5919cc911da21bae80fa3d12a248",
                gameSHA256: expectedGameSHA256,
                ply: failedMove.ply,
                actualMove: failedMove.usi,
                positionCommand: failedMove.positionBefore,
                configuredMultiPV: configuredMultiPV,
                legalRootMoveCount: legalRootMoveCount,
                maxObservedNodes: maxObservedNodes,
                bestmoveLine: bestmoveLine,
                scoredPVBearingMultiPV3Count: scoredPVBearingMultiPV3Count,
                observedMultiPVRanks: observedRanks,
                frozenRequired3SnapshotExists: snapshot != nil,
                frozenCompletion: frozenCompletion,
                rawUSI: rawUSI,
                failureReasons: reasons
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(report).write(to: outputURL, options: .atomic)
            if report.status != "PASS" {
                try reasons.joined(separator: "\n").write(to: errorURL, atomically: true, encoding: .utf8)
            }
            try? await link.send("quit")
        } catch {
            try? String(describing: error).write(to: errorURL, atomically: true, encoding: .utf8)
        }
    }
}

#endif
