# Build19-3B Coaching Explanation Integration — Architecture

Date: 2026-10-05

## Purpose

Build19-3B converts only upstream-authorized comparison evidence into beginner-facing coaching language. It is a read-only sidecar over Build19-1 CandidateComparison, Build19-2 SequenceComparisonEvidence, and Build19-3A ComparisonConfidenceResult.

## Frozen authority

- Build18: COMPLETE / FROZEN ON MAIN
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-1 authority HEAD: `07fac474b723d35d49093adce5e5e886acf600da`
- Build19-2 authority HEAD: `701b50a319407c6d31f7aff684ab6af7e0c76626`
- Build19-3A authority HEAD: `d348eefccfe40f8f24ecfdb0e7aa64659f0bd060`
- Build19-3B validated production HEAD: `d60e2abf95e58a2e1e03f7b0d99753bca37170a7`

## Production files

- `Sources/ShogiCoachCore/ComparisonCoachingExplanation.swift`
- `Sources/ShogiCoachCore/ComparisonCoachingExplanationRepetition.swift`

## Pipeline

`CandidateComparison → SequenceComparisonEvidence → ComparisonConfidenceResult → CandidateComparisonCoachingExplanation → CoachingComparisonPresentation`

## Output structure

The semantic explanation contains:

1. conclusion/headline
2. primary grounded difference
3. optional alternative outcome
4. optional difference timing
5. optional opponent opportunity
6. optional exchange-after explanation
7. confidence note

The resolver never promotes a withheld claim into prose. `eligibleEvidenceIDs` and claim-level confidence remain the authority gate.

## Safety boundaries

- score gap is never used as a causal explanation
- `UNRESOLVED` safely abstains
- `SEQUENCE_CORRELATED` cannot become direct causal wording
- unstable future evidence is omitted without deleting unrelated stable immediate evidence
- observed engine PV replies are described as observations, not proven forced continuations
- unsupported axes are withheld
- HOLD concepts remain HOLD
- Build18 MoveIntent, ContextConfidence, GroundedExplanation and Frozen Corpus are not mutated

## Repetition integration

Repetition control is presentation-only. The full semantic explanation is generated first and retained unchanged.

Equivalent semantic shape is displayed as:

- occurrence 1: `STANDARD`
- occurrence 2: `CONTINUITY`
- occurrence 3+: `SUPPRESSED_DUPLICATE`

The repetition signature uses semantic shape rather than move text: pair kind, confidence, tone, branch framing, authorized evidence shape, visible section kinds, future-evidence shape and stable horizon.

Reset conditions include changed pair kind, comparison confidence, tone, framing, authorized evidence, visible section kind, or future-evidence shape. An explicit reset is also supported.

## UI boundary

Build19-3B exposes UI-facing typed data only. It does not redesign the existing interface and does not force the current UI to display every optional section.

## Exit criteria

- beginner compression: PASS
- no PV dump: PASS
- no score-only causal wording: PASS
- no unsupported initiative/tempo/practical wording: PASS
- no forced-PV overclaim: PASS
- semantic-preserving repetition integration: PASS
- prior Build19 and Build18 regression: PASS
- iOS build: PASS
