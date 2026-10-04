# Build18-6 Source / Sampling Plan — Gate A

Date: 2026-10-04  
Repository: inari-1234/shogi-ai-coach  
Branch: candidate/build18-6-real-game-e2e

## Authority

- Build18-3 frozen candidate HEAD: 054f30a54463d472cc96a16c49cd14d6e0e28b45
- Build18-3 validated production implementation HEAD: 3ef903e5762e695646204987196e8b8fff500155
- Build18-2 Frozen Diagnostic Corpus SHA-256: 433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0
- Build18-4V Freeze Package parent-accepted SHA-256: 3f298c3c87bf43d40365fb53196d4e5649cb2fa352a592b6d5489f50a69c39c4
- Build18-5A corrected HEAD: 3443b3cb0830783b325fca4bd82fd374a185dc6a
- Build18-5A decision: PROMOTE 0 / HOLD 5 / Build18-5B skipped

The Build18-4V package bytes are not stored in this repository and were not found in the connected Drive at Gate A. Therefore the workflow records that hash as parent-attested upstream authority; it does not claim an independent byte-level recomputation of that archive. The repository-verifiable authorities are verified directly. Build18-2 Frozen Corpus bytes are read from `origin/candidate/build18-2-diagnostic-corpus:Build18/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json` and SHA-256 is recomputed at Gate A.

## Real-game source

Primary source:

- source ID: denryusen:dr4-hardware2:2024
- source type: official KIF archive
- event: 第2回マイナビニュース杯電竜戦統一ハードウェア戦
- archive: https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip
- event page: https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php
- rights note carried from the official source path used by Build17-6R: 棋譜利用は制限等ありませんので、ご自由にお使いください。
- use: E2E / regression fixture only; not persisted as training data

The Build17-6R official real-game acquisition path is reused.

## Sampling policy freeze

Game selection is not lexical-first and not "first N games".

1. Enumerate all parseable .kif files in the official archive.
2. Compute stable FNV-1a 64-bit hash from each KIF filename.
3. Sort by hash, with full path as deterministic tie-breaker.
4. Consume games in that frozen order.

Position selection is not "first N plies".

1. Consider all moves up to max-ply 140.
2. For each selected game, choose positions evenly across the available ply range.
3. Use the same deterministic selection rule for Pilot, Mid Audit, and Full E2E.
4. The Full E2E target is 720 positions across at least 12 games, providing margin above the formal 600 / 10 minimum.

Gates:

- Gate B Pilot: 100 positions, at least 4 games, max 25 positions per game.
- Gate C Mid Audit: 300 positions, at least 10 games, max 30 positions per game.
- Gate D Full E2E: 720 positions, at least 12 games, max 60 positions per game.

## Stratification definitions

Operational phase proxy used for deterministic coverage reporting:

- OPENING: ply 1–30
- MIDDLEGAME: ply 31–70
- ENDGAME: ply 71–140

This is a sampling/reporting proxy, not a semantic assertion that every position in a range is objectively in that shogi phase. Human semantic review may note exceptions.

Other strata are read from production analysis output:

- confidence: HIGH / MEDIUM / LOW / UNRESOLVED
- WhyNow trigger
- multiple Intent candidates
- safe Concept supplement / no supplement
- forcing position
- quiet / ambiguous position
- NONE_IDENTIFIED
- Shikenbisha heuristic

Shikenbisha heuristic is used only to ensure review coverage: an early rook relocation away from its initial file during the first 30 plies. It never changes Production intent, confidence, Concept, or explanation.

## Human review sample

Human review candidates are selected only after the full deterministic sample is fixed.

Selection rule:

1. Stable SHA-256 order of gameID:ply.
2. First eligible record for each required stratum:
   phase, confidence, each observed WhyNow trigger, supplement/no supplement, multiple Intent, forcing, quiet/ambiguous, Shikenbisha heuristic, adversarial-like.
3. Fill deterministically to 48 unique records.

No sample is selected based on whether the explanation "looks good".

## Production freeze

Build18-6 may change only audit tooling, workflow, and evidence/report files.

The workflow must fail if files under Sources/ShogiCoachCore differ from Build18-3 frozen candidate HEAD 054f30a54463d472cc96a16c49cd14d6e0e28b45.

## Execution trace

Execution PR: #9 (draft; Build18-6 audit evidence only; do not merge in this stage).
