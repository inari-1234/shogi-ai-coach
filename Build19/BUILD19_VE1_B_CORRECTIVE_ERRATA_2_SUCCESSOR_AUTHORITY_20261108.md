# VE1-B Errata #2 — Corrective Successor Authority

Date: 2026-11-08
Status: **FORMAL AUTHORITY PROMOTION / ERRATA #2 CORRECTED**

## Frozen identities

- **Promoted, CI-validated code/fixture Authority:** `05ec68ba0b40bdd2980431d9d1931c08a4052b02`. This exact SHA, **not** any later handoff/recording commit, is the successor Authority.
- VE1-B frozen historical parent: `8daf78caa2bd5919cc911da21bae80fa3d12a248` — unchanged.
- VE1-A frozen Authority: `3252adb0fb5a066fc90362d978eec7f196f62135` — unchanged.
- Preregistered requirements: `BUILD19_VE1_B_ERRATA_LOW_LEGAL_MOVES_CORRECTIVE_20261015.md` §§2–9 — unchanged.
- 2026-11-08 owner decision: approve `05ec68b` as the Errata #2 corrective successor after verifying its evidence. This file is only an additive Authority record and does not alter the validated runtime SHA.

Implementation scope: unrestricted search uses `requiredMultiPV = min(configuredMultiPV, |YaneuraOu MoveList<LEGAL>|)`. `LEGAL_ALL` is not substituted. Zero-root fails closed. Restricted `searchmoves` behavior and other frozen search semantics are not changed.

## §6 acceptance proof

| §6 requirement | Evidence |
|---|---|
| 1: LEGAL 1/2/3 | Native fixture PASS `42331772717`, Simulator 50k PASS `42331772703` |
| 2: LEGAL=2 vs LEGAL_ALL=3 | Same fixture + Simulator PASSED with effective required 2 |
| 3: Engine vs Swift LEGAL count | B6 independent native-vs-Swift crosscheck `39950258266`, parity mismatches 0 |
| 4: Swift/Core unit tests | PASS in `42331772757` and associated candidate workflows |
| 5: Simulator E2E | `42331772763` PASS (`42331772731` is not a valid run ID) |
| 6: HDS Contract | `42331772695` PASS |
| 7: Device Build | `42331772740` PASS |
| 8: B6 physical-scope audit | Inherited `39950258266` PASS, exact rationale below |
| 9: Historical evidence unchanged | Compare `8daf78c...05ec68b`: Build19 files are additions only, no modified/deleted prior file |

All six direct CI runs listed above, excluding the inherited B6 run, have `head_sha=05ec68ba0b40bdd2980431d9d1931c08a4052b02` and `conclusion=success`.

Preserved Corrective Simulator artifact `13557584652`, digest `sha256:045aaae22369025f1ba86bfdf565b0fa75eeebc38da72d373eda2e122fd57e0f`.

### B6 evidence reuse decision

B6 audit ran on ancestor `c3352128029b21045f13f9aac0ac4b4962587d01`, run `39950258266`, and PASSED: 9 distinct roots; Standard 315 / Stress 189 / total 504 attempts; minimum native `MoveList<LEGAL>` count 31; affected attempts 0; native-vs-Swift mismatch 0.

Compare `c335212...05ec68b` contains exactly three modifications:

1. `.github/workflows/build19-ve1-b-low-legal-corrective-simulator.yml`
2. `iOS/ShogiCoachPoC/VE1BLowLegalCorrectiveFixtureProbe.swift`
3. `tools/engine-verify/fixtures/ve1b_low_legal_corrective.json`

None affects the B6 inputs, root-count algorithm, independent Swift reconstruction or B6 audit harness. Therefore B6 results remain applicable without remeasurement. Retained B6 audit artifact: `12499378992`, ZIP digest `sha256:bd2e3d267274c3b835cd86321097aa4dacae3ffc8a950b3728ac9aa9342052f3`.

## Explicit remaining constraints

- **Errata #1:** mixed MultiPV block/cohort, still OPEN at production level, Build20+ corrective. C1 coherent block is a separate downstream guard.
- **Errata #2:** CORRECTED by `05ec68b`; historical `8daf78c` remains VE1-B FORMAL PASS/Freeze with historical errata.
- **Natural pool:** rerun from first seeded game, preserving corpus, seeded game order, shortest-prefix stop, max-four-per-game and round-robin 16-position selection. Never substitute, reseed or skip exposed games in pool selection.
- **VE1-D contamination:** previously inspected seed rank 1 `38a01eb52ef27664f010b558114bd85f922eccdaeae8c281be461ea321cc65a0` and seed rank 2 `a3ea21dba4d3395d569d846b8cb119452fad0cedbf690eb72a29976918a8702a` are **permanently excluded from tuning, holdout and reserve** even if they yield zero candidates on rerun. This is a pre-exposure exception to the ordinary zero-candidate rule. The final exclusion Authority must ALSO include all candidate-producing processed-prefix games and permanent B6 `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`. Final manifest must be committed **before natural pilot**.
- **Unresolved C1 nonpromotion/searchmoves issue:** fail-closed `NOT_CLASSIFIABLE` vs comparison-only `LEGAL_ALL` route must be evidenced and decided **before C1 Freeze**, not a pool blocker.
- **VE1-C1:** PILOT-READY / NOT FROZEN. No natural pilot or VE1-D tuning yet.

A documentation commit containing this promotion is not itself the promoted corrective code Authority. No historical or preregistered document is rewritten.
