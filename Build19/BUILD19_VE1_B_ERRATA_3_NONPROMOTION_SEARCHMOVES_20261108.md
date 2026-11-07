# Build19 VE1-B — Errata #3: omitted non-promotion searchmoves target binding

Date: 2026-11-08
Status: **ENGINE BEHAVIOR CONFIRMED / PRODUCT TERMINAL BESTMOVE GUARD INCOMPLETE / BUILD20 FIX REQUIRED**
Scope: VE1-B native restricted search behavior and production result validation. **No change to frozen VE1-B Authority or C1 pilot.**

## Reproduction

Pinned `legal-2-legal-all-3-rook-nonpromotion-boundary` fixture:
`position sfen k7r/9/6R2/9/9/9/7g1/9/8K b - 1`.
Under default `MoveList<LEGAL>`, legal root count is 2; under `LEGAL_ALL`, 3. Optional rook non-promotion `3c1c` is present in `LEGAL_ALL` but omitted from `LEGAL`; promoted `3c1c+` is retained.

C1 Pilot Controls run `42425517284` on commit `f0f86b7fe6a18fdd3457a99875a5edddf25fb90d`:
- Requested `go nodes 50000 searchmoves 3c1c`; observed terminal `bestmove 1i2i` and selected exact root PV `1i2i`, **not** `3c1c`. It reported a normal 50k search, so success/completion status alone cannot establish requested-target identity.
- Requested `searchmoves 3c1c+`; returned `bestmove 3c1c+` and selected PV root `3c1c+`.
- Unrestricted control returned `1i2i`.
- Evidence artifact `13595611158`, ZIP digest `sha256:77e79628f64812baac18381e784fc634db0d71f95430c5fea94acf6bad4183ab`.

## Code-path distinction: do not overstate current product impact

The **engine-level target substitution is confirmed**. A C1 Python evaluator lacking target binding could misattribute the unrestricted score; C1 now fails closed on both terminal bestmove and selected PV root mismatch and its regression passed (`42426046533`).

**Current product VE1-B `iOS/ShogiCoachPoC/VE1BNodeComparisonAnalyzer.swift` is not entirely unguarded.** Its independent recommended/actual one-target searches occur around lines 245–299; it selects the exact searched PV with `.first(where: { $0.move == requestedMove })`, and `makeLine` derives `move` from PV[0]. For the measured substitution `3c1c -> 1i2i`, **this product path would fail the PV-root gate and throw**, rather than use `1i2i` to compute an ordinary false MATCH/loss. The same path **does not explicitly require the terminal `bestmove` to equal the requested target**; that second identity gate and explicit user-facing fail-closed provenance remain to be specified and regressed. Audit other product comparison paths rather than claim all are safe or all misattribute scores.

## Required product disposition

**Build20+ product fix**, unless separately authorized under an explicit corrective Freeze process:
1. For every independent single-target `searchmoves(X)` product measurement, verify **both** terminal `bestmove == X` and completed exact rank-1 PV root `== X`. Reject mismatched/absent/insufficient observations; do not reuse another move's score.
2. Preserve requested move, observed terminal bestmove, scored PV root, full raw USI, TT generation and node budget. Emit fail-closed `NOT_CLASSIFIABLE` / unconfirmed state or explicit non-success result; do not display MATCH, zero loss or a confirmed recommendation from invalid evidence.
3. Regress omitted optional pawn/lance/rook/bishop non-promotions, the pinned `3c1c` mismatch, the valid `3c1c+` control, and normal valid searchmoves. Verify the user-facing handling and upstream VE1-B stability/PV roles without relaxing its frozen gates.
4. This errata is **separate** from Errata #1 (MultiPV cohort) and Errata #2 (unrestricted LEGAL cardinality), and does not authorize globally enabling `LEGAL_ALL` or changing node budgets.

## C1 consequence

The C1-only §9 option A was implemented and verified in `BUILD19_VE1_C1_NONPROMOTION_SEARCHMOVES_POLICY_20261108.md`. The frozen 16-position pilot had **160/160** valid target bindings; its prior `PILOT_PASS` and F2/E0 do not change. Include the **C1 fail-closed clause** (not a new product-engine fix) in the future single C1 Freeze Authority.

This is a product errata record, **not a modification or replacement of historical VE1-B Authority**.
