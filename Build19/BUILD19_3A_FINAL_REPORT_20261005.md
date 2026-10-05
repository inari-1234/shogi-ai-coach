# Build19-3A Comparison Confidence / Explanation Eligibility — Final Report

Date: 2026-10-05

## Final Verdict

**PASS — COMPARISON CONFIDENCE COMPLETE**

Build19-3A establishes an independent typed confidence and explanation-eligibility layer over Build19-1 pairwise differences and Build19-2 sequence/counterfactual evidence.

## Frozen Authority

- Build18: `COMPLETE / FROZEN ON MAIN`
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-1 final authority HEAD: `07fac474b723d35d49093adce5e5e886acf600da`
- Build19-2 final authority HEAD: `701b50a319407c6d31f7aff684ab6af7e0c76626`
- Build19-3A branch: `candidate/build19-3a-comparison-confidence`
- Validated implementation/workflow HEAD: `e43c7375819cab6f2c6cb9e210f8d4125166a152`

The formal artifact commit that contains this report changes only `Build19/BUILD19_3A_*` artifacts; production confidence code is frozen at the validated implementation HEAD above.

## Implemented Core

Production file:

`Sources/ShogiCoachCore/ComparisonConfidence.swift`

Typed outputs:

- `ComparisonConfidenceLevel`
  - HIGH
  - MEDIUM
  - LOW
  - UNRESOLVED
- `ComparisonWordingStrength`
  - DIRECT_CAUSAL
  - QUALIFIED_CAUSAL
  - FACTUAL_ONLY
  - RANKING_ONLY
- `PreferenceMagnitude`
- `ComparisonConfidenceComponents`
- `ClaimConfidenceAssessment`
- `ComparisonConfidenceResult`
- `ComparisonConfidenceDiagnostic`

The confidence layer is a read-only sidecar. It does not overwrite CandidateComparison, MoveIntent, or ContextConfidence.

## Evaluation Gap Separation

The engine score gap is retained as `PreferenceMagnitude` only.

It is explicitly not a confidence booster.

Validated behavior:

- +1000cp with no non-score grounded reason → UNRESOLVED
- +30cp with a stable direct grounded tactical difference → HIGH claim confidence can be valid

Therefore preference magnitude and explanation confidence are no longer conflated.

## Independent Confidence Components

Build19-3A evaluates:

1. pairwise condition match
2. ranking stability
3. score-domain comparability
4. first-move traceability
5. sequence stability through the claimed horizon
6. difference specificity
7. strongest causal strength
8. conflict state
9. provenance completeness

No one component independently authorizes HIGH.

## Claim-level Confidence

Each typed DifferenceEvidence receives a companion ClaimConfidenceAssessment.

This records:

- evidence ID
- evidence kind
- claim horizon
- causal strength
- claim confidence
- safe-to-verbalize state
- causal-wording eligibility
- limitations

This preserves the Build19-1 contract instead of retroactively mutating it.

## Causal Strength Policy

- `DIRECT_CONSEQUENCE`: can reach HIGH and authorize direct causal wording when all gates pass.
- `REPLY_LINKED`: can reach HIGH only when the reply horizon is stably reconstructed; the observed PV reply is still not automatically proven forced.
- `SEQUENCE_CORRELATED`: maximum MEDIUM; cannot authorize direct causal wording.
- `UNRESOLVED`: at most LOW factual wording when the fact itself is safe.
- `SCORE_DIFFERENCE`: never causal evidence.
- `NO_GROUNDED_CAUSAL_DIFFERENCE`: UNRESOLVED.

## Horizon Isolation

Build19-3A validates claims at their own required horizon.

A continuation instability does not invalidate unrelated immediate evidence.

Validated case:

- immediate direct difference → HIGH remains eligible
- opponent-reply claim beyond stable horizon → UNRESOLVED and withheld
- overall comparison may remain HIGH based only on the stable immediate claim

This closes the key planning requirement that unstable sequence evidence degrades only the claims that depend on it.

## Conflict Semantics

Multiple complementary observations are not treated as automatic causal conflict.

Capture + promotion + material change can describe the same tactical event.

Conflict is reserved for:

- explicit contradiction/conflict evidence, or
- multiple verbalizable substantive differences with no dominant upstream difference candidate.

## Unsupported-axis Boundary

A HIGH confidence concrete comparison does not authorize unrelated unsupported axes.

In particular, Build19-3A does not unlock:

- initiative without required concrete evidence
- tempo management
- practical complexity
- ease of play / practical winning chances
- HOLD concepts

The five HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

## Dedicated Validation

Workflow:

`Build19-3A Comparison Confidence`

Validated implementation run:

- Run: `37278664261`
- Job: `111661330091`
- HEAD: `e43c7375819cab6f2c6cb9e210f8d4125166a152`
- Result: SUCCESS

Results:

- Build19-3A ComparisonConfidence: **12 / 12 PASS**
- Build19-2 SequenceCounterfactual: **10 / 10 PASS**
- Build19-1 CandidateComparison: **14 / 14 PASS**
- Build17 Safe Concept: **19 / 19 PASS**
- Build18 Grounded WhyNow: **9 / 9 PASS**
- Build18 Frozen Corpus projection: **1 / 1 PASS**
- Full XCTest: **120 / 120 PASS**
- Swift Testing: **16 / 16 PASS**
- Static Verify: **PASS**

Validation artifact:

- Artifact ID: `11331770594`
- SHA-256: `ea6a0fb5ae03f67706480d24750e916ff1e4ad467122cc44688166b3e721b317`

## iOS Device Build

Validated implementation HEAD device build:

- Run: `37278664096`
- Job: `111661330137`
- HEAD: `e43c7375819cab6f2c6cb9e210f8d4125166a152`
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

- Artifact ID: `11331661558`
- SHA-256: `90519a2b5885ca36c6e75942de77456f3ce665dc75b253ec436313ec2be48b2d`

## Build19-P Requirement Coverage

The 30 Build19-P real-game samples remain requirement sources rather than new pairwise truth labels.

Profile coverage:

- BASE_PAIR: 12
- PREVIOUS_REPLY: 7
- EXCHANGE: 6
- FORCING: 5

Build19-3A covers the confidence contract required by every profile, including `Q_COMPARE_CONFIDENCE`.

The source corpus does not contain complete A/B candidate-specific engine lines for all 30 positions. Build19-3A therefore does not invent alternate candidates, PVs, or per-position confidence labels merely to claim 30/30 execution.

## Formal Artifacts

1. `BUILD19_3A_ARCHITECTURE_20261005.md`
2. `BUILD19_3A_CONFIDENCE_SCHEMA_20261005.json`
3. `BUILD19_3A_CLAIM_CONFIDENCE_POLICY_20261005.json`
4. `BUILD19_3A_UNIT_TEST_RESULTS_20261005.json`
5. `BUILD19_3A_REQUIREMENT_FIXTURE_COVERAGE_20261005.json`
6. `BUILD19_3A_REGRESSION_RESULTS_20261005.json`
7. `BUILD19_3A_FINAL_REPORT_20261005.md`

## Completion Assessment

- independent ComparisonConfidence: PASS
- ContextConfidence isolation: PASS
- score-gap non-boost rule: PASS
- claim-level confidence: PASS
- claim-horizon isolation: PASS
- same-condition gate: PASS
- score-domain gate: PASS
- provenance gate: PASS
- DIRECT / REPLY_LINKED policy: PASS
- SEQUENCE_CORRELATED ceiling: PASS
- unsupported-axis suppression: PASS
- HOLD isolation: PASS
- Build19-2 regression: PASS
- Build19-1 regression: PASS
- Build18 regression: PASS
- full Swift regression: PASS
- static validation: PASS
- iOS application build: PASS

## Next Stage Entry

Build19-3B may now integrate authorized comparison claims into coaching explanations.

It should consume:

- CandidateComparison
- SequenceComparisonEvidence
- ComparisonConfidenceResult

and map them into beginner-facing explanation structure such as:

- why A is preferred to B
- what concretely differs
- whether the difference appears immediately or later
- what B permits in the analyzed line
- how certain that explanation is

Build19-3B must not re-derive confidence from the raw score gap, must not verbalize withheld claims, and must not introduce unsupported strategic labels through prose generation.
