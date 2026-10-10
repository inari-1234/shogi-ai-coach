# Shogi AI Coach — Current Handoff Authority

Reference date: 2026-10-10
Status: **CURRENT HANDOFF AUTHORITY / VE1-B IN PROGRESS / NOT FORMAL PASS**

This document supersedes older chat handoff wording wherever there is a conflict. Historical VE1-Q / VR1A documents remain useful as development history, but they must not override the current VE1-A runtime authority, VE1-B contract amendments, or the evidence-boundary rules listed here.

## 1. Current formal stage

Repository: `inari-1234/shogi-ai-coach`

Current work branch:

`candidate/build19-ve1-b-pv-role-finalize`

Current stage:

**Build19-VE1-B — Search / Evidence Reliability**

VE1-B is not formally complete until the final candidate commit passes its required automated regressions, Simulator/device build path, and required physical-iPhone evidence / production-search-policy decision.

Do not start VE1-C calibration, HDS-H, Build19 Freeze, or Build20 as if VE1-B were already complete.

## 2. Engine runtime authority

The VE1-A PASS made the corrected runtime configuration authoritative.

- YaneuraOu pin: `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`
- Evaluation: Suisho5 / 水匠5
- NNUE SHA-256: `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`
- Threads: 1
- USI_Hash: 64 MB
- **FV_SCALE: 24 — FORMAL VE1-A RUNTIME AUTHORITY**

`FV_SCALE=24` is not merely a VE1-B candidate value. Do not revert to 16 or describe 24 as optional without a new formal authority-changing stage.

The current VE1-B node budgets remain calibration values until B6 physical-device evidence is accepted. Do not confuse the formal FV_SCALE authority with the still-unfrozen production node budget.

## 3. Fixed development / evidence rules

The normal workflow remains:

`current-state check -> cause analysis -> design -> implementation -> static validation -> automated/regression tests -> corrective fix -> revalidation`

An intermediate candidate is never final PASS.

Additional fixed rules:

1. **No score-only causality.** Evaluation gap may establish preference evidence but cannot by itself establish why a move is good.
2. **Shared evidence is not difference evidence.** An event appearing in both candidate lines cannot be selected as the explanation of why one candidate is preferred.
3. **PV is evidence only inside its qualified horizon.** It is not proof that the opponent is forced to play the displayed continuation unless the line is formally forced.
4. **Unstable comparison cannot become a settled recommendation.** Reliability/confidence state and recommendation wording must agree.
5. **Search instability is confidence/reliability information, not position importance.** `DeepImportanceSelector` must not raise or lower learning importance merely because deeper search is unstable.
6. **Numeric observations require complete provenance before becoming expected values.** Under `tools/engine-verify/VE1_NUMERIC_EVIDENCE_POLICY.md`, exact position identity/SFEN, the complete relevant command sequence, raw USI output, and runtime provenance are required. Numbers without that evidence remain diagnostic observations only.
7. **HDS-M PASS is a regression-contract result, not semantic validation.** For the historical 41/49/69 path it establishes that the pipeline / position-selection / contract machinery still behaves as expected. It does not prove that the prose or the old interpretation is correct.
8. **HDS contract changes are guarded.** Do not silently change the historical position-selection/fixture contract just to make HDS-M pass.
9. **VE1B-001 remains mandatory.** Later scoreless `info` must not overwrite an already valid scored observation.
10. **Mate-sign semantic acceptance remains VE1-C scope (`VE1C-002`).** Do not silently solve/freeze it inside VE1-B unless an unavoidable shared abstraction change is explicitly justified and requalified.
11. **No silent input repair.** Engine/NNUE/profile/fixture mismatches fail rather than being substituted with convenient alternatives.
12. **Preserve raw evidence.** Human-readable summaries never replace raw USI logs and machine-readable evidence/provenance.
13. **The current 120cp `loss_changed` threshold is not calibrated authority.** It is stored as `UNFROZEN_VE1C_CALIBRATION` metadata solely so current labels can be reproduced and later recalculated from saved evidence without rerunning the engine.

## 3A. Current PV evidence-role authority and current blocker correction

The current authority is `BUILD19_VE1_B_PV_ROLE_SEPARATION_AMENDMENT_20261010.md`.

- `confirmedBestPV` / `confirmedActualPV`: stability-confirmed common prefix; the **only** PV allowed to drive Reason, HDS, continuation/counterfactual simulation or verified causal explanation. Empty is valid for non-stable evidence.
- `referenceBestPV` / `referenceActualPV`: deepest qualifying completed-exact direct-measurement PV from already-saved Evidence. It is observation/display-only, must be labeled **未確認**, and cannot backfill confirmed evidence.
- all nine searches are cold: 3 discovery + 3 recommended + 3 actual; no warm N -> 2N -> 4N inheritance is current authority.

The generic Simulator failure observed in run `38056325984` was not an engine-search failure. Completion/evidence counts and non-stable loss suppression were valid; the stale E2E assertion incorrectly required every deep result to have a non-empty confirmed PV. The sampled positions were `unconfirmed`/`unstable`, for which the stability evaluator correctly returned an empty confirmed common prefix.

The earlier `PvInterval=300` / completed-iteration problem is not the current blocker. `BUILD19_VE1_B_PV_INTERVAL_COMPLETED_ITERATION_AMENDMENT_20261010.md` requires `PvInterval=0`, and commit `046ba47` implemented that correction. Also preserve the historical distinction: B3 did **not** accept a deeper bound as a final exact score; it rejected the bound, which left no qualifying exact completed result under the earlier observation path.

The current remediation therefore separates confirmed and reference PV roles, keeps non-stable coaching provisional, and adds a negative E2E guard proving that reference PV cannot leak into explanation/continuation.

## 4. 41 / 49 / 69 historical diagnostic positions

The old 41 / 49 / 69 examples are **Historical Diagnostic Fixtures only**. Their old prose and old candidate identity are not Frozen Semantic Authority.

### Ply 41 — historical failure mode

The earlier explanation taught that advancing the gold was good because the same piece participated again several moves later. Subsequent review found that this explanation **misidentified the reason**. Deeper analysis also showed that the historical candidate was not a uniquely established best move; multiple good moves existed.

Therefore the old lesson:

> advance the piece now because the same piece participates several moves later

must not be memorized or reintroduced as the semantic answer for this position.

The valid historical lesson is about the failure class: a later appearance of the same piece is not, by itself, DifferenceEvidence or proof of why one candidate is preferred.

### Ply 49 — historical failure mode

The earlier explanation emphasized reading the sequence until the exchange settles. Review found that this missed the actual differentiating mechanism and incorrectly relied on an event shared by both lines as if it were a difference.

The review correction identified removal of the bishop's defending piece as the meaningful differentiator in that analysis. However, this review correction is recorded as audit history, not promoted here into a universal or newly frozen semantic expected value without independent requalification.

The valid historical lesson is the evidence rule: **a shared capture/exchange event cannot explain preference; the explanation must point to the actual branch difference.**

### Ply 69 — historical instability example

The old case remains useful as an example of why unstable candidate ranking must not be rendered as a settled recommendation. But the historical move identity itself is not current engine truth and must not be frozen from the old fixture.

## 5. Why VE1 exists

VE1 was inserted because explanation quality cannot be trusted if the upstream Engine Evidence is not qualified.

The problems included:

- historical runtime scale mismatch before VE1-A;
- `movetime` ranking non-reproducibility;
- lowerbound/upperbound handling;
- MultiPV depth/evidence mismatch;
- an inadequate old definition of `stable`;
- prose reaching beyond the validated PV horizon;
- historical cp thresholds whose meaning changed after the corrected runtime authority.

Therefore current work must qualify search/evidence reliability before semantic thresholds or HDS-H are resumed.

## 6. VE1 stage order

Required order:

1. VE1-Q — verification harness qualification — completed upstream
2. VE1-A — engine configuration authority / corrected runtime — PASS
3. **VE1-B — search/evidence reliability — CURRENT STAGE**
4. VE1-C1 — decision-metric design before looking at calibration outcomes
5. VE1-D — reference corpus (80-100+; untouched holdout >= 30)
6. VE1-C2 — calibrate numerical thresholds using calibration data only
7. VE1-E — production app vs untouched holdout
8. VE1-V — independent validation
9. VR1B — explanation fidelity
10. Independent Semantic Validation
11. HDS-H
12. Build19 Freeze
13. Build20 — Full Game Commentary

Do not tune a threshold on the holdout and then call the same holdout independent validation.

## 7. VE1-B corrected B5/B6 search model

Two sequential defects were identified and corrected during VE1-B review.

### Defect 1 — shallow Top-1 was frozen

The first VE1-B implementation selected `discoveredBest` once at shallow search and then only compared that fixed pair at deeper budgets. That could not prove that unrestricted deeper search still preferred the same move.

The candidate-discovery correction remains mandatory:

- unrestricted MultiPV candidate discovery is re-run at every increasing node tier;
- every discovery tier starts from a cold TT boundary;
- the full ranked MultiPV observations, including exact/lowerbound/upperbound state, are retained at every tier;
- candidate Top-1 identity remains part of the B5 convergence evidence/fingerprint.

`candidate_top1_changed` is an independent reliability reason code. It is **not** synonymous with `MULTIPLE_GOOD`. VE1-C owns near-tie/multiple-good semantics and must be able to inspect the saved full candidate sets.

### Defect 2 — MultiPV2 pair measurement generated boundary-only weaker lines

The next implementation measured recommended and actual moves together with `searchmoves recommended actual`, MultiPV 2. Review showed that the weaker line can remain `upperbound`/`lowerbound` at the target, causing even a clear position to be non-qualifying under the correct B3 rule.

That method is superseded by:

`BUILD19_VE1_B_INDEPENDENT_SINGLE_MOVE_COMPARISON_AMENDMENT_20261010.md`

Current direct-comparison contract for every node tier `N`:

1. cold TT reset;
2. `searchmoves <recommended>` / MultiPV 1 / `go nodes N`;
3. preserve complete evidence;
4. cold TT reset again;
5. `searchmoves <actual>` / MultiPV 1 / `go nodes N`;
6. preserve complete evidence;
7. form the tier comparison only after both searches complete normally.

Therefore **N means N nodes per move**. No TT is inherited between the two moves or between comparison tiers. With three candidate-discovery tiers plus three recommended and three actual measurements, the corrected path is **9 engine searches per analyzed position**.

B3 is not weakened. If a single-move target still ends bounded, it remains bounded/non-exact and cannot silently support an exact stable tier.

## 8. Evidence-only stability reclassification

Stability labels must be reproducible from saved Evidence JSON alone.

The Evidence document must retain:

- explicit stability rules used for the stored label, including the current uncalibrated 120cp `loss_changed` value;
- candidate Top-1 identity/bound state per discovery tier;
- independently measured recommended and actual score kind/value/bound/PV per comparison tier;
- derived loss/inversion inputs;
- node budget, TT generation, issued command, selected final line, all raw observations, and raw USI provenance.

A regression must serialize the evidence, decode it, rerun the classifier without an engine, and reproduce the same state/reason set. VE1-C may later substitute a calibrated rule set and relabel this stored evidence without rerunning search.

## 9. `topCandidateGapCp`

The shallow first-discovery gap is not authority.

If exposed at all, the gap must:

- come from the deepest retained unrestricted candidate-discovery result;
- require exact scores for both leading candidates;
- be withheld when overall B5 convergence is not stable.

It must not be used to create a `MULTIPLE_GOOD` threshold before VE1-C calibration.

## 10. Required VE1-B regression

The regression suite must include at least:

- a fixed comparison whose unrestricted candidate Top-1 changes at the deepest tier; expected result: **not stable**;
- six direct-comparison search invocations across three tiers, each MultiPV 1 with exactly one `searchmoves` move and a distinct cold TT generation;
- node-budget evidence ordered `N,N,2N,2N,4N,4N`, where each value is per move;
- saved Evidence JSON -> decode -> evidence-only classifier produces the same stored stability state/reasons;
- all candidate-discovery MultiPV observations remain retained for later `MULTIPLE_GOOD` calibration;
- normally completed `unstable`/`unconfirmed` analysis is not treated as engine execution failure and does not expose unqualified cp loss or top-candidate gap.

A synthetic 69-like fixture is suitable for the Top-1-change contract test. Observed real-position numerical outputs remain diagnostic unless they independently satisfy the numeric evidence policy.

## 11. VE1-B formal completion boundary

VE1-B is not complete merely because Swift unit tests pass.

Final PASS requires one final candidate revision to satisfy all applicable B-gates and regressions, including:

- parser/evidence behavior and VE1B-001;
- bound handling;
- candidate-discovery convergence;
- independent cold single-move comparison convergence;
- TT isolation semantics;
- evidence-only stability reclassification;
- `BookFile=no_book`;
- abort/incomplete handling;
- Simulator/E2E regression;
- device build;
- required physical-iPhone measurements using the corrected nine-search-per-position path;
- production node-budget/search-policy decision and evidence.

**Do not perform or accept B6 physical-iPhone production-policy measurement from the superseded six-search/MultiPV2 schedule.** First finish the automated/Core/Simulator/device-build validation of the corrected method. Only then measure the corrected method on physical iPhone and choose/freeze production budgets and safety ceiling.

Until that boundary is met, report **VE1-B IN PROGRESS / NOT FORMAL PASS**.

## 12. Immediate restart instruction

When resuming from this document:

1. inspect `candidate/build19-ve1-b-pv-role-finalize` and its exact HEAD;
2. confirm `BUILD19_VE1_B_PV_ROLE_SEPARATION_AMENDMENT_20261010.md` is present and highest priority in the VE1-B Contract Index;
3. verify the production path still performs 3 cold discovery + 3 cold recommended + 3 cold actual searches and uses `PvInterval=0`;
4. verify non-stable samples may have non-empty **reference** PV while confirmed PV, Reason continuation evidence and continuation routes remain empty/provisional;
5. require the generic production-path Simulator E2E, Core regression, HDS contract evidence and iOS Device Build to PASS on the same final candidate revision;
6. only after those automated gates pass, perform physical-iPhone B6 exactly under `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md` (primary 50k/100k/200k first; only the pre-authorized 25k/50k/100k fallback if required);
7. freeze a production node/search policy only from accepted B6 evidence;
8. do not advance to VE1-C until VE1-B receives an evidence-backed formal PASS.
