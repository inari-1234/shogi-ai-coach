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


## Field-level NONE_IDENTIFIED WhyNow de-duplication

Resetting the full explanation does not require reprinting an identical generic WhyNow fallback. If Intent/evidence changes but the raw WhyNow remains the exact same NONE_IDENTIFIED fallback:

- the new conclusion is shown normally;
- evidence and safe Concept supplement remain available;
- the repeated WhyNow field is omitted for that ply;
- raw WhyNow remains in diagnostic output;
- the mode is STANDARD_WHY_NOW_SUPPRESSED.

This rule is not synonym rotation and does not add any semantic claim. It exists solely to enforce the hard gate that no exact WhyNow text remains mechanically visible for 4+ true consecutive plies.
