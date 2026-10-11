# Build19-VE1-B — Contract Index

Date: 2026-10-10
Status: **IMPLEMENTATION IN PROGRESS / NOT FORMAL PASS**
Updated: 2026-10-11

Authority order for VE1-B work, highest priority first where wording conflicts:

1. `BUILD19_VE1_B_B6_SHALLOW_FIXED_NODE_PREMEASUREMENT_20261011.md` — current redesigned-B6 Shallow authority, frozen after the first primary campaign failed Shallow reproducibility and before a redesigned physical result is observed. It replaces only the old 150 ms Shallow search/reproducibility rules with 50,000-node, MultiPV1, cold-TT-per-position measurement; requires complete per-ply Shallow evidence; and requires exact deterministic repetition (all Top-3 Jaccards 1.00, Top-1 5/5, full ordered selection identity). It does not alter the Deep 50k/100k/200k policy or activate Deep fallback.
2. `BUILD19_VE1_B_B6_PRIMARY_SHALLOW_REPRO_FAIL_20261011.md` — immutable authority for the first physical B6 campaign on `7dcfdc436ea51feb0876c110581067ddbfbaaff1`. Records `B6_HOLD`, Top-3 Run1-4 `[79,81,49]` vs Run5 `[49,69,53]`, selected-set replacement ply 7 ↔ ply 41, Deep standard operational PASS, and repeated per-ply Deep semantic determinism. Later redesign evidence must not rewrite this failed campaign into a PASS.
3. `BUILD19_VE1_B_B6_MEASUREMENT_OPERATION_ADDENDUM_20261011.md` — B6 physical-operation/evidence-retention authority. It binds the original primary candidate to preserved proof/device artifacts, freezes offline artifact retention, fallback-only change control, and mandatory accounting/disposition of every interrupted physical attempt.
4. `BUILD19_VE1_B_PROVEN_MATE_TERMINATION_AMENDMENT_20261011.md` — completion-state authority. `proven_mate_termination` is completed only for a coherent full-MultiPV exact-mate snapshot with consistent terminal bestmove; unmatched `early_engine_termination` remains incomplete.
5. `BUILD19_VE1_B_PV_INTERVAL_COMPLETED_ITERATION_AMENDMENT_20261010.md` — evidence-observation authority. `PvInterval=0` is mandatory; the measured result is the deepest fully completed exact iterative-deepening snapshot; deeper terminal bounds remain raw provenance; no exact completed iteration is incomplete.
6. `BUILD19_VE1_B_INDEPENDENT_SINGLE_MOVE_COMPARISON_AMENDMENT_20261010.md` — recommended and actual are measured independently with cold TT / MultiPV1 / one `searchmoves` move, producing nine Deep searches per position. Item 5 supersedes older target-bound wording where applicable.
7. `BUILD19_VE1_B_CANDIDATE_DISCOVERY_CONVERGENCE_AMENDMENT_20261010.md` — unrestricted candidate discovery must be re-checked across increasing node tiers; fixed-pair convergence alone cannot establish stability.
8. `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md` — original B6 physical-device acceptance method and numerical operational gates. Its Deep thresholds, standard/stress gates, primary 50k/100k/200k Deep policy, predetermined 25k/50k/100k Deep fallback and no-post-hoc rule remain authoritative. Its old 150 ms Shallow reproducibility section is superseded for the redesigned campaign by item 1.
9. `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md` — base formal B1-B8 pass/fail gates.
10. `BUILD19_VE1_B_GENERIC_E2E_MIGRATION_20261010.md` — production/context authority migration and regression bridge.
11. `BUILD19_VE1_B_ISSUES_20261009.md` — issue backlog and implementation notes.
12. `BUILD19_VE1_A_FORMAL_PASS_20261010.md` — frozen VE1-A runtime baseline; FV_SCALE=24 remains formal runtime authority.
13. `BUILD19_VE1_A_PHYSICAL_DEVICE_EVIDENCE_REQUIREMENTS_20261009.md` — known-answer provenance/mismatch policy.
14. `tools/engine-verify/VE1_NUMERIC_EVIDENCE_POLICY.md` — numeric evidence provenance requirements.
15. `tools/engine-verify/HDS_CONTRACT_EVIDENCE_POLICY.md` — HDS historical regression authority.
16. `BUILD19_VE1_C_ISSUES_20261009.md` — deferred semantic threshold/mate-sign work.

Implementation must not begin by changing expected outputs. The original physical candidate `7dcfdc436ea51feb0876c110581067ddbfbaaff1` remains frozen as failed-campaign authority; redesigned implementation proceeds on a new SHA.

Required implementation order for the current continuation:

`freeze failed campaign -> freeze Shallow fixed-node contract -> minimal Shallow implementation/evidence expansion -> Core/HDS/Simulator/device/incomplete-state proof -> new proof-bound B6 candidate -> full physical B6 standard 5 -> stress 3 only after standard PASS -> independent evidence review`.

Additional fixed rules carried forward:

- the original B6 primary campaign on `7dcfdc436ea51feb0876c110581067ddbfbaaff1` is `B6_HOLD` because Shallow reproducibility failed; its report/Evidence remain immutable;
- original Top-3 membership changed, not only order: runs 1/4 included ply 7 while runs 2/3/5 included ply 41;
- repeated Deep analysis of the same ply was semantically identical across physical runs under fixed nodes/cold TT; TT generation ordinal differences caused by position order are bookkeeping, not semantic disagreement;
- the first campaign's Deep operational gate passed with 315/315 completed searches, so `25k/50k/100k` Deep fallback is not activated;
- redesigned Shallow uses 50,000 nodes, MultiPV1, cold TT for every position, PvInterval=0 and the existing completed-exact/proven-mate semantics;
- redesigned Shallow must preserve per-ply move/score/node/completion/derived importance/rank and the adopted raw `info` line;
- fixed-node Shallow deterministic integrity requires Top-3 Jaccard 1.00 for all ten pairs, Top-1 5/5, identical full ordered selection lists, and no unexplained semantic per-ply evidence difference; any deviation yields `B6_HOLD` for investigation;
- do not run stress after an earlier standard/Shallow gate has failed;
- every physical attempt, including interrupted attempts, remains visible in chronology under the measurement-operation addendum;
- proof/device artifacts must be retained with hashes for later independent review;
- `proven_mate_termination` remains completed only under the strict amendment predicate;
- `PvInterval=0` remains mandatory across app/harness evidence paths;
- candidate-search instability is confidence/reliability information, not position importance;
- confirmedPV/referencePV semantics remain frozen;
- HDS-M PASS remains a historical pipeline/selection regression statement, not semantic correctness;
- `VE1B-001` scored-info preservation remains mandatory;
- mate-sign semantic acceptance remains VE1-C unless shared-abstraction work is unavoidable;
- VE1-B is not complete until all B1-B7 gates plus Simulator/device/physical-iPhone evidence and final independent review pass on the redesigned final candidate.
