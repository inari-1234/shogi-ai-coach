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

### App false-UNIQUE structural proxy by δ (report only; not H3)

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

At 50k the repeatedly affected position is `p12-ply-126`; at 100k, `p04-ply-10`, `p08-ply-81`, `p12-ply-126` are exposed at δ<=0.015. At the **primary 200k tier** the false-UNIQUE proxy is **0/12 at every δ**. This is evidence of shallower-tier instability, but the pilot does **not** demonstrate a persisting primary-tier H1 failure. **Gate separation:** H3 tests whether a move emitted as `UNIQUE_RECOMMENDATION` belongs to the Reference good set. It is **not** a played-move disagreement test, and none of the Reference GOOD → App SOMEWHAT_WORSE cells can be called an H3 violation. The full H3 recommendation-membership gate remains a separately owned evaluation.

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
- **Bounded job:** Up to 8 positions per shard, **six independent searches per position**: at each of the two node budgets (16M and 64M), one full root MultiPV search and two single-target `searchmoves` measurements (rank1 and actual). Add any H3/H4 targeted checks only if separately fixed by the §8 audit plan. Each search has cold `isready→readyok→usinewgame`, original MultiPV `min(3,|MoveList<LEGAL>|)` for the root, MultiPV1 for single targets, Threads1, Hash512 MB, FV_SCALE24, Suisho5/engine/patch identity. Node-limited, no movetime substitution or shortened evidence. Cap each shard job strictly below the hosted **360-minute** hard limit (proposed `timeout-minutes:330`); do not use elapsed-time termination as an alternative accepted node budget. If an 8-position shard cannot fit, **STOP and version the shard plan before any further holdout execution**, not after seeing results.
- **Shard output:** Write `partition_id`, manifest SHA, frozen shard-plan version/digest, shard index/count, expected ordinal interval, each `position_id`, source `game_sha256`, `position_command`, actual move, node budgets, all raw USI stdout command transcripts, terminal `bestmove`, requested searchmoves target, selected exact/coherent block and candidate root PV, TT generations, root LEGAL count and effective MultiPV, full engine/compiler/CPU/NNUE hash provenance. Hash each raw file and normalized per-position output; keep raw logs and failure stage even when one search fails.
- **Fail-closed merger:** For each **partition separately**, require all planned shard artifacts and exact SHA; verify no gaps, duplicate ordinals, duplicate positions or game contamination, per-shard expected ranges, original manifest identities, root and requested-target binding, all node budgets and exact evidence. Sort **only by frozen ordinal**; recompute the per-position labels, statuses, DISPUTED/INSUFFICIENT denominators and aggregate counts from source evidence, not trusted shard summaries. Publish an aggregate manifest, ordered position-digest list and aggregate digest binding every shard and provenance identity. If any shard is missing, timed out, insufficient or fails integrity, mark the aggregation **INCOMPLETE/STOP**; never silently drop bad positions, count them as success or reassign them to reserve.
- **Authorization boundary:** This is a proposed execution protocol. Before production use, approve the §12 version increment, fix the detailed implementation/merger and run regression on the **same 16 permanently excluded pilot positions** with full 16M/64M root + rank1/actual searches, parser/Swift parity and F/E rederivation; only then consider the original **DISPUTED+INSUFFICIENT <=10%** and **coverage >=70%** VE1-D/VE1-E gates. Neither 0/16 diagnostic nor this draft changes the original active 4M/16M Authority.

## New Reference 16M/64M: structure and played confusion-cell feasibility (report only)

**Independent grid CI PASS:** run `42452415770`, code commit `de29827dea403fca7761c09f0330bf453ee463a3`, artifact `13605174997`, digest `sha256:b6a32103098cf16b4d1f003c1edb320cf1200744f639097d37f6ed013fd86a97`. Reads original frozen pilot SHA and the 16M/64M root diagnostic for *all 16*, verifies 16 RESOLVED and Reference labels of 15 MULTIPLE_GOOD plus 1 NO_SAVING_MOVE; no new sampling, δ selection or budget amendment.

- At the C1 primary App 200k tier, the false UNIQUE proxy (Reference 16M/64M **MULTIPLE_GOOD** but App **UNIQUE_GOOD** after the CROSS_AXIS_CONFLICT guard) is **0/15 across all 11 δ values**. The structure definitive counts `[16,15,15,14,14,13,10,10,9,8,1]` remain as in the old Reference analysis. With `δ_final=δ_min+0.010`, structure >=70% requires `δ_min<=0.015` in this pilot; this is compatibility evidence, not an invitation to choose δ using pilot outcomes.
- **Initial top-three-based played confusion-cell observation (NOT H3):** `p04-ply-10` and `p09-ply-7` have the **actual move in the shared 16M∩64M Reference GOOD set**, while App 200k assigns `SOMEWHAT_WORSE`. This first root-based view saw two cases; the independent played search later correctly found a third, `p01-ply-282`, outside the top-three root candidates. These are **Reference GOOD → App SOMEWHAT_WORSE**, a preregistered **report-only confusion-matrix cell**, not the H3 hard gate. Absence from the root top-three is not evidence of NONMEMBER.
- Swift's **actual frozen VE1BStabilityReclassifier** replay on the exact same pilot was independently run: `42452566184` success; artifact `13605478876`, digest `sha256:bc515d8f74cf13613e39623ec776e104eb839ac5aff7755b2f50dedc34eed667`. **Stable=4/16: p08, p09, p10, p12**. In particular, p09 is stable upstream while p04 is not, but C1 `playedMoveCertainty` is **not** identical to VE1BStability and must be determined independently. Do not promote a non-stable VE1-B tier to confirmedPV because of any C1 semantic label.
- The previous pending pilot-only 4-shard diagnostic `42452851691` was superseded after the negative-mate `NO_SAVING_MOVE` rank1 root identity fix. Its validated successor `42453160640` on code SHA `b689b28c674760f5ca641c41a3f2fc8d9cb74242` **COMPLETED SUCCESS**, four independent shards and the fail-closed merger all succeeded. The future §12 shard design for VE1-D remains distinct, proposed and unapproved.

**Uncertainty bound:** Zero observed Reference structure disputes out of 16 is evidence of feasibility, **not** proof that true unresolved probability is <=10%. The rule-of-three gives an approximate 95% upper risk near **3/16 ≈ 19%**. p08 and p11 still approach the 0.050 boundary at 64M. The hard **DISPUTED+INSUFFICIENT ceiling remains 10%** if any amendment is approved.

## Completed all-16 independent Reference played-move audit — report-only confusion matrix

**Run `42453160640`: SUCCESS, 4/4 shards + merger SUCCESS, source SHA `b689b28c674760f5ca641c41a3f2fc8d9cb74242`.** Each shard is a strictly frozen pilot-only set of four positions, with Reference 16M and 64M independent one-target `searchmoves(rank1)` and `searchmoves(actual)` for each position. Results are **diagnostic**, not an amended 16M/64M pilot or VE1-E holdout.

| Artifact | ID | ZIP SHA-256 |
|---|---|---|
| shard 0 | `13606234854` | `00654098524c434b6ca5c42abf044132967155d964ad8560fbbed1c092ab31b1` |
| shard 1 | `13606483353` | `f9cb0ad4099a81fa40761c875b0fb75fdc34b6bbeac9ce454d1d3b36b2537a5d` |
| shard 2 | `13607056946` | `2caa00cfc464195b887efb5e4ebe624069c07febfae82357a14a34336ca310d9` |
| shard 3 | `13607146494` | `368a4b31d48465418076a6491223432f508552fe4c7eac36738f1d6f112a0ccc` |
| merged | `13606144428` | `25f22d9750ed3dbb0702d316be119f108e8e2516624855d0184c821d72726c33` |

**Independent saved-evidence inspection:** All five ZIP files were downloaded and their whole-file SHA-256 digests matched. Each shard reports `SHARD_COMPLETE` for its four exact position ordinals; merged report is `DIAGNOSTIC_COMPLETE` for 16/16. Across **64/64** raw USI logs, the SHA-256 agrees with the shard manifest, the requested `go nodes N searchmoves X` occurs in the raw transcript, terminal `bestmove` equals the requested move, the selected rank-1 PV root equals the requested move, and every search has `candidateBlockStatus=RESOLVED` and `selectedSnapshotEvidenceStatus=RESOLVED`. This inspection supports the reported fail-closed merger; it does not constitute a separate cross-language parser revalidation.

**Reference played classification (independent 16M and 64M):**

| Cross-budget Reference played result | Positions |
|---|---:|
| `CONFIRMED_GOOD` (both GOOD) | **15/16** |
| `CONFIRMED_NON_GOOD` | **0/16** |
| `DISPUTED` | **0/16** |
| `INSUFFICIENT` | **1/16**, `p02-ply-156` negative mate `NO_SAVING_MOVE` |

Distinguish these axes: **Reference root-structure** diagnostic is RESOLVED 16/16 with DISPUTED+INSUFFICIENT 0/16; **independent played** membership is GOOD 15/16 with INSUFFICIENT 1/16. The 10% unresolved target must retain its authority-defined denominator; neither status is silently dropped or merged into a favorable denominator.

**Reference GOOD → App SOMEWHAT_WORSE: three report-only cells under adopted App 200k F2/E0:**

| Position | App 200k independent `comparisonLoss` | App semantic class | Reference played 16M / 64M `loss` | Reference verdict | Frozen VE1-B stability |
|---|---:|---|---:|---|---|
| `p01-ply-282` | 0.119460 | `SOMEWHAT_WORSE` | 0.000000 / 0.000000 | GOOD / GOOD | `unstable` |
| `p04-ply-10` | 0.133525 | `SOMEWHAT_WORSE` | 0.037865 / 0.016234 | GOOD / GOOD | `unstable` |
| `p09-ply-7` | 0.101027 | `SOMEWHAT_WORSE` | 0.021463 / 0.010985 | GOOD / GOOD | `stable` |

At all 11 preregistered δ values, the merged report's legacy field `H3IndependentPlayedMismatch` contains the **same three played confusion-cell cases** `[p01-ply-282, p04-ply-10, p09-ply-7]`. **The field name is incorrect; the values are NOT H3.** The correct report-only confusion-matrix denominator is **15 independently Reference-CONFIRMED_GOOD positions**, of which **3/15 (20%)** are App `SOMEWHAT_WORSE`. Among these 15 there are **0 App `BLUNDER` under the adopted F2/E0 classification**, hence **0/15 for the H2-related GOOD → BLUNDER cell**. The separate App F2/E0 score-evidence classifiable count is **12/16** at δ=0.000–0.045 and **5/16** at δ=0.050; it must not replace the 15-position confusion-matrix denominator. The frozen historical artifact and run logs retain their legacy key for provenance; future interpretation must use the corrected name `referenceGOODtoAppSOMEWHAT_WORSE`.

**Critical evidence distinction:** `p04` and `p09` have their actual move in the 16M/64M root good-set intersection; `p01` does **not** have its actual move in the top-three root good-set intersection, yet is independently **GOOD at both budgets**. Omitting `p01` because it is outside top-three would be a false `NONMEMBER` and violate the pre-pilot §8 independent played-search rule. This is why the full 16-position targeted search was necessary.

**Interpretation and gate separation:** At the primary App 200k tier, the **false-UNIQUE structural proxy is 0/15** across the δ grid and the structure definitive count at δ=0.025 is 13/16 (81.25%). The **played-move overcriticism cell is 3/15 (20%)**, separately report-only, not H3 and not a posthoc hard gate. All three App losses (0.119460, 0.133525, 0.101027) exceed the maximum good-boundary upper limit `τ_good+δ <= 0.100`, so the discrepancy cannot be absorbed by choosing a δ from the allowed grid. Frozen VE1-B stability is `unstable` for p01/p04 and `stable` for p09. **p09 warrants explicit product-display risk review** for definitive undue criticism, but stable status alone is not a direct observed screenshot of product text; VR1B should review actual wording. **H3 remains the separate test of a `UNIQUE_RECOMMENDATION` move's Reference good-set membership**, and has not been established by these three played cases.

Any eventual §12 operational amendment may alter only permitted operational parameters (e.g. Reference budgets / recovery), not H1–H5 meanings, adopted F2/E0 or score thresholds. The tradeoff is thus open: 16M/64M gives promising 0/16 root structural disputes, while **the report-only GOOD → SOMEWHAT_WORSE cell remains 3/15**, with potential product overcriticism. This cell does **not** itself block C1 as an H3 or H2 hard-gate failure, and it must not be promoted into a new hard gate after observing the pilot. No changed budget, δ selection, 70% floor, 10% ceiling or C1 Freeze is authorized by this diagnostic.

### Corrected labeling independently reproduced (report-only)

GitHub Actions **`42528637400` SUCCESS** at code SHA `8df3eae3995fbecd65c228d567a87eee064082aa` ran `ve1c1_played_confusion_cell_report.py` against the **unaltered** original 16-position pilot result/evaluation, all-shard merged Reference played artifact and frozen Swift VE1-B stability report. Corrected artifact **`13635949602`**, ZIP SHA-256 **`c77295cef438ee306619d48d937a0368ee53b5549c2d4d9e0e650f1dc3219a44`** was downloaded and independently hash-checked; its `report.json` has `REPORT_ONLY_RECONCILED`, all 11 δ rows have **3/15 Reference GOOD → App SOMEWHAT_WORSE, 0/15 GOOD → App BLUNDER**, the three fixed pilot IDs, **H3_formal_gate_assessed=false**, and **H5 observed Reference BLUNDER denominator=0**. Its source domain is explicitly the frozen computer-engine tournament, not human professional or amateur games. Original merged ZIP and misnamed historic JSON fields are immutable; the corrected artifact supplies the authoritative **interpretive label for the report-only metric**, not a changed freeze authority or a new H3 gate.

## Feasibility risk (a): H5 minimum denominator of 10 Reference BLUNDER cases

The pilot's independent 16M/64M Reference played results are **15 CONFIRMED_GOOD / 0 CONFIRMED_NON_GOOD / 0 DISPUTED / 1 INSUFFICIENT**. Therefore **zero Reference BLUNDER cases were observed in this 16-position pilot**, and the pilot contributes **0 eligible H5 BLUNDER denominator cases**. A future VE1-E H5 denominator requirement of **at least 10** cannot be assumed achievable from this evidence. This is a *denominator feasibility risk*, not an observed H5 numerator violation or permission to relax the requirement.

The 0/16 observed count is not proof that the underlying population never contains blunders. Nevertheless, a holdout50 denominator of 10 needs at least 20% Reference BLUNDER examples among the selected positions. The current strongly played source distribution gives no demonstrated basis for that rate. The `PILOT_PASS` execution result is unaffected, while the future H5 opportunity gate may HOLD for an insufficient denominator even if its violation count is zero.

**Required before VE1-D:** document the exact frozen H5 eligible-opportunity definition and denominator counting, perform an *independent pre-corpus source-domain feasibility assessment* (without examining tuning/holdout/reserve labels), and decide whether the planned source can realistically produce enough eligible H5 examples. Do not invent BLUNDER examples, drop hard cases, substitute failing reserve examples or decrease the denominator minimum after seeing holdout results.

## Feasibility risk (b): source-game population does not represent typical amateur users

The immutable C1 pre-pool contract `BUILD19_VE1_C1_PRE_POOL_CONTRACT_20261014.md` §1 identifies the sole input source as `denryusen:dr4-hardware2:2024`, **the 2024 Denryu-sen unified-hardware computer-shogi competition**. Its `BUILD19_VE1_C1_NATURAL_PILOT_MANIFEST_20261014.json` binds all 16 pilot positions to **five distinct games from that same computer-engine competition**. This is **not human professional-game data and not amateur-user gameplay**. Engine-vs-engine games naturally contain fewer large human errors, which is a plausible explanation of the 15/16 GOOD and H5 denominator scarcity; this hypothesis is not yet independently established for actual users.

Population validity and algorithmic validity are different: parser parity, run integrity and Reference agreement on these 16 positions do not establish performance on games played by amateur users. Using only a high-strength engine-game distribution to select thresholds and evaluate error-cell coverage risks a selection/covariate shift. The original frozen sampling and exclusions remain immutable; no after-the-fact pilot replacement or access to VE1-D holdout is permitted.

**Required decision before VE1-D:** explicitly document the intended product user population, the observable mismatch between that population and the frozen competition-game source, a partition-safe and rights-checked plan for representative game domains if needed, and how source proportions / game-level splits / eligible H5 opportunities will be specified **before** sampling. Changing the **source corpus or eligibility/sampling rule is NOT within §12's permitted operational feasibility amendments**; that would require a distinct, approved versioned contract/corpus decision and preservation of all prior evidence/exclusion boundaries before any new corpus creation. Do not silently broaden §12 to authorize a new sampling population.

The public source/rights survey is recorded in `BUILD19_VE1_C1_AMATEUR_CORPUS_SOURCE_SURVEY_20261109.md` (2026-11-09). It documents lishogi API ambiguity, 81Dojo script-access prohibition, HEROZ's explicit 2026 restrictions and Shogi Club 24's 2025 closure. **Source due diligence is not acquisition authorization.**

### Supply-sizing refinement (2026-11-09; no authorization)

The human-amateur primary cohort may need **only ~60–100 contributed games** to supply the tuning/holdout selected-position quotas plus a new excluded pilot and reserve, rather than a massive online archive. This is a **contingent supply target**, not the required number of qualifying positions. Under the planned minimums, tuning/holdout together require ≥100 selected positions across ≥30 distinct games (≥15 each), with ≤4 selected positions per game. New pilot (≥4 games, 16 selected positions), reserve and zero-output/unusable games increase supply requirements; rights-cleared local records are not automatically eligible production-selector outputs.

H5 uncertainty remains: a **hypothetical** 30% Reference BLUNDER rate among selected human positions yields only about **63.5%** chance of ≥10 in 35 under independent-binomial assumptions, vs **96.0%** with 50; actual rates and within-game dependence are unknown. No H5 guarantee, source outcome filtering or post-Reference supplementation is authorized. Before fixing source quotas/strata, gather a **metadata-only, consent-aware local inventory** by contributor, broad skill band, available game count, time-control/completion status and platform permissions. Do not upload private games or personal identities to GitHub. The related procedure is documented in `BUILD19_VE1_C1_AMATEUR_CORPUS_SOURCE_SURVEY_20261109.md`.

**Priority adjustment:** A-only human contributor corpus if feasible; recruit additional consenting humans or seek lishogi permission only for missing strata/volume; weak-engine B remains optional secondary stress coverage with separate reporting, not an automatic H5 workaround. No corpus Authority is approved.

## §13.3 priority decision — mother-population redesign before budget selection (2026-11-09)

**Priority: SOURCE-POPULATION CONTRACT REVIEW FIRST / REFERENCE 16M-64M SECOND. Decision status: REQUIRED_REVIEW, NOT APPROVED.** This note records the pre-corpus engineering decision order, **not** a third §13.3 disposition or an amendment to the frozen pre-pilot contract. Original §13.3 still permits only (i) an explicit §12 operational amendment and same-excluded-pilot rerun, or (ii) retaining the original contract with acknowledged HOLD risk. **Changing corpus source, population mix or sampling rules is outside §12 and needs a separate successor versioned corpus/pre-pool contract approved before looking at its candidate results.**

### Why source population has precedence

1. **H5 opportunity scarcity:** Original engine-vs-engine 16-position pilot yielded **0/16 eligible Reference BLUNDER observations** and 15 independently confirmed GOOD. A future H5 prerequisite of at least 10 qualifying BLUNDER opportunities is therefore **not demonstrated feasible** in this population. This is evidence of risk, **not** proof of a zero underlying BLUNDER rate or a guarantee of HOLD.
2. **Possible engine-family/reference alignment (UNVERIFIED):** Both the source and Reference are shogi engines; the source engines may share implementation/evaluation ancestry or preferences with YaneuraOu/Suisho5. That can bias apparent MATCH/GOOD upward and conceal independent-generalization weaknesses. **No per-game participant-engine genealogy, NNUE hash or strength alignment has yet been verified**; do not claim that named competition participants use YaneuraOu/Suisho or assert causality without source-level evidence. Add an engine-identity overlap audit as part of corpus suitability review.
3. **Target population validity:** The actual product use case is amateur human game analysis, while frozen `denryusen:dr4-hardware2:2024` games are **computer-vs-computer**. Good performance on this particular engine competition does not establish human BLUNDER detection, undue-criticism behavior or UNIQUE claims in amateur positions. The report-only GOOD→SOMEWHAT_WORSE cell **3/15**, including stable p09, remains useful diagnostic evidence; it is **not H3** and is not to be turned into a new hard gate.

### Candidate source designs — no option selected yet

| Candidate | Intended role | Acceptance prerequisite | Limitation |
|---|---|---|---|
| **A: human amateur KIF/record corpus** | **Preferred primary source** matching intended users | Verifiable per-source redistribution/processing rights, acquisition terms, privacy and pseudonymization handling, provenance, and available rating/skill-band metadata (if used) | Cannot assume a public game is freely reusable; no personal identifiers or nonconsensual private records in distributed artifacts |
| **B: weak/handicapped engine self-play** | Reproducible *auxiliary/stress* source | Pin engine/NNUE strength settings, seeds, opening distributions, source labeling and exact reproducibility | Error mechanisms may differ from human mistakes; **not a substitute** for target-population validation |
| **C: A-primary/B-auxiliary fixed mix** | Fallback only if an adequate A-only sample is not feasible but usable A data exists | **Precommit the A:B ratio, per-source allocation, eligibility, sampling sequence, split policy and separately reported per-domain metrics before any Reference labeling** | Mixing can inflate H5 opportunity counts without proving human-user validity; maintain a separately interpretable human-source result |

**Pre-corpus source eligibility gates:** documentary rights/terms check by source; human-participant privacy policy including personal identifiers and any platform terms; known game count and deterministic raw-byte SHA-256 manifest; basic parsing/legal-move quality; target-level/strength metadata availability and permissible **pre-Reference** stratification (e.g. rating bands); no filtering by later Reference `BLUNDER`, coverage, `UNIQUE`, desired H5 opportunities or App errors. Do not use already-viewed VE1-D tuning/holdout/reserve data to make this decision.

### Required successor contract and replay boundaries

1. **Source decision first:** Document eligibility of A and B, including evidence of licenses and source access, population representativeness and risk of same-family engine circularity. Select A-primary if feasible; if not, consider C with **A still present** and B solely auxiliary. If neither provides representative permitted human games, record a **source-feasibility HOLD**, not a quietly substituted B-only success.
2. **Separate successor Authority before new data results:** Explicitly version the corpus/pre-pool contract and new source universe, pin manifest sha256 and rights/privacy handling, deterministic seed/ordering, source proportions, pre-Reference rating strata, game-level train/holdout/reserve partition and sampling; lock every partition and all contamination exclusions **before any new pilot or Reference labels**. Reuse the same actual production Swift deep selector and 16-position/≥4-game/≤4-per-game rule **only if explicitly carried forward** into the approved successor; do not claim the old contract silently covers a changed mother population.
3. **New 16-position pilot:** Reexecute on **newly selected excluded positions from the new mother population** under a preregistered successor configuration. Mechanically **reselect F0/F2 and E0/E1 using the same prerecorded decision rules**, without assuming old engine-pilot F2/E0 generalize. Record full raw USI/Swift parity, Reference coherent block, 200k App behavior, played and structure coverage, H1/H2/H3/H4 opportunities, H5 qualifying denominator and population-specific report-only confusion cells. Any new interpretation must be frozen *before* inspecting new sample outcomes; do not redefine PASS, H-gates or source quotas after the result.
4. **Reference budgets second, jointly frozen for successor:** Existing all-16 16M/64M evidence **supports** considering this candidate over 4M/16M (root structure unresolved 3/16 → 0/16) but does not guarantee 10% on human amateur games; score nonmonotonicity at p08/p11 remains. Before the new pilot, choose the successor's 4M/16M or 16M/64M budgets **together with** source, shard sizing, hash/provenance and fail-closed merger. The old §12 **same-original-16 rerun** is required if the old contract is amended operationally; **a new-population 16 does not retroactively count as that rerun**. If creating a separate successor Authority instead, it must explicitly specify its own full acceptance/replay gates and preserve the untouched historic branch.
5. **Prospective quality gates and statistical honesty:** Keep original **10% unresolved ceiling, 70% coverage floor, H5 ≥10 opportunity requirement, F/E adoption rules and semantic meanings** unless a *separately authorized pre-data successor design decision* explicitly modifies them. Do not use source mixing to bypass a target-population floor; report human-source/engine-source outcomes separately and avoid presenting B-only success as A-population validation. No pilot-based `δ` selection or BLUNDER-only resampling.
6. **Authority and evidence retention:** The former `PILOT_PASS` (run `42413155051`), original 4M/16M frozen manifest and exclusion Authority, F2/E0 outcomes, diagnostic 16M/64M runs, original raw logs and hashes **remain valid historical engine-population evidence**, not rejected or deleted. The Reference budget lesson is transferable as a *methodological concern*, not a universal numeric performance guarantee. All original exposed game hashes, B6 fixture and previously exposed seed games remain contamination-excluded in any successor as applicable. No current C1 Freeze, VE1-D inspection or deployment authorization is implied.

### Present §13.3 disposition

**`PILOT_PASS` unchanged; `PILOT_FEASIBILITY_AMENDMENT_REQUIRED` review OPEN. No source corpus selected, no successor Authority approved, no §12 budget amendment approved, no new pilot executed.** First obtain independently verifiable candidate A access/terms and determine target population / H5 opportunity feasibility. Only then choose the successor source and Reference budget as one preregistered design, with separate approval gates. The original §13.3 allowed dispositions remain intact.

## Explicit §13.3 disposition before VE1-D

**Invoke `PILOT_FEASIBILITY_AMENDMENT_REQUIRED` as post-PASS feasibility assessment**. This is **not** `PILOT_HOLD`; all four execution-integrity PASS conditions remain satisfied. However **do not** proceed silently to synthetic/final Freeze candidate or VE1-D while these feasibility risks are undecided.

- **Reference all-16 diagnostic COMPLETE / SUCCESS**: run `42440362235`, evidence ZIP `13601594763` digest `sha256:5c09435f850db4f4ed3a134638cfa6204396cb6ee99707684746d220f24eb33d`. The original 4M/16M unresolved 3/16 became 16M/64M unresolved 0/16, with all 16 fresh 16M structures matching the frozen 16M. **16M/64M is a supported §12 candidate, not a formal amendment.** Rank-2 losses remain nonmonotonic, so do not claim numerical convergence. If formally adopted later, C1 version increment and full excluded-pilot rerun are mandatory.
- **Played score-evidence feasibility separately**: the v4 §E E0 upper bound remains 13/16, but **F2 additionally abstains on p06's large 200k inversion**; the verified F2/E0 source-evidence upper bound is therefore **12/16 (75%)** at δ 0..0.045 (5/16 at δ=0.050). It is not yet the final certainty-aware 70% holdout coverage. Confirm VE1-B upstream stability/qualification and the exact C1 certainty mapping before any amendment decision; keep E0, F2, scoring semantics and the 70% floor unchanged.
- The original hard 10% unresolved ceiling, 70% coverage floor, 4M/16M budgets and all thresholds **remain unchanged pending decision**. No amendments are approved in this record.
- **Prioritized next action as of 2026-11-09:** source-population suitability and rights/privacy/engine-family audit **FIRST**, decide A-primary versus C (A-primary/B-auxiliary fixed mix) and a separately versioned corpus/pre-pool successor **before any corpus creation**. **SECOND**, choose Reference 16M/64M candidate and fixed sharded evidence plan together with the successor design, then new excluded 16-position pilot and F/E re-selection under the precommitted rules. Continue evaluating H5 opportunity feasibility (0 observed in historical pilot), eventual H1–H5 gate coverage and final C1 played certainty. Do not silently classify old GOOD→SOMEWHAT_WORSE as H3, relax frozen requirements, or inspect VE1-D.

This document is report-only analysis and a **pre-Freeze review decision**, not a replacement for the single future C1 Freeze Authority.
