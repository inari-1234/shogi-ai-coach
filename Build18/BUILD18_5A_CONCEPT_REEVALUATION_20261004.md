# Build18-5A Concept Re-evaluation

Date: 2026-10-04  
Stage: Shikenbisha / Deferred Concept Re-evaluation  
Verdict: PASS (evaluation complete; no Production integration performed)

## Authority

- main baseline: fd35c8b990379ebccbf1711d1cc0fa4a8464d53d
- Build18-1 specification HEAD: ea37b850c72fd07b328adbd046892b647edf8c2f
- Build18-2 annotation schema SHA-256: 3b7453198c25504dbb94226fc9863a2e53a9b86d29b19c1398b5ae6b32884d1a
- Build18-2 authority bundle SHA-256: 101a30f4a6965aa810317cab046120461e1513d5514f68baae14b8ba5c969c12
- Build18-2 frozen diagnostic corpus SHA-256: 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
- Build18-3 freeze candidate HEAD: 054f30a54463d472cc96a16c49cd14d6e0e28b45
- Build18-3 validated implementation HEAD: 3ef903e5762e695646204987196e8b8fff500155
- Build18-4V freeze evidence package SHA-256: 3f298c3c87bf43d40365fb53196d4e5649cb2fa352a592b6d5489f50a69c39c4
- Build18-4V freeze manifest SHA-256: eeb499fa73d54e380ab1af6b39c2f9abb088700af814ce65ad9b6685aaa19324

Frozen corpus audit: 316 records / 300 unique positions. Required diagnostic strata are present, including TIMING_MOVE_ORDER, COUNTERFACTUAL_DEMANDING, EFFECT_INTENT_BOUNDARY, AMBIGUOUS_MULTI_INTENT, SHIKENBISHA_DEDICATED and adversarial geometry coverage.

## Decision summary

| Concept | Build17 evidence | Frozen-corpus observation | Decision |
|---|---|---|---|
| respond_to_rapid_attack | 6 confirmed positive / 3 negative / 4 adversarial | The six positives map safely to generic capture_threat_response + DIRECT_PREVIOUS_MOVE, but no dedicated machine-verifiable rapid-attack event authority exists. | HOLD |
| sabai | 7 provisional positive / 4 negative / 4 adversarial; 0 confirmed positive | Two safe records only prove bishop_line_response; seven specialized candidates remain UNRESOLVED and lack post-exchange continuation/resource-preservation evidence. | HOLD |
| trade_to_transform | 8 provisional positive / 3 negative / 3 adversarial; 0 confirmed positive | Two safe exchange cases prove bishop_line_response, not transformation purpose; remaining candidates are unresolved. | HOLD |
| multi_threat | 5 provisional positive / 3 negative / 9 adversarial; 0 confirmed positive | Candidate geometry shows multiple attacked targets, but independence under one best reply is not verified; Frozen candidates remain unresolved. | HOLD |
| tempo_management | 9 provisional positive / 4 negative / 4 adversarial; 0 confirmed positive | Four safe cases prove generic tenuki, not tempo purpose; Shikenbisha timing candidates lack sequence/counterfactual timing dependence. | HOLD |

## A. respond_to_rapid_attack — HOLD

### Evidence
Build17 positions B17-3-011 through B17-3-016 are confirmed positive exposures. In the Frozen Corpus they are CONFIRMED_SAFE with:
- primaryIntent = capture_threat_response
- confidence = HIGH
- whyNowTrigger = DIRECT_PREVIOUS_MOVE
- supportingEvidenceIDs includes ev_capture_threat_response

Negative controls B17-3-001..003 and adversarial controls B17-3-004..007 remain valid separators.

### Missing Evidence
A machine-verifiable concept-specific signal equivalent to concrete_opponent_rapid_attack_event is absent. Current generic evidence proves a direct capture-threat response, but does not independently prove the broader specialized claim “rapid attack”.

### False-positive risk
MEDIUM_HIGH. Reusing capture_threat_response as a proxy would collapse “specific immediate capture threat” into “opponent rapid attack”, producing an unsupported strategy label.

### Allowed wording
Generic wording only, tied to the frozen generic intent and direct previous-move causality, e.g. “直前の相手の手で生じた取り込みの脅威に応じています。”

### Forbidden wording
“急戦に対応しています” or equivalent specialized strategy wording unless a concrete rapid-attack event is independently verified.

### Scope
No Production specialized label. Do not modify Intent, confidence, score, evidence weight, or resolver behavior.

### Regression requirement
Any future promotion must retain all 6 confirmed positives, reject all 3 negatives and 4 adversarial controls, and add explicit rapid-attack-event positives/near-misses that are independent of opening name.

## B. sabai — HOLD

### Evidence
Build17 recorded 7 positive exposures but 0 confirmed positives. B17-3-032/033 are confirmed ADVERSARIAL for sabai: bishop exchange in Shikenbisha is insufficient because post-exchange activation is unverified. B17-3-037..043 are only PROVISIONAL specialized candidates; Frozen records remain UNRESOLVED_DIAGNOSTIC except for generic non-sabai explanations.

### Missing Evidence
Required evidence is not jointly present:
- exchange/contact
- major-piece activation before/after
- post-exchange continuation
- active resource preservation
- stable sequence or counterfactual evidence

### False-positive risk
VERY_HIGH. “Shikenbisha + exchange”, major-piece movement, or mobility gain can look natural while still failing the causal sabai claim.

### Allowed wording
Only generic verified exchange/activation facts already supported by the frozen generic layers.

### Forbidden wording
“さばいた”, “駒をさばくため”, or equivalent sabai-purpose wording without the full evidence gate.

### Scope
Explanation-only candidate remains deferred; no Production integration.

### Regression requirement
Future gate must include confirmed post-exchange activation continuations, explicit resource preservation, and adversarial Shikenbisha exchange traps including B17-3-032/033.

## C. trade_to_transform — HOLD

### Evidence
Build17: 8 positive exposures, 0 confirmed positives, 3 negative, 3 adversarial. B17-3-032/033 are safe generic bishop-line responses but do not prove transformation purpose. B17-3-037/039/040/041/042/043 remain unresolved in Frozen Corpus.

### Missing Evidence
- verified exchange
- before/after role or position transformation
- sequence/counterfactual demonstrating that the transformation is relevant to the move choice

### False-positive risk
HIGH. Any capture or exchange can be retrospectively narrated as a transformation.

### Allowed wording
State the verified exchange and concrete before/after board changes only.

### Forbidden wording
“交換して局面を変える狙い”, “役割を変えるための交換” unless transformation relevance is proven.

### Scope
Deferred explanation-only concept; no Production integration.

### Regression requirement
Future tests must separate ordinary exchange, tactical recapture, and genuine role/position transformation; B17-3-038/044/045 negatives and B17-3-046..048 adversarial controls must remain non-firing.

## D. multi_threat — HOLD

### Evidence
Build17: 5 provisional positives, 0 confirmed positives, 3 negative, 9 adversarial. Candidate examples such as B17-3-040, 044, 054, 056 and 100 only establish two or more newly attacked geometric targets. Frozen candidates remain UNRESOLVED_DIAGNOSTIC.

### Missing Evidence
- multiple independent concrete threats
- proof that one opponent response cannot neutralize them simultaneously
- stable continuation or counterfactual

### False-positive risk
MEDIUM_HIGH. Geometry alone confuses “attacking multiple pieces” with “multiple independent threats”.

### Allowed wording
Concrete attacked-target/effect wording only when independently verified as an EFFECT.

### Forbidden wording
“二つ以上の狙いを同時に作った”, “どちらかは必ず通る” without reply-independence and continuation evidence.

### Scope
Deferred explanation-only concept; no Production integration.

### Regression requirement
Future promotion requires one-best-reply independence checks and must reject B17-3-057..061 plus all geometry-only multi-target cases.

## E. tempo_management — HOLD

### Evidence
Build17: 9 provisional positives, 0 confirmed positives, 4 negative, 4 adversarial. B17-3-017..020 are Frozen CONFIRMED_SAFE as generic tenuki with DIRECT_PREVIOUS_MOVE, but they contain no concept-specific timing comparison. B17-3-027..031 remain UNRESOLVED with INSUFFICIENT_COUNTERFACTUAL / INSUFFICIENT_SEQUENCE_CONTINUITY.

### Missing Evidence
- explicit move-order or tempo comparison
- verified timing dependence
- stable counterfactual or sequence continuity

### False-positive risk
VERY_HIGH. Quiet moves, tenuki, normal development order, and “fast-looking” moves can all be mislabeled as tempo management.

### Allowed wording
Generic tenuki/direct-response wording already supported by the selectedIntent.

### Forbidden wording
“手順を調整した”, “一手得した”, “テンポを管理した” without explicit comparative evidence.

### Scope
Deferred explanation-only concept; no Production integration.

### Regression requirement
Future promotion must compare at least two move orders or sequences, demonstrate timing dependence, and keep B17-3-001..008 negative/adversarial cases non-firing.

## Final evaluation

All 5 Concepts have a completed evidence-backed decision. No Concept is promoted in Build18-5A.

Build18-5A: PASS  
Production promotions: 0  
HOLD: 5  
REJECT / MERGE: 0  
Production source changes: 0

Next stage: Build18-6.
