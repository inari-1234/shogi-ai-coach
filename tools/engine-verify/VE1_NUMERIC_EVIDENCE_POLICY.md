# VE1 Numeric Evidence Authority Policy

Effective date: 2026-10-09

This policy applies to VE1 engine-evidence work, including numeric expectations supplied by implementers, reviewers, users, or external validation runs.

## Rule

A numeric engine observation must **not** be promoted to a formal expected value unless the evidence package contains all of the following:

1. **Exact position identity** — full SFEN, or an unambiguous complete `position ...` command whose moves are all legal.
2. **Complete relevant command sequence** — engine options that materially affect the value, including at minimum Threads, MultiPV, FV_SCALE, evaluation file identity/path where applicable, and the exact `go ...` command.
3. **Raw USI log** — the actual engine transcript for the run, including warnings/errors and the final `info` / `bestmove` evidence used for the expected value.
4. **Runtime provenance** — engine revision/binary identity and NNUE identity sufficient to reproduce the run.

If any item is missing, the number is `OBSERVATION_ONLY` and cannot be used as a formal known-answer expectation.

## Illegal or partially accepted position commands

If a raw log contains `Illegal Input Move`, the requested move sequence is not itself position authority. The effective legal position must be reconstructed, recorded explicitly as SFEN or a legal move sequence, and then re-run directly from that corrected position before the result can become a known-answer fixture.

## Correction path for pre-existing incomplete observations

A pre-existing observation that was already used before this policy may be corrected only when:

- a dated correction record explains the missing or incorrect provenance;
- the exact corrected position and command sequence are fixed before the new qualifying run;
- a fresh raw log is generated from that corrected input on the pinned qualification environment;
- the fresh result matches the corrected expected value; and
- any applicable expectation-independent invariant also passes.

The expected value must not be changed merely to match the new run.

## C1 application

`fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md` is the correction record for the VE1-Q C1 236/157 observation. `fixtures/runtime/runtime-calibration-v2.json` fixes two direct known-answer positions plus the scale invariant. C1 remains failed unless the final qualifying run generates fresh raw logs and passes all of those checks.

## Scope

This policy governs evidence qualification only. It does not itself choose the production FV_SCALE, production node budget, win-rate conversion, cp thresholds, recommendation semantics, or 41/49/69 answer authority.
