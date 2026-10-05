# Build19-3B Coaching Explanation Integration — Final Report

Date: 2026-10-05

## Final Verdict

**PASS — COACHING EXPLANATION INTEGRATION COMPLETE**

Build19-3B establishes a grounded, beginner-facing comparison explanation sidecar over Build19-1 candidate comparison, Build19-2 sequence/counterfactual evidence, and Build19-3A comparison confidence. It also integrates semantic-preserving repetition control required by the Build19-P roadmap.

## Frozen Authority

- Build18: `COMPLETE / FROZEN ON MAIN`
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-1 authority HEAD: `07fac474b723d35d49093adce5e5e886acf600da`
- Build19-2 authority HEAD: `701b50a319407c6d31f7aff684ab6af7e0c76626`
- Build19-3A authority HEAD: `d348eefccfe40f8f24ecfdb0e7aa64659f0bd060`
- Build19-3B branch: `candidate/build19-3b-coaching-explanation-integration`
- Validated production implementation HEAD: `d60e2abf95e58a2e1e03f7b0d99753bca37170a7`

The formal artifact commit that contains this report is artifact-only. Production Build19-3B code is frozen at the validated implementation HEAD above.

## Implemented Production Core

- `Sources/ShogiCoachCore/ComparisonCoachingExplanation.swift`
- `Sources/ShogiCoachCore/ComparisonCoachingExplanationRepetition.swift`

The semantic resolver consumes only:

- `CandidateComparison`
- optional `SequenceComparisonEvidence`
- `ComparisonConfidenceResult`

It emits `CandidateComparisonCoachingExplanation` with typed sections for grounded difference, alternative outcome, difference timing, opponent opportunity, exchange-after information and confidence.

## Beginner Compression

The output is organized around:

1. conclusion
2. largest authorized grounded difference
3. when/how the difference appears
4. optional caveat

Optional sequence sections are omitted when the stable authorized horizon is insufficient. Raw PV dumps are not exposed as the coaching explanation.

## Causal Safety

Build19-3B does not infer a coaching reason from evaluation magnitude.

Validated behavior includes:

- score-only large gap → safe abstention
- HIGH direct grounded evidence → concrete beginner explanation
- SEQUENCE_CORRELATED → qualified wording, never direct causal wording
- unstable future claim → withheld while stable immediate reason may remain
- mismatched confidence/sequence comparison IDs → fail closed
- unsupported axes → withheld

Observed engine PV replies are described as observations within a stable reconstructed branch, not as proof that the reply is forced.

## Best vs Actual

When branch metadata identifies recommended vs actual play, the explanation explicitly frames the comparison as recommended move vs played move. It does not retroactively change MoveIntent or Build18 coaching authority.

## Exchange Semantics

When authorized exchange evidence is available, Build19-3B can explain that exchange/recapture flow differs across candidates. Equal final material does not erase a concrete difference in the exchange event sequence.

## Explanation Repetition Integration

Roadmap-required repetition integration is implemented as a presentation-only layer.

The full semantic explanation is generated and retained before presentation suppression.

Equivalent semantic shape progresses through:

- first: `STANDARD`
- second: `CONTINUITY`
- third and later: `SUPPRESSED_DUPLICATE`

The second display preserves the primary reason and confidence while removing repeated optional future-detail sections. Third-and-later duplicates are omitted from display, but the semantic explanation remains intact in state output.

Repetition resets when semantic authority changes, including comparison confidence, authorized evidence shape, pair framing or future evidence shape.

## HOLD / Unsupported Concept Isolation

No Build19-3B output automatically authorizes:

- initiative
- tempo management
- practical complexity
- ease of play
- practical winning chances

The five HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

They remain subject to Build19-4 independent re-evaluation.

## Dedicated Validation

Workflow: `Build19-3B Coaching Explanation Integration`

Validated implementation run:

- Run: `37286568941`
- Job: `111686760365`
- HEAD: `d60e2abf95e58a2e1e03f7b0d99753bca37170a7`
- Result: SUCCESS

Results:

- Build19-3B explanation + repetition: **17 / 17 PASS**
  - semantic explanation: 11 / 11
  - repetition: 6 / 6
- Build19-3A ComparisonConfidence: **12 / 12 PASS**
- Build19-2 SequenceCounterfactual: **10 / 10 PASS**
- Build19-1 CandidateComparison: **14 / 14 PASS**
- Build17 Safe Concept: **19 / 19 PASS**
- Build18 Grounded WhyNow: **9 / 9 PASS**
- Build18 Frozen Corpus projection: **1 / 1 PASS**
- Full XCTest: **137 / 137 PASS**
- Swift Testing: **16 / 16 PASS**
- Static Verify: **PASS**

Validation artifact:

- Artifact ID: `11333904402`
- SHA-256: `621f5c45a700bfddc0eae0f67ae2c99bc0f425b5f5a50596e26f7d1f8f46808d`

## iOS Device Build

Validated implementation HEAD device build:

- Run: `37286569011`
- Job: `111686760420`
- HEAD: `d60e2abf95e58a2e1e03f7b0d99753bca37170a7`
- Result: SUCCESS

Confirmed PASS:

- Core regression tests
- engine assets restore
- pinned engine preparation
- Xcode project generation
- unsigned iPhone application build
- IPA verification/package
- artifact upload

Artifact:

- Artifact ID: `11334861516`
- SHA-256: `8981040898d1a44a94d71586b91a1a525e9c12fe5ee06822fb59d89df8fa925b`

## Build19-P Requirement Coverage

The 30 Build19-P samples remain requirement sources, not fabricated pairwise truth labels.

Profile distribution:

- BASE_PAIR: 12
- PREVIOUS_REPLY: 7
- EXCHANGE: 6
- FORCING: 5

Build19-3B supplies the beginner-facing mapping for the planning questions only when upstream evidence and confidence authorize it. It does not invent missing alternative candidates or PVs merely to claim 30/30 pairwise execution.

## Formal Artifacts

1. `BUILD19_3B_ARCHITECTURE_20261005.md`
2. `BUILD19_3B_EXPLANATION_SCHEMA_20261005.json`
3. `BUILD19_3B_WORDING_POLICY_20261005.json`
4. `BUILD19_3B_REPETITION_POLICY_20261005.json`
5. `BUILD19_3B_UNIT_TEST_RESULTS_20261005.json`
6. `BUILD19_3B_REQUIREMENT_FIXTURE_COVERAGE_20261005.json`
7. `BUILD19_3B_REGRESSION_RESULTS_20261005.json`
8. `BUILD19_3B_FINAL_REPORT_20261005.md`

## Completion Assessment

- grounded beginner comparison explanation: PASS
- score-gap causal suppression: PASS
- confidence-authorized wording: PASS
- future-horizon isolation: PASS
- PV non-forced caveat: PASS
- Best vs Actual framing: PASS
- exchange-after explanation: PASS
- repetition integration: PASS
- semantic preservation under repetition: PASS
- unsupported-axis suppression: PASS
- HOLD isolation: PASS
- Build19-3A regression: PASS
- Build19-2 regression: PASS
- Build19-1 regression: PASS
- Build18 regression: PASS
- full Swift regression: PASS
- static validation: PASS
- iOS application build: PASS

## Next Stage Entry

Build19-4 may now perform independent HOLD Concept Re-evaluation.

Build19-4 must not automatically promote any HOLD concept merely because sequence evidence is now available. Each concept requires its own positive/negative semantic authority and safe wording decision before any integration.
