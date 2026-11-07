# Build19 VE1-C1 — Current Handoff

Last updated: 2026-11-07
State: VE1_B_CORRECTIVE_GATES_PASS / AUTHORITY_PROMOTION_PENDING; VE1_C1_PILOT_READY / NOT_FROZEN

## Validated implementation and fixed authorities

- Repository: `inari-1234/shogi-ai-coach`
- Candidate branch: `candidate/build19-ve1-c1-pilot`
- **Validated code/fixture commit:** `05ec68ba0b40bdd2980431d9d1931c08a4052b02`. The handoff update itself does not change runtime code or fixture inputs.
- VE1-A frozen Authority: `3252adb0fb5a066fc90362d978eec7f196f62135`.
- VE1-B historical frozen Authority: `8daf78caa2bd5919cc911da21bae80fa3d12a248` — **must not overwrite or retroactively alter**.
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

**Disposition:** Corrective implementation and listed gates PASS. **Do not yet call `05ec68b...` the formally promoted VE1-B Corrective successor Authority** until the designated owner makes that explicit Authority decision.

## Remaining boundaries / non-change rules

- VE1-B Errata #1 (mixed MultiPV output iteration/cohort) remains unresolved at production selector level; downstream C1 coherent-block guard is separate. A production-level repair is deferred to Build20+.
- C1 omitted non-promotion `searchmoves`: resolve as preregistered `NOT_CLASSIFIABLE` fail-closed or an independently specified comparison-only `LEGAL_ALL` path, with pinned regression, **before C1 Freeze**. This does not block a pool rerun after Corrective Authority promotion.
- Natural production pool **not yet rerun successfully**; no frozen 16-position manifest; natural pilot **not run**.
- Do not alter the committed corpus, seeded game order, `VE1-C1-SAMPLING-v1` key, at-most-four-per-game, shortest-prefix stop rule, or round-robin 16-position derivation. No ad hoc substitutions.
- Seed-ranked games 1 and 2 were already exposed and must be excluded from every VE1-D tuning/holdout/reserve partition, regardless of whether either contributes a final pilot position.
- Once the production pool and 16-position manifest are derived, commit VE1-D exclusion Authority for **every processed-prefix game producing >=1 candidate plus the permanent B6 fixture**, before any natural pilot invocation. Zero-candidate processed games do not enter the exclusion.
- No VE1-D tuning, holdout or reserve inspection before the preregistered C1 pilot and exclusion boundary.

## Next bounded action

1. Obtain explicit owner decision on promoting validated code SHA `05ec68ba0b40bdd2980431d9d1931c08a4052b02` as the VE1-B Corrective successor Authority, preserving historical parent `8daf78c...`.
2. Only after that Authority boundary, rerun the frozen production pool **from the first seeded game** under the same pinned engine/NNUE, selection path, original corpus and stop rules.
3. Freeze the deterministic 16-position manifest and VE1-D contamination exclusion before the natural pilot; perform Python/Swift parser parity and coherent block checks, preregistered F/E derivation, then C1 checks.
4. Do not treat this handoff or any intermediate CI PASS alone as C1 Freeze.

## Loop-minimization note

The 50k fixture incident was localized from the already-preserved Simulator `report.json`, raw USI and `failureReasons`. No additional generic Gate, Authority JSON, or workflow router was introduced. Future workflow changes should target observed failures at their actual owner, retain evidence identity and avoid reruns of independent unaffected evidence; any formal Freeze-specific full-regression requirement remains in force.
