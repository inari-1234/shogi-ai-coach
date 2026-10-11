# Build19-VE1-B — Proven Mate Termination Amendment

Date: 2026-10-11
Status: **FROZEN BEFORE PHYSICAL B6 MEASUREMENT / VE1-B STILL HOLD**

## 1. Trigger and scope

Production-path Simulator E2E on commit `6b456dfe2a78768bb90bcfedb09ac30f1fcbaecd` exposed a completion-state gap in the terminal-position regression. At ply 81, the unrestricted candidate-discovery search at the 200,000-node tier returned `bestmove` before the requested node count after already emitting a coherent completed exact mate snapshot. The existing state machine classified every pre-budget engine return as `early_engine_termination`, so the terminal regression entered the incomplete-analysis path.

No physical B6 qualification measurement had been started when this gap was identified. This amendment is therefore frozen before physical B6 data and does not tune a threshold in response to device results.

This amendment changes only node-search completion classification. It does not change candidate-discovery budgets, comparison budgets, the 15-second safety ceiling, convergence rules, cp thresholds, semantic stability rules, or explanation gates.

## 2. New qualified completion state

Add a distinct completion state:

- `proven_mate_termination`

A search may receive this state only when **all** of the following hold:

1. the search was not safety-aborted;
2. `maxObservedNodes < requestedNodeBudget`, i.e. the engine returned naturally before the node budget;
3. a deepest fully completed exact snapshot exists for the full requested MultiPV cardinality;
4. every required MultiPV rank `1...N` is present exactly once in that snapshot;
5. every required rank has an **exact** `score mate ...` result, with no lowerbound/upperbound;
6. every required rank has a non-empty PV;
7. terminal `bestmove` consistency is `consistent`;
8. the rank-1 PV head equals terminal `bestmove`.

Failure of any condition above leaves the pre-budget return classified as `early_engine_termination`.

## 3. Evidence and measurement semantics

`proven_mate_termination` is a **qualified completed search state**. It is not an incomplete/abort state.

The Evidence record must still preserve:

- requested node budget;
- actual `maxObservedNodes`;
- raw terminal `bestmove` provenance;
- all raw USI observations;
- the selected deepest fully completed exact snapshot and its true depth/nodes;
- the explicit completion value `proven_mate_termination`.

The actual observed node count must never be relabeled as the requested node budget.

The selected semantic measurement remains the deepest fully completed exact snapshot defined by the PvInterval/completed-iteration authority. This amendment does not permit a bounded terminal line to replace that measurement.

## 4. States that remain incomplete

The following remain incomplete and are not relaxed by this amendment:

- `early_engine_termination` that does not satisfy the strict proven-mate predicate;
- `safety_aborted`;
- `no_completed_exact_iteration`;
- any future operational state that lacks qualified completed evidence.

In particular, an early exact centipawn result, bounded mate result, missing MultiPV rank, empty PV, or inconsistent terminal `bestmove` remains a failure.

## 5. B6 operational interpretation

This amendment narrowly supersedes the assumption in the frozen B6 pre-measurement contract that every natural pre-budget return necessarily belongs to `early_engine_termination`.

For B6 standard qualification:

- `safety_aborted`: 0 occurrences;
- unmatched `early_engine_termination`: 0 occurrences;
- `no_completed_exact_iteration`: 0 occurrences;
- other incomplete-search states: 0 occurrences;
- `proven_mate_termination`: permitted as a completed search **only** when the strict predicate above is satisfied and its raw evidence is retained.

B6 reports must count `proven_mate_termination` separately from `node_budget_reached` and separately from all incomplete states.

No B6 timing threshold, node schedule, fallback schedule, or thermal threshold is changed.

## 6. Mate sign is not decided here

This state proves only that the engine completed the search by reaching an exact mate result before exhausting the requested node budget. It does **not** decide whether a positive or negative mate score should be described as winning or losing from any presentation perspective.

Both positive and negative exact mate values may satisfy completion provenance. Mate-sign semantic acceptance remains outside this amendment and must not be inferred from `proven_mate_termination` alone.

## 7. Required automated negative coverage

The implementation must include automated cases proving that the following do **not** qualify:

- exact centipawn pre-budget return;
- bounded mate;
- missing requested MultiPV rank;
- empty PV;
- inconsistent terminal `bestmove` / rank-1 PV;
- safety-aborted search even if earlier mate observations exist.

A positive case must prove coherent full-MultiPV exact mate qualification. A negative exact mate may also be accepted as completion provenance, with no winning/losing semantic assertion.

## 8. Gate boundary

Production-path Simulator E2E must pass with this completion-state distinction before physical B6 begins. A Simulator PASS is necessary but does not itself make VE1-B FORMAL PASS; physical B6 and the remaining VE1-B authority checks are still required.
