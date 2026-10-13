# Build19-VE1-C1 — Pre-Pilot Contract

Date: 2026-10-13
Status: **PILOT-READY / NOT FROZEN**
Authority base: `8daf78caa2bd5919cc911da21bae80fa3d12a248`

This document fixes the pre-corpus pilot contract. It does not modify VE1-A or VE1-B Authority.

## 1. C1 certainty is downstream semantic certainty

`playedMoveCertainty = CONFIRMED` in VE1-C means only that the VE1-C semantic classifier has sufficient evidence for that played-move claim under this contract.

It is **not** the same as `VE1BStability.state == stable`.

VE1-B remains authoritative for:

- `confirmedPV` / `referencePV` roles;
- PV promotion;
- continuation stability;
- any upstream/deep-analysis selection condition requiring VE1-B stability.

A C1 `CONFIRMED` result must never make a VE1-B non-qualifying tier stable and must never promote `referencePV` to `confirmedPV`.

## 2. Frozen App evidence shape used by the pilot

At the 8daf78c Authority implementation:

- unrestricted candidate discovery executes 50k, 100k and 200k nodes;
- comparison executes 50k, 100k and 200k nodes;
- the deepest unrestricted discovery top move is the fixed recommended move for every comparison tier;
- every independent discovery / best / actual search has a cold logical TT boundary;
- a comparison inversion is non-qualifying for VE1-B stability even when its magnitude is only 1 cp.

There is no 50k early-termination path in this contract.

C1 comparisons compare **same-tier evidence only**. The primary App semantic source is 200k discovery versus 200k comparison. If an operation explicitly consumes a VE1-B qualifying tier instead, it uses the deepest qualifying tier and still compares like-for-like node budgets.

### 2.1 C1 candidate-snapshot coherence guard

The frozen `USICompletedIterationSelector` remains unchanged. Parser/selector parity with VE1-B is checked **before** the following downstream C1 guard.

A selected MultiPV snapshot is usable for C1 Candidate Structure only when all of the following hold:

- exactly the required MultiPV ranks are present;
- every selected line has a non-empty PV/root move;
- required root moves are pairwise distinct;
- all selected ranks have the same non-null `nodes` value, establishing one output cohort rather than a mixture of an earlier completed iteration and stale rank lines emitted during a later partial iteration.

Otherwise C1 Candidate Structure evidence is insufficient. Reasons are recorded as one of:

- `INSUFFICIENT_NO_COMPLETED_EXACT_SNAPSHOT`;
- `INSUFFICIENT_MISSING_ROOT_MOVE`;
- `INSUFFICIENT_DUPLICATE_ROOT_MOVE`;
- `INSUFFICIENT_MIXED_ITERATION_COHORT`.

For App evidence, this guard does **not** replace the frozen VE1-B recommendation identity with an alternative historical snapshot. The deepest VE1-B recommendation may still be measured for played-move diagnostics, but C1 must not issue a confirmed UNIQUE/MULTIPLE structure claim from an incoherent snapshot.

For Reference evidence, structure and played resolution remain separate: an incoherent root MultiPV snapshot makes Reference structure insufficient, while independent exact rank-1/actual `searchmoves` evidence may still be retained as played evidence. Any F/H3/H4 decision requiring Reference good-set membership remains unresolved unless the Reference structure/membership evidence itself is sufficient.

This is a fail-closed C1 evidence-validity guard and does not modify VE1-B stability, `confirmedPV`, `referencePV`, or the frozen completed-iteration selector.

## 3. CROSS_AXIS_CONFLICT

Let recommended move be B and actual move be A, with `A != B`.

If the App independent same-tier comparison places A:

- definitely inside the App good set;
- in the good-boundary ambiguity band; or
- above B by comparison inversion;

then Candidate Structure may not remain `UNIQUE_GOOD + CONFIRMED`.

Required result:

- Candidate Structure = `UNKNOWN`;
- structure certainty = `UNCONFIRMED`;
- no `UNIQUE_RECOMMENDATION` may be emitted;
- reason = `CROSS_AXIS_CONFLICT`.

This rule is evaluated independently of the final F policy selected by the pilot.

## 4. F policy candidates fixed before pilot

No post-pilot third rule may be invented.

### F0 — conservative fallback

Any comparison inversion:

- MATCH prohibited;
- Played Move = `NOT_CLASSIFIABLE`;
- played certainty = `UNCONFIRMED`;
- reason = `COMPARISON_INVERSION`.

### F2 — small-inversion semantic recovery

For inversion magnitude

`I = E(actual) - E(recommended)`

with `E(cp)=1/(1+exp(-cp/285))`:

If `0 < I <= 0.050`:

- severity `L=0`;
- MATCH prohibited;
- Played Move = `WITHIN_GOOD_SET`;
- C1 played certainty = `CONFIRMED`;
- reason = `COMPARISON_INVERSION`.

If `I > 0.050`:

- Played Move = `NOT_CLASSIFIABLE`;
- played certainty = `UNCONFIRMED`;
- reason = `LARGE_COMPARISON_INVERSION`.

F2 does not alter VE1-B stability.

### F2 adoption rule

Collect every natural-pilot small inversion.

F2 is adopted only when:

1. at least one such case exists; and
2. every case belongs to the Reference good set at both 4M and 16M.

Any non-good, DISPUTED, INSUFFICIENT or otherwise unresolved case rejects F2 and selects F0.

`0 / 0` selects F0.

## 5. E policy candidates fixed before pilot

### E0 — strict fallback

- ambiguity at either score source => `NOT_CLASSIFIABLE`;
- two definite but different semantic classes => `SCORE_SOURCE_CONFLICT`;
- only matching definite classes are accepted.

### E1 — ambiguity intersection

Allowed finite class sets:

- definite good: `{GOOD}`
- good-boundary ambiguity: `{GOOD, SOMEWHAT_WORSE}`
- definite somewhat worse: `{SOMEWHAT_WORSE}`
- blunder-boundary ambiguity: `{SOMEWHAT_WORSE, BLUNDER}`
- definite blunder: `{BLUNDER}`

Two sources are compatible iff their allowed-class intersection is non-empty.
Mate outcome classes are separate and are not reconciled by this finite rule.

### E1 adoption rule

Evaluate the entire frozen δ grid:

`0.000, 0.005, ..., 0.050`.

Collect every `(position, tier, δ)` for which E0 abstains/conflicts but E1 accepts compatibility.

E1 is adopted only when:

1. at least one E1-only case exists; and
2. every E1-only case is compatible with the resolved Reference class at both 4M and 16M.

Any Reference contradiction, DISPUTED, INSUFFICIENT or unresolved case selects E0.

`0 / 0` selects E0.

## 6. Pilot mother population and deterministic sampling

Natural pilot positions must come from the same mother population intended for VE1-D:

**positions selected by the frozen production deep-analysis selector**.

Diagnostic controls such as startpos or the corrected C1 SFEN may be run separately, but do not count toward the 16 natural positions.

Natural pilot requirements:

- exactly 16 positions;
- at least 4 source games;
- at most 4 selected positions from one source game;
- every contributing pilot game is permanently excluded from VE1-D tuning, holdout and reserve manifests.

Sampling key:

`VE1-C1-SAMPLING-v1`

For each eligible position:

`SHA256("VE1-C1-SAMPLING-v1" | gameSHA256 | ply)`

Within each game, sort ascending and retain at most the first four.

Games are ranked by:

`SHA256("VE1-C1-SAMPLING-v1" | "GAME" | gameSHA256)`.

Fill the 16-position pilot by deterministic round-robin across ranked games, slot 1 through slot 4. No manual substitution based on position appearance or engine result is allowed.

## 7. Reference pilot configuration

- YaneuraOu pinned revision: `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`
- Suisho5 NNUE SHA-256: `768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76`
- FV_SCALE = 24
- Threads = 1
- Hash = 512 MB
- BookFile = `no_book`
- PvInterval = 0
- MultiPV = `min(3, legal root moves)`
- Budget A = 4,000,000 nodes
- Budget B = 16,000,000 nodes
- cold logical TT boundary before every independent search: `isready` -> `readyok` -> `usinewgame`
- semantic measurement = deepest fully completed exact iteration
- terminal bound-bearing partial iteration must not replace an earlier completed exact iteration
- raw USI and complete runtime provenance are mandatory.

Reference remains a deeper same-engine reference, not independent shogi truth.

## 8. H3/H4 cross-budget membership

For a move X:

- MEMBER only if it is Reference-good at both 4M and 16M;
- NONMEMBER only if it is non-good at both;
- otherwise UNRESOLVED.

For partially overlapping MULTIPLE_GOOD sets, only the intersection `G4 ∩ G16` is confirmed membership for H3/H4.

Targeted H3/H4 audit compares independent `searchmoves(rank1)` against independent `searchmoves(X)` at the same Reference budget. MultiPV score and targeted searchmoves score are not mixed.

In VE1-E, any strong emitted H3/H4 claim requiring UNRESOLVED membership is HOLD.

## 9. H4 display eligibility

A move may be shown as an explicit good alternative only when it is definitely inside the App good-set boundary.

A good-boundary ambiguity-band move may not be displayed as a good alternative.

## 10. Parser/evidence parity gate

A non-Swift pilot harness is permitted only after parity against the frozen Swift evidence semantics.

The same raw USI must produce identical:

- root move identity;
- score kind/value;
- bound kind;
- depth, nodes and PV used by measurement;
- deepest fully completed exact iteration;
- comparison-inversion boolean where applicable.

Required mismatch count: **0**.

Parity is evaluated against the frozen Swift parser/selector output first. The Section 2.1 coherence guard is then applied as an additional downstream C1 validity check; triggering that guard is not a parser-parity mismatch.

An existing 8daf B6 raw Evidence package may be used as parity data because this is parser/evidence validation, not semantic corpus calibration.

## 11. Pilot measurements

Report at minimum:

- comparison inversion rate by 50k / 100k / 200k;
- small-inversion count;
- large-inversion count;
- raw MultiPV-vs-searchmoves divergence;
- strict E0 source-conflict/abstention rate;
- E1-only compatibility count across the full δ grid;
- CROSS_AXIS_CONFLICT count;
- 4M and 16M terminal-bound frequency;
- completed-exact recovery success rate;
- no-recoverable-exact count;
- Reference structure DISPUTED rate;
- Reference played DISPUTED rate;
- Reference INSUFFICIENT rate;
- UNIQUE identity-change count;
- disjoint MULTIPLE good-set count.

## 12. Pilot amendment boundary

Pilot may not change semantic meaning:

- `k=285`;
- `τ_good_ref=0.050`;
- `τ_blunder_ref=0.200`;
- H1-H5 meanings;
- mate semantics;
- Candidate Structure meanings;
- Played Move meanings.

Before VE1-D begins, pilot evidence may justify an explicit **operational feasibility amendment** only for:

- Reference node budgets;
- Reference Hash;
- exact-evidence recovery mechanics;
- unresolved-rate ceiling;
- coverage floor.

Such an amendment requires a C1 version increment, explicit evidence, no inspection of VE1-D tuning/holdout, and a complete rerun of the same excluded pilot.

## 13. Pilot PASS definition fixed before execution

Pilot PASS is an **execution-integrity gate**, not a favorable-semantic-outcome gate. The natural-pilot observations may select F0 or F2 and E0 or E1; those selections are pilot results and do not by themselves make the pilot PASS or FAIL.

### 13.1 PASS conditions — execution-system health

The natural 16-position pilot is `PILOT_PASS` only when all of the following are satisfied:

1. Exactly 16 natural positions were executed, and every required search has its raw USI evidence and complete engine/runtime provenance preserved.
2. Parser/evidence parity between Python and the frozen Swift semantics has mismatch count **0** under Section 10.
3. A block/coherence-selection result is recorded for every required App search at 50k / 100k / 200k and every required Reference search at 4M / 16M, including both resolved and insufficient outcomes. An insufficient block is valid recorded evidence; a missing block result is not.
4. F is selected mechanically as F0 or F2, and E is selected mechanically as E0 or E1, using only the preregistered rules in Sections 4 and 5. No rule, threshold or exception may be introduced after observing pilot results.

Choosing the conservative policies F0 and/or E0 is not a pilot failure. Choosing F2 and/or E1 is not a pilot success criterion.

### 13.2 Report-only feasibility indicators — never retroactive PASS criteria

The pilot report must include, at minimum, the following feasibility indicators, but none of them may retroactively change `PILOT_PASS` into FAIL or HOLD:

- unresolved rate, with `DISPUTED + INSUFFICIENT` reported explicitly;
- H1, H2 and H5 denominator occurrence rates;
- 16M no-recoverable-exact rate;
- comparison inversion rate;
- `SCORE_SOURCE_CONFLICT` rate.

These indicators estimate whether the preregistered C1 design is likely to achieve the later VE1-D / VE1-E gates. They do not measure whether the pilot executor itself was healthy.

### 13.3 Poor feasibility after a valid PASS

If a valid `PILOT_PASS` has poor feasibility indicators — for example unresolved rate materially above the later 10% target — the result remains `PILOT_PASS`.

Before VE1-D, choose explicitly between only these dispositions:

- make an evidence-backed C1 operational feasibility amendment within the Section 12 boundary, increment the C1 version and rerun the same permanently excluded pilot; or
- retain the preregistered contract unchanged and accept the demonstrated risk that VE1-D / VE1-E may later HOLD.

The pilot result must not be reclassified by moving thresholds, redefining PASS, inventing an F/E rule, or inspecting VE1-D tuning/holdout data after the pilot outcome is known.

## 14. Pilot exit states

### PILOT_PASS

All Section 13.1 execution-integrity conditions are satisfied. Record the mechanically selected F/E policies and all Section 13.2 feasibility indicators.

If no operational feasibility amendment is chosen, proceed to final synthetic regressions and the C1 Freeze candidate.

### PILOT_FEASIBILITY_AMENDMENT_REQUIRED

This is a **post-PASS disposition**, not a pilot failure. Use it only when a valid `PILOT_PASS` has poor feasibility indicators and the evidence supports an explicit Section 12 operational feasibility amendment. Increment C1 and rerun the same excluded pilot before VE1-D.

### PILOT_HOLD

Use HOLD only when the Section 13.1 execution-integrity gate cannot be established under the preregistered contract — for example missing mandatory evidence, non-zero parser/evidence parity mismatch, missing required block-selection records, or an F/E outcome that cannot be derived without an unregistered rule.

Poor feasibility indicators alone are not `PILOT_HOLD`.

Do not start VE1-D from `PILOT_HOLD`.

## 15. Current disposition

**VE1-C1 = PILOT-READY / NOT FROZEN**

Frozen VE1-B Authority remains unchanged.
