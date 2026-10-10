import Foundation
import ShogiCoachCore

struct VE1BNodeSearchPolicy: Sendable {
    let candidateDiscoveryNodes: Int
    let confirmationNodeTiers: [Int]
    let safetyCeilingMs: Int
    let authorityStatus: String

    /// Calibration-only values used to exercise VE1-B on Simulator/device.
    /// These values are NOT production authority and must be replaced/frozen
    /// only after the B6 physical-device measurements are accepted.
    static let calibrationUnfrozen = VE1BNodeSearchPolicy(
        candidateDiscoveryNodes: 50_000,
        confirmationNodeTiers: [50_000, 100_000, 200_000],
        safetyCeilingMs: 15_000,
        authorityStatus: "UNFROZEN_CALIBRATION"
    )

    func validate() throws {
        guard candidateDiscoveryNodes > 0,
              safetyCeilingMs > 0,
              confirmationNodeTiers.count >= 2 else {
            throw EngineUSISession.ProbeError.protocolError("VE1-B node policy is incomplete")
        }
        var previous = 0
        for value in confirmationNodeTiers {
            guard value > previous else {
                throw EngineUSISession.ProbeError.protocolError(
                    "VE1-B confirmation node tiers must be strictly increasing"
                )
            }
            previous = value
        }
    }
}

struct VE1BEngineLine: Sendable {
    let move: String
    let score: USIScore
    let boundKind: USIBoundKind
    let depth: Int?
    let selDepth: Int?
    let nodes: UInt64?
    let nps: UInt64?
    let pvMoves: [String]

    var scoreText: String {
        let base: String
        switch score {
        case .centipawn(let value, _): base = "cp \(value)"
        case .mate(let value, _): base = "mate \(value)"
        }
        return boundKind == .exact ? base : "\(base) \(boundKind.rawValue)"
    }

    var centipawn: Int? {
        if case .centipawn(let value, _) = score { return value }
        return nil
    }

    var pvText: String { pvMoves.joined(separator: " ") }
    var opponentReply: String { pvMoves.dropFirst().first ?? "-" }
}

struct VE1BNodeComparisonAttempt: Sendable {
    let nodeBudget: Int
    let bestLine: VE1BEngineLine
    let actualLine: VE1BEngineLine
    let lossCp: Int?
    let comparisonInversion: Bool
    let unstableReasons: [String]
    let qualifiesForStability: Bool
    let conclusionGroup: Int
    let evidence: VE1BSearchAttemptRecord
}

struct VE1BNodeComparisonResult: Sendable {
    let policy: VE1BNodeSearchPolicy
    let candidateLines: [VE1BEngineLine]
    let discoveryEvidence: VE1BSearchAttemptRecord
    let attempts: [VE1BNodeComparisonAttempt]
    let stability: VE1BStabilityAssessment
    let comparisonInstabilityReasons: [String]
    let continuationInstabilityReasons: [String]
    let topCandidateGapCp: Int?

    var finalAttempt: VE1BNodeComparisonAttempt { attempts[attempts.count - 1] }
    var comparisonStable: Bool { stability.state == .stable }
    var continuationStable: Bool {
        comparisonStable
            && stability.confirmedBestPVPrefix.count >= 3
            && stability.confirmedActualPVPrefix.count >= 2
    }
    var confirmedBestPV: [String] { stability.confirmedBestPVPrefix }
    var confirmedActualPV: [String] { stability.confirmedActualPVPrefix }
    var totalElapsedMs: Int {
        discoveryEvidence.elapsedMs + attempts.reduce(0) { $0 + $1.evidence.elapsedMs }
    }
    var evidenceRecords: [VE1BSearchAttemptRecord] {
        [discoveryEvidence] + attempts.map(\.evidence)
    }
    var finalNodeBudget: Int { finalAttempt.nodeBudget }
}

struct VE1BNodeComparisonFailure: Error, LocalizedError, Sendable {
    let detail: String
    let evidence: [VE1BSearchAttemptRecord]

    var errorDescription: String? { "VE1-B解析未完了: \(detail)" }
}

enum VE1BNodeComparisonAnalyzer {
    // Frozen only as pre-existing behavior. VE1-C owns semantic recalibration.
    private static let lossSwingThresholdCp = 120

    static func analyze(
        session: EngineUSISession,
        command: String,
        actualMove: String,
        candidateCount: Int = 3,
        policy: VE1BNodeSearchPolicy = .calibrationUnfrozen
    ) async throws -> VE1BNodeComparisonResult {
        try policy.validate()
        let candidateMultiPV = max(1, candidateCount)
        var evidence: [VE1BSearchAttemptRecord] = []

        _ = try await session.resetForColdSeries(reason: "candidate_discovery")
        let discoverySample = try await session.analyzePositionNodes(
            command: command,
            nodeBudget: policy.candidateDiscoveryNodes,
            safetyCeilingMs: policy.safetyCeilingMs,
            role: .candidateDiscovery,
            multiPV: candidateMultiPV
        )
        let discoveryRecord = VE1BSearchAttemptRecord(
            attemptID: "discovery-\(policy.candidateDiscoveryNodes)-tt\(discoverySample.ttGeneration)",
            positionCommand: command,
            multiPV: candidateMultiPV,
            searchMoves: [],
            sample: discoverySample
        )
        evidence.append(discoveryRecord)

        guard discoverySample.isNormalCompletedResult,
              let discoveryResult = discoverySample.result else {
            throw VE1BNodeComparisonFailure(
                detail: "candidate discovery did not complete normally (\(discoverySample.completion.rawValue))",
                evidence: evidence
            )
        }

        let candidates = discoveryResult.principalVariations
            .prefix(candidateMultiPV)
            .compactMap(makeLine)
        guard let discoveredBest = candidates.first else {
            throw VE1BNodeComparisonFailure(
                detail: "candidate discovery has no scored PV",
                evidence: evidence
            )
        }
        guard discoveredBest.boundKind == .exact else {
            throw VE1BNodeComparisonFailure(
                detail: "candidate discovery MultiPV1 is bounded at target",
                evidence: evidence
            )
        }

        let searchMoves = discoveredBest.move == actualMove
            ? [discoveredBest.move]
            : [discoveredBest.move, actualMove]
        let compareMultiPV = searchMoves.count

        // Discovery history must not seed the direct-comparison role.
        _ = try await session.resetForColdSeries(reason: "direct_comparison")

        var attempts: [VE1BNodeComparisonAttempt] = []
        var previousQualifying: VE1BNodeComparisonAttempt?
        var conclusionGroup = 0

        for (index, nodes) in policy.confirmationNodeTiers.enumerated() {
            let role: EngineSearchRole = index == 0 ? .directComparison : .confirmation
            let sample = try await session.analyzePositionNodes(
                command: command,
                nodeBudget: nodes,
                safetyCeilingMs: policy.safetyCeilingMs,
                role: role,
                searchMoves: searchMoves,
                multiPV: compareMultiPV
            )
            let record = VE1BSearchAttemptRecord(
                attemptID: "compare-\(index)-\(nodes)-tt\(sample.ttGeneration)",
                positionCommand: command,
                multiPV: compareMultiPV,
                searchMoves: searchMoves,
                sample: sample
            )
            evidence.append(record)

            guard sample.isNormalCompletedResult,
                  let result = sample.result else {
                throw VE1BNodeComparisonFailure(
                    detail: "node tier \(nodes) did not complete normally (\(sample.completion.rawValue))",
                    evidence: evidence
                )
            }

            let lines = result.principalVariations.compactMap(makeLine)
            guard let comparedBest = lines.first(where: { $0.move == discoveredBest.move }) else {
                throw VE1BNodeComparisonFailure(
                    detail: "node tier \(nodes) missing discovered-best line",
                    evidence: evidence
                )
            }
            let comparedActual: VE1BEngineLine
            if discoveredBest.move == actualMove {
                comparedActual = comparedBest
            } else if let actual = lines.first(where: { $0.move == actualMove }) {
                comparedActual = actual
            } else {
                throw VE1BNodeComparisonFailure(
                    detail: "node tier \(nodes) missing actual-move line",
                    evidence: evidence
                )
            }

            let inversion = discoveredBest.move != actualMove
                && isBetter(comparedActual.score, than: comparedBest.score)
            let loss = centipawnLoss(best: comparedBest, actual: comparedActual)
            var reasons: [String] = []
            if comparedBest.boundKind != .exact || comparedActual.boundKind != .exact {
                reasons.append("bounded_at_target")
            }
            if inversion { reasons.append("comparison_inversion") }

            let currentQualifies = reasons.isEmpty
            if let previousQualifying {
                let pairReasons = disagreementReasons(
                    previous: previousQualifying,
                    best: comparedBest,
                    actual: comparedActual,
                    lossCp: loss,
                    inversion: inversion
                )
                reasons.append(contentsOf: pairReasons)
                if currentQualifies && pairReasons.isEmpty {
                    conclusionGroup = previousQualifying.conclusionGroup
                } else if currentQualifies {
                    conclusionGroup = previousQualifying.conclusionGroup + 1
                }
            } else if currentQualifies {
                conclusionGroup = 0
            }

            let attempt = VE1BNodeComparisonAttempt(
                nodeBudget: nodes,
                bestLine: comparedBest,
                actualLine: comparedActual,
                lossCp: loss,
                comparisonInversion: inversion,
                unstableReasons: Array(Set(reasons)).sorted(),
                qualifiesForStability: currentQualifies,
                conclusionGroup: conclusionGroup,
                evidence: record
            )
            attempts.append(attempt)
            if currentQualifies {
                previousQualifying = attempt
            }
        }

        let tiers = attempts.map { attempt in
            VE1BConfirmationTier(
                nodeBudget: attempt.nodeBudget,
                conclusionFingerprint: attempt.qualifiesForStability
                    ? "group-\(attempt.conclusionGroup)"
                    : nil,
                qualifiesForStability: attempt.qualifiesForStability,
                bestPV: attempt.bestLine.pvMoves,
                actualPV: attempt.actualLine.pvMoves
            )
        }
        let stability = VE1BStabilityEvaluator.assess(tiers)

        var comparisonReasons = Array(Set(attempts.flatMap(\.unstableReasons)).sorted())
        if stability.state != .stable {
            comparisonReasons.append("convergence_\(stability.state.rawValue)")
        }
        comparisonReasons = Array(Set(comparisonReasons)).sorted()

        var continuationReasons: [String] = []
        if stability.state == .stable {
            if stability.confirmedBestPVPrefix.count < 3 {
                continuationReasons.append("best_confirmed_prefix_short")
            }
            if stability.confirmedActualPVPrefix.count < 2 {
                continuationReasons.append("actual_confirmed_prefix_short")
            }
        } else {
            continuationReasons.append("comparison_not_stable")
        }

        return VE1BNodeComparisonResult(
            policy: policy,
            candidateLines: candidates,
            discoveryEvidence: discoveryRecord,
            attempts: attempts,
            stability: stability,
            comparisonInstabilityReasons: comparisonReasons,
            continuationInstabilityReasons: continuationReasons,
            topCandidateGapCp: candidateGap(candidates)
        )
    }

    private static func makeLine(_ info: USIInfo) -> VE1BEngineLine? {
        guard let score = info.score, let move = info.pv.first else { return nil }
        return VE1BEngineLine(
            move: move,
            score: score,
            boundKind: info.boundKind ?? .exact,
            depth: info.depth,
            selDepth: info.selDepth,
            nodes: info.nodes,
            nps: info.nps,
            pvMoves: info.pv
        )
    }

    private static func disagreementReasons(
        previous: VE1BNodeComparisonAttempt,
        best: VE1BEngineLine,
        actual: VE1BEngineLine,
        lossCp: Int?,
        inversion: Bool
    ) -> [String] {
        var reasons: [String] = []
        if previous.bestLine.move != best.move {
            reasons.append("bestmove_changed")
        }
        if scoreKind(previous.bestLine.score) != scoreKind(best.score) {
            reasons.append("best_score_kind_changed")
        }
        if scoreKind(previous.actualLine.score) != scoreKind(actual.score) {
            reasons.append("actual_score_kind_changed")
        }
        if let previousLoss = previous.lossCp, let lossCp,
           abs(previousLoss - lossCp) >= lossSwingThresholdCp {
            reasons.append("loss_changed")
        }
        if previous.comparisonInversion != inversion {
            reasons.append("comparison_inversion_changed")
        }
        return reasons
    }

    private static func scoreKind(_ score: USIScore) -> String {
        switch score {
        case .centipawn: return "cp"
        case .mate(let value, _): return value >= 0 ? "mate_win" : "mate_loss"
        }
    }

    private static func centipawnLoss(best: VE1BEngineLine, actual: VE1BEngineLine) -> Int? {
        if best.move == actual.move { return 0 }
        guard let bestCp = best.centipawn, let actualCp = actual.centipawn,
              bestCp >= actualCp else { return nil }
        return bestCp - actualCp
    }

    private static func candidateGap(_ candidates: [VE1BEngineLine]) -> Int? {
        guard candidates.count >= 2,
              let first = candidates[0].centipawn,
              let second = candidates[1].centipawn else { return nil }
        return max(0, first - second)
    }

    private static func isBetter(_ lhs: USIScore, than rhs: USIScore) -> Bool {
        let left = orderingKey(lhs)
        let right = orderingKey(rhs)
        if left.category != right.category { return left.category > right.category }
        return left.value > right.value
    }

    private static func orderingKey(_ score: USIScore) -> (category: Int, value: Int) {
        switch score {
        case .centipawn(let value, _): return (1, value)
        case .mate(let value, _):
            if value >= 0 { return (2, -abs(value)) }
            return (0, abs(value))
        }
    }
}
