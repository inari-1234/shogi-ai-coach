# Build19-VE1-B B6 — Physical iPhone Pre-measurement Acceptance Contract

Date: 2026-10-10
Status: **FROZEN BEFORE PHYSICAL B6 MEASUREMENT / VE1-B STILL HOLD**

## Purpose

Freeze the B6 operational acceptance rules before any physical-device result is used to decide them. These rules prevent outcome-driven threshold selection and separate search reliability from position semantics.

This document does **not** freeze the current node schedule as production authority. It freezes the method by which the current calibration schedule is accepted or rejected.

## 1. Initial validated device floor

For Build19 VE1-B, the initial minimum validated physical-device floor is:

- device identifier: `iPhone17,1`;
- OS baseline: iOS 26.7.1;
- engine/runtime: the same pinned YaneuraOu / Suisho5 NNUE / FV_SCALE=24 / Threads=1 / Hash=64MB / BookFile=no_book authority used by VE1-A and VE1-B.

A PASS on this floor authorizes only this device class or newer/equivalent classes that are separately covered by the product's compatibility policy. It does **not** claim that older iPhones satisfy B6. Supporting an older device requires a separate physical qualification run against this same contract or a formally superseding contract fixed before that run.

## 2. Physical-run control conditions

All evidence must identify app commit/build, device identifier, OS, engine/NNUE hashes, search policy, timestamps and thermal states.

### 2.1 Standard qualification runs

- Use one fixed B6 qualification KIF for shallow-repeatability measurement and record its SHA-256 before the first physical measurement.
- The fixture must yield at least three selectable shallow positions.
- Repeat the complete shallow pass **5 times**.
- Before each standard run, return the device to `nominal` thermal state.
- Use the same app build and engine options for every repetition.
- Do not reuse a previous run's engine session or TT as evidence for another run.

### 2.2 Stress characterization

After the standard qualification set, run **3 complete whole-game analyses consecutively without cooldown**, beginning from `nominal` thermal state. Stress evidence is separate from the standard sample and must never be substituted for missing standard evidence.

## 3. Shallow triage reproducibility gate

The existing shallow `movetimeMs: 150` pass is triage only. It is not explanation authority, but it affects which positions receive Deep VE1-B analysis. Therefore its selection repeatability is a mandatory B6 gate.

For the 5 standard shallow repetitions:

- define `K = 3` and take the top three selected plies from each run;
- compute Jaccard similarity for all `C(5,2) = 10` unordered run pairs using the Top-3 ply sets;
- **minimum pairwise Top-3 Jaccard must be >= 0.50**;
- the modal Top-1 ply must be the Top-1 selection in **at least 4 of 5 runs (>=80%)**;
- the same KIF, focus-side rules and position-selection code must be used in all repetitions.

For two sets of size three, Jaccard `0.50` means at least two selected plies are shared. This discrete threshold is intentional.

### Shallow gate failure rule

If either shallow criterion fails:

1. do not relax the thresholds;
2. do not continue to production-policy freeze using the 150 ms triage path;
3. migrate shallow triage to a fixed-node contract;
4. rerun the **entire B6 qualification** from the beginning under the revised shallow policy.

The shallow Top-3/Top-1 agreement metrics are selection-reproducibility metrics only. They are not semantic truth labels for the positions.

## 4. Deep VE1-B primary policy under test

The primary calibration policy to test first is fixed before measurement as:

- candidate discovery: `50,000 -> 100,000 -> 200,000` nodes, unrestricted MultiPV 3, cold TT at every tier;
- independent comparison: at each `50,000 -> 100,000 -> 200,000` tier, measure the recommended move and actual move separately with MultiPV 1, one `searchmoves` move, and a fresh cold TT boundary before **each** invocation; no warm pair series is permitted;
- nine search invocations per analyzed position under the current comparison design (3 cold unrestricted discovery + 3 cold recommended + 3 cold actual);
- per-search wall-clock safety ceiling: **15,000 ms**;
- authority before PASS: `UNFROZEN_CALIBRATION`.

B6 measures this policy; it does not silently tune it.

## 5. Standard operational acceptance gates

Use **5 complete standard whole-game runs** on the device floor, returning to `nominal` before every run. Measure every Deep VE1-B position selected by the production path.

### 5.1 Per-position nine-search workload

For `DeepAnalysisEntry.elapsedMs` / equivalent full nine-search elapsed time across all analyzed deep positions:

- median must be **<= 15,000 ms**;
- empirical P95 must be **<= 25,000 ms**.

P95 uses the nearest-rank rule: sort N observations ascending and select rank `ceil(0.95*N)`, capped at N.

### 5.2 Whole-game end-to-end runtime

Measure from shallow-analysis start through completion of all selected Deep VE1-B positions, excluding user think time and export/share actions:

- median must be **<= 90 seconds**;
- empirical P95 must be **<= 120 seconds**.

### 5.3 Completion / abort rate

Across every search invocation in the 5 standard runs:

- `safetyAborted`: **0 occurrences**;
- `earlyEngineTermination`: **0 occurrences**;
- `noCompletedExactIteration`: **0 occurrences**;
- any other incomplete-search completion state: **0 occurrences**.

Thus the standard incomplete-search rate must be **0%**. A completed but semantically `unstable`/`unconfirmed` position is **not** an incomplete search and does not fail this operational gate.

### 5.4 Thermal gate

Across the 5 standard runs:

- `.critical`: **0 occurrences**;
- `.serious`: **0 occurrences**;
- each run must begin at `nominal` as stated above.

Thermal state is an operational safety/performance gate, not evidence that a chess/shogi conclusion is semantically correct.

## 6. Stress acceptance gates

For 3 consecutive whole-game analyses without cooldown:

- `.critical`: **0 occurrences**;
- aggregate incomplete-search rate across all issued searches must be **<= 5%**;
- every incomplete Deep VE1-B position must enter the explicit incomplete-analysis state;
- incomplete/aborted evidence must suppress normal `actualLossCp`, `topCandidateGapCp`, stable coaching conclusion and any stale result from an earlier completed run;
- safe incomplete-state handling must succeed in **100% of incomplete cases**.

A `.serious` state during stress is recorded and may cause safe degradation/abort; it is not by itself a failure if the critical-state, incomplete-rate and safe-state gates above all pass.

## 7. Production node-policy decision rule

### 7.1 Primary schedule

If the primary `50k/100k/200k` policy passes:

- the shallow reproducibility gate;
- all standard operational gates;
- all stress gates;
- the already-required automated VE1-B contracts;

then B6 may freeze `50k/100k/200k` with the 15 s safety ceiling as production authority, subject to the final evidence/provenance review.

### 7.2 Predetermined fallback

If the primary schedule fails any Deep operational gate, do **not** alter thresholds after seeing the result. The only pre-authorized fallback schedule is:

- candidate discovery: `25,000 -> 50,000 -> 100,000` nodes, unrestricted MultiPV 3, cold TT at every tier;
- independent comparison: at each `25,000 -> 50,000 -> 100,000` tier, measure recommended and actual separately with MultiPV 1, one `searchmoves` move, and a fresh cold TT boundary before **each** invocation;
- nine search invocations per analyzed position (3 cold unrestricted discovery + 3 cold recommended + 3 cold actual);
- safety ceiling remains **15,000 ms**.

The fallback must rerun the **entire B6 standard and stress qualification**. It cannot inherit PASS evidence from the primary schedule.

If the fallback also fails, VE1-B remains HOLD and requires an explicit redesign/new pre-measurement contract. No ad-hoc third schedule or post-hoc threshold relaxation is permitted.

## 8. Semantic-state non-gates

Do **not** use any of the following as B6 performance acceptance thresholds:

- percentage of positions classified `stable`;
- percentage of positions where Top-1 matches the actual move;
- cp gap size;
- number of `candidate_top1_changed` observations;
- historical 41/49/69 move identities.

These are position/evidence characteristics, not runtime-health targets. B6 records their distribution for audit but does not tune node policy to force a desired semantic answer.

## 9. Required B6 report fields

The formal B6 report must contain at least:

1. app commit/build and all engine/runtime hashes/options;
2. device identifier and OS;
3. qualification KIF identity and SHA-256;
4. five shallow Top-3 lists, all ten pairwise Jaccard values, minimum Jaccard, and Top-1 modal agreement;
5. every deep position and all nine search attempts with node budget, role, TT generation, elapsed time, completion state, thermal before/after and raw evidence reference;
6. per-position nine-search median and P95;
7. whole-game median and P95;
8. standard incomplete/abort counts and rates;
9. standard thermal counts;
10. three-run stress incomplete/abort and thermal counts;
11. proof of incomplete-state UI behavior for any synthetic or naturally occurring abort;
12. final policy decision: `PRIMARY_PASS`, `FALLBACK_REQUIRED`, `FALLBACK_PASS`, or `B6_HOLD`.

## 10. Formal boundary

Automated CI PASS is necessary but not sufficient. VE1-B remains **HOLD** until physical B6 satisfies this contract and the selected production policy is frozen on one final candidate commit with preserved raw evidence/provenance.
