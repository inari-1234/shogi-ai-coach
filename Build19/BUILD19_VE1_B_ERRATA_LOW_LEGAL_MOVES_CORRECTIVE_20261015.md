# Build19 VE1-B Errata #2 — Low-Legal-Move MultiPV Corrective

Date: 2026-10-15
Status: **PREREGISTERED / IMPLEMENTATION HOLD**
Frozen base Authority: `8daf78caa2bd5919cc911da21bae80fa3d12a248`
Branch: `candidate/build19-ve1-c1-pilot`

This corrective does **not** rewrite the frozen VE1-B Authority history. `8daf78c...` remains the frozen historical Authority and is corrected only by a new successor commit after every gate below passes.

## 1. Suspected defect

At the frozen base, `EngineUSISession.analyzePositionNodes` uses configured `currentMultiPV` directly as `requiredMultiPV`. `USICompletedIterationSelector` therefore requires ranks `1...requiredMultiPV` even when the root position has fewer legal moves than the configured MultiPV.

For an unrestricted search with configured `MultiPV = 3`, a root with only one or two legal moves can never emit all three ranks. Reaching the node budget can therefore end as `no_completed_exact_iteration` even when every legal root move has been completely represented by the engine.

This is treated as a product defect, not as a C1 threshold/semantic relaxation.

## 2. Mandatory cause-confirmation gate

Before the production corrective is enabled, reproduce the failed C1 pool position (seed rank 2, ply 126) using the same pinned engine/NNUE/runtime contract and preserve raw USI.

The defect is **CONFIRMED** only if both are true:

1. YaneuraOu's own effective unrestricted root generator (`MoveList<LEGAL>`, matching the default production root-search path) reports fewer than 3 legal root moves for the failed position.
2. The frozen MultiPV=3 50k search emits zero scored/PV-bearing `multipv 3` observations and terminates with the frozen `no_completed_exact_iteration` behavior.

If either condition is false: **STOP**. Do not enable this corrective and investigate another cause.

Legal-move count must be computed from the position with YaneuraOu's legal move generator. It must never be inferred from the number of MultiPV lines emitted by a bounded search.

## 3. Corrective behavior

For unrestricted VE1-B MultiPV measurement:

`requiredMultiPV = min(configuredMultiPV, effectiveLegalRootMoveCount)`

where `effectiveLegalRootMoveCount` is obtained deterministically from the engine position using the same `MoveList<LEGAL>` root-move universe used by production search when `GenerateAllLegalMoves` is false.

Requirements:

- zero legal root moves are terminal/invalid for this measurement and remain fail-closed;
- `searchmoves` behavior and configured MultiPV values are not broadened;
- node tiers, safety ceiling, TT reset policy, score semantics, stability rules, PV roles, and C1 semantics are unchanged;
- Errata #1 (MultiPV mixed block/cohort) is not repaired here and remains scheduled separately for Build20+.

## 4. Scope proof against frozen B6

Before accepting the successor Authority, audit every frozen physical B6 deep attempt:

- Standard: 315 attempts;
- Stress: 189 attempts;
- total: 504 attempts.

For every attempt, compute the effective unrestricted root legal-move count from its recorded `positionCommand` using YaneuraOu `MoveList<LEGAL>`.

Required result:

- all 504 attempts have legal-root count >= 3;
- no B6 attempt's required MultiPV changes under this corrective.

If any attempt has legal-root count < 3: **STOP** and require a fresh B6 impact disposition; do not claim B6 PRIMARY_PASS is unchanged.

If all 504 are >= 3, B6 PRIMARY_PASS remains semantically and operationally unaffected and no physical-device remeasurement is required solely for this corrective.

## 5. Corrective regression fixtures

Add three pinned positions with effective legal-root counts exactly 1, 2, and 3.

For each fixture under configured MultiPV=3 and `go nodes 50000`:

- engine-reported legal-root count must equal the fixture expectation;
- effective required MultiPV must equal `min(3, legalRootCount)`;
- completion must be `node_budget_reached`;
- selected completed-exact snapshot rank count must equal the legal-root count for 1 and 2, and equal 3 for the boundary fixture;
- selected ranks must be exactly `1...effectiveRequiredMultiPV`;
- raw USI is preserved.

The 3-legal-move boundary must demonstrate no behavior change from configured MultiPV=3.

## 6. Regression gates

Required before successor Authority is accepted:

1. corrective fixture 1/2/3 PASS;
2. frozen Swift/core unit tests PASS;
3. Simulator E2E PASS;
4. HDS Contract Evidence PASS;
5. normal iOS/device build PASS;
6. B6 504-attempt legal-root audit PASS;
7. no changes to frozen VE1-B historical documents/evidence other than an additive errata/corrective record.

## 7. Successor Authority

Only after Sections 2, 4, 5, and 6 pass, the implementation commit may be designated the VE1-B Corrective successor Authority.

The frozen historical status then reads:

- `8daf78c...`: VE1-B FORMAL PASS / Freeze, historical Authority;
- Errata #1: MultiPV block/cohort mixing — known, repair deferred Build20+;
- Errata #2: configured MultiPV exceeding legal-root count — corrected by successor Authority.

## 8. C1 pool rerun and contamination

After the successor Authority is fixed, rerun the production pool from the beginning with the **same** committed candidate-game corpus, the **same** `VE1-C1-SAMPLING-v1` game order, and the same shortest-prefix/round-robin rules.

No game substitution is allowed.

Because seed-rank games 1 and 2 were already processed and diagnostic/deep results were exposed during the failed pool attempt, both games are contamination-excluded from VE1-D tuning, holdout, and reserve regardless of whether they ultimately contribute one of the 16 pilot positions.

The broader pre-pool exclusion rule remains unchanged: all processed-prefix games producing one or more candidate positions, plus B6, are excluded from VE1-D.

## 9. Current disposition

- VE1-B Corrective #2: **PREREGISTERED / IMPLEMENTATION HOLD**
- C1 production pool: **BLOCKED**
- natural 16-position pilot: **NOT RUN**
- VE1-C1: **PILOT-READY / NOT FROZEN**

No VE1-D work may begin.