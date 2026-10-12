# Build19 — Current Handoff Authority

Date: 2026-10-13 (JST)
Status: **Build19-VE1-B FORMAL PASS / FREEZE**

## Current authority

The current frozen implementation authority is:

`8daf78caa2bd5919cc911da21bae80fa3d12a248`

Formal freeze record:

`Build19/BUILD19_VE1_B_FREEZE_20261013.md`

The documentation commits on `docs/build19-ve1-b-freeze-20261013` are documentary only. They do not replace or mutate the frozen implementation authority above.

## Physical B6 authority

Fixed-node physical B6 completed on `iPhone17,1` / `iOS 26.7.1` with the frozen candidate.

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

The following verification evidence is tied to the same implementation commit `8daf78caa2bd5919cc911da21bae80fa3d12a248`:

- Build19 HDS Contract Evidence — run `38185781889` — PASS
- B6 fixed-node / incomplete-state proof — run `38185781897` — PASS
- iOS Device Build — run `38185781911` — PASS
- B6 Device Candidate — run `38185781921` — PASS
- normal iOS Simulator E2E — run `38185781966` — PASS
- Build19 VE1-B Node Contract — run `38290061937` — PASS
- Build19 VE1-B Simulator E2E — run `38290062004` — PASS

The dedicated VE1-B workflows were triggered by a non-forced fast-forward of `candidate/build19-ve1-b-implementation` from `204bdceddc0c1327f28cf4a382b22d82017a2069` to the already measured `8daf78caa2bd5919cc911da21bae80fa3d12a248`. This introduced no new candidate commit and did not alter the physical authority.

At handoff, both of these candidate refs are intended to identify the same frozen implementation commit:

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

## Next authorized phase

**Proceed to Build19-VE1-C.**

VE1-C owns the deferred mate-sign semantics and subsequent calibration work. In particular, positive/negative mate interpretation remains outside the VE1-B freeze except for the already frozen strict `proven_mate_termination` completion classification.

A VE1-C change must not silently modify the frozen VE1-B search/evidence contract. If VE1-C requires a change to search policy, TT policy, completion classification, Shallow/Deep selection semantics, or physical runtime behavior, treat it as a new candidate requiring the affected VE1-B evidence gates again; physical-runtime changes require new physical authority rather than reuse of the completed B6 campaign.
