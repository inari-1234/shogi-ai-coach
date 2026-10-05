# Build19-2 Sequence / Counterfactual Evidence — Final Report

Date: 2026-10-05

## Final Verdict

**PASS — SEQUENCE / COUNTERFACTUAL EVIDENCE COMPLETE**

Build19-2 satisfies its implementation and regression boundary and is ready to hand typed sequence evidence to the next Build19 stage.

## Frozen Authority

- Build18: `COMPLETE / FROZEN ON MAIN`
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-1 authority: `candidate/build19-1-candidate-comparison-core` @ `07fac474b723d35d49093adce5e5e886acf600da`
- Build19-2 branch: `candidate/build19-2-sequence-counterfactual-evidence`
- Validated production/workflow HEAD: `24ae609227c251bceac0715c3df1afe26bbd7acc`
- Validated artifact + iOS build HEAD: `4734355c53c68eef2f2aedbd3d4ff1043ad5e749`

Commits after the validated artifact/build HEAD add formal regression/final-report artifacts only; they do not change production comparison or sequence code.

## Implemented Core

Build19-2 adds a typed, production-core, read-only sequence sidecar over Build19-1:

`CandidateComparison`
→ `CandidateSequenceEvidence(A/B)`
→ `stableHorizonPly`
→ `SequenceDifferencePoint`
→ `ObservedOpponentConsequence`
→ `SequenceExchangeEventEvidence`
→ `FutureDifferenceResolution`
→ `CounterfactualBranchTimeline`.

The implementation stays in `ShogiCoachCore` and reuses existing board/MoveEffect infrastructure. It does not make iOS ViewModel state the authority.

## Sequence Reconstruction

Candidate-specific PV moves are replayed on reconstructed board state. Each ply retains:

- ply number and role,
- move,
- capture / promotion / drop,
- check state,
- local recapture fact,
- material inventory,
- resulting board / position command,
- whether the ply lies within the stable evidence horizon.

An invalid later PV move truncates that branch with an explicit diagnostic warning. It does not crash and no claim is inferred beyond the reconstruction failure.

## Stable Horizon

Build19-2 separates `reconstructable` from `safe to verbalize`.

- unstable pairwise comparison → stable sequence horizon = 0
- stable first-move comparison but unstable continuation → first candidate move only
- stable comparison + stable continuation → common reconstructed A/B horizon

A reconstructed but unstable later ply is retained diagnostically but is not elevated to safe sequence explanation evidence.

This remains separate from the future Build19 explanation-confidence policy.

## First Grounded Difference Timing

Candidate A and Candidate B trivially have different first move strings. Build19-2 deliberately does not treat that tautology as the useful first difference.

`firstGroundedDifference` instead selects the earliest concrete grounded consequence difference such as:

- capture,
- promotion,
- check,
- drop,
- material ownership inventory,
- opponent PV reply difference,
- later continuation difference.

This gives later coaching logic a meaningful answer to `where does the branch actually start to differ in an observable way?`

## Opponent Reply / What the Branch Allows

The stable PV can expose opponent events such as:

- capture,
- check,
- promotion,
- drop,
- immediate/local recapture.

These are represented as observed branch consequences, not as unrestricted causal claims.

Every PV-derived opponent consequence keeps the safety boundary that the observed engine PV is not an exhaustive move tree and does not by itself prove that the reply is uniquely forced.

Build19-2 can therefore ground `the analyzed A line contains this opponent capture`, while a stronger claim such as `A necessarily allows only this response` requires separate forcing evidence.

## Exchange Consequence — Corrective Finding Closed

The initial dedicated test run exposed an important architecture edge case.

A capture followed by an equal-value recapture can return material ownership counts to the starting totals. The first implementation could therefore erase the fact that an exchange had occurred because it relied too strongly on net material inventory.

The test was not weakened.

The architecture was corrected by adding `SequenceExchangeEventEvidence`, which separately preserves:

1. concrete capture / recapture event sequence, and
2. stable-horizon net material ownership delta.

As a result, `equal net material` no longer incorrectly means `no exchange difference`.

The correction is CLOSED and the complete validation chain subsequently passes.

## Future Difference Resolution

Build19-1 `FutureDifferenceCandidate` placeholders are now handed back with explicit typed status:

- `RESOLVED`
- `NOT_OBSERVED_WITHIN_STABLE_HORIZON`
- `UNRESOLVED_UNSTABLE`
- `RECONSTRUCTION_UNAVAILABLE`

No unresolved future difference is silently promoted to a grounded explanation.

## Counterfactual Timeline

Both candidate branches receive structured timelines containing:

- ply / role / move,
- capture,
- promotion,
- check,
- recapture,
- material signature,
- stable-horizon flag.

Branch reality is explicit:

- `ACTUAL`
- `COUNTERFACTUAL`
- `ANALYSIS_BRANCH`

For `Best vs Actual`, the played move remains `ACTUAL`; an unplayed recommended candidate is `COUNTERFACTUAL`.

Build19-2 does not yet turn this timeline into the final beginner-facing `もしBなら…` prose.

## Causal Safety Boundary

Build19-2 does not claim to reconstruct the engine's complete hidden evaluation rationale.

In particular:

- PV event ≠ complete engine cause
- PV reply ≠ automatically proven forced reply
- sequence correlation ≠ full causality
- equal net material ≠ no exchange
- large score gap ≠ high sequence confidence
- unstable reconstructed continuation ≠ safe explanation evidence

This is consistent with the Build19-1 rule that grounded A/B differences may explain part of the evaluation difference without claiming to explain the whole engine score gap.

## Build18 / Build19-1 Isolation

The dedicated scope guard and regression chain confirm that Build19-2 does not modify the protected authorities:

- MoveIntent unchanged
- ContextIntentResolver unchanged
- intent weights unchanged
- ContextConfidence thresholds unchanged
- Build18 GroundedExplanation policy unchanged
- Build19-1 Candidate Comparison authority unchanged
- Frozen Corpus unchanged
- existing UI not forced to show sequence/counterfactual explanation
- HOLD concepts not promoted

The five HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

## Formal Validation

Latest pre-final-artifact Build19-2 validation run `37273733668` on HEAD `4734355c53c68eef2f2aedbd3d4ff1043ad5e749` completed successfully:

- Build19-1 Authority / Scope Guard: PASS
- dedicated Sequence / Counterfactual tests: 10/10 PASS
- Build19-1 Candidate Comparison regression: 14/14 PASS
- Build17 Safe Concept regression: 19/19 PASS
- Build18 Grounded WhyNow regression: 9/9 PASS
- Build18 Frozen Corpus projection: 1/1 PASS
- full XCTest suite: 108/108 PASS
- Swift Testing library: 16/16 PASS
- Static Verify: PASS

Validation log artifact:

- artifact ID: `11329082313`
- SHA-256: `ce87f4986819f6a251d72b6cd529ed2a894fbefe0e7d308bc9729153c088e446`

## iOS Device Build

`iOS Device Build` run `37273733665`, attempt 2, job `111647054030`, on HEAD `4734355c53c68eef2f2aedbd3d4ff1043ad5e749` completed successfully.

Confirmed PASS:

- engine assets restore
- Core regression tests
- pinned engine preparation
- Xcode project generation
- unsigned iPhone application build
- IPA verification/package
- artifact upload

Validated iPhone artifact:

- artifact ID: `11329851934`
- SHA-256: `95afb44533895961ed21adf31a9870496858b79dd68b1f901be3e8163ce98607`

Attempt 1 had been cancelled by workflow concurrency while artifact-only commits were being added. Commits were paused and the same latest HEAD was rerun to successful completion; this was not a code failure.

## Build19-P Requirement Fixtures

The 30 Build19-P real-game samples remain Requirement sources, not new answer labels.

Their coverage includes:

- `NONE_IDENTIFIED`
- `DIRECT_PREVIOUS_MOVE`
- `EXCHANGE_SEQUENCE`
- `FORCING_TACTIC`
- `high / medium / low / unresolved`
- `OPENING / MIDDLEGAME / ENDGAME`
- evidence profiles `BASE_PAIR / PREVIOUS_REPLY / EXCHANGE / FORCING`

The planning samples do not contain a complete A/B candidate-specific PV pair for every position. Build19-2 therefore does **not** invent alternate candidates/PVs and does not falsely report `30/30 sequence replay`.

Instead, `BUILD19_2_REQUIREMENT_FIXTURE_COVERAGE_20261005.json` verifies that every required profile has an appropriate typed Build19-2 contract. A future real-game A/B sequence corpus should contain actual candidate-specific engine lines before claiming per-position sequence replay.

## Formal Artifacts

Build19-2 contains:

1. `BUILD19_2_ARCHITECTURE_20261005.md`
2. `BUILD19_2_SEQUENCE_EVIDENCE_SCHEMA_20261005.json`
3. `BUILD19_2_COUNTERFACTUAL_TIMELINE_SCHEMA_20261005.json`
4. `BUILD19_2_UNIT_TEST_RESULTS_20261005.json`
5. `BUILD19_2_REQUIREMENT_FIXTURE_COVERAGE_20261005.json`
6. `BUILD19_2_REGRESSION_RESULTS_20261005.json`
7. `BUILD19_2_FINAL_REPORT_20261005.md`

## Completion Assessment

- Candidate PV board reconstruction: PASS
- stable horizon separation: PASS
- first grounded difference timing: PASS
- future difference typed resolution: PASS
- opponent reply consequence evidence: PASS
- PV/forced-reply safety boundary: PASS
- exchange consequence after recapture: PASS
- equal-net exchange preservation: PASS
- actual vs counterfactual timeline: PASS
- unstable continuation suppression: PASS
- invalid PV truncation/diagnostics: PASS
- structured JSON diagnostics: PASS
- Build19-1 regression preserved: PASS
- Build18 authority preserved: PASS
- full Swift regression: PASS
- static validation: PASS
- iOS application build: PASS

## Next Stage Entry

Build19-2 provides the evidence required for the next Build19 stage to combine:

- Build19-1 pairwise comparison facts,
- Build19-2 sequence timing and counterfactual facts,
- engine comparison stability,
- continuation stability,
- causal strength,
- unsupported / unresolved boundaries.

The next stage should determine when comparison evidence is strong enough to present and how strongly it may be stated. It must not collapse `score gap`, `engine stability`, `causal evidence`, and `explanation confidence` into a single signal.

Build19-2 intentionally does not finalize beginner-facing natural-language coaching.
