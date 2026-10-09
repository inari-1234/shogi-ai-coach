# Build19-VE1-A — Formal PASS Record

Date: 2026-10-10
Formal candidate commit: `3252adb0fb5a066fc90362d978eec7f196f62135`
Status: **PASS**

## Physical iPhone known-answer evidence

Device:
- model identifier: `iPhone17,1`
- OS: `iOS 26.7.1`
- app version: `0.8.3`
- app build: `16`
- tested Git commit: `3252adb0fb5a066fc90362d978eec7f196f62135`
- bundled NNUE SHA-256: `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`

Known-answer probes:

1. Start position
   - `position startpos`
   - `go depth 1`
   - `Threads=1`, `MultiPV=1`, `FV_SCALE=24`
   - expected / actual: `cp 108`
   - expected / actual bestmove: `7g7f`
   - actual depth: `1`

2. Corrected C1 effective position
   - `position sfen lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8`
   - `go depth 1`
   - `Threads=1`, `MultiPV=1`, `FV_SCALE=24`
   - expected / actual: `cp 157`
   - expected / actual bestmove: `2b7g+`
   - actual depth: `1`

`mismatch_count=0`.

The raw physical-device transcript retained `setoption name FV_SCALE value 24`, `EvalDir`, `isready`/`readyok`, final score-bearing `info` lines and `bestmove` lines. The bundled path and SHA-256 provenance were retained. Expected values were not modified.

## Automated same-commit evidence

The final VE1-A candidate commit also passed the required automated gates:
- Build19 VE1-A Runtime Verify;
- iOS Simulator E2E;
- iOS Device Build / IPA packaging;
- Build19 HDS Contract Evidence;
- Core regression tests and cp-impact inventory.

The cp-impact audit is closed for VE1-A as an inventory/classification gate. FV24 semantic threshold recalibration remains explicitly assigned to VE1-C; historical FV16 values were not mechanically rescaled.

## BookFile note carried to VE1-B

The physical transcript contained `Error! : can't read file : book/standard_book.db`. This did not affect the VE1-A known-answer verdict because no opening book was successfully loaded and both pinned known answers matched exactly.

However, production app analysis did not explicitly send `BookFile=no_book`, while verification harness paths did. VE1-B therefore must align production and harness configuration by explicitly disabling opening-book use and retaining the setting in raw evidence. This is a VE1-B hardening requirement, not a reopening of VE1-A.

## Boundaries preserved

- VE1-B implementation not started by this record.
- VE1-C threshold recalibration not started.
- HDS-H and Build20 not started.
- Historical 41/49/69 remains a diagnostic contract, not Semantic Authority.
