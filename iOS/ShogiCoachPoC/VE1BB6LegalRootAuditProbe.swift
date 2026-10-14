import Foundation

#if targetEnvironment(simulator)

enum VE1BB6LegalRootAuditProbe {
    private static let argument = "--ci-ve1b-b6-legal-root-audit"

    private struct Input: Decodable {
        let schemaVersion: String
        let authorityBase: String
        let inputSHA256: String
        let uniquePositionCount: Int
        let standardAttemptCount: Int
        let stressAttemptCount: Int
        let totalAttemptCount: Int
        let positions: [PositionInput]
    }

    private struct PositionInput: Decodable {
        let ply: Int
        let positionCommand: String
        let standardAttemptCount: Int
        let stressAttemptCount: Int
        let totalAttemptCount: Int
    }

    private struct PositionResult: Codable {
        let ply: Int
        let legalRootMoveCount: Int
        let standardAttemptCount: Int
        let stressAttemptCount: Int
        let totalAttemptCount: Int
        let affectedAttemptCount: Int
    }

    private struct Report: Codable {
        let schemaVersion: Int
        let status: String
        let authorityBase: String
        let inputSHA256: String
        let rootMoveGenerator: String
        let uniquePositionCount: Int
        let standardAttemptCount: Int
        let stressAttemptCount: Int
        let totalAttemptCount: Int
        let affectedStandardAttemptCount: Int
        let affectedStressAttemptCount: Int
        let affectedTotalAttemptCount: Int
        let minimumLegalRootMoveCount: Int
        let positions: [PositionResult]
        let failureReasons: [String]
    }

    static func runIfRequested() async {
        guard ProcessInfo.processInfo.arguments.contains(argument) else { return }

        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let inputURL = directory.appendingPathComponent("ve1b-b6-legal-root-audit-input.json")
        let outputURL = directory.appendingPathComponent("ve1b-b6-legal-root-audit.json")
        let errorURL = directory.appendingPathComponent("ve1b-b6-legal-root-audit-error.txt")

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let input = try decoder.decode(Input.self, from: Data(contentsOf: inputURL))
            guard input.schemaVersion == "ve1b-b6-legal-root-audit-input-v2",
                  input.authorityBase == "8daf78caa2bd5919cc911da21bae80fa3d12a248",
                  input.uniquePositionCount == 9,
                  input.positions.count == 9,
                  input.standardAttemptCount == 315,
                  input.stressAttemptCount == 189,
                  input.totalAttemptCount == 504 else {
                throw EngineUSISession.ProbeError.protocolError("B6 legal-root audit input contract mismatch")
            }

            let link = LocalUSITransport()
            try await link.start()
            defer { Task { await link.close() } }
            try await link.send("usi")
            _ = try await link.readUntil({ $0 == "usiok" }, timeoutSeconds: 5, label: "b6-legal-audit-usiok")

            let sortedInputs = input.positions.sorted(by: { $0.ply < $1.ply })
            var positionResults: [PositionResult] = []
            var failureReasons: [String] = []
            for position in sortedInputs {
                try await link.send(position.positionCommand)
                try await link.send("ve1b_legal_move_count")
                let line = try await link.readUntil(
                    { $0.hasPrefix("info string ve1b_legal_move_count ") },
                    timeoutSeconds: 2,
                    label: "b6-legal-audit-ply-\(position.ply)"
                )
                guard let count = Int(line.split(separator: " ").last ?? "") else {
                    throw EngineUSISession.ProbeError.protocolError("invalid legal-count response at ply \(position.ply)")
                }
                let affected = count < 3 ? position.totalAttemptCount : 0
                if affected > 0 {
                    failureReasons.append("PLY_\(position.ply)_LEGAL_ROOT_COUNT_\(count)_AFFECTS_\(affected)_ATTEMPTS")
                }
                positionResults.append(
                    PositionResult(
                        ply: position.ply,
                        legalRootMoveCount: count,
                        standardAttemptCount: position.standardAttemptCount,
                        stressAttemptCount: position.stressAttemptCount,
                        totalAttemptCount: position.totalAttemptCount,
                        affectedAttemptCount: affected
                    )
                )
            }

            let affectedStandard = zip(sortedInputs, positionResults)
                .reduce(0) { $0 + ($1.1.legalRootMoveCount < 3 ? $1.0.standardAttemptCount : 0) }
            let affectedStress = zip(sortedInputs, positionResults)
                .reduce(0) { $0 + ($1.1.legalRootMoveCount < 3 ? $1.0.stressAttemptCount : 0) }
            let minimum = positionResults.map(\.legalRootMoveCount).min() ?? 0
            let report = Report(
                schemaVersion: 1,
                status: failureReasons.isEmpty ? "PASS" : "FAIL",
                authorityBase: input.authorityBase,
                inputSHA256: input.inputSHA256,
                rootMoveGenerator: "YaneuraOu MoveList<LEGAL>",
                uniquePositionCount: positionResults.count,
                standardAttemptCount: input.standardAttemptCount,
                stressAttemptCount: input.stressAttemptCount,
                totalAttemptCount: input.totalAttemptCount,
                affectedStandardAttemptCount: affectedStandard,
                affectedStressAttemptCount: affectedStress,
                affectedTotalAttemptCount: affectedStandard + affectedStress,
                minimumLegalRootMoveCount: minimum,
                positions: positionResults,
                failureReasons: failureReasons
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(report).write(to: outputURL, options: .atomic)
            if report.status != "PASS" {
                try failureReasons.joined(separator: "\n").write(to: errorURL, atomically: true, encoding: .utf8)
            }
            try? await link.send("quit")
        } catch {
            try? String(describing: error).write(to: errorURL, atomically: true, encoding: .utf8)
        }
    }
}

#endif
