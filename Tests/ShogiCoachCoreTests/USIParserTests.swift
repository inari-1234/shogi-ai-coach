import Testing
@testable import ShogiCoachCore

@Test func parsesCentipawnInfo() {
    let line = "info depth 18 seldepth 27 multipv 2 score cp 348 nodes 123456 nps 987654 time 125 pv 6g6f 8c8d 6f6e"
    let info = USIParser.parseInfo(line)
    #expect(info?.depth == 18)
    #expect(info?.selDepth == 27)
    #expect(info?.multipv == 2)
    #expect(info?.score == .centipawn(348, bound: nil))
    #expect(info?.nodes == 123456)
    #expect(info?.nps == 987654)
    #expect(info?.timeMs == 125)
    #expect(info?.pv == ["6g6f", "8c8d", "6f6e"])
}

@Test func parsesMateAndBound() {
    let info = USIParser.parseInfo("info depth 24 score mate -5 upperbound pv 5a4b")
    #expect(info?.score == .mate(-5, bound: .upper))
}

@Test func parsesBestMoveAndPonder() {
    let best = USIParser.parseBestMove("bestmove 6g6f ponder 8c8d")
    #expect(best == USIBestMove(move: "6g6f", ponder: "8c8d"))
}

@Test func accumulatorKeepsDeepestPV() {
    var acc = USIAccumulator()
    #expect(acc.consume("info depth 8 multipv 1 score cp 50 time 10 pv 7g7f") == nil)
    #expect(acc.consume("info depth 12 multipv 1 score cp 80 time 30 pv 2g2f") == nil)
    #expect(acc.consume("info depth 10 multipv 2 score cp 40 time 31 pv 7g7f") == nil)
    let result = acc.consume("bestmove 2g2f")
    #expect(result?.bestMove.move == "2g2f")
    #expect(result?.principalVariations.count == 2)
    #expect(result?.principalVariations[0].depth == 12)
    #expect(result?.principalVariations[0].pv.first == "2g2f")
}

@Test func ignoresEngineStringInfo() {
    let info = USIParser.parseInfo("info string NNUE evaluation loaded")
    #expect(info != nil)
    #expect(info?.pv.isEmpty == true)
}

@Test func parsesLowerBoundWithoutLosingPV() {
    let info = USIParser.parseInfo("info depth 20 score cp 120 lowerbound nodes 99 pv 2g2f 8c8d")
    #expect(info?.score == .centipawn(120, bound: .lower))
    #expect(info?.nodes == 99)
    #expect(info?.pv == ["2g2f", "8c8d"])
}

@Test func parsesVE1BFinalNodeTelemetryAsScorelessObservation() {
    let line = "info nodes 100123 string ve1b_final_nodes"
    let info = USIParser.parseInfo(line)
    #expect(info?.nodes == 100123)
    #expect(info?.score == nil)
    #expect(info?.pv.isEmpty == true)
    #expect(info?.rawLine == line)
}

@Test func bestMoveResignIsPreserved() {
    #expect(USIParser.parseBestMove("bestmove resign")?.move == "resign")
}
