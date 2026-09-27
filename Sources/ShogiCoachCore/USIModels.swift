import Foundation

public enum USIScore: Equatable, Sendable {
    case centipawn(Int, bound: Bound?)
    case mate(Int, bound: Bound?)

    public enum Bound: String, Equatable, Sendable {
        case lower
        case upper
    }
}

public struct USIInfo: Equatable, Sendable {
    public var depth: Int?
    public var selDepth: Int?
    public var multipv: Int
    public var score: USIScore?
    public var nodes: UInt64?
    public var nps: UInt64?
    public var timeMs: UInt64?
    public var pv: [String]

    public init(
        depth: Int? = nil,
        selDepth: Int? = nil,
        multipv: Int = 1,
        score: USIScore? = nil,
        nodes: UInt64? = nil,
        nps: UInt64? = nil,
        timeMs: UInt64? = nil,
        pv: [String] = []
    ) {
        self.depth = depth
        self.selDepth = selDepth
        self.multipv = multipv
        self.score = score
        self.nodes = nodes
        self.nps = nps
        self.timeMs = timeMs
        self.pv = pv
    }
}

public struct USIBestMove: Equatable, Sendable {
    public let move: String
    public let ponder: String?

    public init(move: String, ponder: String?) {
        self.move = move
        self.ponder = ponder
    }
}

public struct EngineProbeResult: Equatable, Sendable {
    public let bestMove: USIBestMove
    public let principalVariations: [USIInfo]

    public init(bestMove: USIBestMove, principalVariations: [USIInfo]) {
        self.bestMove = bestMove
        self.principalVariations = principalVariations
    }
}
