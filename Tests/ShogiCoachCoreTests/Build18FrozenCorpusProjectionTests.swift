import Foundation
import XCTest
@testable import ShogiCoachCore

#if canImport(Compression)
import Compression
#endif

final class Build18FrozenCorpusProjectionTests: XCTestCase {
    func testFrozen360ProjectionExpectations() throws {
        #if canImport(Compression)
        let compressed = try XCTUnwrap(
            Data(base64Encoded: Self.frozenProjectionBase64, options: .ignoreUnknownCharacters)
        )
        let jsonData = try decompressZlib(compressed, capacity: 65_536)
        let object = try JSONSerialization.jsonObject(with: jsonData)
        let rows = try XCTUnwrap(object as? [[Any]])

        XCTAssertEqual(rows.count, 360)

        var triggerCounts: [GroundedWhyNowTrigger: Int] = [:]
        for row in rows {
            XCTAssertEqual(row.count, 8)
            let positionID = try XCTUnwrap(row[0] as? String)
            let previousMove = row[1] is NSNull ? nil : row[1] as? String
            let intentRaw = try XCTUnwrap(row[2] as? String)
            let confidenceRaw = try XCTUnwrap(row[3] as? String)
            let expectedTriggerRaw = try XCTUnwrap(row[4] as? String)
            let givesCheck = try XCTUnwrap(row[5] as? Bool)
            let evidenceKinds = try XCTUnwrap(row[6] as? [String])

            let intent = try XCTUnwrap(MoveIntent(rawValue: intentRaw), positionID)
            let confidence = try XCTUnwrap(confidence(fromFrozen: confidenceRaw), positionID)
            let expectedTrigger = try XCTUnwrap(
                GroundedWhyNowTrigger(rawValue: expectedTriggerRaw),
                positionID
            )

            var facts = [ContextFact(id: "current_move", kind: .currentMove, detail: positionID)]
            if previousMove != nil {
                facts.append(.init(id: "previous_move", kind: .previousMove, detail: previousMove!))
            }
            if givesCheck {
                facts.append(.init(id: "check", kind: .check, detail: "frozen corpus explicit check"))
            }

            let effects: [ContextSignal] = givesCheck
                ? [.init(id: "gives_check", detail: "frozen corpus explicit check")]
                : []

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
                : [.init(intent: intent, score: 100, evidenceIDs: evidence.map { $0.id })]

            let analysis = MoveContextAnalysis(
                move: positionID,
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

            if confidence == .unresolved {
                XCTAssertNil(projected.compatibleIntent, positionID)
                XCTAssertNotEqual(projected.verbalizationMode, .assertive, positionID)
            }
            if expectedTrigger == .directPreviousMove {
                XCTAssertNotNil(projected.previousMove, positionID)
                XCTAssertTrue(
                    projected.sourceEvidenceIDs.contains("frozen_previous_move_causality"),
                    positionID
                )
            }

            triggerCounts[projected.trigger, default: 0] += 1
        }

        XCTAssertEqual(triggerCounts[.directPreviousMove], 60)
        XCTAssertEqual(triggerCounts[.forcingTactic], 50)
        XCTAssertEqual(triggerCounts[.noneIdentified], 250)
        XCTAssertEqual(triggerCounts.values.reduce(0, +), 360)
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
    private func decompressZlib(_ data: Data, capacity: Int) throws -> Data {
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
        guard decodedSize > 0 else {
            throw FrozenFixtureError.decompressionFailed
        }
        output.count = decodedSize
        return output
    }
    #endif

    private enum FrozenFixtureError: Error {
        case decompressionFailed
    }

    // Lossless compact projection of the uploaded frozen Build18-2 360-record corpus.
    // Fields per row:
    // [positionId, previousMove, primaryIntent, confidence, whyNowTrigger,
    //  diagnosticInspection.givesCheck, supportingEvidence.kind[], constructionFamily]
    // Source corpus SHA-256:
    // 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
    private static let frozenProjectionBase64 = """
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
"""
}
