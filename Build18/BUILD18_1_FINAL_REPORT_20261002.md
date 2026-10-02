# BUILD18_1_FINAL_REPORT

Date: 2026-10-02  
Repository: `inari-1234/shogi-ai-coach`  
Baseline main: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`

## Verdict

**BUILD18-1 COMPLETE / FROZEN CANDIDATE**

This stage is specification/architecture only. No Production Code was changed.

## Baseline audit

- GitHub `main` HEAD verified at `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`.
- Existing `MoveContextAnalysis` already separates Fact / ContextChange / Effect / Outcome / Intent candidates / selected Intent / Confidence / Evidence.
- Existing `ContextExplanationGenerator` still uses fixed `whyNowText(for: selectedIntent)`, confirming Build18's primary gap.
- Existing Build17-4/5 rules preserve the three safe Concept signals as explanation-only/subordinate material and prohibit purpose hallucination.
- Existing knowledge handling reinforces an existing non-geometry anchor; raw opening/precedent does not independently create Intent.
- Existing engine/counterfactual handling is stability-gated and primarily reinforcing, with explicit mate/threatmate exceptions.
- Build17-3 false-positive audit remains authoritative for deferred concepts; sabai/prophylaxis/waiting etc. are not promoted by this stage.

## Frozen decisions

1. `GroundedExplanationContext` is an Explanation-only projection layer after Confidence.
2. Why-now trigger v1 is narrowed to causal/verified timing classes; broad “opponent plan” inference is excluded.
3. Claim Type boundary is frozen: FACT / CONTEXT_CHANGE / EFFECT / INTENT / OUTCOME / UNCERTAINTY.
4. Effect→Intent automatic promotion is strictly forbidden.
5. Every concrete verbalized claim requires traceability.
6. Geometry never supports purpose alone.
7. Opening/precedent never creates Intent.
8. LOW/UNRESOLVED never emit assertive purpose claims.
9. Missing-evidence explanations are emitted only when the missing/unstable condition itself is verifiable.
10. Shikenbisha enters only through an Explanation-only specialized provider boundary.

## Deliverables

- BUILD18_1_GROUNDED_EXPLANATION_SCHEMA_20261002.json
- BUILD18_1_WHY_NOW_TRIGGER_V1_20261002.json
- BUILD18_1_CLAIM_TYPE_MATRIX_20261002.json
- BUILD18_1_EVIDENCE_COMPATIBILITY_MATRIX_20261002.json
- BUILD18_1_UNCERTAINTY_RULES_20261002.json
- BUILD18_1_SHIKENBISHA_BOUNDARY_20261002.json
- BUILD18_1_QUALITY_RUBRIC_20261002.json
- BUILD18_1_ARCHITECTURE_DECISION_20261002.md
- BUILD18_1_FINAL_REPORT_20261002.md

## PASS criteria audit

- All explanation claims traceable to Evidence/signals: PASS by schema requirement.
- Effect→Intent promotion prohibition: PASS.
- Intent / Confidence mutation forbidden: PASS.
- Geometry-only purpose prohibition: PASS.
- LOW / UNRESOLVED assertion prohibition: PASS.
- Missing-evidence wording rules: PASS.
- Shikenbisha generic resolver contamination blocked: PASS.
- Claim Type boundary: PASS.
- Quality Rubric v1: PASS.
- Build18-2 annotation connection: PASS; schema fields map directly to annotation requirements.
- Build17 Locked Regression protection: PASS; resolver path remains immutable.

## Next stage

Proceed to **Build18-2 — Diagnostic Corpus / Annotation Design & Freeze** using this Build18-1 Frozen Candidate as input authority.
