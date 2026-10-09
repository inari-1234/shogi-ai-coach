# Build19-VE1-B Issue Backlog — 2026-10-09

This file records issues discovered during VE1-Q qualification and VE1-A review. It does **not** start VE1-B implementation and does not establish new Semantic Authority.

Formal pass/fail conditions are defined in `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`.

## VE1B-001 — scoreless `info` can overwrite scored accumulator entry

Status: **OPEN / NOT IMPLEMENTED**

Observed by: Build19-VE1-Q Swift/Python parity fixture `missing-score-swift-compat`.

Current behavior: when `USIAccumulator` already holds a scored PV entry and a later `info` line for the same MultiPV rank is selected by the accumulator's depth/time rule but has no score, the later scoreless entry replaces the scored entry. The resulting app-side evaluation can therefore become `nil`.

Required work: implement a coherent-observation retention rule and regression-test scored/scoreless ordering, depth changes, MultiPV identity and field coherence.

## VE1B-002 — live deep analysis is movetime-bounded rather than node-bounded

Status: **OPEN / NOT IMPLEMENTED**

Observed by: VE1-A HDS-M regression review after a time-limited deep search changed `comparisonStable` and temporarily changed final position selection.

Current behavior: the live deep-analysis/HDS path is bounded by `movetime`. Search results can therefore vary with simulator/device speed, thermal state, scheduling, and other runtime conditions even when the position and engine assets are unchanged.

Required work: migrate deterministic regression, live verification and production iPhone deep analysis to node-budget normal completion. Production policy is node budget plus wall-clock safety ceiling; ceiling expiry is an abort/failure state, not successful completion.

## VE1B-003 — production app does not explicitly disable opening-book use

Status: **OPEN / NOT IMPLEMENTED**

Observed by: VE1-A physical iPhone raw USI transcript and source review.

Current behavior: production `EngineUSISession` sends Threads, Hash, MultiPV, FV_SCALE and EvalDir but not `BookFile=no_book`. The engine therefore tries its default `book/standard_book.db`. This was harmless in VE1-A because no book loaded, but a future bundled/working-directory book could bypass normal search evidence in opening positions.

Required work: send `setoption name BookFile value no_book` before `isready` in production analysis paths and align app/harness/Simulator/device diagnostics. Add a regression showing a present book file cannot affect results when disabled.

## VE1B-004 — bound scores and compared-depth provenance are insufficiently explicit

Status: **OPEN / NOT IMPLEMENTED**

Required work: preserve `exact` / `lowerbound` / `upperbound` as distinct evidence states; do not treat a bound as an exact final semantic score; retain and expose compared-move depth differences; add exact/bounded and unequal-depth fixtures.

## VE1B-005 — search evidence is projected too aggressively

Status: **OPEN / NOT IMPLEMENTED**

Required work: preserve per-attempt/per-MultiPV evidence including score kind/value, bound kind, depth, seldepth, nodes, nps, complete PV and raw USI (or lossless equivalent), and prove those fields survive diagnostic export.

## VE1B-006 — one search attempt can be treated as stable

Status: **OPEN / NOT IMPLEMENTED**

Required work: introduce an explicit state model where one qualifying attempt is `unconfirmed`; only two or more agreeing qualifying observations can become `stable`; conflicts become `unstable`; insufficient evidence remains non-stable.

## VE1B-007 — continuation stability is not recorded at PV-ply granularity

Status: **OPEN / NOT IMPLEMENTED**

Required work: record the longest confirmed common PV prefix and restrict downstream explanation to that confirmed prefix. Add full/partial/first-ply/short/asymmetric PV fixtures.

## Deferred item

Mate-sign semantics (`mate -N` must not count as a missed winning mate) is assigned to VE1-C unless VE1-B necessarily changes the same scoring abstraction. The VE1-B implementation must not silently absorb or redefine that semantic rule.
