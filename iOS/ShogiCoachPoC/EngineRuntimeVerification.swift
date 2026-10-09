import Foundation
import CryptoKit
import ShogiCoachCore

enum EngineRuntimeAuthority {
    static let fvScale = 24
    static let expectedNNUESHA256 = "768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"
    static let c1Depth = 1
    static let c1ExpectedCp = 108
    static let c1ExpectedBestMove = "7g7f"
    static let correctedC1SFEN = "lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8"
    static let correctedC1ExpectedCp = 157
    static let correctedC1ExpectedBestMove = "2b7g+"
    static let missingFVScaleExpectedCp = 164
}

struct EngineRuntimeVerificationResult: Sendable {
    let positionCommand: String
    let cp: Int
    let bestMove: String
    let depth: Int?
    let nnuePath: String
    let nnueSHA256: String
    let fvScale: Int?
    let transcript: [String]
}

struct EngineRuntimePhysicalEvidenceSuite: Sendable {
    let startpos: EngineRuntimeVerificationResult
    let correctedC1: EngineRuntimeVerificationResult
}

enum EngineRuntimeVerificationError: Error, LocalizedError {
    case evalMissing
    case nnueIdentityMismatch(expected: String, actual: String)
    case protocolFailure(String)
    case knownAnswerMismatch(String)
    case negativeControlDidNotFail(String)

    var errorDescription: String? {
        switch self {
        case .evalMissing:
            return "Bundle内の eval/nn.bin が見つかりません"
        case .nnueIdentityMismatch(let expected, let actual):
            return "NNUE SHA-256不一致 expected=\(expected) actual=\(actual)"
        case .protocolFailure(let detail):
            return "VE1-A USI診断異常: \(detail)"
        case .knownAnswerMismatch(let detail):
            return "VE1-A C1既知解不一致: \(detail)"
        case .negativeControlDidNotFail(let detail):
            return "VE1-A負例が検出できませんでした: \(detail)"
        }
    }
}

enum EngineRuntimeIdentity {
    static func verifyBundledNNUE() throws -> (url: URL, sha256: String) {
        guard let evalURL = Bundle.main.url(
            forResource: "nn",
            withExtension: "bin",
            subdirectory: "eval"
        ) else {
            throw EngineRuntimeVerificationError.evalMissing
        }
        return (evalURL, try verifyNNUE(at: evalURL))
    }

    static func verifyNNUE(at url: URL) throws -> String {
        let actual = try sha256Hex(of: url)
        guard actual == EngineRuntimeAuthority.expectedNNUESHA256 else {
            throw EngineRuntimeVerificationError.nnueIdentityMismatch(
                expected: EngineRuntimeAuthority.expectedNNUESHA256,
                actual: actual
            )
        }
        return actual
    }

    static func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}

actor EngineRuntimeVerifier {
    static let shared = EngineRuntimeVerifier()

    func runC1KnownAnswer() async throws -> EngineRuntimeVerificationResult {
        let verified = try EngineRuntimeIdentity.verifyBundledNNUE()
        let result = try await runStartposDepth1(
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: EngineRuntimeAuthority.fvScale
        )
        try validateKnownAnswer(
            result,
            expectedCp: EngineRuntimeAuthority.c1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.c1ExpectedBestMove,
            label: "startpos"
        )
        return result
    }

    func runCorrectedC1KnownAnswer() async throws -> EngineRuntimeVerificationResult {
        let verified = try EngineRuntimeIdentity.verifyBundledNNUE()
        let result = try await runPositionDepth1(
            positionCommand: "position sfen \(EngineRuntimeAuthority.correctedC1SFEN)",
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: EngineRuntimeAuthority.fvScale
        )
        try validateKnownAnswer(
            result,
            expectedCp: EngineRuntimeAuthority.correctedC1ExpectedCp,
            expectedBestMove: EngineRuntimeAuthority.correctedC1ExpectedBestMove,
            label: "corrected-c1"
        )
        return result
    }

    /// Physical-device evidence intentionally returns raw actual values without
    /// converting a numeric mismatch into a thrown known-answer error. The UI
    /// must retain/share the transcript and mark VE1-A HOLD on any mismatch.
    func runPhysicalDeviceEvidenceSuite() async throws -> EngineRuntimePhysicalEvidenceSuite {
        let verified = try EngineRuntimeIdentity.verifyBundledNNUE()
        let startpos = try await runPositionDepth1(
            positionCommand: "position startpos",
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: EngineRuntimeAuthority.fvScale
        )
        let correctedC1 = try await runPositionDepth1(
            positionCommand: "position sfen \(EngineRuntimeAuthority.correctedC1SFEN)",
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: EngineRuntimeAuthority.fvScale
        )
        return EngineRuntimePhysicalEvidenceSuite(
            startpos: startpos,
            correctedC1: correctedC1
        )
    }

    func runMissingFVScaleNegativeControl() async throws -> EngineRuntimeVerificationResult {
        let verified = try EngineRuntimeIdentity.verifyBundledNNUE()
        let result = try await runStartposDepth1(
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: nil
        )

        guard result.cp == EngineRuntimeAuthority.missingFVScaleExpectedCp else {
            throw EngineRuntimeVerificationError.negativeControlDidNotFail(
                "FV_SCALE omitted: expected default cp=\(EngineRuntimeAuthority.missingFVScaleExpectedCp), actual=\(result.cp)"
            )
        }
        guard result.cp != EngineRuntimeAuthority.c1ExpectedCp else {
            throw EngineRuntimeVerificationError.negativeControlDidNotFail(
                "FV_SCALE omitted but qualified cp=\(EngineRuntimeAuthority.c1ExpectedCp) still appeared"
            )
        }
        return result
    }

    func runWrongNNUEIdentityNegativeControl() throws -> String {
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ve1a-wrong-nnue-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        try Data("VE1-A intentionally wrong NNUE identity".utf8).write(
            to: temporaryURL,
            options: .atomic
        )
        let actual = try EngineRuntimeIdentity.sha256Hex(of: temporaryURL)

        do {
            _ = try EngineRuntimeIdentity.verifyNNUE(at: temporaryURL)
        } catch EngineRuntimeVerificationError.nnueIdentityMismatch(_, _) {
            return actual
        }

        throw EngineRuntimeVerificationError.negativeControlDidNotFail(
            "wrong NNUE SHA was accepted"
        )
    }

    private func validateKnownAnswer(
        _ result: EngineRuntimeVerificationResult,
        expectedCp: Int,
        expectedBestMove: String,
        label: String
    ) throws {
        guard result.depth == EngineRuntimeAuthority.c1Depth else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "\(label) depth expected=\(EngineRuntimeAuthority.c1Depth) actual=\(result.depth.map(String.init) ?? "nil")"
            )
        }
        guard result.cp == expectedCp else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "\(label) cp expected=\(expectedCp) actual=\(result.cp)"
            )
        }
        guard result.bestMove == expectedBestMove else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "\(label) bestmove expected=\(expectedBestMove) actual=\(result.bestMove)"
            )
        }
    }

    private func runStartposDepth1(
        evalURL: URL,
        nnueSHA256: String,
        fvScale: Int?
    ) async throws -> EngineRuntimeVerificationResult {
        try await runPositionDepth1(
            positionCommand: "position startpos",
            evalURL: evalURL,
            nnueSHA256: nnueSHA256,
            fvScale: fvScale
        )
    }

    private func runPositionDepth1(
        positionCommand: String,
        evalURL: URL,
        nnueSHA256: String,
        fvScale: Int?
    ) async throws -> EngineRuntimeVerificationResult {
        let link = LocalUSITransport()
        var transcript: [String] = []

        do {
            try await link.start()

            transcript.append("> usi")
            try await link.send("usi")
            transcript.append(contentsOf: try await readUntilRecording(
                link,
                predicate: { $0 == "usiok" },
                timeoutSeconds: 5,
                label: "ve1a-usiok"
            ))

            let commands: [String] = [
                "setoption name Threads value 1",
                "setoption name USI_Hash value 64",
                "setoption name MultiPV value 1"
            ]
            for command in commands {
                transcript.append("> \(command)")
                try await link.send(command)
            }

            if let fvScale {
                let command = "setoption name FV_SCALE value \(fvScale)"
                transcript.append("> \(command)")
                try await link.send(command)
            }

            let evalCommand = "setoption name EvalDir value \(evalURL.deletingLastPathComponent().path)"
            transcript.append("> \(evalCommand)")
            try await link.send(evalCommand)

            transcript.append("> isready")
            try await link.send("isready")
            transcript.append(contentsOf: try await readUntilRecording(
                link,
                predicate: { $0 == "readyok" },
                timeoutSeconds: 20,
                label: "ve1a-readyok"
            ))

            transcript.append("> usinewgame")
            try await link.send("usinewgame")
            transcript.append("> \(positionCommand)")
            try await link.send(positionCommand)
            transcript.append("> go depth 1")
            try await link.send("go depth 1")

            var accumulator = USIAccumulator()
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var finalResult: EngineProbeResult?
            while ContinuousClock.now < deadline {
                let remaining = ContinuousClock.now.duration(to: deadline)
                let line = try await link.nextLine(timeout: remaining, label: "ve1a-bestmove")
                transcript.append("< \(line)")
                if let result = accumulator.consume(line) {
                    finalResult = result
                    break
                }
            }

            guard let result = finalResult,
                  let primary = result.principalVariations.first,
                  let score = primary.score else {
                throw EngineRuntimeVerificationError.protocolFailure(
                    "bestmove/primary score missing"
                )
            }

            let cp: Int
            switch score {
            case .centipawn(let value, let bound) where bound == nil:
                cp = value
            case .centipawn(let value, let bound):
                throw EngineRuntimeVerificationError.protocolFailure(
                    "bounded cp is not a C1 known answer: value=\(value) bound=\(String(describing: bound))"
                )
            case .mate(let value, _):
                throw EngineRuntimeVerificationError.protocolFailure(
                    "mate score is not a C1 known answer: mate=\(value)"
                )
            }

            transcript.append("> quit")
            try? await link.send("quit")
            await link.close()

            return EngineRuntimeVerificationResult(
                positionCommand: positionCommand,
                cp: cp,
                bestMove: result.bestMove.move,
                depth: primary.depth,
                nnuePath: evalURL.path,
                nnueSHA256: nnueSHA256,
                fvScale: fvScale,
                transcript: transcript
            )
        } catch {
            try? await link.send("quit")
            await link.close()
            throw error
        }
    }

    private func readUntilRecording(
        _ link: LocalUSITransport,
        predicate: @escaping @Sendable (String) -> Bool,
        timeoutSeconds: Double,
        label: String
    ) async throws -> [String] {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeoutSeconds))
        var lines: [String] = []
        while ContinuousClock.now < deadline {
            let remaining = ContinuousClock.now.duration(to: deadline)
            let line = try await link.nextLine(timeout: remaining, label: label)
            lines.append("< \(line)")
            if predicate(line) {
                return lines
            }
        }
        throw EngineUSISession.ProbeError.timeout(label)
    }
}
