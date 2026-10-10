# Build19-VE1-B — Independent Single-Move Comparison Amendment

Date: 2026-10-10
Status: **CURRENT VE1-B CONTRACT AMENDMENT / VE1-B NOT FORMAL PASS**

This amendment supersedes any conflicting wording in `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`, `BUILD19_VE1_B_CANDIDATE_DISCOVERY_CONVERGENCE_AMENDMENT_20261010.md`, and older handoff material concerning a MultiPV2 fixed-pair comparison or staged TT reuse inside the direct-comparison series.

## 1. Defect being corrected

The previous corrected B5 model re-ran unrestricted candidate discovery at every tier, but then measured the deepest recommended move and the actual move together with `searchmoves recommended actual`, MultiPV 2.

With this engine configuration, the weaker line can remain `upperbound`/`lowerbound` at the target even when the position is semantically clear. Under B3, such a bound cannot be promoted to an exact value. Therefore a clear position can remain permanently unconfirmed for reasons caused by the measurement method itself.

This is a measurement-contract defect, not a reason to weaken B3.

## 2. Required comparison method

For every confirmation node tier `N`:

1. clear TT to a verified cold boundary;
2. run `searchmoves <recommendedMove>`, MultiPV 1, `go nodes N`;
3. preserve the full raw evidence and the engine-selected final scored line;
4. clear TT again to a new verified cold boundary;
5. run `searchmoves <actualMove>`, MultiPV 1, `go nodes N`;
6. preserve the full raw evidence and the engine-selected final scored line;
7. only after both searches complete normally, form the tier comparison evidence.

`N` therefore means **N nodes per move**, not N total nodes shared by two MultiPV candidates.

No TT state may be inherited:
- from candidate discovery into either compared move;
- from the recommended-move search into the actual-move search;
- from one comparison node tier into the next comparison node tier.

Candidate discovery remains unrestricted MultiPV and remains cold independently at every discovery tier.

## 3. Bound handling remains conservative

B3 is unchanged:

- `exact`, `lowerbound`, and `upperbound` remain distinct evidence states;
- a bounded target result is not an exact score;
- a shallower exact score may not masquerade as a deeper exact score;
- a bounded comparison input does not qualify as an exact stable tier.

Directional use of a bound (for example, proving a minimum loss from one exact score and one upperbound) may be calibrated later, but VE1-B does not silently reinterpret a bound as an exact loss.

## 4. Candidate Top-1 change is not `MULTIPLE_GOOD`

`candidate_top1_changed` is retained as an independent reliability reason code.

A Top-1 change:
- is evidence that candidate identity changed under deeper unrestricted search;
- is not, by itself, proof that the position is semantically unstable;
- is not equivalent to `MULTIPLE_GOOD`;
- must remain distinguishable so VE1-C can decide whether the changed candidates form a near-tie/multiple-good set.

Every candidate-discovery tier must therefore retain the complete MultiPV candidate evidence, including move identity, score kind/value, bound kind, depth, nodes, PV, and raw USI provenance.

## 5. Stability classification must be evidence-only reproducible

The current VE1-B `loss_changed` threshold of 120cp is **not calibrated semantic authority**. It is retained only as an explicit `UNFROZEN_VE1C_CALIBRATION` rule so the present label can be reproduced.

The evidence document must contain enough information to recompute the stability label without rerunning the engine, including at least:

- the explicit stability-rule parameters used for the stored label;
- candidate Top-1 identity and bound state for every discovery tier;
- independently measured recommended-move score kind/value/bound/PV for every confirmation tier;
- independently measured actual-move score kind/value/bound/PV for every confirmation tier;
- node budget and TT generation for every search invocation;
- derived loss/inversion inputs used by the current classifier;
- the complete underlying raw search attempts/observations.

PASS requires a regression that serializes the evidence, decodes it, recomputes the label using only decoded evidence plus decoded rules, and obtains the same state/reason set.

VE1-C may later change the rules and reclassify the stored evidence without rerunning the engine.

## 6. Search-count and B6 consequence

With three candidate-discovery tiers and three comparison tiers, one analyzed position now requires:

- 3 unrestricted candidate-discovery searches; plus
- 3 recommended-move single searches; plus
- 3 actual-move single searches;
- total: **9 engine searches per position**.

Therefore prior physical-iPhone timing measurements for the six-search schedule cannot establish the production B6 budget for this corrected method.

**Do not perform or accept B6 physical-iPhone production-policy measurement until this amended search contract passes automated/Core/Simulator/device-build gates.**

After those gates pass, B6 must measure the corrected nine-search-per-position path and then select/freeze the production node schedule and safety ceiling from that evidence.

## 7. Required regression/E2E gates

At minimum:

- a Top-1-changing deeper discovery fixture cannot become stable merely because pair-comparison evidence otherwise agrees;
- the direct-comparison evidence contains six independent single-move attempts for three node tiers;
- every comparison attempt has MultiPV 1 and exactly one `searchmoves` move;
- each of those six attempts has a distinct cold TT generation;
- node budgets occur as `N,N,2N,2N,4N,4N` for recommended/actual measurements;
- stored Evidence JSON contains the three reclassification input tiers and the explicit rule set;
- Evidence JSON -> decode -> classifier reproduces the stored label/reasons;
- unstable/unconfirmed analysis remains a normally completed analysis state and does not expose unqualified cp loss or candidate-gap values.

Until these gates and the later corrected-method physical-device B6 evidence pass, VE1-B remains **IN PROGRESS / NOT FORMAL PASS**.
