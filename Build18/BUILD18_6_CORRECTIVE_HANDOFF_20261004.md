# Build18-6R1 — Explanation Repetition Corrective Implementation

Reference date: 2026-10-04

Start a NEW PRODUCTION / CORRECTIVE IMPLEMENTATION CHAT.

Build18-6 result: **FAIL — CORRECTIVE IMPLEMENTATION REQUIRED**.

## Defect

Real-game contiguous audit found major repeated explanation output.

- 840 contiguous real-game positions audited
- true consecutive exact full-explanation repeats: 155
- true consecutive exact WhyNow repeats: 220
- maximum repeated run: 11 consecutive plies
- semantic false-explanation blockers: 0

Typical repeated output is the safe unresolved/NONE_IDENTIFIED fallback. The safety behavior is correct; the UX repetition is not.

## Corrective objective

Reduce repeated coaching text **without weakening evidence discipline**.

Missing remains safer than wrong.

Do not create textual variety by inventing:

- purpose
- opponent plan
- opening name
- mate / threatmate
- specialized Concept
- unsupported WhyNow causality

## Protected behavior

Do not change unless independently justified by a newly discovered defect:

- MoveIntent
- ContextIntentResolver
- Intent score
- evidence weight
- confidence threshold
- Build18-2 frozen labels
- Build18-5A HOLD decisions
- safe Concept semantics

## Preferred correction boundary

Correct the explanation presentation/repetition policy only.

Acceptable approaches include:

- suppressing duplicate WhyNow on immediately adjacent moves when no new evidence exists;
- replacing repeated full fallback text with a shorter continuity indication after the first occurrence;
- surfacing a new move-specific FACT / CONTEXT_CHANGE only when already present in evidence;
- resetting suppression immediately when trigger, confidence, selected Intent, evidence, or observable change materially changes.

Do not rewrite a missing-evidence case into an asserted purpose.

## Required revalidation

After correction:

1. dedicated unit tests for repetition policy;
2. Build16-R1 regression;
3. Build17 A/B/C;
4. Build18-3 Grounded WhyNow tests;
5. Build18-2 360 frozen corpus regression;
6. 100-position Pilot;
7. 300-position Mid Audit;
8. 600+ deterministic Full E2E;
9. 600+ contiguous repetition audit;
10. full Human Semantic Review;
11. Device / Simulator / Simulator E2E.

PASS requires semantic blockers = 0 **and** major repetition failures = 0.

Do not merge to main. Build18-M remains blocked until Build18-6 independent revalidation passes.
