import Foundation

public enum CoachingComparisonTone: String, Codable, Equatable, Sendable {
    case assertive = "ASSERTIVE"
    case measured = "MEASURED"
    case tentative = "TENTATIVE"
    case unresolved = "UNRESOLVED"
}

public enum CoachingComparisonSectionKind: String, Codable, Equatable, Sendable {
    case groundedDifference = "GROUNDED_DIFFERENCE"
    case alternativeOutcome = "ALTERNATIVE_OUTCOME"
    case differenceTiming = "DIFFERENCE_TIMING"
    case opponentOpportunity = "OPPONENT_OPPORTUNITY"
    case exchangeAfter = "EXCHANGE_AFTER"
    case confidence = "CONFIDENCE"
}

public struct CoachingComparisonSection: Codable, Equatable, Sendable {
    public let kind: CoachingComparisonSectionKind
    public let text: String
    public let evidenceIDs: [String]
    public let confidence: ComparisonConfidenceLevel
    public let causalWordingUsed: Bool

    public init(
        kind: CoachingComparisonSectionKind,
        text: String,
        evidenceIDs: [String],
        confidence: ComparisonConfidenceLevel,
        causalWordingUsed: Bool
    ) {
        self.kind = kind
        self.text = text
        self.evidenceIDs = evidenceIDs
        self.confidence = confidence
        self.causalWordingUsed = causalWordingUsed
    }
}

public struct CandidateComparisonCoachingExplanation: Codable, Equatable, Sendable {
    public let comparisonID: String
    public let preferredMove: String?
    public let alternativeMove: String?
    public let headline: String
    public let primaryReason: String
    public let alternativeOutcome: String?
    public let differenceTiming: String?
    public let opponentOpportunity: String?
    public let exchangeAfter: String?
    public let confidenceNote: String
    public let confidence: ComparisonConfidenceLevel
    public let tone: CoachingComparisonTone
    public let sections: [CoachingComparisonSection]
    public let usedEvidenceIDs: [String]
    public let withheldEvidenceIDs: [String]
    public let warnings: [String]

    public init(
        comparisonID: String,
        preferredMove: String?,
        alternativeMove: String?,
        headline: String,
        primaryReason: String,
        alternativeOutcome: String?,
        differenceTiming: String?,
        opponentOpportunity: String?,
        exchangeAfter: String?,
        confidenceNote: String,
        confidence: ComparisonConfidenceLevel,
        tone: CoachingComparisonTone,
        sections: [CoachingComparisonSection],
        usedEvidenceIDs: [String],
        withheldEvidenceIDs: [String],
        warnings: [String]
    ) {
        self.comparisonID = comparisonID
        self.preferredMove = preferredMove
        self.alternativeMove = alternativeMove
        self.headline = headline
        self.primaryReason = primaryReason
        self.alternativeOutcome = alternativeOutcome
        self.differenceTiming = differenceTiming
        self.opponentOpportunity = opponentOpportunity
        self.exchangeAfter = exchangeAfter
        self.confidenceNote = confidenceNote
        self.confidence = confidence
        self.tone = tone
        self.sections = sections
        self.usedEvidenceIDs = usedEvidenceIDs
        self.withheldEvidenceIDs = withheldEvidenceIDs
        self.warnings = warnings
    }
}

public enum ComparisonCoachingExplanationResolver {
    public static func resolve(
        comparison: CandidateComparison,
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence? = nil
    ) -> CandidateComparisonCoachingExplanation {
        var warnings = comparison.comparisonWarnings + confidence.warnings + (sequence?.warnings ?? [])
        warnings.append("comparison_explanation_is_read_only_sidecar")
        warnings.append("score_gap_is_not_used_as_causal_explanation")

        guard confidence.comparisonID == comparison.comparisonID else {
            warnings.append("confidence_comparison_id_mismatch")
            return unresolved(
                comparison: comparison,
                confidence: confidence,
                warnings: warnings
            )
        }
        if let sequence, sequence.comparisonID != comparison.comparisonID {
            warnings.append("sequence_comparison_id_mismatch")
            return unresolved(
                comparison: comparison,
                confidence: confidence,
                warnings: warnings
            )
        }

        let preferred = preferredCandidate(in: comparison)
        let alternative = preferred.flatMap { preferredCandidate in
            otherCandidate(than: preferredCandidate, in: comparison)
        }
        let allowed = allowedEvidence(comparison: comparison, confidence: confidence)
        let ordered = orderEvidence(allowed, dominant: comparison.dominantDifferenceCandidate)

        guard confidence.level != .unresolved,
              let preferred,
              let alternative,
              let primary = ordered.first,
              let primaryClaim = claim(for: primary.id, confidence: confidence) else {
            return unresolved(
                comparison: comparison,
                confidence: confidence,
                warnings: warnings,
                preferred: preferred,
                alternative: alternative
            )
        }

        let primaryText = differenceText(
            evidence: primary,
            claim: primaryClaim,
            preferred: preferred,
            alternative: alternative,
            comparison: comparison
        )

        var sections: [CoachingComparisonSection] = [
            CoachingComparisonSection(
                kind: .groundedDifference,
                text: primaryText,
                evidenceIDs: [primary.id],
                confidence: primaryClaim.confidence,
                causalWordingUsed: primaryClaim.eligibleForCausalWording
            )
        ]

        if ordered.count > 1 {
            for supporting in ordered.dropFirst().prefix(2) {
                guard let supportingClaim = claim(for: supporting.id, confidence: confidence) else { continue }
                sections.append(
                    CoachingComparisonSection(
                        kind: .groundedDifference,
                        text: differenceText(
                            evidence: supporting,
                            claim: supportingClaim,
                            preferred: preferred,
                            alternative: alternative,
                            comparison: comparison
                        ),
                        evidenceIDs: [supporting.id],
                        confidence: supportingClaim.confidence,
                        causalWordingUsed: supportingClaim.eligibleForCausalWording
                    )
                )
            }
        }

        let timing = timingText(from: ordered, confidence: confidence, sequence: sequence)
        if let timing {
            let timingIDs = timingEvidenceIDs(from: ordered, confidence: confidence)
            sections.append(
                CoachingComparisonSection(
                    kind: .differenceTiming,
                    text: timing,
                    evidenceIDs: timingIDs,
                    confidence: confidence.level,
                    causalWordingUsed: false
                )
            )
        }

        let alternativeOutcome = alternativeOutcomeText(
            alternative: alternative,
            allowedEvidence: ordered,
            confidence: confidence,
            sequence: sequence
        )
        if let alternativeOutcome {
            sections.append(
                CoachingComparisonSection(
                    kind: .alternativeOutcome,
                    text: alternativeOutcome,
                    evidenceIDs: sequenceEligibleEvidenceIDs(ordered),
                    confidence: confidence.level,
                    causalWordingUsed: false
                )
            )
        }

        let opponentOpportunity = opponentOpportunityText(
            alternative: alternative,
            allowedEvidence: ordered,
            confidence: confidence,
            sequence: sequence
        )
        if let opponentOpportunity {
            sections.append(
                CoachingComparisonSection(
                    kind: .opponentOpportunity,
                    text: opponentOpportunity,
                    evidenceIDs: ordered.filter {
                        $0.kind == .opponentReplyDifference || $0.kind == .exchangeConsequenceDifference || $0.kind == .sequenceEventDifference
                    }.map(\.id),
                    confidence: confidence.level,
                    causalWordingUsed: false
                )
            )
        }

        let exchangeAfter = exchangeAfterText(
            allowedEvidence: ordered,
            sequence: sequence
        )
        if let exchangeAfter {
            sections.append(
                CoachingComparisonSection(
                    kind: .exchangeAfter,
                    text: exchangeAfter,
                    evidenceIDs: ordered.filter {
                        $0.kind == .exchangeConsequenceDifference || $0.kind == .materialDifference
                    }.map(\.id),
                    confidence: confidence.level,
                    causalWordingUsed: false
                )
            )
        }

        let confidenceNote = confidenceText(confidence.level)
        sections.append(
            CoachingComparisonSection(
                kind: .confidence,
                text: confidenceNote,
                evidenceIDs: [],
                confidence: confidence.level,
                causalWordingUsed: false
            )
        )

        let usedIDs = Array(Set(sections.flatMap(\.evidenceIDs))).sorted()
        warnings.append(contentsOf: comparison.unsupportedClaims.map { "unsupported_axis_withheld:\($0)" })
        warnings = Array(Set(warnings)).sorted()

        return CandidateComparisonCoachingExplanation(
            comparisonID: comparison.comparisonID,
            preferredMove: preferred.move,
            alternativeMove: alternative.move,
            headline: headlineText(preferred: preferred, alternative: alternative, comparison: comparison),
            primaryReason: primaryText,
            alternativeOutcome: alternativeOutcome,
            differenceTiming: timing,
            opponentOpportunity: opponentOpportunity,
            exchangeAfter: exchangeAfter,
            confidenceNote: confidenceNote,
            confidence: confidence.level,
            tone: tone(for: confidence.level),
            sections: sections,
            usedEvidenceIDs: usedIDs,
            withheldEvidenceIDs: confidence.withheldEvidenceIDs.sorted(),
            warnings: warnings
        )
    }

    private static func allowedEvidence(
        comparison: CandidateComparison,
        confidence: ComparisonConfidenceResult
    ) -> [DifferenceEvidence] {
        let allowedIDs = Set(confidence.eligibleEvidenceIDs)
        return comparison.differenceEvidence.filter {
            allowedIDs.contains($0.id)
                && $0.kind != .scoreDifference
                && $0.kind != .noGroundedCausalDifference
                && $0.safeToVerbalize
                && claim(for: $0.id, confidence: confidence)?.safeToVerbalize == true
                && claim(for: $0.id, confidence: confidence)?.confidence != .unresolved
        }
    }

    private static func orderEvidence(
        _ evidence: [DifferenceEvidence],
        dominant: DifferenceEvidence?
    ) -> [DifferenceEvidence] {
        evidence.sorted { lhs, rhs in
            let leftDominant = lhs.id == dominant?.id
            let rightDominant = rhs.id == dominant?.id
            if leftDominant != rightDominant { return leftDominant }
            let leftStrength = strengthPriority(lhs.causalStrength)
            let rightStrength = strengthPriority(rhs.causalStrength)
            if leftStrength != rightStrength { return leftStrength < rightStrength }
            let leftHorizon = horizonPriority(lhs.horizon)
            let rightHorizon = horizonPriority(rhs.horizon)
            if leftHorizon != rightHorizon { return leftHorizon < rightHorizon }
            return kindPriority(lhs.kind) < kindPriority(rhs.kind)
        }
    }

    private static func preferredCandidate(in comparison: CandidateComparison) -> CandidateAnalysis? {
        let candidates = [comparison.candidateA, comparison.candidateB]
        if let recommended = candidates.first(where: { $0.branchType == .recommended }) {
            return recommended
        }
        if comparison.candidateA.rank != comparison.candidateB.rank {
            return comparison.candidateA.rank < comparison.candidateB.rank
                ? comparison.candidateA
                : comparison.candidateB
        }
        return nil
    }

    private static func otherCandidate(
        than candidate: CandidateAnalysis,
        in comparison: CandidateComparison
    ) -> CandidateAnalysis? {
        if comparison.candidateA.candidateID == candidate.candidateID {
            return comparison.candidateB
        }
        if comparison.candidateB.candidateID == candidate.candidateID {
            return comparison.candidateA
        }
        return nil
    }

    private static func claim(
        for evidenceID: String,
        confidence: ComparisonConfidenceResult
    ) -> ClaimConfidenceAssessment? {
        confidence.claimAssessments.first { $0.evidenceID == evidenceID }
    }

    private static func differenceText(
        evidence: DifferenceEvidence,
        claim: ClaimConfidenceAssessment,
        preferred: CandidateAnalysis,
        alternative: CandidateAnalysis,
        comparison: CandidateComparison
    ) -> String {
        let preferredIsA = comparison.candidateA.candidateID == preferred.candidateID
        let preferredValue = preferredIsA ? evidence.candidateAValue : evidence.candidateBValue
        let alternativeValue = preferredIsA ? evidence.candidateBValue : evidence.candidateAValue
        let fact = factText(
            kind: evidence.kind,
            preferredValue: preferredValue,
            alternativeValue: alternativeValue,
            preferredMove: preferred.move,
            alternativeMove: alternative.move
        )

        if claim.eligibleForCausalWording {
            return "候補差の具体的な根拠の一つは、\(fact)"
        }
        return "\(fact) ただし、この差だけを優劣の直接原因とは断定しません。"
    }

    private static func factText(
        kind: DifferenceKind,
        preferredValue: String,
        alternativeValue: String,
        preferredMove: String,
        alternativeMove: String
    ) -> String {
        switch kind {
        case .captureDifference:
            return captureFact(preferredValue: preferredValue, alternativeValue: alternativeValue)
        case .materialDifference:
            return "\(preferredMove)と\(alternativeMove)では、指した直後の駒の所有状況に差があることです。"
        case .promotionDifference:
            return booleanContrast(
                preferredValue: preferredValue,
                alternativeValue: alternativeValue,
                trueText: "\(preferredMove)は成りを伴い、\(alternativeMove)は成りを伴わないことです。",
                falseText: "\(alternativeMove)は成りを伴い、\(preferredMove)は成りを伴わないことです。"
            )
        case .checkDifference:
            return booleanContrast(
                preferredValue: preferredValue,
                alternativeValue: alternativeValue,
                trueText: "\(preferredMove)は王手になり、\(alternativeMove)は王手にならないことです。",
                falseText: "\(alternativeMove)は王手になり、\(preferredMove)は王手にならないことです。"
            )
        case .mateStateDifference:
            return "詰みに関するエンジン評価の状態が異なることです（\(preferredMove): \(preferredValue)、\(alternativeMove): \(alternativeValue)）。"
        case .kingSafetyDifference:
            return "両候補で、定義済みの玉周辺の安全指標に具体的な差があることです。"
        case .exchangeConsequenceDifference:
            return "両候補で、相手の応手まで含めた交換の結果が異なることです。"
        case .opponentReplyDifference:
            return "両候補で、同条件のエンジンPVに現れた相手の応手が異なることです。"
        case .boardEffectDifference:
            return boardEffectFact(preferredValue: preferredValue, alternativeValue: alternativeValue)
        case .sequenceEventDifference:
            return "安定して追跡できた短い手順の中で、両候補に異なる出来事が現れることです。"
        case .scoreDifference:
            return "エンジン評価値に差があることです。"
        case .noGroundedCausalDifference:
            return "比較理由を特定できる具体的な差がまだ不足していることです。"
        }
    }

    private static func captureFact(preferredValue: String, alternativeValue: String) -> String {
        let preferredCapture = preferredValue != "none"
        let alternativeCapture = alternativeValue != "none"
        if preferredCapture && !alternativeCapture {
            return "上位候補では駒取りが発生し、別候補では発生しないことです。"
        }
        if !preferredCapture && alternativeCapture {
            return "別候補では駒取りが発生し、上位候補では発生しないことです。"
        }
        return "両候補で取る駒が異なることです。"
    }

    private static func boardEffectFact(preferredValue: String, alternativeValue: String) -> String {
        if preferredValue == "drop" && alternativeValue == "move" {
            return "上位候補は持駒を打つ手で、別候補は盤上の駒を動かす手であることです。"
        }
        if preferredValue == "move" && alternativeValue == "drop" {
            return "別候補は持駒を打つ手で、上位候補は盤上の駒を動かす手であることです。"
        }
        return "盤面への作用が両候補で異なることです。"
    }

    private static func booleanContrast(
        preferredValue: String,
        alternativeValue: String,
        trueText: String,
        falseText: String
    ) -> String {
        if preferredValue == "true" && alternativeValue == "false" { return trueText }
        if preferredValue == "false" && alternativeValue == "true" { return falseText }
        return "両候補で状態が異なることです。"
    }

    private static func timingText(
        from evidence: [DifferenceEvidence],
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence?
    ) -> String? {
        guard let first = evidence.first(where: {
            claim(for: $0.id, confidence: confidence)?.confidence != .unresolved
        }) else { return nil }

        switch first.horizon {
        case .immediate:
            return "この差は、候補手を指した直後から確認できます。"
        case .opponentReply:
            guard sequence?.stableHorizonPly ?? 0 >= 2 else { return nil }
            return "この差は、相手の応手まで進めたところで確認できます。"
        case .ownContinuation:
            guard sequence?.stableHorizonPly ?? 0 >= 3 else { return nil }
            return "この差は、自分の次の手まで進めたところで確認できます。"
        case .shortHorizon:
            guard let sequence, sequence.stableHorizonPly >= 2 else { return nil }
            return "この差は、数手先の安定して再構成できた範囲で確認できます。"
        }
    }

    private static func timingEvidenceIDs(
        from evidence: [DifferenceEvidence],
        confidence: ComparisonConfidenceResult
    ) -> [String] {
        guard let first = evidence.first(where: {
            claim(for: $0.id, confidence: confidence)?.confidence != .unresolved
        }) else { return [] }
        return [first.id]
    }

    private static func alternativeOutcomeText(
        alternative: CandidateAnalysis,
        allowedEvidence: [DifferenceEvidence],
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence?
    ) -> String? {
        guard let sequence,
              sequence.stableHorizonPly >= 2,
              allowedEvidence.contains(where: { $0.horizon != .immediate }) else { return nil }
        let timeline = timeline(for: alternative, in: sequence)
        let stableSteps = timeline?.steps.filter(\.withinStableHorizon) ?? []
        guard stableSteps.count >= 2 else { return nil }
        let events = stableSteps.dropFirst().prefix(2).compactMap(eventText)
        guard !events.isEmpty else {
            return "別候補を選んだ場合も、同条件のエンジンPVを相手の応手まで追跡できています。ただし、その手順が強制とは限りません。"
        }
        return "別候補のPVでは、\(events.joined(separator: "、"))。これは安定して再構成できた範囲の観測で、強制手順とは限りません。"
    }

    private static func opponentOpportunityText(
        alternative: CandidateAnalysis,
        allowedEvidence: [DifferenceEvidence],
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence?
    ) -> String? {
        let gate = allowedEvidence.contains {
            $0.kind == .opponentReplyDifference
                || $0.kind == .exchangeConsequenceDifference
                || $0.kind == .sequenceEventDifference
        }
        guard gate, let sequence else { return nil }
        let consequences = sequence.opponentConsequences.filter {
            $0.candidateID == alternative.candidateID
                && $0.safeToVerbalize
                && $0.ply <= sequence.stableHorizonPly
        }
        guard let consequence = consequences.first else { return nil }
        let observation: String
        switch consequence.kind {
        case .capture:
            observation = "相手の駒取り"
        case .check:
            observation = "相手からの王手"
        case .promotion:
            observation = "相手の成り"
        case .drop:
            observation = "相手の持駒投入"
        case .recapture:
            observation = "相手の取り返し"
        }
        return "別候補のPVでは、\(observation)が観測されています。PV上の一例であり、その応手が常に強制されるとは断定しません。"
    }

    private static func exchangeAfterText(
        allowedEvidence: [DifferenceEvidence],
        sequence: SequenceComparisonEvidence?
    ) -> String? {
        let gate = allowedEvidence.contains {
            $0.kind == .exchangeConsequenceDifference || $0.kind == .materialDifference
        }
        guard gate, let sequence,
              let exchange = sequence.exchangeEventConsequence,
              exchange.differs,
              exchange.safeToVerbalize else { return nil }
        return "交換を含む安定PVでは、両候補で駒取り・取り返しの流れが異なります。最終的な駒数が同じでも、交換の過程の差は別に残ります。"
    }

    private static func timeline(
        for candidate: CandidateAnalysis,
        in sequence: SequenceComparisonEvidence
    ) -> CounterfactualBranchTimeline? {
        if sequence.candidateATimeline.candidateID == candidate.candidateID {
            return sequence.candidateATimeline
        }
        if sequence.candidateBTimeline.candidateID == candidate.candidateID {
            return sequence.candidateBTimeline
        }
        return nil
    }

    private static func eventText(_ step: CounterfactualTimelineStep) -> String? {
        if step.recapturesPreviousMover { return "取り返しが起きます" }
        if let capture = step.capture { return "駒取り（\(capture)）が起きます" }
        if step.givesCheck { return "王手がかかります" }
        if step.promotes { return "成りが発生します" }
        return nil
    }

    private static func sequenceEligibleEvidenceIDs(_ evidence: [DifferenceEvidence]) -> [String] {
        evidence.filter { $0.horizon != .immediate }.map(\.id)
    }

    private static func headlineText(
        preferred: CandidateAnalysis,
        alternative: CandidateAnalysis,
        comparison: CandidateComparison
    ) -> String {
        if comparison.pairKind == .bestVsActual,
           preferred.branchType == .recommended,
           alternative.branchType == .actual {
            return "推奨手 \(preferred.move) を実戦手 \(alternative.move) より優先する根拠を比較できます。"
        }
        return "\(preferred.move) を \(alternative.move) より優先する具体的な差を比較できます。"
    }

    private static func confidenceText(_ confidence: ComparisonConfidenceLevel) -> String {
        switch confidence {
        case .high:
            return "この比較理由は、同条件の候補比較と具体的な差の両方で強く確認できています。"
        case .medium:
            return "具体的な差は確認できますが、その差を優劣の直接原因とまでは断定しません。"
        case .low:
            return "事実として確認できる差はありますが、比較理由としての確信は低めです。"
        case .unresolved:
            return "エンジン上の順位があっても、候補差の理由は安全に特定できていません。"
        }
    }

    private static func tone(for confidence: ComparisonConfidenceLevel) -> CoachingComparisonTone {
        switch confidence {
        case .high: return .assertive
        case .medium: return .measured
        case .low: return .tentative
        case .unresolved: return .unresolved
        }
    }

    private static func strengthPriority(_ strength: CausalStrength) -> Int {
        switch strength {
        case .directConsequence: return 0
        case .replyLinked: return 1
        case .sequenceCorrelated: return 2
        case .unresolved: return 3
        }
    }

    private static func horizonPriority(_ horizon: ComparisonHorizon) -> Int {
        switch horizon {
        case .immediate: return 0
        case .opponentReply: return 1
        case .ownContinuation: return 2
        case .shortHorizon: return 3
        }
    }

    private static func kindPriority(_ kind: DifferenceKind) -> Int {
        switch kind {
        case .mateStateDifference: return 0
        case .captureDifference: return 1
        case .exchangeConsequenceDifference: return 2
        case .materialDifference: return 3
        case .checkDifference: return 4
        case .promotionDifference: return 5
        case .opponentReplyDifference: return 6
        case .kingSafetyDifference: return 7
        case .boardEffectDifference: return 8
        case .sequenceEventDifference: return 9
        case .scoreDifference: return 10
        case .noGroundedCausalDifference: return 11
        }
    }

    private static func unresolved(
        comparison: CandidateComparison,
        confidence: ComparisonConfidenceResult,
        warnings: [String],
        preferred: CandidateAnalysis? = nil,
        alternative: CandidateAnalysis? = nil
    ) -> CandidateComparisonCoachingExplanation {
        let resolvedPreferred = preferred ?? preferredCandidate(in: comparison)
        let resolvedAlternative = alternative ?? resolvedPreferred.flatMap {
            otherCandidate(than: $0, in: comparison)
        }
        let note = confidenceText(.unresolved)
        var allWarnings = warnings
        allWarnings.append(contentsOf: comparison.unsupportedClaims.map { "unsupported_axis_withheld:\($0)" })
        allWarnings = Array(Set(allWarnings)).sorted()

        return CandidateComparisonCoachingExplanation(
            comparisonID: comparison.comparisonID,
            preferredMove: resolvedPreferred?.move,
            alternativeMove: resolvedAlternative?.move,
            headline: resolvedPreferred.map { "エンジンでは \($0.move) が上位候補ですが、比較理由は未解決です。" }
                ?? "候補の優劣理由は未解決です。",
            primaryReason: "評価値や順位だけでは、なぜ一方が良いのかを安全に説明できません。",
            alternativeOutcome: nil,
            differenceTiming: nil,
            opponentOpportunity: nil,
            exchangeAfter: nil,
            confidenceNote: note,
            confidence: .unresolved,
            tone: .unresolved,
            sections: [
                CoachingComparisonSection(
                    kind: .confidence,
                    text: note,
                    evidenceIDs: [],
                    confidence: .unresolved,
                    causalWordingUsed: false
                )
            ],
            usedEvidenceIDs: [],
            withheldEvidenceIDs: Array(Set(confidence.withheldEvidenceIDs + confidence.eligibleEvidenceIDs)).sorted(),
            warnings: allWarnings
        )
    }
}

public struct ComparisonCoachingExplanationDiagnostic: Codable, Equatable, Sendable {
    public let comparisonID: String
    public let preferredMove: String?
    public let alternativeMove: String?
    public let confidence: String
    public let tone: String
    public let headline: String
    public let primaryReason: String
    public let sections: [CoachingComparisonSection]
    public let usedEvidenceIDs: [String]
    public let withheldEvidenceIDs: [String]
    public let warnings: [String]

    public init(_ explanation: CandidateComparisonCoachingExplanation) {
        comparisonID = explanation.comparisonID
        preferredMove = explanation.preferredMove
        alternativeMove = explanation.alternativeMove
        confidence = explanation.confidence.rawValue
        tone = explanation.tone.rawValue
        headline = explanation.headline
        primaryReason = explanation.primaryReason
        sections = explanation.sections
        usedEvidenceIDs = explanation.usedEvidenceIDs
        withheldEvidenceIDs = explanation.withheldEvidenceIDs
        warnings = explanation.warnings
    }
}

public enum ComparisonCoachingExplanationIsolationContract {
    public static let mutatesMoveIntent = false
    public static let mutatesContextConfidence = false
    public static let mutatesGroundedExplanation = false
    public static let promotesHoldConcepts = false
    public static let usesScoreGapAsCausalReason = false
}
