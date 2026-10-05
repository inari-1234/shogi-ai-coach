# Build18-6R1 Corrective Design — 2026-10-05

## Scope

Build18-6 found a presentation-quality blocker: safe fallback / WhyNow text repeated across true consecutive plies. Semantic blocker counts were zero. Build18-6R1 therefore changes only Explanation Presentation / Repetition Policy.

The following remain unchanged: MoveIntent, ContextIntentResolver, intent scoring, evidence weights, confidence thresholds, GroundedExplanationContext semantics, Build17 Concept semantics, Build18-2 Frozen Diagnostic Corpus labels, and Build18-5A HOLD decisions.

## Authority rule

Missing is safer than wrong.

Repetition is never reduced by inventing a purpose, opponent plan, opening interpretation, mate/threatmate, future continuation, Concept, or WhyNow causality.

## Separation of semantic result and presentation

ContextExplanationGenerator and GroundedExplanationProjector continue to produce the semantic result. ContextExplanationRepetitionState receives that result afterward and decides only what should be displayed.

Both raw semantic explanation and displayed explanation are retained in diagnostic/audit output.

## Semantic repetition signature

A consecutive explanation is equivalent only when all material presentation inputs remain unchanged: selected Intent; Confidence; WhyNow trigger/authority; source evidence/signals; selected-Intent supporting evidence including ID/kind/weight/detail; observable FACT except naturally changing current/previous move identifiers; CONTEXT_CHANGE; grounded observed change; previous-move identity when causality is asserted; forcing markers; and unsuppressed safe Concept candidate.

Any change resets full-explanation suppression.

## Full-explanation state machine

- First occurrence: STANDARD — show the existing safe semantic explanation.
- Second identical semantic signature: CONTINUITY — show one short continuity statement and do not repeat the same WhyNow field.
- Third and later identical semantic signature: SUPPRESSED_DUPLICATE — omit the duplicate explanation display.
- Any semantic-signature change immediately returns the explanation to STANDARD.

This preserves the required T2/T3/T4/T5/T6 reset contract.

## Generic WhyNow visible-run hard cap

A separate presentation-only guard handles the case where the full semantic signature changes but the raw NONE_IDENTIFIED fallback WhyNow sentence remains textually identical.

A reset still returns to STANDARD and the new conclusion/evidence remains visible. The generic WhyNow field may be shown for at most three true consecutive plies. If a fourth identical visible generic WhyNow would occur, only that WhyNow field is omitted for that ply.

The presentation remains STANDARD; diagnostics record whyNowSuppressedAsRepeatedGeneric=true; the raw grounded WhyNow remains unchanged and auditable. The omission breaks the visible run, so a later reset may show the fallback again.

This field-level cap satisfies the hard gate without weakening reset semantics or inventing new meaning.

## Audit invariants

A field-level WhyNow omission is valid only when: the ply is truly consecutive; mode is STANDARD; the semantic signature changed; trigger is NONE_IDENTIFIED; current raw WhyNow equals preceding raw WhyNow; preceding visible exact WhyNow run length is exactly three; current displayed WhyNow is empty; and current displayed conclusion remains present.

Any violation is a blocker.
