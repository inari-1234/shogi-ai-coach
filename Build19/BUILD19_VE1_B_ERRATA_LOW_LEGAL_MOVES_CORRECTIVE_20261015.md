# Build19 VE1-B Errata #2 — Low-Legal-Move MultiPV Corrective

Date: 2026-10-15
Status: **PREREGISTERED / IMPLEMENTATION HOLD**
Frozen base Authority: `8daf78caa2bd5919cc911da21bae80fa3d12a248`
Branch: `candidate/build19-ve1-c1-pilot`

This corrective does **not** rewrite the frozen VE1-B Authority history. `8daf78c...` remains the frozen historical Authority and is corrected only by a new successor commit after every gate below passes.

## 1. Suspected defect

At the frozen base, `EngineUSISession.analyzePositionNodes` uses configured `currentMultiPV` directly as `requiredMultiPV`. `USICompletedIterationSelector` therefore requires ranks `1...requiredMultiPV` even when the root position has fewer search-root moves than the configured MultiPV.

For an unrestricted search with configured `MultiPV = 3`, a root with only one or two search-root moves can never emit all three ranks. Reaching the node budget can therefore end as `no_completed_exact_iteration` even when every root move that the engine actually searches has been completely represented.

This is treated as a product defect, not as a C1 threshold/semantic relaxation.

### 1.1 Frozen definition of `legalRootMoveCount`

For this corrective, **legal root move count means YaneuraOu's effective default search-root universe, not every rule-legal shogi move**.

Pinned engine: `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`.

With production/default `GenerateAllLegalMoves = false`:

- authority count: `MoveList<LEGAL>(position).size()`;
- `LEGAL_ALL` is not a valid substitute for the corrective count;
- the count must never be inferred from observed bounded-search MultiPV output.

The pinned generator deliberately omits some optional non-promotion variants from `LEGAL` that exist in `LEGAL_ALL`. The implementation-level distinction includes pawn non-promotion when the destination is in the promotion zone (the mandatory-promotion last rank is not legal in either universe), lance non-promotion to the second rank, and bishop/rook non-promotion whenever promotion is available from the origin or destination.

Any Swift-side reconstruction used for verification must reproduce this `LEGAL` omission behavior and must be checked against the engine's own `MoveList<LEGAL>` count.

## 2. Mandatory cause-confirmation gate

Before the production corrective is enabled, reproduce the failed C1 pool position (seed rank 2, ply 126) using the same pinned engine/NNUE/runtime contract and preserve raw USI.

The defect is **CONFIRMED** only if both are true:

1. YaneuraOu's own effective unrestricted root generator (`MoveList<LEGAL>`, matching the default production root-search path with `GenerateAllLegalMoves=false`) reports fewer than 3 root moves for the failed position.
2. The frozen MultiPV=3 50k search emits zero scored/PV-bearing `multipv 3` observations and terminates with the frozen `no_completed_exact_iteration` behavior.

If either condition is false: **STOP**. Do not enable this corrective and investigate another cause.

Legal-move count must be computed from the position with YaneuraOu's legal move generator. It must never be inferred from the number of MultiPV lines emitted by a bounded search.

## 3. Corrective behavior

For unrestricted VE1-B MultiPV measurement:

`requiredMultiPV = min(configuredMultiPV, effectiveLegalRootMoveCount)`

where `effectiveLegalRootMoveCount = |MoveList<LEGAL>|` from the same engine position when `GenerateAllLegalMoves=false`.

Requirements:

- zero legal root moves are terminal/invalid for this measurement and remain fail-closed;
- `searchmoves` behavior and configured MultiPV values are not broadened;
- `LEGAL_ALL` must not be used to compute `requiredMultiPV`;
- node tiers, safety ceiling, TT reset policy, score semantics, stability rules, PV roles, and C1 semantics are unchanged;
- Errata #1 (MultiPV mixed block/cohort) is not repaired here and remains scheduled separately for Build20+.

## 4. Scope proof against frozen B6

Before accepting the successor Authority, audit every frozen physical B6 deep attempt:

- Standard: 315 attempts;
- Stress: 189 attempts;
- total: 504 attempts;
- unique recorded root positions: 9.

For every unique position, compute the effective unrestricted root count from its recorded `positionCommand` using the pinned YaneuraOu engine. Mechanically map that result back to all 504 recorded attempts.

The B6 audit has two required methods:

1. **Authority:** native pinned YaneuraOu `MoveList<LEGAL>` count.
2. **Crosscheck:** obtain the same position's `MoveList<LEGAL_ALL>` move universe and have Swift independently apply the pinned `LEGAL` non-promotion omission rules; the derived count must equal the authority count.

Required result:

- all 9 unique positions have `MoveList<LEGAL>` count >= 3;
- all 504 mapped attempts therefore have effective count >= 3;
- engine-vs-Swift count mismatch count = 0;
- no B6 attempt's required MultiPV changes under this corrective.

If any position has legal-root count < 3, or if any engine-vs-Swift parity mismatch exists: **STOP** and require a fresh B6 impact disposition; do not claim B6 PRIMARY_PASS is unchanged.

If all gates pass, B6 PRIMARY_PASS remains semantically and operationally unaffected and no physical-device remeasurement is required solely for this corrective.

## 5. Corrective regression fixtures

Add four pinned fixture classes.

### 5.1 Effective LEGAL count 1 / 2 / 3

Add positions whose engine `MoveList<LEGAL>` counts are exactly 1, 2, and 3.

For each fixture under configured MultiPV=3 and `go nodes 50000`:

- engine-reported `MoveList<LEGAL>` count must equal the fixture expectation;
- effective required MultiPV must equal `min(3, legalRootCount)`;
- completion must be `node_budget_reached`;
- selected completed-exact snapshot rank count must equal the legal-root count for 1 and 2, and equal 3 for the boundary fixture;
- selected ranks must be exactly `1...effectiveRequiredMultiPV`;
- raw USI is preserved.

The 3-LEGAL-move boundary must demonstrate no behavior change from configured MultiPV=3.

### 5.2 `LEGAL=2`, `LEGAL_ALL=3` non-promotion distinction

Add at least one pinned position for which:

- `MoveList<LEGAL>.size() == 2`;
- `MoveList<LEGAL_ALL>.size() == 3`;
- the extra `LEGAL_ALL` move is one of the optional non-promotion variants omitted by the default search generator.

This fixture must prove that using rule-legal/`LEGAL_ALL` count would incorrectly leave `requiredMultiPV=3`, while the corrective correctly selects `requiredMultiPV=2` and completes.

The fixture must be validated by the pinned engine itself; a synthetic Swift-only move list is not sufficient as the final engine regression fixture.

## 6. Regression gates

Required before successor Authority is accepted:

1. corrective engine fixtures for effective LEGAL counts 1/2/3 PASS;
2. `LEGAL=2`, `LEGAL_ALL=3` non-promotion distinction fixture PASS;
3. engine `MoveList<LEGAL>` vs Swift reconstruction parity PASS;
4. frozen Swift/core unit tests PASS;
5. Simulator E2E PASS;
6. HDS Contract Evidence PASS;
7. normal iOS/device build PASS;
8. B6 504-attempt legal-root audit PASS;
9. no changes to frozen VE1-B historical documents/evidence other than an additive errata/corrective record.

## 7. Successor Authority

Only after Sections 2, 4, 5, and 6 pass, the implementation commit may be designated the VE1-B Corrective successor Authority.

The frozen historical status then reads:

- `8daf78c...`: VE1-B FORMAL PASS / Freeze, historical Authority;
- Errata #1: MultiPV block/cohort mixing — known, repair deferred Build20+;
- Errata #2: configured MultiPV exceeding effective `MoveList<LEGAL>` root count — corrected by successor Authority.

## 8. C1 pool rerun and contamination

After the successor Authority is fixed, rerun the production pool from the beginning with the **same** committed candidate-game corpus, the **same** `VE1-C1-SAMPLING-v1` game order, and the same shortest-prefix/round-robin rules.

No game substitution is allowed.

Because seed-rank games 1 and 2 were already processed and diagnostic/deep results were exposed during the failed pool attempt, both games are contamination-excluded from VE1-D tuning, holdout, and reserve regardless of whether they ultimately contribute one of the 16 pilot positions.

The broader pre-pool exclusion rule remains unchanged: all processed-prefix games producing one or more candidate positions, plus B6, are excluded from VE1-D.

## 9. Separate C1 issue: played move excluded from default LEGAL root universe

A distinct edge case exists when the actual played move is rule-legal but is one of the optional non-promotion variants omitted from the default `MoveList<LEGAL>` search universe. A `searchmoves <actualMove>` comparison may then reject the move or fail to analyze the intended root.

This issue is **not part of Errata #2's unrestricted MultiPV corrective** and must not delay the pool rerun after the successor Authority is established. However it must be resolved and documented before C1 Freeze.

Before C1 Freeze:

1. verify the current comparison/searchmoves behavior on pinned-engine fixtures for omitted non-promotion moves;
2. choose and preregister one policy, with regression evidence:
   - fail closed as `NOT_CLASSIFIABLE`; or
   - use a separately specified comparison-only search universe such as `GenerateAllLegalMoves=true` without contaminating unrestricted-search semantics;
3. preserve same-tier comparison and provenance requirements and do not silently substitute another move.

Until that decision is evidenced, this edge case is an explicit **C1 pre-Freeze open item**, not a pool blocker.

## 10. Current disposition

- VE1-B historical Authority `8daf78c...`: **FORMAL PASS / Freeze（既知 errata あり）**
- VE1-B Corrective #2: **PREREGISTERED / IMPLEMENTATION HOLD**
- B6 LEGAL scope audit: **REQUIRED BEFORE IMPLEMENTATION**
- C1 production pool: **BLOCKED pending Corrective #2 successor Authority**
- natural 16-position pilot: **NOT RUN**
- VE1-C1: **PILOT-READY / NOT FROZEN**
- played-move non-promotion/searchmoves issue: **OPEN / MUST RESOLVE BEFORE C1 FREEZE, DOES NOT BLOCK POOL RERUN AFTER CORRECTIVE**

No VE1-D work may begin.
