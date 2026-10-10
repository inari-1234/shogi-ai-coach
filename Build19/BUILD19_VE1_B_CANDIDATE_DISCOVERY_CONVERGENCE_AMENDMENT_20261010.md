# Build19-VE1-B — Candidate Discovery Convergence Amendment

Date: 2026-10-10
Status: **NORMATIVE VE1-B CONTRACT AMENDMENT / IMPLEMENTATION IN PROGRESS**

This amendment supplements `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`. Where the earlier wording can be read as allowing a shallow candidate-discovery result to be frozen and then only re-compared with `searchmoves`, this amendment supersedes that reading.

## Defect being corrected

The first VE1-B implementation selected `discoveredBest` from one shallow MultiPV discovery search and then ran only a fixed `searchmoves discoveredBest actual` series at increasing node budgets. That can prove convergence of a fixed pair while never checking whether unrestricted deeper search still considers `discoveredBest` the leading candidate.

Therefore a fixed-pair series alone is insufficient to satisfy B5.

## Revised B5 candidate-conclusion rule

Candidate identity is part of the convergence conclusion.

For each ordered depth stage, VE1-B must retain an unrestricted MultiPV candidate-discovery observation. The candidate Top-1 identity at that stage is included in the stability fingerprint together with the fixed-pair comparison conclusion.

Required behavior:

1. candidate discovery is re-run at increasing node tiers rather than performed only once at the shallowest tier;
2. each candidate-discovery tier starts from a cold TT boundary so ranking at a deeper budget is not merely inherited from the shallower discovery search;
3. the full emitted MultiPV observations and ordering are preserved as evidence;
4. a Top-1 change between the highest qualifying increasing tiers prevents `stable` even when the later fixed-pair `searchmoves` comparison itself agrees;
5. `N -> 2N -> 4N` may still converge after an earlier disagreement only when the highest qualifying tiers agree under the complete fingerprint;
6. bounded/aborted/inconsistent discovery evidence cannot qualify a tier for stability.

The calibration fixture currently uses candidate-discovery tiers `50k -> 100k -> 200k`; these numbers remain **UNFROZEN_CALIBRATION**, not production authority.

## Direct-comparison role remains separate

After candidate discovery, direct comparison starts from a fresh cold TT boundary. The deepest unrestricted candidate Top-1 is used for the fixed-pair diagnostic series against the actual move. Within that fixed-pair confirmation series, TT may be retained across increasing node tiers under the existing B6 staged-reuse contract.

Candidate-discovery history must not seed direct comparison.

## Multiple-good-move boundary

VE1-B does **not** invent a new cp threshold for "nearly equal" candidates. Numerical grouping of multiple good moves remains VE1-C calibration scope.

VE1-B instead:

- preserves the full ranked MultiPV evidence at every discovery tier;
- treats Top-1 identity changes as search-confidence evidence;
- does not equate ranking instability with position importance;
- leaves semantic `UNIQUE` / `MULTIPLE_GOOD` boundaries to VE1-C/VE1-D/VE1-E.

## `topCandidateGapCp`

The candidate gap must not be published from the shallow first discovery search.

The implementation must calculate it, if at all, from the deepest retained candidate-discovery result, require exact scores for both leading candidates, and expose it to downstream code only when the overall convergence state is `stable`. Otherwise it is unconfirmed (`nil` or equivalent).

## Required regression

A negative regression must prove:

> If unrestricted candidate discovery changes Top-1 at a deeper tier, the result cannot be `stable` merely because the fixed pair comparison remains unchanged.

The synthetic regression uses the same failure shape as the observed 69-ply case: shallow/middle Top-1 `4f7c+`, deepest Top-1 `P*2e`, while the pair-comparison fingerprint itself remains constant. Expected state: `unstable`.

The observed 41/49/69 numeric engine outputs are not promoted to formal expected values by this amendment unless they separately satisfy `tools/engine-verify/VE1_NUMERIC_EVIDENCE_POLICY.md`.

## Authority boundary

This amendment changes search/evidence reliability only. It does not:

- create new 41/49/69 Semantic Authority;
- calibrate a near-tie cp threshold;
- recalibrate historical FV16 cp thresholds;
- change the VE1-C ownership of mate-sign semantics;
- start HDS-H or Build20.
