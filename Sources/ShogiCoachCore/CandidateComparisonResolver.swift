import Foundation

public enum CandidateComparisonResolver {
    public static func compare(
        comparisonID: String,
        pairKind: CandidatePairKind,
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        requestedAxes: [ComparisonAxis] = ComparisonAxis.allCases
    ) -> CandidateComparison {
        var warnings = candidateA.analysisWarnings + candidateB.analysisWarnings
        let normalizationIssues = normalizationIssues(candidateA: candidateA, candidateB: candidateB)
        warnings.append(contentsOf: normalizationIssues)
        warnings = Array(Set(warnings)).sorted()

        let stable = candidateA.comparisonStable
            && candidateB.comparisonStable
            && normalizationIssues.isEmpty
        let continuationStable = candidateA.continuationStable && candidateB.continuationStable
        let unsupported = requestedAxes.filter { !supportedAxes.contains($0) }.map(\.rawValue).sorted()

        var shared: [SharedEvidence] = []
        var differences: [DifferenceEvidence] = []
        var future: [FutureDifferenceCandidate] = []
        let sourceIDs = Array(Set(
            candidateA.sourceEvidence.map(\.id) + candidateB.sourceEvidence.map(\.id)
        )).sorted()
        let firstMoves = [candidateA.move, candidateB.move]

        addScoreEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            stable: stable,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            differences: &differences
        )

        addCaptureEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            shared: &shared,
            differences: &differences
        )
        addPromotionEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            shared: &shared,
            differences: &differences
        )
        addCheckEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            shared: &shared,
            differences: &differences
        )
        addDropEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            shared: &shared,
            differences: &differences
        )
        addMaterialEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            differences: &differences
        )
        addKingSafetyEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            sourceIDs: sourceIDs,
            sourceMoves: firstMoves,
            differences: &differences
        )
        addReplyAndExchangeEvidence(
            candidateA: candidateA,
            candidateB: candidateB,
            stable: stable,
            continuationStable: continuationStable,
            sourceIDs: sourceIDs,
            differences: &differences
        )

        future.append(contentsOf: futureCandidates(candidateA: candidateA, candidateB: candidateB))

        let causal = differences.filter {
            $0.kind != .scoreDifference
                && $0.kind != .noGroundedCausalDifference
                && $0.causalStrength != .unresolved
        }
        if causal.isEmpty {
            differences.append(
                DifferenceEvidence(
                    id: "\(comparisonID)-no-grounded-causal-difference",
                    kind: .noGroundedCausalDifference,
                    candidateAValue: "unresolved",
                    candidateBValue: "unresolved",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: firstMoves,
                    horizon: .immediate,
                    causalStrength: .unresolved,
                    safeToVerbalize: true,
                    limitations: ["score_gap_alone_is_not_a_causal_explanation"]
                )
            )
        }

        let immediate = differences.filter { $0.horizon == .immediate }
        let requiresSequence = !future.isEmpty
        let dominant = stable ? selectDominant(differences) : nil
        if !stable {
            warnings.append("comparison_unstable_preference_explanation_suppressed")
        }
        if !continuationStable {
            warnings.append("continuation_unstable_future_claims_require_revalidation")
        }

        let actualMove = [candidateA, candidateB].first { $0.branchType == .actual }?.move
        let recommendedMove = [candidateA, candidateB].first { $0.branchType == .recommended }?.move
        let alternative = [candidateA, candidateB].first {
            $0.branchType == .alternative || $0.branchType == .rankedCandidate
        }?.move

        return CandidateComparison(
            comparisonID: comparisonID,
            pairKind: pairKind,
            candidateA: candidateA,
            candidateB: candidateB,
            actualMove: actualMove,
            recommendedMove: recommendedMove,
            alternativeCandidate: alternative,
            sharedEvidence: shared,
            differenceEvidence: differences,
            immediateDifferences: immediate,
            futureDifferenceCandidates: future,
            dominantDifferenceCandidate: dominant,
            comparisonStable: stable,
            continuationStable: continuationStable,
            requiresSequenceEvidence: requiresSequence,
            unsupportedClaims: unsupported,
            comparisonWarnings: Array(Set(warnings)).sorted()
        )
    }

    private static let supportedAxes: Set<ComparisonAxis> = [
        .evaluation, .capture, .material, .promotion, .check, .mateState,
        .kingSafety, .exchangeConsequence, .opponentReply, .boardEffect, .sequenceEvent
    ]

    private static func normalizationIssues(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis
    ) -> [String] {
        var issues: [String] = []
        if candidateA.positionCommand != candidateB.positionCommand {
            issues.append("different_position")
        }
        if candidateA.engineContext.engineContextID != candidateB.engineContext.engineContextID {
            issues.append("different_engine_context")
        }
        if candidateA.engineContext.searchConditionID != candidateB.engineContext.searchConditionID {
            issues.append("different_search_condition")
        }
        if candidateA.engineContext.scorePerspective != candidateB.engineContext.scorePerspective {
            issues.append("different_score_perspective")
        }
        if candidateA.engineContext.requestedMoveTimeMs != candidateB.engineContext.requestedMoveTimeMs {
            issues.append("different_movetime")
        }
        if candidateA.engineContext.requestedDepth != candidateB.engineContext.requestedDepth {
            issues.append("different_depth")
        }
        return issues
    }

    private static func addScoreEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        stable: Bool,
        sourceIDs: [String],
        sourceMoves: [String],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.engineScore
        let b = candidateB.engineScore
        guard a != b else { return }

        if a.kind != b.kind,
           a.kind == .mateWin || b.kind == .mateWin || a.kind == .mateLoss || b.kind == .mateLoss {
            differences.append(
                DifferenceEvidence(
                    id: "mate-state",
                    kind: .mateStateDifference,
                    candidateAValue: a.text,
                    candidateBValue: b.text,
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves,
                    horizon: .immediate,
                    causalStrength: stable ? .directConsequence : .unresolved,
                    safeToVerbalize: stable,
                    limitations: ["mate_state_is_engine_outcome_not_full_internal_reason"]
                )
            )
        }

        differences.append(
            DifferenceEvidence(
                id: "score",
                kind: .scoreDifference,
                candidateAValue: a.text,
                candidateBValue: b.text,
                sourceEvidenceIDs: sourceIDs,
                sourceMoves: sourceMoves,
                horizon: .immediate,
                causalStrength: .unresolved,
                safeToVerbalize: stable,
                limitations: ["preference_evidence_not_causal_reason"]
            )
        )
    }

    private static func addCaptureEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        shared: inout [SharedEvidence],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.firstMoveEffect.capturedPiece
        let b = candidateB.firstMoveEffect.capturedPiece
        if let a, let b, a == b {
            shared.append(
                SharedEvidence(
                    id: "shared-capture",
                    kind: "CAPTURE_EVENT",
                    value: a.rawValue,
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves
                )
            )
            return
        }
        guard a != b else { return }
        let recaptureGuard = candidateA.opponentReplyPreview?.recapturesFirstMover == true
            || candidateB.opponentReplyPreview?.recapturesFirstMover == true
        differences.append(
            DifferenceEvidence(
                id: "capture",
                kind: .captureDifference,
                candidateAValue: a?.rawValue ?? "none",
                candidateBValue: b?.rawValue ?? "none",
                sourceEvidenceIDs: sourceIDs,
                sourceMoves: sourceMoves,
                horizon: .immediate,
                causalStrength: recaptureGuard ? .unresolved : .directConsequence,
                safeToVerbalize: true,
                limitations: recaptureGuard
                    ? ["immediate_recapture_detected_do_not_treat_as_simple_material_advantage"]
                    : ["capture_event_does_not_explain_full_evaluation_gap"]
            )
        )
    }

    private static func addPromotionEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        shared: inout [SharedEvidence],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.firstMoveEffect.promotes
        let b = candidateB.firstMoveEffect.promotes
        if a && b {
            shared.append(
                SharedEvidence(
                    id: "shared-promotion",
                    kind: "PROMOTION_EVENT",
                    value: "true",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves
                )
            )
        } else if a != b {
            differences.append(
                DifferenceEvidence(
                    id: "promotion",
                    kind: .promotionDifference,
                    candidateAValue: String(a),
                    candidateBValue: String(b),
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves,
                    horizon: .immediate,
                    causalStrength: .directConsequence,
                    safeToVerbalize: true,
                    limitations: ["promotion_event_does_not_explain_full_evaluation_gap"]
                )
            )
        }
    }

    private static func addCheckEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        shared: inout [SharedEvidence],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.boardMetrics.givesCheck
        let b = candidateB.boardMetrics.givesCheck
        if a && b {
            shared.append(
                SharedEvidence(
                    id: "shared-check",
                    kind: "CHECK_STATE",
                    value: "true",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves
                )
            )
        } else if a != b {
            differences.append(
                DifferenceEvidence(
                    id: "check",
                    kind: .checkDifference,
                    candidateAValue: String(a),
                    candidateBValue: String(b),
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves,
                    horizon: .immediate,
                    causalStrength: .directConsequence,
                    safeToVerbalize: true,
                    limitations: ["check_state_does_not_by_itself_explain_score_delta"]
                )
            )
        }
    }

    private static func addDropEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        shared: inout [SharedEvidence],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.firstMoveEffect.isDrop
        let b = candidateB.firstMoveEffect.isDrop
        if a && b {
            shared.append(
                SharedEvidence(
                    id: "shared-drop",
                    kind: "DROP_EVENT",
                    value: "true",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves
                )
            )
        } else if a != b {
            differences.append(
                DifferenceEvidence(
                    id: "drop",
                    kind: .boardEffectDifference,
                    candidateAValue: a ? "drop" : "move",
                    candidateBValue: b ? "drop" : "move",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: sourceMoves,
                    horizon: .immediate,
                    causalStrength: .directConsequence,
                    safeToVerbalize: true,
                    limitations: ["drop_vs_move_is_board_effect_not_full_evaluation_reason"]
                )
            )
        }
    }

    private static func addMaterialEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.boardMetrics.materialInventory
        let b = candidateB.boardMetrics.materialInventory
        guard a != b else { return }
        let recaptureGuard = candidateA.opponentReplyPreview?.recapturesFirstMover == true
            || candidateB.opponentReplyPreview?.recapturesFirstMover == true
        differences.append(
            DifferenceEvidence(
                id: "material",
                kind: .materialDifference,
                candidateAValue: a.signature(),
                candidateBValue: b.signature(),
                sourceEvidenceIDs: sourceIDs,
                sourceMoves: sourceMoves,
                horizon: .immediate,
                causalStrength: recaptureGuard ? .unresolved : .directConsequence,
                safeToVerbalize: true,
                limitations: recaptureGuard
                    ? ["snapshot_material_difference_may_be_neutralized_by_immediate_recapture"]
                    : ["inventory_difference_is_observed_not_weighted_material_evaluation"]
            )
        )
    }

    private static func addKingSafetyEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        sourceIDs: [String],
        sourceMoves: [String],
        differences: inout [DifferenceEvidence]
    ) {
        let a = candidateA.boardMetrics
        let b = candidateB.boardMetrics
        let aValue = "ownPressure=\(a.moverKingZonePressure),ownDefenders=\(a.moverKingZoneDefenders),oppPressure=\(a.opponentKingZonePressure)"
        let bValue = "ownPressure=\(b.moverKingZonePressure),ownDefenders=\(b.moverKingZoneDefenders),oppPressure=\(b.opponentKingZonePressure)"
        guard aValue != bValue else { return }
        differences.append(
            DifferenceEvidence(
                id: "king-safety",
                kind: .kingSafetyDifference,
                candidateAValue: aValue,
                candidateBValue: bValue,
                sourceEvidenceIDs: sourceIDs,
                sourceMoves: sourceMoves,
                horizon: .immediate,
                causalStrength: .directConsequence,
                safeToVerbalize: true,
                limitations: ["defined_metric_difference_not_full_engine_reason"]
            )
        )
    }

    private static func addReplyAndExchangeEvidence(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis,
        stable: Bool,
        continuationStable: Bool,
        sourceIDs: [String],
        differences: inout [DifferenceEvidence]
    ) {
        let aReply = candidateA.opponentReplyPreview
        let bReply = candidateB.opponentReplyPreview
        let safe = stable && continuationStable

        if aReply?.recapturesFirstMover == true || bReply?.recapturesFirstMover == true {
            differences.append(
                DifferenceEvidence(
                    id: "exchange-consequence",
                    kind: .exchangeConsequenceDifference,
                    candidateAValue: aReply?.recapturesFirstMover == true ? "immediate_recapture" : "no_immediate_recapture_observed",
                    candidateBValue: bReply?.recapturesFirstMover == true ? "immediate_recapture" : "no_immediate_recapture_observed",
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: [candidateA.move, aReply?.move, candidateB.move, bReply?.move].compactMap { $0 },
                    horizon: .opponentReply,
                    causalStrength: safe ? .replyLinked : .unresolved,
                    safeToVerbalize: safe,
                    limitations: ["two_ply_exchange_fact_only_deeper_consequence_deferred_to_build19_2"]
                )
            )
        }

        if let aReply, let bReply, replySignature(aReply) != replySignature(bReply) {
            differences.append(
                DifferenceEvidence(
                    id: "opponent-reply",
                    kind: .opponentReplyDifference,
                    candidateAValue: replySignature(aReply),
                    candidateBValue: replySignature(bReply),
                    sourceEvidenceIDs: sourceIDs,
                    sourceMoves: [candidateA.move, aReply.move, candidateB.move, bReply.move],
                    horizon: .opponentReply,
                    causalStrength: safe ? .replyLinked : .unresolved,
                    safeToVerbalize: safe,
                    limitations: ["first_reply_event_only_full_sequence_interpretation_deferred_to_build19_2"]
                )
            )
        }
    }

    private static func futureCandidates(
        candidateA: CandidateAnalysis,
        candidateB: CandidateAnalysis
    ) -> [FutureDifferenceCandidate] {
        var result: [FutureDifferenceCandidate] = []
        let aReply = candidateA.opponentReplyPreview
        let bReply = candidateB.opponentReplyPreview

        if aReply?.recapturesFirstMover == true || bReply?.recapturesFirstMover == true {
            let moves = [candidateA.move, aReply?.move, candidateB.move, bReply?.move].compactMap { $0 }
            result.append(
                FutureDifferenceCandidate(
                    id: "reply-recapture",
                    horizon: .opponentReply,
                    reason: .immediateRecaptureDetected,
                    sourceMoves: moves
                )
            )
        }

        if let aReply, let bReply {
            let aSignature = replySignature(aReply)
            let bSignature = replySignature(bReply)
            if aSignature != bSignature {
                result.append(
                    FutureDifferenceCandidate(
                        id: "reply-events",
                        horizon: .opponentReply,
                        reason: .opponentReplyEventsDiffer,
                        sourceMoves: [candidateA.move, aReply.move, candidateB.move, bReply.move]
                    )
                )
            }
        }

        if candidateA.pv.dropFirst() != candidateB.pv.dropFirst() {
            result.append(
                FutureDifferenceCandidate(
                    id: "continuation-differs",
                    horizon: .shortHorizon,
                    reason: .continuationDiffers,
                    sourceMoves: Array(candidateA.pv.prefix(3)) + Array(candidateB.pv.prefix(3))
                )
            )
        }

        if !candidateA.continuationStable || !candidateB.continuationStable {
            result.append(
                FutureDifferenceCandidate(
                    id: "continuation-unstable",
                    horizon: .shortHorizon,
                    reason: .continuationUnstable,
                    sourceMoves: Array(candidateA.pv.prefix(3)) + Array(candidateB.pv.prefix(3))
                )
            )
        }
        return uniqueFuture(result)
    }

    private static func replySignature(_ reply: CandidateReplyPreview) -> String {
        [
            reply.effect.capturedPiece?.rawValue ?? "none",
            String(reply.effect.promotes),
            String(reply.effect.isDrop),
            String(reply.givesCheck),
            String(reply.recapturesFirstMover)
        ].joined(separator: "|")
    }

    private static func uniqueFuture(_ values: [FutureDifferenceCandidate]) -> [FutureDifferenceCandidate] {
        var seen = Set<String>()
        return values.filter { seen.insert($0.id).inserted }
    }

    private static func selectDominant(_ differences: [DifferenceEvidence]) -> DifferenceEvidence? {
        let eligible = differences.filter {
            $0.safeToVerbalize
                && $0.kind != .scoreDifference
                && $0.kind != .noGroundedCausalDifference
                && $0.causalStrength != .unresolved
        }
        return eligible.sorted {
            let left = priority($0)
            let right = priority($1)
            if left != right { return left > right }
            return $0.id < $1.id
        }.first
    }

    private static func priority(_ evidence: DifferenceEvidence) -> Int {
        switch evidence.kind {
        case .mateStateDifference: return 100
        case .exchangeConsequenceDifference: return 90
        case .materialDifference: return 80
        case .captureDifference: return 70
        case .checkDifference: return 60
        case .promotionDifference: return 50
        case .opponentReplyDifference: return 45
        case .kingSafetyDifference: return 40
        case .boardEffectDifference: return 30
        case .sequenceEventDifference: return 20
        case .scoreDifference, .noGroundedCausalDifference: return 0
        }
    }
}
