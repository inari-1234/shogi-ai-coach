# Build19 VE1-C1 — Current Handoff

Last updated: 2026-11-08
State: VE1_B_CORRECTIVE_SUCCESSOR_PROMOTED / VE1_C1_POOL_RERUN_PREPARATION; VE1_C1_PILOT_READY / NOT_FROZEN

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
- Natural production pool **not yet rerun successfully**; no frozen 16-position manifest; natural pilot **not run**.
- Do not alter the committed corpus, seeded game order, `VE1-C1-SAMPLING-v1` key, at-most-four-per-game, shortest-prefix stop rule, or round-robin 16-position derivation. No ad hoc substitutions.
- Seed-ranked games 1 (`38a01eb52ef27664f010b558114bd85f922eccdaeae8c281be461ea321cc65a0`) and 2 (`a3ea21dba4d3395d569d846b8cb119452fad0cedbf690eb72a29976918a8702a`) were previously exposed: **permanently exclude both from all VE1-D tuning/holdout/reserve partitions, even if candidate-zero in the new pool**. Production pool selection must still process them in frozen seed order.
- Once the production pool and 16-position manifest are derived, commit VE1-D exclusion Authority for **every processed-prefix game producing >=1 candidate plus the permanent B6 fixture**, before any natural pilot invocation. Zero-candidate processed games do not enter the exclusion.
- No VE1-D tuning, holdout or reserve inspection before the preregistered C1 pilot and exclusion boundary.

## Next bounded action

1. **Authority promotion is complete**, exact successor `05ec68ba0b40bdd2980431d9d1931c08a4052b02`. Before pool execution, ensure the actual VE1-D exclusion generator/validator includes previously exposed seed 1 and 2 even if the current selector finds zero candidates, while retaining the ordinary zero-candidate rule for unrelated games.
2. Rerun the **unchanged** production pool from rank 1 using the pinned engine/NNUE, frozen corpus, seeded order, shortest-prefix stop rule, per-game cap and round-robin selection.
3. Commit complete pool, exactly 16-position manifest and complete VE1-D exclusion Authority (both exposed seeds + all candidate-producing prefix games + B6) **before any natural pilot**.
4. Before C1 Freeze, independently resolve omitted nonpromotion played-move `searchmoves` classification. C1 remains NOT FROZEN.

## Loop-minimization note

The 50k fixture incident was localized from the already-preserved Simulator `report.json`, raw USI and `failureReasons`. No additional generic Gate, Authority JSON, or workflow router was introduced. Future workflow changes should target observed failures at their actual owner, retain evidence identity and avoid reruns of independent unaffected evidence; any formal Freeze-specific full-regression requirement remains in force.
