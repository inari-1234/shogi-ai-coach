# Build19-1 Candidate Comparison Core — Architecture

Date: 2026-10-05

## Authority

- Build18 is COMPLETE / FROZEN ON MAIN.
- Frozen Build18-M authority HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`.
- Build19-P planning authority: `candidate/build19-p-gap-audit` @ `1ff3ce4196ce7d5f88cda9a1aadebf53bc15f215`.
- Build19-1 implementation branch: `candidate/build19-1-candidate-comparison-core`.

Build19-1 is a read-only sidecar over existing analysis. It does not change MoveIntent, ContextIntentResolver, intent scores, evidence weights, ContextConfidence thresholds, GroundedExplanation policy, WhyNow, concept detectors, Frozen Corpus, HOLD decisions, or repetition policy.

## Production boundary

The new production-core path is:

`CandidateAnalysisResolver`
→ `CandidateAnalysis`
→ `CandidateComparisonResolver`
→ `SharedEvidence` / `DifferenceEvidence`
→ `CandidateComparison`
→ `ComparisonConfidenceSignals`
→ `CandidateComparisonDiagnostic`

Existing iOS ViewModel types are not authority types. Existing `AdaptiveComparisonAnalyzer`, `ReasonAnalysis`, and `ContinuationSimulation` remain sources of engine/stability/UX behavior only; Build19 authority lives in `ShogiCoachCore` typed contracts.

## Reuse

Build19-1 reuses existing Core `BoardSnapshotResolver`, `MoveEffectResolver`, `USIScore`, and existing defined board metrics. The check and king-zone metric algorithms previously used by continuation analysis are exposed in the Core `BoardTacticalMetricResolver`; no new strategic heuristic is introduced.

`CandidateAnalysisResolver` normalizes one engine candidate from a position, move, typed score, candidate-specific PV, engine/search context, stability flags, and branch metadata. PV[0] must equal the candidate move; otherwise comparison and continuation stability are forced false.

## Pairwise unit and same-condition normalization

Formal comparison unit is A vs B. `CandidatePairKind` supports `TOP1_VS_TOP2`, `BEST_VS_ACTUAL`, and future custom pairings.

A comparison is stable only when both candidates are individually stable and all of the following match:

- position command,
- engine context ID,
- search condition ID,
- score perspective,
- requested movetime,
- requested depth,
- candidate-specific PV first move.

A mismatch is retained as an auditable warning and suppresses `dominantDifferenceCandidate` rather than being silently normalized.

Engine comparison stability and explanation confidence remain separate. Build19-1 emits only confidence signals; final ComparisonConfidence policy remains Build19-3A responsibility.

## Evidence model

Shared facts are emitted as `SharedEvidence` and are never emitted as a difference reason. Current shared events include matching capture, promotion, check, and drop facts where applicable.

Observed differences are typed `DifferenceEvidence`. Each record carries:

- ID and kind,
- A/B values,
- source evidence IDs and source moves,
- horizon,
- causal strength,
- `safeToVerbalize`,
- explicit limitations.

`causalStrength` describes how directly the *observed difference* follows from the compared branch evidence. It does **not** mean the evidence fully explains the engine score gap. Score evidence is always `UNRESOLVED` as a causal reason. Check and other direct board facts contain explicit limitations forbidding conversion into claims such as “A is 120cp better because it checks.”

If a score gap is present but no grounded non-score causal difference can be established, the comparison emits `NO_GROUNDED_CAUSAL_DIFFERENCE`.

## Immediate vs future boundary

Build19-1 resolves the first candidate move and may inspect the first opponent PV reply as a concrete preview. This supports immediate recapture guarding and typed opponent-reply/exchange evidence.

It does not perform general PV semantic interpretation. Anything requiring aligned continuation, first-difference timing, stable horizon, net multi-ply exchange evaluation, or a counterfactual timeline is emitted as `FutureDifferenceCandidate` and deferred to Build19-2.

An immediate material/capture observation is downgraded to `UNRESOLVED` as a causal reason when the first opponent reply immediately recaptures the moved piece. This prevents a transient snapshot from being presented as a simple material advantage.

## Grounded axes

Implemented grounded comparison axes are:

- evaluation / mate-state category,
- capture,
- material inventory,
- promotion,
- check,
- defined king-zone pressure/defender metrics,
- immediate exchange consequence,
- first opponent reply event,
- drop/board effect,
- typed sequence-event placeholder.

Initiative, tempo, activity, future attack/defense burden, and continuation quality are guarded concepts and are not generated as raw claims. Move flexibility, risk, practical complexity, human ease, “easy to play”, “practical”, and “easy to win” remain deferred and unsupported.

Default comparison requests only grounded axes. Unsupported axes are recorded only when they are explicitly requested.

## Dominant difference

A dominant candidate may be selected only from stable, safe-to-verbalize, non-score, resolved evidence. Current priority favors categorical mate state and concrete tactical/exchange/material facts over softer board metrics. The selection is a candidate for later explanation, not a claim that one evidence item explains the entire engine evaluation gap.

No dominant difference is returned for an unstable comparison.

## Isolation from Build18

The Build19-1 CI scope guard rejects any production-core change outside the newly introduced comparison files and separately asserts no changes to Build18 authority files. It also asserts all five HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

No Build19 comparison is wired into existing explanation rendering or UI output in this stage.

## Diagnostics

`CandidateComparisonDiagnostic` is Codable JSON authority for audit/export. It records the position, A/B identity/rank/move/score/kind/PV/branch/stability, shared evidence, each difference with source IDs and moves, horizon, causal strength, limitations, future-difference candidates, unsupported claims, warnings, and dominant difference ID.

Natural language is not the only retained representation.

## Build19-2 entry

Build19-2 can consume `CandidateAnalysis`, `FutureDifferenceCandidate`, typed opponent-reply evidence, branch metadata, and stability signals without changing Build18 intent authority. It owns sequence reconstruction, stable horizon, first-difference timing, future differences, what the alternative allows, net exchange consequences, and counterfactual timeline generation.
