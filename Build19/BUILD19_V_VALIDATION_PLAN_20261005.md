# Build19-V — Independent Real-game / Semantic Validation Plan

Date: 2026-10-05
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build19-v-real-game-semantic-validation
Upstream authority: Build19-4 final HEAD `a81cc5da27713207888bb65c6357b8eb081f4ae3`

## Purpose

Independently validate the completed Build19 comparison stack on real-game positions without changing `Sources/ShogiCoachCore`.

Validation chain:

`real KIF position -> engine candidate pair -> CandidateAnalysis -> CandidateComparison -> SequenceCounterfactualEvidence -> ComparisonConfidence -> CoachingExplanation -> repetition presentation`

## Real-game source

Reuse the Build18-6 authority source and deterministic selection path:

- source ID: `denryusen:dr4-hardware2:2024`
- official KIF archive: `https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip`
- usage: validation fixture only

The 30 Build19-P gap records remain requirements only. They are used to recover exact real-game positions and expected sampling metadata, never as pairwise truth labels.

## Candidate acquisition

For every selected position:

1. Discover Top1/Top2 with the pinned YaneuraOu engine and Suisho5 evaluation.
2. Compare Best vs Actual when the actual game move differs from Best.
3. If the actual move equals Best, compare Top1 vs Top2.
4. Re-search both compared root moves separately under the same candidate-specific search condition.
5. Use a low-search and high-search pass to estimate ranking and continuation stability.
6. Never infer causal confidence from centipawn magnitude alone.

Pinned engine authority:

- YaneuraOu commit: `a5ee2786c0030edc7d4a1cdfe94b04dffec55493`
- evaluation file: repository `scripts/fetch_eval.sh` Suisho5 source
- Threads: 1
- Hash: 128 MB
- high movetime: 120 ms per root candidate
- low movetime: 40 ms per root candidate
- MultiPV discovery: 2

Candidate-specific root restriction is applied equally to both compared candidates. The pairwise engine context therefore represents the same engine/eval/time condition, while the root move is the candidate identity rather than a differing search condition.

## Samples

### Requirement-linked semantic sample

- 30 exact Build19-P records.
- Each `src` index must resolve to the regenerated deterministic Build18-6R1 human-review candidate at the same ply and actual move.
- Any mismatch fails closed.

### Contiguous repetition sample

- at least 12 true consecutive plies from one deterministically selected real game.
- comparison explanations are passed through `ComparisonCoachingExplanationRepetitionState` in real ply order.
- presentation-only behavior is checked independently of semantic explanation.

## Blocking rules

Build19-V fails if any of the following occurs:

- Build19-P source record cannot be recovered exactly.
- Candidate PV first move does not match the candidate root move.
- pairwise search conditions differ.
- unstable comparison receives resolved causal confidence.
- score-only evidence becomes a causal explanation.
- an evidence ID withheld by 3A is used by 3B.
- sequence claims exceed the stable reconstructed horizon.
- observed PV reply is worded as proven forced/unique without proof.
- HOLD concepts leak into user-visible comparison explanation.
- unresolved confidence uses assertive/measured causal wording.
- repetition presentation suppresses first occurrence, suppresses the second occurrence, or fails to reset after semantic evidence/confidence changes.
- any `Sources/ShogiCoachCore` file differs from the Build19-4 authority.
- Build19-1/2/3A/3B, Build18, full Swift regression, or static verification fails.

## Human semantic review

Automated gates are necessary but not sufficient. After CI produces the structured semantic report, review the real-game explanation rows for:

- factual agreement with the typed evidence
- natural Japanese
- beginner comprehensibility
- causal overstatement
- misleading confidence
- unnecessary repetition
- unsafe counterfactual wording

The final verdict may be PASS only after this human semantic review is completed.
