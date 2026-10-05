# BUILD19_P_ROADMAP_20261005

## 1. Build19 objective

Evolve the coach from grounded single-move explanation to grounded pairwise coaching:

```text
Candidate Comparison
→ Sequence Evidence
→ Counterfactual
→ Comparison Confidence
→ Coaching Explanation
```

Build18 remains frozen authority and must stay regression-safe.

## 2. Recommended stage split

### Build19-1A — Comparison Data Contract / Pairwise Engine Normalization

Scope:

- CandidateAnalysis contract
- arbitrary A-vs-B pair selection
- same-condition pairwise engine evidence
- cp/mate score-domain rules
- provenance IDs
- no natural-language coaching yet

Exit:

- deterministic pairwise fixtures;
- unstable/inverted comparisons safely withheld;
- no change to MoveIntent/ContextIntentResolver.

### Build19-1B — DifferenceEvidence Core

Scope:

- SharedEvidence
- immediate A/B DifferenceEvidence
- immediate axes: capture/check/promotion/material inventory/king metrics
- causal strength `DIRECT_CONSEQUENCE`
- dominant-difference selection only for immediate evidence

Exit:

- A/B factual differences are typed and traceable;
- score gap never creates a reason.

**Build19-1 = Candidate Comparison Core**

---

### Build19-2A — SequenceEvidence / Stable Horizon

Scope:

- structured PV step evidence;
- BoardSnapshot/MoveEffect checkpoints;
- stable-through-relative-ply tracking;
- opponent-reply and own-continuation horizons;
- exchange/recapture chains.

Exit:

- future claims stop at the stable horizon;
- PV is never treated as certain future.

### Build19-2B — Counterfactual Difference Timeline

Scope:

- align candidate branches by relative horizon;
- future DifferenceEvidence;
- `REPLY_LINKED` / `SEQUENCE_CORRELATED`;
- CounterfactualExplanation contract.

Exit:

- “別の手なら何が起きるか” can be answered conditionally and traceably.

**Build19-2 = Sequence / Counterfactual Evidence**

---

### Build19-3A — ComparisonConfidence

Scope:

- independent HIGH/MEDIUM/LOW/UNRESOLVED;
- evidence gates;
- claim-level confidence;
- unsupported-axis handling.

Exit:

- large score gap cannot manufacture confidence;
- unstable sequence degrades only claims that depend on it.

### Build19-3B — Coaching Explanation Integration

Scope:

- beginner compression:
  1. conclusion
  2. biggest difference
  3. when/how the difference appears
  4. optional caveat
- explanation repetition integration;
- UI-facing data only as necessary, without redesign.

Exit:

- no PV dump;
- no ungrounded initiative/tempo/practical wording;
- no false causal wording.

**Build19-3 = Coaching Explanation Integration**

---

### Build19-4 — HOLD Concept Re-evaluation

Re-evaluate only after Build19-1 through 3 are frozen candidates.

Still requires independent positive/negative semantic authority.

Targets:

- `respond_to_rapid_attack`
- `sabai`
- `trade_to_transform`
- `multi_threat`
- `tempo_management`

No automatic promotion from the existence of SequenceEvidence.

---

### Build19-V — Independent Real-game / Semantic Validation

Minimum validation:

- frozen Build18 regression;
- pairwise comparison fixtures;
- counterfactual false-explanation audit;
- at least 30 real-game review positions, including the Build19-P gap categories;
- forcing / exchange / quiet / unresolved coverage;
- HIGH/MEDIUM/LOW/UNRESOLVED cases;
- human semantic review;
- beginner readability review;
- repetition review.

Blockers:

- score-only reason generation;
- PV certainty wording;
- causal wording on SEQUENCE_CORRELATED evidence;
- shared fact incorrectly selected as a difference;
- HOLD concept leakage;
- Build18 regression.

---

### Build19-M — Main Integration / Final Regression

Scope:

- integrate only frozen Build19 candidate;
- full unit/regression;
- iOS simulator/device build path;
- Build18 safety regression;
- final artifact/evidence bundle.

## 3. Build19-1 Entry Criteria

Build19-1 may start only when all are true:

1. Build18 authority remains `c1316508fad4c5bd2fa9e8728bcee42cba7d0d73` or a documented non-semantic successor.
2. Build19-P is parent-accepted as `PASS — PLANNING COMPLETE / IMPLEMENTATION READY`.
3. CandidateAnalysis / CandidateComparison / DifferenceEvidence responsibilities are frozen.
4. Comparison axis whitelist is frozen.
5. Equal-condition pairwise engine contract is accepted.
6. cp/mate score-domain policy is accepted.
7. Sequence horizons and causal-strength vocabulary are accepted.
8. ComparisonConfidence remains independent of ContextConfidence.
9. The five HOLD Concepts remain HOLD.
10. Production scope explicitly excludes UI redesign, engine replacement, and frozen corpus rewrite.

## 4. Build19-1 Non-goals

- no new MoveIntent;
- no ContextIntentResolver weight changes;
- no HOLD concept implementation;
- no “practical complexity” model;
- no generic initiative/tempo labels;
- no free-form LLM reason completion;
- no UI redesign.

## 5. Regression strategy

Every Build19 stage must retain:

- Build18 GroundedExplanation tests;
- Build18 frozen corpus projection tests;
- Build17 safe concept tests;
- Build18 repetition policy behavior;
- existing comparison stability behavior.

New tests should be additive.

## 6. Migration strategy

Do not rewrite all existing iOS analysis code in one stage.

Recommended migration:

1. preserve AdaptiveComparisonAnalyzer behavior;
2. introduce reusable core contracts;
3. adapt Deep/Reason/Continuation paths to emit/consume new contracts;
4. compare old and new outputs on fixed fixtures;
5. retire duplicate heuristic reason logic only after semantic parity/safety is proven.

## 7. Roadmap result

Build19 should begin with **Build19-1A**, then Build19-1B.

The formal next major stage remains:

**Build19-1 — Candidate Comparison Core**

**ROADMAP: IMPLEMENTATION READY**
