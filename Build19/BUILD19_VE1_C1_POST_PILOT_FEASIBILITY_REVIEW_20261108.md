# Build19 VE1-C1 — Post-Pilot Feasibility Review

Date: 2026-11-08
Status: **PILOT_PASS / PILOT_FEASIBILITY_AMENDMENT_REQUIRED — 16M/64M REFERENCE CANDIDATE SUPPORTED; PLAYED CERTAINTY REVIEW OPEN / NO AMENDMENT APPROVED**
This is a post-pilot evidence/decision record under frozen pre-pilot §§12–14, **not** a new C1 Freeze Authority, a new pilot PASS rule, a selected delta, or an authorization to inspect VE1-D data.

## Evidence identity and immutability

- Natural 16-position pilot: `PILOT_PASS`, run `42413155051`, execution SHA `637213c21697401882dc930a6aa63f135df441b5`.
- Frozen artifact ID `13590953109`, ZIP SHA-256 `9540af0368c673cd4aa3110b8882934d25f5babd62b4adedf577b64209e01af9`.
- `pilot-result.json`: SHA `860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea`.
- `pilot-evaluation.json`: SHA `10e9d86beca6763bd01bb4aa21bc8b2b105949fbd305a30b4cbe6bc6f3d42d0a`.
- Pinned score conversion: `E(cp)=1/(1+exp(-cp/285))`; `tau_good_ref=0.050`; Reference budgets 4M/16M nodes. All observations below derive from the **same frozen pilot**, not from VE1-D tuning/holdout/reserve.

## Root cause of the 3/16 Reference structure DISPUTED

All 3 are `STRUCTURE_LABEL_CHANGED` from **UNIQUE_GOOD at 4M to MULTIPLE_GOOD at 16M**. Rank-1 move identity remained unchanged; there was **zero** `GOOD_SET_DISJOINT` among these three. Each root had a completed exact MultiPV snapshot: this is genuine budget-dependent score/structure instability, not loss of exact evidence.

| Pilot position | Reference 4M rank1/rank2 cp | 4M rank2 expected-score loss (distance above 0.050) | 16M rank1/rank2 cp | 16M rank2 expected-score loss (distance below 0.050) | Cause |
|---|---|---|---|---|---|
| `p06-ply-161` | 957 / 667 | 0.054198 (+0.004198) | 698 / 662 | 0.009749 (-0.040251) | `STRUCTURE_LABEL_CHANGED` |
| `p09-ply-7` | 113 / 51 | 0.053227 (+0.003227) | 94 / 47 | 0.040582 (-0.009418) | `STRUCTURE_LABEL_CHANGED` |
| `p15-ply-162` | -531 / -680 | 0.050086 (+0.000086) | -780 / -861 | 0.014350 (-0.035650) | `STRUCTURE_LABEL_CHANGED` |

Thus all 4M cases lie close to the hard 0.050 boundary, and all 16M cases fall clearly within the good region (though `p09` is only 0.0094 below). The evidence is compatible with a too-shallow 4M Reference budget; it **does not prove** 16M is stable against 64M. Do not claim increasing budgets is guaranteed to resolve all disputes. The independent played-class `SOMEWHAT_WORSE -> GOOD` transitions at `p01-ply-282`, `p04-ply-10`, `p08-ply-81` are distinct from these 3 **structure** DISPUTED cases and should be separately retained as feasibility evidence.

At the pilot point estimate `p=3/16=18.75%`, a simple independent-binomial approximation gives `P(X<=5 | n=50,p)=7.31%`; at 15%, 21.94%; at 10%, 61.61%. These are **illustrations, not predictive guarantees**: the pilot has 16 positions from five games and clustering/selection may violate independent identical draws.

## Delta grid: report-only coverage prognosis (CORRECTED §E source availability)

**Correction of the earlier 3/16 result:** The previous proxy *wrongly required the actual played move to appear in the App top-three MultiPV*. Frozen v4 §E's two-score-source compatibility check applies **only if both sources exist**. When the played move is not among the MultiPV roots, the independently measured same-tier comparison supplies the single available source; there is no absent root score to conflict with it. E0 still rejects any pair of *present* conflicting or ambiguous sources. This corrects analysis of the original immutable result, **not** the stored pilot, F2/E0 decision, δ selection, or the frozen contract.

At the primary App 200k node tier:
- **Structure coverage proxy:** definite UNIQUE/MULTIPLE/NO_SAVING_MOVE after C1's `CROSS_AXIS_CONFLICT` guard.
- **Played score-source E0 coverage upper bound:** If the played move is absent from the App root MultiPV, require a single definite class from a valid independent same-tier comparison; if present in MultiPV, require root and independent comparison losses to yield **the same singleton class** under frozen `app_allowed_classes(loss, δ)`. Invalid `searchmoves` target binding or missing/mate/unclassifiable loss fails closed. This is an **upper bound**, because F2 exceptions, stability and final played certainty have not been applied.
- Both finite root + independent comparison losses exist for **5/16**; of these at δ=0, **3 agree and 2 conflict**. The independent comparison alone gives a definite class in **15/16**. The source-availability-adjusted E0 bound at δ=0 is **10 independent-only + 3 agreeing dual-source = 13/16**, not 3/16.
- At δ=0, the two definite source contradictions are `p08-ply-81` and `p12-ply-126`; `p02-ply-156` has `NO_SAVING_MOVE` / no finite independent played loss and does not count. These cases are not silently turned into MATCH.

| δ | App structure definitive /16 | Corrected E0 played source-compatibility UPPER BOUND /16 | Independent comparison singleton /16 | Finite dual-source available /16 |
|---:|---:|---:|---:|---:|
| 0.000 | 16 | 13 | 15 | 5 |
| 0.005 | 15 | 13 | 15 | 5 |
| 0.010 | 15 | 13 | 15 | 5 |
| 0.015 | 14 | 13 | 15 | 5 |
| 0.020 | 14 | 13 | 15 | 5 |
| 0.025 | 13 | 13 | 15 | 5 |
| 0.030 | 10 | 13 | 15 | 5 |
| 0.035 | 10 | 13 | 15 | 5 |
| 0.040 | 9 | 13 | 15 | 5 |
| 0.045 | 8 | 13 | 15 | 5 |
| 0.050 | 1 | 6 | 9 | 5 |

**No chosen δ:** With `δ_final=δ_min+0.010`, App structure >=70% (at least 12/16) requires **δ_final <=0.025**, i.e. **δ_min <=0.015** in this pilot. But that is a feasibility observation, not a license to choose δ from the pilot. Corrected E0 score-source coverage no longer by itself proves 70% played coverage unattainable; the missing ingredients are full F2 / stability / played-certainty application.

### H1/H3-oriented false-UNIQUE proxy by δ (report only)

**Independent reproducibility:** GitHub Actions run `42440561106` at SHA `88450cc218f6ef49ed5c1aa8988077fb51bf1126` PASS; archived derived grid artifact `13601093583`, ZIP digest `sha256:60dfa1b37e100fe447d080c6e1354e644eb767af5ee339e2003b125cc3bb4029`. The script `tools/engine-verify/ve1c1_pilot_feasibility_grid.py` reads the immutable artifact and enforces original result/evaluation SHA identity, 16-position count, 13 Reference RESOLVED, 12 MULTIPLE, corrected 13/16 E0 at δ=0, 6/16 at δ=0.050, and the all-δ primary-200k false-UNIQUE absence. The derived artifact is report-only, not a changed pilot or selected δ.

The frozen 4M/16M Reference cross-budget structure is RESOLVED for 13/16; **12 are MULTIPLE_GOOD**, one `NO_SAVING_MOVE`. Count each reference-resolved MULTIPLE_GOOD position where an App tier asserts `UNIQUE_GOOD` without C1's downstream cross-axis guard. These are *exposure counts* for H1/H3 analysis, **not** formal complete H1/H3 truth labels or a selected δ. The primary App 200k tier is the preregistered C1 semantic source, not the earlier exploration tiers.

| δ | False UNIQUE at App 50k / 12 | App 100k / 12 | Primary App 200k / 12 |
|---:|---:|---:|---:|
| 0.000 | 1 | 3 | 0 |
| 0.005 | 1 | 3 | 0 |
| 0.010 | 1 | 3 | 0 |
| 0.015 | 1 | 3 | 0 |
| 0.020 | 1 | 2 | 0 |
| 0.025 | 1 | 1 | 0 |
| 0.030 | 1 | 1 | 0 |
| 0.035 | 1 | 1 | 0 |
| 0.040 | 1 | 1 | 0 |
| 0.045 | 1 | 1 | 0 |
| 0.050 | 1 | 1 | 0 |

**After the C1 CROSS_AXIS_CONFLICT guard**, the 100k raw exposure `p04-ply-10` is suppressed; the *confirmable false-UNIQUE* counts (50k / 100k / 200k) for δ=0.000–0.015 are `[1,2,0]`, at δ=0.020 `[1,1,0]`, and for δ=0.025–0.050 `[1,1,0]`. The raw/unfiltered candidates in the table above are diagnostic only. Full per-δ counts and position IDs are in the derived grid artifact.

At 50k the repeatedly affected position is `p12-ply-126`; at 100k, `p04-ply-10`, `p08-ply-81`, `p12-ply-126` are exposed at δ<=0.015. At the **primary 200k tier** the false-UNIQUE proxy is **0/12 at every δ**. This is evidence of shallower-tier instability, but the pilot does **not** demonstrate a persisting primary-tier H1 failure. If H1/H3 formally require a different denominator/played membership evaluation, it must be evaluated independently, not silently equated to this proxy.

## All-16 independent 16M/64M Reference convergence evidence — verified

**GitHub Actions `42440362235` success** at source SHA `f9897a6c06895f67ca6a5d9c3e455ff7135febe3`, report `DIAGNOSTIC_COMPLETE`; retained artifact ID `13601594763`, ZIP SHA-256 `5c09435f850db4f4ed3a134638cfa6204396cb6ee99707684746d220f24eb33d`. The actual ZIP was independently downloaded and SHA-checked. All **32 new raw USI files** (one 16M and one 64M per position) exist; each contains the requested `go nodes N` and terminal `bestmove`. Its `report.json` has the 16 rows and labels, original pilot result/evaluation identities and the original pinned provenance. Pinned YaneuraOu SHA `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`, Suisho5 NNUE SHA `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`, AVX2, clang 18.1.3, and the original USI searchmoves case-preservation patch.

| Criterion | Frozen 4M/16M | New 16M/64M |
|---|---:|---:|
| Reference Structure RESOLVED | 13/16 | **16/16** |
| DISPUTED | 3/16 | **0/16** |
| INSUFFICIENT | 0/16 | **0/16** |
| unresolved rate | 18.75% | **0%** |

Fresh 16M roots reproduce frozen 16M **structure and good sets on all 16**. No previously RESOLVED position became DISPUTED at 64M, and the original three DISPUTED positions (`p06`, `p09`, `p15`) all became RESOLVED.

**Full rank-2 expected-score loss trajectory**, rounded to 6 decimals, with the same `τ_good_ref = 0.050`:

| Pilot position | Original 4M | Repeated 16M | New 64M | 16M/64M verdict |
|---|---:|---:|---:|---|
| p01 | 0.000000 | 0.000763 | 0.000540 | RESOLVED |
| p02 | — | — | — | RESOLVED; negative-mate NO_SAVING_MOVE |
| p03 | 0.000013 | 0.000000 | 0.000000 | RESOLVED |
| p04 | 0.004346 | 0.009537 | 0.009349 | RESOLVED |
| p05 | 0.000002 | 0.000000 | 0.000000 | RESOLVED |
| p06 | 0.054198 | 0.009749 | 0.010929 | RESOLVED |
| p07 | 0.000021 | 0.000005 | 0.000000 | RESOLVED |
| p08 | 0.007606 | 0.000000 | 0.042034 | RESOLVED |
| p09 | 0.053227 | 0.040582 | 0.027405 | RESOLVED |
| p10 | 0.000056 | 0.000059 | 0.000028 | RESOLVED |
| p11 | 0.033149 | 0.013898 | 0.045464 | RESOLVED |
| p12 | 0.024943 | 0.024249 | 0.015323 | RESOLVED |
| p13 | 0.000159 | 0.000196 | 0.000024 | RESOLVED |
| p14 | 0.000009 | 0.000002 | 0.000000 | RESOLVED |
| p15 | 0.050086 | 0.014350 | 0.023178 | RESOLVED |
| p16 | 0.000000 | 0.000001 | 0.000001 | RESOLVED |

For 15 finite pairs, 4M→16M was **10 decreases / 5 increases**; 16M→64M **10 decreases / 4 increases / 1 tie**. Thus convergence is **not** monotone per position. `p08` increased to 0.042034 and `p11` to 0.045464 by 64M: both remain MULTIPLE but are closer to the hard 0.050 boundary. `p07` changed rank-1 from `S*7b` at 16M to `S*6a` at 64M; the two MULTIPLE good sets still intersect at `S*7b`, so the preregistered cross-budget rule returns RESOLVED. This is **structure-classification stability at 16M/64M, not exact-score convergence or identical move ranking**.

This supplies strong **pilot-based grounds to consider** a §12 operational change from **4M/16M to 16M/64M**. It does **not** guarantee that the later 50-position holdout meets 10%, because all 16 are from five permanently excluded games. The run is an excluded-pilot **diagnostic**, not a new C1 PASS, a frozen Reference Authority or an approved amendment.

## Played coverage feasibility: F2-adjusted upper bound, not final certainty

The archived 200k v4 §E E0 source-compatibility upper bound was 13/16 for δ=0.000..0.045, or 6/16 at δ=0.050. The selected **F2** forbids definite played claims from a **large comparison inversion** `I > 0.050`, even when E0's independent source otherwise gives a definite class. In the frozen 200k evidence, `p06-ply-161` has `I=0.186286...` and is therefore `NOT_CLASSIFIABLE`, rather than a confirmed GOOD/MATCH. Three other 200k inversions (`p03`, `p11`, `p15`) are small and are eligible under the already adopted F2 rule without promoting VE1-B stability.

The **F2-adjusted, E0-consistent 200k score-evidence upper bound** is therefore **12/16 = 75%** for δ=0.000..0.045 and **5/16 = 31.25%** at δ=0.050. This is a *necessary source+F2 filter* only. It still does **not** establish the final 70% played coverage because VE1-B upstream qualification/selection and the exact final C1 played-certainty mapping have not been operationally proven. In particular, C1 semantic `CONFIRMED` never promotes VE1-B `confirmedPV` or changes a nonqualifying VE1-B stability tier.

Reproducible CI: feasibility grid rerun `42446834625`, code SHA `211738507c55408a184a14bd5abdb6261042cb5f`, **success**, artifact `13603424172`, digest `sha256:9b0a282d6ed53f3dbd0594b6c6cba997dd0933ff047d571a188a8c38020a761b`. The workflow fixes the original pilot result/evaluation SHAs, asserts E0 13/16, F2-adjusted 12/16 and the exact p06 abstention, and maintains the false-UNIQUE proxy. This is report-only and selects **no δ**.

### Implication for §13.3 decision

**Conditionally favor the Reference-budget amendment candidate, not its immediate adoption.** The unresolved-rate evidence moved from 3/16 to 0/16 without modifying the frozen scoring semantics. However the F2/E0 75% source-evidence ceiling is only slightly above the 70% holdout floor, and the full played-certainty/VE1-B stability gate could reduce that figure. Resolve the exact final played certainty semantics and outcome (under the frozen contract, without VE1-D inspection or δ selection) **before committing to a versioned amendment**. If a §12 change is chosen, increment C1 and rerun the same permanently excluded 16 positions from scratch under newly pinned 16M/64M Reference conditions, retain new raw/Swift parity/cohort evidence, recompute F/E from the preregistered rules, and only then consider final synthetic Freeze gate. In the meantime, original Reference **4M/16M remains the active frozen contract**.

## Proposed 16M/64M operational execution and shard contract (NOT YET APPROVED)

A 16M/64M Reference change increases per-position cost. A single 6-hour hosted job must **never** own the whole future VE1-D/VE1-E population. The following deterministic execution contract is proposed for the **versioned §12 amendment**, but is only a pre-VE1-D design record until adopted. The already running exposed-pilot four-shard targeted diagnostic is a separate prototype and is not itself a production/holdout authorization.

- **Frozen index and partition boundary:** Every position belongs to exactly one predefined tuning, holdout or reserve manifest (and never an excluded pilot game). Freeze each complete manifest SHA before scheduling; use zero-based `ordinal` in that manifest, then `shard = floor(ordinal / 8)`, `shard_local_offset = ordinal % 8`, `shard_count = ceil(position_count / 8)`. Do not group positions by result, Reference label, elapsed time or H1/H3 outcome. Maintain sealed partition-specific working directories and outputs; tuning must not inspect holdout/reserve content.
- **Bounded job:** Up to 8 positions/shard, four independent root/rank1/played searches per 16M/64M? **No — six searches per position**: each node budget has one full root MultiPV and two independent single-target `searchmoves` measurements (rank1 and actual). Add any H3/H4 targeted checks only if separately fixed by the §8 audit plan. Each search has cold `isready→readyok→usinewgame`, original MultiPV `min(3,|MoveList<LEGAL>|)` for the root, MultiPV1 for single targets, Threads1, Hash512 MB, FV_SCALE24, Suisho5/engine/patch identity. Node-limited, no movetime substitution or shortened evidence. Cap each shard job strictly below the hosted **360-minute** hard limit (proposed `timeout-minutes:330`); do not use elapsed-time termination as an alternative accepted node budget. If an 8-position shard cannot fit, **STOP and version the shard plan before any further holdout execution**, not after seeing results.
- **Shard output:** Write `partition_id`, manifest SHA, frozen shard-plan version/digest, shard index/count, expected ordinal interval, each `position_id`, source `game_sha256`, `position_command`, actual move, node budgets, all raw USI stdout command transcripts, terminal `bestmove`, requested searchmoves target, selected exact/coherent block and candidate root PV, TT generations, root LEGAL count and effective MultiPV, full engine/compiler/CPU/NNUE hash provenance. Hash each raw file and normalized per-position output; keep raw logs and failure stage even when one search fails.
- **Fail-closed merger:** For each **partition separately**, require all planned shard artifacts and exact SHA; verify no gaps, duplicate ordinals, duplicate positions or game contamination, per-shard expected ranges, original manifest identities, root and requested-target binding, all node budgets and exact evidence. Sort **only by frozen ordinal**; recompute the per-position labels, statuses, DISPUTED/INSUFFICIENT denominators and aggregate counts from source evidence, not trusted shard summaries. Publish an aggregate manifest, ordered position-digest list and aggregate digest binding every shard and provenance identity. If any shard is missing, timed out, insufficient or fails integrity, mark the aggregation **INCOMPLETE/STOP**; never silently drop bad positions, count them as success or reassign them to reserve.
- **Authorization boundary:** This is a proposed execution protocol. Before production use, approve the §12 version increment, fix the detailed implementation/merger and run regression on the **same 16 permanently excluded pilot positions** with full 16M/64M root + rank1/actual searches, parser/Swift parity and F/E rederivation; only then consider the original **DISPUTED+INSUFFICIENT <=10%** and **coverage >=70%** VE1-D/VE1-E gates. Neither 0/16 diagnostic nor this draft changes the original active 4M/16M Authority.

## Explicit §13.3 disposition before VE1-D

**Invoke `PILOT_FEASIBILITY_AMENDMENT_REQUIRED` as post-PASS feasibility assessment**. This is **not** `PILOT_HOLD`; all four execution-integrity PASS conditions remain satisfied. However **do not** proceed silently to synthetic/final Freeze candidate or VE1-D while these feasibility risks are undecided.

- **Reference all-16 diagnostic COMPLETE / SUCCESS**: run `42440362235`, evidence ZIP `13601594763` digest `sha256:5c09435f850db4f4ed3a134638cfa6204396cb6ee99707684746d220f24eb33d`. The original 4M/16M unresolved 3/16 became 16M/64M unresolved 0/16, with all 16 fresh 16M structures matching the frozen 16M. **16M/64M is a supported §12 candidate, not a formal amendment.** Rank-2 losses remain nonmonotonic, so do not claim numerical convergence. If formally adopted later, C1 version increment and full excluded-pilot rerun are mandatory.
- **Played score-evidence feasibility separately**: the v4 §E E0 upper bound remains 13/16, but **F2 additionally abstains on p06's large 200k inversion**; the verified F2/E0 source-evidence upper bound is therefore **12/16 (75%)** at δ 0..0.045 (5/16 at δ=0.050). It is not yet the final certainty-aware 70% holdout coverage. Confirm VE1-B upstream stability/qualification and the exact C1 certainty mapping before any amendment decision; keep E0, F2, scoring semantics and the 70% floor unchanged.
- The original hard 10% unresolved ceiling, 70% coverage floor, 4M/16M budgets and all thresholds **remain unchanged pending decision**. No amendments are approved in this record.
- Next bounded actions: finish the exact played-certainty/stability coverage mapping against the **12/16 F2/E0 evidence ceiling**, then decide **explicit §12 16M/64M candidate amendment plus C1 version increment/same-16 pilot rerun** or **unchanged 4M/16M with documented HOLD risk**. Do not select δ from this pilot, relax 10%/70%, run synthetic Freeze or inspect VE1-D before the decision.

This document is report-only analysis and a **pre-Freeze review decision**, not a replacement for the single future C1 Freeze Authority.
