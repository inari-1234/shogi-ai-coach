# Build19 — Current Handoff Authority

Date: 2026-10-13 (JST)
Status: **Build19-VE1-B FORMAL PASS / FREEZE**

## Current implementation authorities

### Build19-VE1-A — App Engine Configuration / Runtime Authority

VE1-A is the engine-configuration/runtime qualification stage. Its authority is:

`3252adb0fb5a066fc90362d978eec7f196f62135`

VE1-A covers:

- production/runtime `FV_SCALE=24` authority;
- bundled Suisho5 NNUE identity verification;
- deterministic known-answer runtime checks;
  - start position, `Threads=1`, `MultiPV=1`, `FV_SCALE=24`, `go depth 1`: expected `cp 108`, bestmove `7g7f`;
  - corrected SFEN calibration, `FV_SCALE=24`, `go depth 1`: expected `cp 157`, bestmove `2b7g+`;
- physical-iPhone runtime verification;
- audit of Build17/18 and current runtime cp/score/threshold dependencies affected by the scale authority;
- negative controls for missing/wrong FV scale and wrong NNUE identity where applicable.

The root-move identity corrections, `confirmedPV` / `referencePV` separation, G3 wording corrections, promotion-notation corrections, continuation guards and related presentation/evidence repairs are **not VE1-A scope**. They belong to the later VE1-B corrective work and must not be used to redefine the VE1-A freeze boundary.

### Build19-VE1-B — Search / Evidence / Runtime Policy Authority

The current frozen VE1-B implementation authority is:

`8daf78caa2bd5919cc911da21bae80fa3d12a248`

Formal freeze record:

`Build19/BUILD19_VE1_B_FREEZE_20261013.md`

The documentation commits on `docs/build19-ve1-b-freeze-20261013` are documentary only. They do not replace or mutate either frozen implementation authority above.

## Physical B6 authority

Fixed-node physical B6 completed on `iPhone17,1` / `iOS 26.7.1` with the frozen VE1-B candidate.

- fixture: `CPU対局 81手.kif`
- fixture SHA-256: `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`
- aggregate report SHA-256: `fe63385d97293ae8cb7a577618ae66d7592d57b2960dcc899bcf93b51ff4a2a9`
- physical decision: **PRIMARY_PASS**
- Standard: 5/5 complete
- Stress: 3/3 consecutive complete
- Shallow Top-3: `[79, 81, 49]` in all five Standard runs
- minimum pairwise Top-3 Jaccard: `1.00`
- modal Top-1: ply `79`, `5/5`
- full ordered Deep selection identical in all Standard runs
- Standard incomplete: `0 / 315`
- Stress incomplete: `0 / 189`
- Standard serious/critical thermal observations: `0 / 0`
- Stress critical thermal observations: `0`

No Deep fallback was activated or required.

## Exact-candidate cloud authority

The following verification evidence is tied to the same VE1-B implementation commit `8daf78caa2bd5919cc911da21bae80fa3d12a248`:

- Build19 HDS Contract Evidence — run `38185781889` — PASS
- B6 fixed-node / incomplete-state proof — run `38185781897` — PASS
- iOS Device Build — run `38185781911` — PASS
- B6 Device Candidate — run `38185781921` — PASS
- normal iOS Simulator E2E — run `38185781966` — PASS
- Build19 VE1-B Node Contract — run `38290061937` — PASS
- Build19 VE1-B Simulator E2E — run `38290062004` — PASS

The dedicated VE1-B workflows were triggered by a non-forced fast-forward of `candidate/build19-ve1-b-implementation` from `204bdceddc0c1327f28cf4a382b22d82017a2069` to the already measured `8daf78caa2bd5919cc911da21bae80fa3d12a248`. This introduced no new candidate commit and did not alter the physical authority.

At handoff, both of these candidate refs identify the same frozen VE1-B implementation commit:

- `candidate/build19-ve1-b6-shallow-fixed-node`
- `candidate/build19-ve1-b-implementation`

## Frozen VE1-B semantics

Preserve the following without reinterpretation:

- `confirmedPV` is stability-confirmed only.
- `referencePV` may carry usable evidence that is not confirmed.
- a non-stable position cannot receive `confirmedPV`.
- a non-stable position may receive `referencePV`.
- never promote `referencePV` to `confirmedPV` merely to make an explanation available.
- explainability and confirmed analysis remain separate concepts.
- Shallow B6 triage is fixed-node under the accepted policy; do not restore the former 150 ms movetime policy.
- Deep primary policy remains the accepted 50k -> 100k -> 200k discovery/confirmation structure; the B6 fallback was not used.
- historical HDS-M expected positions, including 41 / 49 / 69, must not be modified without separately approved evidence.

## Correct downstream phase order

The authorized sequence after VE1-B is:

`VE1-C1 -> VE1-D -> Reference Analysis -> VE1-C2 -> VE1-E -> VE1-V -> VR1B -> HDS-H -> Build19 Freeze -> Build20`

This order is a methodological guard. Do not collapse VE1-C1 and VE1-C2, do not consume the holdout during tuning, and do not create numerical thresholds after looking at the untouched validation results.

### VE1-C1 — Pre-data decision-method freeze

VE1-C1 freezes the **decision axes, labels, evidence requirements and metrics before calibration data are inspected**. It is not the numeric-threshold stage.

At minimum, the method must distinguish three separate questions:

1. candidate structure — unique good move / multiple good moves / unknown;
2. certainty — confirmed / unconfirmed / insufficient evidence;
3. played-move assessment — match / within the good set / somewhat worse / blunder.

VE1-C1 must decide the metric used to define boundaries (for example, a win-probability-difference representation or another predeclared transformation) and its directionality/handling rules **before** the corpus is used for threshold selection. Numerical cut points are reserved for VE1-C2.

Mate-sign semantics is included here as a bounded correctness repair: positive mate may support a missed-winning-mate claim only under the declared perspective semantics; `mate -N` must not be counted as a missed winning mate. This is an important regression guard, but it is not the main purpose of VE1-C1.

### VE1-D — Corpus construction

Create a representative corpus of at least roughly `80-100+` positions, with an untouched holdout of at least `30` positions.

The holdout is reserved for VE1-E and must not be used to choose labels, metrics, transformations, thresholds, tie handling or special cases.

### Reference Analysis

Produce the reference classification/evidence for the corpus under the frozen C1 method.

Reference disagreement or irreconcilable ambiguity is recorded as **DISPUTED** and kept separate. DISPUTED cases must be reported, but they are not silently forced into PASS/FAIL authority or used as ordinary denominator cases for threshold calibration/validation.

### VE1-C2 — Calibration on tuning data only

Choose the numerical thresholds only from the designated tuning/calibration portion of the corpus using the already frozen C1 axes and metrics.

Do not inspect or optimize against the untouched holdout while selecting thresholds.

### VE1-E — Untouched holdout validation

Run the production app against the untouched holdout.

Hard gate:

- when the reference classification is **MULTIPLE_GOOD**, cases where the app emits **UNIQUE_RECOMMENDATION** must be `0`.

Also report false positives, false negatives and coverage, while keeping DISPUTED reference cases separate from authoritative pass/fail denominators.

### VE1-V — Independent validation

Perform an independent validation pass after VE1-E. This is a separate authority gate, not an alias for VE1-E.

### VR1B

Run the planned review/rubric extension. In the HDS/quality terminology used for this program:

- **G6 = UNCERTAINTY**;
- **G9 = FIDELITY**, added/planned at VR1B.

Do not relabel G6 as FAITHFULNESS/FIDELITY in handoff material.

### HDS-H -> Build19 Freeze -> Build20

HDS-H remains a required gate after VR1B. Only after HDS-H passes may Build19 receive its overall Freeze, after which Build20 may start.

## Post-freeze mutation rule

A VE1-C or later change must not silently modify the frozen VE1-B search/evidence contract. If later work requires a change to search policy, TT policy, completion classification, Shallow/Deep selection semantics or physical runtime behavior, treat it as a new candidate and rerun the affected VE1-B evidence gates. Physical-runtime changes require new physical authority rather than reuse of the completed B6 campaign.
