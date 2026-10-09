# Build19-VE1-C Issue Backlog — 2026-10-09

This file records threshold-calibration work identified during VE1-A review. It does **not** start VE1-C implementation and does not establish new Semantic Authority.

## VE1C-001 — recalibrate final meaningful-loss threshold for FV24

Status: **OPEN / NOT IMPLEMENTED**

Current threshold: `DeepImportanceSelector.legacyMeaningfulLossThresholdCp = 80`.

Provenance: the `80 cp` threshold predates FV_SCALE=24 and was selected under the older FV16-scale behavior.

Required VE1-C work: determine an FV24-appropriate threshold from behavioral and semantic validation. Do **not** mechanically multiply or divide 80 by an FV_SCALE ratio; the threshold is a product decision boundary and must be re-established against representative positions and desired coaching behavior.
