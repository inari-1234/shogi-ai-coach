# Build18-6R1 Explanation Repetition Policy — 2026-10-05

## Classification

**Exact duplicate**: displayed conclusion + WhyNow + Concept supplement are identical on true consecutive plies.

**Near duplicate**: normalized displayed wording is materially identical even if incidental tokens differ.

**Legitimate repeated explanation**: visible wording may repeat, but a reset condition changed (Intent, Confidence, trigger, evidence, causality, observable context, forcing state, or Concept candidate). It is not suppressible merely to make the text look different.

**Continuity explanation**: the first repeat of an unchanged semantic signature. It states only that no new explanatory basis has appeared.

**Suppressed duplicate**: the third or later ply in the same unchanged semantic run. The semantic explanation is retained for diagnostics, but duplicate user-visible text is omitted.

## Reset conditions

Suppression is reset when any of the following changes:

- WhyNow trigger or authority;
- selected Intent;
- Confidence;
- supporting evidence ID/kind/weight/detail;
- source signal;
- FACT excluding current/previous move identity;
- CONTEXT_CHANGE or observed change;
- actual previous-move identity when causality is asserted;
- forcing state;
- safe Concept candidate.

## Safety invariants

- Missing remains safer than wrong.
- No random paraphrase rotation.
- No confidence promotion.
- No new Concept.
- No unsupported purpose.
- No future-line assertion.
- No fabricated mate/threatmate.
- No alteration to GroundedExplanationProjector output.
- Build18-5A HOLD remains unchanged.
