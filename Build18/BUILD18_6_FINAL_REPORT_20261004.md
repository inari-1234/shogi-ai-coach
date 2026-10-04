# Build18-6 Final Report — Real-game E2E / Explanation Quality Audit

Date: 2026-10-04  
Repository: `inari-1234/shogi-ai-coach`  
Branch: `candidate/build18-6-real-game-e2e`  
Audited candidate HEAD: `32635a23a29ef1bd01c250276f81395352afc2a4`

## Final verdict

**Build18-6: FAIL**

**Status: CORRECTIVE IMPLEMENTATION REQUIRED**

Reason: **QUALITY BLOCKER — major consecutive explanation repetition**.

This is not a semantic hallucination failure. Groundedness/scope automated checks passed, but the same safe fallback/WhyNow wording repeats over true consecutive plies, reaching an 11-ply run. Build18-6 explicitly requires major repetition failures to be zero.

## Authority

Authority Production HEAD: `3ef903e5762e695646204987196e8b8fff500155`  
Build18-3 Frozen candidate HEAD: `054f30a54463d472cc96a16c49cd14d6e0e28b45`  
Build18-2 Frozen Corpus SHA-256: `433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0`  
Build18-4V Freeze Package SHA-256: `3f298c3c87bf43d40365fb53196d4e5649cb2fa352a592b6d5489f50a69c39c4`  
Build18-5A: PROMOTE 0 / HOLD 5 / Build18-5B skipped.

Authority Audit: **PASS**.  
Production Code changed by Build18-6: **0**.

## Full real-game E2E

Games: **12**  
Evaluated positions: **720**

Opening: **168**  
Middlegame: **221**  
Endgame: **331**

HIGH: **68**  
MEDIUM: **431**  
LOW: **11**  
UNRESOLVED: **210**

Concept supplement: **156**  
No supplement: **564**

WhyNow trigger distribution:

- DIRECT_PREVIOUS_MOVE: 156
- IMMEDIATE_THREAT: 0
- FORCING_TACTIC: 44
- EXCHANGE_SEQUENCE: 67
- VERIFIED_SEQUENCE_TIMING: 0
- FORMATION_WINDOW: 0
- ENDGAME_URGENCY: 0
- NONE_IDENTIFIED: 453

Multiple Intent candidate: **364**  
Forcing positions: **141**  
Quiet / ambiguous: **344**  
Shikenbisha heuristic positions: **120**

Blocking crashes: **0**  
Intent drift detected: **0**  
Confidence drift detected: **0**

Unsupported purpose: **0**  
Effect -> Intent: **0**  
Outcome -> Reason: **0**  
False previous-move causality: **0**  
Geometry-only purpose: **0**  
LOW / UNRESOLVED assertive purpose: **0**  
Shikenbisha overclaim: **0**  
Held Concept leakage: **0**  
Fictitious mate: **0**  
Fictitious threatmate: **0**

## Blocking repetition result

A separate contiguous real-game audit evaluated **840 true sequential positions**.

- true consecutive exact full-explanation repeats: **155**
- true consecutive exact WhyNow repeats: **220**
- maximum exact full-explanation run: **11 plies**
- maximum normalized WhyNow run: **11 plies**
- same Concept on consecutive ply: **0**

Representative failure mode: multiple consecutive unresolved/NONE_IDENTIFIED positions output exactly the same safe uncertainty sentence. Other runs repeat the same “WhyNow direct evidence is not identified” sentence even when the primary Intent changes.

This is semantically conservative, but it creates a substantial UX failure: the coach repeatedly tells the user essentially the same thing instead of adding move-specific observable information or suppressing redundant wording.

Major repetition failures: **1 blocking class / FAIL**

## Human semantic / quality audit

Formal Gate E: **NOT RUN**, because Gate D2 produced a blocker and the stage instruction prohibits advancing past a blocking gate.

Targeted human inspection of the failing repetition sequences: **QUALITY BLOCKER CONFIRMED**.

Human semantic blockers from a full Gate E: **NOT ASSESSED**.  
Major readability failures: **not formally assessed**.  
Major repetition failure: **CONFIRMED**.

## Existing regression and runtime evidence

Locked Regression: **PASS in fresh 73/73 Swift suite / mandatory regression path**  
Build16-R1: **PASS**  
Build17 mandatory regression: **PASS**  
Build18 diagnostic/dedicated regression: **PASS in fresh Swift suite**  
Formal Gate F: **NOT REACHED after Gate D2 blocker**

Device build job: **PASS**  
Simulator build: **PASS**  
Simulator E2E: **PASS**

Simulator evidence:

- `stage=complete`
- `context_semantics_status=PASS`
- `context_explanation_status=PASS`
- `analysis_quality_gate_status=PASS`

The iOS Device workflow is marked FAIL only because its separate Build18-6 audit job hit the repetition blocker; the actual iPhone build/IPA job passed.

## Blocking issues

1. **QUALITY BLOCKER: repeated safe fallback / WhyNow wording across consecutive real-game plies.**
2. Maximum confirmed run: **11 consecutive plies**.

No false-explanation blocker was detected in the 720-position Full E2E.

## Corrective scope

Do **not** weaken the evidence gate and do **not** invent purpose to create textual variety.

The correction must preserve “Missing is safer than wrong” while preventing repetitive coaching. Preferred scope is an explanation presentation/repetition policy that can suppress, condense, or vary only evidence-grounded move-specific observable information without changing:

- MoveIntent
- ContextIntentResolver
- intent scores / evidence weights
- confidence thresholds
- Build18-2 frozen labels
- Build18-5A HOLD decisions

## Next stage

**Build18-6R1 — Explanation Repetition Corrective Implementation**

Build18-M is **NOT ALLOWED** at this point.  
After correction, Build18-6 must be independently revalidated from Gate A through Gate F.
