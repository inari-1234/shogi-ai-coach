import Foundation
import XCTest
@testable import ShogiCoachCore

final class Build18FrozenCorpusProjectionTests: XCTestCase {
    func testFrozen360ProjectionExpectations() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let corpusURL = repositoryRoot
            .appendingPathComponent("Build18")
            .appendingPathComponent("BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json")

        let data = try Data(contentsOf: corpusURL)
        let document = try JSONDecoder().decode(FrozenCorpusDocument.self, from: data)

        XCTAssertEqual(document.baselineMainSHA, "fd35c8b990379ebccbf1711d1cc0fa4a8464d53d")
        XCTAssertEqual(document.build18_1_specificationHEAD, "ea37b850c72fd07b328adbd046892b647edf8c2f")
        XCTAssertEqual(document.records.count, 360)

        var triggerCounts: [GroundedWhyNowTrigger: Int] = [:]

        for record in document.records {
            let intent = try XCTUnwrap(MoveIntent(rawValue: record.primaryIntent), record.positionId)
            let confidence = try XCTUnwrap(confidence(fromFrozen: record.confidence), record.positionId)
            let expectedTrigger = try XCTUnwrap(
                GroundedWhyNowTrigger(rawValue: record.whyNowTrigger),
                record.positionId
            )

            var facts = [
                ContextFact(
                    id: "current_move",
                    kind: .currentMove,
                    detail: record.currentMove
                )
            ]
            if let previousMove = record.previousMove {
                facts.append(
                    .init(
                        id: "previous_move",
                        kind: .previousMove,
                        detail: previousMove
                    )
                )
            }

            let givesCheck = record.diagnosticInspection?.givesCheck ?? false
            if givesCheck {
                facts.append(
                    .init(
                        id: "check",
                        kind: .check,
                        detail: "frozen corpus explicit check"
                    )
                )
            }

            let effects: [ContextSignal] = givesCheck
                ? [.init(id: "gives_check", detail: "frozen corpus explicit check")]
                : []

            let evidenceKinds = Set(record.traceDetails.supportingEvidence.map(\.kind))
            var evidence: [ContextEvidence] = []
            if evidenceKinds.contains(ContextEvidenceKind.previousMoveCausality.rawValue) {
                evidence.append(
                    .init(
                        id: "frozen_previous_move_causality",
                        kind: .previousMoveCausality,
                        detail: "frozen corpus direct-causality authority",
                        supportedIntent: intent,
                        weight: 100
                    )
                )
            }

            let candidates: [IntentCandidate] = intent == .unresolved
                ? []
                : [
                    .init(
                        intent: intent,
                        score: 100,
                        evidenceIDs: evidence.map(\.id)
                    )
                ]

            let analysis = MoveContextAnalysis(
                move: record.currentMove,
                previousMove: record.previousMove,
                facts: facts,
                contextChanges: [],
                effects: effects,
                outcomes: [],
                intentCandidates: candidates,
                selectedIntent: intent,
                confidence: confidence,
                evidence: evidence
            )

            let projected = GroundedExplanationProjector.make(analysis: analysis)

            XCTAssertEqual(projected.trigger, expectedTrigger, record.positionId)
            XCTAssertEqual(analysis.selectedIntent, intent, record.positionId)
            XCTAssertEqual(analysis.confidence, confidence, record.positionId)

            if confidence == .unresolved {
                XCTAssertNil(projected.compatibleIntent, record.positionId)
                XCTAssertNotEqual(projected.verbalizationMode, .assertive, record.positionId)
            }

            if expectedTrigger == .directPreviousMove {
                XCTAssertNotNil(projected.previousMove, record.positionId)
                XCTAssertTrue(
                    projected.sourceEvidenceIDs.contains("frozen_previous_move_causality"),
                    record.positionId
                )
            }

            triggerCounts[projected.trigger, default: 0] += 1
        }

        XCTAssertEqual(triggerCounts[.directPreviousMove], 60)
        XCTAssertEqual(triggerCounts[.forcingTactic], 50)
        XCTAssertEqual(triggerCounts[.noneIdentified], 250)
        XCTAssertEqual(triggerCounts.values.reduce(0, +), 360)
    }

    private func confidence(fromFrozen raw: String) -> ContextConfidence? {
        switch raw {
        case "HIGH": return .high
        case "MEDIUM": return .medium
        case "LOW": return .low
        case "UNRESOLVED": return .unresolved
        default: return nil
        }
    }

    private struct FrozenCorpusDocument: Decodable {
        let baselineMainSHA: String
        let build18_1_specificationHEAD: String
        let records: [FrozenRecord]
    }

    private struct FrozenRecord: Decodable {
        let positionId: String
        let previousMove: String?
        let currentMove: String
        let primaryIntent: String
        let confidence: String
        let whyNowTrigger: String
        let traceDetails: TraceDetails
        let diagnosticInspection: DiagnosticInspection?
    }

    private struct TraceDetails: Decodable {
        let supportingEvidence: [SupportingEvidence]
    }

    private struct SupportingEvidence: Decodable {
        let kind: String
    }

    private struct DiagnosticInspection: Decodable {
        let givesCheck: Bool?
    }
}
