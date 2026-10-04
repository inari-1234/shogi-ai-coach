# Build18-5A Human Semantic Review

Date: 2026-10-04

This review separates “sounds natural as an explanation” from “is supported by evidence”.

## respond_to_rapid_attack

- Positive candidate: B17-3-011..016. “The opponent advanced and this move answered immediately” is natural and generic capture-threat causality is confirmed.
- Near-miss: B17-3-001..003. A direct rook-pawn response exists, but rapid-attack purpose is not established.
- Adversarial: B17-3-004..007. Superficial similarity was explicitly marked adversarial in Build17.
- Opening-name trap: B17-3-006 is Shikenbisha, but opening context does not prove rapid-attack response.
- Geometry trap: B17-3-007 has bishop-line/geometry context; geometry cannot create the strategy label.
- Ambiguous case: B17-3-011..016 can be accurately described as capture-threat responses, but the broader term “rapid attack” is not independently encoded.

Human verdict: HOLD.

## sabai

- Positive candidate: B17-3-037..043 look like exchange/major-piece activity and are natural sabai candidates.
- Near-miss: B17-3-032/033 are bishop exchanges with a safe generic bishop_line_response.
- Adversarial: B17-3-032/033 are explicitly confirmed adversarial for sabai because post-exchange activation is unverified.
- Opening-name trap: Shikenbisha + exchange is specifically forbidden as sufficient evidence.
- Geometry trap: major-piece activity or increased mobility can look like sabai without proving continuation/resource preservation.
- Ambiguous case: B17-3-037..043 remain UNRESOLVED_DIAGNOSTIC because the sequence after the candidate move is not sufficient.

Human verdict: HOLD.

## trade_to_transform

- Positive candidate: B17-3-037/039/040/041/042/043 are plausible exchange/transformation candidates.
- Near-miss: B17-3-032/033 contain an exchange but only a generic bishop-line response is proven.
- Adversarial: B17-3-046..048 are explicit superficial-similarity traps.
- Opening-name trap: Shikenbisha-like geometry does not show that an exchange was chosen to transform roles/position.
- Geometry trap: a changed piece relation after capture is an EFFECT, not proof of transformation purpose.
- Ambiguous case: B17-3-038 is negative despite being in the same Shikenbisha-like family, showing that family/context cannot supply the missing intent.

Human verdict: HOLD.

## multi_threat

- Positive candidate: B17-3-040/044/054/056/100 have two or more newly attacked targets.
- Near-miss: any position with multiple attacked pieces but no proof that the threats are independent.
- Adversarial: B17-3-057..061 fail even the multi-target geometric threshold and are confirmed adversarial.
- Opening-name trap: Shikenbisha-like geometry does not establish multi-threat purpose.
- Geometry trap: the provisional positives themselves demonstrate the trap—multiple attacked targets are not yet multiple independent threats.
- Ambiguous case: B17-3-040 has three newly attacked targets but still lacks one-best-reply independence.

Human verdict: HOLD.

## tempo_management

- Positive candidate: B17-3-017..020 are natural “timing/tenuki” explanations.
- Near-miss: B17-3-027..031 are Shikenbisha quiet/timing-looking moves but lack counterfactual and sequence continuity.
- Adversarial: B17-3-005..008 are confirmed adversarial controls.
- Opening-name trap: B17-3-006 and B17-3-027..031 show that Shikenbisha context does not prove tempo purpose.
- Geometry trap: a normal developing/quiet move may look like time management without any comparative timing evidence.
- Ambiguous case: B17-3-017..020 are safe as tenuki, but “tenuki” does not itself prove that the move was chosen to manage tempo.

Human verdict: HOLD.

## Overall semantic conclusion

All five concepts remain semantically useful educational ideas, but their current authority cannot support the specialized purpose claims at Production precision. Generic verified wording remains preferable to a natural-sounding but unsupported specialized label.
