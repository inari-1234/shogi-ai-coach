# Build19-4 HOLD Concept Re-evaluation — Final Report

Date: 2026-10-05

## Final Verdict

**PASS — HOLD CONCEPT RE-EVALUATION COMPLETE**

Build19-4 independently re-evaluated the five concepts held by Build18-5A after Build19-1 through Build19-3B introduced typed candidate comparison, stable sequence/counterfactual evidence, comparison confidence, and beginner-facing coaching explanation.

The formal result is a safe no-promotion decision:

- `respond_to_rapid_attack`: HOLD
- `sabai`: HOLD
- `trade_to_transform`: HOLD
- `multi_threat`: HOLD
- `tempo_management`: HOLD

No concept is promoted merely because SequenceEvidence is now available.

## Authority

- Build19-3B final authority HEAD: `9637da6998235ed0e8464b8cbfeb0256f5511d41`
- Build19-4 branch: `candidate/build19-4-hold-concept-reevaluation`
- Validated reevaluation candidate HEAD: `3cae3289d330150bd23c933efdc7f59b42bc20fa`

Build18 authority and Build19-1 through Build19-3B production authority were not changed.

## Core conclusion

Build19 materially improves **observability** but does not by itself provide **specialized semantic authority**.

The reevaluation therefore distinguishes four layers:

1. concrete fact/effect observability;
2. candidate-to-candidate difference evidence;
3. causal support for a bounded comparison claim;
4. authority to name a specialized shogi concept.

Build19 improves the first three for several cases. It does not automatically satisfy the fourth.

## Concept decisions

### respond_to_rapid_attack — HOLD

Build19 can reconstruct stable branches and compare responses, but there is still no independently verified rapid-attack event classifier or concept-specific positive authority. A direct response to a rook-pawn advance may support generic response wording; it does not establish the specialized `rapid attack` category.

### sabai — HOLD

Build19 closes important observation gaps: exchange/recapture events, post-exchange continuation, board reconstruction, and counterfactual comparison are now available. However, there are still zero authoritative positive sabai examples and no typed semantic gate for major-piece activation quality or active-resource preservation. Exchange, mobility, or Shikenbisha identity alone cannot prove sabai.

### trade_to_transform — HOLD

Verified exchange sequences and before/after board states are now available. The remaining gap is semantic: a transformation effect cannot be promoted into transformation purpose without independent authority. No positive labeled authority or typed role-transformation semantic predicate exists.

### multi_threat — HOLD

Stable continuation and observed opponent PV replies are now representable, but a single PV is not an exhaustive legal-reply tree. The system cannot yet prove multiple independent threats or that one legal reply cannot neutralize them all. Existing adversarial authority therefore remains binding.

### tempo_management — HOLD

Build19 provides relative-ply timelines and counterfactual candidate branches, but no matched move-order semantic experiment establishes that a consequence differs specifically because of timing/order. Branch length, quiet moves, tenuki, development order, or evaluation gap cannot prove tempo-management purpose.

## Production isolation

Build19-4 adds no production concept detector and no production concept wording.

Validated protections:

- Production code changed: NO
- Build18 authority changed: NO
- Build19-1 through Build19-3B authority changed: NO
- automatic promotion from SequenceEvidence: NO
- HOLD concept identifier leakage into `Sources/ShogiCoachCore`: NONE

This phase is an authority/research decision layer, not a production feature integration phase.

## False-positive boundary

The following are explicitly insufficient to promote any HOLD concept:

- score gap alone;
- HIGH confidence on an unrelated grounded comparison claim;
- stable PV existence;
- PV length;
- ACTUAL / COUNTERFACTUAL branch identity;
- opening family;
- Shikenbisha identity;
- capture, promotion, mobility, or board-shape change alone;
- observed PV reply treated as forced.

## Validation

Dedicated workflow: `Build19-4 HOLD Concept Re-evaluation`

Validated candidate run:

- Run: `37290831468`
- Job: `111700558097`
- HEAD: `3cae3289d330150bd23c933efdc7f59b42bc20fa`
- Result: SUCCESS

Decision and isolation checks:

- authority/scope guard: PASS
- concept decisions: 5 / 5 HOLD
- promoted concepts: 0
- positive semantic authority: 0
- SequenceEvidence auto-promotion: blocked
- production HOLD leakage scan: PASS

Regression results:

- Build19-3B explanation + repetition: **17 / 17 PASS**
- Build19-3A ComparisonConfidence: **12 / 12 PASS**
- Build19-2 SequenceCounterfactual: **10 / 10 PASS**
- Build19-1 CandidateComparison: **14 / 14 PASS**
- Build17 Safe Concept: **19 / 19 PASS**
- Build18 Grounded WhyNow: **9 / 9 PASS**
- Build18 Frozen Corpus projection: **1 / 1 PASS**
- Full XCTest: **137 / 137 PASS**
- Swift Testing: **16 / 16 PASS**
- Static Verify: **PASS**

Validation artifact:

- Artifact ID: `11336287037`
- SHA-256: `e9423495b429145e126f4b2748270302dabd7df02d8e17c1f04114a8d8f33720`

## iOS Device Build

Validated candidate device build:

- Run: `37290831419`
- Job: `111700857158`
- HEAD: `3cae3289d330150bd23c933efdc7f59b42bc20fa`
- Result: SUCCESS

Confirmed PASS:

- Core regression tests
- engine assets restore
- pinned engine preparation
- Xcode project generation
- unsigned iPhone application build
- IPA verification/package
- artifact upload

Artifact:

- Artifact ID: `11336636486`
- SHA-256: `9f24ca88a7a269804270da1ddcd4de3451e41c28ebb82937f55846bc10c35008`

## Formal artifacts

1. `BUILD19_4_REEVALUATION_METHOD_20261005.md`
2. `BUILD19_4_CAPABILITY_DELTA_MATRIX_20261005.json`
3. `BUILD19_4_EVIDENCE_MATRIX_20261005.json`
4. `BUILD19_4_DECISION_MANIFEST_20261005.json`
5. `BUILD19_4_FALSE_POSITIVE_AUDIT_20261005.md`
6. `BUILD19_4_HUMAN_SEMANTIC_REVIEW_20261005.md`
7. `BUILD19_4_REGRESSION_RESULTS_20261005.json`
8. `BUILD19_4_FINAL_REPORT_20261005.md`

## Completion assessment

- independent five-concept re-evaluation: PASS
- concept-specific blocker analysis: PASS
- capability-delta analysis: PASS
- false-positive audit: PASS
- human semantic review: PASS
- no automatic SequenceEvidence promotion: PASS
- production isolation: PASS
- Build19-1 through Build19-3B regression: PASS
- Build18 protected regression: PASS
- full Swift regression: PASS
- static validation: PASS
- iOS application build: PASS

## Next stage

Build19-V may now perform **Independent Real-game / Semantic Validation** over the completed Build19 comparison stack.

Build19-V should validate whether real-game explanations remain useful, calibrated, non-repetitive, and semantically grounded without weakening the HOLD decisions established here.
