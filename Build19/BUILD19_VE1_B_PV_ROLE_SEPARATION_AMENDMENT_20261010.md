# Build19-VE1-B — Confirmed PV / Reference PV Role Separation Amendment

Date: 2026-10-10
Status: **NORMATIVE VE1-B AMENDMENT / IMPLEMENTATION MUST PASS FINAL GATES**

## 1. Purpose

VE1-B distinguishes a PV that is qualified for semantic use from a PV that is merely useful as an observation. This amendment resolves the generic Simulator E2E failure exposed after the completed-iteration/bound contract was corrected. It does **not** weaken B3, B5, B6 or B7 and does not add an engine search.

## 2. Two PV roles

### 2.1 `confirmedPV`

`confirmedBestPV` / `confirmedActualPV` are the only PVs authorized for explanation, branch comparison, continuation simulation, HDS evidence and causal coaching claims. They are the stability-confirmed common prefix produced by the VE1-B classifier.

For `unstable`, `unconfirmed` or otherwise non-qualified continuation evidence, an empty confirmed PV is a **valid safe result**. Empty confirmed PV must not be repaired by copying a deeper unconfirmed observation.

### 2.2 `referencePV`

`referenceBestPV` / `referenceActualPV` are observation-only. They are derived from already-saved direct-measurement Evidence and therefore require no additional engine search.

A reference PV may be selected only from an attempt that:

- has the matching direct target (`recommended_move` or `actual_move`);
- completed with `node_budget_reached`;
- selected an `exact` completed iteration;
- contains a non-empty selected PV.

Among qualifying attempts, use the deepest node tier; depth is only a tie-breaker. If no qualifying attempt exists, the reference PV is empty. A terminal lowerbound/upperbound is never promoted into reference PV.

## 3. Mandatory semantic boundary

The following consumers may read **confirmed PV only**:

- Reason analysis;
- HDS G4/G5 or equivalent explanation-fidelity logic;
- continuation / development simulation;
- counterfactual or causal explanation;
- any recommendation wording that implies a verified continuation.

`referencePV` must never be used to fill an empty confirmed PV, establish a difference mechanism, generate a continuation route, or upgrade confidence/stability.

The context/explanation layer must use explicit `confirmed*` accessors where it consumes deep PV evidence so that future refactors cannot accidentally switch to reference observations.

## 4. UI rule

When a non-qualified reference PV is shown to a user, it must be labeled **未確認** and identified as display-only. The UI must state that it is not used as the basis for the reason, recommendation or continuation simulation.

Stable/qualified coaching continues to use confirmed PV. The reference display exists only to avoid discarding useful observational information while preserving the semantic safety boundary.

## 5. Generic production-path E2E contract

For a normally completed non-stable sample where direct exact measurements exist:

- `referenceBestPV` and `referenceActualPV` must be non-empty;
- `confirmedBestPV` and `confirmedActualPV` must remain empty;
- Reason output must contain only the empty confirmed PV, not the reference PV;
- Continuation routes must remain empty;
- presentation must remain `provisional` / `比較保留` / `暫定候補`;
- policy audit must accept this as a valid non-stable state.

For stable samples, confirmed PV must be present and downstream consumers may use that confirmed evidence.

The production-path E2E must include the non-stable case as a **negative leakage test**. A test that merely checks reference PV existence is insufficient.

## 6. Historical correction: bound / PvInterval

The previous handoff wording that described the 49-ply issue as a bound line being accepted as the final score is not current authority. B3 correctly rejected the deeper bound; the failure mode was that no qualifying exact completed iteration remained available under the then-observed output.

The completed-iteration authority in `BUILD19_VE1_B_PV_INTERVAL_COMPLETED_ITERATION_AMENDMENT_20261010.md` already requires `PvInterval=0` and selection of the deepest fully completed exact iteration. Commit `046ba47` implemented that correction and the dedicated VE1-B contract path passed. Do not reopen the old `PvInterval=300` diagnosis as the current generic-E2E blocker without new evidence.

## 7. TT correction

All nine searches in the corrected VE1-B per-position path are cold:

- 3 unrestricted candidate-discovery tiers;
- 3 independent recommended-move tiers;
- 3 independent actual-move tiers.

Each invocation receives its own cold TT boundary. No N -> 2N -> 4N series is authorized to inherit a warm TT. Any older base-document wording that says otherwise is superseded by the later amendments and this clarification.

## 8. Scope and completion boundary

This amendment changes evidence role semantics and downstream handling only. It does not change:

- the nine-search engine schedule;
- node budgets;
- B6 physical-device thresholds;
- candidate discovery rules;
- B3 exact/bound qualification;
- VE1-C calibration ownership.

VE1-B remains **NOT FORMAL PASS** until the final candidate commit passes the required Core/Simulator/device gates and the frozen physical-iPhone B6 acceptance contract. A generic Simulator PASS after this amendment authorizes moving to physical B6; it does not itself complete VE1-B.
