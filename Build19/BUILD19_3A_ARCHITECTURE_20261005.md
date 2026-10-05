# Build19-3A Comparison Confidence / Explanation Eligibility — Architecture

Date: 2026-10-05

## 1. Objective

Build19-3A adds an independent confidence sidecar over Build19-1 CandidateComparison and Build19-2 SequenceComparisonEvidence.

Pipeline:

`CandidateComparison + SequenceComparisonEvidence -> ClaimConfidenceAssessment[] -> ComparisonConfidenceResult`

This stage decides **whether a grounded A/B difference may be verbalized and how strongly**, not how the final beginner-facing sentence is written.

## 2. Authority boundary

Build19-3A does not mutate or rerank:

- MoveIntent
- ContextIntentResolver
- Intent weights
- ContextConfidence
- Build18 GroundedExplanation policy
- Build19-1 CandidateComparison evidence
- Build19-2 Sequence / Counterfactual evidence
- HOLD concepts

ComparisonConfidence is deliberately independent from ContextConfidence.

## 3. Confidence levels

- `HIGH`: same-condition stable pair, comparable score domain, traceable/provenanced grounded claim, stable required horizon, and at least one DIRECT_CONSEQUENCE or REPLY_LINKED claim without unresolved conflict.
- `MEDIUM`: grounded difference exists but attribution is incomplete, sequence-correlated, or multiple plausible grounded explanations prevent direct wording.
- `LOW`: only factual/limited grounded distinction is safe; no direct causal wording.
- `UNRESOLVED`: foundation gates fail, no non-score grounded difference exists, provenance is missing, score domains are unsafe to compare, or no claim can safely be verbalized.

## 4. Preference magnitude is separate

The engine score gap is retained only as `PreferenceMagnitude`:

- score domain
- exact centipawn delta when applicable
- candidate A score text
- candidate B score text

It is never an input that increases ComparisonConfidence. A 1000cp gap can remain UNRESOLVED. A 30cp gap can coexist with HIGH evidence confidence for a directly observed tactical distinction.

## 5. Component gates

`ComparisonConfidenceComponents` exposes:

1. pairwiseConditionMatch
2. rankingStability
3. scoreDomainComparability
4. firstMoveTraceability
5. sequenceStableThroughClaimedHorizon
6. differenceSpecificity
7. strongestCausalStrength
8. conflictingDifferenceState
9. provenanceCompleteness

No single component independently manufactures HIGH.

## 6. Claim-level confidence

Every upstream DifferenceEvidence receives a sidecar ClaimConfidenceAssessment with:

- evidence ID
- kind
- horizon
- causal strength
- HIGH / MEDIUM / LOW / UNRESOLVED
- safeToVerbalize
- eligibleForCausalWording
- limitations

This avoids rewriting the frozen Build19-1 data contract while still giving each claim an explicit confidence state.

## 7. Horizon isolation

Immediate and future claims are evaluated independently.

An unstable continuation does not erase a stable immediate fact. Instead:

- an immediate DIRECT_CONSEQUENCE may remain HIGH;
- an OPPONENT_REPLY / OWN_CONTINUATION / SHORT_HORIZON claim that exceeds the stable reconstructed horizon becomes UNRESOLVED and is withheld.

Overall confidence is aggregated from claims actually eligible for output. A withheld future claim cannot downgrade a valid immediate direct claim merely by existing.

## 8. Causal wording policy

- DIRECT_CONSEQUENCE: direct causal wording may be eligible when all gates pass.
- REPLY_LINKED: direct causal wording may be eligible when the required reply horizon is stable and provenance is complete.
- SEQUENCE_CORRELATED: maximum MEDIUM; direct causal wording is prohibited.
- UNRESOLVED: maximum LOW factual wording if the fact itself is safe.
- SCORE_DIFFERENCE: never causal evidence; at most ranking/factual support.
- NO_GROUNDED_CAUSAL_DIFFERENCE: UNRESOLVED.

## 9. Conflict semantics

Multiple complementary facts are not automatically conflicts. For example, capture + promotion + material ownership change may describe one tactical consequence.

Conflict is raised only when:

- an explicit contradiction/conflict warning exists, or
- several verbalizable substantive differences exist but upstream cannot select a dominant difference candidate.

## 10. Unsupported axes

ComparisonConfidence does not grant authority to unsupported axes such as initiative, tempo, practical complexity, or HOLD concepts. High confidence in a concrete capture difference does not authorize an unrelated strategic label.

## 11. Diagnostic contract

`ComparisonConfidenceDiagnostic` exports structured JSON containing:

- overall level
- wording strength
- preference magnitude
- component gates
- claim assessments
- eligible / withheld evidence IDs
- reasons
- warnings

## 12. Build19-3B boundary

Build19-3A does not produce final beginner coaching prose, UI redesign, PV dumps, or free-form causal completion. Build19-3B may consume only claims authorized by this policy.
