import Foundation

public enum CoachingComparisonPresentationMode: String, Codable, Equatable, Sendable {
    case standard = "STANDARD"
    case continuity = "CONTINUITY"
    case suppressedDuplicate = "SUPPRESSED_DUPLICATE"
}

public struct CoachingComparisonPresentation: Codable, Equatable, Sendable {
    public let mode: CoachingComparisonPresentationMode
    public let semanticExplanation: CandidateComparisonCoachingExplanation
    public let displayedExplanation: CandidateComparisonCoachingExplanation?
    public let semanticSignature: String
    public let equivalentRunLength: Int
    public let resetReasons: [String]

    public init(
        mode: CoachingComparisonPresentationMode,
        semanticExplanation: CandidateComparisonCoachingExplanation,
        displayedExplanation: CandidateComparisonCoachingExplanation?,
        semanticSignature: String,
        equivalentRunLength: Int,
        resetReasons: [String]
    ) {
        self.mode = mode
        self.semanticExplanation = semanticExplanation
        self.displayedExplanation = displayedExplanation
        self.semanticSignature = semanticSignature
        self.equivalentRunLength = equivalentRunLength
        self.resetReasons = resetReasons
    }
}

/// Presentation-only repetition control for Build19 pairwise coaching.
///
/// The semantic explanation is always generated in full first. This state decides only
/// whether that already-authorized explanation should be shown in full, condensed once,
/// or omitted after repeated equivalent comparison semantics.
public struct ComparisonCoachingExplanationRepetitionState: Sendable {
    private struct Signature: Equatable, Sendable {
        let pairKind: String
        let confidence: String
        let tone: String
        let framing: String
        let evidenceShape: [String]
        let sectionKinds: [String]
        let futureShape: String

        var serialized: String {
            [
                "pair=\(pairKind)",
                "confidence=\(confidence)",
                "tone=\(tone)",
                "framing=\(framing)",
                "evidence=\(evidenceShape.joined(separator: ","))",
                "sections=\(sectionKinds.joined(separator: ","))",
                "future=\(futureShape)"
            ].joined(separator: "|")
        }

        func resetReasons(comparedWith previous: Signature) -> [String] {
            var reasons: [String] = []
            if pairKind != previous.pairKind { reasons.append("PAIR_KIND_CHANGED") }
            if confidence != previous.confidence { reasons.append("COMPARISON_CONFIDENCE_CHANGED") }
            if tone != previous.tone { reasons.append("EXPLANATION_TONE_CHANGED") }
            if framing != previous.framing { reasons.append("COMPARISON_FRAMING_CHANGED") }
            if evidenceShape != previous.evidenceShape { reasons.append("AUTHORIZED_EVIDENCE_CHANGED") }
            if sectionKinds != previous.sectionKinds { reasons.append("VISIBLE_SECTION_KIND_CHANGED") }
            if futureShape != previous.futureShape { reasons.append("FUTURE_EVIDENCE_SHAPE_CHANGED") }
            return reasons
        }
    }

    private var previousSignature: Signature?
    private var equivalentRunLength = 0

    public init() {}

    public mutating func reset() {
        previousSignature = nil
        equivalentRunLength = 0
    }

    public mutating func present(
        comparison: CandidateComparison,
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence? = nil
    ) -> CoachingComparisonPresentation {
        let semantic = ComparisonCoachingExplanationResolver.resolve(
            comparison: comparison,
            confidence: confidence,
            sequence: sequence
        )
        let signature = Self.signature(
            comparison: comparison,
            confidence: confidence,
            sequence: sequence,
            explanation: semantic
        )

        let mode: CoachingComparisonPresentationMode
        let displayed: CandidateComparisonCoachingExplanation?
        let resetReasons: [String]

        if let previousSignature, previousSignature == signature {
            equivalentRunLength += 1
            resetReasons = []
            if equivalentRunLength == 2 {
                mode = .continuity
                displayed = Self.continuityExplanation(from: semantic)
            } else {
                mode = .suppressedDuplicate
                displayed = nil
            }
        } else {
            resetReasons = previousSignature.map { signature.resetReasons(comparedWith: $0) } ?? ["INITIAL"]
            previousSignature = signature
            equivalentRunLength = 1
            mode = .standard
            displayed = semantic
        }

        return CoachingComparisonPresentation(
            mode: mode,
            semanticExplanation: semantic,
            displayedExplanation: displayed,
            semanticSignature: signature.serialized,
            equivalentRunLength: equivalentRunLength,
            resetReasons: resetReasons
        )
    }

    private static func signature(
        comparison: CandidateComparison,
        confidence: ComparisonConfidenceResult,
        sequence: SequenceComparisonEvidence?,
        explanation: CandidateComparisonCoachingExplanation
    ) -> Signature {
        let used = Set(explanation.usedEvidenceIDs)
        let evidenceShape = comparison.differenceEvidence
            .filter { used.contains($0.id) }
            .map { evidence in
                let claim = confidence.claimAssessments.first { $0.evidenceID == evidence.id }
                return [
                    evidence.kind.rawValue,
                    evidence.horizon.rawValue,
                    evidence.causalStrength.rawValue,
                    claim?.confidence.rawValue ?? "-",
                    claim?.eligibleForCausalWording == true ? "causal" : "noncausal"
                ].joined(separator: ":")
            }
            .sorted()

        let framing = [comparison.candidateA.branchType, comparison.candidateB.branchType]
            .map(Self.branchTypeText)
            .sorted()
            .joined(separator: "+")

        let futureShape = [
            explanation.alternativeOutcome == nil ? "no-alt-outcome" : "alt-outcome",
            explanation.opponentOpportunity == nil ? "no-opponent-opportunity" : "opponent-opportunity",
            explanation.exchangeAfter == nil ? "no-exchange-after" : "exchange-after",
            sequence.map { "stable-ply-\($0.stableHorizonPly)" } ?? "no-sequence"
        ].joined(separator: ":")

        return Signature(
            pairKind: comparison.pairKind.rawValue,
            confidence: explanation.confidence.rawValue,
            tone: explanation.tone.rawValue,
            framing: framing,
            evidenceShape: evidenceShape,
            sectionKinds: explanation.sections.map { $0.kind.rawValue },
            futureShape: futureShape
        )
    }

    private static func branchTypeText(_ branch: CandidateBranchType) -> String {
        switch branch {
        case .recommended: return "recommended"
        case .actual: return "actual"
        case .alternative: return "alternative"
        case .rankedCandidate: return "ranked"
        }
    }

    private static func continuityExplanation(
        from semantic: CandidateComparisonCoachingExplanation
    ) -> CandidateComparisonCoachingExplanation {
        let grounded = semantic.sections.first { $0.kind == .groundedDifference }
        let confidenceSection = semantic.sections.last { $0.kind == .confidence }
        let sections = [grounded, confidenceSection].compactMap { $0 }
        var warnings = semantic.warnings
        warnings.append("comparison_repetition_continuity_presentation")
        warnings = Array(Set(warnings)).sorted()

        return CandidateComparisonCoachingExplanation(
            comparisonID: semantic.comparisonID,
            preferredMove: semantic.preferredMove,
            alternativeMove: semantic.alternativeMove,
            headline: semantic.confidence == .unresolved
                ? "前の比較と同様、候補差の理由を断定できる新しい根拠はありません。"
                : "前の比較と同じ種類の根拠が続いています。",
            primaryReason: semantic.primaryReason,
            alternativeOutcome: nil,
            differenceTiming: nil,
            opponentOpportunity: nil,
            exchangeAfter: nil,
            confidenceNote: semantic.confidenceNote,
            confidence: semantic.confidence,
            tone: semantic.tone,
            sections: sections,
            usedEvidenceIDs: semantic.usedEvidenceIDs,
            withheldEvidenceIDs: semantic.withheldEvidenceIDs,
            warnings: warnings
        )
    }
}

public enum ComparisonCoachingExplanationRepetitionIsolationContract {
    public static let mutatesSemanticExplanation = false
    public static let mutatesMoveIntent = false
    public static let mutatesContextConfidence = false
    public static let promotesHoldConcepts = false
}
