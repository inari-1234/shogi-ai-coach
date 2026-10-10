import Testing
@testable import ShogiCoachCore

@Test func ve1bScoredObservationSurvivesLaterScorelessInfo() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 12 seldepth 18 multipv 1 score cp 80 nodes 1000 time 10 pv 2g2f 8c8d")
    _ = accumulator.consume("info depth 13 seldepth 30 multipv 1 nodes 1500 time 20 pv 7g7f 8c8d")

    let result = accumulator.consume("bestmove 2g2f")
    let primary = result?.principalVariations.first

    #expect(primary?.score == .centipawn(80, bound: nil))
    #expect(primary?.depth == 12)
    #expect(primary?.selDepth == 18)
    #expect(primary?.nodes == 1000)
    #expect(primary?.pv == ["2g2f", "8c8d"])
    #expect(result?.observations.count == 2)
    #expect(result?.observations.last?.score == nil)
    #expect(result?.bestMoveConsistency == .consistent)
}

@Test func ve1bLaterScoredObservationReplacesEarlierScorelessInfo() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 10 multipv 1 nodes 800 pv 7g7f")
    _ = accumulator.consume("info depth 10 multipv 1 score cp 42 nodes 900 pv 2g2f")

    let result = accumulator.consume("bestmove 2g2f")
    #expect(result?.principalVariations.first?.score == .centipawn(42, bound: nil))
    #expect(result?.principalVariations.first?.pv.first == "2g2f")
}

@Test func ve1bMultiPVScorelessUpdateDoesNotCorruptOtherCandidate() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 14 multipv 1 score cp 100 nodes 1000 pv 2g2f")
    _ = accumulator.consume("info depth 14 multipv 2 score cp 60 nodes 1000 pv 7g7f")
    _ = accumulator.consume("info depth 15 multipv 1 nodes 1300 pv 6i7h")

    let result = accumulator.consume("bestmove 2g2f")
    #expect(result?.principalVariations.count == 2)
    #expect(result?.principalVariations[0].pv.first == "2g2f")
    #expect(result?.principalVariations[1].pv.first == "7g7f")
    #expect(result?.principalVariations[1].score == .centipawn(60, bound: nil))
}

@Test func ve1bDeeperBoundRemainsBoundedAtTargetInsteadOfPromotingShallowExact() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 12 multipv 1 score cp 70 nodes 1000 pv 2g2f")
    _ = accumulator.consume("info depth 16 multipv 1 score cp 95 lowerbound nodes 3000 pv 2g2f 8c8d")

    let result = accumulator.consume("bestmove 2g2f")
    let primary = result?.principalVariations.first
    #expect(primary?.depth == 16)
    #expect(primary?.score == .centipawn(95, bound: .lower))
    #expect(primary?.boundKind == .lowerbound)
    #expect(result?.observations.first?.boundKind == .exact)
    #expect(result?.observations.last?.boundKind == .lowerbound)
}

@Test func ve1bExactWinsAgainstBoundAtSameDepth() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 18 multipv 1 score cp 120 nodes 3000 pv 2g2f")
    _ = accumulator.consume("info depth 18 multipv 1 score cp 130 lowerbound nodes 4000 pv 7g7f")
    _ = accumulator.consume("info depth 18 multipv 1 score cp 125 nodes 3500 pv 2g2f 8c8d")

    let result = accumulator.consume("bestmove 2g2f")
    #expect(result?.principalVariations.first?.score == .centipawn(125, bound: nil))
    #expect(result?.principalVariations.first?.pv.first == "2g2f")
}

@Test func ve1bUpperBoundIsPreservedAsUncertainEvidence() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 20 seldepth 31 multipv 1 score cp -44 upperbound nodes 9000 nps 50000 pv 7g7f 3c3d")

    let result = accumulator.consume("bestmove 7g7f")
    let primary = result?.principalVariations.first
    #expect(primary?.boundKind == .upperbound)
    #expect(primary?.selDepth == 31)
    #expect(primary?.nps == 50000)
    #expect(primary?.rawLine?.contains("upperbound") == true)
}

@Test func ve1bBestMoveMismatchIsExplicitAndNotSilentlyNormal() {
    var accumulator = USIAccumulator()
    _ = accumulator.consume("info depth 18 multipv 1 score cp 90 nodes 5000 pv 2g2f 8c8d")

    let result = accumulator.consume("bestmove 7g7f")
    #expect(result?.bestMove.move == "7g7f")
    #expect(result?.principalVariations.first?.pv.first == "2g2f")
    #expect(result?.bestMoveConsistency == .inconsistent)
}

@Test func ve1bRawObservationOrderAndFieldsAreLossless() {
    let first = "info depth 10 seldepth 15 multipv 2 score mate -5 upperbound nodes 1234 nps 5678 time 9 pv 5a4b 4c4d"
    let second = "info depth 11 multipv 2 nodes 2000 time 12 pv 5a4b"
    var accumulator = USIAccumulator()
    _ = accumulator.consume(first)
    _ = accumulator.consume(second)

    let result = accumulator.consume("bestmove 5a4b")
    #expect(result?.observations.map(\.rawLine) == [first, second])
    #expect(result?.observations[0].score == .mate(-5, bound: .upper))
    #expect(result?.observations[0].depth == 10)
    #expect(result?.observations[0].selDepth == 15)
    #expect(result?.observations[0].nodes == 1234)
    #expect(result?.observations[0].nps == 5678)
    #expect(result?.observations[0].pv == ["5a4b", "4c4d"])
}
