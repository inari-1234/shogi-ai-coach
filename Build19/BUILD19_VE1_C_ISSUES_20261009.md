# Build19-VE1-C Issue Backlog — 2026-10-09

This file records threshold-calibration and semantic-scoring work identified during VE1-A/VE1-B review. It does **not** start VE1-C implementation and does not establish new Semantic Authority.

## VE1C-001 — recalibrate cp-scale-dependent thresholds for FV24

Status: **OPEN / NOT IMPLEMENTED**

The following production thresholds were introduced before the FV_SCALE=24 runtime authority and therefore require explicit semantic/behavioral recalibration. They must **not** be mechanically multiplied or divided by an FV_SCALE ratio.

### Final important-position selection

- `DeepImportanceSelector.legacyMeaningfulLossThresholdCp = 80`
  - Controls whether a selected deep-analysis position is meaningful enough to retain.

### Adaptive deep-comparison search/stability

- `AdaptiveComparisonAnalyzer.closeCandidateThresholdCp = 40`
  - Controls confirmation when top candidates are close.
- `AdaptiveComparisonAnalyzer.lossSwingThresholdCp = 120`
  - Controls whether cross-tier loss movement is classified as comparison instability.
- `AdaptiveComparisonAnalyzer.decisiveConfirmationThresholdCp = 1_500`
  - Controls confirmation of a decisive non-mate score.

### Phase review / coaching

- evaluation swing `>= 200 cp`
  - Contributes to middlegame transition scoring and human-readable evidence.
- evaluation swing `>= 350 cp`
  - Contributes to endgame transition scoring.
- representative stable loss `>= 300 cp`
  - Changes opening/middlegame coaching theme text.
- evaluation-difference bands `<100`, `100..<300`, `300..<700`, `>=700 cp`
  - Change the user-facing description of the recommended-vs-actual evaluation difference.

### Required VE1C-001 work

For each threshold above:
1. establish representative FV24 positions and expected coaching/search behavior;
2. measure FV24 outputs using pinned engine/runtime provenance;
3. choose the threshold from semantic/behavioral evidence rather than numeric rescaling;
4. add regression tests at both sides of each chosen decision boundary;
5. keep historical FV16 records unchanged.

## VE1C-002 — mate sign semantics in importance / meaningfulness

Status: **OPEN / NOT IMPLEMENTED**

Current risk: logic based only on `bestScoreText.hasPrefix("mate ")` cannot distinguish a winning mate from `mate -N` (the side to move is being mated). Search fluctuation could therefore incorrectly award the missed-mate importance bonus when the best line is a negative mate and the actual line is non-mate.

Required semantics:
- only positive mate values (`mate N`, `N > 0`) may qualify as a missed winning mate when the actual line does not preserve that winning mate;
- negative mate values (`mate -N`) must never be classified as a missed winning mate;
- score parsing should use structured mate sign/value rather than string prefix alone where practical;
- add at least one positive-mate regression and one negative-mate regression;
- ensure the same sign rule is used by both ranking and meaningfulness decisions.

This item remains VE1-C scope unless VE1-B must touch the exact same scoring abstraction for its evidence-model work. If VE1-B changes that shared abstraction, it may add structural support, but VE1-C owns the semantic acceptance rule.

## Boundary

VE1-A remains formally PASS. VE1-B owns runtime evidence/search-contract hardening. VE1-C owns semantic threshold recalibration and mate-sign semantic acceptance. No historical expected values may be rewritten merely to fit new runtime output.
