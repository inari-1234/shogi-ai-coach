import SwiftUI
import UniformTypeIdentifiers
import Foundation
import CryptoKit
import UIKit
import Darwin
import ShogiCoachCore

private enum VE1BB6Environment {
    static let yaneuraOuPin = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"
    static let requiredDeviceModelIdentifier = "iPhone17,1"
    static let requiredOSVersion = "iOS 26.7.1"

    static var platform: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "device"
        #endif
    }

    static var hardwareModelIdentifier: String {
        #if targetEnvironment(simulator)
        if let identifier = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"],
           !identifier.isEmpty {
            return identifier
        }
        #endif

        var systemInfo = utsname()
        guard uname(&systemInfo) == 0 else { return UIDevice.current.model }
        return Mirror(reflecting: systemInfo.machine).children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier += String(UnicodeScalar(UInt8(bitPattern: value)))
        }
    }

    static var osVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }

    static var appBuild: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
    }

    static var gitCommit: String {
        guard let raw = Bundle.main.object(forInfoDictionaryKey: "GitCommit") as? String else {
            return "unknown"
        }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isFullSHA = value.count == 40 && value.allSatisfy { $0.isHexDigit }
        return isFullSHA ? value : "unknown"
    }

    static var incompleteProofRunID: String {
        Bundle.main.object(forInfoDictionaryKey: "B6IncompleteProofRunID") as? String ?? "unknown"
    }

    static var incompleteProofResult: String {
        Bundle.main.object(forInfoDictionaryKey: "B6IncompleteProofResult") as? String ?? "UNKNOWN"
    }

    static var incompleteProofTestName: String {
        Bundle.main.object(forInfoDictionaryKey: "B6IncompleteProofTestName") as? String ?? "unknown"
    }

    static var incompleteProofWorkflow: String {
        Bundle.main.object(forInfoDictionaryKey: "B6IncompleteProofWorkflow") as? String ?? "unknown"
    }

    static var thermalState: String {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }
}

private struct VE1BB6FixtureRecord: Codable {
    let fileName: String
    let sha256: String
    let moveCount: Int
    let lockedAt: Date
}

private struct VE1BB6ShallowSample: Codable {
    let ply: Int
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
}

private struct VE1BB6AttemptSummary: Codable {
    let attemptID: String
    let role: String
    let measurementTarget: String
    let nodeBudget: Int
    let ttGeneration: Int
    let multiPV: Int
    let searchMoves: [String]
    let completion: String
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let maxObservedNodes: UInt64
    let selectedNodes: UInt64?
    let selectedBoundKind: String?

    init(_ record: VE1BSearchAttemptRecord) {
        attemptID = record.attemptID
        role = record.role
        measurementTarget = record.measurementTarget
        nodeBudget = record.nodeBudget
        ttGeneration = record.ttGeneration
        multiPV = record.multiPV
        searchMoves = record.searchMoves
        completion = record.completion
        elapsedMs = record.elapsedMs
        thermalBefore = record.thermalBefore
        thermalAfter = record.thermalAfter
        maxObservedNodes = record.maxObservedNodes
        selectedNodes = record.selectedNodes
        selectedBoundKind = record.selectedBoundKind
    }
}

private struct VE1BB6PositionSummary: Codable {
    let ply: Int
    let elapsedMs: Int
    let attemptCount: Int
    let stabilityState: String
    let attempts: [VE1BB6AttemptSummary]
}

private struct VE1BB6RunRecord: Codable, Identifiable {
    let id: String
    let kind: String
    let ordinal: Int
    let startedAt: Date
    let endedAt: Date
    let platform: String
    let deviceModelIdentifier: String
    let osVersion: String
    let appVersion: String
    let appBuild: String
    let gitCommit: String
    let yaneuraOuPin: String
    let nnueSHA256: String
    let fvScale: Int
    let threads: Int
    let hashMB: Int
    let bookFile: String
    let pvIntervalMs: Int
    let shallowMovetimeMs: Int
    let nodePolicyAuthorityStatus: String
    let candidateDiscoveryNodeTiers: [Int]
    let confirmationNodeTiers: [Int]
    let safetyCeilingMs: Int
    let startThermal: String
    let endThermal: String
    let shallowStatus: String
    let shallowTop3Plies: [Int]
    let shallowSamples: [VE1BB6ShallowSample]
    let deepState: String
    let deepStatus: String
    let deepDisplayStatus: String?
    let selectedDeepPlies: [Int]
    let completedPositions: [VE1BB6PositionSummary]
    let incompletePly: Int?
    let incompleteAttempts: [VE1BB6AttemptSummary]
    let safeIncompleteState: Bool
    let wholeGameElapsedMs: Int
    let rawEvidenceFileName: String?
    let rawEvidenceSHA256: String?
    let runError: String?

    var allAttempts: [VE1BB6AttemptSummary] {
        completedPositions.flatMap(\.attempts) + incompleteAttempts
    }
}

private struct VE1BB6PersistentState: Codable {
    var schemaVersion: Int = 1
    var createdAt: Date = Date()
    var fixture: VE1BB6FixtureRecord?
    var standardRuns: [VE1BB6RunRecord] = []
    var stressRuns: [VE1BB6RunRecord] = []
}

private struct VE1BB6PairwiseJaccardRecord: Codable {
    let leftRun: Int
    let rightRun: Int
    let value: Double
}

private struct VE1BB6Report: Codable {
    let schemaVersion: Int
    let generatedAt: Date
    let authority: String
    let policyDecision: String
    let decisionReasons: [String]
    let fixture: VE1BB6FixtureRecord?
    let standardRuns: [VE1BB6RunRecord]
    let stressRuns: [VE1BB6RunRecord]
    let pairwiseTop3Jaccard: [VE1BB6PairwiseJaccardRecord]
    let minimumTop3Jaccard: Double?
    let modalTop1Ply: Int?
    let modalTop1Count: Int
    let deepPositionMedianMs: Double?
    let deepPositionP95Ms: Int?
    let wholeGameMedianMs: Double?
    let wholeGameP95Ms: Int?
    let standardAttemptCount: Int
    let standardCompletionCounts: [String: Int]
    let standardNodeBudgetReachedCount: Int
    let standardProvenMateTerminationCount: Int
    let standardIncompleteCount: Int
    let standardIncompleteRate: Double?
    let standardSeriousThermalObservationCount: Int
    let standardCriticalThermalObservationCount: Int
    let stressAttemptCount: Int
    let stressCompletionCounts: [String: Int]
    let stressIncompleteCount: Int
    let stressIncompleteRate: Double?
    let stressCriticalThermalObservationCount: Int
    let stressSafeIncompleteHandlingPassed: Bool
    let incompleteStateProof: String
    let shallowReproducibilityPassed: Bool
    let standardEvidenceIntegrityPassed: Bool
    let standardOperationalPassed: Bool
    let stressEvidenceIntegrityPassed: Bool
    let stressPassed: Bool
}

@MainActor
final class VE1BPhysicalQualificationViewModel: ObservableObject {
    @Published fileprivate var state = VE1BB6PersistentState()
    @Published private(set) var status = "B6 未開始"
    @Published private(set) var detail = ""
    @Published private(set) var isRunning = false
    @Published private(set) var reportURL: URL?

    private let standardRunTarget = 5
    private let stressRunTarget = 3
    private let policy = VE1BNodeSearchPolicy.calibrationUnfrozen

    init() {
        loadState()
        refreshReport()
    }

    var fixtureLocked: Bool { state.fixture != nil }
    var standardComplete: Bool { state.standardRuns.count == standardRunTarget }
    var stressComplete: Bool { state.stressRuns.count == stressRunTarget }
    var standardProgressText: String { "\(state.standardRuns.count)/\(standardRunTarget)" }
    var stressProgressText: String { "\(state.stressRuns.count)/\(stressRunTarget)" }
    var currentThermal: String { VE1BB6Environment.thermalState }

    func lockFixture(_ url: URL) {
        guard !isRunning else { return }
        guard state.standardRuns.isEmpty, state.stressRuns.isEmpty else {
            status = "B6 HOLD"
            detail = "測定開始後は棋譜を変更できません。既存証拠を保持したまま別キャンペーンとして扱ってください。"
            return
        }

        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            let game = try KIFParser.parse(data: data)
            guard Self.potentialSelectableCount(game: game) >= 3 else {
                throw EngineUSISession.ProbeError.protocolError(
                    "B6棋譜は浅解析で3局面以上を選択できる必要があります"
                )
            }

            let sha = Self.sha256Hex(data)
            try data.write(to: Self.fixtureURL, options: .atomic)
            state.fixture = VE1BB6FixtureRecord(
                fileName: url.lastPathComponent,
                sha256: sha,
                moveCount: game.moves.count,
                lockedAt: Date()
            )
            try persistStateAndReport()
            status = "B6 棋譜固定 PASS"
            detail = [
                "file=\(url.lastPathComponent)",
                "sha256=\(sha)",
                "moves=\(game.moves.count)",
                "次は端末thermal=nominalを確認して標準runを1回ずつ実行します。"
            ].joined(separator: "\n")
        } catch {
            status = "B6 HOLD"
            detail = error.localizedDescription
        }
    }

    func runNextStandard() async {
        guard !isRunning else { return }
        guard state.standardRuns.count < standardRunTarget else {
            status = "標準run 完了"
            return
        }
        guard VE1BB6Environment.platform == "device" else {
            status = "B6 HOLD"
            detail = "物理iPhoneのみ実行できます。platform=\(VE1BB6Environment.platform)"
            return
        }
        guard VE1BB6Environment.thermalState == "nominal" else {
            status = "B6 HOLD"
            detail = "各標準runはthermal=nominalから開始してください。current=\(VE1BB6Environment.thermalState)"
            return
        }

        isRunning = true
        let ordinal = state.standardRuns.count + 1
        status = "標準run \(ordinal)/\(standardRunTarget) 実行中"
        defer { isRunning = false }

        do {
            let run = try await executeRun(kind: "standard", ordinal: ordinal)
            state.standardRuns.append(run)
            try persistStateAndReport()
            let report = makeReport()
            status = run.deepState == "completed" ? "標準run \(ordinal) 記録済" : "標準run \(ordinal) HOLD記録"
            detail = summaryText(report: report)
        } catch {
            status = "B6 HOLD"
            detail = error.localizedDescription
            refreshReport()
        }
    }

    func runStressCampaign() async {
        guard !isRunning else { return }
        guard standardComplete else {
            status = "B6 HOLD"
            detail = "stressは標準run 5/5の後に実行します。"
            return
        }
        guard state.stressRuns.isEmpty else {
            status = stressComplete ? "stress 3/3 完了" : "B6 HOLD"
            detail = "stressは1回の操作で3局連続実行します。途中記録があるため再開せず証拠を保全してください。"
            return
        }
        let preliminary = makeReport()
        guard preliminary.shallowReproducibilityPassed,
              preliminary.standardOperationalPassed else {
            status = "B6 HOLD"
            detail = "標準ゲートがPASSしていないためstressへ進めません。decision=\(preliminary.policyDecision)"
            return
        }
        guard VE1BB6Environment.platform == "device",
              VE1BB6Environment.thermalState == "nominal" else {
            status = "B6 HOLD"
            detail = "stress 3連続runは物理iPhoneのthermal=nominalから開始してください。"
            return
        }

        isRunning = true
        status = "stress 3連続run 実行中"
        defer { isRunning = false }

        do {
            for ordinal in 1...stressRunTarget {
                status = "stress \(ordinal)/\(stressRunTarget) 実行中（cooldown禁止）"
                let run = try await executeRun(kind: "stress", ordinal: ordinal)
                state.stressRuns.append(run)
                try persistStateAndReport()
            }
            let report = makeReport()
            status = report.policyDecision
            detail = summaryText(report: report)
        } catch {
            status = "B6 HOLD"
            detail = error.localizedDescription
            refreshReport()
        }
    }

    func refreshReport() {
        do {
            try writeReport(makeReport())
            detail = summaryText(report: makeReport())
        } catch {
            detail = "B6 report更新失敗: \(error.localizedDescription)"
        }
    }

    func evidenceURL(fileName: String) -> URL {
        Self.documentsDirectory.appendingPathComponent(fileName)
    }

    private func executeRun(kind: String, ordinal: Int) async throws -> VE1BB6RunRecord {
        guard let fixture = state.fixture else {
            throw EngineUSISession.ProbeError.protocolError("B6 qualification KIFが固定されていません")
        }
        let fixtureData = try Data(contentsOf: Self.fixtureURL)
        let actualFixtureSHA = Self.sha256Hex(fixtureData)
        guard actualFixtureSHA == fixture.sha256 else {
            throw EngineUSISession.ProbeError.protocolError(
                "B6 fixture SHA mismatch expected=\(fixture.sha256) actual=\(actualFixtureSHA)"
            )
        }
        let game = try KIFParser.parse(data: fixtureData)
        try validateFrozenPrimaryPolicy()
        let verifiedNNUE = try EngineRuntimeIdentity.verifyBundledNNUE()
        try validateQualificationEnvironment(nnueSHA256: verifiedNNUE.sha256)
        let startedAt = Date()
        let startThermal = VE1BB6Environment.thermalState
        let clockStart = ContinuousClock.now

        let shallow = ShallowAnalysisViewModel()
        let deep = DeepAnalysisViewModel()
        await shallow.analyze(game: game, fileName: fixture.fileName, movetimeMs: 150)

        if shallow.status == "浅解析 PASS" {
            await deep.analyze(
                game: game,
                shallowEntries: shallow.entries,
                diagnosticURL: shallow.diagnosticURL,
                deepMovetimeMs: 800,
                multiPV: 3,
                maxPositions: 5,
                nodePolicy: policy
            )
        }

        let wholeElapsedMs = Self.elapsedMilliseconds(from: clockStart, to: ContinuousClock.now)
        let endedAt = Date()
        let endThermal = VE1BB6Environment.thermalState

        var positions: [VE1BB6PositionSummary] = []
        var incompleteAttempts: [VE1BB6AttemptSummary] = []
        var incompletePly: Int?
        var selectedPlies: [Int] = []
        var top3: [Int] = []
        var evidenceFileName: String?
        var evidenceSHA: String?
        var runError: String?

        if shallow.status != "浅解析 PASS" {
            runError = "shallow analysis did not pass"
        } else if let sourceURL = deep.searchEvidenceURL {
            let evidenceData = try Data(contentsOf: sourceURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let document = try decoder.decode(VE1BSearchEvidenceDocument.self, from: evidenceData)

            positions = document.positions.map { position in
                let attempts = position.attempts.map(VE1BB6AttemptSummary.init)
                return VE1BB6PositionSummary(
                    ply: position.ply,
                    elapsedMs: attempts.reduce(0) { $0 + $1.elapsedMs },
                    attemptCount: attempts.count,
                    stabilityState: position.stabilityState,
                    attempts: attempts
                )
            }
            selectedPlies = positions.map(\.ply)
            incompleteAttempts = document.incompleteAttempts.map(VE1BB6AttemptSummary.init)
            if let command = document.incompleteAttempts.first?.positionCommand,
               let move = game.moves.first(where: { $0.positionBefore == command }) {
                incompletePly = move.ply
                selectedPlies.append(move.ply)
            }
            if selectedPlies.count >= 3 {
                // document.positions preserves the production Deep selector order.
                // Record shallow Top-3 even when a later Deep position becomes incomplete.
                top3 = Array(selectedPlies.prefix(3))
            }
            runError = document.error

            let label = String(format: "%02d", ordinal)
            let fileName = "ve1b-b6-primary-\(kind)-\(label)-search-evidence.json"
            let destination = Self.documentsDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: destination)
            try evidenceData.write(to: destination, options: .atomic)
            evidenceFileName = fileName
            evidenceSHA = Self.sha256Hex(evidenceData)
        } else {
            runError = "VE1-B search evidence JSON was not produced"
        }

        let shallowSamples = shallow.entries.map {
            VE1BB6ShallowSample(
                ply: $0.ply,
                elapsedMs: $0.elapsedMs,
                thermalBefore: $0.thermalBefore,
                thermalAfter: $0.thermalAfter
            )
        }
        let deepState = Self.deepStateKey(deep.runState)
        let everyAttempt = positions.flatMap(\.attempts) + incompleteAttempts
        let hasIncompleteSearch = everyAttempt.contains { !Self.isCompletedSearch($0.completion) }
        let safeIncompleteState = hasIncompleteSearch
            ? deepState == "incomplete"
            : deepState == "completed"

        return VE1BB6RunRecord(
            id: "primary-\(kind)-\(ordinal)-\(Int(startedAt.timeIntervalSince1970))",
            kind: kind,
            ordinal: ordinal,
            startedAt: startedAt,
            endedAt: endedAt,
            platform: VE1BB6Environment.platform,
            deviceModelIdentifier: VE1BB6Environment.hardwareModelIdentifier,
            osVersion: VE1BB6Environment.osVersion,
            appVersion: VE1BB6Environment.appVersion,
            appBuild: VE1BB6Environment.appBuild,
            gitCommit: VE1BB6Environment.gitCommit,
            yaneuraOuPin: VE1BB6Environment.yaneuraOuPin,
            nnueSHA256: verifiedNNUE.sha256,
            fvScale: EngineRuntimeAuthority.fvScale,
            threads: 1,
            hashMB: 64,
            bookFile: "no_book",
            pvIntervalMs: VE1BEngineEvidenceAuthority.pvIntervalMs,
            shallowMovetimeMs: 150,
            nodePolicyAuthorityStatus: policy.authorityStatus,
            candidateDiscoveryNodeTiers: policy.candidateDiscoveryNodeTiers,
            confirmationNodeTiers: policy.confirmationNodeTiers,
            safetyCeilingMs: policy.safetyCeilingMs,
            startThermal: startThermal,
            endThermal: endThermal,
            shallowStatus: shallow.status,
            shallowTop3Plies: top3,
            shallowSamples: shallowSamples,
            deepState: deepState,
            deepStatus: deep.status,
            deepDisplayStatus: deep.displayStatus,
            selectedDeepPlies: selectedPlies,
            completedPositions: positions,
            incompletePly: incompletePly,
            incompleteAttempts: incompleteAttempts,
            safeIncompleteState: safeIncompleteState,
            wholeGameElapsedMs: wholeElapsedMs,
            rawEvidenceFileName: evidenceFileName,
            rawEvidenceSHA256: evidenceSHA,
            runError: runError
        )
    }

    private func makeReport() -> VE1BB6Report {
        let top3Runs = state.standardRuns.map(\.shallowTop3Plies)
        let pairwise = VE1BPhysicalQualificationMetrics.pairwiseJaccards(top3Runs)
        let pairRecords = pairwise.map {
            VE1BB6PairwiseJaccardRecord(
                leftRun: $0.leftRunIndex + 1,
                rightRun: $0.rightRunIndex + 1,
                value: $0.value
            )
        }
        let minimumJaccard = pairwise.map(\.value).min()
        let modal = VE1BPhysicalQualificationMetrics.modalTop1(top3Runs)

        let standardPositionElapsed = state.standardRuns.flatMap { $0.completedPositions.map(\.elapsedMs) }
        let standardWholeElapsed = state.standardRuns.map(\.wholeGameElapsedMs)
        let standardAttempts = state.standardRuns.flatMap(\.allAttempts)
        let stressAttempts = state.stressRuns.flatMap(\.allAttempts)

        let standardIncomplete = standardAttempts.filter { !Self.isCompletedSearch($0.completion) }
        let stressIncomplete = stressAttempts.filter { !Self.isCompletedSearch($0.completion) }
        let standardCompletionCounts = Self.completionCounts(standardAttempts)
        let stressCompletionCounts = Self.completionCounts(stressAttempts)
        let standardIncompleteRate: Double? = standardAttempts.isEmpty
            ? nil
            : Double(standardIncomplete.count) / Double(standardAttempts.count)
        let standardThermals = Self.allThermalObservations(runs: state.standardRuns)
        let stressThermals = Self.allThermalObservations(runs: state.stressRuns)

        let shallowPassed = state.standardRuns.count == standardRunTarget
            && top3Runs.allSatisfy { $0.count == 3 }
            && pairwise.count == 10
            && (minimumJaccard ?? 0) >= 0.50
            && modal.count >= 4

        let standardEvidenceIntegrityPassed = state.standardRuns.count == standardRunTarget
            && state.standardRuns.allSatisfy { run in
                run.shallowStatus == "浅解析 PASS"
                    && run.rawEvidenceFileName != nil
                    && run.rawEvidenceSHA256 != nil
                    && (run.deepState == "completed" || run.deepState == "incomplete")
            }
        let allCompletedPositionsHaveNine = state.standardRuns.allSatisfy { run in
            run.deepState == "completed"
                && run.incompleteAttempts.isEmpty
                && run.completedPositions.count == run.selectedDeepPlies.count
                && run.completedPositions.allSatisfy { $0.attemptCount == 9 }
        }
        let deepMedian = VE1BPhysicalQualificationMetrics.median(standardPositionElapsed)
        let deepP95 = VE1BPhysicalQualificationMetrics.nearestRankP95(standardPositionElapsed)
        let wholeMedian = VE1BPhysicalQualificationMetrics.median(standardWholeElapsed)
        let wholeP95 = VE1BPhysicalQualificationMetrics.nearestRankP95(standardWholeElapsed)
        let standardOperationalPassed = state.standardRuns.count == standardRunTarget
            && allCompletedPositionsHaveNine
            && !standardPositionElapsed.isEmpty
            && (deepMedian ?? .infinity) <= 15_000
            && (deepP95 ?? Int.max) <= 25_000
            && (wholeMedian ?? .infinity) <= 90_000
            && (wholeP95 ?? Int.max) <= 120_000
            && standardIncomplete.isEmpty
            && state.standardRuns.allSatisfy { $0.startThermal == "nominal" }
            && !standardThermals.contains("serious")
            && !standardThermals.contains("critical")

        let stressIncompleteRate: Double? = stressAttempts.isEmpty
            ? nil
            : Double(stressIncomplete.count) / Double(stressAttempts.count)
        let stressEvidenceIntegrityPassed = state.stressRuns.count == stressRunTarget
            && state.stressRuns.allSatisfy { run in
                guard run.shallowStatus == "浅解析 PASS",
                      run.rawEvidenceFileName != nil,
                      run.rawEvidenceSHA256 != nil,
                      run.completedPositions.allSatisfy({ $0.attemptCount == 9 }) else {
                    return false
                }
                switch run.deepState {
                case "completed":
                    return run.incompleteAttempts.isEmpty
                        && run.completedPositions.count == run.selectedDeepPlies.count
                        && run.safeIncompleteState
                case "incomplete":
                    return !run.incompleteAttempts.isEmpty && run.safeIncompleteState
                default:
                    return false
                }
            }
        let stressPassed = stressEvidenceIntegrityPassed
            && state.stressRuns.first?.startThermal == "nominal"
            && !stressThermals.contains("critical")
            && (stressIncompleteRate ?? 1.0) <= 0.05
            && state.stressRuns.allSatisfy { $0.safeIncompleteState }

        var decision = "B6_HOLD"
        var reasons: [String] = []
        if state.standardRuns.count < standardRunTarget {
            reasons.append("standard_runs_incomplete")
        } else if !standardEvidenceIntegrityPassed {
            reasons.append("standard_evidence_integrity_failed")
        } else if !allCompletedPositionsHaveNine || !standardIncomplete.isEmpty {
            decision = "FALLBACK_REQUIRED"
            reasons.append("primary_standard_incomplete_search_gate_failed")
        } else if !shallowPassed {
            reasons.append("shallow_reproducibility_failed_requires_fixed_node_redesign")
        } else if !standardOperationalPassed {
            decision = "FALLBACK_REQUIRED"
            reasons.append("primary_standard_operational_gate_failed")
        } else if state.stressRuns.count < stressRunTarget {
            reasons.append("stress_runs_incomplete")
        } else if !stressEvidenceIntegrityPassed {
            reasons.append("stress_evidence_integrity_failed")
        } else if !stressPassed {
            decision = "FALLBACK_REQUIRED"
            reasons.append("primary_stress_gate_failed")
        } else {
            decision = "PRIMARY_PASS"
            reasons.append("all_primary_b6_physical_gates_passed")
        }

        return VE1BB6Report(
            schemaVersion: 1,
            generatedAt: Date(),
            authority: "BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010 + PROVEN_MATE_TERMINATION_AMENDMENT_20261011",
            policyDecision: decision,
            decisionReasons: reasons,
            fixture: state.fixture,
            standardRuns: state.standardRuns,
            stressRuns: state.stressRuns,
            pairwiseTop3Jaccard: pairRecords,
            minimumTop3Jaccard: minimumJaccard,
            modalTop1Ply: modal.ply,
            modalTop1Count: modal.count,
            deepPositionMedianMs: deepMedian,
            deepPositionP95Ms: deepP95,
            wholeGameMedianMs: wholeMedian,
            wholeGameP95Ms: wholeP95,
            standardAttemptCount: standardAttempts.count,
            standardCompletionCounts: standardCompletionCounts,
            standardNodeBudgetReachedCount: standardAttempts.filter { $0.completion == "node_budget_reached" }.count,
            standardProvenMateTerminationCount: standardAttempts.filter { $0.completion == "proven_mate_termination" }.count,
            standardIncompleteCount: standardIncomplete.count,
            standardIncompleteRate: standardIncompleteRate,
            standardSeriousThermalObservationCount: standardThermals.filter { $0 == "serious" }.count,
            standardCriticalThermalObservationCount: standardThermals.filter { $0 == "critical" }.count,
            stressAttemptCount: stressAttempts.count,
            stressCompletionCounts: stressCompletionCounts,
            stressIncompleteCount: stressIncomplete.count,
            stressIncompleteRate: stressIncompleteRate,
            stressCriticalThermalObservationCount: stressThermals.filter { $0 == "critical" }.count,
            stressSafeIncompleteHandlingPassed: state.stressRuns.count == stressRunTarget
                && state.stressRuns.allSatisfy { $0.safeIncompleteState },
            incompleteStateProof: "test=\(VE1BB6Environment.incompleteProofTestName); workflow=\(VE1BB6Environment.incompleteProofWorkflow); ciRunID=\(VE1BB6Environment.incompleteProofRunID); result=\(VE1BB6Environment.incompleteProofResult); gitCommit=\(VE1BB6Environment.gitCommit); physicalRunDisplayStatusField=deepDisplayStatus",
            shallowReproducibilityPassed: shallowPassed,
            standardEvidenceIntegrityPassed: standardEvidenceIntegrityPassed,
            standardOperationalPassed: standardOperationalPassed,
            stressEvidenceIntegrityPassed: stressEvidenceIntegrityPassed,
            stressPassed: stressPassed
        )
    }

    private func summaryText(report: VE1BB6Report) -> String {
        let minJaccard = report.minimumTop3Jaccard.map { String(format: "%.3f", $0) } ?? "-"
        let standardRate = report.standardIncompleteRate.map { String(format: "%.3f", $0) } ?? "-"
        let stressRate = report.stressIncompleteRate.map { String(format: "%.3f", $0) } ?? "-"
        return [
            "decision=\(report.policyDecision)",
            "standard=\(state.standardRuns.count)/5 stress=\(state.stressRuns.count)/3",
            "shallow_jaccard_min=\(minJaccard) modal_top1=\(report.modalTop1Ply.map(String.init) ?? "-") count=\(report.modalTop1Count)",
            "deep_median_ms=\(report.deepPositionMedianMs.map { String(format: "%.1f", $0) } ?? "-") p95_ms=\(report.deepPositionP95Ms.map(String.init) ?? "-")",
            "whole_median_ms=\(report.wholeGameMedianMs.map { String(format: "%.1f", $0) } ?? "-") p95_ms=\(report.wholeGameP95Ms.map(String.init) ?? "-")",
            "standard_incomplete=\(report.standardIncompleteCount) rate=\(standardRate) proven_mate=\(report.standardProvenMateTerminationCount)",
            "stress_incomplete_rate=\(stressRate) critical=\(report.stressCriticalThermalObservationCount)",
            "reasons=\(report.decisionReasons.joined(separator: ","))"
        ].joined(separator: "\n")
    }

    private func persistStateAndReport() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(state).write(to: Self.stateURL, options: .atomic)
        try writeReport(makeReport())
    }

    private func writeReport(_ report: VE1BB6Report) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(report).write(to: Self.reportFileURL, options: .atomic)
        reportURL = Self.reportFileURL
    }

    private func loadState() {
        guard let data = try? Data(contentsOf: Self.stateURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            state = try decoder.decode(VE1BB6PersistentState.self, from: data)
            status = "B6 記録復元"
        } catch {
            status = "B6 HOLD"
            detail = "保存済みB6 stateを復元できません: \(error.localizedDescription)"
        }
    }

    private func validateFrozenPrimaryPolicy() throws {
        guard policy.candidateDiscoveryNodeTiers == [50_000, 100_000, 200_000],
              policy.confirmationNodeTiers == [50_000, 100_000, 200_000],
              policy.candidateDiscoveryNodes == 50_000,
              policy.safetyCeilingMs == 15_000,
              policy.authorityStatus == "UNFROZEN_CALIBRATION" else {
            throw EngineUSISession.ProbeError.protocolError(
                "B6 primary policy drift detected; expected 50k/100k/200k, safety=15000, UNFROZEN_CALIBRATION"
            )
        }
    }

    private func validateQualificationEnvironment(nnueSHA256: String) throws {
        guard VE1BB6Environment.platform == "device" else {
            throw EngineUSISession.ProbeError.protocolError("B6 qualification requires platform=device")
        }
        guard VE1BB6Environment.hardwareModelIdentifier == VE1BB6Environment.requiredDeviceModelIdentifier else {
            throw EngineUSISession.ProbeError.protocolError(
                "B6 device floor mismatch expected=\(VE1BB6Environment.requiredDeviceModelIdentifier) actual=\(VE1BB6Environment.hardwareModelIdentifier)"
            )
        }
        guard VE1BB6Environment.osVersion == VE1BB6Environment.requiredOSVersion else {
            throw EngineUSISession.ProbeError.protocolError(
                "B6 OS baseline mismatch expected=\(VE1BB6Environment.requiredOSVersion) actual=\(VE1BB6Environment.osVersion)"
            )
        }
        guard VE1BB6Environment.gitCommit != "unknown",
              VE1BB6Environment.appVersion != "unknown",
              VE1BB6Environment.appBuild != "unknown" else {
            throw EngineUSISession.ProbeError.protocolError("B6 app provenance is incomplete")
        }
        let proofRunID = VE1BB6Environment.incompleteProofRunID
        guard VE1BB6Environment.incompleteProofResult == "PASS",
              VE1BB6Environment.incompleteProofTestName == "B6IncompleteStateProductionAbortProbe",
              VE1BB6Environment.incompleteProofWorkflow == "iOS Simulator E2E",
              !proofRunID.isEmpty, proofRunID != "unknown",
              proofRunID.allSatisfy({ $0.isNumber }) else {
            throw EngineUSISession.ProbeError.protocolError(
                "B6 incomplete-state Simulator proof is missing or not PASS"
            )
        }

        if let prior = (state.standardRuns + state.stressRuns).first {
            let unchanged = prior.deviceModelIdentifier == VE1BB6Environment.hardwareModelIdentifier
                && prior.osVersion == VE1BB6Environment.osVersion
                && prior.appVersion == VE1BB6Environment.appVersion
                && prior.appBuild == VE1BB6Environment.appBuild
                && prior.gitCommit == VE1BB6Environment.gitCommit
                && prior.yaneuraOuPin == VE1BB6Environment.yaneuraOuPin
                && prior.nnueSHA256 == nnueSHA256
            guard unchanged else {
                throw EngineUSISession.ProbeError.protocolError(
                    "B6 campaign provenance changed after measurement began; do not pool evidence across builds/devices"
                )
            }
        }
    }

    private static func deepStateKey(_ state: DeepAnalysisRunState) -> String {
        switch state {
        case .idle: return "idle"
        case .running: return "running"
        case .completed: return "completed"
        case .incomplete: return "incomplete"
        case .error: return "error"
        }
    }

    private static func isCompletedSearch(_ completion: String) -> Bool {
        completion == "node_budget_reached" || completion == "proven_mate_termination"
    }

    private static func completionCounts(_ attempts: [VE1BB6AttemptSummary]) -> [String: Int] {
        Dictionary(grouping: attempts, by: \.completion).mapValues(\.count)
    }

    private static func allThermalObservations(runs: [VE1BB6RunRecord]) -> [String] {
        runs.flatMap { run in
            var values = [run.startThermal, run.endThermal]
            for sample in run.shallowSamples {
                values.append(sample.thermalBefore)
                values.append(sample.thermalAfter)
            }
            for attempt in run.allAttempts {
                values.append(attempt.thermalBefore)
                values.append(attempt.thermalAfter)
            }
            return values
        }
    }

    private static func potentialSelectableCount(game: KIFGame) -> Int {
        let sente = game.metadata["先手"] ?? ""
        let gote = game.metadata["後手"] ?? ""
        if sente.contains("あなた"), !gote.contains("あなた") {
            return game.moves.filter { !$0.ply.isMultiple(of: 2) }.count
        }
        if gote.contains("あなた"), !sente.contains("あなた") {
            return game.moves.filter { $0.ply.isMultiple(of: 2) }.count
        }
        return game.moves.count
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func elapsedMilliseconds(
        from start: ContinuousClock.Instant,
        to end: ContinuousClock.Instant
    ) -> Int {
        let components = start.duration(to: end).components
        return Int(components.seconds * 1000)
            + Int(components.attoseconds / 1_000_000_000_000_000)
    }

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static var fixtureURL: URL {
        documentsDirectory.appendingPathComponent("ve1b-b6-qualification.kif")
    }

    private static var stateURL: URL {
        documentsDirectory.appendingPathComponent("ve1b-b6-state.json")
    }

    private static var reportFileURL: URL {
        documentsDirectory.appendingPathComponent("ve1b-b6-report.json")
    }
}

struct VE1BPhysicalQualificationView: View {
    @StateObject private var model = VE1BPhysicalQualificationViewModel()
    @State private var showingImporter = false

    var body: some View {
        Form {
            Section("B6 Authority") {
                Text("物理iPhoneで 50k→100k→200k の9-search方針を、標準5回＋stress 3連続で測定します。標準runは毎回 thermal=nominal から開始し、stressは最初だけnominalを確認して途中cooldownしません。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("現在thermal: \(model.currentThermal)")
                    .font(.system(.footnote, design: .monospaced))
            }

            Section("固定棋譜") {
                Button(model.fixtureLocked ? "棋譜固定済み" : "B6 qualification KIFを固定") {
                    showingImporter = true
                }
                .disabled(model.isRunning || (model.fixtureLocked && (!model.state.standardRuns.isEmpty || !model.state.stressRuns.isEmpty)))

                if let fixture = model.state.fixture {
                    Text("\(fixture.fileName)\nSHA-256: \(fixture.sha256)\n\(fixture.moveCount)手")
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
            }

            Section("標準 qualification") {
                Text("進捗 \(model.standardProgressText)")
                Button(model.isRunning ? "実行中…" : "次の標準runを実行") {
                    Task { await model.runNextStandard() }
                }
                .disabled(model.isRunning || !model.fixtureLocked || model.standardComplete)
            }

            Section("Stress characterization") {
                Text("進捗 \(model.stressProgressText)")
                Button(model.isRunning ? "3連続実行中…" : "stress 3連続runを実行") {
                    Task { await model.runStressCampaign() }
                }
                .disabled(model.isRunning || !model.standardComplete || !model.state.stressRuns.isEmpty)
            }

            Section("判定・証拠") {
                Text(model.status)
                    .font(.headline)
                if model.isRunning {
                    ProgressView()
                }
                if !model.detail.isEmpty {
                    Text(model.detail)
                        .font(.system(.footnote, design: .monospaced))
                        .textSelection(.enabled)
                }
                if let reportURL = model.reportURL {
                    ShareLink(item: reportURL) {
                        Label("B6集約report JSONを共有", systemImage: "square.and.arrow.up")
                    }
                }
                ForEach(model.state.standardRuns + model.state.stressRuns) { run in
                    if let fileName = run.rawEvidenceFileName {
                        ShareLink(item: model.evidenceURL(fileName: fileName)) {
                            Label("\(run.kind) #\(run.ordinal) raw Evidence", systemImage: "doc")
                        }
                    }
                }
            }
        }
        .navigationTitle("VE1-B B6実機計測")
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                model.lockFixture(url)
            }
        }
    }
}

struct VE1BB6RootView: View {
    @State private var showingB6 = false

    var body: some View {
        VE1ARootView()
            .overlay(alignment: .bottomLeading) {
                Button {
                    showingB6 = true
                } label: {
                    Label("VE1-B B6", systemImage: "gauge")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.regularMaterial, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding()
                .accessibilityLabel("VE1-B B6 物理iPhone計測")
            }
            .sheet(isPresented: $showingB6) {
                NavigationStack {
                    VE1BPhysicalQualificationView()
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("閉じる") { showingB6 = false }
                            }
                        }
                }
            }
    }
}
