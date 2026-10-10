import Foundation

// Compatibility initializer for frozen historical diagnostic fixtures only.
// It deliberately does not manufacture VE1-B node-search evidence for records
// created before the VE1-B evidence contract existed.
extension DeepAnalysisEntry {
    init(
        id: Int,
        ply: Int,
        actualMove: String,
        shallowBestMove: String,
        shallowEstimatedLossCp: Int?,
        bestMove: String,
        bestScoreText: String,
        actualScoreText: String,
        actualLossCp: Int?,
        bestPV: String,
        actualPV: String,
        actualAnalysisSource: String,
        opponentBestReply: String,
        candidates: [DeepCandidateLine],
        elapsedMs: Int,
        thermalBefore: String,
        thermalAfter: String,
        comparisonStable: Bool,
        instabilityReasons: [String],
        continuationStable: Bool,
        continuationInstabilityReasons: [String],
        analysisAttempts: Int,
        finalMovetimeMs: Int,
        adaptiveTriggered: Bool,
        topCandidateGapCp: Int?
    ) {
        self.init(
            id: id,
            ply: ply,
            actualMove: actualMove,
            shallowBestMove: shallowBestMove,
            shallowEstimatedLossCp: shallowEstimatedLossCp,
            bestMove: bestMove,
            bestScoreText: bestScoreText,
            actualScoreText: actualScoreText,
            actualLossCp: actualLossCp,
            bestPV: bestPV,
            actualPV: actualPV,
            actualAnalysisSource: actualAnalysisSource,
            opponentBestReply: opponentBestReply,
            candidates: candidates,
            elapsedMs: elapsedMs,
            thermalBefore: thermalBefore,
            thermalAfter: thermalAfter,
            comparisonStable: comparisonStable,
            instabilityReasons: instabilityReasons,
            continuationStable: continuationStable,
            continuationInstabilityReasons: continuationInstabilityReasons,
            analysisAttempts: analysisAttempts,
            finalMovetimeMs: finalMovetimeMs,
            adaptiveTriggered: adaptiveTriggered,
            topCandidateGapCp: topCandidateGapCp,
            stabilityState: "historical_fixture",
            confirmedBestPVPlyCount: 0,
            confirmedActualPVPlyCount: 0,
            nodePolicyAuthorityStatus: "HISTORICAL_DIAGNOSTIC_FIXTURE",
            candidateDiscoveryNodes: 0,
            confirmationNodeTiers: [],
            safetyCeilingMs: 0,
            finalNodeBudget: 0,
            searchEvidence: []
        )
    }
}
