import Foundation
import Dispatch
import Darwin
import ShogiCoachCore

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

struct ProbeSample: Sendable {
    let result: EngineProbeResult
    let elapsedMs: Int
    let memoryBytesAfter: UInt64?
    let thermalBefore: String
    let thermalAfter: String
}

actor EngineUSISession {
    enum ProbeError: Error, LocalizedError {
        case engineStartFailed(Int32)
        case connectionClosed
        case evalMissing
        case timeout(String)
        case protocolError(String)
        case ioError(String)

        var errorDescription: String? {
            switch self {
            case .engineStartFailed(let code): return "やねうら王起動失敗: \(code)"
            case .connectionClosed: return "USI接続が途中で閉じました"
            case .evalMissing: return "Bundle内の eval/nn.bin が見つかりません"
            case .timeout(let what): return "待機タイムアウト: \(what)"
            case .protocolError(let detail): return "USIプロトコル異常: \(detail)"
            case .ioError(let detail): return "USI I/O異常: \(detail)"
            }
        }
    }

    private var transport: LocalUSITransport?

    func beginAnalysis(multiPV: Int = 1) async throws {
        if let old = transport {
            try? await old.send("quit")
            await old.close()
            transport = nil
        }

        guard let evalURL = Bundle.main.url(forResource: "nn", withExtension: "bin", subdirectory: "eval") else {
            throw ProbeError.evalMissing
        }

        let link = LocalUSITransport()
        transport = link

        do {
            try await link.start()
            SimulatorStage.mark("session_opened")

            try await link.send("usi")
            SimulatorStage.mark("usi_sent")
            _ = try await link.readUntil({ $0 == "usiok" }, timeoutSeconds: 5, label: "usiok")
            SimulatorStage.mark("usiok")

            try await link.send("setoption name Threads value 1")
            try await link.send("setoption name USI_Hash value 64")
            try await link.send("setoption name MultiPV value \(max(1, multiPV))")
            try await link.send("setoption name EvalDir value \(evalURL.deletingLastPathComponent().path)")
            try await link.send("isready")
            SimulatorStage.mark("isready_sent")
            _ = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "readyok")
            SimulatorStage.mark("readyok")

            try await link.send("usinewgame")
        } catch {
            try? await link.send("quit")
            await link.close()
            transport = nil
            throw error
        }
    }

    func analyzePosition(command: String, movetimeMs: Int) async throws -> ProbeSample {
        guard let link = transport else {
            throw ProbeError.protocolError("解析セッションが開始されていません")
        }
        guard command.hasPrefix("position ") else {
            throw ProbeError.protocolError("positionコマンドが不正です")
        }

        try await link.send(command)

        let thermalBefore = RuntimeMetrics.thermalState
        let started = ContinuousClock.now
        var accumulator = USIAccumulator()
        try await link.send("go movetime \(max(50, movetimeMs))")
        SimulatorStage.mark("go_sent")

        let deadline = ContinuousClock.now.advanced(
            by: .seconds(max(5, Double(movetimeMs) / 1000.0 + 5))
        )
        var finalResult: EngineProbeResult?
        while ContinuousClock.now < deadline {
            let remaining = ContinuousClock.now.duration(to: deadline)
            let line = try await link.nextLine(timeout: remaining, label: "bestmove")
            if let result = accumulator.consume(line) {
                finalResult = result
                break
            }
        }

        guard let result = finalResult else { throw ProbeError.timeout("bestmove") }
        SimulatorStage.mark("bestmove_received")
        guard let primary = result.principalVariations.first,
              primary.score != nil,
              !primary.pv.isEmpty else {
            throw ProbeError.protocolError("bestmoveは取得したがscore/PVが不足")
        }

        let elapsed = started.duration(to: .now)
        let components = elapsed.components
        let elapsedMs = Int(components.seconds * 1000)
            + Int(components.attoseconds / 1_000_000_000_000_000)

        return ProbeSample(
            result: result,
            elapsedMs: elapsedMs,
            memoryBytesAfter: RuntimeMetrics.physicalFootprintBytes,
            thermalBefore: thermalBefore,
            thermalAfter: RuntimeMetrics.thermalState
        )
    }

    func endAnalysis() async {
        guard let link = transport else { return }
        try? await link.send("quit")
        await link.close()
        transport = nil
    }

    func run(sfen: String, movetimeMs: Int, multiPV: Int) async throws -> ProbeSample {
        try await beginAnalysis(multiPV: multiPV)
        do {
            let sample = try await analyzePosition(
                command: "position sfen \(sfen)",
                movetimeMs: movetimeMs
            )
            await endAnalysis()
            return sample
        } catch {
            await endAnalysis()
            throw error
        }
    }
}

actor LocalUSITransport {
    private let queue = DispatchQueue(label: "ShogiCoach.LocalUSITransport")
    private var descriptor: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var receiveBuffer = Data()
    private var queuedLines: [String] = []
    private var waiterOrder: [UUID] = []
    private var lineWaiters: [UUID: CheckedContinuation<String, Error>] = [:]

    func start() async throws {
        let fd = yaneuraou_open_session()
        guard fd >= 0 else {
            throw EngineUSISession.ProbeError.engineStartFailed(fd)
        }

        descriptor = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [fd] in
            var bytes = [UInt8](repeating: 0, count: 64 * 1024)
            let count = Darwin.read(fd, &bytes, bytes.count)

            if count > 0 {
                let data = Data(bytes.prefix(Int(count)))
                Task { await self.handleReceive(data) }
            } else if count == 0 {
                Task { await self.handleClosed() }
            } else if errno != EINTR {
                let code = errno
                Task { await self.handleIOError(code) }
            }
        }
        source.setCancelHandler { [fd] in
            Darwin.close(fd)
        }
        readSource = source
        source.resume()
    }

    func send(_ line: String) async throws {
        guard descriptor >= 0 else {
            throw EngineUSISession.ProbeError.connectionClosed
        }

        let data = Data((line + "\n").utf8)
        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.baseAddress else { return }
            var offset = 0
            while offset < rawBuffer.count {
                let written = Darwin.write(
                    descriptor,
                    base.advanced(by: offset),
                    rawBuffer.count - offset
                )
                if written > 0 {
                    offset += written
                } else if written < 0 && errno == EINTR {
                    continue
                } else {
                    throw EngineUSISession.ProbeError.ioError("write errno=\(errno)")
                }
            }
        }
    }

    func readUntil(
        _ predicate: @escaping @Sendable (String) -> Bool,
        timeoutSeconds: Double,
        label: String
    ) async throws -> String {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeoutSeconds))
        while ContinuousClock.now < deadline {
            let remaining = ContinuousClock.now.duration(to: deadline)
            let line = try await nextLine(timeout: remaining, label: label)
            if predicate(line) { return line }
        }
        throw EngineUSISession.ProbeError.timeout(label)
    }

    func nextLine(timeout: Duration, label: String) async throws -> String {
        if !queuedLines.isEmpty {
            return queuedLines.removeFirst()
        }

        let id = UUID()
        return try await withCheckedThrowingContinuation { continuation in
            waiterOrder.append(id)
            lineWaiters[id] = continuation
            Task {
                try? await Task.sleep(for: timeout)
                await self.timeoutLineWaiter(id: id, label: label)
            }
        }
    }

    private func timeoutLineWaiter(id: UUID, label: String) {
        guard let continuation = lineWaiters.removeValue(forKey: id) else { return }
        waiterOrder.removeAll { $0 == id }
        continuation.resume(throwing: EngineUSISession.ProbeError.timeout(label))
    }

    private func handleReceive(_ data: Data) {
        receiveBuffer.append(data)
        drainLines()
    }

    private func handleClosed() {
        failLineWaiters(EngineUSISession.ProbeError.connectionClosed)
    }

    private func handleIOError(_ code: Int32) {
        failLineWaiters(EngineUSISession.ProbeError.ioError("read errno=\(code)"))
    }

    private func drainLines() {
        while let idx = receiveBuffer.firstIndex(of: 0x0A) {
            var lineData = receiveBuffer[..<idx]
            if lineData.last == 0x0D {
                lineData = lineData.dropLast()
            }
            receiveBuffer.removeSubrange(...idx)
            deliver(String(decoding: lineData, as: UTF8.self))
        }
    }

    private func deliver(_ line: String) {
        if line == "usiok"
            || line == "readyok"
            || line.hasPrefix("bestmove ")
            || line.hasPrefix("info string bridge_") {
            let marker = line.prefix(120)
                .replacingOccurrences(of: " ", with: "_")
                .replacingOccurrences(of: "/", with: "_")
            SimulatorStage.mark("rx_\(marker)")
        }
        while let id = waiterOrder.first {
            waiterOrder.removeFirst()
            if let continuation = lineWaiters.removeValue(forKey: id) {
                continuation.resume(returning: line)
                return
            }
        }
        queuedLines.append(line)
    }

    private func failLineWaiters(_ error: Error) {
        let pending = lineWaiters
        lineWaiters.removeAll()
        waiterOrder.removeAll()
        for continuation in pending.values {
            continuation.resume(throwing: error)
        }
    }

    func close() {
        let source = readSource
        readSource = nil
        descriptor = -1
        source?.cancel()

        receiveBuffer.removeAll(keepingCapacity: false)
        queuedLines.removeAll(keepingCapacity: false)
        failLineWaiters(EngineUSISession.ProbeError.connectionClosed)
    }
}
