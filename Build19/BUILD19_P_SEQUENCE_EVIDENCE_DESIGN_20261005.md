# BUILD19_P_SEQUENCE_EVIDENCE_DESIGN_20261005

## 1. Purpose

Engine PV is not an explanation.

SequenceEvidence transforms a short, sufficiently stable engine continuation into a traceable set of observable events and checkpoint states that can be compared across candidates.

## 2. Source hierarchy

SequenceEvidence may use:

1. pairwise engine line and stability metadata;
2. BoardSnapshot before/after each PV move;
3. MoveEffect for each PV move;
4. explicit engine-verified mate/threatmate state;
5. existing grounded single-move evidence.

It must not use free-form language generation as evidence.

## 3. Sequence checkpoints

Each candidate sequence is projected into relative checkpoints.

```text
H0  common position before candidate
H1  after candidate move
H2  after opponent reply
H3  after original side continuation
H4+ subsequent short-horizon plies
```

Comparison is by **relative horizon and semantic features**, not by expecting both branches to contain the same moves or squares.

## 4. Per-ply event record

Conceptual `SequenceStepEvidence`:

```text
- stepID
- relativePly
- move
- side
- snapshotBeforeID
- snapshotAfterID
- capture?
- capturedPiece?
- drop?
- promotion?
- givesCheck?
- mateState?
- materialInventoryChange
- kingStateChange
- kingZoneMetricChange
- movedPieceControlChange
- source = PV_OBSERVED / ENGINE_VERIFIED
```

Every later natural-language claim must point back to one or more step IDs.

## 5. Checkpoint features

Initial Build19 feature whitelist:

### Exact board facts

- side to move
- king square
- in-check state
- piece inventory on board
- pieces in hand
- capture / recapture chain
- promotion
- drop
- move destination

### Defined board metrics

- king escape-square count
- king-zone attacked-square count
- king-zone friendly control count
- moved-piece legal/control reach where already supported
- optional major-piece control metrics if separately tested

### Engine states

- cp/mate score
- stable comparison flag
- stable continuation horizon
- verified mate / threatmate flags where available

## 6. Material design

“Material” is initially represented as an inventory/event delta, not an invented universal point score.

Safe:

- “A側では銀を取り、2手後まで取り返されていません。”
- “AもBも歩を1枚取るため、この駒取りは差ではありません。”

Unsafe without an approved valuation model:

- “銀=500点だからAが500点得.”
- “material +3.2” from an undocumented local scale.

## 7. Sequence stability

Comparison stability and continuation stability remain separate.

### `comparisonStable`

May authorize:
- candidate ordering;
- same-condition score gap.

Does not authorize:
- a future PV explanation.

### `continuationStable`

May authorize sequence claims only to a verified horizon.

Build19 should track:

```text
stableThroughRelativePly: Int?
```

If the PV is stable through H2 but changes afterward:

- H1/H2 claims may be used;
- H3+ claims are omitted;
- ComparisonConfidence is degraded only for claims requiring H3+.

This is more precise than treating the entire continuation as one boolean.

## 8. PV prefix confirmation

The existing adaptive analyzer already detects some PV-prefix changes.

Build19-2 should generalize this into explicit per-candidate prefix evidence:

- same pair;
- repeated/adaptive analysis attempt;
- compare prefixes at each relative ply;
- record stable-through horizon.

A longer PV is not inherently a more reliable explanation.

## 9. Difference timing

Every DifferenceEvidence must identify its first supported horizon:

- `IMMEDIATE`
- `OPPONENT_REPLY`
- `OWN_CONTINUATION`
- `SHORT_HORIZON`

This directly answers the user's question:

> “今すぐ差が出るのか、後で差が出るのか？”

## 10. Opponent reply semantics

A single PV opponent reply is:

- `PV_OBSERVED_REPLY`

It is **not automatically**:

- forced;
- the only move;
- evidence of low flexibility;
- evidence of multi-threat.

A reply may be described as forced only when the forcing condition is independently established, for example:

- legal response to check;
- verified mate constraint;
- future branch-analysis extension that proves response restriction.

## 11. Exchange sequences

SequenceEvidence must explicitly detect:

- capture;
- immediate recapture;
- delayed recapture inside stable horizon;
- exchange completion;
- post-exchange board/hand inventory;
- post-exchange king/pressure metrics.

This prevents the common false explanation:

> “A takes a piece, therefore A is better”

when the piece is immediately recaptured.

## 12. Future attack / defense

Build19 may state concrete future events:

- additional check;
- capture;
- forced defensive reply;
- increased/decreased defined king-zone pressure;
- explicit attack on a piece.

It may not automatically state:

- “attack continues”;
- “defense becomes difficult”;
- “initiative is retained.”

Those strategic summaries require their own grounded evidence policy.

## 13. Counterfactual branch design

`CounterfactualExplanation` compares actual branch and alternative branch.

Contract:

```text
- actualCandidateID
- alternativeCandidateID
- sharedStartPosition
- claimedThroughHorizon
- branchAEvents[]
- branchBEvents[]
- firstDifferenceID
- futureDifferenceIDs[]
- confidence
- wordingMode
```

Required language:

- “この探索条件のPVでは…”
- “Bを選んだ場合の読み筋では…”
- “2手後の時点では…”

Forbidden certainty:

- “必ず…”
- “確実に…”
- “相手は絶対に…”

unless the evidence is a formally verified forced mate/forced legal sequence.

## 14. Sequence-derived causal strength

### Direct consequence

Difference appears at H1 and is mechanically caused by candidate choice.

Examples:
- check vs no check;
- capture vs no capture;
- promotion vs no promotion.

### Reply-linked

Difference appears at H2 and is tied to the stable opponent reply.

Examples:
- B permits immediate capture;
- A forces a recapture sequence that B does not.

### Sequence-correlated

Difference first appears at H3+.

It may support:
- “A側では3手後に…という差が現れる.”

It does not by itself support:
- “Aが良いのはそのため.”

## 15. SequenceEvidence result

Existing PV reconstruction is sufficient as a technical base, but Build19 needs:

- stable-horizon tracking;
- explicit semantic checkpoints;
- A/B delta extraction;
- causal-strength labels;
- conditional counterfactual wording.

**SEQUENCE EVIDENCE DESIGN: READY**
