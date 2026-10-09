# Build19-VE1-Q C1 Review Correction — 2026-10-09

Status: **CORRECTION AUTHORITY FOR VE1-Q C1 INPUTS ONLY**

This record corrects the source description for the review-side FV_SCALE observation `FV16=cp236 / FV24=cp157`.

## Original review-side command

Relevant engine settings:

- Threads = 1
- MultiPV = 1
- FV_SCALE = 16 or 24, depending on the run

Search commands:

```text
position startpos moves 7g7f 3c3d 2g2f 8c8d 2f2e 4a3b 8h7g 3c3d
go depth 1
```

The final move `3c3d` is illegal because the pawn on 3c already moved on move 2. YaneuraOu emitted:

```text
Illegal Input Move : 3c3d
```

The warning was overlooked during the original review. The engine therefore evaluated the position after the first seven legal moves.

## Correct effective position

The corrected effective position is the following SFEN, with White to move:

```text
lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8
```

Formal qualification must address it directly as:

```text
setoption name Threads value 1
setoption name MultiPV value 1
setoption name FV_SCALE value <16-or-24>
position sfen lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8
go depth 1
```

Expected rank-1 result:

- FV_SCALE 16: `score cp 236`, bestmove `2b7g+`
- FV_SCALE 24: `score cp 157`, bestmove `2b7g+`

These values are not semantic shogi truth labels. They are deterministic runtime calibration expectations for the pinned engine/NNUE qualification environment.

## Independent second calibration

The ordinary start position is also a formal C1 runtime calibration:

```text
setoption name Threads value 1
setoption name MultiPV value 1
setoption name FV_SCALE value <16-or-24>
position startpos
go depth 1
```

Expected rank-1 result:

- FV_SCALE 16: `score cp 164`, bestmove `7g7f`
- FV_SCALE 24: `score cp 108`, bestmove `7g7f`

The reviewer independently re-ran these values, and the VE1-Q CI environment previously reproduced the same 164/108 pair. Formal C1 acceptance still requires fresh raw USI logs in the final qualifying run.

## Scale invariant

Each calibration must also satisfy the expectation-independent check:

```text
abs(cp(FV16) * 16 - cp(FV24) * 24) <= 40
```

For the two corrected calibrations:

- startpos: `164*16=2624`, `108*24=2592`, delta 32
- corrected SFEN: `236*16=3776`, `157*24=3768`, delta 8

## Authority boundary

This correction does not establish Build20, HDS-H, production FV_SCALE authority, production node budgets, or new 41/49/69 Semantic Authority. It only repairs the provenance of the C1 calibration inputs.
