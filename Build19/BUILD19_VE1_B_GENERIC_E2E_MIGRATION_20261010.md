# Build19-VE1-B Generic E2E / Context Authority Migration

Date: 2026-10-10
Status: corrective contract (pre-B6)
Applied migration commit: `b46fc7c2b6d9e80ce4aca6b846417af516c5cb6d`

## Purpose

Remove the remaining mixed search authority from production and migrate the generic Simulator quality gate without weakening its intent.

## Production authority

Deep engine evidence is produced only by `VE1BNodeComparisonAnalyzer` under the VE1-B node-search contract. `ContextAnalysisViewModel` must not launch a second `AdaptiveComparisonAnalyzer` movetime search for the same position. Context analysis consumes/reuses the already-produced Deep VE1-B evidence.

`AdaptiveComparisonAnalyzer` is legacy implementation material only. It is not a production engine-evidence authority after this migration.

## Generic E2E migration map

| Legacy assertion | VE1-B replacement | Rationale |
| --- | --- | --- |
| `finalMovetimeMs == 200` | `finalMovetimeMs == 0`, node-policy fields, final node budget, and complete search-evidence count | Deep search is node-budgeted; movetime is no longer an engine budget. |
| adaptive tiers `[800,1600,2400]` | strictly increasing fixed-node tiers `N -> 2N -> 4N` | Stability is evidence across increasing node budgets, not elapsed time. |
| close gap `<= 40cp` triggers extra movetime | all comparison tiers execute and are recorded; bounded data never becomes exact gap evidence | VE1-C owns numerical decision-threshold calibration. VE1-B must not freeze a cp threshold. |
| one MultiPV comparison result | unrestricted candidate discovery plus independent one-move `searchmoves` measurements for recommendation and actual move | Prevents pair competition / TT history from becoming comparison authority. |
| old `stable` / loss output | VE1-B comparison stability, continuation horizon, bound-aware loss publication | Numeric loss is withheld unless evidence is exact and comparison-stable. |
| Context low/unresolved position launches old movetime refinement | reuse Deep VE1-B evidence; no additional engine search | One position must not have two competing stability authorities. |

No legacy condition is removed merely to make CI green; each is either replaced by its VE1-B equivalent or explicitly retired because VE1-C owns the semantic threshold.

## Context refinement semantics

`refinementCandidatePlies` now means positions where LOW/UNRESOLVED context coincides with unstable comparison or continuation evidence. `refinementCompletedPlies` records that those candidates were re-evaluated from the authoritative Deep VE1-B evidence. `usedAdditionalEngineSearch` remains `false`; no second engine search is permitted. Confidence/intent change counters remain zero unless a future non-engine context-only refinement changes them.

## Shallow analysis and B6 scope

Shallow analysis currently remains the legacy movetime triage path. It is **not** explanation evidence and cannot publish recommendation confidence, loss, causal reason, or stable PV authority. Every selected deep position is re-analyzed by VE1-B before it can support an explanation.

Because shallow output affects which positions are selected, B6 must nevertheless measure it before production search policy is frozen:

1. repeat the same whole-game shallow pass multiple times on the physical target device;
2. record selected-position overlap / ordering stability;
3. record shallow total runtime and per-position elapsed distribution;
4. run Deep VE1-B on the selected positions and record total end-to-end runtime, incomplete rate, thermal state and UX impact;
5. if shallow selection repeatability is not acceptable, migrate shallow triage to fixed nodes and repeat B6 before freeze.

Therefore B6 does not treat the current 150 ms shallow pass as authority; it treats its selection reproducibility as an acceptance variable. VE1-B cannot FORMAL PASS while that B6 decision is unresolved.
