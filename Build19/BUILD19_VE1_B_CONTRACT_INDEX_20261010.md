# Build19-VE1-B — Contract Index

Date: 2026-10-10
Status: **IMPLEMENTATION IN PROGRESS / NOT FORMAL PASS**
Updated: 2026-10-11

Authority order for VE1-B work, highest priority first where wording conflicts:

1. `BUILD19_VE1_B_B6_MEASUREMENT_OPERATION_ADDENDUM_20261011.md` — current B6 physical-operation/evidence-retention authority. It binds the qualified primary candidate `7dcfdc436ea51feb0876c110581067ddbfbaaff1` to its preserved proof/device artifacts, freezes offline artifact retention, fallback-only change control, and mandatory accounting/disposition of every interrupted physical attempt before any B6 device result is observed. It changes no B6 measurement threshold or qualified IPA.
2. `BUILD19_VE1_B_PROVEN_MATE_TERMINATION_AMENDMENT_20261011.md` — current pre-B6 completion-state authority. `proven_mate_termination` is a qualified completed state only for a coherent full-MultiPV exact-mate snapshot with consistent terminal bestmove; unmatched `early_engine_termination` remains incomplete. This amendment was frozen before any physical B6 measurement and changes no node/timing threshold.
3. `BUILD19_VE1_B_PV_INTERVAL_COMPLETED_ITERATION_AMENDMENT_20261010.md` — current evidence-observation authority. `PvInterval=0` is mandatory; the measured result is the deepest fully completed exact iterative-deepening snapshot; deeper terminal bounds remain raw provenance; no exact completed iteration is incomplete.
4. `BUILD19_VE1_B_INDEPENDENT_SINGLE_MOVE_COMPARISON_AMENDMENT_20261010.md` — current direct-comparison method: recommended and actual are measured independently with cold TT / MultiPV1 / one `searchmoves` move, so N means N nodes per move and the three-tier path has 9 searches per position. This remains in force except where item 3 supersedes its older target-bound wording.
5. `BUILD19_VE1_B_CANDIDATE_DISCOVERY_CONVERGENCE_AMENDMENT_20261010.md` — normative B5/B6 clarification: unrestricted candidate discovery itself must be re-checked across increasing node tiers; fixed-pair convergence alone cannot establish stability. This amendment supersedes any earlier wording that could allow the shallow Top-1 to remain frozen without deeper unrestricted verification.
6. `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md` — B6 physical-device acceptance method and numerical operational gates frozen before physical measurement. It controls shallow-repeatability thresholds, standard/stress runtime gates, the primary 50k/100k/200k qualification path, the only pre-authorized 25k/50k/100k fallback, and the no-post-hoc-threshold rule. It does not by itself freeze either node schedule as production authority; item 2 narrowly supersedes its assumption that every natural pre-budget return is necessarily incomplete.
7. `BUILD19_VE1_B_ACCEPTANCE_CRITERIA_20261010.md` — base formal pass/fail gates for B1-B8, including node-budget convergence, TT state, role-budget and abort semantics. Conflicting B3/B5/B6 wording is resolved by items 1-6 above.
8. `BUILD19_VE1_B_GENERIC_E2E_MIGRATION_20261010.md` — production/context authority migration and audit bridge from legacy movetime quality assertions to VE1-B node evidence. The legacy close-gap extension test is replaced by unconditional increasing-tier evidence, preserved MultiPV ranking and candidate-Top1-change diagnostics; it is not silently deleted.
9. `BUILD19_VE1_B_ISSUES_20261009.md` — previously discovered issue backlog and implementation notes.
10. `BUILD19_VE1_A_FORMAL_PASS_20261010.md` — frozen VE1-A runtime baseline and physical-device evidence summary. FV_SCALE=24 is formal runtime authority, not a VE1-B candidate value.
11. `BUILD19_VE1_A_PHYSICAL_DEVICE_EVIDENCE_REQUIREMENTS_20261009.md` — unchanged known-answer provenance/mismatch policy.
12. `tools/engine-verify/VE1_NUMERIC_EVIDENCE_POLICY.md` — numeric observations are not formal expected values without exact position identity, complete relevant command sequence, raw USI log and runtime provenance.
13. `tools/engine-verify/HDS_CONTRACT_EVIDENCE_POLICY.md` — 41/49/69 is a historical diagnostic regression contract only; silent fixture-selection changes are CI-guarded.
14. `BUILD19_VE1_C_ISSUES_20261009.md` — deferred semantic threshold/mate-sign work; not VE1-B implementation scope unless an unavoidable shared abstraction change is explicitly justified.

Implementation must not begin by changing expected outputs. It begins from the VE1-A formal runtime candidate `3252adb0fb5a066fc90362d978eec7f196f62135` and must preserve the VE1-A known answers throughout VE1-B.

Required implementation order:

`B1 -> B2/B3/B4 -> B6 -> B5/B7 -> full regression / Simulator / device build / physical iPhone evidence`.

B6 precedes B5/B7 because stability is defined as convergence under increasing node budgets, and therefore depends on the node-budget, TT-isolation/reuse, search-role and abort contract. Same-budget repetition is reproducibility evidence only and cannot establish stability.

Additional fixed rules carried forward:

- the B6 primary physical campaign is qualified only on commit `7dcfdc436ea51feb0876c110581067ddbfbaaff1`; documentation-only commits must not be mistaken for a new measurement candidate;
- the proof/device candidate artifacts for that SHA must be preserved outside expiring GitHub Actions storage with hashes recorded for later independent review;
- every physical attempt begun by the operator, including force-quit/crash/thermal/external interruptions, must remain visible in chronology and be disposed according to the premeasurement operations addendum rather than silently replaced;
- a fallback campaign requires a new SHA and may change only the pre-authorized node-policy values/direct provenance label; any other functional change forces `B6_HOLD` and a new pre-measurement contract;
- `proven_mate_termination` is completed provenance only under the strict 2026-10-11 amendment predicate; generic `early_engine_termination` remains incomplete, raw requested/observed node counts stay distinct, and mate-sign semantics remain outside this completion classification;
- `PvInterval=0` is part of VE1-B evidence provenance across app and harness paths;
- a qualifying node-search measurement is the deepest coherent completed exact iteration, with its true depth/nodes retained;
- a deeper terminal lowerbound/upperbound is preserved but cannot replace that completed exact measurement;
- an attempt with no qualifying exact completed iteration is incomplete and cannot count toward stability;
- candidate-search instability is confidence/reliability information, not position importance; `DeepImportanceSelector` must not promote or demote importance merely because deep comparison is unstable;
- HDS-M PASS means the historical pipeline/position-selection regression contract passed, not that the explanation is semantically correct;
- `VE1B-001` remains mandatory: scored `info` evidence must not be overwritten by later scoreless `info`;
- mate-sign semantic acceptance remains VE1-C (`VE1C-002`), unless VE1-B must touch the exact same scoring abstraction;
- B6 operational thresholds and fallback selection must not be changed after seeing physical measurements unless VE1-B remains HOLD and a new pre-measurement contract is explicitly adopted before a new qualification run;
- percentage of semantically `stable` positions is not a B6 runtime-health acceptance target;
- VE1-B is not complete until all B1-B7 gates plus Simulator/device/physical-iPhone evidence pass on one final candidate commit.