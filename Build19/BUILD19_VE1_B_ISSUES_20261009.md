# Build19-VE1-B Issue Backlog — 2026-10-09

This file records issues discovered during VE1-Q qualification and VE1-A review. It does **not** start VE1-B implementation and does not establish new Semantic Authority.

## VE1B-001 — scoreless `info` can overwrite scored accumulator entry

Status: **OPEN / NOT IMPLEMENTED**

Observed by: Build19-VE1-Q Swift/Python parity fixture `missing-score-swift-compat`.

Current behavior: when `USIAccumulator` already holds a scored PV entry and a later `info` line for the same MultiPV rank is selected by the accumulator's depth/time rule but has no score, the later scoreless entry replaces the scored entry. The resulting app-side evaluation can therefore become `nil`.

VE1-Q interpretation: parity PASS is correct because the verification harness reproduces the current Swift behavior. That parity result must not be interpreted as correctness of the app behavior.

Required VE1-B work: decide and implement the intended accumulator retention rule, then add regression tests covering scored -> scoreless replacement at equal/higher depth and time. No corrective implementation is included in VE1-Q.

## VE1B-002 — live deep analysis is movetime-bounded rather than node-bounded

Status: **OPEN / NOT IMPLEMENTED**

Observed by: VE1-A HDS-M regression review after a time-limited deep search changed `comparisonStable` and temporarily changed final position selection.

Current behavior: the live deep-analysis/HDS path is bounded by `movetime`. Search results can therefore vary with simulator/device speed, thermal state, scheduling, and other runtime conditions even when the position and engine assets are unchanged.

Required VE1-B work: design a node-count-bounded deep/live analysis mode, record the node budget and engine/runtime provenance, and validate simulator/device comparability. Any migration must preserve explicit confidence/instability reporting rather than treating determinism as semantic correctness.

This backlog item does not authorize a VE1-B implementation in VE1-A.
