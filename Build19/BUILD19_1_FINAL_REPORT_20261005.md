# Build19-1 Candidate Comparison Core — Final Report

Date: 2026-10-05

## Final Verdict

**PASS — CANDIDATE COMPARISON CORE COMPLETE**

Build19-1 satisfies the formal completion criteria and is ready to hand off typed comparison evidence to Build19-2.

## Frozen Authority

- Build18: `COMPLETE / FROZEN ON MAIN`
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-P planning authority: `candidate/build19-p-gap-audit` @ `1ff3ce4196ce7d5f88cda9a1aadebf53bc15f215`
- Build19-1 branch: `candidate/build19-1-candidate-comparison-core`
- Validated production-code HEAD: `e628b5b0dc848231bf541d6b74214d06568b3f19`

Later Build19-1 commits add only formal artifacts and CI hardening; no production comparison code was changed after the validated production-code HEAD.

## Implemented Core

Build19-1 adds a production-core, typed, read-only comparison sidecar:

`CandidateAnalysisResolver`
→ `CandidateAnalysis`
→ `CandidateComparisonResolver`
→ `SharedEvidence` / `DifferenceEvidence`
→ `CandidateComparison`
→ confidence signals / diagnostic export.

The implementation is not based on iOS ViewModel authority. Existing `BoardSnapshotResolver`, `MoveEffectResolver`, `USIScore`, and defined check/king-zone board metrics are reused in `ShogiCoachCore`.

Pairwise comparison formally supports:

- `TOP1_VS_TOP2`
- `BEST_VS_ACTUAL`
- future custom pairings without requiring N-way ranking now.

## Same-condition Engine Normalization

A comparison is stable only when both candidates are individually stable and the compared lines use the same:

- position,
- engine context,
- search condition,
- score perspective,
- movetime,
- requested depth,
- candidate-specific PV first move.

A mismatch is retained as a warning and suppresses the dominant-difference conclusion. A candidate whose PV does not start with its own move is forced to `comparisonStable=false` and `continuationStable=false`.

Engine-comparison stability remains separate from future explanation confidence. Build19-1 exports confidence signals but does not implement Build19-3A's final confidence policy.

## Shared vs Difference Evidence

Shared facts are first-class `SharedEvidence` and cannot be reused as a reason why A is better than B.

`DifferenceEvidence` carries:

- ID and typed kind,
- A/B values,
- source evidence IDs,
- source moves,
- explicit horizon,
- causal strength,
- safe-to-verbalize flag,
- limitations.

Grounded initial differences cover score/mate category, capture, material inventory, promotion, check, defined king-zone metrics, exchange consequence, first opponent reply, and defined first-move board effects.

## Causal Safety Boundary

Build19-1 does not reverse-engineer the engine's full internal reason for an evaluation gap.

- `SCORE_DIFFERENCE` is always causal-strength `UNRESOLVED`.
- A score gap alone cannot become `dominantDifferenceCandidate`.
- Score-only cases emit `NO_GROUNDED_CAUSAL_DIFFERENCE`.
- Check, capture, material, and other observed facts retain limitations preventing claims that the fact alone explains the complete evaluation delta.
- Immediate recapture downgrades transient capture/material observations from simple causal advantage and emits exchange evidence at the opponent-reply horizon instead.
- Unstable comparison suppresses the dominant conclusion entirely.

## Immediate / Future Boundary

Build19-1 resolves the candidate's first move and may inspect the first opponent PV reply only as concrete typed evidence.

It does not attempt full PV semantic interpretation. The following remain typed future handoffs for Build19-2:

- immediate recapture detected,
- opponent-reply events differ,
- continuation differs,
- continuation is unstable.

Build19-2 remains responsible for stable-horizon reconstruction, first-difference timing, multi-ply exchange consequence, what a branch allows, and counterfactual timeline explanation.

## Unsupported / Deferred Axes

Raw strategic or human-practical labels are not automatically grounded in Build19-1.

Guarded or deferred axes include initiative, tempo, board/piece activity, future attack, future defense burden, continuation quality, move flexibility, risk, practical complexity, and human ease. Default comparison requests grounded axes only. Unsupported axes are reported only when explicitly requested.

No `risk`, `practical`, `easy to play`, `easy to win`, or equivalent automatic explanation is generated.

## Build18 Isolation

The Build19-1 CI scope guard confirms that Build19-1 did not redesign or modify the protected Build18 authority. Specifically:

- MoveIntent is not reranked or overwritten.
- ContextIntentResolver is unchanged.
- Intent weights are unchanged.
- ContextConfidence thresholds are unchanged.
- GroundedExplanation policy is unchanged.
- Existing UI is not forced to show comparison explanations.
- Frozen Corpus is unchanged.
- HOLD concepts are not promoted.

The five HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

## Formal Validation

Build19 validation run `37269680484` completed successfully with all gates PASS:

- Authority and scope guard: PASS
- 30-position requirement-fixture contract coverage: 30/30, critical defects 0
- Candidate Comparison dedicated tests: 14/14 PASS
- Build17 Safe Concept regression: 19/19 PASS
- Build18 Grounded WhyNow regression: 9/9 PASS
- Build18 Frozen Corpus projection: 1/1 PASS
- Full XCTest suite: 98/98 PASS
- Swift Testing library: 16/16 PASS
- Static verify: PASS

The Build19-P 30-position labels were used only as requirement-source metadata, not as newly asserted answer labels. No alternative candidate was invented merely to make the fixture pass.

iOS Device Build run `37269181189` also completed successfully on validated production code:

- Core regression tests: PASS
- Pinned engine setup: PASS
- Xcode project generation: PASS
- Unsigned iPhone build: PASS
- IPA verification/package: PASS

An initial dedicated-test run failed because three new tests reused `7g7f` after the fixture position had already played that move. This was a test-fixture defect, not a production-architecture conflict. The fixture was corrected to a legal quiet move and the complete validation chain subsequently passed. The defect is CLOSED.

## Requirement Fixture Result

`BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json` contributes 30 requirement fixtures covering:

- `NONE_IDENTIFIED`
- `DIRECT_PREVIOUS_MOVE`
- `EXCHANGE_SEQUENCE`
- `FORCING_TACTIC`
- confidence classes `high / medium / low / unresolved`
- `OPENING / MIDDLEGAME / ENDGAME`

Build19-1 validates that its typed contract can represent the required comparison/evidence handoff class for all 30. It intentionally does not relabel those samples or claim Build19-2 sequence conclusions prematurely.

## Completion Criteria

- CandidateAnalysis contract: PASS
- A/B pairwise comparison: PASS
- same-condition engine comparison: PASS
- SharedEvidence vs DifferenceEvidence separation: PASS
- Immediate Difference: PASS
- Future Difference typed handoff: PASS
- causalStrength retained: PASS
- score gap not converted into causal reason: PASS
- unstable comparison suppression: PASS
- unsupported-axis suppression: PASS
- MoveIntent unchanged: PASS
- ContextConfidence unchanged: PASS
- Build18 regression preserved: PASS
- 30 requirement fixtures without critical defect: PASS
- diagnostic JSON authority available: PASS
- iOS application build: PASS
- Build19-2 entry criteria: PASS

## Required Artifacts

Build19-1 contains all required artifacts:

1. `BUILD19_1_ARCHITECTURE_20261005.md`
2. `BUILD19_1_COMPARISON_DATA_CONTRACT_20261005.json`
3. `BUILD19_1_DIFFERENCE_EVIDENCE_SCHEMA_20261005.json`
4. `BUILD19_1_GROUNDED_AXIS_MATRIX_20261005.json`
5. `BUILD19_1_UNIT_TEST_RESULTS_20261005.json`
6. `BUILD19_1_REAL_GAME_FIXTURE_RESULTS_20261005.json`
7. `BUILD19_1_REGRESSION_RESULTS_20261005.json`
8. `BUILD19_1_FINAL_REPORT_20261005.md`

## Build19-2 Entry

Build19-2 `Sequence / Counterfactual Evidence` may now consume the Build19-1 typed sidecar without changing Build18 intent authority. Its formal responsibility begins at sequence reconstruction: Candidate Move → Opponent Reply → Continuation, stable horizon, first-difference timing, future difference, what each branch allows, net exchange consequence, and grounded counterfactual timeline.

Build19-1 does not pre-implement Build19-2 natural-language counterfactual explanation.
