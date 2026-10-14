# Build19-VE1-C1 — Pre-Pool Independence Contract

Date: 2026-10-14
Status: **FROZEN BEFORE POOL GENERATION / PILOT NOT RUN**
Authority base: `566253d3b49a786c29e36a4ce73ebae7df511d13`
Sampling key: `VE1-C1-SAMPLING-v1`

This contract is fixed before inspecting or generating the natural-pilot pool. It supplements `BUILD19_VE1_C1_PRE_PILOT_CONTRACT_20261013.md`. It does not modify frozen VE1-B Authority `8daf78caa2bd5919cc911da21bae80fa3d12a248`.

## 1. Candidate-game universe is fixed before game selection

The candidate-game universe must be materialized as a committed manifest before any natural-pilot game is selected.

Primary source:

- source ID: `denryusen:dr4-hardware2:2024`
- title: `第2回マイナビニュース杯電竜戦統一ハードウェア戦`
- archive: `https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip`
- source page: `https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php`
- rights note inherited from the prior frozen regression fixture: `公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。`

The committed corpus manifest must contain:

- archive SHA-256;
- source/provenance and rights note;
- every `.kif` member path in the archive;
- exact raw-byte SHA-256 and byte size for every candidate game;
- total KIF count;
- explicit blocked/excluded game SHA-256 values.

No game may be silently added, removed, renamed by content, or substituted after the manifest is committed.

### 1.1 Permanent B6 exclusion

The repeatedly inspected B6 fixture is blocked from both VE1-C1 pilot and all VE1-D partitions:

- file: `CPU対局 81手.kif`
- SHA-256: `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`

If that hash appears in any candidate source, it must be excluded before seeded ranking. The exclusion is hash-based, not filename-based.

## 2. Game selection is seeded before engine-result inspection

Eligible games are ordered only by:

`SHA256("VE1-C1-SAMPLING-v1" | "GAME" | gameSHA256)`

ascending, with raw `gameSHA256` as the deterministic tiebreaker.

No human may choose which games are convenient or visually interesting.

Pool generation processes games in that seeded order. For each processed game, the frozen production deep-analysis selection path produces its eligible positions. Within each game, those production-selected positions are ordered by:

`SHA256("VE1-C1-SAMPLING-v1" | gameSHA256 | ply)`

and capped at four.

The processed-game prefix stops at the **shortest seeded prefix** for which:

- at least four games contribute one or more eligible positions; and
- the sum of per-game capped eligible positions is at least 16.

The 16-position manifest is then derived by the preregistered round-robin rule from the Pre-Pilot Contract. A game producing zero eligible positions causes deterministic continuation to the next seeded game; it does not permit substitution or manual selection.

## 3. Production selector implementation identity

Python must not reimplement `DeepImportanceSelector` or the private production provisional selector for authoritative pool membership.

The authoritative pool generator must execute the actual frozen production path in the iOS Simulator build:

1. `ShallowAnalysisViewModel.analyze(...)` with production fixed-node authority;
2. `DeepAnalysisViewModel.analyze(...)` in production-selection mode;
3. the private production provisional selection used by that view model;
4. `DeepImportanceSelector.selectIndices(...)` from `ShogiCoachCore` for final selection.

This is stronger than a parallel rewrite: the CI pool generator calls the same Swift production implementation that the app calls. SwiftPM `ShogiCoachCore` regression tests remain mandatory in the same workflow.

If a future implementation cannot call that exact production path, it is not authorized by this contract unless a new amendment first introduces a zero-mismatch Swift-vs-alternate selector parity gate on the identical inputs and outputs.

## 4. x86 CI shallow parity against physical B6 evidence

Before natural-pilot pool generation is accepted, the 50,000-node shallow stage on the x86 CI engine must be checked against the final physical B6 fixed-node evidence.

Physical authority source:

- aggregate file: `ve1b-b6-fixed-node-report.json`
- aggregate SHA-256: `fe63385d97293ae8cb7a577618ae66d7592d57b2960dcc899bcf93b51ff4a2a9`
- Authority commit recorded by the physical report: `8daf78caa2bd5919cc911da21bae80fa3d12a248`
- device: `iPhone17,1`
- OS: `iOS 26.7.1`
- shallow nodes: `50,000`
- fixture SHA-256: `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`

The committed parity fixture must be derived only from this exact aggregate. The physical report contains 8 runs × 81 shallow samples; derivation is accepted only if all eight runs are semantically identical on the fields consumed by production selection.

Blocking x86 parity fields for every one of the 81 plies are:

- position command;
- actual move;
- best move;
- score kind/value, including side-to-move to Black-perspective conversion;
- production `blackPerspectiveCp` where finite;
- normal completion state and 50,000-node policy.

Required result: **81 / 81 exact, zero mismatches**.

Timing, NPS and thermal values are provenance/diagnostic fields and are not cross-architecture equality gates because they do not affect production position selection.

A mismatch blocks pool acceptance. The natural pilot must not run until the mismatch is explained and this contract is explicitly amended if necessary.

## 5. Pilot-game exclusion must precede pilot execution

As soon as the deterministic 16-position manifest is derived, every contributing game SHA-256 must be committed to a VE1-D exclusion authority file before the natural pilot is executed.

The exclusion file must bind at least:

- sampling key;
- corpus-manifest SHA-256;
- pool-manifest SHA-256;
- 16-position pilot-manifest SHA-256;
- every contributing game SHA-256;
- the permanent B6 fixture SHA-256;
- exclusion scope: VE1-D tuning, holdout and reserve.

The natural-pilot workflow must refuse to run unless the committed exclusion file exactly covers all contributing pilot-game hashes and its file commit is already present in the checked-out history before the pilot execution begins.

## 6. Gate order

The required order is:

1. freeze this Pre-Pool Contract;
2. generate and commit the complete candidate-game corpus manifest;
3. derive seeded game order;
4. establish B6 x86-vs-physical shallow parity 81/81;
5. generate the pool by the actual Swift production selection path;
6. derive the deterministic 16-position manifest;
7. commit the VE1-D exclusion authority;
8. only then execute the natural 16-position pilot;
9. apply the already-frozen Pilot PASS definition;
10. synthetic regression → C1 Freeze candidate → VE1-D.

No later step may be used to tune or replace an earlier selection decision.

## 7. Current disposition

**Pre-Pool Contract = FROZEN**  
**Natural pilot = NOT RUN**  
**VE1-C1 = PILOT-READY / NOT FROZEN**
