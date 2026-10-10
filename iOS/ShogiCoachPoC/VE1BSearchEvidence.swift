import Foundation
import ShogiCoachCore

struct VE1BSearchObservationRecord: Codable, Sendable {
    let multipv: Int
    let pvHead: String?
    let scoreKind: String?
    let scoreValue: Int?
    let boundKind: String?
    let depth: Int?
    let seldepth: Int?
    let nodes: UInt64?
    let nps: UInt64?
    let timeMs: UInt64?
    let pv: [String]
    let rawUSI: String?

    init(_ info: USIInfo) {
        multipv = info.multipv
        pvHead = info.pv.first
        switch info.score {
        case .centipawn(let value, _):
            scoreKind = "cp"
            scoreValue = value
        case .mate(let value, _):
            scoreKind = "mate"
            scoreValue = value
        case .none:
            scoreKind = nil
            scoreValue = nil
        }
        boundKind = info.boundKind?.rawValue
        depth = info.depth
        seldepth = info.selDepth
        nodes = info.nodes
        nps = info.nps
        timeMs = info.timeMs
        pv = info.pv
        rawUSI = info.rawLine
    }
}

struct VE1BSearchAttemptRecord: Codable, Sendable {
    let attemptID: String
    let positionCommand: String
    let role: String
    let measurementTarget: String
    let nodeBudget: Int
    let safetyCeilingMs: Int
    let pvIntervalMs: Int
    let issuedGoCommand: String
    let ttGeneration: Int
    let multiPV: Int
    let searchMoves: [String]
    let completion: String
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let maxObservedNodes: UInt64
    let observationCount: Int

    /// Raw terminal `bestmove` provenance. This may belong to a deeper partial
    /// iteration than the completed exact measurement below.
    let bestMove: String?
    let bestMoveConsistency: String?

    /// VE1-B measurement selected from the deepest fully completed exact
    /// iteration. Its own depth/nodes are retained and never relabeled as the
    /// requested node target.
    let selectedMove: String?
    let selectedScoreKind: String?
    let selectedScoreValue: Int?
    let selectedBoundKind: String?
    let selectedDepth: Int?
    let selectedSelDepth: Int?
    let selectedNodes: UInt64?
    let selectedPV: [String]

    /// Last scored PV-bearing info line emitted by the engine, retained only as
    /// terminal provenance. It is allowed to be lowerbound/upperbound.
    let terminalScoredMove: String?
    let terminalScoredScoreKind: String?
    let terminalScoredScoreValue: Int?
    let terminalScoredBoundKind: String?
    let terminalScoredDepth: Int?
    let terminalScoredNodes: UInt64?

    let observations: [VE1BSearchObservationRecord]

    init(
        attemptID: String,
        positionCommand: String,
        multiPV: Int,
        searchMoves: [String],
        measurementTarget: String = "unspecified",
        sample: NodeProbeSample
    ) {
        self.attemptID = attemptID
        self.positionCommand = positionCommand
        role = sample.searchRole.rawValue
        self.measurementTarget = measurementTarget
        nodeBudget = sample.nodeBudget
        safetyCeilingMs = sample.safetyCeilingMs
        pvIntervalMs = VE1BEngineEvidenceAuthority.pvIntervalMs
        issuedGoCommand = sample.issuedGoCommand
        ttGeneration = sample.ttGeneration
        self.multiPV = multiPV
        self.searchMoves = searchMoves
        completion = sample.completion.rawValue
        elapsedMs = sample.elapsedMs
        thermalBefore = sample.thermalBefore
        thermalAfter = sample.thermalAfter
        maxObservedNodes = sample.maxObservedNodes
        observationCount = sample.observations.count
        bestMove = sample.terminalResult?.bestMove.move
        bestMoveConsistency = sample.terminalResult?.bestMoveConsistency.rawValue

        if let selected = sample.result?.principalVariations.first {
            selectedMove = selected.pv.first
            switch selected.score {
            case .centipawn(let value, _):
                selectedScoreKind = "cp"
                selectedScoreValue = value
            case .mate(let value, _):
                selectedScoreKind = value >= 0 ? "mate_win" : "mate_loss"
                selectedScoreValue = value
            case .none:
                selectedScoreKind = nil
                selectedScoreValue = nil
            }
            selectedBoundKind = (selected.boundKind ?? .exact).rawValue
            selectedDepth = selected.depth
            selectedSelDepth = selected.selDepth
            selectedNodes = selected.nodes
            selectedPV = selected.pv
        } else {
            selectedMove = nil
            selectedScoreKind = nil
            selectedScoreValue = nil
            selectedBoundKind = nil
            selectedDepth = nil
            selectedSelDepth = nil
            selectedNodes = nil
            selectedPV = []
        }

        if let terminal = sample.observations.last(where: {
            $0.score != nil && !$0.pv.isEmpty
        }) {
            terminalScoredMove = terminal.pv.first
            switch terminal.score {
            case .centipawn(let value, _):
                terminalScoredScoreKind = "cp"
                terminalScoredScoreValue = value
            case .mate(let value, _):
                terminalScoredScoreKind = value >= 0 ? "mate_win" : "mate_loss"
                terminalScoredScoreValue = value
            case .none:
                terminalScoredScoreKind = nil
                terminalScoredScoreValue = nil
            }
            terminalScoredBoundKind = terminal.boundKind?.rawValue
            terminalScoredDepth = terminal.depth
            terminalScoredNodes = terminal.nodes
        } else {
            terminalScoredMove = nil
            terminalScoredScoreKind = nil
            terminalScoredScoreValue = nil
            terminalScoredBoundKind = nil
            terminalScoredDepth = nil
            terminalScoredNodes = nil
        }

        observations = sample.observations.map(VE1BSearchObservationRecord.init)
    }
}

struct VE1BPositionEvidenceRecord: Codable, Sendable {
    let ply: Int
    let stabilityState: String
    let confirmedBestPVPlyCount: Int
    let confirmedActualPVPlyCount: Int
    let attempts: [VE1BSearchAttemptRecord]
    let stabilityEvidenceTiers: [VE1BStabilityEvidenceTier]
    let stabilityReasons: [String]

    init(
        ply: Int,
        stabilityState: String,
        confirmedBestPVPlyCount: Int,
        confirmedActualPVPlyCount: Int,
        attempts: [VE1BSearchAttemptRecord],
        stabilityEvidenceTiers: [VE1BStabilityEvidenceTier] = [],
        stabilityReasons: [String] = []
    ) {
        self.ply = ply
        self.stabilityState = stabilityState
        self.confirmedBestPVPlyCount = confirmedBestPVPlyCount
        self.confirmedActualPVPlyCount = confirmedActualPVPlyCount
        self.attempts = attempts

        let derived = stabilityEvidenceTiers.isEmpty
            ? Self.deriveStabilityEvidence(from: attempts)
            : stabilityEvidenceTiers
        self.stabilityEvidenceTiers = derived
        if stabilityReasons.isEmpty && !derived.isEmpty {
            self.stabilityReasons = VE1BStabilityReclassifier.assess(
                evidence: derived,
                rules: .ve1bCalibration
            ).comparisonInstabilityReasons
        } else {
            self.stabilityReasons = stabilityReasons
        }
    }

    private static func deriveStabilityEvidence(
        from attempts: [VE1BSearchAttemptRecord]
    ) -> [VE1BStabilityEvidenceTier] {
        let discovery = attempts.filter { $0.measurementTarget == "candidate_discovery" }
        let recommended = attempts.filter { $0.measurementTarget == "recommended_move" }
        let actual = attempts.filter { $0.measurementTarget == "actual_move" }
        guard !discovery.isEmpty, !recommended.isEmpty, !actual.isEmpty else { return [] }

        return recommended.sorted { $0.nodeBudget < $1.nodeBudget }.compactMap { best in
            guard let candidate = discovery.last(where: { $0.nodeBudget == best.nodeBudget }),
                  let played = actual.last(where: { $0.nodeBudget == best.nodeBudget }),
                  let candidateMove = candidate.selectedMove,
                  let candidateBound = candidate.selectedBoundKind,
                  let bestMove = best.selectedMove,
                  let bestKind = best.selectedScoreKind,
                  let bestBound = best.selectedBoundKind,
                  let actualMove = played.selectedMove,
                  let actualKind = played.selectedScoreKind,
                  let actualBound = played.selectedBoundKind else {
                return nil
            }

            let inversion = bestMove != actualMove && Self.isBetter(
                kind: actualKind,
                value: played.selectedScoreValue,
                thanKind: bestKind,
                value: best.selectedScoreValue
            )
            let loss: Int?
            if bestMove == actualMove {
                loss = 0
            } else if bestKind == "cp",
                      actualKind == "cp",
                      let bestValue = best.selectedScoreValue,
                      let actualValue = played.selectedScoreValue,
                      bestValue >= actualValue {
                loss = bestValue - actualValue
            } else {
                loss = nil
            }

            return VE1BStabilityEvidenceTier(
                nodeBudget: best.nodeBudget,
                candidateTopMove: candidateMove,
                candidateTopBoundKind: candidateBound,
                bestMove: bestMove,
                bestScoreKind: bestKind,
                bestScoreValue: best.selectedScoreValue,
                bestBoundKind: bestBound,
                bestPV: best.selectedPV,
                actualMove: actualMove,
                actualScoreKind: actualKind,
                actualScoreValue: played.selectedScoreValue,
                actualBoundKind: actualBound,
                actualPV: played.selectedPV,
                lossCp: loss,
                comparisonInversion: inversion
            )
        }
    }

    private static func isBetter(
        kind: String,
        value: Int?,
        thanKind otherKind: String,
        value otherValue: Int?
    ) -> Bool {
        let left = orderingKey(kind: kind, value: value)
        let right = orderingKey(kind: otherKind, value: otherValue)
        if left.category != right.category { return left.category > right.category }
        return left.value > right.value
    }

    private static func orderingKey(kind: String, value: Int?) -> (category: Int, value: Int) {
        switch kind {
        case "mate_win": return (2, -(abs(value ?? Int.max)))
        case "cp": return (1, value ?? Int.min)
        case "mate_loss": return (0, abs(value ?? Int.max))
        default: return (-1, Int.min)
        }
    }
}

struct VE1BSearchEvidenceDocument: Codable, Sendable {
    let schemaVersion: Int
    let generatedAt: Date
    let status: String
    let policyAuthorityStatus: String
    let stabilityRules: VE1BStabilityRules
    let pvIntervalMs: Int
    let measurementDefinition: String
    let candidateDiscoveryNodes: Int
    let candidateDiscoveryNodeTiers: [Int]
    let confirmationNodeTiers: [Int]
    let safetyCeilingMs: Int
    let positions: [VE1BPositionEvidenceRecord]
    let incompleteAttempts: [VE1BSearchAttemptRecord]
    let error: String?
}

enum VE1BSearchEvidenceExporter {
    static func write(
        status: String,
        policy: VE1BNodeSearchPolicy,
        positions: [VE1BPositionEvidenceRecord],
        incompleteAttempts: [VE1BSearchAttemptRecord],
        error: String?
    ) throws -> URL {
        let document = VE1BSearchEvidenceDocument(
            schemaVersion: 4,
            generatedAt: Date(),
            status: status,
            policyAuthorityStatus: policy.authorityStatus,
            stabilityRules: .ve1bCalibration,
            pvIntervalMs: VE1BEngineEvidenceAuthority.pvIntervalMs,
            measurementDefinition: "deepest_fully_completed_exact_iteration",
            candidateDiscoveryNodes: policy.candidateDiscoveryNodes,
            candidateDiscoveryNodeTiers: policy.candidateDiscoveryNodeTiers,
            confirmationNodeTiers: policy.confirmationNodeTiers,
            safetyCeilingMs: policy.safetyCeilingMs,
            positions: positions,
            incompleteAttempts: incompleteAttempts,
            error: error
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(document)
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = directory.appendingPathComponent("ve1b-search-evidence.json")
        try data.write(to: url, options: .atomic)
        return url
    }
}
