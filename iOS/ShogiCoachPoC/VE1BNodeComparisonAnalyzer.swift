import Foundation
import ShogiCoachCore

struct VE1BNodeSearchPolicy: Sendable {
    let candidateDiscoveryNodes: Int
    let candidateDiscoveryNodeTiers: [Int]
    let confirmationNodeTiers: [Int]
    let safetyCeilingMs: Int
    let authorityStatus: String

    init(
        candidateDiscoveryNodes: Int,
        candidateDiscoveryNodeTiers: [Int]? = nil,
        confirmationNodeTiers: [Int],
        safetyCeilingMs: Int,
        authorityStatus: String
    ) {
        self.candidateDiscoveryNodes = candidateDiscoveryNodes
        self.candidateDiscoveryNodeTiers = candidateDiscoveryNodeTiers ?? confirmationNodeTiers
        self.confirmationNodeTiers = confirmationNodeTiers
        self.safetyCeilingMs = safetyCeilingMs
        self.authorityStatus = authorityStatus
    }

    /// Calibration-only values used to exercise VE1-B on Simulator/device.
    /// These values are NOT production authority and must be replaced/frozen
    /// only after the B6 physical-device measurements are accepted.
    static let calibrationUnfrozen = VE1BNodeSearchPolicy(
        candidateDiscoveryNodes: 50_000,
        candidateDiscoveryNodeTiers: [50_000, 100_000, 200_000],
        confirmationNodeTiers: [50_000, 100_000, 200_000],
        safetyCeilingMs: 15_000,
        authorityStatus: "UNFROZEN_CALIBRATION"
    )

    func validate() throws {
        guard candidateDiscoveryNodes > 0,
              safetyCeilingMs > 0,
              candidateDiscoveryNodeTiers.count >= 2,
              candidateDiscoveryNodeTiers.count == confirmationNodeTiers.count,
              candidateDiscoveryNodeTiers.first == candidateDiscoveryNodes,
              confirmationNodeTiers.count >= 2 else {
            throw EngineUSISession.ProbeError.protocolError("VE1-B node policy is incomplete")
        }
        try Self.validateIncreasing(candidateDiscoveryNodeTiers, label: "candidate discovery")
        try Self.validateIncreasing(confirmationNodeTiers, label: "confirmation")
    }

    private static func validateIncreasing(_ tiers: [Int], label: String) throws {
        var previous = 0
        for value in tiers {
            guard value > previous else {
                throw EngineUSISession.ProbeError.protocolError(
                    "VE1-B \(label) node tiers must be strictly increasing"
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
    let bestEvidence: VE1BSearchAttemptRecord
    let actualEvidence: VE1BSearchAttemptRecord

    /// Compatibility view for downstream presentation that needs the last
    /// measurement's thermal/runtime state. Full evidence contains both searches.
    var evidence: VE1BSearchAttemptRecord { actualEvidence }
}

struct VE1BNodeComparisonResult: Sendable {
    let policy: VE1BNodeSearchPolicy
    let candidateLines: [VE1BEngineLine]
    let discoveryEvidence: VE1BSearchAttemptRecord
    let discoveryTierEvidence: [VE1BSearchAttemptRecord]
    let candidateDiscoveryTopMoves: [String]
    let attempts: [VE1BNodeComparisonAttempt]
    let stabilityEvidenceTiers: [VE1BStabilityEvidenceTier]
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
        discoveryTierEvidence.reduce(0) { $0 + $1.elapsedMs }
            + attempts.reduce(0) { $0 + $1.bestEvidence.elapsedMs + $1.actualEvidence.elapsedMs }
    }
    var evidenceRecords: [VE1BSearchAttemptRecord] {
        discoveryTierEvidence + attempts.flatMap { [$0.bestEvidence, $0.actualEvidence] }
    }
    var finalNodeBudget: Int { finalAttempt.nodeBudget }
}

struct VE1BNodeComparisonFailure: Error, LocalizedError, Sendable {
    let detail: String
    let evidence: [VE1BSearchAttemptRecord]

    var errorDescription: String? { "VE1-B解析未完了: \(detail)" }
}

enum VE1BNodeComparisonAnalyzer {
    private struct DiscoveryTier {
        let nodeBudget: Int
        let lines: [VE1BEngineLine]
        let topLine: VE1BEngineLine
        let evidence: VE1BSearchAttemptRecord
    }

    private struct MeasuredTier {
        let nodeBudget: Int
        let bestLine: VE1BEngineLine
        let actualLine: VE1BEngineLine
        let lossCp: Int?
        let comparisonInversion: Bool
        let bestEvidence: VE1BSearchAttemptRecord
        let actualEvidence: VE1BSearchAttemptRecord
    }

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
        var discoveryTiers: [DiscoveryTier] = []

        // Candidate identity is part of the B5 evidence. Each tier is a cold,
        // unrestricted MultiPV discovery; all candidate observations, including
        // bound metadata, are persisted for later VE1-C near-tie classification.
        for (index, nodes) in policy.candidateDiscoveryNodeTiers.enumerated() {
            _ = try await session.resetForColdSeries(reason: "candidate_discovery_\(index)")
            let sample = try await session.analyzePositionNodes(
                command: command,
                nodeBudget: nodes,
                safetyCeilingMs: policy.safetyCeilingMs,
                role: .candidateDiscovery,
                multiPV: candidateMultiPV
            )
            let record = VE1BSearchAttemptRecord(
                attemptID: "discovery-\(index)-\(nodes)-tt\(sample.ttGeneration)",
                positionCommand: command,
                multiPV: candidateMultiPV,
                searchMoves: [],
                measurementTarget: "candidate_discovery",
                sample: sample
            )
            evidence.append(record)

            guard sample.isNormalCompletedResult,
                  let result = sample.result else {
                throw VE1BNodeComparisonFailure(
                    detail: "candidate discovery tier \(nodes) did not complete normally (\(sample.completion.rawValue))",
                    evidence: evidence
                )
            }

            let lines = result.principalVariations
                .prefix(candidateMultiPV)
                .compactMap(makeLine)
            guard let topLine = lines.first else {
                throw VE1BNodeComparisonFailure(
                    detail: "candidate discovery tier \(nodes) has no scored PV",
                    evidence: evidence
                )
            }

            discoveryTiers.append(
                DiscoveryTier(
                    nodeBudget: nodes,
                    lines: lines,
                    topLine: topLine,
                    evidence: record
                )
            )
        }

        guard let deepestDiscovery = discoveryTiers.last else {
            throw VE1BNodeComparisonFailure(
                detail: "candidate discovery produced no tiers",
                evidence: evidence
            )
        }

        // The deepest unrestricted discovery supplies the recommendation to be
        // measured. Comparison is NOT a MultiPV2 race. At each node budget the
        // recommended move and actual move are each measured in their own cold
        // searchmoves-one-move / MultiPV1 run. Therefore N means N nodes PER MOVE.
        let discoveredBest = deepestDiscovery.topLine
        let candidates = deepestDiscovery.lines
        var measuredTiers: [MeasuredTier] = []
        var stabilityEvidence: [VE1BStabilityEvidenceTier] = []

        for (index, nodes) in policy.confirmationNodeTiers.enumerated() {
            let role: EngineSearchRole = index == 0 ? .directComparison : .confirmation

            _ = try await session.resetForColdSeries(reason: "comparison_best_\(index)")
            let bestSample = try await session.analyzePositionNodes(
                command: command,
                nodeBudget: nodes,
                safetyCeilingMs: policy.safetyCeilingMs,
                role: role,
                searchMoves: [discoveredBest.move],
                multiPV: 1
            )
            let bestRecord = VE1BSearchAttemptRecord(
                attemptID: "best-\(index)-\(nodes)-tt\(bestSample.ttGeneration)",
                positionCommand: command,
                multiPV: 1,
                searchMoves: [discoveredBest.move],
                measurementTarget: "recommended_move",
                sample: bestSample
            )
            evidence.append(bestRecord)
            guard bestSample.isNormalCompletedResult,
                  let bestResult = bestSample.result,
                  let comparedBest = bestResult.principalVariations.compactMap(makeLine)
                    .first(where: { $0.move == discoveredBest.move }) else {
                throw VE1BNodeComparisonFailure(
                    detail: "recommended-move tier \(nodes) did not produce its single-move line",
                    evidence: evidence
                )
            }

            _ = try await session.resetForColdSeries(reason: "comparison_actual_\(index)")
            let actualSample = try await session.analyzePositionNodes(
                command: command,
                nodeBudget: nodes,
                safetyCeilingMs: policy.safetyCeilingMs,
                role: role,
                searchMoves: [actualMove],
                multiPV: 1
            )
            let actualRecord = VE1BSearchAttemptRecord(
                attemptID: "actual-\(index)-\(nodes)-tt\(actualSample.ttGeneration)",
                positionCommand: command,
                multiPV: 1,
                searchMoves: [actualMove],
                measurementTarget: "actual_move",
                sample: actualSample
            )
            evidence.append(actualRecord)
            guard actualSample.isNormalCompletedResult,
                  let actualResult = actualSample.result,
                  let comparedActual = actualResult.principalVariations.compactMap(makeLine)
                    .first(where: { $0.move == actualMove }) else {
                throw VE1BNodeComparisonFailure(
                    detail: "actual-move tier \(nodes) did not produce its single-move line",
                    evidence: evidence
                )
            }

            let inversion = discoveredBest.move != actualMove
                && isBetter(comparedActual.score, than: comparedBest.score)
            let loss = centipawnLoss(best: comparedBest, actual: comparedActual)
            measuredTiers.append(
                MeasuredTier(
                    nodeBudget: nodes,
                    bestLine: comparedBest,
                    actualLine: comparedActual,
                    lossCp: loss,
                    comparisonInversion: inversion,
                    bestEvidence: bestRecord,
                    actualEvidence: actualRecord
                )
            )
            stabilityEvidence.append(
                makeStabilityEvidence(
                    nodeBudget: nodes,
                    candidateTop: discoveryTiers[index].topLine,
                    best: comparedBest,
                    actual: comparedActual,
                    lossCp: loss,
                    inversion: inversion
                )
            )
        }

        let reclassified = VE1BStabilityReclassifier.assess(
            evidence: stabilityEvidence,
            rules: .ve1bCalibration
        )
        guard reclassified.tierClassifications.count == measuredTiers.count else {
            throw VE1BNodeComparisonFailure(
                detail: "stability reclassification count mismatch",
                evidence: evidence
            )
        }

        let attempts = measuredTiers.enumerated().map { index, measured in
            let classified = reclassified.tierClassifications[index]
            return VE1BNodeComparisonAttempt(
                nodeBudget: measured.nodeBudget,
                bestLine: measured.bestLine,
                actualLine: measured.actualLine,
                lossCp: measured.lossCp,
                comparisonInversion: measured.comparisonInversion,
                unstableReasons: classified.unstableReasons,
                qualifiesForStability: classified.qualifiesForStability,
                conclusionGroup: classified.conclusionGroup,
                bestEvidence: measured.bestEvidence,
                actualEvidence: measured.actualEvidence
            )
        }
        let stability = reclassified.assessment

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
            discoveryEvidence: discoveryTiers[0].evidence,
            discoveryTierEvidence: discoveryTiers.map(\.evidence),
            candidateDiscoveryTopMoves: discoveryTiers.map { $0.topLine.move },
            attempts: attempts,
            stabilityEvidenceTiers: stabilityEvidence,
            stability: stability,
            comparisonInstabilityReasons: reclassified.comparisonInstabilityReasons,
            continuationInstabilityReasons: continuationReasons,
            topCandidateGapCp: stability.state == .stable ? candidateGap(candidates) : nil
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

    private static func makeStabilityEvidence(
        nodeBudget: Int,
        candidateTop: VE1BEngineLine,
        best: VE1BEngineLine,
        actual: VE1BEngineLine,
        lossCp: Int?,
        inversion: Bool
    ) -> VE1BStabilityEvidenceTier {
        let bestScore = scoreEvidence(best.score)
        let actualScore = scoreEvidence(actual.score)
        return VE1BStabilityEvidenceTier(
            nodeBudget: nodeBudget,
            candidateTopMove: candidateTop.move,
            candidateTopBoundKind: candidateTop.boundKind.rawValue,
            bestMove: best.move,
            bestScoreKind: bestScore.kind,
            bestScoreValue: bestScore.value,
            bestBoundKind: best.boundKind.rawValue,
            bestPV: best.pvMoves,
            actualMove: actual.move,
            actualScoreKind: actualScore.kind,
            actualScoreValue: actualScore.value,
            actualBoundKind: actual.boundKind.rawValue,
            actualPV: actual.pvMoves,
            lossCp: lossCp,
            comparisonInversion: inversion
        )
    }

    private static func scoreEvidence(_ score: USIScore) -> (kind: String, value: Int?) {
        switch score {
        case .centipawn(let value, _):
            return ("cp", value)
        case .mate(let value, _):
            return (value >= 0 ? "mate_win" : "mate_loss", value)
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
              candidates[0].boundKind == .exact,
              candidates[1].boundKind == .exact,
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
