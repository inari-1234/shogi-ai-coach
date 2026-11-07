# Build19 VE1-C1 — omitted non-promotion searchmoves fail-closed policy

Date: 2026-11-08
State: **C1 PRE-FREEZE FAIL-CLOSED DECISION / REGRESSION PASS / AWAIT FREEZE AUTHORITY**
Scope owner: C1 semantic comparator/evaluator; **not** VE1-B unrestricted search or frozen pilot thresholds.

## Prior authority and incident

This resolves the explicitly OPEN choice in the *already preregistered* `BUILD19_VE1_B_ERRATA_LOW_LEGAL_MOVES_CORRECTIVE_20261015.md` §9. Default YaneuraOu `MoveList<LEGAL>` may omit optional non-promotions present in `LEGAL_ALL`.

- Root fixture: `tools/engine-verify/fixtures/ve1b_low_legal_corrective.json`, `legal-2-legal-all-3-rook-nonpromotion-boundary`.
- Pinned engine/NNUE verification: C1 Pilot Controls run `42425517284`, code SHA `f0f86b7fe6a18fdd3457a99875a5edddf25fb90d`, evidence artifact `13595611158` (ZIP SHA-256 `77e79628f64812baac18381e784fc634db0d71f95430c5fea94acf6bad4183ab`).
- `go nodes 50000 searchmoves 3c1c` requested legal but omitted non-promotion; engine returned **`bestmove 1i2i`**, and its scored rank-1 PV also began with `1i2i`. This silently used a different move.
- Control `searchmoves 3c1c+` returned `bestmove 3c1c+`, rank-1 PV `3c1c+`; unrestricted returned `1i2i`.
- The already frozen natural C1 pilot run `42413155051` is **PILOT_PASS** at `637213c`, 16 positions and 240 searches. Independent inspection of its archived result found **0 mismatches among 160 single-target `searchmoves` attempts**, so its F2/E0 evidence is not retroactively invalidated.

## Selected policy — option A from preregistered §9

**Fail closed as `NOT_CLASSIFIABLE`. No comparison-only `LEGAL_ALL` expansion.**

For any C1 independent single-target `searchmoves(X)` measurement, require both:
1. Returned terminal `bestmove` is exactly `X`.
2. Selected exact rank-1 PV's root is exactly `X`.

Missing/insufficient evidence, a different `bestmove`, or a different PV root must not be treated as the requested move's score. Classify the affected C1 played move as `NOT_CLASSIFIABLE`, with `SEARCHMOVES_TARGET_MISMATCH` provenance (or unresolved missing evidence); do not issue definite severity, MATCH, or H3/H4 Reference good-set membership on that measurement. Omit such cases from F2/E1 evidence-based adoption denominators rather than converting them into favorable cases. Preserve raw USI, requested target, returned move, PV, node tier, TT boundary and engine provenance. No silent move substitution.

For unrestricted root search, VE1-B Errata #2's `min(configuredMultiPV, |MoveList<LEGAL>|)` rule remains unchanged. Do not alter `GenerateAllLegalMoves` globally. Do not change `k`, score thresholds, node budgets, F2/E0 selection rules, C1 §13.1 PASS semantics, or frozen manifest.

## Mandatory regression boundary before C1 Freeze

- A synthetic C1 evaluator regression with requested `3c1c` but returned `1i2i` must be `NOT_CLASSIFIABLE`, with no false inversion/F2 candidate or false Reference membership.
- A correctly bound `3c1c+` control retains an evaluable exact result.
- Replay the immutable 16-position natural pilot result artifact under the new **C1-only** target-binding guard; require 160/160 target bindings valid and F2/E0 unchanged. This replay does not change the original pilot result/evaluation SHA or redefine `PILOT_PASS`.
- **PASS**: C1 Pilot Contract workflow `42426046533` at code SHA `274e7fe5415b32bbc3f8e19a0fdc50b74ed447f8`. All 26 unit tests passed, including omitted `3c1c` -> `1i2i` fail-closed classification, retained `3c1c+` control, no false F2 case and no spurious inversion display.
- **PASS**: the same workflow downloaded the immutable natural-pilot artifact `13590953109`, verified all **160/160** targeted search bindings, then re-evaluated the saved pilot result at `860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea`; policy outcomes were unchanged: **F2 (7 small inversions), E0 (42 E1-only cases)**. Original frozen result SHA and evaluation SHA `10e9d86beca6763bd01bb4aa21bc8b2b105949fbd305a30b4cbe6bc6f3d42d0a` remain immutable. The supplemental replay has a new *derived* evaluation SHA `ce508d28bbee3f6bb3e99ed32a479222b42e6947e8af50584a51e7607cbd6751` because it includes additional validity fields; it is not a replacement for the frozen pilot evaluation.
- The confirmed policy and evidence **must be incorporated in the single C1 Freeze Authority** at final integration. This pre-Freeze policy document is a verification record, not the C1 Freeze Authority. No new pilot threshold, node budget, F/E rule, unlimited `LEGAL_ALL` root universe, or VE1-D inspection was introduced.

No natural resampling, VE1-D partition inspection, or Build20 engine fix is authorized by this document.
