# HDS-M Regression Contract Change Evidence Policy

The HDS-M 41/49/69 fixture is a **historical diagnostic regression contract**, not Semantic Authority.

Canonical contract source:
`tools/engine-verify/fixtures/build19-hds-41-49-69.json`

## Rule

Code and workflow assertions that enforce the selected HDS-M plies must match the canonical fixture.

If a commit changes the canonical fixture plies, the same change must include an approved evidence record under:

`Build19/HDS_CONTRACT_CHANGE_EVIDENCE_*.json`

with all of the following fields:

- `schema`: `HDS-CONTRACT-CHANGE-EVIDENCE-1.0`
- `contract`: `HDS-M_REAL_POSITION_SELECTION`
- `previousPlies`: exact previous canonical list
- `newPlies`: exact new canonical list
- `authorityStatus`: `REGRESSION_CONTRACT_ONLY`
- `rationale`: non-empty explanation
- `evidence`: non-empty list of evidence references/results
- `reviewStatus`: `APPROVED`

Without that record, CI must fail.

Changing only a code/workflow expectation without changing the canonical fixture also fails because the enforced surfaces no longer match the fixture.

This guard protects regression-contract changes from silent relaxation. It does not convert 41/49/69 into semantic truth and does not replace VR1B semantic validation.
