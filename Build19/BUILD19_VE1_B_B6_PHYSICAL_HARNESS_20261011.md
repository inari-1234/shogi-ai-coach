# Build19-VE1-B B6 — Physical Qualification Harness Authority

Date: 2026-10-11
Status: **FROZEN BEFORE PHYSICAL B6 MEASUREMENT / IMPLEMENTATION CANDIDATE**

## 1. Scope

This document fixes the operation of the in-app B6 physical qualification harness before any B6 device measurement is used to accept or reject the node schedule. It implements the already-frozen `BUILD19_VE1_B_B6_PREMEASUREMENT_ACCEPTANCE_20261010.md` and the `PROVEN_MATE_TERMINATION` amendment. It does not change any B6 threshold, node tier, semantic rule, or explanation gate.

The parent pre-B6 integration authority is commit `e0e64578eeba4377e58147fd3f1c9a016997e5a7`, where Core regression, HDS Contract Evidence, iOS Device Build/IPA, Simulator app build, and production-path Simulator E2E all passed.

## 2. Qualification KIF locking

Before the first physical measurement, the operator selects exactly one KIF file in the B6 screen.

The harness must:

1. read the original file bytes;
2. parse them through the production `KIFParser`;
3. reject a fixture that cannot provide at least three focus-eligible plies;
4. calculate SHA-256 over the unmodified original bytes;
5. copy those exact bytes to app Documents as the qualification fixture;
6. persist file name, SHA-256, move count, and lock timestamp before the first standard run;
7. verify the copied fixture SHA before every subsequent run;
8. prevent fixture replacement after any standard/stress evidence exists.

Changing the fixture after measurement begins invalidates that campaign. Evidence from two fixture hashes must never be pooled.

The Top-3 plies recorded for the reproducibility gate are taken from the actual production Deep selection order exposed by the production run's VE1-B Evidence, not by an independent selector or reimplementation. Therefore B6 does not introduce a second position-selection algorithm. If a Deep run becomes incomplete only after at least three selected positions were emitted, those first three still preserve the shallow Top-3 observation; if Deep terminates before three positions are emitted, that run cannot supply a complete shallow Top-3 and no primary B6 PASS is possible from that campaign.

## 3. Standard runs

The harness performs one standard run per explicit operator action, up to 5 runs.

Before every standard run it must enforce:

- exact frozen primary policy identity: discovery/confirmation `50k/100k/200k`, `safetyCeilingMs=15000`, `UNFROZEN_CALIBRATION`;
- physical `device` platform;
- the frozen floor `iPhone17,1` / `iOS 26.7.1`;
- complete app version/build/GitCommit provenance;
- unchanged app/device/OS/YaneuraOu/NNUE provenance across the campaign;
- current thermal state exactly `nominal`;
- locked fixture SHA unchanged;
- bundled NNUE SHA still equal to VE1-A authority.

Each run creates fresh `ShallowAnalysisViewModel` and `DeepAnalysisViewModel` instances. This prevents a previous standard run's engine session from being reused. Inside Deep VE1-B, the existing independent nine-search cold-TT contract remains authoritative.

The timed whole-game interval begins immediately before production shallow analysis and ends after the production Deep VE1-B stage returns. Later board/reason/context/export presentation stages are excluded, matching the frozen B6 definition.

## 4. Stress run

Stress starts only after the five standard runs satisfy both shallow reproducibility and standard operational gates.

The harness requires `nominal` immediately before stress begins, then runs 3 complete shallow+Deep analyses in one uninterrupted loop. It must not introduce an artificial cooldown or a `nominal` precondition between stress runs 1→2 or 2→3.

Each stress run still uses fresh shallow/deep view-model instances so engine sessions are not reused as evidence across whole-game runs.

## 5. Raw evidence preservation

After every run, the harness copies the production `ve1b-search-evidence.json` to a run-specific file and records its SHA-256 in the B6 aggregate report.

The aggregate report stores compact per-attempt fields needed for B6 arithmetic:

- role / measurement target;
- node budget;
- TT generation;
- MultiPV and `searchmoves` identity;
- completion state;
- elapsed time;
- thermal before/after;
- actual observed nodes and selected completed-iteration nodes/bound kind.

Raw USI observations remain in the separately hashed run evidence file; the aggregate report references rather than rewrites that evidence.

## 6. Completion classification

For B6 arithmetic, only these are completed search states:

- `node_budget_reached`;
- `proven_mate_termination`.

`proven_mate_termination` is counted separately in the report.

Every other completion value is incomplete. In particular, the harness does not reinterpret or forgive `early_engine_termination`, `safety_aborted`, or `no_completed_exact_iteration`.

The aggregate report records completion-state counts and incomplete rates explicitly for both standard and stress campaigns.

A completed standard Deep position must contain exactly 9 attempts. Missing attempts fail the standard operational gate.

## 7. Frozen metric arithmetic

- Top-3 Jaccard uses set intersection / set union.
- All `C(5,2)=10` standard run pairs are retained.
- Modal Top-1 tie breaking is deterministic by lower ply only for report identity; acceptance uses only the winning count and still requires `>=4/5`.
- Median is the conventional middle observation for odd N and arithmetic mean of the two middle observations for even N.
- P95 uses the frozen nearest-rank rule: `ceil(0.95*N)`, one-based and capped at N.

No measurement outcome may change these definitions.

## 8. Thermal arithmetic

Standard thermal observations include:

- each run start/end;
- every shallow search thermal before/after;
- every Deep VE1-B attempt thermal before/after.

Thus any observed `serious` or `critical` during standard qualification is visible to the gate.

Stress uses the same observation coverage and requires zero `critical`. A `serious` observation remains characterization and may coexist with safe degradation as defined by the frozen B6 contract.

A stress run is evidence-integrity-valid only when production shallow passed, the raw Evidence JSON and its SHA are retained, completed positions contain all 9 attempts, and Deep ends either `completed` with no incomplete attempts or `incomplete` with explicit incomplete attempts. `.error`, missing Evidence, and other malformed states can never be converted into a zero-percent incomplete rate or a stress PASS.

## 9. Decision values

The aggregate report emits only the frozen decision vocabulary:

- `PRIMARY_PASS`;
- `FALLBACK_REQUIRED`;
- `FALLBACK_PASS`;
- `B6_HOLD`.

This initial harness executes the primary `50k/100k/200k` campaign only.

- Incomplete primary standard/stress operational evidence yields `FALLBACK_REQUIRED` where the frozen fallback rule applies.
- Shallow reproducibility failure yields `B6_HOLD` because the frozen contract requires migration of shallow triage itself to a fixed-node policy before a new full B6 campaign.
- `PRIMARY_PASS` means the physical B6 arithmetic passed; it does **not** by itself freeze VE1-B. The raw evidence/provenance review and production policy freeze on a final candidate commit remain mandatory.

The predetermined `25k/50k/100k` fallback schedule remains frozen in the pre-measurement contract. If it is required, a separate full campaign must be executed and primary evidence must not be reused as fallback PASS evidence.

## 10. Required CI before device use

The harness candidate must pass, on its own final commit:

- `swift test` / Core regression, including B6 metric tests;
- HDS Contract Evidence;
- iOS Device Build / IPA packaging;
- production-path Simulator E2E.

Only then may the physical iPhone B6 measurement begin.
