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

## Delta grid: report-only coverage prognosis

Frozen candidate structure logic at the primary App 200k tier:
- `MULTIPLE_GOOD` iff rank-2 loss `<= 0.050 - delta`; `UNKNOWN` iff inside the ambiguity band through `0.050 + delta`; otherwise `UNIQUE_GOOD` (respecting mate and missing-snapshot cases). A `CROSS_AXIS_CONFLICT` invalidates a purported definitive UNIQUE claim.
- **Structure coverage proxy**: count of 16 with definitive App 200k Candidate Structure after the C1 cross-axis guard, including definite `NO_SAVING_MOVE` if observed.
- **Played coverage proxy (adopted E0, strict)**: count of 16 where the actual move has both (a) a finite **root MultiPV** loss and (b) a same-tier independently measured comparison loss, and both frozen `app_allowed_classes(loss, delta)` are the **same singleton class**; the existing fail-closed target binding must pass. `F2` is still the adopted small-inversion policy, and no inversion-induced MATCH promotion is allowed. Do **not** treat a single-source class as E0 confirmation.
- These are deliberately conservative **one-position/200k proxies**, **not** a final preregistered 50-position holdout gate or a new threshold. `delta` has not been selected. The total three-tier `CROSS_AXIS_CONFLICT=5` and `E1-only=42` recompute to exactly the archived evaluator totals, giving an independent arithmetic crosscheck.

| delta | App structure definitive /16 | E0 played definitive /16 | Independent comparison singleton /16 | Both root+comparison available /16 |
|---:|---:|---:|---:|---:|
| 0.000 | 16 | 3 | 15 | 5 |
| 0.005 | 15 | 3 | 15 | 5 |
| 0.010 | 15 | 3 | 15 | 5 |
| 0.015 | 14 | 3 | 15 | 5 |
| 0.020 | 14 | 3 | 15 | 5 |
| 0.025 | 13 | 3 | 15 | 5 |
| 0.030 | 10 | 3 | 15 | 5 |
| 0.035 | 10 | 3 | 15 | 5 |
| 0.040 | 9 | 3 | 15 | 5 |
| 0.045 | 8 | 3 | 15 | 5 |
| 0.050 | 1 | 1 | 9 | 5 |

At delta 0, strictly reconciled E0 played claims were `p03-ply-115`, `p04-ply-10` and `p16-ply-143`. In 10 other positions the actual move did not occur among the App 200k MultiPV root candidates, and one additional position lacked a finite comparison loss; **increasing Reference budget alone cannot supply the missing App root score source**. The 70% played-coverage floor is not supported by this conservative E0 proxy at **any** delta. Conversely, App structure coverage is >= 12/16 (75%) only for delta 0.000–0.025. Neither observation licenses choosing a favorable delta from pilot outcomes.

## Explicit §13.3 disposition before VE1-D

**Invoke `PILOT_FEASIBILITY_AMENDMENT_REQUIRED` as post-PASS feasibility assessment**. This is **not** `PILOT_HOLD`; all four execution-integrity PASS conditions remain satisfied. However **do not** proceed silently to synthetic/final Freeze candidate or VE1-D while these feasibility risks are undecided.

- Track **(b), possible shallow 4M Reference**: first measure the **same three exposed pilot positions** with pinned conditions at 16M/64M as a bounded diagnostic (not a holdout, not a selected operational budget). If 16M/64M are structurally consistent, an *explicit* §12 Reference budget amendment can be proposed; it would require a C1 version increment and a full rerun of the same excluded 16-position pilot **before** Freeze. Merely reaching exact at 16M does not prove budget convergence.
- Track **E0 played coverage limitation** separately: the very low two-source availability (5/16 at 200k) cannot be addressed by a 4M→16M Reference budget change. The §12 operational allowance does **not** permit changing adopted E0, candidate/root evidence meaning, score semantics or the sampling rule. Do not lower the 70% floor merely to force PASS. Establish the precise final holdout coverage denominator and assess whether a permissible operational amendment exists; otherwise explicitly retain the risk, or HOLD the Freeze candidate for a properly versioned semantic redesign (not an improvised post-pilot rule).
- The original hard 10% unresolved ceiling, 70% coverage floor, 4M/16M budgets and all thresholds **remain unchanged pending decision**. No amendments are approved in this record.
- Next bounded actions: targeted pinned Reference convergence diagnostic on three pilot positions; clarify final coverage metric without VE1-D inspection; decide **amendment with version+same-pilot rerun** or **unchanged contract with explicit HOLD risk**, then only remaining synthetic/final regression if authorized.

This document is report-only analysis and a **pre-Freeze review decision**, not a replacement for the single future C1 Freeze Authority.
