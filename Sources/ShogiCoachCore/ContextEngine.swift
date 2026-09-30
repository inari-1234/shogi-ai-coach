import Foundation

public enum ContextEvidenceTier: Int, Codable, Comparable, Sendable {
    case geometry = 1
    case boardFunction = 2
    case engine = 3
    case precedent = 4
    case causal = 5

    public static func < (lhs: ContextEvidenceTier, rhs: ContextEvidenceTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum ContextConfidence: String, Codable, Sendable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
    case unresolved = "UNRESOLVED"
}

public enum MoveIntent: String, Codable, CaseIterable, Sendable {
    case rookPawnPressureResponse = "rook_pawn_pressure_response"
    case bishopLineResponse = "bishop_line_response"
    case defendPiece = "defend_piece"
    case captureThreatResponse = "capture_threat_response"
    case recapture = "recapture"
    case exchangePreparation = "exchange_preparation"
    case attackContinuation = "attack_continuation"
    case attackPreparation = "attack_preparation"
    case defense = "defense"
    case checkEvasion = "check_evasion"
    case kingEscape = "king_escape"
    case kingSafety = "king_safety"
    case castleFormation = "castle_formation"
    case pieceDevelopment = "piece_development"
    case majorPieceActivation = "major_piece_activation"
    case minorPieceDevelopment = "minor_piece_development"
    case tenuki = "tenuki"
    case neutralizeOpponentPlan = "neutralize_opponent_plan"
    case handPieceDeployment = "hand_piece_deployment"
    case forcingCheck = "forcing_check"
    case matingAttack = "mating_attack"
    case mateThreat = "mate_threat"
    case mateThreatResponse = "mate_threat_response"
    case escapeRouteCreation = "escape_route_creation"
    case addControl = "add_control"
    case blockLine = "block_line"
    case postExchangeImprovement = "post_exchange_improvement"
    case geometricAttackAdvance = "geometric_attack_advance"
    case positionImprovement = "position_improvement"
}

public enum ContextFactKind: String, Codable, Sendable {
    case previousMove = "previous_move"
    case currentMove = "current_move"
    case previousRookPawnAdvance = "previous_rook_pawn_advance"
    case newlyAttackedPiece = "newly_attacked_piece"
    case checkBeforeMove = "check_before_move"
    case currentGivesCheck = "current_gives_check"
    case currentCapture = "current_capture"
    case currentPromotion = "current_promotion"
    case currentDrop = "current_drop"
    case addedControl = "added_control"
    case removedAttack = "removed_attack"
    case increasedDefense = "increased_defense"
    case majorPieceMobilityIncrease = "major_piece_mobility_increase"
    case opponentKingDistanceReduced = "opponent_king_distance_reduced"
    case engineComparison = "engine_comparison"
    case knowledgeMatch = "knowledge_match"
}

public struct ContextFact: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContextFactKind
    public let text: String
    public let moves: [String]
    public let squares: [String]

    public init(
        id: String,
        kind: ContextFactKind,
        text: String,
        moves: [String] = [],
        squares: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.moves = moves
        self.squares = squares
    }
}

public enum ContextEffectKind: String, Codable, Sendable {
    case givesCheck = "gives_check"
    case capturesPiece = "captures_piece"
    case promotes = "promotes"
    case dropsPiece = "drops_piece"
    case controlAdded = "control_added"
    case attackReduced = "attack_reduced"
    case mobilityIncreased = "mobility_increased"
    case kingRelocated = "king_relocated"
}

public struct ContextEffect: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContextEffectKind
    public let text: String
    public let squares: [String]
    public let evidenceFactIDs: [String]

    public init(
        id: String,
        kind: ContextEffectKind,
        text: String,
        squares: [String] = [],
        evidenceFactIDs: [String] = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.squares = squares
        self.evidenceFactIDs = evidenceFactIDs
    }
}

public enum ContextOutcomeSource: String, Codable, Sendable {
    case actualPV = "actual_pv"
    case counterfactual = "counterfactual"
}

public struct ContextOutcome: Codable, Equatable, Sendable {
    public let source: ContextOutcomeSource
    public let stable: Bool
    public let text: String
    public let moves: [String]
    public let evaluationDeltaCp: Int?

    public init(
        source: ContextOutcomeSource,
        stable: Bool,
        text: String,
        moves: [String],
        evaluationDeltaCp: Int? = nil
    ) {
        self.source = source
        self.stable = stable
        self.text = text
        self.moves = moves
        self.evaluationDeltaCp = evaluationDeltaCp
    }
}

public enum ContextChangeKind: String, Codable, Sendable {
    case rookPawnAdvance = "rook_pawn_advance"
    case pieceNewlyAttacked = "piece_newly_attacked"
    case checkCreated = "check_created"
    case linePressureChanged = "line_pressure_changed"
}

public enum ContextResponseKind: String, Codable, Sendable {
    case resolved = "resolved"
    case reduced = "reduced"
    case exploited = "exploited"
    case ignored = "ignored"
    case countered = "countered"
    case unresolved = "unresolved"
}

public struct ContextChange: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContextChangeKind
    public let sourceMove: String
    public let targetSquares: [String]
    public let response: ContextResponseKind
    public let evidenceFactIDs: [String]

    public init(
        id: String,
        kind: ContextChangeKind,
        sourceMove: String,
        targetSquares: [String],
        response: ContextResponseKind,
        evidenceFactIDs: [String]
    ) {
        self.id = id
        self.kind = kind
        self.sourceMove = sourceMove
        self.targetSquares = targetSquares
        self.response = response
        self.evidenceFactIDs = evidenceFactIDs
    }
}

public struct IntentCandidate: Codable, Equatable, Sendable {
    public let intent: MoveIntent
    public let dominantTier: ContextEvidenceTier
    public let score: Double
    public let evidenceFactIDs: [String]

    public init(
        intent: MoveIntent,
        dominantTier: ContextEvidenceTier,
        score: Double,
        evidenceFactIDs: [String]
    ) {
        self.intent = intent
        self.dominantTier = dominantTier
        self.score = score
        self.evidenceFactIDs = evidenceFactIDs
    }
}

public enum PositionKnowledgeKind: String, Codable, Sendable {
    case openingBook = "opening_book"
    case precedent = "precedent"
}

public struct PositionKnowledgeCandidate: Codable, Equatable, Sendable {
    public let move: String
    public let gameCount: Int
    public let blackWins: Int?
    public let whiteWins: Int?
    public let draws: Int?
    public let typicalContinuation: [String]
    public let intentHints: [MoveIntent]

    public init(
        move: String,
        gameCount: Int,
        blackWins: Int? = nil,
        whiteWins: Int? = nil,
        draws: Int? = nil,
        typicalContinuation: [String] = [],
        intentHints: [MoveIntent] = []
    ) {
        self.move = move
        self.gameCount = gameCount
        self.blackWins = blackWins
        self.whiteWins = whiteWins
        self.draws = draws
        self.typicalContinuation = typicalContinuation
        self.intentHints = intentHints
    }
}

public struct PositionKnowledgeRecord: Codable, Equatable, Sendable {
    public let sfen: String
    public let kind: PositionKnowledgeKind
    public let source: String
    public let openingName: String?
    public let totalGames: Int
    public let candidates: [PositionKnowledgeCandidate]

    public init(
        sfen: String,
        kind: PositionKnowledgeKind,
        source: String,
        openingName: String? = nil,
        totalGames: Int,
        candidates: [PositionKnowledgeCandidate]
    ) {
        self.sfen = sfen
        self.kind = kind
        self.source = source
        self.openingName = openingName
        self.totalGames = totalGames
        self.candidates = candidates
    }
}

public struct PositionKnowledgeQuery: Equatable, Sendable {
    public let sfen: String
    public let move: String
    public let recentMoves: [String]

    public init(sfen: String, move: String, recentMoves: [String]) {
        self.sfen = sfen
        self.move = move
        self.recentMoves = recentMoves
    }
}

public protocol PositionKnowledgeProvider {
    func lookup(_ query: PositionKnowledgeQuery) -> PositionKnowledgeRecord?
}

public struct CompactPositionKnowledgeIndex: PositionKnowledgeProvider, Sendable {
    private let records: [String: PositionKnowledgeRecord]

    public init(records: [PositionKnowledgeRecord]) {
        self.records = Dictionary(uniqueKeysWithValues: records.map { ($0.sfen, $0) })
    }

    public init(jsonData: Data) throws {
        let decoded = try JSONDecoder().decode([PositionKnowledgeRecord].self, from: jsonData)
        self.init(records: decoded)
    }

    public func lookup(_ query: PositionKnowledgeQuery) -> PositionKnowledgeRecord? {
        records[query.sfen]
    }
}

public enum EngineSemanticTag: String, Codable, Sendable {
    case forcedMate = "forced_mate"
    case mateThreat = "mate_threat"
    case mateThreatResponse = "mate_threat_response"
    case rookBreakthroughAvoided = "rook_breakthrough_avoided"
    case materialLossAvoided = "material_loss_avoided"
    case checkAvoided = "check_avoided"
}

public struct ContextCounterfactualEvidence: Codable, Equatable, Sendable {
    public let alternativeMove: String
    public let evaluationDeltaCp: Int?
    public let opponentReply: String?
    public let stable: Bool
    public let tags: [EngineSemanticTag]

    public init(
        alternativeMove: String,
        evaluationDeltaCp: Int? = nil,
        opponentReply: String? = nil,
        stable: Bool,
        tags: [EngineSemanticTag] = []
    ) {
        self.alternativeMove = alternativeMove
        self.evaluationDeltaCp = evaluationDeltaCp
        self.opponentReply = opponentReply
        self.stable = stable
        self.tags = tags
    }
}

public struct ContextEngineEvidence: Codable, Equatable, Sendable {
    public let bestMove: String
    public let actualMove: String
    public let actualLossCp: Int?
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let bestPV: [String]
    public let actualPV: [String]
    public let semanticTags: [EngineSemanticTag]
    public let counterfactual: ContextCounterfactualEvidence?

    public init(
        bestMove: String,
        actualMove: String,
        actualLossCp: Int? = nil,
        comparisonStable: Bool,
        continuationStable: Bool,
        bestPV: [String] = [],
        actualPV: [String] = [],
        semanticTags: [EngineSemanticTag] = [],
        counterfactual: ContextCounterfactualEvidence? = nil
    ) {
        self.bestMove = bestMove
        self.actualMove = actualMove
        self.actualLossCp = actualLossCp
        self.comparisonStable = comparisonStable
        self.continuationStable = continuationStable
        self.bestPV = bestPV
        self.actualPV = actualPV
        self.semanticTags = semanticTags
        self.counterfactual = counterfactual
    }
}

public struct MoveContextAnalysis: Codable, Equatable, Sendable {
    public let move: String
    public let positionSFEN: String
    public let recentMoves: [String]
    public let facts: [ContextFact]
    public let effects: [ContextEffect]
    public let outcomes: [ContextOutcome]
    public let contextChanges: [ContextChange]
    public let intentCandidates: [IntentCandidate]
    public let selectedIntent: MoveIntent?
    public let confidence: ContextConfidence
    public let confidenceReasons: [String]
    public let knowledgeEvidence: PositionKnowledgeRecord?
    public let engineEvidence: ContextEngineEvidence?

    public init(
        move: String,
        positionSFEN: String,
        recentMoves: [String],
        facts: [ContextFact],
        effects: [ContextEffect],
        outcomes: [ContextOutcome],
        contextChanges: [ContextChange],
        intentCandidates: [IntentCandidate],
        selectedIntent: MoveIntent?,
        confidence: ContextConfidence,
        confidenceReasons: [String],
        knowledgeEvidence: PositionKnowledgeRecord?,
        engineEvidence: ContextEngineEvidence?
    ) {
        self.move = move
        self.positionSFEN = positionSFEN
        self.recentMoves = recentMoves
        self.facts = facts
        self.effects = effects
        self.outcomes = outcomes
        self.contextChanges = contextChanges
        self.intentCandidates = intentCandidates
        self.selectedIntent = selectedIntent
        self.confidence = confidence
        self.confidenceReasons = confidenceReasons
        self.knowledgeEvidence = knowledgeEvidence
        self.engineEvidence = engineEvidence
    }
}

public enum MoveContextEngine {
    private struct CandidateAccumulator {
        var tier: ContextEvidenceTier
        var score: Double
        var evidenceFactIDs: Set<String>
    }

    private struct PreviousContext {
        let move: String
        let effect: MoveEffect
        let before: BoardSnapshot
        let after: BoardSnapshot
        let rookPawnExchangeSquare: BoardCoordinate?
        let newAttacks: [NewAttack]
    }

    private struct NewAttack {
        let target: BoardCoordinate
        let attackerKinds: Set<BoardPieceKind>
    }

    public static func analyze(
        positionCommand: String,
        move: String,
        knowledgeProvider: (any PositionKnowledgeProvider)? = nil,
        engineEvidence: ContextEngineEvidence? = nil,
        recentMoveLimit: Int = 6
    ) throws -> MoveContextAnalysis {
        let before = try BoardSnapshotResolver.resolve(positionCommand: positionCommand)
        let currentEffect = try MoveEffectResolver.resolve(
            positionCommand: positionCommand,
            move: move
        )
        let afterCommand = try MoveEffectResolver.appending(move: move, to: positionCommand)
        let after = try BoardSnapshotResolver.resolve(positionCommand: afterCommand)
        let allMoves = moves(in: positionCommand)
        let recentMoves = Array(allMoves.suffix(max(0, recentMoveLimit)))
        let previous = try previousContext(
            positionCommand: positionCommand,
            currentSide: currentEffect.side
        )

        var facts: [ContextFact] = []
        var effects: [ContextEffect] = []
        var outcomes: [ContextOutcome] = []
        var changes: [ContextChange] = []
        var candidates: [MoveIntent: CandidateAccumulator] = [:]

        func addFact(
            _ id: String,
            _ kind: ContextFactKind,
            _ text: String,
            moves: [String] = [],
            squares: [String] = []
        ) {
            facts.append(
                ContextFact(
                    id: id,
                    kind: kind,
                    text: text,
                    moves: moves,
                    squares: squares
                )
            )
        }

        func addEffect(
            _ id: String,
            _ kind: ContextEffectKind,
            _ text: String,
            squares: [String] = [],
            evidence: [String] = []
        ) {
            effects.append(
                ContextEffect(
                    id: id,
                    kind: kind,
                    text: text,
                    squares: squares,
                    evidenceFactIDs: evidence
                )
            )
        }

        func addCandidate(
            _ intent: MoveIntent,
            tier: ContextEvidenceTier,
            score: Double,
            evidence: [String]
        ) {
            if var existing = candidates[intent] {
                existing.tier = max(existing.tier, tier)
                existing.score += score
                existing.evidenceFactIDs.formUnion(evidence)
                candidates[intent] = existing
            } else {
                candidates[intent] = CandidateAccumulator(
                    tier: tier,
                    score: score,
                    evidenceFactIDs: Set(evidence)
                )
            }
        }

        addFact(
            "current-move",
            .currentMove,
            "current move \(move)",
            moves: [move],
            squares: [currentEffect.destination.usi]
        )

        if let previous {
            addFact(
                "previous-move",
                .previousMove,
                "previous opponent move \(previous.move)",
                moves: [previous.move]
            )
        }

        let inCheckBefore = BoardAttackAnalyzer.isKingInCheck(
            snapshot: before,
            side: currentEffect.side
        )
        let inCheckAfter = BoardAttackAnalyzer.isKingInCheck(
            snapshot: after,
            side: currentEffect.side
        )
        if inCheckBefore {
            addFact(
                "check-before",
                .checkBeforeMove,
                "side to move is in check before the move",
                moves: previous.map { [$0.move] } ?? []
            )
            if !inCheckAfter {
                addCandidate(
                    .checkEvasion,
                    tier: .causal,
                    score: 0.98,
                    evidence: ["check-before", "current-move"]
                )
                addCandidate(
                    .defense,
                    tier: .causal,
                    score: 0.90,
                    evidence: ["check-before", "current-move"]
                )
            }
        }

        if let previous,
           let exchangeSquare = previous.rookPawnExchangeSquare {
            addFact(
                "previous-rook-pawn",
                .previousRookPawnAdvance,
                "the previous move advanced a pawn in front of its rook",
                moves: [previous.move],
                squares: [previous.effect.destination.usi, exchangeSquare.usi]
            )

            let controlBefore = BoardAttackAnalyzer.attackerCount(
                snapshot: before,
                target: exchangeSquare,
                by: currentEffect.side
            )
            let controlAfter = BoardAttackAnalyzer.attackerCount(
                snapshot: after,
                target: exchangeSquare,
                by: currentEffect.side
            )
            let addressed = controlAfter > controlBefore
            if addressed {
                addFact(
                    "rook-exchange-control-added",
                    .addedControl,
                    "the current move increases control of the rook-pawn exchange square",
                    moves: [move],
                    squares: [exchangeSquare.usi]
                )
                addEffect(
                    "effect-rook-exchange-control",
                    .controlAdded,
                    "control is added to the rook-pawn exchange square",
                    squares: [exchangeSquare.usi],
                    evidence: ["rook-exchange-control-added"]
                )
                addCandidate(
                    .rookPawnPressureResponse,
                    tier: .causal,
                    score: 1.00,
                    evidence: ["previous-rook-pawn", "rook-exchange-control-added", "current-move"]
                )
                addCandidate(
                    .neutralizeOpponentPlan,
                    tier: .boardFunction,
                    score: 0.72,
                    evidence: ["rook-exchange-control-added"]
                )
                changes.append(
                    ContextChange(
                        id: "change-rook-pawn",
                        kind: .rookPawnAdvance,
                        sourceMove: previous.move,
                        targetSquares: [exchangeSquare.usi],
                        response: .reduced,
                        evidenceFactIDs: ["previous-rook-pawn", "rook-exchange-control-added"]
                    )
                )
            } else {
                let counterplay = BoardAttackAnalyzer.isKingInCheck(
                    snapshot: after,
                    side: currentEffect.side.opponent
                ) || currentEffect.capturedPiece != nil
                if counterplay {
                    addCandidate(
                        .tenuki,
                        tier: .causal,
                        score: 0.82,
                        evidence: ["previous-rook-pawn", "current-move"]
                    )
                    changes.append(
                        ContextChange(
                            id: "change-rook-pawn",
                            kind: .rookPawnAdvance,
                            sourceMove: previous.move,
                            targetSquares: [exchangeSquare.usi],
                            response: .countered,
                            evidenceFactIDs: ["previous-rook-pawn", "current-move"]
                        )
                    )
                } else {
                    changes.append(
                        ContextChange(
                            id: "change-rook-pawn",
                            kind: .rookPawnAdvance,
                            sourceMove: previous.move,
                            targetSquares: [exchangeSquare.usi],
                            response: .ignored,
                            evidenceFactIDs: ["previous-rook-pawn", "current-move"]
                        )
                    )
                }
            }
        }

        if let previous {
            for (index, newAttack) in previous.newAttacks.enumerated() {
                let factID = "new-attack-\(index)"
                addFact(
                    factID,
                    .newlyAttackedPiece,
                    "the previous move newly attacks a piece on \(newAttack.target.usi)",
                    moves: [previous.move],
                    squares: [newAttack.target.usi]
                )

                let targetStillOccupied = after.piece(at: newAttack.target)?.side == currentEffect.side
                let attackersBeforeResponse = BoardAttackAnalyzer.attackerCount(
                    snapshot: before,
                    target: newAttack.target,
                    by: previous.effect.side
                )
                let attackersAfterResponse = BoardAttackAnalyzer.attackerCount(
                    snapshot: after,
                    target: newAttack.target,
                    by: previous.effect.side
                )
                let movedThreatenedPiece = currentEffect.source == newAttack.target
                let capturedAttacker = currentEffect.capturedPiece != nil
                    && currentEffect.destination == previous.effect.destination
                let reducedAttack = targetStillOccupied && attackersAfterResponse < attackersBeforeResponse

                if movedThreatenedPiece || capturedAttacker || reducedAttack {
                    addCandidate(
                        .captureThreatResponse,
                        tier: .causal,
                        score: 0.91,
                        evidence: [factID, "current-move"]
                    )
                    addCandidate(
                        .defendPiece,
                        tier: .causal,
                        score: 0.86,
                        evidence: [factID, "current-move"]
                    )
                    if !newAttack.attackerKinds.isDisjoint(with: [.bishop, .horse]) {
                        addCandidate(
                            .bishopLineResponse,
                            tier: .causal,
                            score: 0.94,
                            evidence: [factID, "current-move"]
                        )
                    }
                    changes.append(
                        ContextChange(
                            id: "change-new-attack-\(index)",
                            kind: newAttack.attackerKinds.isDisjoint(with: [.bishop, .horse])
                                ? .pieceNewlyAttacked
                                : .linePressureChanged,
                            sourceMove: previous.move,
                            targetSquares: [newAttack.target.usi],
                            response: movedThreatenedPiece ? .resolved : .reduced,
                            evidenceFactIDs: [factID, "current-move"]
                        )
                    )
                }
            }

            if previous.effect.capturedPiece != nil,
               currentEffect.capturedPiece != nil,
               currentEffect.destination == previous.effect.destination {
                addCandidate(
                    .recapture,
                    tier: .causal,
                    score: 1.00,
                    evidence: ["previous-move", "current-move"]
                )
            }
        }

        let givesCheck = BoardAttackAnalyzer.isKingInCheck(
            snapshot: after,
            side: currentEffect.side.opponent
        )
        if givesCheck {
            addFact(
                "gives-check",
                .currentGivesCheck,
                "the current move gives check",
                moves: [move]
            )
            addEffect(
                "effect-gives-check",
                .givesCheck,
                "the move immediately gives check",
                squares: [currentEffect.destination.usi],
                evidence: ["gives-check"]
            )
            addCandidate(
                .forcingCheck,
                tier: .boardFunction,
                score: 0.88,
                evidence: ["gives-check"]
            )
        }

        if let captured = currentEffect.capturedPiece {
            addFact(
                "current-capture",
                .currentCapture,
                "the current move captures \(captured.kanji)",
                moves: [move],
                squares: [currentEffect.destination.usi]
            )
            addEffect(
                "effect-capture",
                .capturesPiece,
                "the move removes an opponent piece from the board",
                squares: [currentEffect.destination.usi],
                evidence: ["current-capture"]
            )
            addCandidate(
                .exchangePreparation,
                tier: .boardFunction,
                score: 0.61,
                evidence: ["current-capture"]
            )
            addCandidate(
                .attackContinuation,
                tier: .boardFunction,
                score: 0.57,
                evidence: ["current-capture"]
            )
        }

        if currentEffect.promotes {
            addFact(
                "current-promotion",
                .currentPromotion,
                "the current move promotes the moving piece",
                moves: [move]
            )
            addEffect(
                "effect-promotion",
                .promotes,
                "the moved piece changes to its promoted movement",
                squares: [currentEffect.destination.usi],
                evidence: ["current-promotion"]
            )
        }

        if currentEffect.isDrop {
            addFact(
                "current-drop",
                .currentDrop,
                "the current move deploys a piece from hand",
                moves: [move],
                squares: [currentEffect.destination.usi]
            )
            addEffect(
                "effect-drop",
                .dropsPiece,
                "a hand piece becomes active on the board",
                squares: [currentEffect.destination.usi],
                evidence: ["current-drop"]
            )
            addCandidate(
                .handPieceDeployment,
                tier: .boardFunction,
                score: 0.55,
                evidence: ["current-drop"]
            )
        }

        if currentEffect.pieceBefore == .king {
            addEffect(
                "effect-king-relocation",
                .kingRelocated,
                "the king changes square",
                squares: [currentEffect.destination.usi],
                evidence: ["current-move"]
            )
            if inCheckBefore && !inCheckAfter {
                addCandidate(
                    .kingEscape,
                    tier: .causal,
                    score: 1.00,
                    evidence: ["check-before", "current-move"]
                )
                addCandidate(
                    .kingSafety,
                    tier: .causal,
                    score: 0.96,
                    evidence: ["check-before", "current-move"]
                )
            } else {
                addCandidate(
                    .kingSafety,
                    tier: .boardFunction,
                    score: 0.56,
                    evidence: ["current-move"]
                )
                let ply = allMoves.count + 1
                if ply <= 30,
                   let source = currentEffect.source,
                   source.file == 5,
                   currentEffect.destination.file != 5,
                   BoardAttackAnalyzer.adjacentFriendlyCount(
                    snapshot: after,
                    around: currentEffect.destination,
                    side: currentEffect.side
                   ) >= 2 {
                    addCandidate(
                        .castleFormation,
                        tier: .boardFunction,
                        score: 0.73,
                        evidence: ["current-move"]
                    )
                }
            }
        }

        if [.bishop, .rook, .horse, .dragon].contains(currentEffect.pieceBefore),
           let source = currentEffect.source {
            let beforeMobility = BoardAttackAnalyzer.attackCount(
                snapshot: before,
                from: source
            )
            let afterMobility = BoardAttackAnalyzer.attackCount(
                snapshot: after,
                from: currentEffect.destination
            )
            if afterMobility >= beforeMobility + 2 {
                addFact(
                    "major-mobility-increase",
                    .majorPieceMobilityIncrease,
                    "the moved major piece controls more squares after the move",
                    moves: [move]
                )
                addEffect(
                    "effect-major-mobility",
                    .mobilityIncreased,
                    "the major piece gains reachable squares",
                    squares: [currentEffect.destination.usi],
                    evidence: ["major-mobility-increase"]
                )
                addCandidate(
                    .majorPieceActivation,
                    tier: .boardFunction,
                    score: 0.60,
                    evidence: ["major-mobility-increase"]
                )
            }
        }

        if let source = currentEffect.source,
           currentEffect.pieceBefore != .king,
           currentEffect.capturedPiece == nil,
           !currentEffect.isDrop,
           let opponentKing = BoardAttackAnalyzer.kingSquare(snapshot: before, side: currentEffect.side.opponent) {
            let beforeDistance = chebyshevDistance(source, opponentKing)
            let afterDistance = chebyshevDistance(currentEffect.destination, opponentKing)
            if afterDistance < beforeDistance {
                addFact(
                    "geometry-closer-enemy-king",
                    .opponentKingDistanceReduced,
                    "the moved piece is geometrically closer to the opponent king",
                    moves: [move]
                )
                addCandidate(
                    .geometricAttackAdvance,
                    tier: .geometry,
                    score: 0.18,
                    evidence: ["geometry-closer-enemy-king"]
                )
            }
        }

        if let engineEvidence {
            if !engineEvidence.actualPV.isEmpty {
                outcomes.append(
                    ContextOutcome(
                        source: .actualPV,
                        stable: engineEvidence.continuationStable,
                        text: engineEvidence.continuationStable
                            ? "observed continuation after the actual move"
                            : "continuation after the actual move is unstable and reference-only",
                        moves: engineEvidence.actualPV
                    )
                )
            }
            if let counterfactual = engineEvidence.counterfactual {
                outcomes.append(
                    ContextOutcome(
                        source: .counterfactual,
                        stable: counterfactual.stable,
                        text: "equal-condition alternative move comparison",
                        moves: [counterfactual.alternativeMove] + (counterfactual.opponentReply.map { [$0] } ?? []),
                        evaluationDeltaCp: counterfactual.evaluationDeltaCp
                    )
                )
            }
            addFact(
                "engine-comparison",
                .engineComparison,
                engineEvidence.comparisonStable
                    ? "equal-condition engine comparison is stable"
                    : "equal-condition engine comparison is unstable",
                moves: [engineEvidence.bestMove, engineEvidence.actualMove]
            )
            if engineEvidence.semanticTags.contains(.forcedMate) {
                addCandidate(
                    .matingAttack,
                    tier: .engine,
                    score: engineEvidence.continuationStable ? 0.95 : 0.75,
                    evidence: ["engine-comparison"]
                )
            }
            if engineEvidence.semanticTags.contains(.mateThreat) {
                addCandidate(
                    .mateThreat,
                    tier: .engine,
                    score: 0.90,
                    evidence: ["engine-comparison"]
                )
            }
            if engineEvidence.semanticTags.contains(.mateThreatResponse) {
                addCandidate(
                    .mateThreatResponse,
                    tier: .engine,
                    score: 0.90,
                    evidence: ["engine-comparison"]
                )
            }
            if engineEvidence.semanticTags.contains(.rookBreakthroughAvoided) {
                addCandidate(
                    .rookPawnPressureResponse,
                    tier: .engine,
                    score: 0.72,
                    evidence: ["engine-comparison"]
                )
            }
        }

        let sfen = before.canonicalSFENMain
        let query = PositionKnowledgeQuery(
            sfen: sfen,
            move: move,
            recentMoves: recentMoves
        )
        let knowledge = knowledgeProvider?.lookup(query)
        if let knowledge,
           let moveEvidence = knowledge.candidates.first(where: { $0.move == move }) {
            addFact(
                "knowledge-match",
                .knowledgeMatch,
                "the move appears in \(moveEvidence.gameCount)/\(max(knowledge.totalGames, 1)) matching records from \(knowledge.source)",
                moves: [move]
            )
            for hint in moveEvidence.intentHints {
                addCandidate(
                    hint,
                    tier: .precedent,
                    score: 0.78,
                    evidence: ["knowledge-match"]
                )
            }
        }

        if candidates.isEmpty {
            addCandidate(
                .positionImprovement,
                tier: .geometry,
                score: 0.10,
                evidence: ["current-move"]
            )
        }

        let sortedCandidates = candidates.map { intent, value in
            IntentCandidate(
                intent: intent,
                dominantTier: value.tier,
                score: value.score,
                evidenceFactIDs: value.evidenceFactIDs.sorted()
            )
        }.sorted { lhs, rhs in
            if lhs.dominantTier != rhs.dominantTier {
                return lhs.dominantTier > rhs.dominantTier
            }
            if abs(lhs.score - rhs.score) > 0.0001 {
                return lhs.score > rhs.score
            }
            return lhs.intent.rawValue < rhs.intent.rawValue
        }

        let selection = select(
            sortedCandidates,
            knowledge: knowledge,
            move: move,
            engineEvidence: engineEvidence
        )

        return MoveContextAnalysis(
            move: move,
            positionSFEN: sfen,
            recentMoves: recentMoves,
            facts: facts,
            effects: effects,
            outcomes: outcomes,
            contextChanges: changes,
            intentCandidates: sortedCandidates,
            selectedIntent: selection.intent,
            confidence: selection.confidence,
            confidenceReasons: selection.reasons,
            knowledgeEvidence: knowledge,
            engineEvidence: engineEvidence
        )
    }

    private static func select(
        _ candidates: [IntentCandidate],
        knowledge: PositionKnowledgeRecord?,
        move: String,
        engineEvidence: ContextEngineEvidence?
    ) -> (intent: MoveIntent?, confidence: ContextConfidence, reasons: [String]) {
        guard let first = candidates.first else {
            return (nil, .unresolved, ["no_intent_candidate"])
        }

        if candidates.count >= 2 {
            let second = candidates[1]
            if first.dominantTier == second.dominantTier,
               abs(first.score - second.score) <= 0.05 {
                return (
                    nil,
                    .unresolved,
                    ["top_candidates_compete_at_same_evidence_tier"]
                )
            }
        }

        let knowledgeSupports = knowledge?.candidates.first(where: { $0.move == move })
            .map { candidate in
                candidate.intentHints.contains(first.intent)
                    || (knowledge?.totalGames ?? 0) >= 8 && candidate.gameCount * 5 >= (knowledge?.totalGames ?? 1)
            } ?? false
        let engineSupports = engineEvidence.map { evidence in
            evidence.comparisonStable
                && evidence.actualMove == move
                && (evidence.bestMove == move || (evidence.actualLossCp ?? Int.max) <= 40)
        } ?? false

        switch first.dominantTier {
        case .causal:
            if knowledgeSupports || engineSupports {
                return (
                    first.intent,
                    .high,
                    ["direct_previous_move_causality", knowledgeSupports ? "precedent_corroboration" : "engine_corroboration"]
                )
            }
            return (first.intent, .medium, ["direct_previous_move_causality"])
        case .precedent:
            return (first.intent, knowledgeSupports ? .high : .medium, ["position_knowledge_match"])
        case .engine:
            let stable = engineEvidence?.comparisonStable == true
            return (
                first.intent,
                stable ? .medium : .low,
                [stable ? "stable_engine_evidence" : "unstable_engine_evidence"]
            )
        case .boardFunction:
            return (
                first.intent,
                first.score >= 0.80 ? .medium : .low,
                ["board_function_only"]
            )
        case .geometry:
            return (first.intent, .low, ["geometry_only"])
        }
    }

    private static func previousContext(
        positionCommand: String,
        currentSide: ShogiSide
    ) throws -> PreviousContext? {
        let history = moves(in: positionCommand)
        guard let previousMove = history.last else { return nil }
        let beforePreviousCommand = command(beforeLastMoveOf: positionCommand)
        let beforePrevious = try BoardSnapshotResolver.resolve(
            positionCommand: beforePreviousCommand
        )
        let previousEffect = try MoveEffectResolver.resolve(
            positionCommand: beforePreviousCommand,
            move: previousMove
        )
        guard previousEffect.side == currentSide.opponent else { return nil }
        let afterPrevious = try BoardSnapshotResolver.resolve(positionCommand: positionCommand)

        let exchangeSquare = rookPawnExchangeSquare(
            effect: previousEffect,
            snapshotAfter: afterPrevious
        )
        let newAttacks = newlyAttackedPieces(
            before: beforePrevious,
            after: afterPrevious,
            attacker: previousEffect.side,
            defender: currentSide
        )
        return PreviousContext(
            move: previousMove,
            effect: previousEffect,
            before: beforePrevious,
            after: afterPrevious,
            rookPawnExchangeSquare: exchangeSquare,
            newAttacks: newAttacks
        )
    }

    private static func rookPawnExchangeSquare(
        effect: MoveEffect,
        snapshotAfter: BoardSnapshot
    ) -> BoardCoordinate? {
        guard effect.pieceBefore == .pawn,
              let source = effect.source,
              source.file == effect.destination.file else {
            return nil
        }
        let direction = effect.side == .black ? -1 : 1
        guard effect.destination.rank - source.rank == direction else {
            return nil
        }

        let rooks = snapshotAfter.squares.filter { coordinate, piece in
            coordinate.file == effect.destination.file
                && piece.side == effect.side
                && [.rook, .dragon].contains(piece.kind)
        }
        guard let rook = rooks.first(where: { coordinate, _ in
            (effect.destination.rank - coordinate.rank) * direction > 0
                && BoardAttackAnalyzer.clearOrthogonalFile(
                    snapshot: snapshotAfter,
                    from: coordinate,
                    to: effect.destination
                )
        })?.key else {
            return nil
        }
        _ = rook

        let nextRank = effect.destination.rank + direction
        guard (1...9).contains(nextRank) else { return nil }
        return BoardCoordinate(file: effect.destination.file, rank: nextRank)
    }

    private static func newlyAttackedPieces(
        before: BoardSnapshot,
        after: BoardSnapshot,
        attacker: ShogiSide,
        defender: ShogiSide
    ) -> [NewAttack] {
        var result: [NewAttack] = []
        for (coordinate, piece) in after.squares where piece.side == defender {
            let beforeAttackers = BoardAttackAnalyzer.attackers(
                snapshot: before,
                target: coordinate,
                by: attacker
            )
            let afterAttackers = BoardAttackAnalyzer.attackers(
                snapshot: after,
                target: coordinate,
                by: attacker
            )
            guard afterAttackers.count > beforeAttackers.count else { continue }
            result.append(
                NewAttack(
                    target: coordinate,
                    attackerKinds: Set(afterAttackers.map(\.kind))
                )
            )
        }
        return result.sorted {
            ($0.target.rank, $0.target.file) < ($1.target.rank, $1.target.file)
        }
    }

    private static func moves(in positionCommand: String) -> [String] {
        let tokens = positionCommand.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 4,
              tokens[0] == "position",
              tokens[1] == "startpos",
              tokens[2] == "moves" else {
            return []
        }
        return Array(tokens.dropFirst(3))
    }

    private static func command(beforeLastMoveOf positionCommand: String) -> String {
        var history = moves(in: positionCommand)
        guard !history.isEmpty else { return "position startpos" }
        history.removeLast()
        guard !history.isEmpty else { return "position startpos" }
        return "position startpos moves " + history.joined(separator: " ")
    }

    private static func chebyshevDistance(
        _ lhs: BoardCoordinate,
        _ rhs: BoardCoordinate
    ) -> Int {
        max(abs(lhs.file - rhs.file), abs(lhs.rank - rhs.rank))
    }
}

public enum BoardAttackAnalyzer {
    public static func kingSquare(
        snapshot: BoardSnapshot,
        side: ShogiSide
    ) -> BoardCoordinate? {
        snapshot.squares.first(where: { $0.value.side == side && $0.value.kind == .king })?.key
    }

    public static func isKingInCheck(
        snapshot: BoardSnapshot,
        side: ShogiSide
    ) -> Bool {
        guard let king = kingSquare(snapshot: snapshot, side: side) else { return false }
        return attackerCount(snapshot: snapshot, target: king, by: side.opponent) > 0
    }

    public static func attackerCount(
        snapshot: BoardSnapshot,
        target: BoardCoordinate,
        by side: ShogiSide
    ) -> Int {
        attackers(snapshot: snapshot, target: target, by: side).count
    }

    public static func attackers(
        snapshot: BoardSnapshot,
        target: BoardCoordinate,
        by side: ShogiSide
    ) -> [BoardPieceState] {
        snapshot.squares.compactMap { coordinate, piece in
            guard piece.side == side,
                  attacks(
                    snapshot: snapshot,
                    from: coordinate,
                    piece: piece,
                    target: target
                  ) else {
                return nil
            }
            return piece
        }
    }

    public static func attackCount(
        snapshot: BoardSnapshot,
        from source: BoardCoordinate
    ) -> Int {
        guard let piece = snapshot.piece(at: source) else { return 0 }
        var count = 0
        for rank in 1...9 {
            for file in 1...9 {
                let target = BoardCoordinate(file: file, rank: rank)
                if target == source { continue }
                if attacks(snapshot: snapshot, from: source, piece: piece, target: target) {
                    count += 1
                }
            }
        }
        return count
    }

    public static func adjacentFriendlyCount(
        snapshot: BoardSnapshot,
        around center: BoardCoordinate,
        side: ShogiSide
    ) -> Int {
        var count = 0
        for fileDelta in -1...1 {
            for rankDelta in -1...1 where !(fileDelta == 0 && rankDelta == 0) {
                let coordinate = BoardCoordinate(
                    file: center.file + fileDelta,
                    rank: center.rank + rankDelta
                )
                guard (1...9).contains(coordinate.file),
                      (1...9).contains(coordinate.rank) else { continue }
                if snapshot.piece(at: coordinate)?.side == side {
                    count += 1
                }
            }
        }
        return count
    }

    public static func attacks(
        snapshot: BoardSnapshot,
        from source: BoardCoordinate,
        piece: BoardPieceState,
        target: BoardCoordinate
    ) -> Bool {
        let df = target.file - source.file
        let dr = target.rank - source.rank
        if df == 0 && dr == 0 { return false }
        let forward = piece.side == .black ? -1 : 1

        switch piece.kind {
        case .pawn:
            return df == 0 && dr == forward
        case .lance:
            return df == 0
                && dr * forward > 0
                && clearLine(snapshot: snapshot, from: source, to: target)
        case .knight:
            return abs(df) == 1 && dr == 2 * forward
        case .silver:
            return (dr == forward && abs(df) <= 1)
                || (dr == -forward && abs(df) == 1)
        case .gold, .promotedPawn, .promotedLance, .promotedKnight, .promotedSilver:
            return (dr == forward && abs(df) <= 1)
                || (dr == 0 && abs(df) == 1)
                || (dr == -forward && df == 0)
        case .bishop:
            return abs(df) == abs(dr)
                && clearLine(snapshot: snapshot, from: source, to: target)
        case .rook:
            return (df == 0 || dr == 0)
                && clearLine(snapshot: snapshot, from: source, to: target)
        case .king:
            return max(abs(df), abs(dr)) == 1
        case .horse:
            if abs(df) == abs(dr) {
                return clearLine(snapshot: snapshot, from: source, to: target)
            }
            return abs(df) + abs(dr) == 1
        case .dragon:
            if df == 0 || dr == 0 {
                return clearLine(snapshot: snapshot, from: source, to: target)
            }
            return abs(df) == 1 && abs(dr) == 1
        }
    }

    public static func clearOrthogonalFile(
        snapshot: BoardSnapshot,
        from source: BoardCoordinate,
        to target: BoardCoordinate
    ) -> Bool {
        guard source.file == target.file else { return false }
        return clearLine(snapshot: snapshot, from: source, to: target)
    }

    private static func clearLine(
        snapshot: BoardSnapshot,
        from source: BoardCoordinate,
        to target: BoardCoordinate
    ) -> Bool {
        let fileDelta = target.file - source.file
        let rankDelta = target.rank - source.rank
        let fileStep = fileDelta == 0 ? 0 : (fileDelta > 0 ? 1 : -1)
        let rankStep = rankDelta == 0 ? 0 : (rankDelta > 0 ? 1 : -1)
        guard fileStep == 0 || rankStep == 0 || abs(fileDelta) == abs(rankDelta) else {
            return false
        }

        var file = source.file + fileStep
        var rank = source.rank + rankStep
        while file != target.file || rank != target.rank {
            if snapshot.piece(at: BoardCoordinate(file: file, rank: rank)) != nil {
                return false
            }
            file += fileStep
            rank += rankStep
        }
        return true
    }
}

public extension BoardSnapshot {
    var canonicalSFENMain: String {
        let board = (1...9).map { rank in
            var row = ""
            var empties = 0
            for file in stride(from: 9, through: 1, by: -1) {
                let coordinate = BoardCoordinate(file: file, rank: rank)
                guard let piece = piece(at: coordinate) else {
                    empties += 1
                    continue
                }
                if empties > 0 {
                    row += String(empties)
                    empties = 0
                }
                row += sfenToken(piece)
            }
            if empties > 0 { row += String(empties) }
            return row
        }.joined(separator: "/")

        let turn = sideToMove == .black ? "b" : "w"
        let handOrder: [BoardPieceKind] = [.rook, .bishop, .gold, .silver, .knight, .lance, .pawn]
        var hand = ""
        for side in [ShogiSide.black, ShogiSide.white] {
            for kind in handOrder {
                let count = handCount(side: side, kind: kind)
                guard count > 0 else { continue }
                if count > 1 { hand += String(count) }
                let letter = kind.rawValue
                hand += side == .black ? letter : letter.lowercased()
            }
        }
        if hand.isEmpty { hand = "-" }
        return "\(board) \(turn) \(hand)"
    }

    private func sfenToken(_ piece: BoardPieceState) -> String {
        let raw = piece.kind.rawValue
        if raw.hasPrefix("+") {
            let letter = String(raw.dropFirst())
            return "+" + (piece.side == .black ? letter : letter.lowercased())
        }
        return piece.side == .black ? raw : raw.lowercased()
    }
}
