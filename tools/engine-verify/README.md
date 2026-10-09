# Build19-VE1-Q — Verification Harness Qualification

This directory is the formal verification harness for **Build19-VE1-Q**. It is scoped to harness qualification only. It does **not** advance Build20, HDS-H, or establish new 41/49/69 Semantic Authority.

The 41/49/69 data in `fixtures/build19-hds-41-49-69.json` are retained only as **Historical Diagnostic Fixture** data. They are not truth labels for VE1-Q.

## Formal gates

`qualify.py` implements the handoff Q1–Q6 gates:

- **Q1** — compile the repository's current Swift `USIParser` + `USIAccumulator`, feed the exact same raw logs to Swift and Python, and compare selected MultiPV evidence including score type/value/bound, depth, seldepth, nodes, nps, time, PV, rank, bestmove and ponder.
- **Q2** — frozen known-answer / protocol-edge fixtures: mate-in-1, mate-in-3, drop `searchmoves`, in-check handling, threat-pass prohibition while checked, lower/upper bound logs, unequal MultiPV depth, missing score, missing PV, illegal move, malformed USI.
- **Q3** — repeat fixed-node, Threads=1 searches and compare formal deterministic fields: bestmove, exact score, bound, depth, seldepth, nodes, MultiPV ordering and PV.
- **Q4** — explicit named profiles from `profiles.json`: `app-current`, `app-candidate`, `reference`. Reports record FV_SCALE, search mode/budget, Threads, Hash and MultiPV.
- **Q5** — mandatory provenance including repository/tool identity, pinned YaneuraOu identity, engine and NNUE SHA-256, fixture SHA, full advertised/applied USI options, profile/budget, OS/CPU/Python, raw log, timestamps and exit status.
- **Q6** — fail-closed negative tests for the ten handoff-required failure classes. A false PASS fails VE1-Q.

## Profiles

`profiles.json` freezes the *profile semantics* required for qualification:

- `app-current`: FV_SCALE 16 equivalent, movetime, Threads 1, Hash 64, MultiPV 3.
- `app-candidate`: FV_SCALE 24, fixed nodes, Threads 1, Hash 64, MultiPV 3.
- `reference`: FV_SCALE 24, fixed nodes with full provenance.

The node budgets in this directory are qualification budgets only and are explicitly **not** production-frozen thresholds.

## Running

```bash
# Static / parser / Swift parity checks only. Expected overall status is HOLD
# because Q3 and Q5 require the pinned engine artifacts.
python3 tools/engine-verify/qualify.py offline

# Build exact pinned YaneuraOu + Suisho5
bash tools/engine-verify/setup.sh

# Formal Q1-Q6 execution
python3 tools/engine-verify/qualify.py qualify
```

A formal PASS creates:

- `results/current/ve1q-results.json`
- `results/current/VE1Q_SUMMARY.md`
- `results/current/VE1Q_FINAL_REPORT.md`
- `results/current/provenance-manifest.json`
- `results/current/raw/*.usi.log`
- `results/current/FREEZE_CANDIDATE_MANIFEST.json`
- `results/current/SHA256SUMS.json`

On FAIL/HOLD, no freeze-candidate manifest is produced.

## Pre-qualification verifier

The input harness's existing verifier is retained only for historical/exploratory diagnostics. Its 41/49/69 outputs are historical observations only; they cannot be used to establish new Semantic Authority. The formal VE1-Q entrypoint is `qualify.py`.
