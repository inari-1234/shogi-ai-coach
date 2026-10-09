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
- evidence identifying/loading the NNUE file, including `EvalDir`, initialization output, bundled path and SHA-256;
- final relevant `info` line(s) containing the score;
- `bestmove` line;
- iPhone hardware model identifier;
- iOS version;
- app version/build number;
- tested Git commit;
- bundled `nn.bin` SHA-256.

Pinned bundled NNUE SHA-256:
`768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`

## Mismatch policy

Any mismatch or missing provenance keeps **VE1-A = HOLD / NOT PASS**.

- Do not change `108`, `157`, `7g7f`, `2b7g+`, the pinned SFEN, FV_SCALE, or the pinned NNUE SHA to fit a device result.
- Preserve and share the raw device evidence before changing implementation.
- Investigate runtime provenance, bundled NNUE identity/loading, FV_SCALE/options, exact position input, depth, parser/accumulator behavior, and architecture/runtime differences.
- Only a fresh physical-device rerun that matches the unchanged authority may clear the HOLD.
