import Foundation
import ShogiCoachCore

struct VE1BSearchObservationRecord: Codable, Sendable {
    let multipv: Int
    let pvHead: String?
    let scoreKind: String?
    let scoreValue: Int?
    let boundKind: String?
    let depth: Int?
    let seldepth: Int?
    let nodes: UInt64?
    let nps: UInt64?
    let timeMs: UInt64?
    let pv: [String]
    let rawUSI: String?

    init(_ info: USIInfo) {
        multipv = info.multipv
        pvHead = info.pv.first
        switch info.score {
        case .centipawn(let value, _):
            scoreKind = "cp"
            scoreValue = value
        case .mate(let value, _):
            scoreKind = "mate"
            scoreValue = value
        case .none:
            scoreKind = nil
            scoreValue = nil
        }
        boundKind = info.boundKind?.rawValue
        depth = info.depth
        seldepth = info.selDepth
        nodes = info.nodes
        nps = info.nps
        timeMs = info.timeMs
        pv = info.pv
        rawUSI = info.rawLine
    }
}

struct VE1BSearchAttemptRecord: Codable, Sendable {
    let attemptID: String
    let positionCommand: String
    let role: String
    let nodeBudget: Int
    let safetyCeilingMs: Int
    let issuedGoCommand: String
    let ttGeneration: Int
    let multiPV: Int
    let searchMoves: [String]
    let completion: String
    let elapsedMs: Int
    let thermalBefore: String
    let thermalAfter: String
    let maxObservedNodes: UInt64
    let bestMove: String?
    let bestMoveConsistency: String?
    let observations: [VE1BSearchObservationRecord]

    init(
        attemptID: String,
        positionCommand: String,
        multiPV: Int,
        searchMoves: [String],
        sample: NodeProbeSample
    ) {
        self.attemptID = attemptID
        self.positionCommand = positionCommand
        role = sample.searchRole.rawValue
        nodeBudget = sample.nodeBudget
        safetyCeilingMs = sample.safetyCeilingMs
        issuedGoCommand = sample.issuedGoCommand
        ttGeneration = sample.ttGeneration
        self.multiPV = multiPV
        self.searchMoves = searchMoves
        completion = sample.completion.rawValue
        elapsedMs = sample.elapsedMs
        thermalBefore = sample.thermalBefore
        thermalAfter = sample.thermalAfter
        maxObservedNodes = sample.maxObservedNodes
        bestMove = sample.result?.bestMove.move
        bestMoveConsistency = sample.result?.bestMoveConsistency.rawValue
        observations = sample.observations.map(VE1BSearchObservationRecord.init)
    }
}
