# BUILD19_P_GAP_AUDIT_20261005

## 1. Authority

- Repository: `inari-1234/shogi-ai-coach`
- Audit date: 2026-10-05
- Build18 authority: **COMPLETE / FROZEN ON MAIN**
- Authority `main` HEAD: `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`
- Build18-M Final Regression: GitHub Actions Run `37260421183` — `success`
- Build18-M evidence artifact digest: `sha256:af7c2b2c9afc67463656b9ccd5659819088bd21ddfbc37dd22de7a8fd75df260`
- Build19-P branch: `candidate/build19-p-gap-audit`
- Production code changes in Build19-P: **0**

Build18 safety rules remain authoritative. In particular, Effect must not be promoted to Intent, engine score must not be converted into a causal explanation, and LOW / UNRESOLVED must not be strengthened merely because a candidate has a larger evaluation advantage.

## 2. Audit evidence

The audit used:

1. Build18 architecture and grounded-explanation contracts.
2. Current `main` source, including:
   - `Sources/ShogiCoachCore/ContextEngine.swift`
   - `Sources/ShogiCoachCore/GroundedExplanationContext.swift`
   - `iOS/ShogiCoachPoC/AdaptiveComparisonAnalyzer.swift`
   - `iOS/ShogiCoachPoC/DeepAnalysisViewModel.swift`
   - `iOS/ShogiCoachPoC/ReasonAnalysisViewModel.swift`
   - `iOS/ShogiCoachPoC/ContinuationSimulationViewModel.swift`
3. Build18-6R1 real-game evidence:
   - 12 games
   - 720 evaluated positions
   - 48 formal Human Semantic Review candidates
4. A deterministic Build19-P subset of **30 positions**, recorded in `BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json`.

The 30-position sample intentionally includes every LOW/UNRESOLVED review candidate, every DIRECT_PREVIOUS_MOVE review candidate, every EXCHANGE_SEQUENCE review candidate, every FORCING_TACTIC review candidate, plus one quiet/ambiguous control.

## 3. Current maximum Gap

### Build18 can answer

- What move was played.
- What concrete board effects occurred.
- Which already-resolved MoveIntent is supported.
- Why-now when a direct previous-move, forcing, or exchange signal is grounded.
- Whether the engine comparison / continuation is stable enough to avoid unsafe assertions.
- Whether a single tactical event is insufficient to explain the evaluation difference.

### Build18 cannot yet answer reliably

- **Why candidate A is better than candidate B.**
- Which facts are shared by both candidates and therefore **do not explain the difference**.
- Which factual difference first appears after A/B.
- Whether the important difference is immediate, appears after the opponent reply, or appears several plies later.
- Whether a PV event merely correlates with the evaluation gap or plausibly explains it.
- What the alternative candidate permits or loses, without turning one PV into a certain future.
- Whether “initiative”, “tempo”, “attack continues”, “practical”, or similar strategic labels are actually grounded.

The maximum Gap is therefore:

> **Build18 has a grounded single-move explanation model, but not a grounded pairwise difference model.**

This is the gap between “the engine prefers A” and “the user can understand why A should be chosen over B.”

## 4. Existing partial capability and why it is insufficient

### 4.1 Engine comparison already exists

`AdaptiveComparisonAnalyzer` already discovers MultiPV candidates and re-analyzes the best move and actual move under equal-condition `searchmoves`. It also separates:

- comparison stability
- continuation stability
- score-kind changes
- best-move changes
- loss swings
- short / changing PVs

This is valuable and should be reused.

However, it currently establishes **ranking and stability**, not the semantic reason for the ranking.

### 4.2 Reason analysis already avoids overclaiming

`ReasonAnalysisViewModel` already handles several safe cases:

- do not blame a move if comparison is unstable;
- do not invent a reason from positive cp loss alone;
- detect immediate capture / promotion differences;
- detect an opponent capture allowed in one route;
- recognize immediate recapture so “capture = material gain” is not falsely asserted.

This is a strong safety baseline, but the logic is ad hoc and limited to best-vs-actual special cases. It does not expose a reusable DifferenceEvidence contract.

### 4.3 Continuation simulation already reconstructs PV boards

`ContinuationSimulationViewModel` reconstructs BoardSnapshot / MoveEffect for PV plies and can observe:

- capture
- drop
- promotion
- check
- king location
- local king-zone attack / defense counts

But recommended and actual routes are largely summarized **independently**. A Build19 comparison must compare the routes against each other at aligned horizons rather than generate two separate narratives.

## 5. 30-position Real-game Gap Audit

Sample distribution:

| Dimension | Distribution |
|---|---|
| Phase | ENDGAME 11 / OPENING 10 / MIDDLEGAME 9 |
| Confidence | HIGH 5 / MEDIUM 14 / LOW 1 / UNRESOLVED 10 |
| WhyNow | NONE_IDENTIFIED 12 / DIRECT_PREVIOUS_MOVE 7 / EXCHANGE_SEQUENCE 6 / FORCING_TACTIC 5 |

Gap classes:

| Gap class | Count | Typical next user question |
|---|---:|---|
| Safe abstention without candidate contrast | 10 | “候補手を比べれば理由は分かる？” |
| Low-confidence single move without contrast | 1 | “別候補と比べると確信度は上がる？” |
| Previous-move response without alternative comparison | 7 | “別の応手だと何を許す？” |
| Exchange detected without net sequence comparison | 6 | “交換後に何が違う？” |
| Forcing fact without alternative forcing comparison | 5 | “王手だから良い、の先は？” |
| Quiet single-move intent without pairwise difference | 1 | “今の差か将来の差か？” |

The audit therefore supports five recurrent user needs:

1. **Why not the runner-up?**
2. **What is actually different between the two moves?**
3. **When does the difference appear?**
4. **What does the alternative allow the opponent to do?**
5. **How certain is the explanation of the difference, separately from the engine evaluation?**

## 6. Candidate-comparison axis audit

### Grounded for initial Build19 scope

| Axis | Initial status | Safe evidence |
|---|---|---|
| Evaluation difference | GROUNDED WITH GATE | Equal-condition engine score + stability |
| Immediate tactical gain | GROUNDED | capture / check / promotion / mate evidence |
| Material | GROUNDED AS INVENTORY/EVENT DELTA | captures, recaptures, hands, exchanges; do not invent piece-value weights |
| King safety | GROUNDED AS DEFINED METRICS | in-check state, escape squares, king-zone pressure/control |
| Threat | GROUNDED WHEN EXPLICIT | check, verified mate/threatmate, directly attacked piece |
| Opponent counterplay | PARTIAL | concrete reply capture/check/threat only; generic “counterplay” forbidden |
| Exchange consequence | GROUNDED | before/after exchange sequence and resulting board facts |
| Forced sequence | PARTIAL | check/mate/forced tactical facts; one PV alone does not prove uniqueness |
| Future attack | PARTIAL | concrete future checks/captures/attack-pressure deltas only |
| Future defense burden | PARTIAL | concrete required defensive replies / king-danger deltas only |

### Grounded only as proxy; strategic wording is gated

| Axis | Status | Boundary |
|---|---|---|
| Initiative | PROXY ONLY | may be stated only through explicit forcing/reply constraints; generic “主導権” forbidden |
| Tempo | PROXY ONLY / HOLD concept | requires verified move-order / timing counterfactual; generic “テンポ得” forbidden |
| Board activity | PROXY ONLY | control/mobility metrics may be shown; strategic value is not automatic |
| Piece activity | PROXY ONLY | mobility/control change is Effect, not Intent/value by itself |
| Continuation quality | PROXY ONLY | stability and concrete event profile, not a free-standing reason |

### Deferred from initial Build19 implementation

| Axis | Status | Reason |
|---|---|---|
| Move flexibility | DEFER | requires branch breadth / alternative-response analysis, not a single PV |
| Risk | DEFER | requires a defined probability/branching model or validated proxy |
| Practical complexity | DEFER | requires human/practical calibration beyond engine PV |
| “実戦的に扱いやすい” | DEFER | not grounded by evaluation score or one principal variation |

## 7. Required new reasoning boundary

Build19 must not feed candidate differences back into `ContextIntentResolver` by default.

The safe architecture is:

```text
Current Position
  ├─ Candidate A → existing MoveContextAnalysis (read-only)
  ├─ Candidate B → existing MoveContextAnalysis (read-only)
  ├─ Pairwise equal-condition engine comparison
  └─ Short stable sequences
          ↓
    SequenceEvidence
          ↓
    DifferenceEvidence
          ↓
    CandidateComparison
          ↓
    ComparisonConfidence
          ↓
    CounterfactualExplanation
          ↓
    Beginner Coaching Explanation
```

`DifferenceEvidence` explains **how A and B differ**. It must not silently create a new MoveIntent or override the existing confidence of either single-move analysis.

## 8. Causal language levels

Build19 needs an explicit causal-strength distinction.

1. **DIRECT_CONSEQUENCE**  
   The difference follows directly from the candidate move itself.  
   Example: A gives check and B does not.

2. **REPLY_LINKED**  
   The difference is observed through the opponent's stable reply and is directly tied to the candidate branch.  
   Example: B allows a capture on the next reply; A does not.

3. **SEQUENCE_CORRELATED**  
   A difference is visible later in a stable PV, but the available evidence does not isolate it as the sole cause of the engine preference.  
   Safe wording: “差が現れています.”  
   Unsafe wording: “これがAが良い理由です.”

Only levels 1–2 should normally authorize “because / 〜ため” causal wording.

## 9. Score is not a reason

Mandatory Build19 rule:

> Evaluation difference decides that candidates differ in engine preference. It does not decide why.

A large cp gap must not:
- promote ComparisonConfidence;
- create a strategic label;
- convert sequence correlation into causality;
- override an unstable or missing DifferenceEvidence layer.

Mate scores must remain in their native score domain; do not convert mate to cp.

## 10. Counterfactual boundary

Counterfactual explanations are allowed only as conditional engine branches.

Safe:
- “Bを選んだPVでは、相手の次の手で銀を取られています。”
- “この探索条件では、A側は2手後まで王手が続きます。”

Unsafe:
- “Bなら必ず銀を取られます。”
- “Aなら主導権を取れます。”

When continuation is unstable beyond the claimed horizon, future explanation must stop at the last stable checkpoint.

## 11. HOLD concepts

The five Build18-5A HOLD concepts remain HOLD:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

Candidate/sequence evidence may create better evidence for later re-evaluation, but Build19-P does **not** promote any of them.

Specific later gates:

- `trade_to_transform`: requires grounded exchange consequence plus post-exchange state differential and positive/negative corpus evidence.
- `multi_threat`: requires evidence that more than one independent threat exists; one PV is insufficient.
- `tempo_management`: requires verified sequence timing / move-order counterfactual evidence.
- `respond_to_rapid_attack`: requires a concept-specific definition and measurable prior attack progression.
- `sabai`: requires specialized semantic authority beyond generic exchange/activity facts.

## 12. Build19 requirements derived from the audit

Build19 implementation must provide:

1. arbitrary A-vs-B comparison contract, not only best-vs-actual;
2. equal-condition score comparison;
3. separate score-domain handling;
4. per-candidate structured immediate evidence;
5. stable, aligned short-sequence checkpoints;
6. SharedEvidence vs DifferenceEvidence separation;
7. Immediate vs Reply vs Future difference timing;
8. causal-strength labeling;
9. independent ComparisonConfidence;
10. Counterfactual wording rules;
11. beginner compression without losing provenance;
12. omission/UNRESOLVED behavior when a reason cannot be grounded.

## 13. Gap Audit conclusion

No architecture blocker remains at the planning level.

The existing engine, board, move-effect, single-move intent, and grounded explanation primitives are sufficient foundations. The missing capability is well-defined and can be added as a sidecar comparison layer without weakening Build18.

**GAP AUDIT: COMPLETE**
