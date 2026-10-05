import Foundation
import XCTest
@testable import ShogiCoachCore

#if canImport(Compression)
import Compression
#endif

final class Build18FrozenCorpusProjectionTests: XCTestCase {
    func testFrozen360AuthorityProjectionAndSafetyGates() throws {
        #if canImport(Compression)
        let rows = try loadRows()
        XCTAssertEqual(rows.count, 360)

        var triggerCounts: [GroundedWhyNowTrigger: Int] = [:]
        var confidenceCounts: [ContextConfidence: Int] = [:]
        var scopeCounts: [String: Int] = [:]
        var shikenbishaCount = 0
        var effectBoundaryCount = 0
        var forbiddenViolationCount = 0

        for row in rows {
            XCTAssertEqual(row.count, 19)
            let positionID = try XCTUnwrap(row[0] as? String)
            let previousMove = row[1] is NSNull ? nil : row[1] as? String
            let currentMove = try XCTUnwrap(row[2] as? String)
            let intentRaw = try XCTUnwrap(row[3] as? String)
            let confidenceRaw = try XCTUnwrap(row[4] as? String)
            let expectedTriggerRaw = try XCTUnwrap(row[5] as? String)
            let givesCheck = try XCTUnwrap(row[6] as? Bool)
            let evidenceKinds = try XCTUnwrap(row[7] as? [String])
            let signalLayers = try XCTUnwrap(row[8] as? [String])
            let claimTypes = try XCTUnwrap(row[9] as? [String])
            let expectedScope = try XCTUnwrap(row[10] as? String)
            let forbiddenClaims = try XCTUnwrap(row[11] as? [String])
            let strata = try XCTUnwrap(row[12] as? [String])
            let specializedRequired = try XCTUnwrap(row[13] as? Bool)
            let specializedStatus = try XCTUnwrap(row[14] as? String)
            let missingEvidence = try XCTUnwrap(row[15] as? [String])
            let requiredFieldsPresent = try XCTUnwrap(row[16] as? Bool)
            let annotationStatus = try XCTUnwrap(row[17] as? String)
            let crossReviewStatus = try XCTUnwrap(row[18] as? String)

            XCTAssertTrue(requiredFieldsPresent, positionID)
            XCTAssertEqual(annotationStatus, "CONFIRMED", positionID)
            XCTAssertEqual(crossReviewStatus, "PASS", positionID)
            XCTAssertFalse(forbiddenClaims.isEmpty, positionID)
            XCTAssertTrue(signalLayers.allSatisfy { ["FACT", "CONTEXT_CHANGE", "EFFECT"].contains($0) }, positionID)
            for claim in claimTypes {
                XCTAssertNotNil(GroundedClaimType(rawValue: claim), "\(positionID): \(claim)")
            }
            for missing in missingEvidence {
                XCTAssertNotNil(GroundedMissingEvidenceReason(rawValue: missing), "\(positionID): \(missing)")
            }

            let intent = try XCTUnwrap(MoveIntent(rawValue: intentRaw), positionID)
            let confidence = try XCTUnwrap(confidence(fromFrozen: confidenceRaw), positionID)
            let expectedTrigger = try XCTUnwrap(GroundedWhyNowTrigger(rawValue: expectedTriggerRaw), positionID)

            var facts = [ContextFact(id: "current_move", kind: .currentMove, detail: currentMove)]
            if let previousMove {
                facts.append(.init(id: "previous_move", kind: .previousMove, detail: previousMove))
            }
            if givesCheck {
                facts.append(.init(id: "check", kind: .check, detail: "frozen corpus explicit check"))
            }

            var effects: [ContextSignal] = givesCheck
                ? [.init(id: "gives_check", detail: "frozen corpus explicit check")]
                : []
            if signalLayers.contains("EFFECT") {
                effects.append(.init(id: "frozen_effect", detail: "effect-layer observation only"))
            }

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
                : [.init(intent: intent, score: 100, evidenceIDs: evidence.map(\.id))]

            let analysis = MoveContextAnalysis(
                move: currentMove,
                previousMove: previousMove,
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

            XCTAssertEqual(projected.trigger, expectedTrigger, positionID)
            XCTAssertEqual(analysis.selectedIntent, intent, positionID)
            XCTAssertEqual(analysis.confidence, confidence, positionID)

            if expectedTrigger == .directPreviousMove {
                XCTAssertNotNil(projected.previousMove, positionID)
                XCTAssertTrue(projected.sourceEvidenceIDs.contains("frozen_previous_move_causality"), positionID)
            }

            if confidence == .low || confidence == .unresolved {
                if projected.verbalizationMode == .assertive { forbiddenViolationCount += 1 }
            }
            if intent == .unresolved, projected.compatibleIntent != nil {
                forbiddenViolationCount += 1
            }
            if forbiddenClaims.contains("EFFECT_TO_INTENT_PROMOTION"),
               intent == .unresolved,
               signalLayers.contains("EFFECT"),
               projected.compatibleIntent != nil {
                forbiddenViolationCount += 1
            }
            if forbiddenClaims.contains("FALSE_PREVIOUS_MOVE_CAUSALITY"),
               projected.trigger == .directPreviousMove,
               !evidenceKinds.contains(ContextEvidenceKind.previousMoveCausality.rawValue) {
                forbiddenViolationCount += 1
            }
            if forbiddenClaims.contains("FICTITIOUS_MATE_OR_THREATMATE"),
               projected.detail.contains("詰み") || projected.detail.contains("詰めろ") {
                forbiddenViolationCount += 1
            }
            if forbiddenClaims.contains("UNSUPPORTED_SPECIALIZED_STRATEGY_LABEL"),
               projected.trigger == .formationWindow {
                forbiddenViolationCount += 1
            }

            if strata.contains("SHIKENBISHA_DEDICATED") {
                shikenbishaCount += 1
                XCTAssertTrue(specializedRequired, positionID)
                XCTAssertEqual(specializedStatus, "UNVERIFIED", positionID)
                XCTAssertEqual(projected.trigger, .noneIdentified, positionID)
                XCTAssertNil(projected.compatibleIntent, positionID)
                XCTAssertNotEqual(projected.verbalizationMode, .assertive, positionID)
            }
            if strata.contains("EFFECT_INTENT_BOUNDARY") {
                effectBoundaryCount += 1
            }

            triggerCounts[projected.trigger, default: 0] += 1
            confidenceCounts[confidence, default: 0] += 1
            scopeCounts[expectedScope, default: 0] += 1
        }

        XCTAssertEqual(triggerCounts[.directPreviousMove], 60)
        XCTAssertEqual(triggerCounts[.forcingTactic], 50)
        XCTAssertEqual(triggerCounts[.noneIdentified], 250)
        XCTAssertEqual(triggerCounts.values.reduce(0, +), 360)
        XCTAssertEqual(confidenceCounts[.high], 45)
        XCTAssertEqual(confidenceCounts[.medium], 15)
        XCTAssertEqual(confidenceCounts[.low, default: 0], 0)
        XCTAssertEqual(confidenceCounts[.unresolved], 300)
        XCTAssertEqual(scopeCounts["INTENT_WHY_NOW"], 60)
        XCTAssertEqual(scopeCounts["OBSERVED_CHANGE_ONLY"], 130)
        XCTAssertEqual(scopeCounts["UNCERTAINTY_ONLY"], 170)
        XCTAssertEqual(shikenbishaCount, 80)
        XCTAssertEqual(effectBoundaryCount, 190)
        XCTAssertEqual(forbiddenViolationCount, 0)
        #else
        throw XCTSkip("Compression framework is required for the frozen Build18-2 projection fixture.")
        #endif
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

    #if canImport(Compression)
    private func loadRows() throws -> [[Any]] {
        let zlibWrapped = try XCTUnwrap(
            Data(base64Encoded: Self.frozenSafetyProjectionBase64, options: .ignoreUnknownCharacters)
        )
        XCTAssertGreaterThan(zlibWrapped.count, 6)
        let compressed = Data(zlibWrapped.dropFirst(2).dropLast(4))
        let jsonData = try decompressRawDeflate(compressed, capacity: 262_144)
        let object = try JSONSerialization.jsonObject(with: jsonData)
        return try XCTUnwrap(object as? [[Any]])
    }

    private func decompressRawDeflate(_ data: Data, capacity: Int) throws -> Data {
        var output = Data(count: capacity)
        let decodedSize = output.withUnsafeMutableBytes { outputBuffer in
            data.withUnsafeBytes { inputBuffer in
                guard let outputBase = outputBuffer.bindMemory(to: UInt8.self).baseAddress,
                      let inputBase = inputBuffer.bindMemory(to: UInt8.self).baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    outputBase,
                    capacity,
                    inputBase,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard decodedSize > 0 else { throw FrozenFixtureError.decompressionFailed }
        output.count = decodedSize
        return output
    }
    #endif

    private enum FrozenFixtureError: Error {
        case decompressionFailed
    }

    // Lossless safety projection generated from the uploaded frozen Build18-2 authority.
    // Source BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json SHA-256:
    // 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
    // Per row:
    // [positionId, previousMove, currentMove, primaryIntent, confidence, whyNowTrigger,
    //  givesCheck, supportingEvidence.kind[], sourceSignal.layer[], claimTypes,
    //  expectedExplanationScope, forbiddenClaims, strata, specializedRequired,
    //  specializedStatus, missingEvidence, allRequiredFieldsPresent,
    //  annotationStatus, crossReviewStatus]
    private static let frozenSafetyProjectionBase64 = """
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
"""
}
