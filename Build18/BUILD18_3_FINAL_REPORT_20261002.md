# BUILD18_3_FINAL_REPORT

Date: 2026-10-02  
Repository: `inari-1234/shogi-ai-coach`  
Branch: `candidate/build18-3-grounded-whynow`  
Baseline main: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`  
Validated implementation HEAD: `3ef903e5762e695646204987196e8b8fff500155`

## Verdict

**BUILD18-3 COMPLETE / FROZEN CANDIDATE**

Build18-3 implements Grounded WhyNow only in the explanation projection path. It does not advance to Build18-4.

## Upstream authority

- Build18-1 specification HEAD: `ea37b850c72fd07b328adbd046892b647edf8c2f`
- Build18-2 Annotation Schema SHA-256: `3b7453198c25504dbb94226fc9863a2e53a9b86d29b19c1398b5ae6b32884d1a`
- Build18-2 authority bundle SHA-256: `101a30f4a6965aa810317cab046120461e1513d5514f68baae14b8ba5c969c12`
- Frozen Diagnostic Corpus SHA-256: `433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0`
- Frozen Diagnostic Corpus: **360 records / 360 unique positions**
- Historical repository Build18-2 corpus with 300 unique positions was isolated under `Build18/Legacy/Build18-2_300_unique/` and is explicitly non-authoritative for Build18-3.

## Production implementation

Production changes are limited to:

1. `Sources/ShogiCoachCore/GroundedExplanationContext.swift`
   - typed explanation-only projection
   - frozen WhyNow trigger representation
   - source Evidence / Signal traceability
   - uncertainty / missing-evidence projection
   - no Intent or Confidence mutation

2. `Sources/ShogiCoachCore/ContextExplanation.swift`
   - replaces fixed intent-only WhyNow wording with the projected grounded detail
   - preserves existing conclusion / Concept supplement responsibilities

Protected resolver path remains unchanged:

- `Sources/ShogiCoachCore/ContextEngine.swift`: **UNCHANGED**
- `MoveIntent`: **UNCHANGED**
- `ContextIntentResolver`: **UNCHANGED**
- Intent score / evidence weight: **UNCHANGED**
- confidence thresholds: **UNCHANGED**

## Initial trigger scope

Implemented and directly tested:

- `DIRECT_PREVIOUS_MOVE`
- explicit `IMMEDIATE_THREAT`
- explicit `FORCING_TACTIC`
- explicit `EXCHANGE_SEQUENCE`
- `NONE_IDENTIFIED` fallback

`VERIFIED_SEQUENCE_TIMING`, `FORMATION_WINDOW`, and `ENDGAME_URGENCY` remain disabled unless future authority-complete evidence gates are provided.

During validation, `EXCHANGE_SEQUENCE` was found to be unreachable when `ev_recapture_exchange` was swallowed by the general direct-previous-move bucket. This was corrected by classifying the explicit exchange sequence before the general direct bucket. Resolver behavior, Intent, Confidence, and evidence weights were not changed.

## Frozen 360-position regression

The frozen authority is bound by source SHA-256 and projected losslessly for the fields needed by the production safety regression.

Expected trigger distribution:

- DIRECT_PREVIOUS_MOVE: **60**
- FORCING_TACTIC: **50**
- NONE_IDENTIFIED: **250**

Confidence distribution:

- HIGH: **45**
- MEDIUM: **15**
- LOW: **0**
- UNRESOLVED: **300**

Expected explanation scope:

- INTENT_WHY_NOW: **60**
- OBSERVED_CHANGE_ONLY: **130**
- UNCERTAINTY_ONLY: **170**

Additional blocking checks:

- required annotation fields present: **360 / 360**
- annotation status CONFIRMED: **360 / 360**
- cross-review status PASS: **360 / 360**
- Shikenbisha dedicated records: **80**, all remain unresolved / non-assertive with specialized authority unverified
- Effect/Intent boundary records: **190**
- forbidden-claim safety violations detected by projection regression: **0**
- LOW/UNRESOLVED assertive-purpose violations: **0**
- Effect -> Intent promotion violations: **0**
- false previous-move causality violations: **0**
- fictitious mate/threatmate violations: **0**
- unsupported specialized trigger violations: **0**

## Locked / existing regression

GitHub Actions at validated implementation HEAD:

### iOS Device Build

- run: `37022808528`
- job: `110889868990`
- Core regression: **73 / 73 PASS**
- failures: **0**
- Xcode unsigned iPhone build: **PASS**
- IPA verification / packaging: **PASS**

### iOS Simulator E2E

- run: `37022808458`
- job: `110890387566`
- Core regression: **73 / 73 PASS**
- Simulator Xcode build: **PASS**
- Simulator engine E2E: **PASS**
- `stage=complete`
- `context_semantics_status=PASS`
- locked rook-pawn intent: `rook_pawn_response`
- bishop-line intent: `bishop_line_response`
- `context_geometry_primary=false`
- `context_explanation_status=PASS`
- `analysis_quality_gate_status=PASS`
- `context_schema8_audit=PASS`

## PASS criteria audit

- Intent / Confidence invariance: **PASS**
- ContextIntentResolver untouched: **PASS**
- Frozen 360-position authority binding: **PASS**
- frozen trigger expectations: **PASS**
- forbiddenClaims safety gate: **PASS**
- Effect -> Intent prohibition: **PASS**
- LOW / UNRESOLVED non-assertive gate: **PASS**
- Shikenbisha boundary: **PASS**
- Locked Regression: **PASS**
- existing Build17/Core regression: **PASS**
- Device build: **PASS**
- Simulator build / E2E: **PASS**
- Build18-4 work: **NOT STARTED / PASS**

## Final packaging rule

This report records the validated implementation HEAD above. The report/manifest packaging commit must itself pass the same automatic Device and Simulator workflows before the parent stage is treated as finally closed.
