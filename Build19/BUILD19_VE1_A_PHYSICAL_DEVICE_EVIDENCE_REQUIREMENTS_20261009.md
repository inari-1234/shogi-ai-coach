# Build19-VE1-A Physical Device Evidence Requirements — 2026-10-09

Status: **REQUIRED / NOT YET OBSERVED ON PHYSICAL IPHONE**

Device Build / IPA success is not physical-device runtime evidence.

## Required known-answer probes

Run both probes with FV_SCALE=24 and the pinned bundled NNUE.

1. Start position
   - command: `position startpos`
   - search: `go depth 1`
   - expected: `cp 108`
   - expected bestmove: `7g7f`

2. Corrected C1 effective position
   - SFEN: `lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8`
   - search: `go depth 1`
   - expected: `cp 157`
   - expected bestmove: `2b7g+`

## Evidence to retain

- raw USI transcript from engine initialization through each `bestmove`;
- the `setoption name FV_SCALE value 24` line;
- evidence identifying/loading the NNUE file;
- final relevant `info` line(s) containing the score;
- `bestmove` line;
- iPhone model;
- iOS version;
- app version/build number;
- bundled `nn.bin` SHA-256.

Pinned bundled NNUE SHA-256:
`768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`

A mismatch is an investigation condition. Do not change the expected values to fit a device result.
