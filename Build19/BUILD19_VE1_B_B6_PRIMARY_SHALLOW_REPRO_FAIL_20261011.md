# Build19-VE1-B B6 — Primary Shallow Reproducibility Failure Authority

Date: 2026-10-11
Status: **FROZEN PHYSICAL RESULT / PRIMARY B6 HOLD**

## 1. Scope

This document records the first physical B6 primary campaign on the frozen candidate commit `7dcfdc436ea51feb0876c110581067ddbfbaaff1` and classifies the failure before any redesign is implemented.

This is a failed-campaign authority. It must not be rewritten into a PASS after later implementation changes.

Qualification fixture:

- file: `CPU対局 81手.kif`;
- moves: 81;
- SHA-256: `ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102`.

Aggregate report SHA-256:

- `4d27717d5ba2c68e401d08c1e540186600c5e0155f44c71afa2c0df72d78a957`.

## 2. Physical environment and policy

All five standard runs used:

- device: `iPhone17,1`;
- OS: iOS `26.7.1`;
- app commit: `7dcfdc436ea51feb0876c110581067ddbfbaaff1`;
- FV_SCALE: 24;
- Threads: 1;
- Hash: 64 MB;
- BookFile: `no_book`;
- PvInterval: 0;
- Deep candidate/confirmation tiers: `50,000 -> 100,000 -> 200,000` nodes;
- per-search safety ceiling: 15,000 ms;
- authority status: `UNFROZEN_CALIBRATION`;
- each standard run began and ended at thermal `nominal`.

## 3. Shallow reproducibility failure

The production shallow stage used `150 ms` per position.

Observed production Deep-selection Top-3 plies were:

| run | Top-3 |
|---|---|
| 1 | 79, 81, 49 |
| 2 | 79, 81, 49 |
| 3 | 79, 81, 49 |
| 4 | 79, 81, 49 |
| 5 | 49, 69, 53 |

The modal Top-1 was ply 79 in 4/5 runs, but the minimum pairwise Top-3 Jaccard was `0.20`, below the frozen `>=0.50` gate.

Therefore the primary campaign decision is:

- `B6_HOLD`;
- reason: `shallow_reproducibility_failed_requires_fixed_node_redesign`.

Stress qualification was correctly not executed after this earlier gate failed.

## 4. The selection set itself changed

The failure is not merely an ordering difference. The seven positions sent to Deep changed across runs.

- runs 1 and 4 selected the set `{7, 49, 53, 69, 77, 79, 81}`;
- runs 2, 3 and 5 selected the set `{41, 49, 53, 69, 77, 79, 81}`.

Within those sets, ordering also changed. In particular, ply 7 and ply 41 replaced each other across runs. Since ply 7 and ply 41 do not have the same Deep stability state, this upstream variation can change user-visible coaching content, not only internal ranking.

## 5. Deep operational result passed with large margin

Across the five standard runs:

- 35 Deep positions were completed;
- each position had exactly 9 searches;
- total searches: 315;
- `node_budget_reached`: 220;
- `proven_mate_termination`: 95;
- incomplete searches: 0;
- serious thermal observations: 0;
- critical thermal observations: 0;
- evidence integrity: PASS.

Frozen arithmetic reproduced:

- Deep-position median: 2,595 ms;
- Deep-position empirical P95: 2,929 ms;
- whole-game median: 34,861 ms;
- whole-game empirical P95: 35,792 ms.

Thus the primary Deep policy did not fail an operational gate. The predetermined Deep fallback `25k/50k/100k` is **not** authorized by this result.

## 6. Deep per-position determinism observed on device

Across the eight distinct plies observed in Deep (`7, 41, 49, 53, 69, 77, 79, 81`), repeated analysis of the same ply produced the same semantic search evidence under the fixed-node/cold-TT design.

For every repeated ply, all nine searches matched across runs in the fields that define the semantic measurement, including:

- completion state;
- issued node budget / role / MultiPV / searchmoves identity;
- selected move;
- selected score kind and value;
- selected depth and seldepth;
- selected node count;
- selected PV;
- max observed nodes;
- bestmove consistency;
- final `stable` / `unstable` state and stability reasons.

`ttGeneration` numbers may differ when the same ply appears at a different selection ordinal; that is expected bookkeeping and does not change the cold-TT search semantics.

This is strong physical evidence that the run-to-run variation in the first B6 campaign arose upstream of Deep, in the 150 ms Shallow triage/selection path.

## 7. Non-mate runtime sensitivity check

The Deep margin is not explained only by mate positions.

Observed non-mate positions (`7, 41, 49, 53, 69`) contributed 20 completed Deep-position observations with:

- median approximately 2,704 ms;
- empirical P95 approximately 2,929 ms.

Observed proven-mate positions (`77, 79, 81`) contributed 15 observations with:

- median approximately 753 ms;
- empirical P95 approximately 836 ms.

Therefore even the non-mate subset remains far below the frozen 15 s median / 25 s P95 Deep-position limits. Broader game-shape characterization may be deferred to later validation; it is not a reason to reinterpret this B6 failure.

## 8. Evidence limitation discovered

The aggregate report's `shallowSamples` retained only:

- ply;
- elapsedMs;
- thermalBefore;
- thermalAfter.

It did not retain the Shallow move/score/node evidence or the derived importance inputs. Therefore the exact per-ply numerical cause of Run 5's ranking reversal cannot be reconstructed after the fact from the preserved B6 package.

This limitation does not weaken the B6_HOLD decision because the observed Top-3/Jaccard failure is sufficient by itself. It does define a mandatory evidence requirement for the redesigned Shallow stage.

## 9. Required next action

Do not:

- run the three stress repetitions on this failed campaign;
- invoke the Deep `25k/50k/100k` fallback;
- relax the Jaccard threshold;
- discard or overwrite this failed campaign evidence.

The next campaign requires a new build/SHA with Shallow migrated from 150 ms timing to a pre-frozen fixed-node contract, complete Shallow evidence retention, and a full B6 restart from standard run 1.
