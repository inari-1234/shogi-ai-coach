# Build19-VE1-Q — Independent Acceptance and VE1-A Carry-Forward

Date: 2026-10-09
Branch: `candidate/build19-ve1-q-engine-verify`
Qualified HEAD before this acceptance note: `bc1fefae3de150239653ea595f2dc8060d0f63a2`
Stage: Build19-VE1-Q — Verification Harness Qualification

## Formal disposition

Independent artifact review confirms that Build19-VE1-Q is acceptable as **FREEZE_CANDIDATE**.

The independent review verified the final evidence package rather than relying on the workflow conclusion alone.

Confirmed items:

- Artifact ZIP SHA-256: `28d2b0c5fb70e1183c11ec51368c66a74dddad390396d6ec4cafd083f4686d3a`.
- `SHA256SUMS.json`: 37 listed targets, 37 actual current-result files excluding the manifest itself, 0 hash mismatches, 0 missing, 0 extra.
- Q1-Q6: PASS.
- STATIC: PASS.
- C1-C5: PASS.
- `FREEZE_CANDIDATE_MANIFEST.json` is present.
- Provenance count: 29 runs.
- All provenance entries bind to tool commit `bc1fefae3de150239653ea595f2dc8060d0f63a2` and harness `Build19-VE1-Q/1.3`.
- C1 uses only two direct legal position authorities: `position startpos` and the corrected direct SFEN.
- C1 raw logs contain 0 `Illegal Input Move` occurrences.
- C1 known answers are 164/108 for startpos and 236/157 for the corrected SFEN.
- C1 scale-invariant differences are 32 and 8, both within the fixed tolerance of 40.
- All four C1 raw logs have Swift/Python parity under Q1.
- All four C1 runs pass Q5 raw/provenance checks for FV_SCALE, loaded NNUE path/hash, and `go` command.

The earlier workflow sealing defect, where build provenance files were copied after `SHA256SUMS.json` generation, was corrected before the final accepted artifact. The accepted artifact is the resealed run in which those files are included before formal qualification and SHA manifest generation.

## Freeze boundary

This acceptance freezes only the VE1-Q verification-harness qualification result and its evidence policy.

It does **not**:

- start Build20;
- start HDS-H;
- implement VE1-B corrective work;
- establish new 41/49/69 Semantic Authority;
- freeze production node budgets, cp thresholds, win-rate conversion, or recommendation semantics.

The 41/49/69 historical data remain **Historical Diagnostic Fixture only**.

`VE1B-001` remains OPEN / NOT IMPLEMENTED.

## VE1-A carry-forward requirements

The following are accepted as VE1-A scope items and do not block VE1-Q FREEZE_CANDIDATE.

### A1 — Real-execution negative tests

Strengthen Q6-style negative coverage with one or two actual runtime corruption/omission tests, for example:

- run without sending `setoption name FV_SCALE value ...` and verify the C1 known-answer gate fails;
- substitute a different `nn.bin` and verify loaded-NNUE SHA/provenance validation fails closed.

These tests must remain fail-closed and must not rewrite expected values to match faulty execution.

### A2 — Production app FV_SCALE 24 and in-app C1 diagnostic

Add `setoption name FV_SCALE value 24` to the app's production `EngineUSISession` path.

Add an app-side known-answer diagnostic using the start position at `go depth 1` and expect `cp 108` under the qualified FV_SCALE 24 / Suisho5 configuration.

The diagnostic expectation is authority-bound to the qualified C1 evidence. If the app produces a different value, do not change the expected value; investigate the cause.

### A3 — Simulator and physical-device equivalence

Run the same startpos / depth-1 known answer on:

- iOS simulator;
- physical iPhone device.

Expected value: `cp 108` under FV_SCALE 24 with the qualified NNUE.

Because the iPhone path may use a different CPU implementation from the CI AVX2 build, equality must be demonstrated empirically. A mismatch is a diagnostic blocker requiring root-cause analysis, not an authorization to update the known answer.

### A4 — Bundled NNUE identity

Verify the application-bundled `nn.bin` SHA-256 equals:

`768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`

The app diagnostic/provenance should make NNUE identity inspectable where practical.

### A5 — Build17/18 impact analysis

Inventory Build17/18 code, fixtures, thresholds, tests, explanation logic, and recommendation logic that depend directly or indirectly on engine cp output or cp-derived thresholds.

Classify each dependency at minimum as:

- scale-invariant / unaffected;
- numerically shifted but semantically equivalent;
- threshold-sensitive and requiring recalibration;
- behavior-sensitive and requiring regression evidence.

Do not silently preserve thresholds whose semantics change under FV_SCALE 24.

## Numeric evidence policy remains authoritative

The VE1 numeric evidence policy remains in force: SFEN or complete legal `position`, relevant command sequence, raw USI log, and runtime provenance are mandatory before a numeric observation can become a formal expected value.

This acceptance note does not supersede `tools/engine-verify/VE1_NUMERIC_EVIDENCE_POLICY.md`; it applies that policy to the VE1-Q closure and VE1-A handoff.

## Current formal state

**Build19-VE1-Q = COMPLETE / FREEZE_CANDIDATE**

Next eligible stage: **VE1-A**, only when explicitly started.
