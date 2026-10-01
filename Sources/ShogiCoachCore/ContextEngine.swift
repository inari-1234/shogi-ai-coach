import Foundation

public enum MoveIntent: String, Codable, CaseIterable, Hashable, Sendable {
    case rookPawnResponse = "rook_pawn_response"
    case bishopLineResponse = "bishop_line_response"
    case pieceDefense = "piece_defense"
    case captureThreatResponse = "capture_threat_response"
    case exchangePreparation = "exchange_preparation"
    case attackContinuation = "attack_continuation"
    case attackPreparation = "attack_preparation"
    case defense = "defense"
    case kingSafety = "king_safety"
    case castling = "castling"
    case development = "development"
    case pieceActivation = "piece_activation"
    case majorPieceActivation = "major_piece_activation"
    case tenuki = "tenuki"
    case neutralizeThreat = "neutralize_threat"
    case handPieceDeployment = "hand_piece_deployment"
    case outpostCreation = "outpost_creation"
    case matingAttack = "mating_attack"
    case threatmate = "threatmate"
    case threatmateDefense = "threatmate_defense"
    case kingEscape = "king_escape"
    case controlAddition = "control_addition"
    case controlBlock = "control_block"
    case postExchangeImprovement = "post_exchange_improvement"
    case unresolved = "unresolved"
}

public enum ContextConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
    case unresolved
}

public enum ContextEvidenceKind: String, Codable, Sendable {
    case previousMoveCausality = "previous_move_causality"
    case boardEffect = "board_effect"
    case openingBook = "opening_book"
    case precedent = "precedent"
    case enginePV = "engine_pv"
    case counterfactual = "counterfactual"
    case geometry = "geometry"
}

public enum ContextFactKind: String, Codable, Sendable {
    case previousMove = "previous_move"
    case currentMove = "current_move"
    case capture = "capture"
    case drop = "drop"
    case promotion = "promotion"
    case check = "check"
    case sideInCheck = "side_in_check"
    case rookPawnAdvance = "rook_pawn_advance"
    case newlyAttackedPiece = "newly_attacked_piece"
    case engineComparison = "engine_comparison"
}

public struct ContextFact: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContextFactKind
    public let detail: String

    public init(id: String, kind: ContextFactKind, detail: String) {
        self.id = id
        self.kind = kind
        self.detail = detail
    }
}

public struct ContextSignal: Codable, Equatable, Sendable {
    public let id: String
    public let detail: String

    public init(id: String, detail: String) {
        self.id = id
        self.detail = detail
    }
}

public struct ContextEvidence: Codable, Equatable, Sendable {
    public let id: String
    public let kind: ContextEvidenceKind
    public let detail: String
    public let supportedIntent: MoveIntent
    public let weight: Int

    public init(
        id: String,
        kind: ContextEvidenceKind,
        detail: String,
        supportedIntent: MoveIntent,
        weight: Int
    ) {
        self.id = id
        self.kind = kind
        self.detail = detail
        self.supportedIntent = supportedIntent
        self.weight = weight
    }
}

public struct IntentCandidate: Codable, Equatable, Sendable {
    public let intent: MoveIntent
    public let score: Int
    public let evidenceIDs: [String]

    public init(intent: MoveIntent, score: Int, evidenceIDs: [String]) {
        self.intent = intent
        self.score = score
        self.evidenceIDs = evidenceIDs
    }
}

public struct MoveContextEngineEvidence: Codable, Equatable, Sendable {
    public let bestMove: String
    public let actualMove: String
    public let comparisonStable: Bool
    public let continuationStable: Bool
    public let bestPV: [String]
    public let actualPV: [String]
    public let actualLossCp: Int?
    public let actualMate: Bool
    public let createsThreatmate: Bool
    public let opponentThreatmateBefore: Bool
    public let opponentThreatmateAfter: Bool

    public init(
        bestMove: String,
        actualMove: String,
        comparisonStable: Bool,
        continuationStable: Bool,
        bestPV: [String],
        actualPV: [String],
        actualLossCp: Int?,
        actualMate: Bool = false,
        createsThreatmate: Bool = false,
        opponentThreatmateBefore: Bool = false,
        opponentThreatmateAfter: Bool = false
    ) {
        self.bestMove = bestMove
        self.actualMove = actualMove
        self.comparisonStable = comparisonStable
        self.continuationStable = continuationStable
        self.bestPV = bestPV
        self.actualPV = actualPV
        self.actualLossCp = actualLossCp
        self.actualMate = actualMate
        self.createsThreatmate = createsThreatmate
        self.opponentThreatmateBefore = opponentThreatmateBefore
        self.opponentThreatmateAfter = opponentThreatmateAfter
    }
}

public struct MoveContextKnowledgeEvidence: Codable, Equatable, Sendable {
    public let kind: ContextEvidenceKind
    public let sourceID: String
    public let intent: MoveIntent
    public let weight: Int
    public let detail: String

    public init(
        kind: ContextEvidenceKind,
        sourceID: String,
        intent: MoveIntent,
        weight: Int,
        detail: String
    ) {
        self.kind = kind
        self.sourceID = sourceID
        self.intent = intent
        self.weight = weight
        self.detail = detail
    }
}

public protocol MoveContextKnowledgeProvider: Sendable {
    func evidence(positionCommand: String, move: String) -> [MoveContextKnowledgeEvidence]
}

public struct EmptyMoveContextKnowledgeProvider: MoveContextKnowledgeProvider {
    public init() {}
    public func evidence(positionCommand: String, move: String) -> [MoveContextKnowledgeEvidence] { [] }
}

public struct MoveContextAnalysis: Codable, Equatable, Sendable {
    public let move: String
    public let previousMove: String?
    public let facts: [ContextFact]
    public let contextChanges: [ContextSignal]
    public let effects: [ContextSignal]
    public let outcomes: [ContextSignal]
    public let intentCandidates: [IntentCandidate]
    public let selectedIntent: MoveIntent
    public let confidence: ContextConfidence
    public let evidence: [ContextEvidence]

    public init(
        move: String,
        previousMove: String?,
        facts: [ContextFact],
        contextChanges: [ContextSignal],
        effects: [ContextSignal],
        outcomes: [ContextSignal],
        intentCandidates: [IntentCandidate],
        selectedIntent: MoveIntent,
        confidence: ContextConfidence,
        evidence: [ContextEvidence]
    ) {
        self.move = move
        self.previousMove = previousMove
        self.facts = facts
        self.contextChanges = contextChanges
        self.effects = effects
        self.outcomes = outcomes
        self.intentCandidates = intentCandidates
        self.selectedIntent = selectedIntent
        self.confidence = confidence
        self.evidence = evidence
    }
}

public enum ContextIntentResolver {
    struct Resolution {
        let candidates: [IntentCandidate]
        let selectedIntent: MoveIntent
        let confidence: ContextConfidence
    }

    static func strongestEngineAnchor(from evidence: [ContextEvidence]) -> MoveIntent? {
        var grouped: [MoveIntent: Int] = [:]
        for item in evidence {
            guard item.weight > 0,
                  item.supportedIntent != .unresolved,
                  item.kind == .previousMoveCausality
                    || item.kind == .boardEffect
                    || item.kind == .openingBook
                    || item.kind == .precedent else {
                continue
            }
            grouped[item.supportedIntent, default: 0] += item.weight
        }
        let ranked = grouped.sorted {
            if $0.value == $1.value { return $0.key.rawValue < $1.key.rawValue }
            return $0.value > $1.value
        }
        guard let first = ranked.first, first.value >= 20 else { return nil }
        if ranked.count > 1, ranked[1].value == first.value { return nil }
        return first.key
    }

    static func resolve(evidence: [ContextEvidence]) -> Resolution {
        var grouped: [MoveIntent: (score: Int, ids: [String])] = [:]
        for item in evidence where item.supportedIntent != .unresolved {
            var entry = grouped[item.supportedIntent] ?? (0, [])
            entry.score += max(0, item.weight)
            entry.ids.append(item.id)
            grouped[item.supportedIntent] = entry
        }

        var candidates = grouped.map {
            IntentCandidate(intent: $0.key, score: $0.value.score, evidenceIDs: $0.value.ids.sorted())
        }
        candidates.sort {
            if $0.score == $1.score { return $0.intent.rawValue < $1.intent.rawValue }
            return $0.score > $1.score
        }

        guard let top = candidates.first, top.score >= 30 else {
            return Resolution(candidates: candidates, selectedIntent: .unresolved, confidence: .unresolved)
        }

        let secondScore = candidates.dropFirst().first?.score ?? Int.min
        let supporting = evidence.filter {
            $0.supportedIntent == top.intent && $0.weight > 0 && $0.kind != .geometry
        }
        let kinds = Set(supporting.map(\.kind))
        let hasHighAuthority = supporting.contains {
            ($0.kind == .previousMoveCausality && $0.weight >= 95)
                || ($0.kind == .enginePV && $0.weight >= 100)
                || ($0.kind == .counterfactual && $0.weight >= 100)
        }

        let confidence: ContextConfidence
        if top.score >= 100, top.score - secondScore >= 15, hasHighAuthority {
            confidence = .high
        } else if top.score >= 60 || (top.score >= 45 && kinds.count >= 2) {
            confidence = .medium
        } else {
            confidence = .low
        }

        return Resolution(
            candidates: candidates,
            selectedIntent: top.intent,
            confidence: confidence
        )
    }
}

public struct MoveContextEngine: Sendable {
    private let knowledgeProvider: any MoveContextKnowledgeProvider

    public init(knowledgeProvider: any MoveContextKnowledgeProvider = EmptyMoveContextKnowledgeProvider()) {
        self.knowledgeProvider = knowledgeProvider
    }

    public func analyze(
        positionCommand: String,
        move: String,
        engineEvidence: MoveContextEngineEvidence? = nil
    ) throws -> MoveContextAnalysis {
        let currentEffect = try MoveEffectResolver.resolve(positionCommand: positionCommand, move: move)
        let beforeCurrent = try BoardSnapshotResolver.resolve(positionCommand: positionCommand)
        let afterCurrentCommand = try MoveEffectResolver.appending(move: move, to: positionCommand)
        let afterCurrent = try BoardSnapshotResolver.resolve(positionCommand: afterCurrentCommand)

        let history = try Self.historyMoves(positionCommand)
        let previousMove = history.last
        var previousEffect: MoveEffect?
        var beforePrevious: BoardSnapshot?
        if let previousMove {
            let previousCommand = Self.positionCommand(moves: Array(history.dropLast()))
            previousEffect = try MoveEffectResolver.resolve(positionCommand: previousCommand, move: previousMove)
            beforePrevious = try BoardSnapshotResolver.resolve(positionCommand: previousCommand)
        }

        var facts: [ContextFact] = [
            .init(id: "current_move", kind: .currentMove, detail: move)
        ]
        var contextChanges: [ContextSignal] = []
        var effects: [ContextSignal] = []
        var outcomes: [ContextSignal] = []
        var evidence: [ContextEvidence] = []

        if let previousMove {
            facts.append(.init(id: "previous_move", kind: .previousMove, detail: previousMove))
        }
        if currentEffect.capturedPiece != nil {
            facts.append(.init(id: "capture", kind: .capture, detail: currentEffect.capturedPiece?.rawValue ?? "-"))
            outcomes.append(.init(id: "material_capture", detail: currentEffect.destination.usi))
        }
        if currentEffect.isDrop {
            facts.append(.init(id: "drop", kind: .drop, detail: currentEffect.pieceAfter.rawValue))
        }
        if currentEffect.promotes {
            facts.append(.init(id: "promotion", kind: .promotion, detail: currentEffect.pieceAfter.rawValue))
        }

        let mover = currentEffect.side
        let opponent = Self.opponent(of: mover)
        let ownKingBefore = Self.kingSquare(side: mover, snapshot: beforeCurrent)
        let ownKingAfter = Self.kingSquare(side: mover, snapshot: afterCurrent)
        let opponentKingAfter = Self.kingSquare(side: opponent, snapshot: afterCurrent)
        let wasInCheck = ownKingBefore.map { Self.isSquareAttacked($0, by: opponent, snapshot: beforeCurrent) } ?? false
        let isInCheckAfter = ownKingAfter.map { Self.isSquareAttacked($0, by: opponent, snapshot: afterCurrent) } ?? false
        let givesCheck = opponentKingAfter.map { Self.isSquareAttacked($0, by: mover, snapshot: afterCurrent) } ?? false

        if wasInCheck {
            facts.append(.init(id: "side_in_check", kind: .sideInCheck, detail: mover.rawValue))
            contextChanges.append(.init(id: "check_pressure", detail: "before_current"))
        }
        if givesCheck {
            facts.append(.init(id: "check", kind: .check, detail: opponent.rawValue))
            effects.append(.init(id: "gives_check", detail: currentEffect.destination.usi))
            evidence.append(.init(
                id: "ev_check_continuation",
                kind: .boardEffect,
                detail: "current_move_gives_check",
                supportedIntent: .attackContinuation,
                weight: 85
            ))
        }

        if wasInCheck, !isInCheckAfter {
            if currentEffect.pieceBefore == .king {
                evidence.append(.init(
                    id: "ev_king_escape",
                    kind: .previousMoveCausality,
                    detail: "king_left_check",
                    supportedIntent: .kingEscape,
                    weight: 110
                ))
            } else {
                evidence.append(.init(
                    id: "ev_check_defense",
                    kind: .previousMoveCausality,
                    detail: "non_king_move_resolved_check",
                    supportedIntent: .defense,
                    weight: 110
                ))
            }
            contextChanges.append(.init(id: "check_resolved", detail: ownKingAfter?.usi ?? "-"))
        }

        if engineEvidence?.actualMate == true, givesCheck {
            evidence.append(.init(
                id: "ev_forced_mate",
                kind: .enginePV,
                detail: "stable_line_reports_forced_mate",
                supportedIntent: .matingAttack,
                weight: 140
            ))
        }
        if engineEvidence?.createsThreatmate == true {
            evidence.append(.init(
                id: "ev_threatmate",
                kind: .enginePV,
                detail: "engine_verified_threatmate_created",
                supportedIntent: .threatmate,
                weight: 125
            ))
        }
        if engineEvidence?.opponentThreatmateBefore == true,
           engineEvidence?.opponentThreatmateAfter == false {
            evidence.append(.init(
                id: "ev_threatmate_defense",
                kind: .counterfactual,
                detail: "opponent_threatmate_removed",
                supportedIntent: .threatmateDefense,
                weight: 135
            ))
        }

        let attackPressureBefore = Self.kingZonePressure(
            attackingSide: mover,
            kingSide: opponent,
            snapshot: beforeCurrent
        )
        let attackPressureAfter = Self.kingZonePressure(
            attackingSide: mover,
            kingSide: opponent,
            snapshot: afterCurrent
        )
        if !givesCheck, attackPressureAfter >= attackPressureBefore + 2 {
            evidence.append(.init(
                id: "ev_attack_preparation",
                kind: .boardEffect,
                detail: "opponent_king_zone_pressure:\(attackPressureBefore)->\(attackPressureAfter)",
                supportedIntent: .attackPreparation,
                weight: 75
            ))
        }

        let dangerBefore = Self.kingZonePressure(
            attackingSide: opponent,
            kingSide: mover,
            snapshot: beforeCurrent
        )
        let dangerAfter = Self.kingZonePressure(
            attackingSide: opponent,
            kingSide: mover,
            snapshot: afterCurrent
        )
        if !wasInCheck, dangerAfter + 2 <= dangerBefore {
            evidence.append(.init(
                id: "ev_defense_pressure_reduction",
                kind: .boardEffect,
                detail: "own_king_zone_pressure:\(dangerBefore)->\(dangerAfter)",
                supportedIntent: .defense,
                weight: 80
            ))
        }

        let defendersBefore = Self.kingZoneControlCount(
            side: mover,
            kingSide: mover,
            snapshot: beforeCurrent
        )
        let defendersAfter = Self.kingZoneControlCount(
            side: mover,
            kingSide: mover,
            snapshot: afterCurrent
        )
        if defendersAfter >= defendersBefore + 2 {
            evidence.append(.init(
                id: "ev_king_safety",
                kind: .boardEffect,
                detail: "king_zone_defenders:\(defendersBefore)->\(defendersAfter)",
                supportedIntent: .kingSafety,
                weight: 70
            ))
        }

        // Build17-4: observable HumanConcept/Effect metadata only.
        // These signals never add Intent evidence and therefore cannot override Build16 intent resolution.
        if let source = currentEffect.source,
           beforeCurrent.piece(at: source) != nil,
           afterCurrent.piece(at: currentEffect.destination) != nil {
            let mobilityBefore = Self.attackCount(from: source, snapshot: beforeCurrent)
            let mobilityAfter = Self.attackCount(from: currentEffect.destination, snapshot: afterCurrent)
            if mobilityAfter >= mobilityBefore + 2 {
                effects.append(.init(
                    id: "piece_mobility",
                    detail: "attack_squares:\(mobilityBefore)->\(mobilityAfter)"
                ))
            }
        }

        let opponentEscapeBefore = Self.kingEscapeSquareCount(
            kingSide: opponent,
            attackingSide: mover,
            snapshot: beforeCurrent
        )
        let opponentEscapeAfter = Self.kingEscapeSquareCount(
            kingSide: opponent,
            attackingSide: mover,
            snapshot: afterCurrent
        )
        if opponentEscapeAfter < opponentEscapeBefore {
            effects.append(.init(
                id: "escape_route_control",
                detail: "opponent_escape_squares:\(opponentEscapeBefore)->\(opponentEscapeAfter)"
            ))
        }

        if let previousEffect,
           previousEffect.side == opponent,
           previousEffect.pieceAfter == .pawn,
           Self.hasAlignedRookBehindPawn(effect: previousEffect, snapshot: beforeCurrent),
           let nextSquare = Self.nextForwardSquare(from: previousEffect.destination, side: previousEffect.side),
           let movedPiece = afterCurrent.piece(at: currentEffect.destination),
           Self.attacks(from: currentEffect.destination, piece: movedPiece, target: nextSquare, snapshot: afterCurrent),
           !Self.sourceAlreadyControlled(
                target: nextSquare,
                effect: currentEffect,
                snapshot: beforeCurrent
           ) {
            facts.append(.init(id: "rook_pawn_advance", kind: .rookPawnAdvance, detail: previousEffect.destination.usi))
            contextChanges.append(.init(id: "rook_pawn_pressure", detail: nextSquare.usi))
            effects.append(.init(id: "added_control", detail: nextSquare.usi))
            evidence.append(.init(
                id: "ev_rook_pawn_response",
                kind: .previousMoveCausality,
                detail: "responds_to_rook_pawn_advance_and_controls_next_break_square:\(nextSquare.usi)",
                supportedIntent: .rookPawnResponse,
                weight: 120
            ))
        }

        var newlyAttackedFromPrevious: Set<BoardCoordinate> = []
        if let beforePrevious {
            let newlyAttacked = Self.newlyAttackedFriendlySquares(
                side: mover,
                before: beforePrevious,
                after: beforeCurrent
            )
            newlyAttackedFromPrevious = newlyAttacked
            for square in newlyAttacked {
                facts.append(.init(id: "new_attack_\(square.usi)", kind: .newlyAttackedPiece, detail: square.usi))
            }

            // attack_attacker is subordinate metadata: a concrete attacker created by the previous
            // move is itself captured or attacked by the current move. It never contributes Intent weight.
            let concreteAttackers = Set(
                newlyAttacked.flatMap {
                    Self.attackers(of: $0, by: opponent, snapshot: beforeCurrent).map(\.square)
                }
            )
            if let movedPiece = afterCurrent.piece(at: currentEffect.destination) {
                let counterattacked = concreteAttackers.filter { attackerSquare in
                    if currentEffect.capturedPiece != nil,
                       currentEffect.destination == attackerSquare {
                        return true
                    }
                    guard afterCurrent.piece(at: attackerSquare)?.side == opponent else { return false }
                    return Self.attacks(
                        from: currentEffect.destination,
                        piece: movedPiece,
                        target: attackerSquare,
                        snapshot: afterCurrent
                    )
                }
                if !counterattacked.isEmpty {
                    effects.append(.init(
                        id: "attack_attacker",
                        detail: counterattacked.map(\.usi).sorted().joined(separator: ",")
                    ))
                }
            }

            for threatened in newlyAttacked where threatened != currentEffect.source {
                let beforeDefenders = Self.controlCount(
                    threatened,
                    by: mover,
                    snapshot: beforeCurrent
                )
                let afterDefenders = Self.controlCount(
                    threatened,
                    by: mover,
                    snapshot: afterCurrent
                )
                if afterDefenders > beforeDefenders {
                    evidence.append(.init(
                        id: "ev_piece_defense_\(threatened.usi)",
                        kind: .previousMoveCausality,
                        detail: "added_defender_to_newly_attacked_piece:\(threatened.usi)",
                        supportedIntent: .pieceDefense,
                        weight: 92
                    ))
                    effects.append(.init(id: "added_piece_defender", detail: threatened.usi))
                }
            }

            if let source = currentEffect.source, newlyAttacked.contains(source) {
                let sourceAttackers = Self.attackers(of: source, by: opponent, snapshot: beforeCurrent)
                let capturedAttacker = currentEffect.capturedPiece != nil
                    && sourceAttackers.contains { $0.square == currentEffect.destination }
                let escapedAttack = !Self.isSquareAttacked(
                    currentEffect.destination,
                    by: opponent,
                    snapshot: afterCurrent
                )

                if capturedAttacker || escapedAttack {
                    let bishopAttack = sourceAttackers
                        .contains { $0.piece.kind == .bishop || $0.piece.kind == .horse }
                    let intent: MoveIntent = bishopAttack ? .bishopLineResponse : .captureThreatResponse
                    evidence.append(.init(
                        id: bishopAttack ? "ev_bishop_line_response" : "ev_capture_threat_response",
                        kind: .previousMoveCausality,
                        detail: capturedAttacker
                            ? "previous_move_created_attack_and_attacker_captured:\(source.usi)"
                            : "previous_move_created_attack_and_piece_evaded:\(source.usi)",
                        supportedIntent: intent,
                        weight: bishopAttack ? 105 : 95
                    ))
                    contextChanges.append(.init(id: "new_attack_from_previous_move", detail: source.usi))
                    effects.append(.init(
                        id: capturedAttacker ? "threat_source_captured" : "threat_evaded",
                        detail: currentEffect.destination.usi
                    ))
                }
            }
        }

        if let previousEffect,
           previousEffect.side == opponent,
           previousEffect.capturedPiece != nil,
           currentEffect.capturedPiece != nil,
           currentEffect.destination == previousEffect.destination {
            evidence.append(.init(
                id: "ev_recapture_exchange",
                kind: .previousMoveCausality,
                detail: "immediate_recapture_on:\(currentEffect.destination.usi)",
                supportedIntent: .postExchangeImprovement,
                weight: 108
            ))
            contextChanges.append(.init(id: "exchange_sequence", detail: currentEffect.destination.usi))
        }

        if currentEffect.isDrop {
            evidence.append(.init(
                id: "ev_drop_deployment",
                kind: .boardEffect,
                detail: "hand_piece_deployed:\(currentEffect.destination.usi)",
                supportedIntent: .handPieceDeployment,
                weight: 60
            ))
        }

        let beforeMobility = currentEffect.source.map {
            Self.attackCount(from: $0, snapshot: beforeCurrent)
        } ?? 0
        let afterMobility = Self.attackCount(from: currentEffect.destination, snapshot: afterCurrent)
        if !currentEffect.isDrop, afterMobility >= beforeMobility + 2 {
            let major = [.rook, .bishop, .dragon, .horse].contains(currentEffect.pieceAfter)
            evidence.append(.init(
                id: major ? "ev_major_activation" : "ev_piece_activation",
                kind: .boardEffect,
                detail: "mobility:\(beforeMobility)->\(afterMobility)",
                supportedIntent: major ? .majorPieceActivation : .pieceActivation,
                weight: major ? 55 : 40
            ))
        }

        if currentEffect.pieceBefore == .king,
           !wasInCheck,
           history.count < 40,
           Self.isHomeCamp(currentEffect.destination, side: mover) {
            evidence.append(.init(
                id: "ev_castling_step",
                kind: .boardEffect,
                detail: "early_home_camp_king_relocation",
                supportedIntent: .castling,
                weight: 90
            ))
        }

        if !currentEffect.isDrop,
           currentEffect.pieceBefore != .pawn,
           currentEffect.pieceBefore != .king,
           history.count < 24,
           let source = currentEffect.source,
           Self.isHomeCamp(source, side: mover),
           !Self.isHomeCamp(currentEffect.destination, side: mover) {
            evidence.append(.init(
                id: "ev_development",
                kind: .boardEffect,
                detail: "early_piece_left_home_camp",
                supportedIntent: .development,
                weight: 38
            ))
        }

        if Self.preparesContestedExchange(
            effect: currentEffect,
            before: beforeCurrent,
            after: afterCurrent
        ) {
            evidence.append(.init(
                id: "ev_exchange_preparation",
                kind: .boardEffect,
                detail: "new_attack_on_defended_enemy_piece",
                supportedIntent: .exchangePreparation,
                weight: 62
            ))
        }

        let hasCausalResponse = evidence.contains { $0.kind == .previousMoveCausality }
        if let previousEffect,
           previousEffect.side == opponent,
           !newlyAttackedFromPrevious.isEmpty,
           !hasCausalResponse,
           Self.chebyshevDistance(previousEffect.destination, currentEffect.destination) >= 4 {
            evidence.append(.init(
                id: "ev_tenuki",
                kind: .previousMoveCausality,
                detail: "concrete_local_threat_ignored_for_distant_move",
                supportedIntent: .tenuki,
                weight: 68
            ))
        }

        if let source = currentEffect.source,
           let opponentKing = Self.kingSquare(side: opponent, snapshot: beforeCurrent) {
            let beforeDistance = Self.chebyshevDistance(source, opponentKing)
            let afterDistance = Self.chebyshevDistance(currentEffect.destination, opponentKing)
            if afterDistance < beforeDistance {
                evidence.append(.init(
                    id: "ev_geometry_toward_king",
                    kind: .geometry,
                    detail: "distance:\(beforeDistance)->\(afterDistance)",
                    supportedIntent: .attackPreparation,
                    weight: 10
                ))
            }
        }

        let rawKnowledgeAnchor = Self.strongestKnowledgeAnchor(from: evidence)
        for item in knowledgeProvider.evidence(positionCommand: positionCommand, move: move) {
            guard item.kind == .openingBook || item.kind == .precedent else { continue }

            let supportedIntent: MoveIntent
            let detail: String
            if item.intent == .unresolved {
                guard let rawKnowledgeAnchor else { continue }
                supportedIntent = rawKnowledgeAnchor
                detail = "raw_knowledge_reinforces=\(rawKnowledgeAnchor.rawValue);\(item.detail)"
            } else {
                supportedIntent = item.intent
                detail = item.detail
            }

            evidence.append(.init(
                id: "knowledge_\(item.sourceID)",
                kind: item.kind,
                detail: detail,
                supportedIntent: supportedIntent,
                weight: max(0, item.weight)
            ))
        }

        if let engineEvidence {
            facts.append(.init(
                id: "engine_comparison",
                kind: .engineComparison,
                detail: "best=\(engineEvidence.bestMove),actual=\(engineEvidence.actualMove),loss=\(engineEvidence.actualLossCp.map(String.init) ?? "-")"
            ))
            if engineEvidence.comparisonStable {
                outcomes.append(.init(
                    id: "engine_comparison_stable",
                    detail: engineEvidence.bestMove == move ? "best_move_match" : "alternative_exists"
                ))
            }
        }

        if let engineEvidence,
           engineEvidence.comparisonStable,
           engineEvidence.actualMove == move,
           let engineAnchor = ContextIntentResolver.strongestEngineAnchor(from: evidence) {
            let engineWeight = engineEvidence.bestMove == move ? 12 : 8
            let id = engineEvidence.bestMove == move ? "ev_engine_best_match" : "ev_engine_actual_line"
            evidence.append(.init(
                id: id,
                kind: .enginePV,
                detail: engineEvidence.bestMove == move ? "stable_best_move_match" : "stable_actual_move_line",
                supportedIntent: engineAnchor,
                weight: engineWeight
            ))
            if engineEvidence.bestMove != move {
                evidence.append(.init(
                    id: "ev_counterfactual_alternative",
                    kind: .counterfactual,
                    detail: "best=\(engineEvidence.bestMove),actual=\(move),loss=\(engineEvidence.actualLossCp.map(String.init) ?? "-")",
                    supportedIntent: engineAnchor,
                    weight: 0
                ))
            }
        }

        let resolution = ContextIntentResolver.resolve(evidence: evidence)

        return MoveContextAnalysis(
            move: move,
            previousMove: previousMove,
            facts: facts,
            contextChanges: contextChanges,
            effects: effects,
            outcomes: outcomes,
            intentCandidates: resolution.candidates,
            selectedIntent: resolution.selectedIntent,
            confidence: resolution.confidence,
            evidence: evidence
        )
    }

    private static func strongestKnowledgeAnchor(from evidence: [ContextEvidence]) -> MoveIntent? {
        var grouped: [MoveIntent: Int] = [:]
        for item in evidence {
            guard item.kind != .geometry,
                  item.kind != .openingBook,
                  item.kind != .precedent,
                  item.supportedIntent != .unresolved else { continue }
            grouped[item.supportedIntent, default: 0] += max(0, item.weight)
        }
        let ranked = grouped.sorted {
            if $0.value == $1.value { return $0.key.rawValue < $1.key.rawValue }
            return $0.value > $1.value
        }
        guard let first = ranked.first, first.value >= 30 else { return nil }
        if ranked.count > 1, ranked[1].value == first.value { return nil }
        return first.key
    }

    private struct Attacker {
        let square: BoardCoordinate
        let piece: BoardPieceState
    }

    private static func historyMoves(_ positionCommand: String) throws -> [String] {
        let tokens = positionCommand.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 2, tokens[0] == "position", tokens[1] == "startpos" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }
        if tokens.count == 2 { return [] }
        guard tokens.count >= 4, tokens[2] == "moves" else {
            throw BoardSnapshotError.unsupportedPosition(positionCommand)
        }
        return Array(tokens.dropFirst(3))
    }

    private static func positionCommand(moves: [String]) -> String {
        moves.isEmpty ? "position startpos" : "position startpos moves " + moves.joined(separator: " ")
    }

    private static func opponent(of side: ShogiSide) -> ShogiSide {
        side == .black ? .white : .black
    }

    private static func nextForwardSquare(from square: BoardCoordinate, side: ShogiSide) -> BoardCoordinate? {
        let rank = square.rank + (side == .black ? -1 : 1)
        guard (1...9).contains(rank) else { return nil }
        return BoardCoordinate(file: square.file, rank: rank)
    }

    private static func hasAlignedRookBehindPawn(effect: MoveEffect, snapshot: BoardSnapshot) -> Bool {
        snapshot.squares.contains { square, piece in
            guard piece.side == effect.side,
                  piece.kind == .rook || piece.kind == .dragon,
                  square.file == effect.destination.file else { return false }
            return clearPath(from: square, to: effect.destination, snapshot: snapshot)
        }
    }

    private static func sourceAlreadyControlled(
        target: BoardCoordinate,
        effect: MoveEffect,
        snapshot: BoardSnapshot
    ) -> Bool {
        guard let source = effect.source,
              let piece = snapshot.piece(at: source) else { return false }
        return attacks(from: source, piece: piece, target: target, snapshot: snapshot)
    }

    private static func newlyAttackedFriendlySquares(
        side: ShogiSide,
        before: BoardSnapshot,
        after: BoardSnapshot
    ) -> Set<BoardCoordinate> {
        let opponent = opponent(of: side)
        var result: Set<BoardCoordinate> = []
        for (square, piece) in after.squares where piece.side == side {
            let wasAttacked = before.piece(at: square)?.side == side
                && isSquareAttacked(square, by: opponent, snapshot: before)
            let isAttacked = isSquareAttacked(square, by: opponent, snapshot: after)
            if !wasAttacked && isAttacked {
                result.insert(square)
            }
        }
        return result
    }

    private static func kingSquare(side: ShogiSide, snapshot: BoardSnapshot) -> BoardCoordinate? {
        snapshot.squares.first { $0.value.side == side && $0.value.kind == .king }?.key
    }

    private static func attackers(
        of target: BoardCoordinate,
        by side: ShogiSide,
        snapshot: BoardSnapshot
    ) -> [Attacker] {
        snapshot.squares.compactMap { square, piece in
            guard piece.side == side,
                  attacks(from: square, piece: piece, target: target, snapshot: snapshot) else { return nil }
            return Attacker(square: square, piece: piece)
        }
    }

    private static func isSquareAttacked(
        _ target: BoardCoordinate,
        by side: ShogiSide,
        snapshot: BoardSnapshot
    ) -> Bool {
        !attackers(of: target, by: side, snapshot: snapshot).isEmpty
    }

    private static func kingZonePressure(
        attackingSide: ShogiSide,
        kingSide: ShogiSide,
        snapshot: BoardSnapshot
    ) -> Int {
        guard let king = kingSquare(side: kingSide, snapshot: snapshot) else { return 0 }
        var pressure = 0
        for file in max(1, king.file - 1)...min(9, king.file + 1) {
            for rank in max(1, king.rank - 1)...min(9, king.rank + 1) {
                let square = BoardCoordinate(file: file, rank: rank)
                if isSquareAttacked(square, by: attackingSide, snapshot: snapshot) {
                    pressure += 1
                }
            }
        }
        return pressure
    }

    private static func kingZoneControlCount(
        side: ShogiSide,
        kingSide: ShogiSide,
        snapshot: BoardSnapshot
    ) -> Int {
        guard let king = kingSquare(side: kingSide, snapshot: snapshot) else { return 0 }
        var controls = 0
        for file in max(1, king.file - 1)...min(9, king.file + 1) {
            for rank in max(1, king.rank - 1)...min(9, king.rank + 1) {
                controls += controlCount(
                    BoardCoordinate(file: file, rank: rank),
                    by: side,
                    snapshot: snapshot
                )
            }
        }
        return controls
    }

    private static func controlCount(
        _ target: BoardCoordinate,
        by side: ShogiSide,
        snapshot: BoardSnapshot
    ) -> Int {
        snapshot.squares.reduce(into: 0) { count, entry in
            if entry.value.side == side,
               controls(from: entry.key, piece: entry.value, target: target, snapshot: snapshot) {
                count += 1
            }
        }
    }

    private static func isHomeCamp(_ square: BoardCoordinate, side: ShogiSide) -> Bool {
        side == .black ? square.rank >= 7 : square.rank <= 3
    }

    private static func kingEscapeSquareCount(
        kingSide: ShogiSide,
        attackingSide: ShogiSide,
        snapshot: BoardSnapshot
    ) -> Int {
        guard let king = kingSquare(side: kingSide, snapshot: snapshot) else { return 0 }
        var count = 0
        for file in max(1, king.file - 1)...min(9, king.file + 1) {
            for rank in max(1, king.rank - 1)...min(9, king.rank + 1) {
                let target = BoardCoordinate(file: file, rank: rank)
                guard target != king else { continue }
                if let occupant = snapshot.piece(at: target), occupant.side == kingSide {
                    continue
                }
                if !isSquareAttacked(target, by: attackingSide, snapshot: snapshot) {
                    count += 1
                }
            }
        }
        return count
    }

    private static func preparesContestedExchange(
        effect: MoveEffect,
        before: BoardSnapshot,
        after: BoardSnapshot
    ) -> Bool {
        guard !effect.isDrop,
              let movedPiece = after.piece(at: effect.destination) else { return false }
        let opponent = opponent(of: effect.side)
        for (target, targetPiece) in after.squares
        where targetPiece.side == opponent && targetPiece.kind != .king {
            let attacksAfter = attacks(
                from: effect.destination,
                piece: movedPiece,
                target: target,
                snapshot: after
            )
            guard attacksAfter else { continue }

            let attackedBefore: Bool
            if let source = effect.source, let beforePiece = before.piece(at: source) {
                attackedBefore = attacks(
                    from: source,
                    piece: beforePiece,
                    target: target,
                    snapshot: before
                )
            } else {
                attackedBefore = false
            }
            if !attackedBefore,
               controlCount(target, by: opponent, snapshot: after) > 0 {
                return true
            }
        }
        return false
    }

    private static func attackCount(from square: BoardCoordinate, snapshot: BoardSnapshot) -> Int {
        guard let piece = snapshot.piece(at: square) else { return 0 }
        var count = 0
        for file in 1...9 {
            for rank in 1...9 {
                let target = BoardCoordinate(file: file, rank: rank)
                if target == square { continue }
                if attacks(from: square, piece: piece, target: target, snapshot: snapshot) {
                    count += 1
                }
            }
        }
        return count
    }

    private static func attacks(
        from: BoardCoordinate,
        piece: BoardPieceState,
        target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        if let occupant = snapshot.piece(at: target), occupant.side == piece.side { return false }
        return controls(from: from, piece: piece, target: target, snapshot: snapshot)
    }

    private static func controls(
        from: BoardCoordinate,
        piece: BoardPieceState,
        target: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let dx = target.file - from.file
        let dy = target.rank - from.rank
        guard dx != 0 || dy != 0 else { return false }
        let ax = abs(dx)
        let forward = piece.side == .black ? -dy : dy

        switch piece.kind {
        case .pawn:
            return dx == 0 && forward == 1
        case .lance:
            return dx == 0 && forward > 0 && clearPath(from: from, to: target, snapshot: snapshot)
        case .knight:
            return ax == 1 && forward == 2
        case .silver:
            return (forward == 1 && ax <= 1) || (forward == -1 && ax == 1)
        case .gold, .promotedPawn, .promotedLance, .promotedKnight, .promotedSilver:
            return (forward == 1 && ax <= 1)
                || (forward == 0 && ax == 1)
                || (forward == -1 && dx == 0)
        case .king:
            return ax <= 1 && abs(dy) <= 1
        case .bishop:
            return ax == abs(dy) && clearPath(from: from, to: target, snapshot: snapshot)
        case .rook:
            return (dx == 0 || dy == 0) && clearPath(from: from, to: target, snapshot: snapshot)
        case .horse:
            if ax == abs(dy) { return clearPath(from: from, to: target, snapshot: snapshot) }
            return (ax == 1 && dy == 0) || (dx == 0 && abs(dy) == 1)
        case .dragon:
            if dx == 0 || dy == 0 { return clearPath(from: from, to: target, snapshot: snapshot) }
            return ax == 1 && abs(dy) == 1
        }
    }

    private static func clearPath(
        from: BoardCoordinate,
        to: BoardCoordinate,
        snapshot: BoardSnapshot
    ) -> Bool {
        let stepFile = (to.file - from.file).signum()
        let stepRank = (to.rank - from.rank).signum()
        var current = BoardCoordinate(file: from.file + stepFile, rank: from.rank + stepRank)
        while current != to {
            if snapshot.piece(at: current) != nil { return false }
            current = BoardCoordinate(file: current.file + stepFile, rank: current.rank + stepRank)
        }
        return true
    }

    private static func chebyshevDistance(_ lhs: BoardCoordinate, _ rhs: BoardCoordinate) -> Int {
        max(abs(lhs.file - rhs.file), abs(lhs.rank - rhs.rank))
    }
}
