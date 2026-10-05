import Foundation

public enum GroundedWhyNowTrigger: String, Codable, CaseIterable, Equatable, Sendable {
    case directPreviousMove = "DIRECT_PREVIOUS_MOVE"
    case immediateThreat = "IMMEDIATE_THREAT"
    case forcingTactic = "FORCING_TACTIC"
    case exchangeSequence = "EXCHANGE_SEQUENCE"
    case verifiedSequenceTiming = "VERIFIED_SEQUENCE_TIMING"
    case formationWindow = "FORMATION_WINDOW"
    case endgameUrgency = "ENDGAME_URGENCY"
    case noneIdentified = "NONE_IDENTIFIED"
}

public enum GroundedClaimType: String, Codable, CaseIterable, Equatable, Sendable {
    case fact = "FACT"
    case contextChange = "CONTEXT_CHANGE"
    case effect = "EFFECT"
    case intent = "INTENT"
    case outcome = "OUTCOME"
    case uncertainty = "UNCERTAINTY"
}

public enum GroundedExplanationAuthorityKind: String, Codable, Equatable, Sendable {
    case directPreviousMove = "DIRECT_PREVIOUS_MOVE"
    case concreteBoardEffect = "CONCRETE_BOARD_EFFECT"
    case stableCounterfactual = "STABLE_COUNTERFACTUAL"
    case stableEnginePV = "STABLE_ENGINE_PV"
    case openingOrPrecedent = "OPENING_OR_PRECEDENT"
    case specializedReference = "SPECIALIZED_REFERENCE"
    case geometry = "GEOMETRY"
    case none = "NONE"
}

public enum GroundedVerbalizationMode: String, Codable, Equatable, Sendable {
    case assertive = "ASSERTIVE"
    case measured = "MEASURED"
    case tentative = "TENTATIVE"
    case uncertaintyOnly = "UNCERTAINTY_ONLY"
    case omit = "OMIT"
}

public enum GroundedMissingEvidenceReason: String, Codable, CaseIterable, Equatable, Sendable {
    case noDirectCausalLink = "NO_DIRECT_CAUSAL_LINK"
    case noNonGeometryAnchor = "NO_NON_GEOMETRY_ANCHOR"
    case multipleIntentCandidates = "MULTIPLE_INTENT_CANDIDATES"
    case insufficientScoreMargin = "INSUFFICIENT_SCORE_MARGIN"
    case unstableEngineComparison = "UNSTABLE_ENGINE_COMPARISON"
    case insufficientCounterfactual = "INSUFFICIENT_COUNTERFACTUAL"
    case insufficientSequenceContinuity = "INSUFFICIENT_SEQUENCE_CONTINUITY"
    case specializedReferenceNotVerified = "SPECIALIZED_REFERENCE_NOT_VERIFIED"
    case specializedRequiredEvidenceMissing = "SPECIALIZED_REQUIRED_EVIDENCE_MISSING"
    case claimLayerConflict = "CLAIM_LAYER_CONFLICT"
}

public struct GroundedExplanationContext: Codable, Equatable, Sendable {
    public let trigger: GroundedWhyNowTrigger
    public let sourceEvidenceIDs: [String]
    public let sourceSignalIDs: [String]
    public let claimTypes: [GroundedClaimType]
    public let observedChange: String?
    public let previousMove: String?
    public let authorityKind: GroundedExplanationAuthorityKind
    public let safeToVerbalize: Bool
    public let missingEvidence: [GroundedMissingEvidenceReason]
    public let compatibleIntent: MoveIntent?
    public let detail: String
    public let verbalizationMode: GroundedVerbalizationMode

    public init(
        trigger: GroundedWhyNowTrigger,
        sourceEvidenceIDs: [String],
        sourceSignalIDs: [String],
        claimTypes: [GroundedClaimType],
        observedChange: String?,
        previousMove: String?,
        authorityKind: GroundedExplanationAuthorityKind,
        safeToVerbalize: Bool,
        missingEvidence: [GroundedMissingEvidenceReason],
        compatibleIntent: MoveIntent?,
        detail: String,
        verbalizationMode: GroundedVerbalizationMode
    ) {
        self.trigger = trigger
        self.sourceEvidenceIDs = sourceEvidenceIDs
        self.sourceSignalIDs = sourceSignalIDs
        self.claimTypes = claimTypes
        self.observedChange = observedChange
        self.previousMove = previousMove
        self.authorityKind = authorityKind
        self.safeToVerbalize = safeToVerbalize
        self.missingEvidence = missingEvidence
        self.compatibleIntent = compatibleIntent
        self.detail = detail
        self.verbalizationMode = verbalizationMode
    }
}

public enum GroundedExplanationProjector {
    public static func make(analysis: MoveContextAnalysis) -> GroundedExplanationContext {
        let compatibleEvidence = analysis.evidence.filter {
            $0.supportedIntent == analysis.selectedIntent && $0.weight > 0
        }
        let directEvidence = compatibleEvidence.filter { $0.kind == .previousMoveCausality }
        let hasDirectPreviousMove = analysis.previousMove != nil && !directEvidence.isEmpty
        let hasImmediateThreat = immediateThreatIsExplicit(in: analysis)
        let hasForcingTactic = forcingTacticIsExplicit(in: analysis)
        let hasExchangeSequence = exchangeSequenceIsExplicit(in: analysis)

        let trigger: GroundedWhyNowTrigger
        // EXCHANGE_SEQUENCE is a frozen, explicit sequence category. In the current
        // engine ev_recapture_exchange is itself previous-move-causality evidence,
        // so evaluate the more specific exchange condition before the general
        // DIRECT_PREVIOUS_MOVE bucket. This changes explanation classification only.
        if hasExchangeSequence {
            trigger = .exchangeSequence
        } else if hasDirectPreviousMove {
            trigger = .directPreviousMove
        } else if hasImmediateThreat {
            trigger = .immediateThreat
        } else if hasForcingTactic {
            trigger = .forcingTactic
        } else {
            trigger = .noneIdentified
        }

        let sourceEvidenceIDs = evidenceIDs(
            for: trigger,
            analysis: analysis,
            compatibleEvidence: compatibleEvidence,
            directEvidence: directEvidence
        )
        let sourceSignalIDs = signalIDs(for: trigger, analysis: analysis)
        let missingEvidence = missingEvidenceReasons(
            for: trigger,
            analysis: analysis,
            compatibleEvidence: compatibleEvidence
        )
        let authorityKind = authority(
            for: trigger,
            analysis: analysis,
            compatibleEvidence: compatibleEvidence
        )
        let claimTypes = claims(
            for: trigger,
            analysis: analysis,
            hasSpecificEngineForcing: hasSpecificEngineForcingEvidence(in: analysis)
        )

        return GroundedExplanationContext(
            trigger: trigger,
            sourceEvidenceIDs: sourceEvidenceIDs,
            sourceSignalIDs: sourceSignalIDs,
            claimTypes: claimTypes,
            observedChange: observedChange(for: trigger, analysis: analysis),
            previousMove: analysis.previousMove,
            authorityKind: authorityKind,
            safeToVerbalize: true,
            missingEvidence: missingEvidence,
            compatibleIntent: compatibleIntent(from: analysis),
            detail: safeWhyNowDetail(for: trigger, analysis: analysis, directEvidence: directEvidence),
            verbalizationMode: verbalizationMode(for: analysis.confidence)
        )
    }

    private static func compatibleIntent(from analysis: MoveContextAnalysis) -> MoveIntent? {
        guard analysis.selectedIntent != .unresolved,
              analysis.confidence != .unresolved else {
            return nil
        }
        return analysis.selectedIntent
    }

    private static func verbalizationMode(for confidence: ContextConfidence) -> GroundedVerbalizationMode {
        switch confidence {
        case .high: return .assertive
        case .medium: return .measured
        case .low: return .tentative
        case .unresolved: return .uncertaintyOnly
        }
    }

    private static func immediateThreatIsExplicit(in analysis: MoveContextAnalysis) -> Bool {
        if analysis.facts.contains(where: { $0.kind == .sideInCheck }) {
            return true
        }
        if analysis.contextChanges.contains(where: { $0.id == "new_attack_from_previous_move" }) {
            return true
        }
        return analysis.evidence.contains {
            $0.weight > 0 && ($0.id == "ev_threatmate_defense" || $0.id == "ev_check_defense" || $0.id == "ev_king_escape")
        }
    }

    private static func forcingTacticIsExplicit(in analysis: MoveContextAnalysis) -> Bool {
        if analysis.effects.contains(where: { $0.id == "gives_check" }) {
            return true
        }
        return hasSpecificEngineForcingEvidence(in: analysis)
    }

    private static func hasSpecificEngineForcingEvidence(in analysis: MoveContextAnalysis) -> Bool {
        analysis.evidence.contains {
            $0.weight > 0 && ($0.id == "ev_forced_mate" || $0.id == "ev_threatmate")
        }
    }

    private static func exchangeSequenceIsExplicit(in analysis: MoveContextAnalysis) -> Bool {
        let hasExchangeSignal = analysis.contextChanges.contains { $0.id == "exchange_sequence" }
        let hasExchangeEvidence = analysis.evidence.contains {
            $0.weight > 0 && $0.id == "ev_recapture_exchange"
        }
        return hasExchangeSignal && hasExchangeEvidence
    }

    private static func evidenceIDs(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis,
        compatibleEvidence: [ContextEvidence],
        directEvidence: [ContextEvidence]
    ) -> [String] {
        let ids: [String]
        switch trigger {
        case .directPreviousMove:
            ids = directEvidence.map { $0.id }
        case .immediateThreat:
            ids = compatibleEvidence.filter {
                $0.id == "ev_threatmate_defense"
                    || $0.id == "ev_check_defense"
                    || $0.id == "ev_king_escape"
                    || $0.id.hasPrefix("ev_piece_defense_")
                    || $0.id == "ev_capture_threat_response"
                    || $0.id == "ev_bishop_line_response"
            }.map { $0.id }
        case .forcingTactic:
            ids = analysis.evidence.filter {
                $0.weight > 0 && ($0.id == "ev_forced_mate" || $0.id == "ev_threatmate" || $0.id == "ev_check_continuation")
            }.map { $0.id }
        case .exchangeSequence:
            ids = analysis.evidence.filter { $0.weight > 0 && $0.id == "ev_recapture_exchange" }.map { $0.id }
        case .noneIdentified:
            ids = compatibleEvidence.filter { $0.kind != .geometry }.map { $0.id }
        case .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            ids = []
        }
        return Array(Set(ids)).sorted()
    }

    private static func signalIDs(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis
    ) -> [String] {
        var ids: [String] = []
        var seen = Set<String>()
        func append(_ id: String) {
            guard seen.insert(id).inserted else { return }
            ids.append(id)
        }

        for fact in analysis.facts {
            switch trigger {
            case .directPreviousMove:
                if fact.kind == .previousMove
                    || fact.kind == .currentMove
                    || fact.kind == .sideInCheck
                    || fact.kind == .rookPawnAdvance
                    || fact.kind == .newlyAttackedPiece {
                    append(fact.id)
                }
            case .immediateThreat:
                if fact.kind == .previousMove
                    || fact.kind == .currentMove
                    || fact.kind == .sideInCheck
                    || fact.kind == .newlyAttackedPiece {
                    append(fact.id)
                }
            case .forcingTactic:
                if fact.kind == .currentMove || fact.kind == .check {
                    append(fact.id)
                }
            case .exchangeSequence:
                if fact.kind == .previousMove || fact.kind == .currentMove || fact.kind == .capture {
                    append(fact.id)
                }
            case .noneIdentified:
                if fact.kind == .previousMove || fact.kind == .currentMove {
                    append(fact.id)
                }
            case .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
                break
            }
        }

        let allowedSignalIDs: Set<String>
        switch trigger {
        case .directPreviousMove:
            allowedSignalIDs = [
                "rook_pawn_pressure", "added_control", "new_attack_from_previous_move",
                "check_resolved", "threat_source_captured", "threat_evaded", "added_piece_defender",
                "exchange_sequence", "material_capture"
            ]
        case .immediateThreat:
            allowedSignalIDs = ["new_attack_from_previous_move", "check_resolved", "threat_source_captured", "threat_evaded"]
        case .forcingTactic:
            allowedSignalIDs = ["gives_check"]
        case .exchangeSequence:
            allowedSignalIDs = ["exchange_sequence", "material_capture"]
        case .noneIdentified, .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            allowedSignalIDs = []
        }

        for signal in analysis.contextChanges where allowedSignalIDs.contains(signal.id) {
            append(signal.id)
        }
        for signal in analysis.effects where allowedSignalIDs.contains(signal.id) {
            append(signal.id)
        }
        for signal in analysis.outcomes where allowedSignalIDs.contains(signal.id) {
            append(signal.id)
        }
        return ids
    }

    private static func missingEvidenceReasons(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis,
        compatibleEvidence: [ContextEvidence]
    ) -> [GroundedMissingEvidenceReason] {
        var reasons: [GroundedMissingEvidenceReason] = []
        func append(_ reason: GroundedMissingEvidenceReason) {
            if !reasons.contains(reason) { reasons.append(reason) }
        }

        let hasDirect = analysis.previousMove != nil && compatibleEvidence.contains { $0.kind == .previousMoveCausality }
        let hasNonGeometryAnchor = compatibleEvidence.contains {
            $0.kind == .previousMoveCausality
                || $0.kind == .boardEffect
                || $0.kind == .enginePV
                || $0.kind == .counterfactual
        }

        if trigger == .noneIdentified {
            if !hasDirect { append(.noDirectCausalLink) }
            if !hasNonGeometryAnchor { append(.noNonGeometryAnchor) }
        }
        if analysis.confidence == .low {
            if analysis.intentCandidates.count > 1 { append(.multipleIntentCandidates) }
            append(.insufficientScoreMargin)
        }
        if analysis.confidence == .unresolved {
            if analysis.intentCandidates.count > 1 { append(.multipleIntentCandidates) }
            if !hasNonGeometryAnchor { append(.noNonGeometryAnchor) }
        }
        if analysis.facts.contains(where: { $0.kind == .engineComparison })
            && !analysis.outcomes.contains(where: { $0.id == "engine_comparison_stable" }) {
            append(.unstableEngineComparison)
        }
        if trigger == .forcingTactic,
           !hasSpecificEngineForcingEvidence(in: analysis),
           analysis.selectedIntent == .matingAttack || analysis.selectedIntent == .threatmate {
            append(.claimLayerConflict)
        }
        return reasons
    }

    private static func authority(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis,
        compatibleEvidence: [ContextEvidence]
    ) -> GroundedExplanationAuthorityKind {
        switch trigger {
        case .directPreviousMove:
            return .directPreviousMove
        case .immediateThreat:
            if compatibleEvidence.contains(where: { $0.kind == .counterfactual }) {
                return .stableCounterfactual
            }
            return .concreteBoardEffect
        case .forcingTactic:
            if hasSpecificEngineForcingEvidence(in: analysis) {
                return .stableEnginePV
            }
            return .concreteBoardEffect
        case .exchangeSequence:
            return analysis.previousMove == nil ? .concreteBoardEffect : .directPreviousMove
        case .noneIdentified:
            if compatibleEvidence.contains(where: { $0.kind == .counterfactual }) { return .stableCounterfactual }
            if compatibleEvidence.contains(where: { $0.kind == .enginePV }) { return .stableEnginePV }
            if compatibleEvidence.contains(where: { $0.kind == .boardEffect }) { return .concreteBoardEffect }
            if compatibleEvidence.contains(where: { $0.kind == .openingBook || $0.kind == .precedent }) { return .openingOrPrecedent }
            if compatibleEvidence.contains(where: { $0.kind == .geometry }) { return .geometry }
            return .none
        case .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            return .none
        }
    }

    private static func claims(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis,
        hasSpecificEngineForcing: Bool
    ) -> [GroundedClaimType] {
        var values: [GroundedClaimType] = []
        func append(_ value: GroundedClaimType) {
            if !values.contains(value) { values.append(value) }
        }

        if compatibleIntent(from: analysis) != nil {
            append(.intent)
        }
        switch trigger {
        case .directPreviousMove:
            append(.fact)
            append(.contextChange)
        case .immediateThreat:
            append(.fact)
            append(.contextChange)
        case .forcingTactic:
            append(.fact)
            append(.effect)
            if hasSpecificEngineForcing { append(.outcome) }
        case .exchangeSequence:
            append(.contextChange)
            append(.outcome)
        case .noneIdentified:
            append(.uncertainty)
            if analysis.selectedIntent == .unresolved { append(.fact) }
        case .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            append(.uncertainty)
        }
        return values
    }

    private static func observedChange(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis
    ) -> String? {
        switch trigger {
        case .directPreviousMove:
            return analysis.contextChanges.first?.detail
        case .immediateThreat:
            if analysis.facts.contains(where: { $0.kind == .sideInCheck }) { return "side_in_check" }
            return analysis.contextChanges.first(where: { $0.id == "new_attack_from_previous_move" || $0.id == "check_resolved" })?.detail
        case .forcingTactic:
            return analysis.effects.first(where: { $0.id == "gives_check" })?.detail
        case .exchangeSequence:
            return analysis.contextChanges.first(where: { $0.id == "exchange_sequence" })?.detail
        case .noneIdentified, .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            return nil
        }
    }

    private static func safeWhyNowDetail(
        for trigger: GroundedWhyNowTrigger,
        analysis: MoveContextAnalysis,
        directEvidence: [ContextEvidence]
    ) -> String {
        switch trigger {
        case .directPreviousMove:
            let ids = Set(directEvidence.map { $0.id })
            if ids.contains("ev_rook_pawn_response") {
                return "直前に相手が飛車先の歩を進め、その前進に直接対応する条件が生じたためです。"
            }
            if ids.contains("ev_bishop_line_response") {
                return "直前手で角筋から自軍の駒が新たに狙われ、その変化へ直接対応する局面になったためです。"
            }
            if ids.contains("ev_capture_threat_response") {
                return "直前手で自軍の駒への具体的な攻撃が生じ、その変化へ直接対応する局面になったためです。"
            }
            if ids.contains(where: { $0.hasPrefix("ev_piece_defense_") }) {
                return "直前手で自軍の駒が新たに狙われ、守りを追加する必要が生じたためです。"
            }
            if ids.contains("ev_king_escape") || ids.contains("ev_check_defense") {
                return "直前から自玉が王手を受けており、この手でその状態を解消する直接の必要があったためです。"
            }
            if ids.contains("ev_recapture_exchange") {
                return "直前手から同じ地点で取り合いが続いており、その交換手順へ直接対応する局面だったためです。"
            }
            return "直前手で、既存解析が選択した狙いに直接関係する変化が確認されたためです。"

        case .immediateThreat:
            if analysis.facts.contains(where: { $0.kind == .sideInCheck }) {
                return "自玉が王手を受けていることが確認でき、応答を急ぐ条件が明示されています。"
            }
            if analysis.evidence.contains(where: { $0.id == "ev_threatmate_defense" && $0.weight > 0 }) {
                return "安定した比較情報で、相手の即時的な脅威がこの手の前後で変化することが確認されています。"
            }
            return "直前手によって自軍の駒への具体的な攻撃が新たに生じ、即時に対応する条件が確認されています。"

        case .forcingTactic:
            if analysis.evidence.contains(where: { $0.id == "ev_forced_mate" && $0.weight > 0 }) {
                return "安定したエンジン根拠で、強制的な終局手順につながることが確認されています。"
            }
            if analysis.evidence.contains(where: { $0.id == "ev_threatmate" && $0.weight > 0 }) {
                return "安定したエンジン根拠で、次の一手に直結する強制的な脅威が確認されています。"
            }
            return "この手で王手になったことは確認できます。王手という事実以上の目的までは広げません。"

        case .exchangeSequence:
            return "直前からの取り合いが同じ地点で継続していることが確認でき、その交換手順に沿う局面です。"

        case .noneIdentified:
            switch analysis.confidence {
            case .low:
                return "現時点では、「なぜ今か」を特定できる直接根拠が十分ではありません。主な狙いは候補として扱い、理由を広げません。"
            case .unresolved:
                return "「なぜ今か」を特定できる直接根拠は確認できていません。目的は断定せず、確認できる事実と不確実性だけを扱います。"
            case .high, .medium:
                return "主な狙いは既存解析の結果として扱いますが、「なぜ今か」を特定できる直接根拠は確認できていません。"
            }

        case .verifiedSequenceTiming, .formationWindow, .endgameUrgency:
            return "必要な追加Evidence gateを満たしていないため、この理由は使用しません。"
        }
    }
}
