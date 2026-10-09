# Build19-VE1-B — Search / Evidence Contract Acceptance Criteria

Date: 2026-10-10
Base: VE1-A formal PASS commit `3252adb0fb5a066fc90362d978eec7f196f62135`.
Status: **CONTRACT CANDIDATE / IMPLEMENTATION NOT STARTED**

## Purpose

VE1-B defines the runtime search and evidence contract that VE1-C through VE1-E may rely on. This document fixes acceptance conditions before implementation. It does not itself change production behavior.

## Scope and acceptance gates

### B1 — Explicitly disable opening-book use

Production `EngineUSISession` must send `setoption name BookFile value no_book` before `isready` for all analysis sessions that produce coaching evidence.

PASS requires:
- raw USI evidence contains `setoption name BookFile value no_book` before `isready`;
- the same setting is used by app-current, app-candidate, regression harness, Simulator and physical iPhone diagnostic paths;
- no analysis result depends on a bundled or working-directory opening-book file;
- the previous `can't read file : book/standard_book.db` warning is absent in the verified path;
- a negative fixture proves that adding a `standard_book.db` file cannot alter an analysis result when `BookFile=no_book` is active.

### B2 — VE1B-001: scored `info` must not be overwritten by scoreless `info`

The accumulator/parser must retain the best eligible scored observation for each analysis identity and must never replace it merely because a later `info` line for that same identity has no score.

PASS requires regression fixtures for at least:
- scored line followed by scoreless line;
- scoreless line followed by scored line;
- multiple depths where only some lines carry scores;
- MultiPV identities where one candidate emits a scoreless update and another does not;
- final selected candidate preserves score, depth, seldepth, nodes, bound flags and PV from a coherent observation rather than mixing fields from unrelated lines.

### B3 — Bound scores are not final exact scores

USI `lowerbound` / `upperbound` scores must be represented explicitly as bounded observations and must not be treated as exact final values for semantic comparison.

PASS requires:
- exact / lowerbound / upperbound are distinct in the evidence model;
- an exact observation is preferred over a same-or-lower-confidence bounded observation for final semantic comparison;
- if only bounded observations exist, the result is marked bounded/uncertain rather than exact;
- the depth difference between the two compared moves is recorded and available to stability logic and diagnostics;
- tests cover exact-vs-lowerbound, exact-vs-upperbound, bounded-only, and unequal-depth comparisons.

### B4 — Preserve raw search evidence without lossy projection

For every search attempt and every MultiPV candidate, retain the evidence needed to audit the comparison.

Minimum retained fields per relevant `info` observation:
- search attempt ID / position identity;
- MultiPV rank;
- move identity / PV head when available;
- score kind and value;
- bound kind (`exact`, `lowerbound`, `upperbound`);
- depth;
- seldepth;
- nodes;
- nps when available;
- complete PV as emitted;
- raw USI line or a lossless equivalent representation.

PASS requires diagnostics to expose every retained MultiPV candidate rather than only the selected line, and unit/regression tests prove the fields survive parser -> accumulator -> analysis result -> diagnostic export.

### B5 — Stability requires confirmation

A single search observation must never be labeled `stable` merely because no contradiction was observed.

Required state model:
- one qualifying observation/attempt => `unconfirmed`;
- two or more independent qualifying observations with the required agreement => `stable`;
- conflicting qualifying observations => `unstable`;
- insufficient/invalid evidence => `unknown` or equivalent non-stable state.

PASS requires:
- one-attempt fixture returns `unconfirmed`;
- two agreeing attempts can return `stable`;
- conflicting best move / score kind / boundedness / materially different loss can return `unstable` according to documented rules;
- downstream coaching cannot treat `unconfirmed` as equivalent to `stable`.

### B6 — Node-count search contract

Regression tests, live deep-analysis verification, and production iPhone deep analysis must use a node-count budget rather than `movetime` as the primary search completion condition.

The production policy is fixed as follows:
- normal completion: reach the configured node budget;
- safety protection: a wall-clock ceiling may abort a pathological/thermally degraded search;
- a wall-clock ceiling is never a successful completion criterion;
- a search stopped by the safety ceiling is recorded as `aborted/timeout` (or equivalent) and its partial result must not be promoted to a normal completed comparison;
- the numeric wall-clock ceiling and node budgets must be chosen from measured device evidence during implementation and covered by regression tests. They must not be guessed or inherited from the current `movetime` values.

PASS requires:
- deterministic regression fixtures use the same node target across repeated runs;
- raw USI evidence records the issued `go nodes ...` command and final node count;
- same-position repeated runs on the pinned engine/runtime satisfy the documented reproducibility tolerance for selected move, score kind, score/bound state and evidence completeness;
- no regression expected value is changed merely to fit a timing-dependent run;
- safety-ceiling abort is represented separately from a completed node-budget search;
- physical iPhone evidence demonstrates both a normal node-budget completion and, via a safe synthetic/test path if necessary, the abort-state handling contract.

### B7 — PV continuation stability is recorded per ply

Continuation agreement must be represented at move/ply granularity, not only as a single boolean for the whole PV.

PASS requires:
- diagnostics show the longest confirmed common PV prefix for the compared confirming attempts;
- each prefix ply used for explanation can be traced to confirming evidence;
- downstream explanations may use only the confirmed prefix, not an unconfirmed tail;
- tests cover full agreement, partial-prefix agreement, first-ply disagreement, short-PV truncation, and asymmetric PV length.

### B8 — Mate sign semantics

The `mate -N` issue is assigned to VE1-C unless implementation work in VE1-B necessarily touches the same scoring abstraction.

VE1-B must not regress the current behavior further. VE1-C acceptance must eventually require:
- positive mate (`mate N`, N > 0) may qualify as a missed winning mate when the actual line does not preserve it;
- negative mate (`mate -N`) must not be classified as a missed winning mate;
- at least one positive and one negative mate regression case.

## Evidence contract

VE1-B PASS requires all of the following evidence on one final candidate commit:

1. `swift test` covering parser/accumulator/evidence/stability/PV contract;
2. deterministic node-budget regression on pinned YaneuraOu + pinned Suisho5 NNUE;
3. Simulator E2E using production app code paths;
4. iOS device build/IPA success;
5. physical iPhone runtime evidence for the node-budget-plus-safety-ceiling production policy;
6. raw USI transcript showing `BookFile=no_book`, `FV_SCALE=24`, `EvalDir`, `go nodes ...`, relevant `info` lines and `bestmove`;
7. diagnostic export proving B3/B4/B5/B7 evidence fields survive end-to-end;
8. existing VE1-A known-answer probes remain unchanged and PASS;
9. HDS-M contract guard remains PASS; no modification of historical 41/49/69 expected positions without separately approved evidence.

## Non-goals / boundaries

- Do not recalibrate FV24 semantic cp thresholds in VE1-B; that remains VE1-C.
- Do not create new 41/49/69 Semantic Authority.
- Do not start HDS-H or Build20.
- Do not treat physical device build success as physical runtime evidence.
- Do not change VE1-A expected values `108`, `157`, `7g7f`, `2b7g+`, pinned SFEN or pinned NNUE SHA.

## Formal completion rule

VE1-B is PASS only when B1-B7 are implemented and all required evidence gates pass on one final commit. B8 may remain deferred to VE1-C if untouched by VE1-B implementation, but the deferral must remain explicit in the final VE1-B report.
