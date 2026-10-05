# Build19-2 Sequence / Counterfactual Evidence — Architecture

Date: 2026-10-05

## Authority

- Build18: COMPLETE / FROZEN ON MAIN
- Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build19-1 authority: `candidate/build19-1-candidate-comparison-core` @ `07fac474b723d35d49093adce5e5e886acf600da`
- Build19-2 branch: `candidate/build19-2-sequence-counterfactual-evidence`

Build19-2 is a read-only sidecar over Build19-1 `CandidateComparison`. It does not rerank or rewrite MoveIntent, IntentCandidate, ContextIntentResolver, ContextConfidence, Build18 explanation policy, Frozen Corpus, or HOLD concepts.

## Responsibility

Build19-2 turns candidate-local PV lines into typed, board-reconstructed sequence evidence:

`CandidateComparison`
→ `CandidateSequenceEvidence(A/B)`
→ `stableHorizonPly`
→ `SequenceDifferencePoint`
→ `ObservedOpponentConsequence`
→ `SequenceExchangeEventEvidence`
→ `FutureDifferenceResolution`
→ `CounterfactualBranchTimeline`

Natural-language coaching remains outside this stage.

## Reconstruction vs Stability

Two concepts are deliberately separate:

1. **Reconstruction validity** — can each USI move be legally applied to the reconstructed board?
2. **Explanation stability** — is that reconstructed ply within a comparison/continuation-stable horizon?

A PV can therefore be reconstructed farther than it is safe to verbalize. `withinStableHorizon` and `safeToVerbalize` preserve this boundary.

Rules:

- comparison unstable → stable horizon 0
- candidate comparison stable but continuation unstable → only candidate first move is stable
- comparison + continuation stable → reconstructed PV is usable up to the common A/B reconstructed horizon
- invalid later PV move → truncate with diagnostic warning; never crash and never infer beyond the failure

## First Difference Timing

Build19-2 does **not** treat the trivial fact that Candidate A's first move string differs from Candidate B's first move as a useful grounded reason.

The first grounded consequence difference is the earliest stable ply with a concrete typed difference such as:

- capture
- promotion
- check
- drop
- material ownership inventory
- opponent PV reply difference
- later PV continuation difference

This avoids the tautology `A differs from B because A is a different move`.

## Opponent Consequences

Opponent reply/continuation events can be recorded when observed in the stable PV:

- capture
- check
- promotion
- drop
- local recapture

Every such event carries the limitation that a PV observation is not an exhaustive move tree and is not automatically proven forced.

Build19-2 therefore supports statements equivalent to `the analyzed A line contains an opponent capture at ply 2`, but not `A necessarily allows only this reply` unless a later stage supplies an independent forcing proof.

## Exchange Consequence

Exchange evidence is split into two dimensions:

- net material/ownership inventory at the stable horizon
- concrete capture/recapture event sequence within the stable horizon

This distinction is required because an equal-value exchange can return ownership counts to an equal total while the exchange itself remains an important branch difference.

`SequenceExchangeEventEvidence` therefore preserves capture/recapture events even when net material delta is zero.

## Counterfactual Timeline

Each candidate receives a typed timeline with:

- ply
- role
- move
- capture
- promotion
- check
- recapture
- material signature
- stable-horizon flag

Reality status is explicit:

- `ACTUAL`
- `COUNTERFACTUAL`
- `ANALYSIS_BRANCH`

For Best-vs-Actual, the actual branch remains `ACTUAL` and the unplayed recommended branch is `COUNTERFACTUAL`.

## Future Difference Resolution

Build19-1 `FutureDifferenceCandidate` placeholders are resolved into:

- `RESOLVED`
- `NOT_OBSERVED_WITHIN_STABLE_HORIZON`
- `UNRESOLVED_UNSTABLE`
- `RECONSTRUCTION_UNAVAILABLE`

No unresolved future difference is silently upgraded into a claim.

## Causal Boundary

Build19-2 describes grounded branch differences, not the complete hidden cause of the engine score gap.

In particular:

- observed PV event ≠ proven unique forced reply
- sequence correlation ≠ full engine causality
- equal net material ≠ no exchange occurred
- score gap magnitude ≠ sequence confidence
- reconstructed unstable continuation ≠ safe explanation evidence

## Diagnostics

Structured diagnostic types retain sequence and exchange evidence as data rather than prose. The diagnostic surface includes:

- comparison ID
- stable horizon
- per-branch reconstruction status
- per-ply role/move/capture/promotion/check/recapture/material/stability
- first grounded difference
- all sequence differences
- opponent consequences
- future-difference resolutions
- exchange-event diagnostic
- warnings / limitations

## Entry to Build19-3

Build19-2 is designed to feed later comparison-confidence and explanation policy without changing Build18 intent authority. The next stage may combine Build19-1 comparison signals and Build19-2 sequence signals, but must continue to distinguish engine stability, evidence availability, causal strength, and explanation confidence.
