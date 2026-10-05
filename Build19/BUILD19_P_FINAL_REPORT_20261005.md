# BUILD19_P_FINAL_REPORT_20261005

## Final verdict

# Build19-P
# PASS — PLANNING COMPLETE / IMPLEMENTATION READY

Date: 2026-10-05  
Repository: `inari-1234/shogi-ai-coach`  
Planning branch: `candidate/build19-p-gap-audit`

## 1. Authority fixed

Build18 remains:

**COMPLETE / FROZEN ON MAIN**

Authority HEAD:

`c1316508fad4c5bd2fa9e8728bcee42cba7d0d73`

Build18-M Final Regression Run `37260421183` completed successfully.

No Build19-P Production Code changes were made.

## 2. Maximum Gap

The current coach can safely explain one move, but it lacks a first-class grounded structure for:

- comparing candidate A and B;
- separating shared facts from actual differences;
- identifying when the difference appears;
- connecting a stable short sequence to the comparison;
- explaining an alternative branch conditionally;
- expressing confidence in the **reason for the comparison**.

The core Build19 problem is therefore not “obtain more PV” or “show a larger score delta.”

It is:

> **turn pairwise engine/board evidence into a traceable DifferenceEvidence model without weakening Build18 safety.**

## 3. Real-game Gap Audit result

Build19-P audited 30 positions from the formal Build18-6R1 Human Semantic Review candidate set.

Coverage:

- ENDGAME 11
- OPENING 10
- MIDDLEGAME 9
- HIGH 5
- MEDIUM 14
- LOW 1
- UNRESOLVED 10
- DIRECT_PREVIOUS_MOVE 7
- EXCHANGE_SEQUENCE 6
- FORCING_TACTIC 5
- NONE_IDENTIFIED 12

Repeated next-user needs were:

1. Why not the second candidate?
2. What specifically differs?
3. When does the difference appear?
4. What does the alternative allow?
5. How certain is that explanation?

## 4. Architecture decision

Preserve the Build18 single-move path.

Add a pairwise sidecar:

```text
CandidateAnalysis(A/B)
→ SequenceEvidence
→ DifferenceEvidence
→ CandidateComparison
→ ComparisonConfidence
→ CounterfactualExplanation
→ Coaching Explanation
```

No comparison evidence is allowed to silently re-rank MoveIntent or overwrite ContextConfidence.

## 5. Grounded / Unsupported boundary

Initial grounded axes:

- equal-condition evaluation comparison;
- capture / recapture;
- promotion;
- check / mate state;
- material inventory/event delta;
- exchange consequence;
- defined king safety metrics;
- opponent reply events;
- short-horizon concrete sequence differences.

Guarded/proxy only:

- initiative;
- tempo;
- activity;
- future attack/defense;
- continuation quality.

Deferred:

- move flexibility;
- risk;
- practical complexity;
- “実戦的に扱いやすい”.

Evaluation difference alone is never the explanation.

## 6. Sequence decision

PV is evidence input, not prose.

Build19 will:

- reconstruct short candidate sequences;
- align them by relative horizon;
- identify first difference timing;
- track stable-through horizon;
- classify causal strength:
  - DIRECT_CONSEQUENCE
  - REPLY_LINKED
  - SEQUENCE_CORRELATED

Future claims stop when stable sequence evidence stops.

## 7. Counterfactual decision

Counterfactual is allowed as a conditional branch only.

Safe form:

> “Bを選んだ場合の、この探索条件のPVでは…”

No deterministic future language unless formally forced.

## 8. Comparison Confidence decision

Add independent:

- HIGH
- MEDIUM
- LOW
- UNRESOLVED

ComparisonConfidence measures the grounding of the A-vs-B explanation, not MoveIntent confidence and not score magnitude.

A large cp difference cannot produce HIGH by itself.

## 9. HOLD Concepts

Remain HOLD:

- respond_to_rapid_attack
- sabai
- trade_to_transform
- multi_threat
- tempo_management

Re-evaluation is deferred to Build19-4 after comparison and sequence evidence exist and have been validated.

## 10. Beginner explanation target

Final display should normally compress to:

1. conclusion;
2. largest grounded difference;
3. where that difference appears in the next few plies;
4. optional uncertainty / evaluation note.

Example structure:

> Aを優先します。  
> 一番大きな違いは、Aだけが王手になり相手の次の手を制限できる点です。  
> BのPVでは次の手でこちらの銀を取られていますが、A側ではその駒取りがありません。  
> 評価差の全てをこの一点だけで説明できるとは限りません。

The exact text must be generated from evidence, not from a template assumption.

## 11. Build19 roadmap

- Build19-1A — Comparison Data Contract / Pairwise Engine Normalization
- Build19-1B — DifferenceEvidence Core
- Build19-2A — SequenceEvidence / Stable Horizon
- Build19-2B — Counterfactual Difference Timeline
- Build19-3A — ComparisonConfidence
- Build19-3B — Coaching Explanation Integration
- Build19-4 — HOLD Concept Re-evaluation
- Build19-V — Independent Real-game / Semantic Validation
- Build19-M — Main Integration / Final Regression

Formal next major stage:

**Build19-1 — Candidate Comparison Core**

## 12. Completion-condition check

| Requirement | Result |
|---|---|
| Current maximum Gap clear | PASS |
| Candidate Comparison requirements clear | PASS |
| Sequence Evidence requirements clear | PASS |
| Counterfactual treatment clear | PASS |
| Comparison Confidence design clear | PASS |
| Build18 architecture connection clear | PASS |
| Grounded / Unsupported boundary clear | PASS |
| HOLD Concept treatment clear | PASS |
| Beginner final explanation form clear | PASS |
| Build19 stage split fixed | PASS |
| Build19-1 Entry Criteria fixed | PASS |
| Production Code unchanged | PASS |

## 13. Required artifacts

- `BUILD19_P_GAP_AUDIT_20261005.md`
- `BUILD19_P_CURRENT_ARCHITECTURE_ASSESSMENT_20261005.md`
- `BUILD19_P_CANDIDATE_COMPARISON_DESIGN_20261005.md`
- `BUILD19_P_SEQUENCE_EVIDENCE_DESIGN_20261005.md`
- `BUILD19_P_COMPARISON_CONFIDENCE_DESIGN_20261005.md`
- `BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json`
- `BUILD19_P_ROADMAP_20261005.md`
- `BUILD19_P_FINAL_REPORT_20261005.md`

## 14. Final decision

There is no remaining planning blocker that requires a HOLD.

**Build19-P: PASS — PLANNING COMPLETE / IMPLEMENTATION READY**

Next:

**Build19-1 — Candidate Comparison Core**
