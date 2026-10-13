# Build19 VE1-C1 Pre-Pilot Amendment — coherent MultiPV output blocks

Status: **PRE-PILOT AMENDMENT / NOT FORMAL FREEZE**

This amendment is mandatory before the excluded 16-position natural pilot.

## C1 evidence rule

Candidate Structure evidence is usable only when MultiPV rows form one coherent completed output block:

1. ranks `1...N` occur in order;
2. depth is identical across ranks;
3. nodes are identical across ranks;
4. time is identical across ranks;
5. every rank is exact;
6. every rank has a non-empty PV;
7. root moves are distinct as an integrity assertion.

A snapshot assembled from different nodes/time cohorts is not usable even when root moves happen to be distinct.

Failure to find a coherent block yields `INSUFFICIENT` for the corresponding Candidate Structure axis.

## App-side rule

The pilot records both:

- the frozen VE1-B selector reconstruction, for Authority impact/audit; and
- the C1 coherent-block snapshot, for Candidate Structure semantics.

The App recommendation identity remains traceable to the frozen VE1-B deepest discovery evidence. C1 may not use its downstream block guard to promote or alter VE1-B stability, confirmedPV, referencePV, or deep-selection Authority.

If the coherent App candidate block is unavailable, C1 Candidate Structure is `INSUFFICIENT` and no confirmed UNIQUE/MULTIPLE structure claim may be emitted from that discovery evidence.

## Reference-side rule

Reference 4M and 16M candidate discovery use the same coherent-block selector.

If either Reference budget lacks a coherent exact block, that budget's Candidate Structure evidence is `INSUFFICIENT`.

Targeted H3/H4 searchmoves remain independent MultiPV1 searches and are not replaced by MultiPV candidate scores.

## Regression fixture

`tools/engine-verify/fixtures/ve1b_multipv_block_mixing.json`

must select the 77806-node depth-12 block:

`2g2f / 7g7f / 6i7h`

and must independently reproduce the frozen selector's mixed result:

`2g2f / 2g2f / 6i7h`.

## Pilot entry gate

The natural 16-position pilot remains blocked until:

- coherent-block guard is active for both App and Reference runners;
- the six-line regression fixture passes;
- VE1-B errata impact scan is recorded;
- control run confirms C1 no longer consumes mixed MultiPV cohorts.

VE1-B Authority `8daf78c` remains unchanged.
