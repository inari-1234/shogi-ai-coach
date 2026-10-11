# Build19-VE1-B B6 — Measurement Operation & Evidence Retention Addendum

Date: 2026-10-11
Status: **FROZEN BEFORE PHYSICAL B6 MEASUREMENT / VE1-B STILL HOLD**

## 1. Purpose and authority

This addendum fixes the remaining physical-operation and evidence-retention rules before the first B6 device measurement. It supplements, and does not replace:

- `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md`;
- `BUILD19_VE1_B_B6_PHYSICAL_HARNESS_20261011.md`;
- `BUILD19_VE1_B_B6_EVIDENCE_EXPORT_PROCEDURE_20261011.md`.

The qualified application candidate remains commit:

- `7dcfdc436ea51feb0876c110581067ddbfbaaff1`

This documentation addendum is kept on a separate documentation branch so that the qualified candidate SHA is not changed.

## 2. Authorized artifacts and retention

Only the B6-bound candidate described below is authorized for the primary physical campaign.

### 2.1 Incomplete-state proof

- workflow run: `38138850760`;
- workflow: `iOS Simulator E2E` (`B6IncompleteStateProductionAbortProbe`);
- result: `success` / proof result `PASS`;
- source commit: `7dcfdc436ea51feb0876c110581067ddbfbaaff1`;
- artifact: `Build19-VE1-B6-Incomplete-State-Proof`;
- GitHub artifact archive digest: `sha256:2e72d1f62d44379736601e5fd394250391153cced5da159fa557331d64d1e6c1`;
- current GitHub Actions expiry: `2026-10-25`.

### 2.2 Physical-device candidate

- workflow run: `38138850753`;
- workflow: `Build19 VE1-B B6 Device Candidate`;
- result: `success`;
- source commit: `7dcfdc436ea51feb0876c110581067ddbfbaaff1`;
- artifact: `Build19-VE1-B6-Device-Candidate`;
- GitHub artifact archive digest: `sha256:1edf4c8e88a627362ea2202dbfeb9e86f8fefe40d0eda859dee1ae7885adee95`;
- extracted B6 IPA SHA-256: `b7f5aa0cf79b9a93214a0e63d0307fbf2a19b7e7ad43d8f5a651dcb4b4768a93`;
- current GitHub Actions expiry: `2026-10-25`.

Before the GitHub Actions artifacts expire, preserve an offline/local copy of both original artifact ZIP archives and the extracted IPA. Record the preserved file names and recomputed SHA-256 values. VE1-V independent validation must be able to compare the original preserved files, not only screenshots, copied text, or later rebuilt artifacts.

Do not delete or reinstall the B6 app after measurement begins and before all physical evidence has been exported and reconciled.

## 3. Device/environment controls

For the entire primary campaign:

- automatic iOS updates must remain disabled;
- device identifier must remain `iPhone17,1`;
- iOS must remain exactly `26.7.1`;
- Low Power Mode must remain disabled;
- one charging condition must be selected before run 1 and kept unchanged across the five standard runs and three stress runs;
- the selected charging condition must be recorded in the external measurement notes;
- the same qualification KIF and its locked SHA-256 must be used throughout the campaign;
- no app replacement, reinstall, candidate replacement, engine/NNUE replacement, or OS change is permitted within one campaign.

A change to any provenance/environment item above invalidates pooling of results before and after the change.

## 4. Predetermined fallback change control

The primary schedule remains:

- `50,000 -> 100,000 -> 200,000` nodes;
- 15,000 ms safety ceiling.

The only pre-authorized fallback remains:

- `25,000 -> 50,000 -> 100,000` nodes;
- 15,000 ms safety ceiling.

If the primary campaign yields `FALLBACK_REQUIRED`, fallback implementation requires a **new build and a new Git commit SHA**. The current primary IPA must not be reused for fallback measurement.

For the fallback-only implementation commit:

1. change only the node-policy values required to move the three tiers from `50k/100k/200k` to `25k/50k/100k` and any directly necessary policy identity/provenance label;
2. do not change acceptance thresholds, metric arithmetic, search semantics, TT-reset semantics, MultiPV/searchmoves comparison design, incomplete-state handling, B6 harness arithmetic, UI gating, HDS behavior, or evidence schema merely to obtain a passing result;
3. do not combine an unrelated bug fix, explanation change, performance optimization, or workflow relaxation into the fallback commit;
4. if any non-policy functional change is required, stop B6 with `B6_HOLD`, write a new pre-measurement contract, and re-establish CI before further physical measurement;
5. run the same-commit automated gates again, including Core regression, HDS Contract Evidence, normal Simulator E2E, Device Build, real incomplete-state Simulator proof, and a newly proof-bound B6 Device Candidate;
6. rerun the complete five-standard plus three-stress B6 campaign from the beginning. Primary evidence must not be pooled into fallback PASS evidence.

These rules are fixed before observing the primary physical outcome.

## 5. Interrupted-attempt accounting

An attempt begins when the B6 UI accepts the operator's start action and the run begins executing. From that point, an interruption may not be silently discarded or replaced by an unreported rerun.

Every interrupted attempt must be recorded, even when the app is force-quit before it can persist a normal run record.

### 5.1 Required interruption log fields

For every interrupted attempt, retain at least:

- campaign ID;
- attempt ID, in chronological order;
- standard/stress mode;
- intended standard run number or stress sequence position;
- start timestamp;
- interruption timestamp when known;
- last completed phase (`preflight`, `shallow`, `deep`, `evidence-write`, or other explicit phase);
- last known thermal state when available;
- interruption category;
- factual reason/observation;
- whether a raw Evidence file exists;
- raw Evidence file name and SHA-256 when it exists;
- whether an aggregate run record exists;
- disposition under the rules below.

Allowed interruption categories are:

- `ENGINE_OR_APP` — app crash, engine/session failure, protocol failure, or other application/runtime failure;
- `THERMAL_OR_SAFE_ABORT` — thermal protection or a search safety/incomplete condition attributable to the measured runtime path;
- `OPERATOR_OR_EXTERNAL` — accidental force quit, phone/system interference, power/cable event, or other external interruption;
- `PROVENANCE_OR_ENVIRONMENT` — OS/build/artifact/fixture/charging/provenance mismatch discovered after the attempt started.

If classification is uncertain, use the more conservative disposition and retain the observation without inventing a cause.

### 5.2 Standard-run disposition

For a standard attempt interrupted by `ENGINE_OR_APP` or `THERMAL_OR_SAFE_ABORT`:

- it is retained as failed primary operational evidence;
- it cannot be removed and replaced solely to recover `PRIMARY_PASS`;
- if the failure is a Deep operational-gate failure covered by the frozen fallback rule, the primary decision becomes `FALLBACK_REQUIRED`;
- otherwise the campaign becomes `B6_HOLD` pending root-cause review.

For a standard attempt interrupted by `OPERATOR_OR_EXTERNAL` or `PROVENANCE_OR_ENVIRONMENT`:

- it does not prove the node schedule failed;
- the affected campaign cannot produce `PRIMARY_PASS` from an unreported replacement run;
- record the interruption and set `B6_HOLD`;
- after correcting the external cause, begin a new campaign and do not pool the prior campaign with the replacement campaign.

### 5.3 Stress-run disposition

Any interruption breaks the required three-run consecutive stress sequence.

For `ENGINE_OR_APP` or `THERMAL_OR_SAFE_ABORT` during stress:

- retain the interruption as primary stress evidence;
- do not restart the three-run sequence to erase the failure;
- if it constitutes a frozen stress operational-gate failure, the primary decision becomes `FALLBACK_REQUIRED`; otherwise use `B6_HOLD`.

For `OPERATOR_OR_EXTERNAL` or `PROVENANCE_OR_ENVIRONMENT` during stress:

- retain the interrupted attempt in the external log;
- the interrupted three-run sequence is not a valid stress qualification sequence;
- set `B6_HOLD` until the external cause is corrected;
- a new stress sequence may start only from `nominal` and only if the five standard runs remain provenance/environment-compatible; if any relevant provenance/environment condition changed, restart the entire campaign instead.

A missing Evidence file caused by interruption is never interpreted as zero incomplete searches or as a PASS condition.

## 6. Canonical completed-run set and extra attempts

The formal aggregate report still requires the canonical completed set defined by the frozen contract:

- five standard runs;
- three consecutive stress runs.

However, the final B6 evidence package must also include the interruption log and every partial raw Evidence file that exists from interrupted attempts. The presence of additional interrupted attempts must be visible to independent review; they are not silently excluded from the history.

The canonical 8 raw Evidence files remain subject to the existing 8/8 file-name and SHA-256 reconciliation requirement. Any partial Evidence file from an interrupted attempt must also be hashed and listed separately.

## 7. Final B6 evidence package

Before independent B6/VE1-V review, retain together:

1. `ve1b-b6-report.json`;
2. the five canonical standard raw Evidence files;
3. the three canonical stress raw Evidence files;
4. the interruption-attempt log, including zero interruptions if none occurred;
5. any partial Evidence files from interrupted attempts;
6. the preserved `Build19-VE1-B6-Incomplete-State-Proof` artifact ZIP;
7. the preserved `Build19-VE1-B6-Device-Candidate` artifact ZIP;
8. the extracted IPA with SHA-256 `b7f5aa0cf79b9a93214a0e63d0307fbf2a19b7e7ad43d8f5a651dcb4b4768a93`;
9. external notes stating the fixed charging condition and any material device/environment event.

The final independent review must reconcile hashes and chronology as well as the numerical B6 gates.

## 8. Boundary

This addendum changes no B6 measurement threshold, primary node schedule, runtime implementation, or qualified IPA. It exists to make artifact retention, fallback change control, and interrupted-attempt handling explicit **before** physical B6 results are observed.

VE1-B remains **HOLD** until physical B6 and final independent evidence review are complete.