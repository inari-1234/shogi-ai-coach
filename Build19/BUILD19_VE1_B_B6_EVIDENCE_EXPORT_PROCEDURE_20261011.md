# Build19-VE1-B B6 — Evidence Export Procedure

Date: 2026-10-11
Status: **FROZEN BEFORE PHYSICAL B6 MEASUREMENT / VE1-B STILL HOLD**

## Purpose

This procedure closes the B6 evidence-handling boundary without changing the frozen physical measurement policy. The primary physical policy remains 50,000 -> 100,000 -> 200,000 nodes with a 15,000 ms per-search safety ceiling.

## 1. Authorized app artifact

Use only the GitHub Actions artifact named:

- `Build19-VE1-B6-Device-Candidate`

The bundled app must contain all of the following provenance fields:

- `GitCommit` = the candidate commit being qualified;
- `B6IncompleteProofRunID` = the successful same-commit Simulator proof run ID;
- `B6IncompleteProofResult` = `PASS`;
- `B6IncompleteProofTestName` = `B6IncompleteStateProductionAbortProbe`;
- `B6IncompleteProofWorkflow` = `iOS Simulator E2E`.

The B6 physical harness rejects a measurement run if this proof binding is absent or malformed.

Do not use the generic `ShogiCoachPoC-iPhone` artifact for formal B6 measurement because it is not required to contain the B6 incomplete-state proof binding.

## 2. Pre-measurement device controls

Before the first standard run:

1. disable automatic iOS updates for the duration of the B6 campaign;
2. verify iOS is exactly `26.7.1` and the device identifier is `iPhone17,1`;
3. disable Low Power Mode;
4. choose one charging condition and keep it consistent for all five standard runs and all three stress runs; record that condition in the external B6 notes;
5. do not delete or reinstall the app after measurement begins.

The app's Documents container contains the persistent campaign state and raw evidence. Deleting/reinstalling the app destroys that local evidence.

## 3. Physical run sequence

Follow the frozen B6 contract exactly:

- standard: 5 complete runs, each beginning at thermal `nominal`;
- stress: 3 complete runs consecutively without cooldown, beginning from `nominal` only at stress campaign start;
- do not substitute stress evidence for a missing standard run;
- do not alter the primary node schedule or thresholds after observing results.

## 4. Files that must be exported

After the campaign, export:

1. the aggregate `ve1b-b6-report.json`;
2. all five standard raw Evidence JSON files;
3. all three stress raw Evidence JSON files.

Expected physical raw Evidence file count: **8**.

Also retain the GitHub Actions artifacts for the exact app commit:

- `Build19-VE1-B6-Incomplete-State-Proof`;
- `Build19-VE1-B6-Device-Candidate`.

## 5. Mandatory SHA-256 reconciliation on PC

After sharing the files to a PC, recompute SHA-256 for every one of the eight raw Evidence JSON files.

For each physical run, compare the recomputed digest against that run's `rawEvidenceSHA256` in `ve1b-b6-report.json` and verify the file name matches `rawEvidenceFileName`.

Acceptance for export integrity requires:

- aggregate report present;
- 8/8 expected raw Evidence files present;
- file-name mapping 8/8 exact;
- SHA-256 mapping 8/8 exact;
- no duplicate file substituted for another run.

Any missing file or SHA mismatch leaves B6 evidence integrity **HOLD** even if the runtime metrics otherwise pass.

## 6. Incomplete-analysis evidence

The formal candidate must be bound to a successful same-commit Simulator run of `B6IncompleteStateProductionAbortProbe`.

That probe must demonstrate the production `DeepAnalysisViewModel` path with a real engine safety abort and prove all of the following:

- run state becomes `incomplete`;
- displayed status is `深掘り 未完了（n/m局面）`;
- normal recommendation/loss output for the incomplete position is suppressed;
- raw search Evidence is written;
- at least one incomplete attempt is `safety_aborted`;
- no incomplete attempt is relabeled `node_budget_reached` or `proven_mate_termination`.

Every physical B6 run also stores `deepDisplayStatus` in its run record so a naturally occurring incomplete physical case preserves the actual UI wording in the aggregate report.

## 7. Final evidence review boundary

Do not declare VE1-B FORMAL PASS from the in-app `PRIMARY_PASS` value alone.

Final review must jointly verify:

- the frozen B6 measurement gates;
- the same-commit Simulator incomplete-state proof and Run ID;
- the B6 device-candidate provenance binding;
- the aggregate report;
- all eight raw Evidence files and their SHA-256 reconciliation;
- all other required VE1-B automated contracts.

Until that review is complete, VE1-B remains **HOLD**.
