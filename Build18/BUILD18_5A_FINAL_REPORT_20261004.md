# Build18-5A Final Report — Corrective Re-evaluation

Date: 2026-10-04
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build18-5a-concept-reevaluation

## Final verdict

Build18-5A: PASS / COMPLETE
Corrective Re-evaluation: PASS
PARENT ACCEPTANCE READY

## Authority

Authority Corpus SHA-256: 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
Authority Corpus records: 360
Authority Corpus unique positions: 360
Duplicate fingerprints: 0
Legacy Corpus used as authority: NO
Legacy Build18/Legacy/Build18-2_300_unique/: NON-AUTHORITATIVE; excluded

Recomputed strata:
DIRECT_PREVIOUS_MOVE_CAUSALITY 60
TIMING_MOVE_ORDER 80
AMBIGUOUS_MULTI_INTENT 170
EFFECT_INTENT_BOUNDARY 190
COUNTERFACTUAL_DEMANDING 80
ENDGAME_FORCING 50
SHIKENBISHA_DEDICATED 80
ADVERSARIAL_HUMAN_NATURAL_GEOMETRY_HARD 301

Example class: POSITIVE 59 / NEGATIVE 57 / ADVERSARIAL 244

## Corrected decisions

respond_to_rapid_attack: HOLD
sabai: HOLD
trade_to_transform: HOLD
multi_threat: HOLD
tempo_management: HOLD

PROMOTE count: 0
HOLD count: 5
REJECT / MERGE count: 0
Unassessed count: 0

The five HOLD decisions were independently re-derived from the 360 authority and were not copied from the prior 316/300 evaluation.

## Key evidence

- respond_to_rapid_attack: concept-specific authority absent; generic direct-response evidence cannot prove "rapid attack".
- sabai: 80 formal sabai-risk controls, all ADVERSARIAL, positive 0.
- trade_to_transform: no exchange/transformation authority; effect-to-purpose promotion remains blocked.
- multi_threat: 80 formal controls = 53 ADVERSARIAL + 27 NEGATIVE, positive 0; reply independence is unverified.
- tempo_management: 80 formal timing controls, all ADVERSARIAL, positive 0.

Build17 source IDs were reused only where the 360 Corpus exposes an explicit migration. Untraceable prior IDs were classified UNVERIFIED LEGACY REFERENCE and excluded from promotion evidence.

## Safety / scope

Production Code changes: 0
GroundedExplanationContext changed: NO
ContextExplanation changed: NO
ContextEngine changed: NO
MoveIntent changed: NO
ContextIntentResolver changed: NO
weights changed: NO
confidence thresholds changed: NO
Concept detector added: NO
Frozen labels changed: NO
Frozen authority changed: NO
Old 316/300 corpus counts mixed into final decision: NO

False-positive audit: PASS
Human semantic review: PASS
Blocking issues: NONE

## Next stage

PROMOTE_TO_LIMITED_EXPLANATION = 0.
Build18-5B is not started.
Next: Build18-6 — Real-game E2E / Explanation Quality Audit
