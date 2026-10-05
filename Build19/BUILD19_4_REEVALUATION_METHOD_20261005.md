# Build19-4 HOLD Concept Re-evaluation — Method

Date: 2026-10-05
Repository: inari-1234/shogi-ai-coach
Base authority: Build19-3B final HEAD `9637da6998235ed0e8464b8cbfeb0256f5511d41`
Status: CANDIDATE / VALIDATION PENDING

## Objective

Re-evaluate exactly the five concepts held by Build18-5A after Build19-1 through Build19-3B added typed pairwise comparison, stable sequence reconstruction, counterfactual evidence, comparison confidence, and beginner-facing coaching explanation.

Targets:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

The existence of new sequence evidence is not promotion authority. Promotion requires concept-specific positive semantic authority, negative/adversarial controls, machine-verifiable evidence gates, and wording that cannot exceed the evidence.

## Frozen authorities

- Build18-M frozen authority remains unchanged.
- Build18-5A decision manifest is historical authority for the pre-Build19 HOLD state.
- Build19-1 CandidateComparison is read-only input authority.
- Build19-2 SequenceCounterfactualEvidence is read-only input authority.
- Build19-3A ComparisonConfidence is read-only claim authorization authority.
- Build19-3B ComparisonCoachingExplanation is read-only presentation authority.

Build19-4 must not change MoveIntent, ContextIntentResolver, ContextConfidence, Build18 GroundedExplanation, comparison confidence thresholds, or the frozen corpus.

## Re-evaluation rule

Each concept is evaluated across six independent questions:

1. **Observable capability** — can the current typed system observe the required board/sequence facts?
2. **Concept-specific positive authority** — are there authoritative examples labeled as true positives for this concept?
3. **Negative/adversarial authority** — are near-miss cases present and protected?
4. **Causal sufficiency** — do available evidence types justify the concept claim rather than merely correlate with it?
5. **Counterfactual sufficiency** — where the concept is inherently comparative, does the system test the required alternative rather than a single PV?
6. **Safe wording boundary** — can the concept be verbalized without implying more than the evidence proves?

A concept may be promoted only if all required gates for that concept pass. Missing positive semantic authority is by itself sufficient to prevent promotion.

## Decision vocabulary

- `PROMOTE_TO_LIMITED_EXPLANATION`: concept has narrow, machine-verifiable positive authority and explicit negative controls; only the approved wording may be emitted.
- `HOLD`: evidence capability or semantic authority is incomplete; no production concept output.
- `REJECT_OR_MERGE`: concept is not independently useful or can be represented safely by an existing grounded concept.

## Build19 capability delta considered

Build19-1 through Build19-3B add:

- normalized A/B candidate comparison;
- immediate typed difference evidence;
- reconstructed candidate-specific PV steps;
- stable sequence horizon;
- observed opponent consequences;
- exchange/recapture event preservation;
- future difference resolution;
- actual/counterfactual branch timelines;
- claim-level comparison confidence;
- beginner-facing explanation with score-gap causal suppression;
- PV non-forced wording;
- repetition control that preserves semantic content.

These capabilities can close observation gaps, but they do not create semantic labels or prove specialized shogi purpose by themselves.

## Concept-specific promotion gates

### respond_to_rapid_attack

Required:

- independently verified opponent rapid-attack event classification;
- direct causal response evidence tied to that event;
- positive examples and near-miss controls;
- no opening-family-only or speed-looking heuristic.

### sabai

Required jointly:

- concrete contact/exchange sequence;
- verified before/after major-piece activity change;
- stable post-exchange continuation;
- evidence that active resources are preserved or improved in the intended sense;
- authoritative positive examples plus the existing adversarial controls.

Exchange alone, mobility alone, or Shikenbisha identity alone is insufficient.

### trade_to_transform

Required jointly:

- verified exchange event;
- typed before/after role or position transformation;
- sequence/counterfactual evidence that the transformation is relevant to the branch difference;
- authoritative positive examples and near-miss controls.

A capture or board change alone is an Effect, not purpose.

### multi_threat

Required jointly:

- at least two independent concrete threats;
- proof that a single legal opponent response cannot neutralize all relevant threats;
- stable continuation or exhaustive-enough reply analysis for that claim;
- positive authority and negative/adversarial controls.

One engine PV is not an exhaustive reply tree and cannot establish reply independence.

### tempo_management

Required jointly:

- matched move-order or timing alternatives;
- verified timing-dependent consequence difference;
- stable counterfactual comparison under equivalent conditions;
- positive semantic authority and near-miss controls.

Fast-looking play, a quiet move, tenuki, development order, or a favorable score gap is insufficient.

## Expected outcome before validation

The current evidence closes several observation gaps, especially exchange and stable-sequence reconstruction, but no new concept-specific positive semantic authority has been introduced. Therefore the candidate decision is HOLD for all five concepts and zero production concept integration.

Formal PASS is withheld until the dedicated Build19-4 scope guard, decision audit, HOLD-leakage scan, complete Swift regression, static verification, and iOS build succeed.
