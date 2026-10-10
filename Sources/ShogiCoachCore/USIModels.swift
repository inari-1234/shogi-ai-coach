import Foundation

public enum USIBoundKind: String, Equatable, Sendable {
    case exact
    case lowerbound
    case upperbound
}

public enum USIScore: Equatable, Sendable {
    case centipawn(Int, bound: Bound?)
    case mate(Int, bound: Bound?)

    public enum Bound: String, Equatable, Sendable {
        case lower
        case upper
    }

    public var boundKind: USIBoundKind {
        switch self {
        case .centipawn(_, let bound), .mate(_, let bound):
            switch bound {
            case .none: return .exact
            case .some(.lower): return .lowerbound
            case .some(.upper): return .upperbound
            }
        }
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
    public var rawLine: String?

    public init(
        depth: Int? = nil,
        selDepth: Int? = nil,
        multipv: Int = 1,
        score: USIScore? = nil,
        nodes: UInt64? = nil,
        nps: UInt64? = nil,
        timeMs: UInt64? = nil,
        pv: [String] = [],
        rawLine: String? = nil
    ) {
        self.depth = depth
        self.selDepth = selDepth
        self.multipv = multipv
        self.score = score
        self.nodes = nodes
        self.nps = nps
        self.timeMs = timeMs
        self.pv = pv
        self.rawLine = rawLine
    }

    public var boundKind: USIBoundKind? { score?.boundKind }
    public var pvHead: String? { pv.first }
    public var hasExactScore: Bool { score?.boundKind == .exact }
}

public struct USIBestMove: Equatable, Sendable {
    public let move: String
    public let ponder: String?

    public init(move: String, ponder: String?) {
        self.move = move
        self.ponder = ponder
    }
}

public enum USIBestMoveConsistency: String, Equatable, Sendable {
    case consistent
    case inconsistent
    case unavailable
}

public struct EngineProbeResult: Equatable, Sendable {
    public let bestMove: USIBestMove
    public let principalVariations: [USIInfo]
    public let observations: [USIInfo]
    public let bestMoveConsistency: USIBestMoveConsistency

    public init(
        bestMove: USIBestMove,
        principalVariations: [USIInfo],
        observations: [USIInfo] = [],
        bestMoveConsistency: USIBestMoveConsistency? = nil
    ) {
        self.bestMove = bestMove
        self.principalVariations = principalVariations
        self.observations = observations
        if let bestMoveConsistency {
            self.bestMoveConsistency = bestMoveConsistency
        } else if let primary = principalVariations.first(where: { $0.multipv == 1 }),
                  let head = primary.pvHead {
            self.bestMoveConsistency = head == bestMove.move ? .consistent : .inconsistent
        } else {
            self.bestMoveConsistency = .unavailable
        }
    }
}
