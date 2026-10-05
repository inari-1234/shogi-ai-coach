# BUILD19_P_CANDIDATE_COMPARISON_DESIGN_20261005

## 1. Design objective

Create a grounded A-vs-B comparison that can answer:

- what differs;
- which difference matters;
- when the difference appears;
- what the alternative permits;
- how certain that explanation is.

The design must not infer a reason from engine score alone.

## 2. Candidate acquisition

### Discovery

Use MultiPV to discover top candidates.

Typical coaching pairs:

1. engine best vs user's actual move;
2. engine best vs runner-up;
3. user-selected candidate A vs B.

### Explanation-bearing comparison

Before producing a comparison explanation, re-analyze the exact pair under equal conditions:

- same position;
- same engine configuration;
- same time/depth policy;
- same score perspective;
- both moves constrained through the same pairwise search mechanism.

This prevents a difference in search conditions from being mistaken for a candidate difference.

## 3. Score-domain contract

`ScoreComparison` must preserve native score semantics.

### cp vs cp

- numeric delta allowed when pairwise comparison is stable;
- cp gap is preference evidence, not a causal reason.

### mate vs non-mate

- categorical difference only;
- safe statement: “Aでは同条件探索で詰みが確認され、Bでは同じ詰み評価が確認されていない.”
- never convert mate to an arbitrary cp number.

### mate vs mate

- preserve mate direction and distance semantics;
- do not use distance as a strategic reason without separate DifferenceEvidence.

### unstable/inverted comparison

- score reason state = UNRESOLVED;
- no evaluation-loss claim.

## 4. Proposed data responsibilities

### CandidateAnalysis

Conceptual contract:

```text
CandidateAnalysis
- candidateID
- move
- discoveryRank
- engineLine
- pairwiseScoreEvidence
- comparisonStable
- continuationStable
- moveContextAnalysis      // existing, read-only
- immediateEvidence[]
- sequenceEvidenceRef
- provenance[]
```

Rules:

- one candidate may be analyzed without comparing it to another;
- CandidateAnalysis never decides that it is “better”;
- selected MoveIntent and ContextConfidence remain untouched.

### CandidateComparison

```text
CandidateComparison
- comparisonID
- positionID
- candidateA
- candidateB
- scoreComparison
- sharedEvidence[]
- immediateDifferenceEvidence[]
- futureDifferenceEvidence[]
- dominantDifferenceID?
- comparisonConfidence
- counterfactualEligibility
- unsupportedAxes[]
```

CandidateComparison owns **difference semantics**, not single-candidate motive semantics.

## 5. Evidence partitions

### Candidate A Evidence

Facts that are true for A.

### Candidate B Evidence

Facts that are true for B.

### Shared Evidence

Facts true for both.

Critical rule:

> Shared evidence cannot explain why A is preferred to B.

Example: if both A and B give check, “A gives check” must not be selected as the differentiating reason.

### DifferenceEvidence

A factual or measured difference between A and B.

### FutureDifferenceEvidence

A difference that first becomes visible after the initial move, at an explicitly named stable horizon.

## 6. DifferenceEvidence contract

Conceptual fields:

```text
DifferenceEvidence
- id
- axis
- horizon
- candidateAValue
- candidateBValue
- direction
- sourceEvidenceIDs[]
- sourceSignalIDs[]
- sequenceStepIDs[]
- causalStrength
- comparisonState
- safeToVerbalize
- verbalizationMode
- unsupportedReason?
```

### `horizon`

- `IMMEDIATE` — after candidate move
- `OPPONENT_REPLY` — after the opponent's analyzed reply
- `OWN_CONTINUATION` — after the next move by the original side
- `SHORT_HORIZON` — later within the validated short sequence

### `causalStrength`

- `DIRECT_CONSEQUENCE`
- `REPLY_LINKED`
- `SEQUENCE_CORRELATED`

### `comparisonState`

- `DIFFERENT`
- `SHARED`
- `INCOMPARABLE`
- `UNRESOLVED`

## 7. Axis whitelist for Build19-1

Initial core should implement only axes with deterministic evidence contracts:

1. `EVALUATION`
2. `CAPTURE_EVENT`
3. `MATERIAL_INVENTORY`
4. `CHECK_STATE`
5. `MATE_STATE`
6. `PROMOTION_EVENT`
7. `EXCHANGE_EVENT`
8. `KING_DANGER_METRIC`
9. `KING_ESCAPE_SQUARES`
10. `KING_ZONE_PRESSURE`
11. `PIECE_CONTROL_OR_MOBILITY`
12. `OPPONENT_REPLY_EVENT`

Strategic labels are not core axes.

## 8. Derived coaching labels

A label such as “the alternative allows counterplay” may be emitted only after concrete DifferenceEvidence exists.

Examples:

### Safe direct difference

A gives check; B does not.

> Aは王手になるため、相手はまず王手への対応が必要です。Bではこの制約がありません。

### Safe reply-linked difference

Stable B branch: opponent captures a silver on the next reply. Stable A branch: no corresponding capture.

> Bを選んだPVでは、相手の次の手で銀を取られています。A側の同じ時点ではその駒取りはありません。

### Correlated future difference

At SHORT_HORIZON, A has lower king-zone danger than B, but no single cause is isolated.

> 3手先のPVでは、A側の方が自玉周辺への相手の利きが少ない形になっています。これが評価差の唯一の原因とまでは断定しません。

## 9. Dominant difference selection

A `dominantDifferenceID` may be selected only when:

1. difference is not Shared;
2. evidence is traceable;
3. claimed horizon is stable;
4. causal strength is DIRECT_CONSEQUENCE or REPLY_LINKED, **or**
5. no stronger reason exists and wording explicitly remains correlational;
6. it is compatible with score direction;
7. no equally plausible conflicting difference invalidates a single-cause statement.

Ranking heuristics may prioritize:

- mate/check/forced reply;
- concrete material swing not immediately neutralized;
- reply-linked tactical loss;
- king-danger change;
- other observable sequence differences.

But ranking priority does not create evidence.

## 10. “Why B is bad” rule

The system should not phrase a runner-up as objectively “bad” merely because it is second.

Safe categories:

- `ALTERNATIVE_NEAR_EQUAL`
- `ALTERNATIVE_HAS_CONCRETE_COST`
- `ALTERNATIVE_LOSES_FORCED_OPPORTUNITY`
- `ALTERNATIVE_REASON_UNRESOLVED`

Examples:

- “Bも大きく悪くはありませんが、Aだけが次の王手を残します。”
- “Bは評価が低いものの、短い読み筋だけでは理由を一つに絞れません。”

## 11. Candidate count and complexity

Build19 explanation is pairwise even if MultiPV returns 3+ candidates.

Default:

- compare A vs B;
- optionally show candidate C as rank/score only;
- do not generate all pair combinations automatically.

This keeps evidence and beginner presentation comprehensible.

## 12. Unsupported strategic terms

Until an explicit evidence contract exists, the following cannot be generated as an explanatory reason:

- “主導権”
- “テンポ”
- “攻めが続く”
- “実戦的”
- “扱いやすい”
- “柔軟”
- “リスクが低い”

A UI may later expose calibrated versions, but Build19 core must first record the underlying concrete differences.

## 13. Integration with Build18

CandidateAnalysis may contain the existing `MoveContextAnalysis`, but CandidateComparison must never:

- add evidence weight to ContextIntentResolver;
- change selectedIntent;
- change ContextConfidence;
- convert Effect to Intent;
- convert score gap to Intent;
- promote HOLD Concepts.

## 14. Candidate Comparison design result

The Build19 comparison core should be implemented as a **pairwise evidence sidecar** around the frozen Build18 single-move architecture.

**DESIGN STATUS: READY FOR BUILD19-1**
