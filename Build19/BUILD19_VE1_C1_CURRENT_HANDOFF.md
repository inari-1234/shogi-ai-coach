# Build19 VE1-C1 — Current Handoff

Last updated: 2026-11-08
State: VE1_B_CORRECTIVE_SUCCESSOR_PROMOTED / VE1_C1_POOL_MANIFEST_EXCLUSION_FROZEN / NATURAL_PILOT_EXECUTING; NOT_FROZEN

## Validated implementation and fixed authorities

- Repository: `inari-1234/shogi-ai-coach`
- Candidate branch: `candidate/build19-ve1-c1-pilot`
- **Validated code/fixture commit:** `05ec68ba0b40bdd2980431d9d1931c08a4052b02`. The handoff update itself does not change runtime code or fixture inputs.
- VE1-A frozen Authority: `3252adb0fb5a066fc90362d978eec7f196f62135`.
- VE1-B historical frozen Authority: `8daf78caa2bd5919cc911da21bae80fa3d12a248` — **must not overwrite or retroactively alter**.
- **VE1-B Corrective Errata #2 successor Authority: `05ec68ba0b40bdd2980431d9d1931c08a4052b02`**, formally promoted 2026-11-08. Promotion record: `BUILD19_VE1_B_CORRECTIVE_ERRATA_2_SUCCESSOR_AUTHORITY_20261108.md`. Current branch HEAD and documentation commits are not its runtime Authority identity.
- Corrective preregistration: `BUILD19_VE1_B_ERRATA_LOW_LEGAL_MOVES_CORRECTIVE_20261015.md`.
- VE1-C1 pilot/pre-pool contracts: `BUILD19_VE1_C1_PRE_PILOT_CONTRACT_20261013.md`, `BUILD19_VE1_C1_PRE_POOL_CONTRACT_20261014.md`.
- The October 10 handoff is historical as to stage/restart point; use this fixed-name handoff for the current continuation, without treating it as replacement of frozen authorities.

## VE1-B Corrective #2 — evidence at the validated commit

Product change: for **unrestricted** searches, `effectiveRequiredMultiPV = min(configuredMultiPV, |YaneuraOu MoveList<LEGAL>|)`. No substitution of `LEGAL_ALL`; zero-root cases remain fail-closed. Restricted `searchmoves` policy is unchanged and is a separate open C1 item.

Evidence-bound final candidate `05ec68b...`:

| Gate | GitHub Actions run | Result |
|---|---|---|
| Native corrective root fixtures, LEGAL=1/2/3 and LEGAL=2 vs LEGAL_ALL=3 | `42331772717` | PASS |
| Production x86_64 Simulator, all four `go nodes 50000` / 10,000ms corrective fixtures | `42331772703` | PASS |
| Node Contract | `42331772757` | PASS |
| HDS Contract Evidence | `42331772695` | PASS |
| iOS Simulator E2E | `42331772763` | PASS |
| iOS Device Build | `42331772740` | PASS |

Corrective Simulator evidence artifact: `Build19-VE1-B-low-legal-corrective-simulator`, artifact ID `13557584652`, ZIP digest `sha256:045aaae22369025f1ba86bfdf565b0fa75eeebc38da72d373eda2e122fd57e0f`. Raw USI and per-fixture counts/completion/ranks/terminal bestmove are retained there.

Earlier native B6 scope audit `39950258266` PASS at `c3352128029b21045f13f9aac0ac4b4962587d01`: 9 distinct roots, Standard 315 + Stress 189 = 504 attempts; minimum native LEGAL root count 31; affected 0; Swift crosscheck mismatches 0. The later validated candidate changed only the corrective fixture geometry after the implementation changes; no B6 audit dependencies were changed by that fixture edit. Audit artifact `Build19-VE1-B-B6-legal-root-audit` ID `12499378992`, ZIP digest `sha256:bd2e3d267274c3b835cd86321097aa4dacae3ffc8a950b3728ac9aa9342052f3`.

The initially selected one-LEGAL position ended in `proven_mate_termination` at 128 nodes and was **not accepted** as a 50k fixture. A defensive-rook variant still ended in mate at 128 nodes. The validated one-LEGAL fixture instead uses `position sfen k7r/9/9/9/9/9/9/7P1/8K b - 1`. This is an incident-derived fixture correction, not a relaxation of the preregistered completion/budget/rank acceptance.

**Disposition:** Corrective implementation and listed gates PASS; designated owner **FORMALLY PROMOTED** exact validated `05ec68ba0b40bdd2980431d9d1931c08a4052b02` as Errata #2 successor Authority on 2026-11-08. Historical parent `8daf78c...` is unchanged. All §6 requirements and inherited B6 applicability are recorded in `BUILD19_VE1_B_CORRECTIVE_ERRATA_2_SUCCESSOR_AUTHORITY_20261108.md`.

## Remaining boundaries / non-change rules

- VE1-B Errata #1 (mixed MultiPV output iteration/cohort) remains unresolved at production selector level; downstream C1 coherent-block guard is separate. A production-level repair is deferred to Build20+.
- C1 omitted non-promotion `searchmoves`: resolve as preregistered `NOT_CLASSIFIABLE` fail-closed or an independently specified comparison-only `LEGAL_ALL` path, with pinned regression, **before C1 Freeze**. This does not block a pool rerun after Corrective Authority promotion.
- Natural production pool **PASS / FROZEN** at bot commit `4eb3bce7264f3f56f05b93c03a8bebc7f990d4eb`, workflow `42393557082`. Five seeded games processed, all five candidate-producing, capped total 18. Frozen 16-position manifest SHA `c24347c6e491b3fe27874ac8088e63852a42fbb0a58ab76b36ccf96a6c3b4d12`; pool SHA `e2cf57fcb99b33c64667c9e04a10129625434eb726dc691a89019945415ae5a4`; VE1-D exclusion Authority SHA `88835b58241d1942946bce7b7a963d3c4b346a4d1945e419ae7f5733b64bb2f0`. Six games excluded (five contributing games plus B6); no zero-candidate game. These three files must remain immutable.
- Pilot admission `42412350136` PASS: `natural_pilot_execution_permitted:false` in frozen exclusion is the pre-commit snapshot; separately derived `computed_natural_pilot_execution_permitted:true` is admitted only when freeze commit ancestor, identities/digests/selection/exclusion binding pass. Do not hand-toggle the frozen field.
- Frozen `deepMovetimeMs:800` is a boolean legacy production selection mode switch (`>=800`), **not** an elapsed-time engine budget; real deep searches use fixed nodes. Do not rerun or alter the frozen pool solely because of the 800 metadata.
- **C1 Freeze integration pending — protected upstream coupling (handoff reminder, NOT Authority):** Draft v3 §25 referred to this coupling; the frozen C1 pre-pilot contract does not contain §25. `DeepAnalysisViewModel.analyze(deepMovetimeMs: 800)` determines `productionSelectionMode = deepMovetimeMs >= 800`, thereby changing `provisionalLimit` and the upstream candidate-position selection even though engine searches use fixed node budgets. **At C1 Freeze integration, put the protected-parameter rule and mandatory change-impact analysis into the single formally approved C1 Freeze Authority document**, covering changes to the call-site value, threshold, predicate, pool selection, frozen 16-position manifest and regression scope before Build20. After that Authority is committed, **replace this handoff explanation with a link to its exact document and clause**; do not maintain a competing normative copy here. Until then retain the value and logic unchanged, with no silent retuning or resampling.
- Pinned native LEGAL root preflight `42412684383` PASS over 16 natural positions: effective MultiPV 3 for 15 positions, 2 for the known seed2 ply126 position. App and Reference pilot harnesses now use these native counts rather than fixed 3.
- Natural 16-position pilot workflow `42413155051` **RUNNING / NOT YET ACCEPTED**. Its integrity gate requires raw search evidence, frozen Swift parser parity zero mismatch, coherent output blocks, and preregistered F/E derivation. No pilot PASS/Freeze has been declared.
- Do not alter the committed corpus, seeded game order, `VE1-C1-SAMPLING-v1` key, at-most-four-per-game, shortest-prefix stop rule, or round-robin 16-position derivation. No ad hoc substitutions.
- Seed-ranked games 1 (`38a01eb52ef27664f010b558114bd85f922eccdaeae8c281be461ea321cc65a0`) and 2 (`a3ea21dba4d3395d569d846b8cb119452fad0cedbf690eb72a29976918a8702a`) were previously exposed: **permanently exclude both from all VE1-D tuning/holdout/reserve partitions, even if candidate-zero in the new pool**. Production pool selection must still process them in frozen seed order.
- Once the production pool and 16-position manifest are derived, commit VE1-D exclusion Authority for **every processed-prefix game producing >=1 candidate plus the permanent B6 fixture**, before any natural pilot invocation. Zero-candidate processed games do not enter the exclusion.
- No VE1-D tuning, holdout or reserve inspection before the preregistered C1 pilot and exclusion boundary.

## Next bounded action

1. Review natural pilot CI run `42413155051` at initiating code commit `637213c21697401882dc930a6aa63f135df441b5`; collect stage, raw USI, Swift parity, coherence evidence, F/E evaluation and execution-integrity result.
2. On a specific FAIL, inspect the preserved stage/logs and fix only the established owning fault domain. Do not loosen frozen 4M/16M budgets, scoring semantics, manifest or admission conditions; no blind reruns.
3. Only if `PILOT_PASS` is independently evidenced, record the derived F/E and feasibility indicators, settle the separate omitted-nonpromotion `searchmoves` policy with pinned regression before C1 Freeze, then perform remaining synthetic/final regression.
   At the C1 Freeze-document integration gate, promote the protected `deepMovetimeMs >= 800` upstream-coupling rule from this non-authoritative reminder into the formal C1 Freeze Authority, verify the new clause, then replace the reminder with the exact Authority document/section reference. Do not treat a handoff update as Authority promotion.
4. Errata #1 remains a separate production-level Build20+ repair. C1 Freeze and VE1-D are **not yet authorized**.

## Loop-minimization note

The 50k fixture incident was localized from the already-preserved Simulator `report.json`, raw USI and `failureReasons`. No additional generic Gate, Authority JSON, or workflow router was introduced. Future workflow changes should target observed failures at their actual owner, retain evidence identity and avoid reruns of independent unaffected evidence; any formal Freeze-specific full-regression requirement remains in force.
