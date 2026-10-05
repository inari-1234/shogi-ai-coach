import Foundation

public struct SequenceExchangeEventEvidence: Equatable, Sendable {
    public let horizonPly: Int
    public let candidateAEvents: [String]
    public let candidateBEvents: [String]
    public let candidateAOwnershipDelta: String
    public let candidateBOwnershipDelta: String
    public let differs: Bool
    public let causalStrength: CausalStrength
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(
        horizonPly: Int,
        candidateAEvents: [String],
        candidateBEvents: [String],
        candidateAOwnershipDelta: String,
        candidateBOwnershipDelta: String,
        differs: Bool,
        causalStrength: CausalStrength,
        safeToVerbalize: Bool,
        limitations: [String]
    ) {
        self.horizonPly = horizonPly
        self.candidateAEvents = candidateAEvents
        self.candidateBEvents = candidateBEvents
        self.candidateAOwnershipDelta = candidateAOwnershipDelta
        self.candidateBOwnershipDelta = candidateBOwnershipDelta
        self.differs = differs
        self.causalStrength = causalStrength
        self.safeToVerbalize = safeToVerbalize
        self.limitations = limitations
    }
}

public extension SequenceComparisonEvidence {
    /// Exchange evidence that preserves concrete capture/recapture events even when
    /// the stable-horizon ownership inventory returns to an equal count.
    ///
    /// This is intentionally separate from engine evaluation causality: it proves
    /// only that the reconstructed stable PV contains a different exchange sequence.
    var exchangeEventConsequence: SequenceExchangeEventEvidence? {
        let aEvents = Self.exchangeEvents(in: candidateASequence, through: stableHorizonPly)
        let bEvents = Self.exchangeEvents(in: candidateBSequence, through: stableHorizonPly)
        guard !aEvents.isEmpty || !bEvents.isEmpty else { return nil }

        let aDelta = exchangeConsequence?.candidateAOwnershipDelta ?? "no_net_ownership_change"
        let bDelta = exchangeConsequence?.candidateBOwnershipDelta ?? "no_net_ownership_change"
        let differs = aEvents != bEvents || aDelta != bDelta
        let strength: CausalStrength = stableHorizonPly <= 2 ? .replyLinked : .sequenceCorrelated

        return SequenceExchangeEventEvidence(
            horizonPly: stableHorizonPly,
            candidateAEvents: aEvents,
            candidateBEvents: bEvents,
            candidateAOwnershipDelta: aDelta,
            candidateBOwnershipDelta: bDelta,
            differs: differs,
            causalStrength: strength,
            safeToVerbalize: sequenceStable && stableHorizonPly > 0,
            limitations: [
                "exchange_events_are_observed_in_stable_pv_only",
                "equal_net_material_does_not_erase_exchange_event",
                "does_not_claim_complete_engine_evaluation_reason",
                "pv_line_is_not_an_exhaustive_or_proven_forced_tree"
            ]
        )
    }

    private static func exchangeEvents(
        in sequence: CandidateSequenceEvidence,
        through horizon: Int
    ) -> [String] {
        sequence.plies.compactMap { ply in
            guard ply.ply <= horizon, ply.withinStableHorizon else { return nil }
            if ply.recapturesPreviousMover {
                let captured = ply.effect.capturedPiece?.rawValue ?? "unknown"
                return "ply\(ply.ply):recapture:\(captured):\(ply.move)"
            }
            if let captured = ply.effect.capturedPiece {
                return "ply\(ply.ply):capture:\(captured.rawValue):\(ply.move)"
            }
            return nil
        }
    }
}

public struct SequenceExchangeEventDiagnostic: Codable, Equatable, Sendable {
    public let horizonPly: Int
    public let candidateAEvents: [String]
    public let candidateBEvents: [String]
    public let candidateAOwnershipDelta: String
    public let candidateBOwnershipDelta: String
    public let differs: Bool
    public let causalStrength: String
    public let safeToVerbalize: Bool
    public let limitations: [String]

    public init(_ evidence: SequenceExchangeEventEvidence) {
        horizonPly = evidence.horizonPly
        candidateAEvents = evidence.candidateAEvents
        candidateBEvents = evidence.candidateBEvents
        candidateAOwnershipDelta = evidence.candidateAOwnershipDelta
        candidateBOwnershipDelta = evidence.candidateBOwnershipDelta
        differs = evidence.differs
        causalStrength = evidence.causalStrength.rawValue
        safeToVerbalize = evidence.safeToVerbalize
        limitations = evidence.limitations
    }
}
