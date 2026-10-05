# Build18-5A Human Semantic Review — Corrective Re-evaluation

Date: 2026-10-04

Authority Corpus SHA-256: 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
Corpus: 360 records / 360 unique positions
Duplicate fingerprints: 0
Legacy Corpus used as authority: NO

This review uses only the authoritative 360 Corpus. Natural shogi wording is not treated as proof.

## respond_to_rapid_attack
- Strong candidate: none concept-specific. Closest safe evidence is B18-2-0006, a Shikenbisha position with HIGH-confidence rook_pawn_response / DIRECT_PREVIOUS_MOVE.
- Near-miss: B18-2-0006 is a direct response but does not encode a rapid-attack event.
- Adversarial: B18-2-0001 guards against geometry/plan overclaim.
- Opening-name trap: B18-2-0006 shows SHIKENBISHA does not upgrade generic response into "急戦対応".
- Geometry trap: direct-response records forbid geometry from replacing the locked generic Intent.
- Ambiguous/unresolved: no concept-specific rapid-attack label or event authority exists.
- Verdict: HOLD.

## sabai
- Strong candidate: none satisfies the full gate; authoritative positive count is 0.
- Near-miss: B18-2-0007 looks natural in Shikenbisha but lacks direct causality, counterfactual, sequence continuity and verified specialized reference.
- Adversarial: all 80 SHIKENBISHA_TO_SABAI records are ADVERSARIAL.
- Opening-name trap: the whole 80-record family proves opening family alone is insufficient.
- Geometry trap: board/mobility appearance is not post-exchange activation/resource preservation.
- Ambiguous/unresolved: all 80 are unresolved / NONE_IDENTIFIED.
- Verdict: HOLD.

## trade_to_transform
- Strong candidate: none; no exchange/transform authority exists.
- Near-miss: B18-2-0010 has a verified bishop-line response plus mobility effect, but effect is not transformation purpose.
- Adversarial: B18-2-0310 is a hard geometry/effect-purpose trap.
- Opening-name trap: opening context cannot supply missing exchange/transformation evidence.
- Geometry trap: 190 EFFECT_INTENT_BOUNDARY records block observed change from becoming purpose.
- Ambiguous/unresolved: no formally traceable Build17 transformation candidate exists in the 360 authority.
- Verdict: HOLD.

## multi_threat
- Strong candidate: none; authoritative concept-specific positive count is 0.
- Near-miss: B18-2-0231 has observable control change but no non-geometry anchor or counterfactual.
- Adversarial: B18-2-0310 is ADVERSARIAL under MULTI_THREAT_WITHOUT_INDEPENDENT_THREATS.
- Opening-name trap: opening labels provide no threat-independence proof.
- Geometry trap: all 80 formal controls keep geometry/control change at EFFECT level.
- Ambiguous/unresolved: all 80 are unresolved / NONE_IDENTIFIED.
- Verdict: HOLD.

## tempo_management
- Strong candidate: none satisfies comparative timing evidence; authoritative positive count is 0.
- Near-miss: B18-2-0007 is a timing-looking quiet move but has insufficient counterfactual and sequence continuity.
- Adversarial: all 80 UNVERIFIED_TIMING_TO_TEMPO_MANAGEMENT records are ADVERSARIAL.
- Opening-name trap: all 80 are SHIKENBISHA and still must not fire.
- Geometry trap: quiet/development appearance does not prove timing dependence.
- Ambiguous/unresolved: all 80 are unresolved / NONE_IDENTIFIED.
- Verdict: HOLD.

Human semantic review: PASS
