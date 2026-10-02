import Foundation
import XCTest
@testable import ShogiCoachCore

final class Build18GroundedWhyNowTests: XCTestCase {
    func testLockedRegressionProjectsDirectPreviousMoveWithoutMutatingIntentOrConfidence() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position startpos moves 7g7f 8c8d 2g2f 8d8e",
            move: "8h7g"
        )
        let intentBefore = analysis.selectedIntent
        let confidenceBefore = analysis.confidence
        let context = GroundedExplanationProjector.make(analysis: analysis)
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .directPreviousMove)
        XCTAssertEqual(context.previousMove, "8d8e")
        XCTAssertTrue(context.sourceEvidenceIDs.contains("ev_rook_pawn_response"))
        XCTAssertEqual(context.compatibleIntent, .rookPawnResponse)
        XCTAssertTrue(context.detail.contains("直前"))
        XCTAssertEqual(analysis.selectedIntent, intentBefore)
        XCTAssertEqual(analysis.confidence, confidenceBefore)
        XCTAssertEqual(analysis.selectedIntent, .rookPawnResponse)
        XCTAssertEqual(analysis.confidence, .high)
        XCTAssertTrue(explanation.whyNow.contains("直前"))
    }

    func testExplicitCheckUsesForcingTacticWithoutExpandingBeyondObservedFact() throws {
        let analysis = try MoveContextEngine().analyze(
            positionCommand: "position sfen 4k4/8R/9/9/9/9/8P/9/K8 b - 1",
            move: "1b5b"
        )
        let context = GroundedExplanationProjector.make(analysis: analysis)
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .forcingTactic)
        XCTAssertTrue(context.sourceSignalIDs.contains("gives_check"))
        XCTAssertTrue(context.detail.contains("王手"))
        XCTAssertFalse(context.detail.contains("詰み"))
        XCTAssertFalse(context.detail.contains("詰めろ"))
        XCTAssertFalse(explanation.whyNow.contains("詰み"))
        XCTAssertFalse(explanation.whyNow.contains("詰めろ"))
    }

    func testLowConfidenceFallsBackToTentativeGroundedWhyNow() {
        let analysis = MoveContextAnalysis(
            move: "7g7f",
            previousMove: nil,
            facts: [.init(id: "current_move", kind: .currentMove, detail: "7g7f")],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .development, score: 38, evidenceIDs: ["dev"])],
            selectedIntent: .development,
            confidence: .low,
            evidence: [.init(id: "dev", kind: .boardEffect, detail: "fixture", supportedIntent: .development, weight: 38)]
        )
        let context = GroundedExplanationProjector.make(analysis: analysis)
        let explanation = ContextExplanationGenerator.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .noneIdentified)
        XCTAssertEqual(context.verbalizationMode, .tentative)
        XCTAssertTrue(context.missingEvidence.contains(.noDirectCausalLink))
        XCTAssertTrue(context.missingEvidence.contains(.insufficientScoreMargin))
        XCTAssertTrue(explanation.whyNow.hasPrefix("現時点では"))
        XCTAssertFalse(explanation.whyNow.contains("駒組みの段階"))
    }

    func testUnresolvedGeometryCannotReconstructPreviousMoveOrWhyNow() {
        let analysis = MoveContextAnalysis(
            move: "6i7h",
            previousMove: nil,
            facts: [.init(id: "current_move", kind: .currentMove, detail: "6i7h")],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [],
            selectedIntent: .unresolved,
            confidence: .unresolved,
            evidence: [.init(id: "geo", kind: .geometry, detail: "distance:5->4", supportedIntent: .attackPreparation, weight: 10)]
        )
        let context = GroundedExplanationProjector.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .noneIdentified)
        XCTAssertNil(context.previousMove)
        XCTAssertNil(context.compatibleIntent)
        XCTAssertFalse(context.sourceSignalIDs.contains("previous_move"))
        XCTAssertTrue(context.missingEvidence.contains(.noNonGeometryAnchor))
        XCTAssertEqual(context.verbalizationMode, .uncertaintyOnly)
    }

    func testFutureTriggersStayDisabledWithoutRequiredEvidenceGates() {
        let analysis = MoveContextAnalysis(
            move: "6i7h",
            previousMove: "3c3d",
            facts: [
                .init(id: "previous_move", kind: .previousMove, detail: "3c3d"),
                .init(id: "current_move", kind: .currentMove, detail: "6i7h")
            ],
            contextChanges: [],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .castling, score: 90, evidenceIDs: ["book"])],
            selectedIntent: .castling,
            confidence: .medium,
            evidence: [.init(id: "book", kind: .openingBook, detail: "fixture", supportedIntent: .castling, weight: 90)]
        )
        let context = GroundedExplanationProjector.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .noneIdentified)
        XCTAssertNotEqual(context.trigger, .formationWindow)
        XCTAssertNotEqual(context.trigger, .verifiedSequenceTiming)
        XCTAssertNotEqual(context.trigger, .endgameUrgency)
    }

    func testFrozenDiagnosticCorpusAll360RecordsRemainPolicyCompatible() throws {
        let document = try loadCorpus()
        XCTAssertEqual(document.records.count, 360)
        XCTAssertEqual(Set(document.records.map(\.positionFingerprint)).count, 360)

        let mandatoryMinimums: [String: Int] = [
            "DIRECT_PREVIOUS_MOVE_CAUSALITY": 40,
            "TIMING_MOVE_ORDER": 40,
            "AMBIGUOUS_MULTI_INTENT": 40,
            "EFFECT_INTENT_BOUNDARY": 40,
            "COUNTERFACTUAL_DEMANDING": 30,
            "ENDGAME_FORCING": 40,
            "SHIKENBISHA_DEDICATED": 60,
            "ADVERSARIAL_HUMAN_NATURAL_GEOMETRY_HARD": 60
        ]
        var strataCounts: [String: Int] = [:]

        for record in document.records {
            XCTAssertNotNil(GroundedWhyNowTrigger(rawValue: record.whyNowTrigger), record.positionId)
            XCTAssertFalse(record.forbiddenClaims.isEmpty, record.positionId)
            XCTAssertFalse(record.strata.isEmpty, record.positionId)
            for claim in record.claimTypes {
                XCTAssertNotNil(GroundedClaimType(rawValue: claim), "\(record.positionId): \(claim)")
            }
            for missing in record.missingEvidence {
                XCTAssertNotNil(GroundedMissingEvidenceReason(rawValue: missing), "\(record.positionId): \(missing)")
            }
            if record.whyNowTrigger == GroundedWhyNowTrigger.directPreviousMove.rawValue {
                XCTAssertNotNil(record.previousMove, record.positionId)
            }
            if record.confidence == "LOW" || record.confidence == "UNRESOLVED" {
                XCTAssertNotEqual(record.expectedExplanationScope, "INTENT_WHY_NOW", record.positionId)
            }
            if record.confidence == "UNRESOLVED" {
                XCTAssertFalse(record.claimTypes.contains("INTENT"), record.positionId)
            }
            for stratum in record.strata {
                strataCounts[stratum, default: 0] += 1
            }
        }

        for (stratum, minimum) in mandatoryMinimums {
            XCTAssertGreaterThanOrEqual(strataCounts[stratum, default: 0], minimum, stratum)
        }

        let locked = try XCTUnwrap(document.records.first { $0.sourceType == "LOCKED_REGRESSION" })
        XCTAssertEqual(locked.primaryIntent, MoveIntent.rookPawnResponse.rawValue)
        XCTAssertEqual(locked.confidence, "HIGH")
        XCTAssertEqual(locked.whyNowTrigger, GroundedWhyNowTrigger.directPreviousMove.rawValue)
    }

    private struct DiagnosticCorpus: Decodable {
        let records: [DiagnosticRecord]
    }

    private struct DiagnosticRecord: Decodable {
        let positionId: String
        let positionFingerprint: String
        let previousMove: String?
        let primaryIntent: String
        let confidence: String
        let whyNowTrigger: String
        let missingEvidence: [String]
        let claimTypes: [String]
        let expectedExplanationScope: String
        let forbiddenClaims: [String]
        let strata: [String]
        let sourceType: String
    }

    private func loadCorpus() throws -> DiagnosticCorpus {
        let fileURL = URL(fileURLWithPath: #filePath)
        let root = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let corpusURL = root.appendingPathComponent("Build18/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json")
        let data = try Data(contentsOf: corpusURL)
        return try JSONDecoder().decode(DiagnosticCorpus.self, from: data)
    }
}
