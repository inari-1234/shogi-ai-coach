# Build18-6R1 Explanation Repetition Policy — 2026-10-05

## Classification

Exact duplicate: user-visible conclusion + WhyNow + Concept supplement are identical on true consecutive plies.

Near duplicate: incidental tokens differ, but the user-visible explanation is materially the same.

Legitimate repeated explanation: wording may repeat after a real reset because Intent, Confidence, trigger, evidence, causality, observable context, forcing state, or Concept candidate changed. The full explanation must return to STANDARD.

Continuity explanation: the first repetition of a completely unchanged semantic signature. It states only that no new explanatory basis has appeared.

Suppressed duplicate: the third or later ply in an unchanged semantic run. Raw semantic explanation remains in diagnostics while duplicate user-visible text is omitted.

## Reset conditions

Full-explanation suppression resets immediately when WhyNow trigger/authority, selected Intent, Confidence, supporting evidence ID/kind/weight/detail, source signal, observable FACT, CONTEXT_CHANGE/observed change, causal previous move, forcing state, or safe Concept candidate changes.

A reset always returns the full presentation mode to STANDARD.

## Generic NONE_IDENTIFIED WhyNow field cap

1. Track only the actually visible WhyNow text on true consecutive plies.
2. For NONE_IDENTIFIED, allow the same exact visible WhyNow at most three consecutive times.
3. If a fourth identical visible occurrence would happen after a genuine semantic reset: keep mode STANDARD; keep the new conclusion/evidence/confidence/tone/Concept behavior; omit only WhyNow for that ply; preserve raw WhyNow; record whyNowSuppressedAsRepeatedGeneric=true.
4. The blank field breaks the visible run; subsequent changed positions can display the fallback normally again.

This is not synonym rotation, confidence manipulation, or meaning creation.

## Safety invariants

- Missing remains safer than wrong.
- No random paraphrase rotation.
- No unsupported purpose.
- No confidence promotion.
- No new Concept.
- No future-line assertion.
- No fabricated mate/threatmate.
- No alteration to GroundedExplanationProjector output.
- Build18-5A HOLD remains unchanged.
- T2/T3/T4/T5/T6 reset behavior must not be weakened to make the repetition gate pass.
