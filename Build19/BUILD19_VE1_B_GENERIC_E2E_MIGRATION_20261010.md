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
| close gap `<= 40cp` triggers extra movetime | unconditional increasing candidate-discovery and fixed-pair tiers; full MultiPV rankings; per-tier candidate Top-1 identity; `candidate_top1_changed` evidence; highest-tier Top-1 agreement required for `stable` | The legacy intent was “uncertain ordering receives more evidence”, not authority for the 40cp constant. VE1-B always collects deeper evidence and leaves near-tie thresholds to VE1-C. |
| one MultiPV comparison result | unrestricted candidate discovery plus independent one-move `searchmoves` measurements for recommendation and actual move | Prevents pair competition / TT history from becoming comparison authority. |
| old `stable` / loss output | VE1-B comparison stability, continuation horizon, bound-aware loss publication | Numeric loss is withheld unless evidence is exact and comparison-stable. |
| Context low/unresolved position launches old movetime refinement | reuse Deep VE1-B evidence; no additional engine search | One position must not have two competing stability authorities. |

No legacy condition is removed merely to make CI green; each is either replaced by its VE1-B equivalent or explicitly retired because VE1-C owns the semantic threshold.

## Legacy close-gap gate: explicit audit bridge

The legacy quality gate used a numerical condition such as “rank 1 and rank 2 are within 40cp, therefore extend movetime.” That numerical threshold is **not** carried forward as VE1-B authority. The behavioral purpose of the test is carried forward as follows:

1. unrestricted MultiPV discovery always runs at all configured increasing tiers (`N -> 2N -> 4N`) rather than conditionally extending only after a shallow close gap;
2. each discovery tier starts cold and preserves the full ranked MultiPV candidate evidence;
3. candidate Top-1 identity is persisted at every tier and participates in the stability fingerprint;
4. a Top-1 transition is retained explicitly as `candidate_top1_changed` diagnostic evidence;
5. disagreement of the highest qualifying Top-1 tiers prevents `stable`, even if the preselected fixed pair itself appears unchanged;
6. fixed-pair confirmation also executes its full increasing-node series rather than conditionally extending by cp gap;
7. bounded/aborted/inconsistent evidence does not become an exact close-gap observation;
8. any future numerical definition of “near tie”, `UNIQUE`, or `MULTIPLE_GOOD` is VE1-C/VE1-D calibration scope.

Therefore the old extension test is **retired by stronger unconditional evidence collection**, not deleted to make the test pass. The Simulator quality gate may use smaller node tiers for runtime economy, but those tiers must be marked calibration-only and must verify the same structural contract; they are not production node authority.

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

The numerical acceptance rules for these measurements are frozen separately in `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md` before physical B6 data are used.

Therefore B6 does not treat the current 150 ms shallow pass as authority; it treats its selection reproducibility as an acceptance variable. VE1-B cannot FORMAL PASS while that B6 decision is unresolved.

## Completed / incomplete / error state contract

Generic E2E and the app UI must not use a semantic stability label as an execution-success label.
`DeepAnalysisViewModel` therefore exposes a structured run state:

- `completed`: all selected searches/evidence completed. The state carries separate `stable`, `unstable`, and `unconfirmed` counts; their sum must equal the completed-position count.
- `incomplete`: an operational search did not complete (for example safety abort or missing completed evidence). This is never accepted as a successful E2E completion.
- `error`: input/protocol/export/diagnostic failure.

A completed `unstable` or `unconfirmed` position is not dropped. It must continue through board review, reason analysis, continuation simulation and HDS presentation. `actualLossCp` remains suppressed and the decision presentation remains provisional/hold. Generic E2E records per-ply state/reason codes for audit but does not require any particular historical ply to be `stable`.

The generic E2E contains explicit negative structural checks proving that the completion gate rejects: (1) incomplete/aborted state, (2) fewer than 9 search-evidence records for any expected position, and (3) state-count totals that do not equal the expected position count. These are structural failures, not semantic expected labels.
