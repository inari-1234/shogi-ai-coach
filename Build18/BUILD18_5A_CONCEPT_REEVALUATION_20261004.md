# Build18-5A Concept Re-evaluation — Corrective Re-evaluation

Date: 2026-10-04
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build18-5a-concept-reevaluation
Status: PASS / COMPLETE — CORRECTIVE RE-EVALUATION PASS — PARENT ACCEPTANCE READY

## Authority Audit

Authority Corpus: BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json
SHA-256: 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
Corpus: 360 records / 360 unique positions
Duplicate fingerprints: 0

Recomputed minimum values:
- DIRECT_PREVIOUS_MOVE_CAUSALITY: 60
- TIMING_MOVE_ORDER: 80
- AMBIGUOUS_MULTI_INTENT: 170
- EFFECT_INTENT_BOUNDARY: 190
- COUNTERFACTUAL_DEMANDING: 80
- ENDGAME_FORCING: 50
- SHIKENBISHA_DEDICATED: 80
- ADVERSARIAL_HUMAN_NATURAL_GEOMETRY_HARD: 301
- Example class: POSITIVE 59 / NEGATIVE 57 / ADVERSARIAL 244

Build18/Legacy/Build18-2_300_unique/ and all 316-record / 300-unique values are NON-AUTHORITATIVE LEGACY and were excluded from all corrected decisions.

## Decision summary

| Concept | Authoritative 360-Corpus evidence | Negative / adversarial coverage | Decision |
|---|---|---|---|
| respond_to_rapid_attack | No concept-specific rapid-attack authority. 60 direct-causality records, including 45 DIRECT_ROOK_PAWN_RESPONSE, prove generic response causality only. | Concept-specific coverage 0; generic hard-adversarial geometry coverage 301. | HOLD |
| sabai | 80 records target SHIKENBISHA_TO_SABAI; all remain unresolved for specialized purpose. | 80 ADVERSARIAL / 0 POSITIVE. | HOLD |
| trade_to_transform | No trade_to_transform, transform, or exchange-specific authority exists. | Dedicated coverage 0; relevant EFFECT_INTENT_BOUNDARY 190 and hard geometry coverage 301. | HOLD |
| multi_threat | 80 records target MULTI_THREAT_WITHOUT_INDEPENDENT_THREATS. | 53 ADVERSARIAL + 27 NEGATIVE / 0 POSITIVE. | HOLD |
| tempo_management | 80 records target UNVERIFIED_TIMING_TO_TEMPO_MANAGEMENT. | 80 ADVERSARIAL / 0 POSITIVE. | HOLD |

## respond_to_rapid_attack — HOLD

Evidence: the authoritative Corpus contains no respond_to_rapid_attack/rapid-attack event authority. It contains 60 DIRECT_PREVIOUS_MOVE_CAUSALITY records. The 45-record DIRECT_ROOK_PAWN_RESPONSE family is HIGH-confidence rook_pawn_response with DIRECT_PREVIOUS_MOVE; B18-2-0006 is a Shikenbisha example. This proves a direct response, not the broader specialized proposition "rapid attack".

Build17 source tracking: B17-3-011..016 are not migrated into the authoritative 360 Corpus and are UNVERIFIED LEGACY REFERENCE for promotion purposes. B17-3-001..006 do have formal migration links but support generic rook_pawn_response only.

Missing Evidence: machine-verifiable concrete opponent rapid-attack event authority.
False-positive risk: MEDIUM_HIGH.
Allowed wording: generic direct-response wording tied to the selected generic Intent and verified previous move.
Forbidden wording: "急戦に対応した" or equivalent specialized purpose without an independently verified rapid-attack event.
Production scope: no specialized output; Intent, Confidence, weights and resolver unchanged.
Future regression: add explicit rapid-attack positives and near-miss/adversarial controls with zero known false positives.

## sabai — HOLD

Evidence: 80 SHIKENBISHA_HIGH_RISK_GUARD records target SHIKENBISHA_TO_SABAI. All 80 are ADVERSARIAL, primaryIntent=unresolved, Confidence=UNRESOLVED, trigger=NONE_IDENTIFIED, positive coverage=0. B18-2-0007 explicitly records insufficient counterfactual, insufficient sequence continuity and unverified specialized reference.

Build17 source tracking: B17-3-027, B17-3-029 and B17-3-030 formally migrate to B18-2-0007..0009 and remain adversarial/unresolved. Prior B17-3-032..043 references are not traceable in the 360 authority and are excluded from promotion evidence.

Missing Evidence: exchange/contact; major-piece activation before/after; post-exchange continuation; active resource preservation; stable sequence/counterfactual.
False-positive risk: VERY_HIGH.
Allowed wording: verified generic facts/effects only.
Forbidden wording: sabai from Shikenbisha name, exchange appearance, mobility, or major-piece move alone.
Production scope: deferred explanation-only; no detector or integration.
Future regression: add confirmed positive sequences satisfying the full joint gate and retain all 80 formal adversarial cases as non-firing controls.

## trade_to_transform — HOLD

Evidence: the authoritative Corpus contains no trade_to_transform, transform, or exchange-specific authority. The 190 EFFECT_INTENT_BOUNDARY records establish that observed board/effect change must not be promoted into purpose. B18-2-0010 is a safe bishop_line_response with a mobility effect; it does not prove transformation purpose.

Build17 source tracking: previously cited B17-3-032..048 mappings are absent from the authoritative 360 Corpus and are UNVERIFIED LEGACY REFERENCE for promotion purposes.

Missing Evidence: verified exchange; before/after role or position transformation; sequence/counterfactual proving transformation relevance.
False-positive risk: HIGH.
Allowed wording: verified Fact/Effect wording only.
Forbidden wording: transformation-purpose wording from capture, promotion, mobility, or relation change alone.
Production scope: deferred explanation-only.
Future regression: add genuine exchange/transformation positives and near-miss controls while preserving the EFFECT-to-INTENT boundary.

## multi_threat — HOLD

Evidence: 80 GEOMETRY_EFFECT_BOUNDARY records target MULTI_THREAT_WITHOUT_INDEPENDENT_THREATS. All are unresolved with no supporting intent evidence. B18-2-0231 is a representative NEGATIVE; B18-2-0310 is ADVERSARIAL.

Negative/adversarial coverage: 53 ADVERSARIAL + 27 NEGATIVE = 80; positive 0.

Build17 source tracking: previously cited B17-3-040/044/054/056/057..061/100 mappings are absent from the authoritative 360 Corpus and are excluded from promotion evidence.

Missing Evidence: multiple independent concrete threats; proof one opponent response cannot neutralize all threats; stable continuation/counterfactual.
False-positive risk: MEDIUM_HIGH.
Allowed wording: concrete attacked/control-square effects only.
Forbidden wording: "複数の狙い" or "どちらかは必ず通る" without reply-independence evidence.
Production scope: deferred explanation-only.
Future regression: add one-best-reply independence checks and true positive continuations while all 80 formal controls remain non-firing.

## tempo_management — HOLD

Evidence: 80 SHIKENBISHA_HIGH_RISK_GUARD records target UNVERIFIED_TIMING_TO_TEMPO_MANAGEMENT. All 80 are ADVERSARIAL with zero positive cases. B18-2-0007 records INSUFFICIENT_COUNTERFACTUAL and INSUFFICIENT_SEQUENCE_CONTINUITY.

Build17 source tracking: B17-3-027/029/030 formally migrate to B18-2-0007..0009 and remain adversarial. Previous B17-3-017..020 and 028/031 references are not formally migrated and are excluded from promotion evidence.

Missing Evidence: explicit move-order/tempo comparison; verified timing dependence; counterfactual or sequence continuity.
False-positive risk: VERY_HIGH.
Allowed wording: verified generic move/causality facts only.
Forbidden wording: quiet move, tenuki, development order or fast-looking move as tempo-management proof.
Production scope: deferred explanation-only.
Future regression: compare at least two move orders/sequences, prove timing dependence, and keep all 80 authoritative adversarial controls non-firing.

## Final decision

PROMOTE_TO_LIMITED_EXPLANATION: 0
HOLD: 5
REJECT / MERGE: 0
Unassessed: 0
Production Code changes: 0
Frozen authority changes: 0
Legacy Corpus used as authority: NO

Build18-5A: PASS / COMPLETE
Corrective Re-evaluation: PASS
Parent acceptance status: PARENT ACCEPTANCE READY
Next stage: Build18-6 — Real-game E2E / Explanation Quality Audit
