import Foundation
import Dispatch
import Darwin
import ShogiCoachCore

struct ProbeSample: Sendable {
    let result: EngineProbeResult
    let elapsedMs: Int
    let memoryBytesAfter: UInt64?
    let thermalBefore: String
    let thermalAfter: String
}

enum EngineSearchRole: String, Sendable {
    case candidateDiscovery = "candidate_discovery"
    case directComparison = "direct_comparison"
    case confirmation = "confirmation"
    case diagnostic = "diagnostic"
}

enum EngineNodeSearchCompletion: String, Sendable {
    case nodeBudgetReached = "node_budget_reached"
    case earlyEngineTermination = "early_engine_termination"
    case safetyAborted = "safety_aborted"
}

struct NodeProbeSample: Sendable {
    let result: EngineProbeResult?
    let observations: [USIInfo]
    let completion: EngineNodeSearchCompletion
    let elapsedMs: Int
    let memoryBytesAfter: UInt64?
    let thermalBefore: String
    let thermalAfter: String
    let issuedGoCommand: String
    let searchRole: EngineSearchRole
    let nodeBudget: Int
    let safetyCeilingMs: Int
    let ttGeneration: Int
    let maxObservedNodes: UInt64

    var isNormalCompletedResult: Bool {
        completion == .nodeBudgetReached
            && result?.bestMoveConsistency == .consistent
            && result?.principalVariations.first?.score != nil
            && result?.principalVariations.first?.pv.isEmpty == false
    }
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
    private var currentMultiPV = 1
    private var ttGeneration = 0

    func beginAnalysis(multiPV: Int = 1) async throws {
        if let old = transport {
            try? await old.send("quit")
            await old.close()
            transport = nil
        }

        let verifiedNNUE = try EngineRuntimeIdentity.verifyBundledNNUE()
        let evalURL = verifiedNNUE.url

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
            currentMultiPV = max(1, multiPV)
            try await link.send("setoption name MultiPV value \(currentMultiPV)")
            try await link.send("setoption name FV_SCALE value \(EngineRuntimeAuthority.fvScale)")
            try await link.send("setoption name BookFile value no_book")
            try await link.send("setoption name EvalDir value \(evalURL.deletingLastPathComponent().path)")
            try await link.send("isready")
            SimulatorStage.mark("isready_sent")
            _ = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "readyok")
            SimulatorStage.mark("readyok")
            ttGeneration = 1

            try await link.send("usinewgame")
        } catch {
            try? await link.send("quit")
            await link.close()
            transport = nil
            ttGeneration = 0
            throw error
        }
    }

    /// Starts a new cold logical search series.
    ///
    /// The pinned YaneuraOu `YaneuraOuEngine::isready()` calls
    /// `tt.clear(threads)`. VE1-B therefore uses `isready`/`readyok` as the
    /// explicit TT reset boundary. Increasing node tiers within one confirmation
    /// series intentionally do NOT call this method and inherit TT state.
    @discardableResult
    func resetForColdSeries(reason: String) async throws -> Int {
        guard let link = transport else {
            throw ProbeError.protocolError("解析セッションが開始されていません")
        }
        try await link.send("isready")
        SimulatorStage.mark("ve1b_tt_reset_isready_\(reason)")
        _ = try await link.readUntil({ $0 == "readyok" }, timeoutSeconds: 20, label: "ve1b-tt-reset-readyok")
        ttGeneration += 1
        try await link.send("usinewgame")
        SimulatorStage.mark("ve1b_tt_generation_\(ttGeneration)")
        return ttGeneration
    }

    func analyzePositionNodes(
        command: String,
        nodeBudget: Int,
        safetyCeilingMs: Int,
        role: EngineSearchRole,
        searchMoves: [String] = [],
        multiPV: Int? = nil
    ) async throws -> NodeProbeSample {
        guard let link = transport else {
            throw ProbeError.protocolError("解析セッションが開始されていません")
        }
        guard command.hasPrefix("position ") else {
            throw ProbeError.protocolError("positionコマンドが不正です")
        }
        guard nodeBudget > 0 else {
            throw ProbeError.protocolError("nodeBudgetは1以上が必要です")
        }
        guard safetyCeilingMs > 0 else {
            throw ProbeError.protocolError("safetyCeilingMsは1以上が必要です")
        }

        if let multiPV {
            let requested = max(1, multiPV)
            if requested != currentMultiPV {
                try await link.send("setoption name MultiPV value \(requested)")
                currentMultiPV = requested
            }
        }

        try await link.send(command)

        let thermalBefore = RuntimeMetrics.thermalState
        let started = ContinuousClock.now
        var accumulator = USIAccumulator()
        var observations: [USIInfo] = []
        var maxObservedNodes: UInt64 = 0
        let searchClause = searchMoves.isEmpty
            ? ""
            : " searchmoves " + searchMoves.joined(separator: " ")
        let goCommand = "go nodes \(nodeBudget)\(searchClause)"
        try await link.send(goCommand)
        SimulatorStage.mark(searchMoves.isEmpty ? "go_nodes_sent" : "go_nodes_searchmoves_sent")

        let deadline = ContinuousClock.now.advanced(
            by: .seconds(Double(safetyCeilingMs) / 1000.0)
        )
        var finalResult: EngineProbeResult?
        var safetyAborted = false

        while ContinuousClock.now < deadline {
            let remaining = ContinuousClock.now.duration(to: deadline)
            do {
                let line = try await link.nextLine(timeout: remaining, label: "ve1b-node-bestmove")
                if let info = USIParser.parseInfo(line), !line.hasPrefix("info string ") {
                    observations.append(info)
                    if let nodes = info.nodes {
                        maxObservedNodes = max(maxObservedNodes, nodes)
                    }
                }
                if let result = accumulator.consume(line) {
                    finalResult = result
                    break
                }
            } catch ProbeError.timeout(_) {
                safetyAborted = true
                break
            }
        }

        if finalResult == nil && !safetyAborted {
            safetyAborted = true
        }

        if safetyAborted {
            try? await link.send("stop")
            SimulatorStage.mark("ve1b_node_safety_abort_stop_sent")
            let stopDeadline = ContinuousClock.now.advanced(by: .seconds(2))
            while ContinuousClock.now < stopDeadline && finalResult == nil {
                let remaining = ContinuousClock.now.duration(to: stopDeadline)
                do {
                    let line = try await link.nextLine(timeout: remaining, label: "ve1b-node-stop-bestmove")
                    if let info = USIParser.parseInfo(line), !line.hasPrefix("info string ") {
                        observations.append(info)
                        if let nodes = info.nodes {
                            maxObservedNodes = max(maxObservedNodes, nodes)
                        }
                    }
                    if let result = accumulator.consume(line) {
                        finalResult = result
                    }
                } catch {
                    break
                }
            }
        }

        let elapsed = started.duration(to: .now)
        let components = elapsed.components
        let elapsedMs = Int(components.seconds * 1000)
            + Int(components.attoseconds / 1_000_000_000_000_000)

        let completion: EngineNodeSearchCompletion
        if safetyAborted {
            completion = .safetyAborted
        } else if maxObservedNodes >= UInt64(nodeBudget) {
            completion = .nodeBudgetReached
        } else {
            completion = .earlyEngineTermination
        }

        if let finalResult {
            SimulatorStage.mark(
                "ve1b_node_bestmove_\(finalResult.bestMove.move)_consistency_\(finalResult.bestMoveConsistency.rawValue)"
            )
        }

        return NodeProbeSample(
            result: finalResult,
            observations: observations,
            completion: completion,
            elapsedMs: elapsedMs,
            memoryBytesAfter: RuntimeMetrics.physicalFootprintBytes,
            thermalBefore: thermalBefore,
            thermalAfter: RuntimeMetrics.thermalState,
            issuedGoCommand: goCommand,
            searchRole: role,
            nodeBudget: nodeBudget,
            safetyCeilingMs: safetyCeilingMs,
            ttGeneration: ttGeneration,
            maxObservedNodes: maxObservedNodes
        )
    }

    /// Legacy movetime API retained for shallow/non-VE1-B callers while the deep
    /// analysis path migrates to `analyzePositionNodes`.
    func analyzePosition(
        command: String,
        movetimeMs: Int,
        searchMoves: [String] = [],
        multiPV: Int? = nil
    ) async throws -> ProbeSample {
        guard let link = transport else {
            throw ProbeError.protocolError("解析セッションが開始されていません")
        }
        guard command.hasPrefix("position ") else {
            throw ProbeError.protocolError("positionコマンドが不正です")
        }

        if let multiPV {
            let requested = max(1, multiPV)
            if requested != currentMultiPV {
                try await link.send("setoption name MultiPV value \(requested)")
                currentMultiPV = requested
            }
        }

        try await link.send(command)

        let thermalBefore = RuntimeMetrics.thermalState
        let started = ContinuousClock.now
        var accumulator = USIAccumulator()
        let boundedMovetime = max(50, movetimeMs)
        let searchClause = searchMoves.isEmpty
            ? ""
            : " searchmoves " + searchMoves.joined(separator: " ")
        try await link.send("go movetime \(boundedMovetime)\(searchClause)")
        SimulatorStage.mark(searchMoves.isEmpty ? "go_sent" : "go_searchmoves_sent")

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
        guard result.bestMoveConsistency == .consistent else {
            throw ProbeError.protocolError(
                "bestmoveとMultiPV 1位PV先頭手が不一致: bestmove=\(result.bestMove.move) consistency=\(result.bestMoveConsistency.rawValue)"
            )
        }
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
        currentMultiPV = 1
        ttGeneration = 0
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
