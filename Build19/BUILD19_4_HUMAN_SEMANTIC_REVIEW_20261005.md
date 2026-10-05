# Build19-4 Human Semantic Review

Date: 2026-10-05
Status: CANDIDATE / VALIDATION PENDING

## Review question

Does Build19-1 through Build19-3B provide enough new evidence to safely change any of the five Build18-5A HOLD decisions?

## Review standard

The review distinguishes:

- **fact/effect observability** — the engine/core can observe a concrete event;
- **comparative evidence** — A/B branches differ in a typed way;
- **causal support** — the evidence can justify a claim about why the difference matters;
- **specialized concept semantics** — the evidence is sufficient to name a higher-level shogi concept.

A gain in the first three categories does not automatically satisfy the fourth.

## Concept review

### respond_to_rapid_attack — HOLD

Build19 improves branch comparison and continuation evidence, but it does not independently classify the opponent action as a rapid attack. The existing direct rook-pawn response family proves response causality, not the specialized category. Promotion would turn an opening-pattern or speed heuristic into semantic authority. HOLD is required.

### sabai — HOLD

Build19 materially improves evidence here: exchange/recapture events, stable continuation, board snapshots, and counterfactual branches now exist. However, sabai is not synonymous with `an exchange happened` or `a major piece became more mobile`. The current system lacks authoritative positives and explicit semantic gates for activity quality and active-resource preservation. The existing 80 adversarial cases are therefore still more informative than the newly available raw sequence facts. HOLD is required.

### trade_to_transform — HOLD

Build19 can now verify exchange sequences and before/after board states, closing two former observation gaps. But the remaining step is exactly the dangerous one: inferring transformation *purpose* from transformation *effect*. No concept-specific positives or role-transformation semantic authority exist. HOLD is required.

### multi_threat — HOLD

Build19 can show stable continuations and observed replies, but one PV is not a proof over the legal reply set. `Multiple things are attacked` is not equivalent to `multiple independent threats`, and the system does not prove that one opponent response cannot neutralize them all. With zero positive semantic authority and 80 existing negative/adversarial controls, HOLD is required.

### tempo_management — HOLD

Build19 provides relative-ply timelines and counterfactual branches, which are necessary infrastructure for timing analysis. It still lacks matched move-order semantic experiments showing that a consequence changes specifically because of timing/order. Inferring tempo management from branch length, a quiet move, or engine preference would remain overclaiming. HOLD is required.

## Cross-cutting review

The most important Build19-4 conclusion is that infrastructure readiness and semantic readiness are different states.

Build19-2/3 make future concept evaluation more feasible, especially for `sabai`, `trade_to_transform`, and `tempo_management`, but the safe current decision is not to expose any of them in production coaching.

No concept should be rejected permanently: each remains a valid future research target once positive/negative authority is built to match the new typed evidence system.

## Candidate human-semantic verdict

- PROMOTE_TO_LIMITED_EXPLANATION: 0
- HOLD: 5
- REJECT_OR_MERGE: 0

No production concept output is authorized in Build19-4.
