# Build19-VE1-Q — Verification Harness Qualification

This directory is the formal verification harness for **Build19-VE1-Q**. It is scoped to harness qualification only. It does **not** advance Build20, HDS-H, VE1-B corrective implementation, or establish new 41/49/69 Semantic Authority.

The 41/49/69 data in `fixtures/build19-hds-41-49-69.json` are retained only as **Historical Diagnostic Fixture** data. They are not truth labels for VE1-Q.

## Formal gates

The current formal entrypoint is `qualify_v4_entry.py`, which binds the v4 runner, corrected C1 authority, evidence policy, fixtures and regression tests into the Q5 source identity.

- **Q1** — compile the repository's current Swift `USIParser` + `USIAccumulator`, feed the exact same raw logs to Swift and Python, and compare selected MultiPV evidence including score type/value/bound, depth, seldepth, nodes, nps, time, PV, rank, bestmove and ponder. Formal engine qualification additionally sends **every generated `raw/*.usi.log`** through both implementations. Protocol-edge coverage includes negative mate values, `info string`, and `currmove` tokens.
- **Q2** — frozen known-answer / protocol-edge fixtures plus runtime FV_SCALE known answers: mate-in-1, mate-in-3, drop `searchmoves`, in-check handling, threat-pass prohibition while checked, lower/upper bound logs, unequal MultiPV depth, missing score, missing PV, illegal move, malformed USI, and the v4 dual runtime calibration.
- **Q3** — repeat Threads=1 fixed-node searches and compare formal deterministic fields: bestmove, score, bound, depth, seldepth, nodes, MultiPV ordering and PV. Coverage includes startpos 50k, a legal middlegame 250k position, a 100k `searchmoves` comparison, and a short movetime control that must produce at least two distinct deterministic views to prove the detector can observe non-reproducibility.
- **Q4** — explicit named profiles from `profiles.json`: `app-current`, `app-candidate`, `reference`. Formal qualification must actually execute `app-current`, not only validate its JSON definition.
- **Q5** — mandatory provenance including repository/tool identity, pinned YaneuraOu identity, engine and NNUE SHA-256, fixture SHA, full advertised/applied USI options, profile/budget, OS/CPU/Python, raw log, timestamps and exit status. The raw `setoption name FV_SCALE` command and raw `loading eval file .../nn.bin` evidence are bound back to provenance and the actual NNUE file hash.
- **Q6** — fail-closed negative tests for the ten handoff-required failure classes. A false PASS fails VE1-Q.

## Independent-review supplemental conditions

VE1-Q FREEZE additionally requires C1-C5:

- **C1** — two direct runtime known-answer positions from `runtime-calibration-v2.json`: (1) startpos depth 1, FV16=`cp 164`, FV24=`cp 108`, bestmove `7g7f`; (2) corrected review SFEN depth 1, FV16=`cp 236`, FV24=`cp 157`, bestmove `2b7g+`. Each position must also satisfy `abs(cp16*16 - cp24*24) <= 40`. Fresh raw USI logs are mandatory in the qualifying run.
- **C2** — actual `app-current` engine execution plus an explicit scope limitation.
- **C3** — Swift/Python parity over all generated raw USI logs plus protocol-edge lines.
- **C4** — raw-log/provenance cross-check for FV_SCALE and loaded NNUE path/hash.
- **C5** — expanded fixed-node reproducibility plus movetime sensitivity control.

A v4 `FREEZE_CANDIDATE_MANIFEST.json` is emitted only when **Q1-Q6 and C1-C5 all PASS**.

## C1 correction record

The original review-side 236/157 observation came from a command ending in an illegal second `3c3d`. YaneuraOu stopped at the effective seven-move position, but that warning and position were not recorded with the original observation. The dated correction is preserved at `fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md`. Formal v4 uses the corrected SFEN directly, so the illegal move cannot be silently reintroduced.

The previous single-position `runtime-calibration.json` is retained as audit history only. The formal v4 C1 authority is `runtime-calibration-v2.json`.

## VE1 numeric evidence rule

`VE1_NUMERIC_EVIDENCE_POLICY.md` is mandatory for VE1 numeric expectations. A reviewer/implementer supplied number cannot become a formal expected value unless exact position identity, the complete relevant command sequence, a raw USI log, and runtime provenance are present. Incomplete numbers remain `OBSERVATION_ONLY`.

A correction of pre-existing incomplete evidence requires a dated correction record and a fresh independent reproduction from the corrected input. Expected values must never be changed merely to match the new run.

## Profiles and scope limitation

`profiles.json` defines the qualification engine settings:

- `app-current`: FV_SCALE 16, movetime 400 ms, Threads 1, Hash 64, MultiPV 3.
- `app-candidate`: FV_SCALE 24, fixed nodes, Threads 1, Hash 64, MultiPV 3.
- `reference`: FV_SCALE 24, fixed nodes with full provenance.

**Profiles reproduce engine settings only; they do not reproduce the app comparison procedure** (MultiPV candidate generation -> `searchmoves` comparison -> progressive search extension). That procedure must be separately verified by VE1-E before it can be treated as reproduced application behavior.

The node budgets in this directory are qualification budgets only and are explicitly **not** production-frozen thresholds. The current `reference` profile remains `qualification-only-unfrozen`; its depth/MultiPV policy must be reconsidered before VE1-D reference analysis authority is established.

## Known app-side issue discovered by Q1

`missing-score-swift-compat` correctly passes parity because Python reproduces current Swift behavior. However, current `USIAccumulator` can replace a scored entry with a later selected scoreless `info` entry, leaving app-side evaluation `nil`. This is recorded as **VE1B-001** in `Build19/BUILD19_VE1_B_ISSUES_20261009.md`. VE1-Q records the defect only; it does not implement the VE1-B correction.

## Running

```bash
# Static/parser/Swift parity checks only. Expected overall status is HOLD because
# runtime C1-C5, Q3 and Q5 require the pinned engine artifacts.
python3 tools/engine-verify/qualify_v4_entry.py offline

# Build exact pinned YaneuraOu + Suisho5
bash tools/engine-verify/setup.sh

# Formal Q1-Q6 + C1-C5 execution
python3 tools/engine-verify/qualify_v4_entry.py qualify
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

The input harness's existing verifier and the earlier `qualify.py` / `qualify_v2.py` / `qualify_v3.py` runners are retained for audit history. They are not the current formal v4 entrypoint. Their 41/49/69 outputs remain historical observations only and cannot establish new Semantic Authority.
