import Foundation

public enum CandidateAnalysisResolver {
    public struct Input: Equatable, Sendable {
        public let candidateID: String
        public let rank: Int
        public let move: String
        public let score: USIScore
        public let pv: [String]
        public let comparisonStable: Bool
        public let continuationStable: Bool
        public let positionCommand: String
        public let sourceEvidence: [CandidateSourceEvidence]
        public let analysisWarnings: [String]
        public let engineContext: EngineComparisonContext
        public let branchType: CandidateBranchType

        public init(
            candidateID: String,
            rank: Int,
            move: String,
            score: USIScore,
            pv: [String],
            comparisonStable: Bool,
            continuationStable: Bool,
            positionCommand: String,
            sourceEvidence: [CandidateSourceEvidence] = [],
            analysisWarnings: [String] = [],
            engineContext: EngineComparisonContext,
            branchType: CandidateBranchType
        ) {
            self.candidateID = candidateID
            self.rank = rank
            self.move = move
            self.score = score
            self.pv = pv
            self.comparisonStable = comparisonStable
            self.continuationStable = continuationStable
            self.positionCommand = positionCommand
            self.sourceEvidence = sourceEvidence
            self.analysisWarnings = analysisWarnings
            self.engineContext = engineContext
            self.branchType = branchType
        }
    }

    public static func resolve(_ input: Input) throws -> CandidateAnalysis {
        let before = try BoardSnapshotResolver.resolve(positionCommand: input.positionCommand)
        let effect = try MoveEffectResolver.resolve(positionCommand: input.positionCommand, move: input.move)
        let afterCommand = try MoveEffectResolver.appending(move: input.move, to: input.positionCommand)
        let after = try BoardSnapshotResolver.resolve(positionCommand: afterCommand)
        let opponentSide = effect.side == .black ? ShogiSide.white : .black
        let metrics = CandidateBoardMetrics(
            givesCheck: BoardTacticalMetricResolver.isKingInCheck(snapshot: after, checkedSide: opponentSide),
            materialInventory: MaterialInventory.resolve(snapshot: after),
            moverKingZonePressure: BoardTacticalMetricResolver.kingZoneAttackerCount(snapshot: after, checkedSide: effect.side),
            moverKingZoneDefenders: BoardTacticalMetricResolver.kingZoneDefenderCount(snapshot: after, side: effect.side),
            opponentKingZonePressure: BoardTacticalMetricResolver.kingZoneAttackerCount(snapshot: after, checkedSide: opponentSide)
        )

        var warnings = input.analysisWarnings
        if input.pv.first != input.move {
            warnings.append("pv_first_move_mismatch")
        }
        let replyPreview: CandidateReplyPreview?
        do {
            replyPreview = try makeReplyPreview(input: input, firstEffect: effect, afterCommand: afterCommand)
        } catch {
            replyPreview = nil
            warnings.append("reply_preview_unavailable")
        }

        return CandidateAnalysis(
            candidateID: input.candidateID,
            rank: input.rank,
            move: input.move,
            engineScore: CandidateScore(input.score),
            pv: input.pv,
            comparisonStable: input.comparisonStable,
            continuationStable: input.continuationStable,
            firstMoveEffect: effect,
            positionCommand: input.positionCommand,
            positionBefore: before,
            positionAfter: after,
            sourceEvidence: input.sourceEvidence,
            analysisWarnings: warnings,
            engineContext: input.engineContext,
            branchType: input.branchType,
            boardMetrics: metrics,
            opponentReplyPreview: replyPreview
        )
    }

    private static func makeReplyPreview(
        input: Input,
        firstEffect: MoveEffect,
        afterCommand: String
    ) throws -> CandidateReplyPreview? {
        guard input.pv.count >= 2, input.pv.first == input.move else { return nil }
        let reply = input.pv[1]
        let effect = try MoveEffectResolver.resolve(positionCommand: afterCommand, move: reply)
        let afterReplyCommand = try MoveEffectResolver.appending(move: reply, to: afterCommand)
        let afterReply = try BoardSnapshotResolver.resolve(positionCommand: afterReplyCommand)
        let checkedSide = effect.side == .black ? ShogiSide.white : .black
        let givesCheck = BoardTacticalMetricResolver.isKingInCheck(snapshot: afterReply, checkedSide: checkedSide)
        let recaptures = effect.capturedPiece == firstEffect.pieceAfter
            && effect.destination == firstEffect.destination
        return CandidateReplyPreview(
            move: reply,
            effect: effect,
            givesCheck: givesCheck,
            recapturesFirstMover: recaptures
        )
    }
}
