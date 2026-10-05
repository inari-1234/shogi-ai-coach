# BUILD19_P_CURRENT_ARCHITECTURE_ASSESSMENT_20261005

## 1. Authority and scope

Authority: Build18 COMPLETE / FROZEN ON MAIN at `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`.

Build19-P does not modify production code. This assessment classifies existing components for the next implementation phase.

Classification:

- **A — reuse as-is**
- **B — reusable with an extension/adaptor while preserving current semantics**
- **C — new layer required**
- **D — not handled in the initial Build19 implementation**

## 2. Existing architecture assessment

| Component | Class | Build19 treatment |
|---|---|---|
| MoveIntent | A | Read-only single-move semantic result. Candidate comparison must not create/re-rank MoveIntent. |
| ContextIntentResolver | A | Preserve weights, thresholds, and resolution. No pairwise score feedback into resolver. |
| ContextExplanation | B | Keep current single-move explanation; add comparison-coaching integration after the new comparison layer. |
| WhyNow / GroundedExplanationContext | B | Preserve current projector. Reuse provenance and uncertainty concepts; sequence/difference timing is supplied by a companion comparison layer rather than silently overloading existing triggers. |
| Confidence (`ContextConfidence`) | B | Keep single-move confidence unchanged; add separate `ComparisonConfidence` as a new companion type. |
| Concept | A | Existing promoted Concepts remain read-only. The five HOLD concepts are D until Build19-4 re-evaluation. |
| Engine score | B | Reuse score data but require pairwise equal-condition normalization, stability, and score-domain rules. |
| PV | B | Reuse PV as evidence input; transform it into structured SequenceEvidence rather than natural-language paraphrase. |
| Position state | B | Reuse BoardSnapshot / MoveEffect; add checkpoint features and pairwise state deltas. |
| Previous move context | A | Reuse existing causal context for each candidate; it is shared starting context, not by itself a pairwise reason. |

## 3. New layers required

### C — CandidateAnalysis

Responsibility:

- package one candidate move;
- attach equal-condition engine evidence;
- attach existing `MoveContextAnalysis` read-only;
- attach immediate board facts;
- reference the candidate's short `SequenceEvidence`;
- retain source provenance.

It must not independently change Intent or ContextConfidence.

### C — SequenceEvidence

Responsibility:

- resolve PV moves into BoardSnapshot / MoveEffect checkpoints;
- record only observable or engine-verified sequence facts;
- track exactly how far the continuation is stable;
- expose relative-horizon features for pairwise comparison.

### C — DifferenceEvidence

Responsibility:

- compare A and B at equivalent horizons;
- separate SharedEvidence from actual differences;
- state where the difference first appears;
- mark causal strength;
- keep traceable source IDs.

### C — CandidateComparison

Responsibility:

- own the A-vs-B comparison;
- aggregate score comparison, shared facts, immediate differences, and future differences;
- select a dominant explainable difference only when supported;
- never use raw evaluation gap as the reason generator.

### C — ComparisonConfidence

Responsibility:

- express confidence in the **reason for the difference**, not confidence in either candidate's MoveIntent;
- gate causal wording and future claims;
- degrade conservatively on unstable or ambiguous evidence.

### C — CounterfactualExplanation

Responsibility:

- verbalize “if B were selected” as a conditional engine branch;
- explicitly preserve hypothetical status;
- stop at the last stable evidence horizon.

## 4. Existing engine-comparison path

Current `AdaptiveComparisonAnalyzer` is a strong upstream primitive because it already supports:

- MultiPV candidate discovery;
- equal-condition best-vs-actual `searchmoves`;
- cp/mate score representation;
- adaptive re-analysis;
- comparison stability;
- continuation stability;
- PV prefix stability checks;
- top-candidate gap.

Build19 should generalize the **data contract** to arbitrary pair A/B. It should not discard this analyzer and replace it with a second unrelated engine-comparison path.

### Required extension boundary

MultiPV discovery may nominate candidates.

Any explanation-bearing A-vs-B score claim should then come from the same-position, same-settings, equal-condition pairwise analysis. Candidate ranking found during discovery is not by itself sufficient causal evidence.

## 5. Existing ContextEngine boundary

Current `MoveContextEngineEvidence` already carries:

- bestMove
- actualMove
- comparisonStable
- continuationStable
- bestPV
- actualPV
- actualLossCp
- mate/threatmate flags

However, the current engine comparison evidence mainly:

- records that an alternative exists;
- gives small support to an already anchored single-move Intent;
- emits counterfactual evidence with zero Intent weight.

This is correct for Build18 safety, but insufficient for Build19 because it does not compare feature deltas between alternatives.

### Decision

Do **not** solve this by increasing engine evidence weight in `ContextIntentResolver`.

Build19 creates a separate pairwise comparison semantic layer.

## 6. Existing ReasonAnalysis boundary

Current ReasonAnalysis has good safety behavior and should inform migration tests, but it is not the Build19 architecture because:

- it is best-vs-actual specific;
- reason rules are imperative special cases;
- SharedEvidence is not a first-class type;
- DifferenceEvidence is not typed;
- temporal localization is incomplete;
- no independent ComparisonConfidence exists.

Build19 should preserve its safe outcomes as regression fixtures, then move generalized semantics into reusable core structures.

## 7. Existing ContinuationSimulation boundary

Reusable:

- board reconstruction from PV;
- MoveEffect resolution;
- check detection;
- capture/drop/promotion events;
- king-zone observations;
- stable continuation flag.

Not authoritative for Build19 causal wording:

- route summaries generated separately;
- generic statements such as “攻めを続けやすい” when not tied to explicit comparison evidence;
- any implication that a single PV proves unique forced play.

Build19 should consume the factual route data and regenerate comparison wording through the grounded comparison layer.

## 8. Build18 GroundedExplanation integration rule

Build18's core semantic invariant remains:

> Effect answers “what changed”; Intent answers “what the move is for.”

Build19 adds:

> DifferenceEvidence answers “what changed differently between candidates”; it does not automatically answer “why the engine prefers A” unless the causal-strength gate permits that claim.

Therefore the combined safe pipeline becomes:

```text
Existing single-candidate:
Fact → ContextChange → Effect → Intent → Outcome → ContextConfidence
                                 ↓
                       GroundedExplanationContext

Build19 pairwise sidecar:
Candidate A analysis ─┐
Candidate B analysis ─┼→ SequenceEvidence → DifferenceEvidence
Engine pair evidence ─┘                          ↓
                                      CandidateComparison
                                               ↓
                                      ComparisonConfidence
                                               ↓
                                    CounterfactualExplanation
                                               ↓
                                     Coaching Integration
```

## 9. Architecture amendment threshold

Build19-1 must stop for an Architecture Amendment if implementation requires any of the following:

- changing MoveIntent semantics;
- changing ContextIntentResolver weights/thresholds;
- allowing candidate score to create Intent;
- weakening LOW/UNRESOLVED rules;
- treating PV as certain future;
- unlocking HOLD Concepts;
- changing engine implementation rather than consuming its existing analysis interface.

## 10. Assessment result

The current architecture is **compatible with Build19**.

Most upstream capabilities are reusable. The required work is a new, explicit pairwise evidence boundary rather than a resolver rewrite.

**CURRENT ARCHITECTURE ASSESSMENT: IMPLEMENTATION-COMPATIBLE**
