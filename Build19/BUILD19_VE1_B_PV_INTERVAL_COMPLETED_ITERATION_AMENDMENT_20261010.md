# Build19-VE1-B — PvInterval / Completed-Iteration Evidence Amendment

Date: 2026-10-10
Status: **CURRENT VE1-B CONTRACT AMENDMENT / VE1-B NOT FORMAL PASS**

This amendment is the highest-priority VE1-B clarification for conflicts concerning `PvInterval`, iterative-deepening output, target-bound handling, and the definition of the measured score/PV. It supersedes conflicting wording in `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md`, `BUILD19_VE1_B_INDEPENDENT_SINGLE_MOVE_COMPARISON_AMENDMENT_20261010.md`, older handoff material, and earlier chat conclusions.

## 1. Defect being corrected

With the pinned YaneuraOu runtime, the default `PvInterval` is time-based. At the current 50k-200k calibration node budgets, a fast environment can finish a search before the default interval emits the completed iterative-deepening results.

In that situation the engine may emit only the line from the iteration that was in progress when the node budget stopped the search. That terminal line is frequently `lowerbound` or `upperbound`.

Therefore a contract that equates "the deepest/final emitted line" with "the measured result" makes evidence shape depend on wall-clock speed even though the search budget is node-count based. Simulator/CI and physical iPhone can then expose different numbers of `info` lines for the same node budget.

This is an evidence-observation defect. B3 must remain conservative about bounds, but the semantic measurement target must be defined as a **completed iteration**, not the interrupted terminal iteration.

## 2. `PvInterval=0` is mandatory evidence authority

Every app and harness profile used to produce VE1 evidence must send:

`setoption name PvInterval value 0`

before the first `isready`, alongside the other authoritative runtime options such as `BookFile=no_book`.

Requirements:

- app, Simulator, native verifier, qualification harness, and physical-device diagnostic paths use the same value;
- profile/provenance records contain `pv_interval_ms: 0` (or an equivalent lossless field);
- raw USI transcript proves the option was sent before `isready`;
- changing machine speed must not change whether completed iterative-deepening evidence is observable merely because of the default time-based print interval.

This option controls evidence emission. It does not change the node budget into a time budget.

## 3. Measurement definition

For a normally node-budget-completed VE1-B search, the semantic measurement is:

**the deepest fully completed exact iterative-deepening snapshot emitted before `bestmove`.**

For MultiPV 1:

- choose the greatest depth having a scored PV with `bound=exact`;
- retain that observation's own depth, seldepth, nodes, score, and PV.

For MultiPV K candidate discovery:

- choose the greatest depth at which all required MultiPV ranks `1...K` have scored exact PV observations;
- select a coherent snapshot at that depth and preserve all ranks;
- a deeper partial/bounded rank set is terminal provenance, not a completed MultiPV measurement.

A shallower completed exact iteration is **not promoted or relabeled** as the deeper interrupted iteration. Its true depth and node count remain explicit in evidence.

## 4. Terminal bound handling

The final scored `info` line emitted before `bestmove` may be `lowerbound` or `upperbound`.

It must:

- remain in raw observations;
- retain its original score/bound/depth/nodes/PV;
- be exportable as terminal provenance/diagnostic evidence;
- not replace the deepest completed exact measurement;
- not be interpreted as an exact score.

Thus B3 remains intact at the observation level: a bound is still a bound. What changes is the definition of the **measurement target**. The target is the last completed exact iteration, not the interrupted terminal iteration.

## 5. No-exact negative case

If a node-budget search emits no completed exact qualifying iteration at all, the attempt is **incomplete for VE1-B measurement**.

Required behavior:

- do not fabricate a score from a bound;
- do not treat `bestmove` alone as an exact measurement;
- do not count the attempt toward stability;
- preserve all raw observations and terminal `bestmove` provenance;
- expose an explicit incomplete reason such as `no_completed_exact_iteration`.

A regression fixture with only bounded observations must prove this negative behavior.

## 6. Bestmove consistency under completed-iteration measurement

`bestmove` is terminal engine provenance and can reflect the interrupted deeper iteration. Therefore it is not, by itself, the identity of the completed exact snapshot.

For independent single-move `searchmoves <oneMove>` searches, the completed exact PV head must match that requested move.

For unrestricted candidate discovery, candidate Top-1 for VE1-B convergence is taken from the deepest completed exact MultiPV snapshot. A terminal deeper partial iteration and its raw `bestmove` are retained separately and must not silently replace that completed snapshot.

## 7. Independent single-move comparison remains the current VE1-B method

The current comparison method remains:

- three cold unrestricted discovery tiers;
- at each comparison tier, one cold MultiPV1 search for the recommended move and one separate cold MultiPV1 search for the actual move;
- `N` means N nodes per move;
- total of 9 searches per analyzed position for three tiers.

This amendment does **not** revert the implementation to MultiPV2. Earlier evidence now suggests that `PvInterval` contributed materially to the old MultiPV2 boundary symptom, so a future comparison of 6-search vs 9-search runtime cost may be legitimate. However, no method switch is authorized inside VE1-B until the current corrected contract passes automated gates and any alternative is separately designed/requalified.

## 8. Evidence schema requirements

Machine-readable VE1-B evidence must make the distinction auditable. For every search attempt retain at least:

- `pv_interval_ms`;
- node budget, issued command, role, MultiPV, searchmoves, TT generation;
- raw observation count and all raw observations;
- terminal `bestmove` / consistency provenance;
- selected completed-exact move/score/bound/depth/seldepth/nodes/PV;
- terminal scored move/score/bound/depth/nodes when present;
- explicit completion/incomplete state.

The selected measurement's bound must be `exact` for a qualifying tier.

Evidence-only stability reclassification must consume the completed-exact selected fields and remain reproducible without rerunning the engine.

## 9. Required automated gates

PASS requires at minimum:

1. selector unit test: shallower exact + deeper bound selects the exact observation at its true shallower depth;
2. selector negative test: bound-only observations produce no measurement / incomplete;
3. MultiPV coherent-snapshot test: a deeper partial rank set cannot displace the deepest depth where all required ranks are exact;
4. native transcript contains `setoption name PvInterval value 0` before `isready`;
5. native single-move searches persist exact completed measurements while retaining terminal bound provenance when present;
6. Simulator production-path Evidence JSON records `pv_interval_ms=0`, selected exact measurement depths, raw observation counts, and terminal bound metadata;
7. serialized Evidence JSON still reclassifies to the same stored stability result without engine execution;
8. device build/IPA succeeds on the same final candidate revision.

## 10. B6 physical-device boundary

Physical-iPhone B6 production-policy measurement remains blocked until this amended contract passes Core/native/Simulator/device-build gates on one candidate revision.

Only after those gates pass may B6 measure the nine-search path and determine production node budgets/safety ceiling from device evidence.

Until then, VE1-B remains **IN PROGRESS / NOT FORMAL PASS**.
