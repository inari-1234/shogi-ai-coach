# Build19-VE1-B B6 — Shallow Fixed-Node Pre-measurement Contract

Date: 2026-10-11
Status: **FROZEN BEFORE REDESIGNED PHYSICAL B6 / VE1-B HOLD**

## 1. Purpose

The first physical B6 campaign failed only the Shallow selection-reproducibility gate while the fixed-node Deep policy passed its standard operational gates with large margin. This contract freezes the Shallow redesign before a new physical result is observed.

It supplements the existing B6 pre-measurement, proven-mate, physical-harness, evidence-export and interruption-accounting authorities. Where this document conflicts with the old `150 ms` Shallow reproducibility rules, this document supersedes them for the redesigned campaign only.

The failed candidate `7dcfdc436ea51feb0876c110581067ddbfbaaff1` and its evidence remain immutable historical authority.

## 2. Change boundary

The redesign may change only the Shallow search/evidence path necessary to replace time-based triage with fixed-node triage and to preserve the missing diagnostic fields.

The following remain frozen and must not be changed merely to obtain a pass:

- Deep discovery/confirmation tiers: `50k -> 100k -> 200k`;
- Deep per-search safety ceiling: 15,000 ms;
- nine-search Deep comparison structure;
- cold-TT Deep boundaries;
- MultiPV/searchmoves semantics;
- completed-exact-iteration measurement semantics;
- strict `proven_mate_termination` predicate;
- stable/unstable/unconfirmed semantics;
- confirmedPV/referencePV separation;
- HDS contracts and explanation semantics;
- B6 standard/stress runtime limits;
- device floor and engine/NNUE/FV_SCALE authority;
- fixture-locking and evidence-retention rules.

The predetermined Deep `25k/50k/100k` fallback is not activated by the first campaign and must not be implemented as part of this Shallow redesign.

## 3. Fixed Shallow search policy

For every production Shallow position in the redesigned B6 candidate:

- budget: **50,000 nodes**;
- MultiPV: 1;
- `searchmoves`: none;
- Threads: 1;
- Hash: 64 MB;
- BookFile: `no_book`;
- FV_SCALE: 24;
- PvInterval: 0;
- safety ceiling: **15,000 ms**;
- semantic measurement: deepest fully completed exact iteration;
- accepted completed states: `node_budget_reached` or strict `proven_mate_termination` only.

A new cold logical search series must be established before every Shallow position using the same authoritative TT-reset mechanism used by VE1-B fixed-node search. Shallow selection must therefore not depend on residual TT contents from an earlier ply.

The `50,000`-node value is fixed before the redesigned physical campaign. It is chosen because the first physical campaign's 50k unrestricted MultiPV3 Deep discovery searches already showed a comparable runtime scale on the target device: 35 observations, median approximately 141 ms and empirical P95 approximately 161 ms. This is calibration rationale, not a post-hoc performance threshold.

No alternative Shallow node budget may be selected after seeing the redesigned physical result. If 50k Shallow fails operationally, B6 returns to HOLD and a new pre-measurement contract is required.

## 4. Selection algorithm preservation

The existing production importance algorithm remains unchanged except for the source of the Shallow engine measurement.

In particular, preserve:

- focus-side filtering;
- black-perspective score conversion;
- estimated loss calculation from consecutive Shallow scores;
- `+120` for bestmove mismatch;
- `+700` for mate score;
- `+180` when estimated loss is unavailable and bestmove mismatches;
- descending importance sort;
- lower-ply deterministic tie break;
- production provisional/final selection limits.

Do not tune these weights from the first campaign's observed plies.

## 5. Mandatory per-ply Shallow evidence

The redesigned B6 evidence must preserve enough information to reconstruct every selected rank after the campaign.

For every Shallow ply, retain at least:

- ply;
- position command or unambiguous position identity;
- actualMove;
- nodeBudget;
- TT generation / cold-series identity;
- MultiPV;
- completion state;
- elapsedMs;
- thermalBefore / thermalAfter;
- maxObservedNodes;
- selectedNodes;
- selectedDepth;
- selectedSelDepth;
- selectedBoundKind;
- selected score kind and value;
- selected bestMove / PV head;
- full selected PV;
- bestmove consistency;
- `blackPerspectiveCp` when applicable;
- `matchesBestMove`;
- derived `estimatedLossCp`;
- final derived `importance`;
- production selected rank, or explicit `not_selected`;
- the raw USI `info` line corresponding to the adopted deepest completed exact value (`selectedRawUSI`).

Raw observations may remain in a separately hashed evidence file, but the aggregate/run evidence must be sufficient to map the adopted value back to that raw line without ambiguity.

An incomplete Shallow position may not silently contribute a stale score or selection rank.

## 6. Fixed-node deterministic integrity gate

The old 150 ms campaign used a minimum Top-3 Jaccard threshold of 0.50 because time-based search was being characterized. The redesigned fixed-node/cold-TT campaign has a stronger integrity expectation.

For the five standard runs on the same locked KIF/build/device/OS/policy:

- all five production Top-3 ply lists must be identical in both membership and order;
- all ten pairwise Top-3 Jaccard values must therefore be exactly **1.00**;
- Top-1 must be identical in **5/5** runs;
- the full ordered Deep-selection list must also be identical across all five runs;
- for every Shallow ply, completion class, adopted score/move/depth/nodes and derived importance/rank must be identical across runs, except elapsed time, thermal observations and other explicitly non-semantic runtime measurements.

Any Jaccard value below 1.00, any Top-1 difference, any selected-set difference, or any unexplained semantic per-ply Shallow evidence difference is treated as an implementation/runtime determinism defect and yields **B6_HOLD** for investigation. It must not be averaged away by the legacy >=0.50 threshold.

This stricter rule is frozen before the redesigned physical campaign because the first campaign demonstrated that repeated fixed-node/cold-TT Deep measurements were semantically identical for every repeated ply, while the 150 ms upstream Shallow stage alone changed the selected positions.

## 7. Shallow completion and safety gate

Each standard run must produce a complete Shallow evidence record for every eligible game ply before Deep selection is accepted.

For standard runs:

- `safety_aborted`: 0;
- `early_engine_termination`: 0 unless classified by the strict proven-mate predicate;
- `no_completed_exact_iteration`: 0;
- missing Shallow records: 0;
- stale-value reuse: 0;
- serious/critical thermal rules remain those of the existing B6 standard contract.

Any incomplete Shallow search makes that standard run incomplete and prevents `PRIMARY_PASS`.

## 8. Deep and whole-game gates remain unchanged

After Shallow determinism passes, the existing Deep and whole-game gates remain authoritative, including:

- Deep-position median <=15,000 ms;
- Deep-position empirical P95 <=25,000 ms;
- whole-game median <=90 s;
- whole-game empirical P95 <=120 s;
- standard Deep incomplete rate 0%;
- standard serious/critical thermal count 0;
- existing stress rules.

The new campaign must rerun five complete standard runs from the beginning. Only after all redesigned Shallow and standard operational gates pass may the three-run no-cooldown stress sequence begin.

## 9. Required redesigned B6 report additions

In addition to existing B6 report fields, retain:

1. Shallow fixed node budget and safety ceiling;
2. per-ply Shallow evidence listed in section 5 for every standard and stress run;
3. five complete ordered Shallow/Deep-selection lists;
4. all ten Top-3 Jaccards;
5. exact all-run per-ply semantic-equality audit result;
6. explicit `SHALLOW_DETERMINISM_PASS` only when section 6 is fully satisfied;
7. any first differing field and raw evidence reference if determinism fails.

## 10. Decision boundary

The redesigned campaign may produce `PRIMARY_PASS` only if:

- Shallow fixed-node deterministic integrity passes exactly as frozen here;
- all existing standard operational gates pass;
- all three stress runs pass;
- evidence integrity and provenance review pass.

A redesigned Shallow determinism failure yields `B6_HOLD`, not Deep fallback.

VE1-B remains HOLD until the redesigned candidate passes the complete physical B6 and final independent evidence review.
