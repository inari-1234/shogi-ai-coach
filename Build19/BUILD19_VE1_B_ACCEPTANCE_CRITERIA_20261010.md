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
- final selected candidate preserves score, depth, seldepth, nodes, bound flags and PV from a coherent observation rather than mixing fields from unrelated lines;
- the raw `bestmove` is retained separately from MultiPV evidence;
- if `bestmove` differs from the PV head of the final MultiPV rank 1 observation, the attempt is marked `inconsistent` (or equivalent), is not a normal completed comparison, does not count toward stability confirmation, and cannot feed coaching output. Raw evidence for both values must be preserved.

### B3 — Bound scores are not final exact scores

USI `lowerbound` / `upperbound` scores must be represented explicitly as bounded observations and must not be treated as exact final values for semantic comparison.

Required final-observation rule:
- if the deepest/final qualifying observation for a candidate is bounded-only while a shallower exact observation exists, preserve both observations;
- do **not** silently promote the shallower exact observation to the final exact value for the deeper target;
- the candidate is `unconfirmed` / `bounded-at-target` (or equivalent non-stable state) for that target search;
- the shallower exact observation may remain available as provenance/diagnostic evidence, with its own depth and node information, but it must not support a `stable` claim for the deeper target.

PASS requires:
- exact / lowerbound / upperbound are distinct in the evidence model;
- an exact observation is preferred over a same-or-lower-confidence bounded observation only when selecting among observations that are eligible for the same semantic target; the rule above prevents a shallower exact value from masquerading as a deeper exact value;
- if only bounded observations exist, the result is marked bounded/uncertain rather than exact;
- the depth difference between the two compared moves is recorded and available to stability logic and diagnostics;
- tests cover exact-vs-lowerbound, exact-vs-upperbound, bounded-only, shallower-exact-plus-deeper-bound, unequal-depth comparisons, and `bestmove`/MultiPV-rank-1 mismatch.

### B4 — Preserve raw search evidence without lossy projection

For every search attempt and every MultiPV candidate, retain the evidence needed to audit the comparison.

Minimum retained fields per relevant `info` observation:
- search attempt ID / position identity;
- search role (candidate discovery, direct comparison, confirmation tier, diagnostic probe, etc.);
- MultiPV rank;
- move identity / PV head when available;
- score kind and value;
- bound kind (`exact`, `lowerbound`, `upperbound`);
- depth;
- seldepth;
- nodes;
- nps when available;
- complete PV as emitted;
- raw USI line or a lossless equivalent representation;
- issued `go` command / node budget;
- transposition-table generation/reset identity sufficient to reconstruct whether an attempt started cold or inherited TT state;
- raw `bestmove` and any consistency status against MultiPV rank 1.

PASS requires diagnostics to expose every retained MultiPV candidate rather than only the selected line, and unit/regression tests prove the fields survive parser -> accumulator -> analysis result -> diagnostic export.

### B5 — Stability means convergence under deeper search, not same-budget reproducibility

A single search observation must never be labeled `stable` merely because no contradiction was observed.

**Reproducibility and stability are separate concepts.** With Threads=1 and a fixed node budget, repeating the same search conditions can deterministically reproduce the same result. Such same-budget repetition is useful for reproducibility verification but contributes **zero additional stability confirmation**.

Stability confirmation must use different search budgets in an explicitly ordered increasing series, such as `N -> 2N -> 4N` nodes. Numeric budgets are selected under B6 from measured evidence; these symbols define the relationship, not final values.

Required state model:
- one valid qualifying budget tier => `unconfirmed`;
- two or more valid qualifying observations at **distinct increasing node budgets** may become `stable` when the conclusion remains in agreement as search is deepened;
- same-budget repeats may establish `reproducible`, but must not advance `unconfirmed` to `stable`;
- conflicting qualifying observations across increasing tiers => `unstable`;
- invalid, bounded-at-target, aborted, inconsistent-bestmove, or otherwise insufficient evidence => `unknown` / `unconfirmed` as appropriate, never `stable`.

Where three or more tiers are available, stability is assessed from the highest completed qualifying tiers according to the documented agreement rule. A contradiction at a later/deeper qualifying tier invalidates an earlier stability claim. VE1-B must not recalibrate existing cp semantic thresholds while implementing this state model; threshold calibration remains VE1-C.

PASS requires:
- one-tier fixture returns `unconfirmed`;
- two same-budget identical repeats remain `unconfirmed` for stability, while optionally proving reproducibility;
- two distinct increasing tiers that agree can return `stable`;
- `N` disagreeing but `2N` and `4N` agreeing is represented according to the documented highest-tier convergence rule and preserves the earlier disagreement in evidence;
- a later/deeper contradiction returns `unstable` or otherwise removes `stable`;
- downstream coaching cannot treat `unconfirmed` as equivalent to `stable`.

### B6 — Node-count search, transposition-table, role-budget and abort contract

Regression tests, live deep-analysis verification, and production iPhone deep analysis must use a node-count budget rather than `movetime` as the primary search completion condition.

#### B6.1 Normal completion and safety ceiling

The production policy is fixed at the semantic level as follows:
- normal completion: reach the configured node budget for that search invocation;
- safety protection: a wall-clock ceiling may abort a pathological/thermally degraded search;
- a wall-clock ceiling is never a successful completion criterion;
- a search stopped by the safety ceiling is recorded as `aborted/timeout` (or equivalent) and its partial result must not be promoted to a normal completed comparison or coaching result;
- the numeric wall-clock ceiling and node budgets must be chosen from measured device evidence during implementation. They must not be guessed or inherited from the current `movetime` values.

Before B6 can be frozen, the runtime policy must explicitly name:
- the minimum supported physical iPhone model for this analysis mode;
- the chosen node budgets by search role/tier;
- the wall-clock safety ceiling;
- observed abort rates on the minimum supported model under normal conditions and a documented thermally/load-constrained test condition;
- the user-facing incomplete-analysis state. On abort, the UI must state that analysis did not complete, must not show a normal coaching conclusion derived from the partial search, and must offer a safe retry path. Exact final copy may be refined, but the semantic behavior is mandatory.

#### B6.2 Transposition-table isolation and staged reuse

Node determinism is not sufficient if the transposition table (TT/hash) depends on earlier searches. VE1-B therefore fixes the TT policy:

1. **New logical search series starts cold.** Before candidate discovery, before direct comparison/confirmation, and whenever the position or search role changes, the TT must be cleared using a sequence proven to clear the table in the pinned YaneuraOu build.
2. **Do not assume `isready` or `usinewgame` clears TT.** Their behavior must be verified against the pinned engine implementation/runtime. The adopted clear operation/sequence must have an executable regression proving that prior unrelated searches cannot change the result of the next cold-start series.
3. **Within one confirmation series, TT is intentionally retained.** Increasing tiers run in fixed ascending order (`N -> 2N -> 4N`, or the final evidence-based equivalent) and inherit TT state from the immediately preceding tier. These are separate `go nodes ...` invocations; the node value is the budget for that invocation, not a cumulative absolute node counter.
4. **Candidate discovery does not seed direct comparison.** After the MultiPV candidate-discovery role completes, clear TT before the `searchmoves` direct-comparison/confirmation series. This prevents discovery order/history from biasing the comparison role.
5. Every evidence record must identify the TT reset/generation boundary and tier order well enough to reproduce the series.

PASS requires order-independence fixtures: analyzing unrelated position A before target B must produce the same cold-start B result as analyzing B first, within the exact reproducibility contract.

#### B6.3 Node-budget meaning by search role

A node budget applies to the **whole engine search invocation**, not independently to each MultiPV candidate.

The contract distinguishes at least:
- candidate discovery: e.g. MultiPV 3, one role-specific total node budget `D`;
- direct comparison/confirmation: e.g. `searchmoves` with MultiPV 2, role-specific increasing total budgets such as `N`, `2N`, `4N`.

`D` and `N` do not have to be numerically equal. Their final values/ratios must be selected from evidence and then frozen. “Same conditions” means same search role, position, options, searchmoves set/order where semantically relevant, MultiPV setting, TT-start policy, node tier and pinned engine/runtime provenance. It does **not** mean dividing the total node budget equally among MultiPV candidates, and VE1-B must not invent a per-candidate node quota that the engine does not implement.

PASS requires:
- raw evidence records search role, MultiPV, searchmoves, total node budget and TT state for each invocation;
- repeated same-budget cold-start runs verify reproducibility;
- increasing-budget warm-within-series runs verify convergence/stability separately under B5;
- candidate-discovery and direct-comparison budgets are reported separately and never conflated as a single “same time/same effort” value.

#### B6.4 B6 overall evidence

PASS requires:
- deterministic regression fixtures use the same role-specific node target across repeated reproducibility runs;
- raw USI evidence records the issued `go nodes ...` command and final node count;
- same-position repeated cold-start runs on the pinned engine/runtime satisfy the documented reproducibility tolerance for selected move, score kind, score/bound state and evidence completeness;
- no regression expected value is changed merely to fit a timing- or history-dependent run;
- safety-ceiling abort is represented separately from a completed node-budget search;
- physical iPhone evidence demonstrates normal node-budget completion and the incomplete-analysis/abort handling contract, using a safe synthetic/test path for abort if necessary;
- the minimum-device/ceiling decision is backed by measured abort-rate evidence rather than assumption.

### B7 — PV continuation stability is recorded per ply

Continuation agreement must be represented at move/ply granularity, not only as a single boolean for the whole PV.

The confirming PVs used here must come from the distinct increasing node-budget tiers defined by B5/B6. Same-budget duplicate runs can verify reproducibility but do not extend the confirmed semantic prefix.

PASS requires:
- diagnostics show the longest confirmed common PV prefix across the qualifying deeper-search confirmation tiers;
- each prefix ply used for explanation can be traced to confirming evidence at distinct increasing budgets;
- downstream explanations may use only the confirmed prefix, not an unconfirmed tail;
- tests cover full agreement, partial-prefix agreement, first-ply disagreement, short-PV truncation, asymmetric PV length, and same-budget repetition that must not increase the confirmed prefix.

### B8 — Mate sign semantics

The `mate -N` issue is assigned to VE1-C unless implementation work in VE1-B necessarily touches the same scoring abstraction.

VE1-B must not regress the current behavior further. VE1-C acceptance must eventually require:
- positive mate (`mate N`, N > 0) may qualify as a missed winning mate when the actual line does not preserve it;
- negative mate (`mate -N`) must not be classified as a missed winning mate;
- at least one positive and one negative mate regression case.

## Required implementation order

Because stability semantics depend on the node-search and TT contract, implementation order is fixed as:

1. B1 — BookFile alignment;
2. B2/B3/B4 — parser, bound semantics and lossless evidence model;
3. B6 — node search, TT isolation/reuse, role budgets, device/abort policy;
4. B5/B7 — convergence-based stability and per-ply confirmed PV;
5. full regression / Simulator / device-build / physical-iPhone evidence.

B8 remains explicitly deferred to VE1-C unless an unavoidable shared-abstraction change is documented before implementation.

## Evidence contract

VE1-B PASS requires all of the following evidence on one final candidate commit:

1. `swift test` covering parser/accumulator/evidence/bound-consistency/stability/PV contract;
2. deterministic node-budget reproducibility and increasing-budget convergence regression on pinned YaneuraOu + pinned Suisho5 NNUE;
3. TT isolation/order-independence regression plus fixed within-series tier-order evidence;
4. Simulator E2E using production app code paths;
5. iOS device build/IPA success;
6. physical iPhone runtime evidence for the node-budget-plus-safety-ceiling production policy, including the declared minimum-device policy and abort handling evidence;
7. raw USI transcript showing `BookFile=no_book`, `FV_SCALE=24`, `EvalDir`, TT clear boundary/sequence, `go nodes ...`, relevant `info` lines and `bestmove`;
8. diagnostic export proving B2/B3/B4/B5/B6/B7 evidence fields survive end-to-end;
9. existing VE1-A known-answer probes remain unchanged and PASS;
10. HDS-M contract guard remains PASS; no modification of historical 41/49/69 expected positions without separately approved evidence.

## Non-goals / boundaries

- Do not recalibrate FV24 semantic cp thresholds in VE1-B; that remains VE1-C.
- Do not create new 41/49/69 Semantic Authority.
- Do not start HDS-H or Build20.
- Do not treat physical device build success as physical runtime evidence.
- Do not change VE1-A expected values `108`, `157`, `7g7f`, `2b7g+`, pinned SFEN or pinned NNUE SHA.

## Formal completion rule

VE1-B is PASS only when B1-B7 are implemented and all required evidence gates pass on one final candidate commit. B8 may remain deferred to VE1-C if untouched by VE1-B implementation, but the deferral must remain explicit in the final VE1-B report.
