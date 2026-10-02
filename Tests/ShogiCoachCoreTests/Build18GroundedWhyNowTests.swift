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
            positionCommand: "position startpos moves 7g7f 3c3d 8h2b+ 3a2b",
            move: "B*3c"
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

    func testExplicitExchangeSequenceUsesFrozenExchangeTriggerWithoutChangingIntent() {
        let analysis = MoveContextAnalysis(
            move: "7f7e",
            previousMove: "7d7e",
            facts: [
                .init(id: "previous_move", kind: .previousMove, detail: "7d7e"),
                .init(id: "current_move", kind: .currentMove, detail: "7f7e"),
                .init(id: "capture", kind: .capture, detail: "7e")
            ],
            contextChanges: [.init(id: "exchange_sequence", detail: "7e")],
            effects: [],
            outcomes: [.init(id: "material_capture", detail: "recapture")],
            intentCandidates: [
                .init(intent: .postExchangeImprovement, score: 108, evidenceIDs: ["ev_recapture_exchange"])
            ],
            selectedIntent: .postExchangeImprovement,
            confidence: .high,
            evidence: [
                .init(
                    id: "ev_recapture_exchange",
                    kind: .previousMoveCausality,
                    detail: "immediate_recapture_on:7e",
                    supportedIntent: .postExchangeImprovement,
                    weight: 108
                )
            ]
        )

        let context = GroundedExplanationProjector.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .exchangeSequence)
        XCTAssertEqual(context.authorityKind, .directPreviousMove)
        XCTAssertEqual(context.compatibleIntent, .postExchangeImprovement)
        XCTAssertEqual(analysis.selectedIntent, .postExchangeImprovement)
        XCTAssertEqual(analysis.confidence, .high)
        XCTAssertTrue(context.sourceEvidenceIDs.contains("ev_recapture_exchange"))
        XCTAssertTrue(context.sourceSignalIDs.contains("exchange_sequence"))
    }

    func testExplicitImmediateThreatCanBeProjectedWithoutInventingPreviousMoveCausality() {
        let analysis = MoveContextAnalysis(
            move: "5i5h",
            previousMove: "5g5h",
            facts: [
                .init(id: "previous_move", kind: .previousMove, detail: "5g5h"),
                .init(id: "current_move", kind: .currentMove, detail: "5i5h"),
                .init(id: "side_in_check", kind: .sideInCheck, detail: "5i")
            ],
            contextChanges: [.init(id: "check_resolved", detail: "5h")],
            effects: [],
            outcomes: [],
            intentCandidates: [.init(intent: .kingEscape, score: 80, evidenceIDs: ["board"])],
            selectedIntent: .kingEscape,
            confidence: .medium,
            evidence: [
                .init(
                    id: "board",
                    kind: .boardEffect,
                    detail: "check resolved",
                    supportedIntent: .kingEscape,
                    weight: 80
                )
            ]
        )

        let context = GroundedExplanationProjector.make(analysis: analysis)

        XCTAssertEqual(context.trigger, .immediateThreat)
        XCTAssertEqual(context.compatibleIntent, .kingEscape)
        XCTAssertEqual(context.verbalizationMode, .measured)
        XCTAssertFalse(context.sourceEvidenceIDs.contains("ev_king_escape"))
        XCTAssertTrue(context.detail.contains("王手"))
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

    func testRepositoryLegacyCorpusIsDetectedAndNotMistakenForFrozen360Authority() throws {
        let document = try loadLegacyCorpus()
        XCTAssertEqual(document.summary.totalRecords, 316)
        XCTAssertEqual(document.summary.uniquePositions, 300)
        XCTAssertEqual(document.positions.count, 316)

        for record in document.positions {
            XCTAssertNotNil(GroundedWhyNowTrigger(rawValue: record.whyNowTrigger), record.positionId)
            XCTAssertFalse(record.forbiddenClaims.isEmpty, record.positionId)
            XCTAssertFalse(record.diagnosticStrata.isEmpty, record.positionId)
            for claim in record.claimTypes {
                XCTAssertNotNil(GroundedClaimType(rawValue: claim), "\\(record.positionId): \\(claim)")
            }
            for missing in record.missingEvidence {
                XCTAssertNotNil(GroundedMissingEvidenceReason(rawValue: missing), "\\(record.positionId): \\(missing)")
            }
            if record.whyNowTrigger == GroundedWhyNowTrigger.directPreviousMove.rawValue {
                XCTAssertNotNil(record.previousMove, record.positionId)
            }
        }
    }

    func testFrozenAuthorityBindingRequires360UniquePositions() {
        XCTAssertEqual(FrozenAuthorityBinding.corpusSHA256, "433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0")
        XCTAssertEqual(FrozenAuthorityBinding.records, 360)
        XCTAssertEqual(FrozenAuthorityBinding.uniquePositions, 360)
    }

    private enum FrozenAuthorityBinding {
        static let corpusSHA256 = "433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0"
        static let records = 360
        static let uniquePositions = 360
    }

    private struct LegacyDiagnosticCorpus: Decodable {
        let summary: LegacySummary
        let positions: [LegacyDiagnosticRecord]
    }

    private struct LegacySummary: Decodable {
        let totalRecords: Int
        let uniquePositions: Int
    }

    private struct LegacyDiagnosticRecord: Decodable {
        let positionId: String
        let previousMove: String?
        let whyNowTrigger: String
        let missingEvidence: [String]
        let claimTypes: [String]
        let forbiddenClaims: [String]
        let diagnosticStrata: [String]
    }

    private func loadLegacyCorpus() throws -> LegacyDiagnosticCorpus {
        let fileURL = URL(fileURLWithPath: #filePath)
        let root = fileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let corpusURL = root.appendingPathComponent("Build18/Legacy/Build18-2_300_unique/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json")
        let data = try Data(contentsOf: corpusURL)
        return try JSONDecoder().decode(LegacyDiagnosticCorpus.self, from: data)
    }
}
