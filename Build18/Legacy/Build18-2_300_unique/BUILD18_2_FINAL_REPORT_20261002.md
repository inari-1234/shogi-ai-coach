# BUILD18_2_FINAL_REPORT

Date: 2026-10-02  
Repository: `inari-1234/shogi-ai-coach`  
Branch: `candidate/build18-2-diagnostic-corpus`  
Baseline main: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`

## Verdict

**BUILD18-2 COMPLETE / FROZEN CANDIDATE**

This stage is Corpus / Annotation authority only. Production Code changed: **NO**.

## Corpus

- total records: **316**
- unique positions: **300**
- Build17-3 inherited records: **200**
- new locked-regression educational variations: **4**
- added precedent-only unresolved controls: **112**
- every position has `forbiddenClaims`: **PASS**
- Build17 Locked Regression included: **PASS**

## Mandatory strata

| Stratum | Minimum | Actual | Result |
| --- | ---: | ---: | --- |
| DIRECT_PREVIOUS_MOVE_CAUSALITY | 40 | 40 | PASS |
| TIMING_MOVE_ORDER | 40 | 44 | PASS |
| AMBIGUOUS_MULTI_INTENT | 40 | 302 | PASS |
| EFFECT_INTENT_BOUNDARY | 40 | 168 | PASS |
| COUNTERFACTUAL_DEMANDING | 30 | 43 | PASS |
| ENDGAME_FORCING | 40 | 59 | PASS |
| SHIKENBISHA_DEDICATED | 60 | 61 | PASS |
| ADVERSARIAL_GEOMETRY_HARD | 60 | 187 | PASS |

Cross-tagging is intentional: strata identify the failure mode a position is meant to break, not extra positive Intent labels.

## Safety decisions

1. Build17-3 provisional labels are not promoted. In particular, waiting_move / prophylaxis / sabai remain non-Intent diagnostic targets.
2. Official compact precedent additions keep `previousMove=null`, `primaryIntent=null`, `confidence=UNRESOLVED`, and `whyNowTrigger=NONE_IDENTIFIED`.
3. Geometry/effect observations may be tested, but Effect→Intent promotion remains forbidden.
4. Shikenbisha wording remains Explanation-only through `SpecializedExplanationContextProvider`.
5. Opening/precedent never creates Intent.
6. Missing evidence is represented explicitly rather than synthesized.

## Cross-review

- STRUCTURAL_SCHEMA_REVIEW: **PASS**
- INDEPENDENT_SEMANTIC_SAFETY_REVIEW: **PASS**
- Build18-1 trigger compatibility: **PASS**
- Build18-1 claim-type compatibility: **PASS**
- High-risk Concept promoted to primary Intent: **0**
- Precedent-only record created Intent: **0**
- Precedent-only record fabricated previousMove: **0**

## PASS criteria

- unique positions >= 300: **PASS**
- mandatory quota: **PASS**
- negative/adversarial coverage: **PASS**
- every position has forbiddenClaims: **PASS**
- Build17 Locked Regression included: **PASS**
- Build18-1 trigger / claim type / evidence boundary compatible: **PASS**
- cross-review completed: **PASS**
- Production Code changes: **0 / PASS**

## Next stage

Proceed only to **Build18-3 — Grounded WhyNow Limited Implementation** using Build18-1 and this Build18-2 Frozen Candidate as authority.
