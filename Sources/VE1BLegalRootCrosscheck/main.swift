import Foundation
import ShogiCoachCore

private struct NativeReport: Decodable {
    let status: String
    let authorityBase: String
    let engineCommit: String
    let inputSHA256: String
    let uniquePositionCount: Int
    let standardAttemptCount: Int
    let stressAttemptCount: Int
    let totalAttemptCount: Int
    let positions: [NativePosition]
}

private struct NativePosition: Decodable {
    let ply: Int
    let positionCommand: String
    let legalRootMoveCount: Int
    let legalAllRootMoveCount: Int
    let legalAllMoves: [String]
    let standardAttemptCount: Int
    let stressAttemptCount: Int
    let totalAttemptCount: Int
}

private struct PositionResult: Codable {
    let ply: Int
    let engineLegalRootMoveCount: Int
    let engineLegalAllRootMoveCount: Int
    let swiftDerivedLegalRootMoveCount: Int
    let parity: Bool
    let omittedBySearchLegal: [String]
    let standardAttemptCount: Int
    let stressAttemptCount: Int
    let totalAttemptCount: Int
}

private struct CrosscheckReport: Codable {
    let schemaVersion: Int
    let status: String
    let authorityBase: String
    let engineCommit: String
    let inputSHA256: String
    let derivation: String
    let uniquePositionCount: Int
    let standardAttemptCount: Int
    let stressAttemptCount: Int
    let totalAttemptCount: Int
    let parityMismatchCount: Int
    let affectedTotalAttemptCount: Int
    let minimumLegalRootMoveCount: Int
    let positions: [PositionResult]
    let failureReasons: [String]
}

@main
private enum Main {
    static func main() throws {
        guard CommandLine.arguments.count == 3 else {
            fputs("usage: VE1BLegalRootCrosscheck <native-report.json> <output.json>\n", stderr)
            Foundation.exit(64)
        }

        let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
        let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
        let native = try JSONDecoder().decode(NativeReport.self, from: Data(contentsOf: inputURL))

        var results: [PositionResult] = []
        var reasons: [String] = []
        var affectedAttempts = 0

        for position in native.positions.sorted(by: { $0.ply < $1.ply }) {
            guard position.legalAllRootMoveCount == position.legalAllMoves.count else {
                reasons.append("PLY_\(position.ply)_LEGAL_ALL_COUNT_PAYLOAD_MISMATCH")
                continue
            }

            let snapshot = try BoardSnapshotResolver.resolve(positionCommand: position.positionCommand)
            let derived = try YaneuraOuLegalMoveSemantics.searchRootMoves(
                snapshot: snapshot,
                legalAllMoves: position.legalAllMoves
            )
            let derivedSet = Set(derived)
            let omitted = position.legalAllMoves.filter { !derivedSet.contains($0) }
            let parity = derived.count == position.legalRootMoveCount
            if !parity {
                reasons.append(
                    "PLY_\(position.ply)_PARITY_ENGINE_\(position.legalRootMoveCount)_SWIFT_\(derived.count)"
                )
            }
            if position.legalRootMoveCount < 3 {
                affectedAttempts += position.totalAttemptCount
                reasons.append(
                    "PLY_\(position.ply)_LEGAL_ROOT_COUNT_\(position.legalRootMoveCount)_AFFECTS_\(position.totalAttemptCount)_ATTEMPTS"
                )
            }

            results.append(
                PositionResult(
                    ply: position.ply,
                    engineLegalRootMoveCount: position.legalRootMoveCount,
                    engineLegalAllRootMoveCount: position.legalAllRootMoveCount,
                    swiftDerivedLegalRootMoveCount: derived.count,
                    parity: parity,
                    omittedBySearchLegal: omitted,
                    standardAttemptCount: position.standardAttemptCount,
                    stressAttemptCount: position.stressAttemptCount,
                    totalAttemptCount: position.totalAttemptCount
                )
            )
        }

        if native.status != "PASS" {
            reasons.append("NATIVE_ENGINE_AUDIT_NOT_PASS")
        }
        if results.count != native.uniquePositionCount {
            reasons.append("POSITION_RESULT_COUNT_MISMATCH")
        }

        let mismatchCount = results.filter { !$0.parity }.count
        let minimum = results.map(\.engineLegalRootMoveCount).min() ?? 0
        let report = CrosscheckReport(
            schemaVersion: 1,
            status: reasons.isEmpty ? "PASS" : "FAIL",
            authorityBase: native.authorityBase,
            engineCommit: native.engineCommit,
            inputSHA256: native.inputSHA256,
            derivation: "engine MoveList<LEGAL> vs Swift filtering of engine MoveList<LEGAL_ALL> using pinned omission semantics",
            uniquePositionCount: results.count,
            standardAttemptCount: native.standardAttemptCount,
            stressAttemptCount: native.stressAttemptCount,
            totalAttemptCount: native.totalAttemptCount,
            parityMismatchCount: mismatchCount,
            affectedTotalAttemptCount: affectedAttempts,
            minimumLegalRootMoveCount: minimum,
            positions: results,
            failureReasons: reasons
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(report).write(to: outputURL, options: .atomic)

        print("B6 LEGAL crosscheck: \(report.status)")
        print("minimumLegalRootMoveCount=\(report.minimumLegalRootMoveCount)")
        print("parityMismatchCount=\(report.parityMismatchCount)")
        if report.status != "PASS" {
            Foundation.exit(2)
        }
    }
}
