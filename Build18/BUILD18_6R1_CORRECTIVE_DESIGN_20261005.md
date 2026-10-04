# Build18-6R1 Corrective Design — 2026-10-05

## Scope

Build18-6 found a presentation-quality blocker: safe fallback / WhyNow text repeated for true consecutive plies. Semantic blocker counts were zero. This correction therefore stays outside MoveIntent resolution, score, evidence weight, confidence thresholds, GroundedExplanationContext semantics, frozen corpus labels, and Build18-5A HOLD decisions.

## Boundary

The correction introduces a stateful **Explanation Presentation / Repetition Policy** after semantic explanation generation.

The raw analysis and grounded explanation remain authoritative. Presentation may:

1. show the normal explanation;
2. show one continuity explanation when the full repetition signature is unchanged;
3. suppress further duplicate display while the same signature continues.

It must never create a new purpose, opponent plan, opening label, mate/threatmate claim, Concept, or WhyNow cause.

## Repetition signature

A consecutive explanation is considered equivalent only when all material presentation inputs remain unchanged:

- selected Intent;
- confidence;
- WhyNow trigger and authority;
- source evidence and source signals;
- selected-Intent supporting evidence including detail/weight;
- observable FACT values except the naturally changing current/previous move identifiers;
- CONTEXT_CHANGE values;
- grounded observed change;
- previous move identity when previous-move causality is actually asserted;
- forcing-state markers;
- unsuppressed safe Concept candidate.

Any change resets suppression and returns to normal display.

## Display state machine

- Run 1: STANDARD — existing safe explanation.
- Run 2: CONTINUITY — one short statement that no new explanatory basis has appeared; no new semantic claim.
- Run 3+: SUPPRESSED_DUPLICATE — no repeated explanation card/text for that ply.
- Reset: any signature change returns immediately to STANDARD.

The existing immediate safe-Concept suppression remains separate. Its display-only suppression does not falsely count as a semantic reset because the repetition signature uses the unsuppressed Concept candidate.

## Audit requirement

Real-game evidence must preserve both semantic and displayed forms. A suppressed display is valid only when the semantic signature is unchanged from the immediately preceding true ply and the run length is at least 3. Any suppression across a changed signature is a blocker.


## Corrective refinement after contiguous audit

A first implementation correctly suppressed repeats only when the complete semantic signature was unchanged. A stricter independent check then found an unacceptable remaining case: the generic NONE_IDENTIFIED WhyNow sentence could remain visible for 4–6 consecutive plies while Intent/evidence changed. Full-explanation suppression correctly reset, but the WhyNow field itself remained mechanically repetitive.

The refined policy therefore adds **field-level generic WhyNow de-duplication**. When the complete semantic signature changes, the new conclusion/evidence remains visible (the reset requirement is preserved), but if the immediately preceding raw WhyNow is the exact same NONE_IDENTIFIED fallback, only that redundant WhyNow field is omitted. The raw grounded WhyNow remains stored for diagnostics.

This is presentation-only and does not invent or modify semantic content.
