# Build19 VE1-B Errata — MultiPV completed-iteration block mixing

Status: **ERRATA / AUTHORITY UNCHANGED**  
VE1-B implementation Authority remains `8daf78caa2bd5919cc911da21bae80fa3d12a248`.

## Defect

`USICompletedIterationSelector` at the frozen VE1-B Authority chooses the latest exact row independently for each MultiPV rank at a selected depth. During a node-budget interruption, YaneuraOu can emit a new deeper rank-1 row and then re-emit not-yet-researched lower ranks with the previous depth label but the new terminal nodes/time. Combining rows by depth and per-rank latest nodes/time can therefore mix rows from different output cohorts.

The defect is cohort mixing, not duplicate-root detection. Duplicate roots are only one visible symptom.

## Correct completed MultiPV evidence rule for downstream C1

A usable MultiPV snapshot must be one coherent output block:

- ranks are exactly `1...N` in order;
- all ranks have the same depth;
- all ranks have the same nodes;
- all ranks have the same time;
- all ranks are exact;
- each rank has a non-empty PV;
- root moves are distinct as an integrity check.

If no such block exists, C1 treats Candidate Structure evidence as `INSUFFICIENT`.

This guard applies identically to App-side candidate discovery and Reference 4M/16M candidate discovery.

## Synthetic reproduction fixture

The committed fixture `tools/engine-verify/fixtures/ve1b_multipv_block_mixing.json` reproduces the observed startpos / MultiPV=3 / 100k interruption.

Expected coherent block:

- depth 12
- nodes 77806
- time 54 ms
- rank-1 `2g2f` cp 151
- rank-2 `7g7f` cp 138
- rank-3 `6i7h` cp 93

Frozen selector reproduction:

- rank-1 `2g2f` at nodes 77806
- rank-2 `2g2f` at nodes 100065
- rank-3 `6i7h` at nodes 100065

The fixture therefore proves both the mixing mechanism and candidate loss/duplication symptom.

## Existing evidence impact scan

Scanner: `tools/engine-verify/ve1b_errata_scan.py`

### Physical B6 PRIMARY campaign — Standard5 + Stress3

Scanned all eight retained primary search-evidence files.

- attempts: **504**
- observations: **25,198**
- frozen-selector vs coherent-block full snapshot mismatches: **112**
- all 112 mismatches: `candidate_discovery / MultiPV3`
- semantic payload changes: **0**
- ordered move changes: **0**
- move-set changes: **0**
- score kind/value changes: **0**
- rank-1 changes: **0**

Therefore the retained physical B6 PRIMARY Deep Evidence has cohort-metadata contamination in 112 candidate-discovery attempts, but the candidate moves, scores, PV payloads, and rank-1 used by those retained records are unchanged by coherent-block reconstruction.

Consequently, no change is detected in the semantic candidate payload of these eight PRIMARY Deep runs, and there is no basis from this scan to revoke the existing B6 PRIMARY_PASS.

Raw file SHA-256:

- Standard01 `b0e19571c18144e7166167d191047fb6f5f06249b841dc1aa6f0816198b85800`
- Standard02 `cb793624055a4c2c24a43e6d0b6fc5e36af65e8c63c004c4be317806b2351237`
- Standard03 `5878f2477db3d76288d325045dcdda02742420528b3b06afebb511925147790f`
- Standard04 `c1d095f1a2f05e8065a80bf896f33b4c619533310f79cbf87f9ebb07720c006f`
- Standard05 `29882916ddb5d8fd70a2c309a242d5740e55c3f457860a7a02a2f555fac9606a`
- Stress01 `ec67b60697e0bd6c37d30f4a5c34f5379adc1325b9ef20b7fa5172b375215d06`
- Stress02 `ec71781ebc8f5aa3ea9a580423914e090b6cc47b44d2a0d730c860a6fc96cb9f`
- Stress03 `52097d06d79c4e7e022cb17c7676781b120e07c8f0f558735de311be8fb1df29`

### VE1-B Node Contract CI at 8daf78c

Workflow run: `38290061937`  
Artifact: `11764713556`  
Artifact digest: `sha256:18f7999eb785160b30caf1ac27ac00f5aaad520d22a0c0d1d78f94c9f8ba598e`

Candidate-discovery runs scanned: **3** (50k / 100k / 200k)

- full snapshot mismatches: **3 / 3**
- semantic payload changes: **2 / 3**
- move-set changes: **2 / 3**
- ordered move changes: **2 / 3**
- score changes: **2 / 3**
- rank-1 changes: **0 / 3**

At 100k, frozen reconstruction incorrectly becomes:

`2g2f / 2g2f / 6i7h`

instead of the coherent block:

`2g2f / 7g7f / 6i7h`.

At 200k, frozen reconstruction incorrectly becomes:

`7g7f / 6i7h / 6i7h`

instead of:

`7g7f / 6i7h / 2g2f`.

CI result SHA-256: `45f47a9024d4c90edef31f648bd8eed742063480b7d5043c75adc8d385b686fa`  
CI raw transcript SHA-256: `5fa5a080d66d13f05237af41253f58b1e44daf958748b14804a706e3793b1d5b`

This establishes that the defect is capable of changing candidate-set evidence even though rank-1 remains intact in the observed cases.

## Scope assessment

### Observed unaffected

- frozen discovered rank-1 in all scanned B6 and Node Contract cases;
- independent MultiPV1 best/actual comparison searches;
- played-move loss derived from those independent comparisons;
- physical B6 PRIMARY retained Deep semantic candidate payloads.

### Potentially affected

- MultiPV rank-2/rank-3 candidate identity;
- candidate scores attached to those ranks;
- any candidate-set or fingerprint field built from a mixed snapshot;
- UI candidate-list completeness/duplication;
- any future Jaccard or candidate-set gate that consumes the mixed snapshot directly.

## Authority disposition

- Do **not** rewrite or amend commit `8daf78c`.
- Do **not** reinterpret the failed historical campaign.
- Keep B6 PRIMARY_PASS because the retained eight physical PRIMARY runs show zero semantic payload change under coherent reconstruction.
- Record this as `VE1B_ERRATA_MULTIPV_BLOCK_COHORT`.
- C1 and later validation code must use the coherent-block rule.
- A production selector repair belongs to a later VE1-B revision / Build20 program and must receive its own regression impact analysis before replacing the frozen selector.
