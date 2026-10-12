# Build19-VE1-B — Formal PASS / Freeze

Date: 2026-10-13 (JST)
Status: **FORMAL PASS / FREEZE**

## Frozen implementation authority

- Candidate commit: `8daf78caa2bd5919cc911da21bae80fa3d12a248`
- App: `0.8.3` / build `16`
- Minimum measured device: `iPhone17,1`
- Measured OS: `iOS 26.7.1`
- YaneuraOu pin: `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`
- Suisho5 NNUE SHA-256: `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`
- Threads: `1`
- Hash: `64 MB`
- `BookFile=no_book`
- `FV_SCALE=24`
- `PvInterval=0`

This document records the acceptance result only. The frozen implementation commit above is not modified by this documentation branch.

## B6 physical authority

Fixture:

- file: `CPU対局 81手.kif`
- move count: `81`
- SHA-256: `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`

Fixed-node Shallow policy:

- every Shallow position: `50,000` nodes
- MultiPV: `1`
- safety ceiling: `15,000 ms`
- cold logical search before each Shallow position
- measurement: deepest fully completed exact iteration

Physical aggregate report SHA-256:

`fe63385d97293ae8cb7a577618ae66d7592d57b2960dcc899bcf93b51ff4a2a9`

Formal physical result: **PRIMARY_PASS**.

### Standard 5 runs

- Top-3: `[79, 81, 49]` in all 5 runs
- minimum pairwise Top-3 Jaccard: `1.00`
- modal Top-1: ply `79`, `5/5`
- full ordered Deep selection: `[79, 81, 49, 53, 77, 69, 61]` in all 5 runs
- Shallow semantic equality: PASS
- Deep attempts: `315`
  - `node_budget_reached`: `220`
  - `proven_mate_termination`: `95`
  - incomplete: `0`
- Deep-position median: `2743 ms`
- Deep-position nearest-rank P95: `2988 ms`
- whole-game median: `46692 ms`
- whole-game nearest-rank P95: `48675 ms`
- serious thermal observations: `0`
- critical thermal observations: `0`

### Stress 3 consecutive runs

- executed consecutively after Standard, no cooldown campaign break
- Top-3 remained `[79, 81, 49]`
- Deep attempts: `189`
  - `node_budget_reached`: `132`
  - `proven_mate_termination`: `57`
  - incomplete: `0`
- incomplete rate: `0`
- critical thermal observations: `0`
- safe incomplete handling gate: PASS
- Stress gate: PASS

### Raw Evidence integrity

All eight raw Evidence files matched the aggregate report SHA references. Independent cross-check of all `504` Deep attempts found zero report/raw summary mismatches.

Raw Evidence SHA-256:

- Standard 01: `b0e19571c18144e7166167d191047fb6f5f06249b841dc1aa6f0816198b85800`
- Standard 02: `cb793624055a4c2c24a43e6d0b6fc5e36af65e8c63c004c4be317806b2351237`
- Standard 03: `5878f2477db3d76288d325045dcdda02742420528b3b06afebb511925147790f`
- Standard 04: `c1d095f1a2f05e8065a80bf896f33b4c619533310f79cbf87f9ebb07720c006f`
- Standard 05: `29882916ddb5d8fd70a2c309a242d5740e55c3f457860a7a02a2f555fac9606a`
- Stress 01: `ec67b60697e0bd6c37d30f4a5c34f5379adc1325b9ef20b7fa5172b375215d06`
- Stress 02: `ec71781ebc8f5aa3ea9a580423914e090b6cc47b44d2a0d730c860a6fc96cb9f`
- Stress 03: `52097d06d79c4e7e022cb17c7676781b120e07c8f0f558735de311be8fb1df29`

## Exact-candidate cloud evidence

All required final verification below uses the same frozen candidate commit `8daf78caa2bd5919cc911da21bae80fa3d12a248`.

- Build19 HDS Contract Evidence — run `38185781889`: PASS
- B6 incomplete/fixed-node proof — run `38185781897`: PASS
- iOS Device Build — run `38185781911`: PASS
- B6 Device Candidate — run `38185781921`: PASS
- normal iOS Simulator E2E — run `38185781966`: PASS
- Build19 VE1-B Node Contract — run `38290061937`: PASS
  - artifact ID: `11764713556`
  - artifact digest: `sha256:18f7999eb785160b30caf1ac27ac00f5aaad520d22a0c0d1d78f94c9f8ba598e`
- Build19 VE1-B Simulator E2E — run `38290062004`: PASS
  - artifact ID: `11766526098`
  - artifact digest: `sha256:26ed7e9b9e36d778dc4402f2a2191e375266f5eed53865668f1a591f7e6003c8`

The implementation branch was fast-forwarded to the already measured candidate solely to trigger the dedicated VE1-B workflows at the identical commit. No candidate content changed.

## Acceptance decision

The VE1-B evidence contract is satisfied on one final implementation commit:

- B1 opening-book disable contract: accepted
- B2 scored-info accumulator contract: accepted
- B3 bound/exact semantics: accepted
- B4 lossless raw Evidence contract: accepted
- B5 increasing-budget convergence/candidate-identity contract: accepted
- B6 node/TT/safety/device/incomplete-state contract: accepted
- B7 per-ply confirmed-PV contract: accepted
- VE1-A known-answer regression: retained
- HDS-M guard: retained

**Build19-VE1-B is FORMAL PASS / FREEZE at `8daf78caa2bd5919cc911da21bae80fa3d12a248`.**

B8 mate-sign semantics remains explicitly deferred to VE1-C under the pre-existing acceptance contract. This freeze does not promote `referencePV` to `confirmedPV` and does not alter the frozen confirmed/reference-PV semantics.

## Mutation rule after freeze

Do not amend the frozen candidate commit or reinterpret its physical campaign. Any future implementation change must use a new candidate SHA and must rerun the evidence gates affected by that change. A change to search/runtime policy, Shallow/Deep selection semantics, completion classification, TT behavior, or physical-runtime behavior requires a new physical authority campaign rather than reusing this B6 result.
