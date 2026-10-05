# BUILD19_P_COMPARISON_CONFIDENCE_DESIGN_20261005

## 1. Separation from existing Confidence

`ContextConfidence` answers:

> How confident are we in the selected **single-move Intent**?

`ComparisonConfidence` answers:

> How confident are we that the stated **A-vs-B difference explains or meaningfully characterizes the engine preference**?

These values must remain independent.

Examples:

- MoveIntent confidence HIGH, comparison confidence LOW.
- MoveIntent UNRESOLVED, comparison confidence HIGH for a direct tactical difference.
- Large cp gap, comparison confidence UNRESOLVED because no grounded reason can be isolated.

## 2. Levels

- `HIGH`
- `MEDIUM`
- `LOW`
- `UNRESOLVED`

## 3. Component evidence

Each comparison records:

1. `pairwiseConditionMatch`
2. `rankingStability`
3. `scoreDomainComparability`
4. `firstMoveTraceability`
5. `sequenceStableThroughClaimedHorizon`
6. `differenceSpecificity`
7. `causalStrength`
8. `conflictingDifferenceState`
9. `provenanceCompleteness`

No single component, including evaluation gap, may independently set HIGH.

## 4. HIGH

Required:

- equal-condition pairwise comparison;
- stable candidate ordering;
- score-domain claim is valid;
- all verbalized facts are traceable;
- claimed sequence horizon is stable;
- at least one material DifferenceEvidence item exists;
- dominant difference is DIRECT_CONSEQUENCE or REPLY_LINKED;
- no unresolved contradiction or equally plausible conflicting explanation invalidates the causal wording.

Permitted wording:

- direct/measured causal explanation;
- “Aの方が良い大きな理由は…”
- only for the supported difference.

## 5. MEDIUM

Typical conditions:

- ranking stable;
- factual A/B difference is grounded;
- relevant horizon is stable;
- but causal attribution is incomplete, multiple factors remain, or the strongest evidence is sequence-correlated.

Permitted wording:

- “主な違いは…”
- “この差が評価に関係している可能性があります.”
- “PV上では…の差が現れます.”

Do not say:
- “これが唯一の理由です.”

## 6. LOW

Typical conditions:

- ranking is stable;
- some pairwise differences are observable;
- but continuation needed for the reason is short/unstable;
- or several plausible differences exist with no dominant causal bridge;
- or only weak/proxy metrics differ.

Permitted output:

- factual differences;
- explicit uncertainty;
- score comparison if score itself is stable.

Example:

> Aが上位ですが、短い安定手順では理由を一つに絞れません。確認できる違いは、自玉周辺の相手の利きがA側で少ないことです。

## 7. UNRESOLVED

Any of the following is sufficient:

- pairwise comparison unstable/inverted;
- no equal-condition pair evidence;
- required score domains are not safely comparable;
- no non-score DifferenceEvidence;
- future claim exceeds stable horizon;
- provenance missing;
- evidence contradicts the proposed reason;
- difference is only a generic strategic label.

Output:

- “候補順位は示せても、理由は安全に特定できません.”
- optionally provide raw factual comparison that is safe.

## 8. Evaluation-gap rule

Evaluation difference is not a confidence booster.

Forbidden:

```text
if abs(scoreGap) > 300:
    comparisonConfidence = HIGH
```

A 1000cp gap with no grounded causal difference can remain LOW or UNRESOLVED.

A 30cp gap with a direct, stable tactical distinction can have high evidence confidence for that distinction, while the coaching conclusion should still note that the overall engine preference is close.

Therefore two separate fields are useful:

- `preferenceMagnitude`
- `comparisonConfidence`

## 9. Preference magnitude

For cp/cp only, optional display bands can be calibrated later.

Build19 core should initially retain the exact stable delta and avoid semantic labels such as “huge” unless thresholds are separately specified and validated.

For mate domains, use categorical states rather than cp magnitude.

## 10. Per-claim confidence

Overall comparison confidence is not enough.

Each DifferenceEvidence should have:

- safeToVerbalize
- requiredHorizon
- causalStrength
- claimConfidence

Overall output confidence is the conservative aggregation of the claims actually verbalized.

A HIGH overall engine comparison cannot rescue a LOW future claim.

## 11. Strategic-label gates

### Initiative

Requires direct evidence of reply restriction / forcing continuation. Otherwise unsupported.

### Tempo

Requires verified move-order counterfactual evidence. HOLD concept remains locked.

### Practical complexity

No ComparisonConfidence level can authorize it in initial Build19. It is out of scope until a dedicated metric/human validation exists.

## 12. Beginner-facing confidence behavior

Do not expose every internal flag.

Display behavior:

### HIGH

1. conclusion;
2. biggest difference;
3. short future consequence.

### MEDIUM

1. conclusion;
2. grounded difference;
3. caveat that more than one factor may contribute.

### LOW

1. engine preference;
2. only the concrete difference we can verify;
3. say the reason cannot be narrowed further.

### UNRESOLVED

1. candidate ranking if stable;
2. explicitly say why the reason cannot be safely explained;
3. omit speculative strategy language.

## 13. ComparisonConfidence result

ComparisonConfidence is a **new companion confidence layer** and must never overwrite ContextConfidence.

**COMPARISON CONFIDENCE DESIGN: READY**
