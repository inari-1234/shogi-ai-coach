# Shogi AI Coach — Current Handoff Authority

Reference date: 2026-10-10
Status: **CURRENT HANDOFF AUTHORITY / VE1-B IN PROGRESS / NOT FORMAL PASS**

This document supersedes older chat handoff wording wherever there is a conflict. Historical VE1-Q / VR1A documents remain useful as development history, but they must not override the current VE1-A runtime authority, VE1-B contract amendments, or the evidence-boundary rules listed here.

## 1. Current formal stage

Repository: `inari-1234/shogi-ai-coach`

Current work branch:

`candidate/build19-ve1-b-implementation`

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

The first VE1-B implementation contained a serious logical defect:

- one shallow unrestricted MultiPV search selected `discoveredBest`;
- later `N -> 2N -> 4N` searches were restricted to `searchmoves discoveredBest actual`;
- therefore the fixed pair could look converged without ever checking whether unrestricted deeper search still ranked `discoveredBest` first.

That model is superseded by `BUILD19_VE1_B_CANDIDATE_DISCOVERY_CONVERGENCE_AMENDMENT_20261010.md`.

Current required model:

### Candidate-discovery series

- unrestricted MultiPV candidate discovery is re-run at every increasing node tier;
- each discovery tier starts from a cold TT boundary;
- full ranked MultiPV evidence is preserved;
- candidate Top-1 identity is part of the B5 convergence fingerprint;
- if the highest qualifying increasing tiers disagree on Top-1, the result cannot be `stable`.

VE1-B does **not** invent a new cp threshold for a "nearly equal" candidate set. That semantic grouping remains VE1-C calibration scope. Until then, Top-1 changes are treated conservatively as reliability evidence and the full MultiPV list is retained for later calibration.

### Direct-comparison series

- after candidate discovery, reset to a fresh cold TT boundary;
- use the deepest unrestricted candidate Top-1 and the actual move for the fixed-pair diagnostic comparison;
- within this single confirmation series, increasing node tiers may retain TT under the staged-reuse contract;
- candidate-discovery TT history must not seed direct comparison.

Candidate-ranking convergence and fixed-pair comparison convergence are different claims and must not be collapsed into one.

## 8. `topCandidateGapCp`

The shallow first-discovery gap is not authority.

If exposed at all, the gap must:

- come from the deepest retained unrestricted candidate-discovery result;
- require exact scores for both leading candidates;
- be withheld when overall B5 convergence is not stable.

It must not be used to create a `MULTIPLE_GOOD` threshold before VE1-C calibration.

## 9. Required VE1-B regression

The regression suite must include a negative case with this shape:

- fixed-pair comparison fingerprint appears unchanged;
- unrestricted candidate discovery changes Top-1 at the deepest tier;
- expected result: **not stable**.

A synthetic 69-like fixture is suitable for the contract test. Observed real-position numerical outputs remain diagnostic unless they independently satisfy the numeric evidence policy.

## 10. VE1-B formal completion boundary

VE1-B is not complete merely because Swift unit tests pass.

Final PASS requires one final candidate revision to satisfy all applicable B-gates and regressions, including:

- parser/evidence behavior and VE1B-001;
- bound handling;
- candidate-discovery convergence;
- fixed-pair convergence;
- TT isolation/reuse semantics;
- `BookFile=no_book`;
- abort/incomplete handling;
- Simulator/E2E regression;
- device build;
- required physical-iPhone measurements;
- production node-budget/search-policy decision and evidence.

Until that boundary is met, report **VE1-B IN PROGRESS / NOT FORMAL PASS**.

## 11. Immediate restart instruction

When resuming from this document:

1. inspect the current `candidate/build19-ve1-b-implementation` HEAD;
2. confirm the candidate-discovery convergence amendment is present;
3. inspect all CI/regression results for that exact HEAD;
4. fix deterministic failures without weakening the contract;
5. if automated gates pass, continue to the required physical-iPhone B6 evidence / production-search-policy decision;
6. do not advance to VE1-C until VE1-B receives an evidence-backed formal PASS.
