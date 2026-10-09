# Build19-VE1-A HDS-M Regression Scope — 2026-10-09

## Formal interpretation

**HDS-M PASS（パイプラインと局面選定の契約の回帰）。意味の品質は対象外。**

The current HDS-M PASS establishes only that the configured pipeline completes and that the historical diagnostic position-selection contract remains `[41, 49, 69]`.

It must not be interpreted as semantic-quality validation for the generated coaching content.

## Why the scope is limited

- `makeHDSRegression` supplies synthetic shallow-analysis evaluation values (1200 / 2400 / 3600), so the live regression is strongly biased toward selecting the three historical positions.
- The live deep-analysis path is currently time-bounded (`movetime`). Search variance can therefore affect deep comparison stability and outputs.
- G1-G7 verify the current structured-output gates. They do not independently establish that the coaching meaning is correct.
- VR1B remains the planned place to rebuild/validate semantic quality.

## Authority boundary

`tools/engine-verify/fixtures/build19-hds-41-49-69.json` remains **HISTORICAL_DIAGNOSTIC_FIXTURE_ONLY**. The values 41/49/69 are a regression contract, not Semantic Authority and not a new answer authority.
