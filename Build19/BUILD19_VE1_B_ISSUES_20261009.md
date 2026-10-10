# Build19-VE1-B Issue Backlog — 2026-10-09

This file records issues discovered during VE1-Q qualification and VE1-A review. It does **not** start VE1-B implementation and does not establish new Semantic Authority.

Formal pass/fail conditions are defined in `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`.

## VE1B-001 — scoreless `info` can overwrite scored accumulator entry

Status: **OPEN / NOT IMPLEMENTED**

Observed by: Build19-VE1-Q Swift/Python parity fixture `missing-score-swift-compat`.

Current behavior: when `USIAccumulator` already holds a scored PV entry and a later `info` line for the same MultiPV rank is selected by the accumulator's depth/time rule but has no score, the later scoreless entry replaces the scored entry. The resulting app-side evaluation can therefore become `nil`.

Required work:
- implement a coherent-observation retention rule and regression-test scored/scoreless ordering, depth changes, MultiPV identity and field coherence;
- retain raw `bestmove` separately from MultiPV rank 1 and reject an attempt as inconsistent if `bestmove` and the final rank-1 PV head disagree;
- preserve both values and all raw evidence for diagnosis rather than normalizing the mismatch away.

## VE1B-002 — live deep analysis is movetime-bounded rather than node-bounded

Status: **OPEN / NOT IMPLEMENTED**

Observed by: VE1-A HDS-M regression review after a time-limited deep search changed `comparisonStable` and temporarily changed final position selection.

Current behavior: the live deep-analysis/HDS path is bounded by `movetime`. Search results can therefore vary with simulator/device speed, thermal state, scheduling, and other runtime conditions even when the position and engine assets are unchanged.

Required work:
- migrate deterministic regression, live verification and production iPhone deep analysis to node-budget normal completion;
- distinguish same-budget reproducibility from increasing-budget convergence/stability;
- use different increasing node budgets for stability confirmation (for example `N -> 2N -> 4N`), never same-budget duplicate runs as confirmation;
- use a wall-clock limit only as a safety abort ceiling; timeout is not successful completion and cannot feed normal coaching output;
- select node budgets, minimum supported iPhone model, wall-clock ceiling and abort UI behavior from measured device evidence before B6 is frozen.

## VE1B-003 — production app does not explicitly disable opening-book use

Status: **OPEN / NOT IMPLEMENTED**

Observed by: VE1-A physical iPhone raw USI transcript and source review.

Current behavior: production `EngineUSISession` sends Threads, Hash, MultiPV, FV_SCALE and EvalDir but not `BookFile=no_book`. The engine therefore tries its default `book/standard_book.db`. This was harmless in VE1-A because no book loaded, but a future bundled/working-directory book could bypass normal search evidence in opening positions.

Required work: send `setoption name BookFile value no_book` before `isready` in production analysis paths and align app/harness/Simulator/device diagnostics. Add a regression showing a present book file cannot affect results when disabled.

## VE1B-004 — bound scores and compared-depth provenance are insufficiently explicit

Status: **OPEN / NOT IMPLEMENTED**

Required work:
- preserve `exact` / `lowerbound` / `upperbound` as distinct evidence states;
- do not treat a bound as an exact final semantic score;
- if a deeper/final observation is bounded-only while a shallower exact observation exists, preserve both but classify the target result as `unconfirmed` / bounded-at-target; do not silently adopt the shallower exact score as if it were exact at the deeper target;
- retain and expose compared-move depth differences;
- add exact/bounded, shallow-exact/deep-bound, unequal-depth, and bestmove/PV-head mismatch fixtures.

## VE1B-005 — search evidence is projected too aggressively

Status: **OPEN / NOT IMPLEMENTED**

Required work: preserve per-attempt/per-MultiPV evidence including search role, score kind/value, bound kind, depth, seldepth, nodes, nps, complete PV, issued `go` command/node budget, TT reset/generation identity, raw bestmove, consistency status and raw USI (or lossless equivalent), and prove those fields survive diagnostic export.

## VE1B-006 — one search attempt can be treated as stable

Status: **OPEN / NOT IMPLEMENTED**

Required work:
- introduce an explicit state model where one qualifying budget tier is `unconfirmed`;
- same-budget duplicate runs may prove reproducibility but must not count as stability confirmation;
- only agreement while increasing search effort at distinct node budgets may establish `stable`;
- a later/deeper contradiction removes `stable` and becomes `unstable` or equivalent;
- insufficient, bounded-at-target, aborted or inconsistent evidence remains non-stable.

## VE1B-007 — continuation stability is not recorded at PV-ply granularity

Status: **OPEN / NOT IMPLEMENTED**

Required work: record the longest confirmed common PV prefix across distinct increasing-budget confirmation tiers and restrict downstream explanation to that confirmed prefix. Same-budget duplicate runs must not extend the semantic confirmed prefix. Add full/partial/first-ply/short/asymmetric PV fixtures.

## VE1B-008 — transposition-table history can make node-bounded results order-dependent

Status: **OPEN / NOT IMPLEMENTED**

Current risk: node-count completion alone does not isolate analysis from earlier searches if the TT/hash retains entries. Candidate-discovery searches, unrelated positions, or earlier confirmation tiers can change later search behavior.

Required policy:
- every new logical search series starts from a verified cold TT;
- do not assume `isready` or `usinewgame` clears TT; prove the adopted clear sequence on the pinned YaneuraOu build;
- changing position or search role clears TT;
- candidate discovery does not seed direct `searchmoves` comparison;
- within one fixed increasing-budget confirmation series, TT is intentionally retained in fixed ascending order;
- record TT generation/reset boundaries and add order-independence regression (A then B vs B first).

## VE1B-009 — “same conditions” is ambiguous after moving from time to node budgets

Status: **OPEN / NOT IMPLEMENTED**

Required policy:
- node budget is per whole engine search invocation, not per MultiPV candidate;
- candidate discovery (e.g. MultiPV 3) and direct comparison (e.g. searchmoves + MultiPV 2) are distinct search roles with separately measured/frozen total node budgets;
- `D` and `N` need not be equal, but their final values/ratios must be evidence-backed and recorded;
- same-condition reproducibility means same role, position, options, searchmoves semantics, MultiPV, cold/warm TT contract, node tier and engine/runtime provenance;
- do not invent equal per-candidate node allocations that the engine does not provide.

## Deferred item

Mate-sign semantics (`mate -N` must not count as a missed winning mate) is assigned to VE1-C unless VE1-B necessarily changes the same scoring abstraction. The VE1-B implementation must not silently absorb or redefine that semantic rule.

## Required implementation order

`B1 -> B2/B3/B4 -> B6 -> B5/B7 -> full regression`.

B6 must precede B5/B7 because convergence-based stability and confirmed-PV semantics depend on the node-budget, TT and search-role contract.
