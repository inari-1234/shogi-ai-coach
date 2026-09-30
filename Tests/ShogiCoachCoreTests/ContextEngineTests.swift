import XCTest
@testable import ShogiCoachCore

final class ContextEngineTests: XCTestCase {
    func testRookPawnAdvanceResponseBeatsGeometryFallback() throws {
        let position = "position startpos moves 7g7f 8c8d 6g6f 8d8e"
        let result = try MoveContextEngine.analyze(
            positionCommand: position,
            move: "8h7g"
        )

        XCTAssertEqual(result.selectedIntent, .rookPawnPressureResponse)
        XCTAssertEqual(result.confidence, .medium)
        XCTAssertTrue(
            result.intentCandidates.contains(where: {
                $0.intent == .geometricAttackAdvance && $0.dominantTier == .geometry
            })
        )
        XCTAssertFalse(result.selectedIntent == .geometricAttackAdvance)
        XCTAssertTrue(
            result.facts.contains(where: { $0.kind == .previousRookPawnAdvance })
        )
        XCTAssertTrue(
            result.facts.contains(where: {
                $0.kind == .addedControl && $0.squares.contains("8f")
            })
        )
    }

    func testBishopLineResponseUsesPreviousMoveCausality() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h7g"
        )
        XCTAssertEqual(result.selectedIntent, .bishopLineResponse)
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .captureThreatResponse }))
        XCTAssertTrue(result.facts.contains(where: { $0.kind == .newlyAttackedPiece }))
    }

    func testCaptureProducesExchangeAndAttackContinuationCandidates() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "8h2b+"
        )
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .exchangePreparation }))
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .attackContinuation }))
        XCTAssertTrue(result.effects.contains(where: { $0.kind == .capturesPiece }))
    }

    func testRecaptureIsCausalIntent() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+",
            move: "8b2b"
        )
        XCTAssertEqual(result.selectedIntent, .recapture)
        XCTAssertEqual(result.intentCandidates.first?.dominantTier, .causal)
    }

    func testGivingCheckIsFunctionalIntentWhenNoStrongerContextExists() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 4c4d",
            move: "8h3c+"
        )
        XCTAssertEqual(result.selectedIntent, .forcingCheck)
        XCTAssertTrue(result.facts.contains(where: { $0.kind == .currentGivesCheck }))
    }

    func testCheckEvasionOutranksGenericKingSafety() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 4c4d 8h3c+",
            move: "5a6b"
        )
        XCTAssertEqual(result.selectedIntent, .kingEscape)
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .checkEvasion }))
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .defense }))
        XCTAssertTrue(result.intentCandidates.contains(where: { $0.intent == .kingSafety }))
    }

    func testEarlyKingMoveCanBeClassifiedAsCastleFormation() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d",
            move: "5i6h"
        )
        XCTAssertEqual(result.selectedIntent, .castleFormation)
    }

    func testTenukiRecognizesCounterplayAgainstRookPawnPressure() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h3c+"
        )
        XCTAssertEqual(result.selectedIntent, .tenuki)
        XCTAssertEqual(
            result.contextChanges.first(where: { $0.kind == .rookPawnAdvance })?.response,
            .countered
        )
    }

    func testHandPieceDeploymentRemainsLowConfidenceWithoutPurposeEvidence() throws {
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 8b2b",
            move: "B*5e"
        )
        XCTAssertEqual(result.selectedIntent, .handPieceDeployment)
        XCTAssertEqual(result.confidence, .low)
    }

    func testEngineMateEvidenceCanSelectMatingAttack() throws {
        let engine = ContextEngineEvidence(
            bestMove: "7g7f",
            actualMove: "7g7f",
            actualLossCp: 0,
            comparisonStable: true,
            continuationStable: true,
            semanticTags: [.forcedMate]
        )
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos",
            move: "7g7f",
            engineEvidence: engine
        )
        XCTAssertEqual(result.selectedIntent, .matingAttack)
        XCTAssertEqual(result.intentCandidates.first?.dominantTier, .engine)
    }

    func testMateThreatEngineEvidenceSelectsMateThreat() throws {
        let engine = ContextEngineEvidence(
            bestMove: "7g7f",
            actualMove: "7g7f",
            actualLossCp: 0,
            comparisonStable: true,
            continuationStable: true,
            semanticTags: [.mateThreat]
        )
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos",
            move: "7g7f",
            engineEvidence: engine
        )
        XCTAssertEqual(result.selectedIntent, .mateThreat)
    }

    func testMateThreatResponseEngineEvidenceSelectsResponse() throws {
        let engine = ContextEngineEvidence(
            bestMove: "7g7f",
            actualMove: "7g7f",
            actualLossCp: 0,
            comparisonStable: true,
            continuationStable: true,
            semanticTags: [.mateThreatResponse]
        )
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos",
            move: "7g7f",
            engineEvidence: engine
        )
        XCTAssertEqual(result.selectedIntent, .mateThreatResponse)
    }

    func testCounterfactualOutcomeIsSeparateFromIntent() throws {
        let counterfactual = ContextCounterfactualEvidence(
            alternativeMove: "2g2f",
            evaluationDeltaCp: 80,
            opponentReply: "8c8d",
            stable: true
        )
        let engine = ContextEngineEvidence(
            bestMove: "2g2f",
            actualMove: "7g7f",
            actualLossCp: 80,
            comparisonStable: true,
            continuationStable: true,
            bestPV: ["2g2f", "8c8d"],
            actualPV: ["7g7f", "3c3d"],
            counterfactual: counterfactual
        )
        let result = try MoveContextEngine.analyze(
            positionCommand: "position startpos",
            move: "7g7f",
            engineEvidence: engine
        )
        XCTAssertTrue(result.outcomes.contains(where: { $0.source == .actualPV }))
        XCTAssertTrue(result.outcomes.contains(where: {
            $0.source == .counterfactual && $0.evaluationDeltaCp == 80
        }))
    }

    func testCompactKnowledgeProviderCanRaiseConfidenceWithoutFreeTextGuessing() throws {
        let position = "position startpos moves 7g7f 8c8d 6g6f 8d8e"
        let before = try BoardSnapshotResolver.resolve(positionCommand: position)
        let record = PositionKnowledgeRecord(
            sfen: before.canonicalSFENMain,
            kind: .precedent,
            source: "regression-fixture",
            openingName: nil,
            totalGames: 20,
            candidates: [
                .init(
                    move: "8h7g",
                    gameCount: 12,
                    typicalContinuation: ["8e8f"],
                    intentHints: [.rookPawnPressureResponse]
                )
            ]
        )
        let provider = CompactPositionKnowledgeIndex(records: [record])
        let result = try MoveContextEngine.analyze(
            positionCommand: position,
            move: "8h7g",
            knowledgeProvider: provider
        )
        XCTAssertEqual(result.selectedIntent, .rookPawnPressureResponse)
        XCTAssertEqual(result.confidence, .high)
        XCTAssertEqual(result.knowledgeEvidence?.source, "regression-fixture")
    }

    func testCanonicalSFENIsStableAcrossMoveCounter() throws {
        let snapshot = try BoardSnapshotResolver.resolve(
            positionCommand: "position startpos moves 7g7f 3c3d"
        )
        XCTAssertEqual(
            snapshot.canonicalSFENMain,
            "lnsgkgsnl/1r5b1/pppppp1pp/6p2/9/2P6/PP1PPPPPP/1B5R1/LNSGKGSNL b -"
        )
    }
}
