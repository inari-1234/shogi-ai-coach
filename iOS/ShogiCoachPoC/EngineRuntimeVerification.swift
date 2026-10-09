import Foundation
import CryptoKit
import ShogiCoachCore

enum EngineRuntimeAuthority {
    static let fvScale = 24
    static let expectedNNUESHA256 = "768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"
    static let c1Depth = 1
    static let c1ExpectedCp = 108
    static let c1ExpectedBestMove = "7g7f"
    static let missingFVScaleExpectedCp = 164
}

struct EngineRuntimeVerificationResult: Sendable {
    let cp: Int
    let bestMove: String
    let depth: Int?
    let nnueSHA256: String
    let fvScale: Int?
    let transcript: [String]
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

actor EngineRuntimeVerifier {
    static let shared = EngineRuntimeVerifier()

    func verifyBundledNNUE() throws -> (url: URL, sha256: String) {
        guard let evalURL = Bundle.main.url(
            forResource: "nn",
            withExtension: "bin",
            subdirectory: "eval"
        ) else {
            throw EngineRuntimeVerificationError.evalMissing
        }
        return (evalURL, try verifyNNUE(at: evalURL))
    }

    func runC1KnownAnswer() async throws -> EngineRuntimeVerificationResult {
        let verified = try verifyBundledNNUE()
        let result = try await runStartposDepth1(
            evalURL: verified.url,
            nnueSHA256: verified.sha256,
            fvScale: EngineRuntimeAuthority.fvScale
        )

        guard result.depth == EngineRuntimeAuthority.c1Depth else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "depth expected=\(EngineRuntimeAuthority.c1Depth) actual=\(result.depth.map(String.init) ?? "nil")"
            )
        }
        guard result.cp == EngineRuntimeAuthority.c1ExpectedCp else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "cp expected=\(EngineRuntimeAuthority.c1ExpectedCp) actual=\(result.cp)"
            )
        }
        guard result.bestMove == EngineRuntimeAuthority.c1ExpectedBestMove else {
            throw EngineRuntimeVerificationError.knownAnswerMismatch(
                "bestmove expected=\(EngineRuntimeAuthority.c1ExpectedBestMove) actual=\(result.bestMove)"
            )
        }
        return result
    }

    func runMissingFVScaleNegativeControl() async throws -> EngineRuntimeVerificationResult {
        let verified = try verifyBundledNNUE()
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
        let actual = try sha256Hex(of: temporaryURL)

        do {
            _ = try verifyNNUE(at: temporaryURL)
        } catch EngineRuntimeVerificationError.nnueIdentityMismatch {
            return actual
        }

        throw EngineRuntimeVerificationError.negativeControlDidNotFail(
            "wrong NNUE SHA was accepted"
        )
    }

    private func verifyNNUE(at url: URL) throws -> String {
        let actual = try sha256Hex(of: url)
        guard actual == EngineRuntimeAuthority.expectedNNUESHA256 else {
            throw EngineRuntimeVerificationError.nnueIdentityMismatch(
                expected: EngineRuntimeAuthority.expectedNNUESHA256,
                actual: actual
            )
        }
        return actual
    }

    private func sha256Hex(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func runStartposDepth1(
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
            let usiOK = try await link.readUntil({ $0 == "usiok" }, timeoutSeconds: 5, label: "ve1a-usiok")
            transcript.append("< \(usiOK)")

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
            let readyOK = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "ve1a-readyok")
            transcript.append("< \(readyOK)")

            transcript.append("> usinewgame")
            try await link.send("usinewgame")
            transcript.append("> position startpos")
            try await link.send("position startpos")
            transcript.append("> go depth 1")
            try await link.send("go depth 1")

            var accumulator = USIAccumulator()
            let deadline = ContinuousClock.now.advanced(by: .seconds(10))
            var finalResult: EngineProbeResult?
            while ContinuousClock.now < deadline {
                let remaining = ContinuousClock.now.duration(to: deadline)
                let line = try await link.nextLine(timeout: remaining, label: "ve1a-bestmove")
                if line.hasPrefix("info ") || line.hasPrefix("bestmove ") {
                    transcript.append("< \(line)")
                }
                if let result = accumulator.consume(line) {
                    finalResult = result
                    break
                }
            }

            guard let result = finalResult,
                  let primary = result.principalVariations.first,
                  let score = primary.score else {
                throw EngineRuntimeVerificationError.protocolFailure("bestmove/primary score missing")
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
                cp: cp,
                bestMove: result.bestMove.move,
                depth: primary.depth,
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
}
