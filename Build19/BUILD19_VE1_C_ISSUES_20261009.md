# Build19-VE1-C Issue Backlog — 2026-10-09

This file records threshold-calibration work identified during VE1-A review. It does **not** start VE1-C implementation and does not establish new Semantic Authority.

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

## Required VE1-C work

For each threshold above:

1. establish representative FV24 positions and expected coaching/search behavior;
2. measure the FV24 outputs using pinned engine/runtime provenance;
3. choose the threshold from semantic/behavioral evidence rather than numeric rescaling;
4. add regression tests at both sides of each chosen decision boundary;
5. keep historical FV16 records unchanged.

The current VE1-A work only inventories and isolates these dependencies. It does not authorize threshold changes.
