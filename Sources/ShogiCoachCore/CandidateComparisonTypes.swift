import Foundation

public enum CandidateBranchType: String, Equatable, Sendable {
    case recommended
    case actual
    case alternative
    case rankedCandidate
}

public enum ComparisonScoreKind: String, Equatable, Sendable {
    case centipawn
    case mateWin
    case mateLoss
}

public struct CandidateScore: Equatable, Sendable {
    public let kind: ComparisonScoreKind
    public let centipawn: Int?
    public let mateDistance: Int?
    public let bound: USIScore.Bound?

    public init(_ score: USIScore) {
        switch score {
        case .centipawn(let value, let bound):
            self.kind = .centipawn
            self.centipawn = value
            self.mateDistance = nil
            self.bound = bound
        case .mate(let value, let bound):
            self.kind = value >= 0 ? .mateWin : .mateLoss
            self.centipawn = nil
            self.mateDistance = value
            self.bound = bound
        }
    }

    public var text: String {
        switch kind {
        case .centipawn:
            return centipawn.map { "cp \($0)" } ?? "cp ?"
        case .mateWin, .mateLoss:
            return mateDistance.map { "mate \($0)" } ?? "mate ?"
        }
    }
}

public struct EngineComparisonContext: Equatable, Sendable {
    public let engineContextID: String
    public let searchConditionID: String
    public let scorePerspective: String
    public let requestedMoveTimeMs: Int?
    public let requestedDepth: Int?

    public init(
        engineContextID: String,
        searchConditionID: String,
        scorePerspective: String = "side_to_move",
        requestedMoveTimeMs: Int? = nil,
        requestedDepth: Int? = nil
    ) {
        self.engineContextID = engineContextID
        self.searchConditionID = searchConditionID
        self.scorePerspective = scorePerspective
        self.requestedMoveTimeMs = requestedMoveTimeMs
        self.requestedDepth = requestedDepth
    }
}

public struct CandidateSourceEvidence: Equatable, Sendable {
    public let id: String
    public let kind: String
    public let sourceMoves: [String]

    public init(id: String, kind: String, sourceMoves: [String]) {
        self.id = id
        self.kind = kind
        self.sourceMoves = sourceMoves
    }
}

public struct MaterialInventory: Equatable, Sendable {
    public let black: [BoardPieceKind: Int]
    public let white: [BoardPieceKind: Int]

    public init(black: [BoardPieceKind: Int], white: [BoardPieceKind: Int]) {
        self.black = black
        self.white = white
    }

    public static func resolve(snapshot: BoardSnapshot) -> MaterialInventory {
        var black: [BoardPieceKind: Int] = [:]
        var white: [BoardPieceKind: Int] = [:]

        for piece in snapshot.squares.values {
            let base = piece.kind.base
            if piece.side == .black {
                black[base, default: 0] += 1
            } else {
                white[base, default: 0] += 1
            }
        }
        for (kind, count) in snapshot.hands[.black] ?? [:] {
            black[kind.base, default: 0] += count
        }
        for (kind, count) in snapshot.hands[.white] ?? [:] {
            white[kind.base, default: 0] += count
        }
        return MaterialInventory(black: black, white: white)
    }

    public func signature() -> String {
        let order: [BoardPieceKind] = [.pawn, .lance, .knight, .silver, .gold, .bishop, .rook, .king]
        func sideText(_ inventory: [BoardPieceKind: Int]) -> String {
            order.map { "\($0.rawValue)=\(inventory[$0, default: 0])" }.joined(separator: ",")
        }
        return "B[\(sideText(black))]|W[\(sideText(white))]"
    }
}

public struct CandidateBoardMetrics: Equatable, Sendable {
    public let givesCheck: Bool
    public let materialInventory: MaterialInventory
    public let moverKingZonePressure: Int
    public let moverKingZoneDefenders: Int
    public let opponentKingZonePressure: Int

    public init(
        givesCheck: Bool,
        materialInventory: MaterialInventory,
        moverKingZonePressure: Int,
        moverKingZoneDefenders: Int,
        opponentKingZonePressure: Int
    ) {
        self.givesCheck = givesCheck
        self.materialInventory = materialInventory
        self.moverKingZonePressure = moverKingZonePressure
        self.moverKingZoneDefenders = moverKingZoneDefenders
        self.opponentKingZonePressure = opponentKingZonePressure
    }
}

public struct CandidateReplyPreview: Equatable, Sendable {
    public let move: String
    public let effect: MoveEffect
    public let givesCheck: Bool
    public let recapturesFirstMover: Bool

    public init(move: String, effect: MoveEffect, givesCheck: Bool, recapturesFirstMover: Bool) {
        self.move = move
        self.effect = effect
        self.givesCheck = givesCheck
        self.recapturesFirstMover = recapturesFirstMover
    }
}

public struct CandidateAnalysis: Equatable, Sendable {
    public let candidateID: String
    public let rank: Int
    public let move: String
    public let engineScore: CandidateScore
    public let scoreKind: ComparisonScoreKind
    public let pv: [String]
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let firstMoveEffect: MoveEffect
    public let positionCommand: String
    public let positionBefore: BoardSnapshot
    public let positionAfter: BoardSnapshot
    public let sourceEvidence: [CandidateSourceEvidence]
    public let analysisWarnings: [String]
    public let engineContext: EngineComparisonContext
    public let branchType: CandidateBranchType
    public let boardMetrics: CandidateBoardMetrics
    public let opponentReplyPreview: CandidateReplyPreview?

    public init(
        candidateID: String,
        rank: Int,
        move: String,
        engineScore: CandidateScore,
        pv: [String],
        comparisonStable: Bool,
        continuationStable: Bool,
        firstMoveEffect: MoveEffect,
        positionCommand: String,
        positionBefore: BoardSnapshot,
        positionAfter: BoardSnapshot,
        sourceEvidence: [CandidateSourceEvidence],
        analysisWarnings: [String],
        engineContext: EngineComparisonContext,
        branchType: CandidateBranchType,
        boardMetrics: CandidateBoardMetrics,
        opponentReplyPreview: CandidateReplyPreview?
    ) {
        self.candidateID = candidateID
        self.rank = rank
        self.move = move
        self.engineScore = engineScore
        self.scoreKind = engineScore.kind
        self.pv = pv
        self.comparisonStable = comparisonStable
        self.continuationStable = continuationStable
        self.firstMoveEffect = firstMoveEffect
        self.positionCommand = positionCommand
        self.positionBefore = positionBefore
        self.positionAfter = positionAfter
        self.sourceEvidence = sourceEvidence
        self.analysisWarnings = analysisWarnings
        self.engineContext = engineContext
        self.branchType = branchType
        self.boardMetrics = boardMetrics
        self.opponentReplyPreview = opponentReplyPreview
    }
}

public enum ComparisonHorizon: String, Equatable, Sendable {
    case immediate = "IMMEDIATE"
    case opponentReply = "OPPONENT_REPLY"
    case ownContinuation = "OWN_CONTINUATION"
    case shortHorizon = "SHORT_HORIZON"
}

public enum DifferenceKind: String, Equatable, Sendable {
    case scoreDifference = "SCORE_DIFFERENCE"
    case captureDifference = "CAPTURE_DIFFERENCE"
    case materialDifference = "MATERIAL_DIFFERENCE"
    case promotionDifference = "PROMOTION_DIFFERENCE"
    case checkDifference = "CHECK_DIFFERENCE"
    case mateStateDifference = "MATE_STATE_DIFFERENCE"
    case kingSafetyDifference = "KING_SAFETY_DIFFERENCE"
    case exchangeConsequenceDifference = "EXCHANGE_CONSEQUENCE_DIFFERENCE"
    case opponentReplyDifference = "OPPONENT_REPLY_DIFFERENCE"
    case boardEffectDifference = "BOARD_EFFECT_DIFFERENCE"
    case sequenceEventDifference = "SEQUENCE_EVENT_DIFFERENCE"
    case noGroundedCausalDifference = "NO_GROUNDED_CAUSAL_DIFFERENCE"
}

public enum CausalStrength: String, Equatable, Sendable {
    case directConsequence = "DIRECT_CONSEQUENCE"
    case replyLinked = "REPLY_LINKED"
    case sequenceCorrelated = "SEQUENCE_CORRELATED"
    case unresolved = "UNRESOLVED"
}

public struct SharedEvidence: Equatable, Sendable {
    public let id: String
    public let kind: String
    public let value: String
    public let sourceEvidenceIDs: [String]
    public let sourceMoves: [String]

    public init(id: String, kind: String, value: String, sourceEvidenceIDs: [String], sourceMoves: [String]) {
        self.id = id
        self.kind = kind
        self.value = value
        self.sourceEvidenceIDs = sourceEvidenceIDs
        self.sourceMoves = sourceMoves
    }
}

public struct DifferenceEvidence: Equatable, Sendable {
    public let id: String
    public let kind: DifferenceKind
    public let candidateAValue: String
    public let candidateBValue: String
    public let sourceEvidenceIDs: [String]
    public let sourceMoves: [String]
    public let horizon: ComparisonHorizon
    public let causalStrength: CausalStrength
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(
        id: String,
        kind: DifferenceKind,
        candidateAValue: String,
        candidateBValue: String,
        sourceEvidenceIDs: [String],
        sourceMoves: [String],
        horizon: ComparisonHorizon,
        causalStrength: CausalStrength,
        safeToVerbalize: Bool,
        limitations: [String]
    ) {
        self.id = id
        self.kind = kind
        self.candidateAValue = candidateAValue
        self.candidateBValue = candidateBValue
        self.sourceEvidenceIDs = sourceEvidenceIDs
        self.sourceMoves = sourceMoves
        self.horizon = horizon
        self.causalStrength = causalStrength
        self.safeToVerbalize = safeToVerbalize
        self.limitations = limitations
    }
}

public enum FutureDifferenceReason: String, Equatable, Sendable {
    case immediateRecaptureDetected = "IMMEDIATE_RECAPTURE_DETECTED"
    case opponentReplyEventsDiffer = "OPPONENT_REPLY_EVENTS_DIFFER"
    case continuationDiffers = "CONTINUATION_DIFFERS"
    case continuationUnstable = "CONTINUATION_UNSTABLE"
}

public struct FutureDifferenceCandidate: Equatable, Sendable {
    public let id: String
    public let horizon: ComparisonHorizon
    public let reason: FutureDifferenceReason
    public let sourceMoves: [String]
    public let requiresStableSequence: Bool

    public init(
        id: String,
        horizon: ComparisonHorizon,
        reason: FutureDifferenceReason,
        sourceMoves: [String],
        requiresStableSequence: Bool = true
    ) {
        self.id = id
        self.horizon = horizon
        self.reason = reason
        self.sourceMoves = sourceMoves
        self.requiresStableSequence = requiresStableSequence
    }
}

public enum ComparisonAxis: String, CaseIterable, Hashable, Sendable {
    case evaluation
    case capture
    case material
    case promotion
    case check
    case mateState
    case kingSafety
    case exchangeConsequence
    case opponentReply
    case boardEffect
    case sequenceEvent
    case initiative
    case tempo
    case boardActivity
    case pieceActivity
    case futureAttack
    case futureDefenseBurden
    case continuationQuality
    case moveFlexibility
    case risk
    case practicalComplexity
    case humanEase
}

public enum CandidatePairKind: String, Equatable, Sendable {
    case top1VsTop2 = "TOP1_VS_TOP2"
    case bestVsActual = "BEST_VS_ACTUAL"
    case custom = "CUSTOM"
}

public struct CandidateComparison: Equatable, Sendable {
    public let comparisonID: String
    public let pairKind: CandidatePairKind
    public let candidateA: CandidateAnalysis
    public let candidateB: CandidateAnalysis
    public let actualMove: String?
    public let recommendedMove: String?
    public let alternativeCandidate: String?
    public let sharedEvidence: [SharedEvidence]
    public let differenceEvidence: [DifferenceEvidence]
    public let immediateDifferences: [DifferenceEvidence]
    public let futureDifferenceCandidates: [FutureDifferenceCandidate]
    public let dominantDifferenceCandidate: DifferenceEvidence?
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let requiresSequenceEvidence: Bool
    public let unsupportedClaims: [String]
    public let comparisonWarnings: [String]

    public var directDifferenceCount: Int {
        differenceEvidence.filter { $0.causalStrength == .directConsequence }.count
    }

    public init(
        comparisonID: String,
        pairKind: CandidatePairKind,
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        actualMove: String?,
        recommendedMove: String?,
        alternativeCandidate: String?,
        sharedEvidence: [SharedEvidence],
        differenceEvidence: [DifferenceEvidence],
        immediateDifferences: [DifferenceEvidence],
        futureDifferenceCandidates: [FutureDifferenceCandidate],
        dominantDifferenceCandidate: DifferenceEvidence?,
        comparisonStable: Bool,
        continuationStable: Bool,
        requiresSequenceEvidence: Bool,
        unsupportedClaims: [String],
        comparisonWarnings: [String]
    ) {
        self.comparisonID = comparisonID
        self.pairKind = pairKind
        self.candidateA = candidateA
        self.candidateB = candidateB
        self.actualMove = actualMove
        self.recommendedMove = recommendedMove
        self.alternativeCandidate = alternativeCandidate
        self.sharedEvidence = sharedEvidence
        self.differenceEvidence = differenceEvidence
        self.immediateDifferences = immediateDifferences
        self.futureDifferenceCandidates = futureDifferenceCandidates
        self.dominantDifferenceCandidate = dominantDifferenceCandidate
        self.comparisonStable = comparisonStable
        self.continuationStable = continuationStable
        self.requiresSequenceEvidence = requiresSequenceEvidence
        self.unsupportedClaims = unsupportedClaims
        self.comparisonWarnings = comparisonWarnings
    }
}

public struct ComparisonConfidenceSignals: Equatable, Sendable {
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let differenceEvidenceCount: Int
    public let directDifferenceCount: Int
    public let unresolvedReasons: [String]
    public let unsupportedAxes: [String]
    public let sequenceRequired: Bool

    public init(comparison: CandidateComparison) {
        self.comparisonStable = comparison.comparisonStable
        self.continuationStable = comparison.continuationStable
        self.differenceEvidenceCount = comparison.differenceEvidence.count
        self.directDifferenceCount = comparison.directDifferenceCount
        self.unresolvedReasons = comparison.comparisonWarnings.filter {
            $0.contains("unstable") || $0.contains("different_")
        }
        self.unsupportedAxes = comparison.unsupportedClaims
        self.sequenceRequired = comparison.requiresSequenceEvidence
    }
}

public enum ComparisonIsolationContract {
    public static let mutatesMoveIntent = false
    public static let mutatesContextConfidence = false
    public static let mutatesIntentCandidate = false
}
