# Build18-5A False Positive Audit

Date: 2026-10-04  
Result: PASS for the evaluation stage.

No Production detector or specialized wording was enabled in Build18-5A. Therefore this audit asks whether any of the five Concepts can be promoted while satisfying the frozen requirement that negative/adversarial false positives remain zero. The answer is no for all five.

## respond_to_rapid_attack
The strongest candidate set is B17-3-011..016. These are safe as generic capture_threat_response + DIRECT_PREVIOUS_MOVE. The negative set B17-3-001..003 and adversarial set B17-3-004..007 show that direct response, proximity, Shikenbisha context, or piece geometry cannot establish the specialized label. Because the frozen authority has no independent machine-verifiable rapid-attack event signal, a Production gate cannot yet distinguish “specific capture threat” from “rapid attack” without semantic overreach.

Decision: HOLD. No new specialized outputs; therefore no new false-positive surface is introduced.

## sabai
B17-3-032/033 are explicit adversarial traps: Shikenbisha + bishop exchange is insufficient because post-exchange activation is unverified. B17-3-037..043 are only provisional and become unresolved under Frozen Corpus requirements. Any gate based on exchange, major-piece move, or mobility would fire on forbidden cases.

Decision: HOLD.

## trade_to_transform
B17-3-032/033 prove an exchange-related generic response but not transformation purpose. B17-3-038/044/045 are negatives and B17-3-046..048 are adversarial controls. Capture/exchange alone is an invalid proxy.

Decision: HOLD.

## multi_threat
Build17 provisional positives only establish multiple newly attacked targets. The key independence criterion—one opponent response cannot neutralize the threats together—was not tested. B17-3-057..061 demonstrate geometry-like cases that must stay negative.

Decision: HOLD.

## tempo_management
B17-3-017..020 are safe generic tenuki cases, not verified tempo-management cases. B17-3-027..031 lack counterfactual and sequence continuity. B17-3-001..004 are negatives; B17-3-005..008 are adversarial. A quiet move, tenuki, or move order alone cannot be treated as timing purpose.

Decision: HOLD.

## Audit conclusion
- proposed Production promotions: 0
- new specialized positive outputs: 0
- known negative/adversarial cases reclassified as positive: 0
- opening-name-only promotions: 0
- geometry-only promotions: 0
- generic Intent changes: 0
- Confidence changes: 0

The audit passes because Build18-5A preserves omission whenever the concept-specific evidence gate is incomplete.
