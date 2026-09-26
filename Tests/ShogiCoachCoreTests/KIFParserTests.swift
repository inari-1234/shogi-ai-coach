import Foundation
import Testing
@testable import ShogiCoachCore

private let openingKIF = """
#KIF version=2.0 encoding=UTF-8
開始日時：2026/09/26 19:00:00
手合割：平手
先手：先手
後手：後手
手数----指手---------消費時間--
   1 ７六歩(77)   ( 0:01/00:00:01)
   2 ３四歩(33)   ( 0:01/00:00:01)
   3 ２六歩(27)   ( 0:01/00:00:02)
   4 ８四歩(83)   ( 0:01/00:00:02)
   5 ２五歩(26)   ( 0:01/00:00:03)
   6 ８五歩(84)   ( 0:01/00:00:03)
   7 ７八金(69)   ( 0:01/00:00:04)
   8 ３二金(41)   ( 0:01/00:00:04)
   9 投了
まで8手で後手の勝ち
"""

@Test func parsesCommonUTF8KIF() throws {
    let game = try KIFParser.parse(openingKIF)
    #expect(game.moves.count == 8)
    #expect(game.moves.map(\.usi) == [
        "7g7f", "3c3d", "2g2f", "8c8d",
        "2f2e", "8d8e", "6i7h", "4a3b"
    ])
    #expect(game.metadata["手合割"] == "平手")
    #expect(game.termination == "投了")
    #expect(game.moves[0].positionBefore == "position startpos")
    #expect(game.moves[3].positionBefore == "position startpos moves 7g7f 3c3d 2g2f")
    #expect(game.finalPositionCommand.hasSuffix("6i7h 4a3b"))
}

@Test func parsesSameSquareCapture() throws {
    let kif = """
手合割：平手
手数----指手---------消費時間--
1 ７六歩(77)
2 ３四歩(33)
3 ２六歩(27)
4 ８四歩(83)
5 ２五歩(26)
6 ８五歩(84)
7 ２四歩(25)
8 同　歩(23)
9 同　飛(28)
10 投了
"""
    let game = try KIFParser.parse(kif)
    #expect(game.moves.suffix(3).map(\.usi) == ["2e2d", "2c2d", "2h2d"])
}

@Test func parsesRealWorldStyleCapturePromotionAndDrops() throws {
    let kif = """
#KIF version=2.0 encoding=Shift_JIS
手合割：平手　　
手数----指手---------消費時間--
1 ７六歩(77) ( 0:00/00:00:00)
2 ３四歩(33) ( 0:00/00:00:00)
3 ２六歩(27) ( 0:00/00:00:00)
4 ５四歩(53) ( 0:00/00:00:00)
5 ２五歩(26) ( 0:00/00:00:00)
6 ５二飛(82) ( 0:00/00:00:00)
*基本図
7 ５八金(49) ( 0:00/00:00:00)
8 ５五歩(54) ( 0:00/00:00:00)
9 ２四歩(25) ( 0:00/00:00:00)
10 同　歩(23) ( 0:00/00:00:00)
11 同　飛(28) ( 0:00/00:00:00)
12 ５六歩(55) ( 0:00/00:00:00)
13 同　歩(57) ( 0:00/00:00:00)
14 ８八角成(22) ( 0:00/00:00:00)
15 同　銀(79) ( 0:00/00:00:00)
16 ３三角打 ( 0:00/00:00:00)
17 ２一飛成(24) ( 0:00/00:00:00)
18 ８八角成(33) ( 0:00/00:00:00)
19 ５五桂打 ( 0:00/00:00:00)
20 ６二玉(51) ( 0:00/00:00:00)
21 １一龍(21) ( 0:00/00:00:00)
22 投了 ( 0:03/ 0:00:03)
"""
    let game = try KIFParser.parse(kif)
    #expect(game.moves.count == 21)
    #expect(game.moves[9].usi == "2c2d")
    #expect(game.moves[10].usi == "2h2d")
    #expect(game.moves[13].usi == "2b8h+")
    #expect(game.moves[15].usi == "B*3c")
    #expect(game.moves[16].usi == "2d2a+")
    #expect(game.moves[18].usi == "N*5e")
    #expect(game.moves[20].usi == "2a1a")
    #expect(game.termination == "投了")
}

@Test func rejectsHandicapForPhase2() {
    #expect(throws: KIFParseError.self) {
        _ = try KIFParser.parse("手合割：香落ち\n1 ７六歩(77)\n")
    }
}

@Test func rejectsBrokenMoveSequence() {
    #expect(throws: KIFParseError.self) {
        _ = try KIFParser.parse("手合割：平手\n1 ７六歩(77)\n3 ３四歩(33)\n")
    }
}

@Test func decodesUTF8BOM() throws {
    let bytes = Data([0xEF, 0xBB, 0xBF]) + Data(openingKIF.utf8)
    let game = try KIFParser.parse(data: bytes)
    #expect(game.moves.count == 8)
}

@Test func decodesShiftJISKIF() throws {
    let text = "手合割：平手\n1 ７六歩(77)\n2 ３四歩(33)\n3 投了\n"
    guard let data = text.data(using: .shiftJIS) else {
        Issue.record("Shift-JIS encoding unavailable on test platform")
        return
    }
    let game = try KIFParser.parse(data: data)
    #expect(game.moves.map(\.usi) == ["7g7f", "3c3d"])
}

@Test func detectsBlockedSlidingMove() {
    #expect(throws: KIFParseError.self) {
        _ = try KIFParser.parse("手合割：平手\n1 ２二角成(88)\n")
    }
}

@Test func ignoresVariationAfterMainLine() throws {
    let kif = """
手合割：平手
1 ７六歩(77)
2 ３四歩(33)
変化：2手
2 ８四歩(83)
3 ２六歩(27)
"""
    let game = try KIFParser.parse(kif)
    #expect(game.moves.map(\.usi) == ["7g7f", "3c3d"])
}
