# Build19 VE1-C1 — Post-Pilot Feasibility Review

Date: 2026-11-08
Status: **PILOT_PASS / PILOT_FEASIBILITY_AMENDMENT_REQUIRED — ASSESSMENT OPEN / NO AMENDMENT APPROVED**
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

## Explicit §13.3 disposition before VE1-D

**Invoke `PILOT_FEASIBILITY_AMENDMENT_REQUIRED` as post-PASS feasibility assessment**. This is **not** `PILOT_HOLD`; all four execution-integrity PASS conditions remain satisfied. However **do not** proceed silently to synthetic/final Freeze candidate or VE1-D while these feasibility risks are undecided.

- Track **(b), possible shallow 4M Reference**: compare **ALL 16 permanently excluded pilot positions**, not just the three originally DISPUTED cases, at freshly measured pinned 16M/64M with identical engine/NNUE/TT/MultiPV conditions. The 4M values come from the immutable pilot artifact; preserve the full 4M→16M→64M rank-2 loss trajectory and compare cross-budget DISPUTED/INSUFFICIENT rates over all 16. Code commit `f9897a6c06895f67ca6a5d9c3e455ff7135febe3`, independent action `42440362235` was started; **do not record a result until this run completes and the artifact is checked**. A justified §12 reference budget amendment would require C1 version increment and complete same-16 pilot rerun.
- Track **played coverage with correct source availability**: 13/16 (81.25%) is the 200k E0 **upper bound** for δ 0..0.045 after excluding genuine conflicts; this corrects the former 3/16 claim. Confirm final played certainty, F2 and VE1-B stability and the holdout 70% denominator before Freeze. The §12 allowance does **not** authorize changing adopted E0, scoring semantics or sampling. No coverage-floor relaxation is approved.
- The original hard 10% unresolved ceiling, 70% coverage floor, 4M/16M budgets and all thresholds **remain unchanged pending decision**. No amendments are approved in this record.
- Next bounded actions: retrieve **ALL-16** pinned 16M/64M convergence diagnostic evidence; compute final certainty-aware played coverage separately from its 13/16 E0 upper bound; then decide **amendment with version+same-pilot rerun** or **unchanged contract with explicit HOLD risk** before final synthetic/Freeze. No VE1-D inspection.

This document is report-only analysis and a **pre-Freeze review decision**, not a replacement for the single future C1 Freeze Authority.
