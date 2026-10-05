import Foundation

public enum SequencePlyRole: String, Equatable, Sendable {
    case candidateMove = "CANDIDATE_MOVE"
    case opponentReply = "OPPONENT_REPLY"
    case ownContinuation = "OWN_CONTINUATION"
    case opponentContinuation = "OPPONENT_CONTINUATION"
}

public enum SequenceDifferenceKind: String, Equatable, Sendable {
    case capture = "CAPTURE"
    case promotion = "PROMOTION"
    case check = "CHECK"
    case drop = "DROP"
    case materialOwnership = "MATERIAL_OWNERSHIP"
    case opponentReplyMove = "OPPONENT_REPLY_MOVE"
    case continuationMove = "CONTINUATION_MOVE"
}

public enum OpponentConsequenceKind: String, Equatable, Sendable {
    case capture = "OPPONENT_CAPTURE"
    case check = "OPPONENT_CHECK"
    case promotion = "OPPONENT_PROMOTION"
    case drop = "OPPONENT_DROP"
    case recapture = "OPPONENT_RECAPTURE"
}

public enum TimelineRealityStatus: String, Equatable, Sendable {
    case actual = "ACTUAL"
    case counterfactual = "COUNTERFACTUAL"
    case analysisBranch = "ANALYSIS_BRANCH"
}

public enum FutureDifferenceResolutionStatus: String, Equatable, Sendable {
    case resolved = "RESOLVED"
    case notObservedWithinStableHorizon = "NOT_OBSERVED_WITHIN_STABLE_HORIZON"
    case unresolvedUnstable = "UNRESOLVED_UNSTABLE"
    case reconstructionUnavailable = "RECONSTRUCTION_UNAVAILABLE"
}

public struct SequencePlyMetrics: Equatable, Sendable {
    public let givesCheck: Bool
    public let materialInventory: MaterialInventory

    public init(givesCheck: Bool, materialInventory: MaterialInventory) {
        self.givesCheck = givesCheck
        self.materialInventory = materialInventory
    }
}

public struct SequencePlyEvidence: Equatable, Sendable {
    public let ply: Int
    public let role: SequencePlyRole
    public let move: String
    public let effect: MoveEffect
    public let metrics: SequencePlyMetrics
    public let recapturesPreviousMover: Bool
    public let positionCommandAfter: String
    public let positionAfter: BoardSnapshot
    public let withinStableHorizon: Bool

    public init(
        ply: Int,
        role: SequencePlyRole,
        move: String,
        effect: MoveEffect,
        metrics: SequencePlyMetrics,
        recapturesPreviousMover: Bool,
        positionCommandAfter: String,
        positionAfter: BoardSnapshot,
        withinStableHorizon: Bool
    ) {
        self.ply = ply
        self.role = role
        self.move = move
        self.effect = effect
        self.metrics = metrics
        self.recapturesPreviousMover = recapturesPreviousMover
        self.positionCommandAfter = positionCommandAfter
        self.positionAfter = positionAfter
        self.withinStableHorizon = withinStableHorizon
    }
}

public struct CandidateSequenceEvidence: Equatable, Sendable {
    public let candidateID: String
    public let branchType: CandidateBranchType
    public let requestedPlyCount: Int
    public let reconstructedPlyCount: Int
    public let stablePlyCount: Int
    public let plies: [SequencePlyEvidence]
    public let reconstructionComplete: Bool
    public let warnings: [String]

    public init(
        candidateID: String,
        branchType: CandidateBranchType,
        requestedPlyCount: Int,
        reconstructedPlyCount: Int,
        stablePlyCount: Int,
        plies: [SequencePlyEvidence],
        reconstructionComplete: Bool,
        warnings: [String]
    ) {
        self.candidateID = candidateID
        self.branchType = branchType
        self.requestedPlyCount = requestedPlyCount
        self.reconstructedPlyCount = reconstructedPlyCount
        self.stablePlyCount = stablePlyCount
        self.plies = plies
        self.reconstructionComplete = reconstructionComplete
        self.warnings = warnings
    }
}

public struct SequenceDifferencePoint: Equatable, Sendable {
    public let ply: Int
    public let horizon: ComparisonHorizon
    public let kind: SequenceDifferenceKind
    public let candidateAValue: String
    public let candidateBValue: String
    public let sourceMoves: [String]
    public let withinStableHorizon: Bool
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(
        ply: Int,
        horizon: ComparisonHorizon,
        kind: SequenceDifferenceKind,
        candidateAValue: String,
        candidateBValue: String,
        sourceMoves: [String],
        withinStableHorizon: Bool,
        safeToVerbalize: Bool,
        limitations: [String]
    ) {
        self.ply = ply
        self.horizon = horizon
        self.kind = kind
        self.candidateAValue = candidateAValue
        self.candidateBValue = candidateBValue
        self.sourceMoves = sourceMoves
        self.withinStableHorizon = withinStableHorizon
        self.safeToVerbalize = safeToVerbalize
        self.limitations = limitations
    }
}

public struct ObservedOpponentConsequence: Equatable, Sendable {
    public let candidateID: String
    public let ply: Int
    public let move: String
    public let kind: OpponentConsequenceKind
    public let value: String
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(
        candidateID: String,
        ply: Int,
        move: String,
        kind: OpponentConsequenceKind,
        value: String,
        safeToVerbalize: Bool,
        limitations: [String]
    ) {
        self.candidateID = candidateID
        self.ply = ply
        self.move = move
        self.kind = kind
        self.value = value
        self.safeToVerbalize = safeToVerbalize
        self.limitations = limitations
    }
}

public struct ExchangeConsequenceEvidence: Equatable, Sendable {
    public let horizonPly: Int
    public let candidateAOwnershipDelta: String
    public let candidateBOwnershipDelta: String
    public let candidateAMaterial: String
    public let candidateBMaterial: String
    public let differs: Bool
    public let causalStrength: CausalStrength
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(
        horizonPly: Int,
        candidateAOwnershipDelta: String,
        candidateBOwnershipDelta: String,
        candidateAMaterial: String,
        candidateBMaterial: String,
        differs: Bool,
        causalStrength: CausalStrength,
        safeToVerbalize: Bool,
        limitations: [String]
    ) {
        self.horizonPly = horizonPly
        self.candidateAOwnershipDelta = candidateAOwnershipDelta
        self.candidateBOwnershipDelta = candidateBOwnershipDelta
        self.candidateAMaterial = candidateAMaterial
        self.candidateBMaterial = candidateBMaterial
        self.differs = differs
        self.causalStrength = causalStrength
        self.safeToVerbalize = safeToVerbalize
        self.limitations = limitations
    }
}

public struct FutureDifferenceResolution: Equatable, Sendable {
    public let id: String
    public let reason: FutureDifferenceReason
    public let status: FutureDifferenceResolutionStatus
    public let resolvedAtPly: Int?
    public let sourceMoves: [String]
    public let limitations: [String]

    public init(
        id: String,
        reason: FutureDifferenceReason,
        status: FutureDifferenceResolutionStatus,
        resolvedAtPly: Int?,
        sourceMoves: [String],
        limitations: [String]
    ) {
        self.id = id
        self.reason = reason
        self.status = status
        self.resolvedAtPly = resolvedAtPly
        self.sourceMoves = sourceMoves
        self.limitations = limitations
    }
}

public struct CounterfactualTimelineStep: Equatable, Sendable {
    public let ply: Int
    public let role: SequencePlyRole
    public let move: String
    public let capture: String?
    public let promotes: Bool
    public let givesCheck: Bool
    public let recapturesPreviousMover: Bool
    public let materialSignature: String
    public let withinStableHorizon: Bool

    public init(
        ply: Int,
        role: SequencePlyRole,
        move: String,
        capture: String?,
        promotes: Bool,
        givesCheck: Bool,
        recapturesPreviousMover: Bool,
        materialSignature: String,
        withinStableHorizon: Bool
    ) {
        self.ply = ply
        self.role = role
        self.move = move
        self.capture = capture
        self.promotes = promotes
        self.givesCheck = givesCheck
        self.recapturesPreviousMover = recapturesPreviousMover
        self.materialSignature = materialSignature
        self.withinStableHorizon = withinStableHorizon
    }
}

public struct CounterfactualBranchTimeline: Equatable, Sendable {
    public let candidateID: String
    public let move: String
    public let realityStatus: TimelineRealityStatus
    public let stablePlyCount: Int
    public let steps: [CounterfactualTimelineStep]

    public init(
        candidateID: String,
        move: String,
        realityStatus: TimelineRealityStatus,
        stablePlyCount: Int,
        steps: [CounterfactualTimelineStep]
    ) {
        self.candidateID = candidateID
        self.move = move
        self.realityStatus = realityStatus
        self.stablePlyCount = stablePlyCount
        self.steps = steps
    }
}

public struct SequenceComparisonEvidence: Equatable, Sendable {
    public let comparisonID: String
    public let candidateASequence: CandidateSequenceEvidence
    public let candidateBSequence: CandidateSequenceEvidence
    public let stableHorizonPly: Int
    public let firstGroundedDifference: SequenceDifferencePoint?
    public let sequenceDifferences: [SequenceDifferencePoint]
    public let opponentConsequences: [ObservedOpponentConsequence]
    public let exchangeConsequence: ExchangeConsequenceEvidence?
    public let futureDifferenceResolutions: [FutureDifferenceResolution]
    public let candidateATimeline: CounterfactualBranchTimeline
    public let candidateBTimeline: CounterfactualBranchTimeline
    public let sequenceStable: Bool
    public let warnings: [String]

    public init(
        comparisonID: String,
        candidateASequence: CandidateSequenceEvidence,
        candidateBSequence: CandidateSequenceEvidence,
        stableHorizonPly: Int,
        firstGroundedDifference: SequenceDifferencePoint?,
        sequenceDifferences: [SequenceDifferencePoint],
        opponentConsequences: [ObservedOpponentConsequence],
        exchangeConsequence: ExchangeConsequenceEvidence?,
        futureDifferenceResolutions: [FutureDifferenceResolution],
        candidateATimeline: CounterfactualBranchTimeline,
        candidateBTimeline: CounterfactualBranchTimeline,
        sequenceStable: Bool,
        warnings: [String]
    ) {
        self.comparisonID = comparisonID
        self.candidateASequence = candidateASequence
        self.candidateBSequence = candidateBSequence
        self.stableHorizonPly = stableHorizonPly
        self.firstGroundedDifference = firstGroundedDifference
        self.sequenceDifferences = sequenceDifferences
        self.opponentConsequences = opponentConsequences
        self.exchangeConsequence = exchangeConsequence
        self.futureDifferenceResolutions = futureDifferenceResolutions
        self.candidateATimeline = candidateATimeline
        self.candidateBTimeline = candidateBTimeline
        self.sequenceStable = sequenceStable
        self.warnings = warnings
    }
}

public enum SequenceCounterfactualEvidenceResolver {
    public static func resolve(
        comparison: CandidateComparison,
        maxPlies: Int = 5
    ) -> SequenceComparisonEvidence {
        let cappedMax = max(1, maxPlies)
        let a = reconstruct(candidate: comparison.candidateA, comparisonStable: comparison.comparisonStable, maxPlies: cappedMax)
        let b = reconstruct(candidate: comparison.candidateB, comparisonStable: comparison.comparisonStable, maxPlies: cappedMax)
        let stableHorizon = min(a.stablePlyCount, b.stablePlyCount)
        let differences = makeDifferences(
            candidateA: a,
            candidateB: b,
            comparisonStable: comparison.comparisonStable,
            stableHorizon: stableHorizon
        )
        let consequences = observedOpponentConsequences(sequence: a, comparisonStable: comparison.comparisonStable)
            + observedOpponentConsequences(sequence: b, comparisonStable: comparison.comparisonStable)
        let exchange = makeExchangeConsequence(
            comparison: comparison,
            candidateA: a,
            candidateB: b,
            stableHorizon: stableHorizon
        )
        let future = comparison.futureDifferenceCandidates.map {
            resolveFutureCandidate(
                $0,
                candidateA: a,
                candidateB: b,
                differences: differences,
                consequences: consequences,
                stableHorizon: stableHorizon
            )
        }
        var warnings = comparison.comparisonWarnings + a.warnings + b.warnings
        if stableHorizon < min(a.reconstructedPlyCount, b.reconstructedPlyCount) {
            warnings.append("sequence_reconstructed_beyond_stable_horizon")
        }
        if stableHorizon < 2 {
            warnings.append("opponent_reply_not_within_stable_horizon")
        }
        warnings = Array(Set(warnings)).sorted()

        return SequenceComparisonEvidence(
            comparisonID: comparison.comparisonID,
            candidateASequence: a,
            candidateBSequence: b,
            stableHorizonPly: stableHorizon,
            firstGroundedDifference: differences.first,
            sequenceDifferences: differences,
            opponentConsequences: consequences,
            exchangeConsequence: exchange,
            futureDifferenceResolutions: future,
            candidateATimeline: timeline(candidate: comparison.candidateA, sequence: a, comparison: comparison),
            candidateBTimeline: timeline(candidate: comparison.candidateB, sequence: b, comparison: comparison),
            sequenceStable: comparison.comparisonStable && comparison.continuationStable && stableHorizon >= min(2, cappedMax),
            warnings: warnings
        )
    }

    private static func reconstruct(
        candidate: CandidateAnalysis,
        comparisonStable: Bool,
        maxPlies: Int
    ) -> CandidateSequenceEvidence {
        let requestedMoves = Array(candidate.pv.prefix(maxPlies))
        guard requestedMoves.first == candidate.move else {
            return CandidateSequenceEvidence(
                candidateID: candidate.candidateID,
                branchType: candidate.branchType,
                requestedPlyCount: requestedMoves.count,
                reconstructedPlyCount: 0,
                stablePlyCount: 0,
                plies: [],
                reconstructionComplete: false,
                warnings: ["pv_first_move_mismatch_sequence_not_reconstructed"]
            )
        }

        var command = candidate.positionCommand
        var plies: [SequencePlyEvidence] = []
        var warnings: [String] = []
        var previousEffect: MoveEffect?

        for (offset, move) in requestedMoves.enumerated() {
            let ply = offset + 1
            do {
                let effect = try MoveEffectResolver.resolve(positionCommand: command, move: move)
                let nextCommand = try MoveEffectResolver.appending(move: move, to: command)
                let snapshot = try BoardSnapshotResolver.resolve(positionCommand: nextCommand)
                let checkedSide = effect.side == .black ? ShogiSide.white : .black
                let givesCheck = BoardTacticalMetricResolver.isKingInCheck(snapshot: snapshot, checkedSide: checkedSide)
                let recapture: Bool
                if let previousEffect {
                    recapture = effect.destination == previousEffect.destination
                        && effect.capturedPiece == previousEffect.pieceAfter
                } else {
                    recapture = false
                }
                let provisionalStablePly = stablePlyCount(
                    candidate: candidate,
                    comparisonStable: comparisonStable,
                    reconstructedCount: requestedMoves.count
                )
                plies.append(
                    SequencePlyEvidence(
                        ply: ply,
                        role: role(for: ply),
                        move: move,
                        effect: effect,
                        metrics: SequencePlyMetrics(
                            givesCheck: givesCheck,
                            materialInventory: MaterialInventory.resolve(snapshot: snapshot)
                        ),
                        recapturesPreviousMover: recapture,
                        positionCommandAfter: nextCommand,
                        positionAfter: snapshot,
                        withinStableHorizon: ply <= provisionalStablePly
                    )
                )
                command = nextCommand
                previousEffect = effect
            } catch {
                warnings.append("sequence_reconstruction_failed_at_ply_\(ply):\(move)")
                break
            }
        }

        let stableCount = stablePlyCount(
            candidate: candidate,
            comparisonStable: comparisonStable,
            reconstructedCount: plies.count
        )
        if !candidate.continuationStable && plies.count > 1 {
            warnings.append("continuation_unstable_only_first_move_is_stable")
        }
        let correctedPlies = plies.map { value in
            SequencePlyEvidence(
                ply: value.ply,
                role: value.role,
                move: value.move,
                effect: value.effect,
                metrics: value.metrics,
                recapturesPreviousMover: value.recapturesPreviousMover,
                positionCommandAfter: value.positionCommandAfter,
                positionAfter: value.positionAfter,
                withinStableHorizon: value.ply <= stableCount
            )
        }
        return CandidateSequenceEvidence(
            candidateID: candidate.candidateID,
            branchType: candidate.branchType,
            requestedPlyCount: requestedMoves.count,
            reconstructedPlyCount: correctedPlies.count,
            stablePlyCount: stableCount,
            plies: correctedPlies,
            reconstructionComplete: correctedPlies.count == requestedMoves.count,
            warnings: warnings
        )
    }

    private static func stablePlyCount(
        candidate: CandidateAnalysis,
        comparisonStable: Bool,
        reconstructedCount: Int
    ) -> Int {
        guard comparisonStable && candidate.comparisonStable else { return 0 }
        if candidate.continuationStable {
            return reconstructedCount
        }
        return min(1, reconstructedCount)
    }

    private static func role(for ply: Int) -> SequencePlyRole {
        if ply == 1 { return .candidateMove }
        if ply == 2 { return .opponentReply }
        return ply.isMultiple(of: 2) ? .opponentContinuation : .ownContinuation
    }

    private static func makeDifferences(
        candidateA: CandidateSequenceEvidence,
        candidateB: CandidateSequenceEvidence,
        comparisonStable: Bool,
        stableHorizon: Int
    ) -> [SequenceDifferencePoint] {
        let count = min(candidateA.plies.count, candidateB.plies.count)
        var result: [SequenceDifferencePoint] = []

        for index in 0..<count {
            let a = candidateA.plies[index]
            let b = candidateB.plies[index]
            let ply = index + 1
            let stable = comparisonStable && ply <= stableHorizon
            let horizon = horizon(for: ply)
            let moves = [a.move, b.move]

            if a.effect.capturedPiece != b.effect.capturedPiece {
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: .capture,
                    a: a.effect.capturedPiece?.rawValue ?? "none",
                    b: b.effect.capturedPiece?.rawValue ?? "none",
                    moves: moves,
                    stable: stable,
                    limitation: "observed_sequence_capture_difference_not_full_engine_reason"
                ))
            }
            if a.effect.promotes != b.effect.promotes {
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: .promotion,
                    a: String(a.effect.promotes),
                    b: String(b.effect.promotes),
                    moves: moves,
                    stable: stable,
                    limitation: "observed_sequence_promotion_difference_not_full_engine_reason"
                ))
            }
            if a.metrics.givesCheck != b.metrics.givesCheck {
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: .check,
                    a: String(a.metrics.givesCheck),
                    b: String(b.metrics.givesCheck),
                    moves: moves,
                    stable: stable,
                    limitation: "observed_sequence_check_difference_not_full_engine_reason"
                ))
            }
            if a.effect.isDrop != b.effect.isDrop {
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: .drop,
                    a: String(a.effect.isDrop),
                    b: String(b.effect.isDrop),
                    moves: moves,
                    stable: stable,
                    limitation: "observed_drop_difference_not_strategic_activity_claim"
                ))
            }
            if a.metrics.materialInventory != b.metrics.materialInventory {
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: .materialOwnership,
                    a: a.metrics.materialInventory.signature(),
                    b: b.metrics.materialInventory.signature(),
                    moves: moves,
                    stable: stable,
                    limitation: "ownership_inventory_difference_not_weighted_material_evaluation"
                ))
            }

            if ply >= 2 && a.move != b.move {
                let kind: SequenceDifferenceKind = ply == 2 ? .opponentReplyMove : .continuationMove
                result.append(point(
                    ply: ply,
                    horizon: horizon,
                    kind: kind,
                    a: a.move,
                    b: b.move,
                    moves: moves,
                    stable: stable,
                    limitation: ply == 2
                        ? "pv_reply_difference_does_not_prove_reply_is_forced"
                        : "pv_continuation_difference_is_observed_line_not_complete_future_tree"
                ))
            }
        }

        return result.sorted {
            if $0.ply != $1.ply { return $0.ply < $1.ply }
            return differencePriority($0.kind) > differencePriority($1.kind)
        }
    }

    private static func point(
        ply: Int,
        horizon: ComparisonHorizon,
        kind: SequenceDifferenceKind,
        a: String,
        b: String,
        moves: [String],
        stable: Bool,
        limitation: String
    ) -> SequenceDifferencePoint {
        SequenceDifferencePoint(
            ply: ply,
            horizon: horizon,
            kind: kind,
            candidateAValue: a,
            candidateBValue: b,
            sourceMoves: moves,
            withinStableHorizon: stable,
            safeToVerbalize: stable,
            limitations: [limitation]
        )
    }

    private static func differencePriority(_ kind: SequenceDifferenceKind) -> Int {
        switch kind {
        case .capture: return 100
        case .materialOwnership: return 90
        case .check: return 80
        case .promotion: return 70
        case .opponentReplyMove: return 60
        case .drop: return 50
        case .continuationMove: return 40
        }
    }

    private static func horizon(for ply: Int) -> ComparisonHorizon {
        if ply == 1 { return .immediate }
        if ply == 2 { return .opponentReply }
        if ply == 3 { return .ownContinuation }
        return .shortHorizon
    }

    private static func observedOpponentConsequences(
        sequence: CandidateSequenceEvidence,
        comparisonStable: Bool
    ) -> [ObservedOpponentConsequence] {
        var result: [ObservedOpponentConsequence] = []
        for ply in sequence.plies where ply.role == .opponentReply || ply.role == .opponentContinuation {
            let safe = comparisonStable && ply.withinStableHorizon
            let commonLimit = "observed_in_engine_pv_not_exhaustive_and_not_proven_forced"
            if let captured = ply.effect.capturedPiece {
                result.append(.init(
                    candidateID: sequence.candidateID,
                    ply: ply.ply,
                    move: ply.move,
                    kind: .capture,
                    value: captured.rawValue,
                    safeToVerbalize: safe,
                    limitations: [commonLimit]
                ))
            }
            if ply.metrics.givesCheck {
                result.append(.init(
                    candidateID: sequence.candidateID,
                    ply: ply.ply,
                    move: ply.move,
                    kind: .check,
                    value: "true",
                    safeToVerbalize: safe,
                    limitations: [commonLimit]
                ))
            }
            if ply.effect.promotes {
                result.append(.init(
                    candidateID: sequence.candidateID,
                    ply: ply.ply,
                    move: ply.move,
                    kind: .promotion,
                    value: ply.effect.pieceAfter.rawValue,
                    safeToVerbalize: safe,
                    limitations: [commonLimit]
                ))
            }
            if ply.effect.isDrop {
                result.append(.init(
                    candidateID: sequence.candidateID,
                    ply: ply.ply,
                    move: ply.move,
                    kind: .drop,
                    value: ply.effect.pieceAfter.rawValue,
                    safeToVerbalize: safe,
                    limitations: [commonLimit]
                ))
            }
            if ply.recapturesPreviousMover {
                result.append(.init(
                    candidateID: sequence.candidateID,
                    ply: ply.ply,
                    move: ply.move,
                    kind: .recapture,
                    value: ply.effect.capturedPiece?.rawValue ?? "unknown",
                    safeToVerbalize: safe,
                    limitations: [commonLimit, "recapture_is_local_sequence_fact_not_complete_exchange_evaluation"]
                ))
            }
        }
        return result
    }

    private static func makeExchangeConsequence(
        comparison: CandidateComparison,
        candidateA: CandidateSequenceEvidence,
        candidateB: CandidateSequenceEvidence,
        stableHorizon: Int
    ) -> ExchangeConsequenceEvidence? {
        guard stableHorizon > 0,
              let aEnd = candidateA.plies.first(where: { $0.ply == stableHorizon }),
              let bEnd = candidateB.plies.first(where: { $0.ply == stableHorizon }) else {
            return nil
        }
        let start = MaterialInventory.resolve(snapshot: comparison.candidateA.positionBefore)
        let aDelta = ownershipDeltaSignature(from: start, to: aEnd.metrics.materialInventory)
        let bDelta = ownershipDeltaSignature(from: start, to: bEnd.metrics.materialInventory)
        let changed = aDelta != "no_change" || bDelta != "no_change"
        guard changed || aEnd.metrics.materialInventory != bEnd.metrics.materialInventory else { return nil }

        let strength: CausalStrength = stableHorizon == 2 ? .replyLinked : .sequenceCorrelated
        return ExchangeConsequenceEvidence(
            horizonPly: stableHorizon,
            candidateAOwnershipDelta: aDelta,
            candidateBOwnershipDelta: bDelta,
            candidateAMaterial: aEnd.metrics.materialInventory.signature(),
            candidateBMaterial: bEnd.metrics.materialInventory.signature(),
            differs: aEnd.metrics.materialInventory != bEnd.metrics.materialInventory,
            causalStrength: strength,
            safeToVerbalize: comparison.comparisonStable && stableHorizon > 0,
            limitations: [
                "material_ownership_delta_is_grounded_sequence_fact",
                "does_not_claim_complete_engine_evaluation_reason",
                "stable_horizon_only"
            ]
        )
    }

    private static func ownershipDeltaSignature(
        from start: MaterialInventory,
        to end: MaterialInventory
    ) -> String {
        let order: [BoardPieceKind] = [.pawn, .lance, .knight, .silver, .gold, .bishop, .rook, .king]
        var parts: [String] = []
        for kind in order {
            let blackDelta = end.black[kind, default: 0] - start.black[kind, default: 0]
            let whiteDelta = end.white[kind, default: 0] - start.white[kind, default: 0]
            if blackDelta != 0 || whiteDelta != 0 {
                parts.append("\(kind.rawValue):B\(signed(blackDelta)),W\(signed(whiteDelta))")
            }
        }
        return parts.isEmpty ? "no_change" : parts.joined(separator: ",")
    }

    private static func signed(_ value: Int) -> String {
        value >= 0 ? "+\(value)" : String(value)
    }

    private static func resolveFutureCandidate(
        _ candidate: FutureDifferenceCandidate,
        candidateA: CandidateSequenceEvidence,
        candidateB: CandidateSequenceEvidence,
        differences: [SequenceDifferencePoint],
        consequences: [ObservedOpponentConsequence],
        stableHorizon: Int
    ) -> FutureDifferenceResolution {
        if candidateA.reconstructedPlyCount == 0 || candidateB.reconstructedPlyCount == 0 {
            return .init(
                id: candidate.id,
                reason: candidate.reason,
                status: .reconstructionUnavailable,
                resolvedAtPly: nil,
                sourceMoves: candidate.sourceMoves,
                limitations: ["sequence_reconstruction_unavailable"]
            )
        }

        switch candidate.reason {
        case .immediateRecaptureDetected:
            if let event = consequences.first(where: { $0.kind == .recapture }) {
                return .init(
                    id: candidate.id,
                    reason: candidate.reason,
                    status: event.ply <= stableHorizon ? .resolved : .unresolvedUnstable,
                    resolvedAtPly: event.ply,
                    sourceMoves: candidate.sourceMoves,
                    limitations: ["recapture_observed_in_pv_not_complete_exchange_tree"]
                )
            }
        case .opponentReplyEventsDiffer:
            if let point = differences.first(where: { $0.ply == 2 }) {
                return .init(
                    id: candidate.id,
                    reason: candidate.reason,
                    status: point.withinStableHorizon ? .resolved : .unresolvedUnstable,
                    resolvedAtPly: point.ply,
                    sourceMoves: candidate.sourceMoves,
                    limitations: point.limitations
                )
            }
        case .continuationDiffers:
            if let point = differences.first(where: { $0.ply >= 2 }) {
                return .init(
                    id: candidate.id,
                    reason: candidate.reason,
                    status: point.withinStableHorizon ? .resolved : .unresolvedUnstable,
                    resolvedAtPly: point.ply,
                    sourceMoves: candidate.sourceMoves,
                    limitations: point.limitations
                )
            }
        case .continuationUnstable:
            return .init(
                id: candidate.id,
                reason: candidate.reason,
                status: .unresolvedUnstable,
                resolvedAtPly: nil,
                sourceMoves: candidate.sourceMoves,
                limitations: ["continuation_stability_required_before_future_claim"]
            )
        }

        return .init(
            id: candidate.id,
            reason: candidate.reason,
            status: stableHorizon > 0 ? .notObservedWithinStableHorizon : .unresolvedUnstable,
            resolvedAtPly: nil,
            sourceMoves: candidate.sourceMoves,
            limitations: ["future_difference_not_grounded_within_current_stable_horizon"]
        )
    }

    private static func timeline(
        candidate: CandidateAnalysis,
        sequence: CandidateSequenceEvidence,
        comparison: CandidateComparison
    ) -> CounterfactualBranchTimeline {
        let status: TimelineRealityStatus
        if candidate.branchType == .actual {
            status = .actual
        } else if let actual = comparison.actualMove, actual != candidate.move {
            status = .counterfactual
        } else {
            status = .analysisBranch
        }
        return CounterfactualBranchTimeline(
            candidateID: candidate.candidateID,
            move: candidate.move,
            realityStatus: status,
            stablePlyCount: sequence.stablePlyCount,
            steps: sequence.plies.map {
                CounterfactualTimelineStep(
                    ply: $0.ply,
                    role: $0.role,
                    move: $0.move,
                    capture: $0.effect.capturedPiece?.rawValue,
                    promotes: $0.effect.promotes,
                    givesCheck: $0.metrics.givesCheck,
                    recapturesPreviousMover: $0.recapturesPreviousMover,
                    materialSignature: $0.metrics.materialInventory.signature(),
                    withinStableHorizon: $0.withinStableHorizon
                )
            }
        )
    }
}

public struct SequenceComparisonDiagnostic: Codable, Equatable, Sendable {
    public struct Ply: Codable, Equatable, Sendable {
        public let ply: Int
        public let role: String
        public let move: String
        public let capture: String?
        public let promotes: Bool
        public let givesCheck: Bool
        public let recapturesPreviousMover: Bool
        public let material: String
        public let stable: Bool
    }

    public struct Branch: Codable, Equatable, Sendable {
        public let candidateID: String
        public let realityStatus: String
        public let reconstructedPlyCount: Int
        public let stablePlyCount: Int
        public let reconstructionComplete: Bool
        public let plies: [Ply]
        public let warnings: [String]
    }

    public struct Difference: Codable, Equatable, Sendable {
        public let ply: Int
        public let horizon: String
        public let kind: String
        public let candidateAValue: String
        public let candidateBValue: String
        public let safeToVerbalize: Bool
        public let limitations: [String]
    }

    public struct OpponentConsequence: Codable, Equatable, Sendable {
        public let candidateID: String
        public let ply: Int
        public let move: String
        public let kind: String
        public let value: String
        public let safeToVerbalize: Bool
        public let limitations: [String]
    }

    public struct FutureResolution: Codable, Equatable, Sendable {
        public let id: String
        public let reason: String
        public let status: String
        public let resolvedAtPly: Int?
        public let limitations: [String]
    }

    public let comparisonID: String
    public let stableHorizonPly: Int
    public let sequenceStable: Bool
    public let candidateA: Branch
    public let candidateB: Branch
    public let firstGroundedDifference: Difference?
    public let differences: [Difference]
    public let opponentConsequences: [OpponentConsequence]
    public let exchangeHorizonPly: Int?
    public let exchangeCandidateADelta: String?
    public let exchangeCandidateBDelta: String?
    public let futureResolutions: [FutureResolution]
    public let warnings: [String]

    public init(_ evidence: SequenceComparisonEvidence) {
        func diagnosticBranch(
            _ sequence: CandidateSequenceEvidence,
            timeline: CounterfactualBranchTimeline
        ) -> Branch {
            Branch(
                candidateID: sequence.candidateID,
                realityStatus: timeline.realityStatus.rawValue,
                reconstructedPlyCount: sequence.reconstructedPlyCount,
                stablePlyCount: sequence.stablePlyCount,
                reconstructionComplete: sequence.reconstructionComplete,
                plies: sequence.plies.map {
                    Ply(
                        ply: $0.ply,
                        role: $0.role.rawValue,
                        move: $0.move,
                        capture: $0.effect.capturedPiece?.rawValue,
                        promotes: $0.effect.promotes,
                        givesCheck: $0.metrics.givesCheck,
                        recapturesPreviousMover: $0.recapturesPreviousMover,
                        material: $0.metrics.materialInventory.signature(),
                        stable: $0.withinStableHorizon
                    )
                },
                warnings: sequence.warnings
            )
        }
        func diagnosticDifference(_ value: SequenceDifferencePoint) -> Difference {
            Difference(
                ply: value.ply,
                horizon: value.horizon.rawValue,
                kind: value.kind.rawValue,
                candidateAValue: value.candidateAValue,
                candidateBValue: value.candidateBValue,
                safeToVerbalize: value.safeToVerbalize,
                limitations: value.limitations
            )
        }

        self.comparisonID = evidence.comparisonID
        self.stableHorizonPly = evidence.stableHorizonPly
        self.sequenceStable = evidence.sequenceStable
        self.candidateA = diagnosticBranch(evidence.candidateASequence, timeline: evidence.candidateATimeline)
        self.candidateB = diagnosticBranch(evidence.candidateBSequence, timeline: evidence.candidateBTimeline)
        self.firstGroundedDifference = evidence.firstGroundedDifference.map(diagnosticDifference)
        self.differences = evidence.sequenceDifferences.map(diagnosticDifference)
        self.opponentConsequences = evidence.opponentConsequences.map {
            OpponentConsequence(
                candidateID: $0.candidateID,
                ply: $0.ply,
                move: $0.move,
                kind: $0.kind.rawValue,
                value: $0.value,
                safeToVerbalize: $0.safeToVerbalize,
                limitations: $0.limitations
            )
        }
        self.exchangeHorizonPly = evidence.exchangeConsequence?.horizonPly
        self.exchangeCandidateADelta = evidence.exchangeConsequence?.candidateAOwnershipDelta
        self.exchangeCandidateBDelta = evidence.exchangeConsequence?.candidateBOwnershipDelta
        self.futureResolutions = evidence.futureDifferenceResolutions.map {
            FutureResolution(
                id: $0.id,
                reason: $0.reason.rawValue,
                status: $0.status.rawValue,
                resolvedAtPly: $0.resolvedAtPly,
                limitations: $0.limitations
            )
        }
        self.warnings = evidence.warnings
    }
}
