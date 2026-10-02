# BUILD18_1_ARCHITECTURE_DECISION

Baseline: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`  
Stage: Build18-1 — Grounded WhyNow Specification / Architecture Freeze

## Decision

Add an **Explanation-only projection boundary** after existing Intent/Confidence resolution:

```
Fact
→ ContextChange
→ Effect
→ Intent
→ Outcome
→ Confidence
→ GroundedExplanationContext
→ Explanation
```

`GroundedExplanationContext` is not a resolver. It is a typed projection of already-verified analysis into explanation-safe claims.

## Protected responsibilities

The following are immutable for Build18-1 and remain outside the new layer:

- `MoveIntent`
- `ContextIntentResolver`
- Intent scoring and evidence weights
- confidence thresholds
- Build17-4 three Concept detector semantics
- Build17-5 Concept explanation safety rules
- Locked Regression behavior
- Production source code

## Explanation authority priority

For **explanation selection only**:

1. direct previous-move causality
2. concrete board effect
3. stable counterfactual
4. stable engine PV
5. opening / precedent knowledge
6. geometry

This list does **not** rewrite the current Intent resolver. Geometry is never sufficient for a purpose claim. Opening/precedent knowledge is supporting context and never creates Intent.

## Key semantic rule

An observable Effect answers “what changed.”  
An Intent answers “what this move is for.”  
The first never automatically becomes the second.

Therefore:

- `piece_mobility`, `escape_route_control`, `attack_attacker` remain observed/subordinate explanation material.
- capture, check, promotion, drop, mobility, escape-square reduction, and material outcome remain in their native semantic layers.
- selected Intent wording can be grounded by compatible Evidence, but Evidence details may not invent a different motive.

## Uncertainty

LOW/UNRESOLVED use the same analysis output but switch the verbalization mode. The layer may name a missing evidence reason only when the absence/instability itself is inspectable. Otherwise it uses a limited generic explanation or omission.

## Specialized knowledge

Shikenbisha knowledge enters through a future `SpecializedExplanationContextProvider` attached to the explanation layer. It may provide reference-backed educational cues and required-evidence gates, but no Intent weight/override or confidence override.

## Implementation consequence for Build18-3

Prefer a new projection type/file rather than modifying `ContextEngine.swift`. If Production implementation later requires modifying the protected resolver path, stop and open an Architecture Amendment gate before proceeding.

## Status

**ARCHITECTURE DECISION: FROZEN CANDIDATE**
