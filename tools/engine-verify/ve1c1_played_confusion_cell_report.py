#!/usr/bin/env python3
"""Interpret immutable pilot + new Reference artifacts without reinterpreting H3.

The historic merged field H3IndependentPlayedMismatch is misnamed. Its cases
are the REPORT-ONLY Reference GOOD -> App SOMEWHAT_WORSE confusion cell,
NOT the H3 hard gate on a UNIQUE_RECOMMENDATION's Reference membership.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as c
import ve1c1_new_reference_feasibility_grid as newref

PILOT_SHA = "860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea"
EVALUATION_SHA = "10e9d86beca6763bd01bb4aa21bc8b2b105949fbd305a30b4cbe6bc6f3d42d0a"
RUN_ID = 42453160640
EXPECTED_CASES = ("p01-ply-282", "p04-ply-10", "p09-ply-7")
SOURCE_ID = "denryusen:dr4-hardware2:2024"


def require(ok: bool, reason: str) -> None:
    if not ok:
        raise ValueError(reason)


def verify(pilot: dict[str, Any], evaluation: dict[str, Any],
           merged: dict[str, Any], stability: dict[str, Any],
           manifest: dict[str, Any]) -> dict[str, Any]:
    require(pilot.get("result_sha256") == PILOT_SHA, "pilot_sha")
    require(evaluation.get("evaluation_sha256") == EVALUATION_SHA, "evaluation_sha")
    require(evaluation.get("F", {}).get("policy") == "F2", "frozen_F")
    require(evaluation.get("E", {}).get("policy") == "E0", "frozen_E")
    require(merged.get("status") == "DIAGNOSTIC_COMPLETE", "merged_status")
    require(merged.get("pilot_result_sha256") == PILOT_SHA, "merged_pilot")
    require(merged.get("reference_root_diagnostic_run_id") == 42440362235, "ref_root_run")
    require(merged.get("reference_budgets") == [16_000_000, 64_000_000], "ref_budgets")
    require(merged.get("amendment_approved") is False, "amendment_was_approved")
    require(merged.get("playedMembershipCounts") == {
        "CONFIRMED_GOOD": 15, "CONFIRMED_NON_GOOD": 0,
        "DISPUTED": 0, "INSUFFICIENT": 1,
    }, "played_membership_counts")
    require(stability.get("position_count") == 16, "stability_count")
    require(stability.get("frozen_result_sha256") == PILOT_SHA, "stability_result_sha")
    require(stability.get("stable_count") == 4, "stability_stable_count")
    positions = pilot["positions"]
    matched = merged["position_reports"]
    selected = manifest["selected_positions"]
    require(len(positions) == len(matched) == len(selected) == 16, "positions_not_16")
    require(all(item.get("source_id") == SOURCE_ID for item in selected),
            "pilot_source_domain_changed")
    require(len({item["game_sha256"] for item in selected}) == 5, "five_source_games")
    require([p["position_id"] for p in positions] == [x["position_id"] for x in matched],
            "merged_position_order")
    require(all(p["game_sha256"] == m["game_sha256"] and p["ply"] == m["ply"]
                for p,m in zip(positions,selected)), "manifest_position_identity")
    require(len(merged.get("grid", [])) == len(c.DELTA_GRID), "legacy_grid_count")
    good_positions = {
        r["position_id"] for r in matched
        if r["referencePlayedMembership"] == "CONFIRMED_GOOD"
    }
    require(len(good_positions) == 15, "Reference_good_count")

    rows = []
    for delta, legacy in zip(c.DELTA_GRID, merged["grid"]):
        require(abs(delta - legacy["delta"]) < 1e-12, "delta_grid_mismatch")
        somewhat = []
        blunder = []
        for p in positions:
            if p["position_id"] not in good_positions:
                continue
            label = newref.app_played_label(p, delta)  # frozen F2 + E0 eligibility
            if label == "SOMEWHAT_WORSE":
                somewhat.append(p["position_id"])
            elif label == "BLUNDER":
                blunder.append(p["position_id"])
        # Old artifacts are immutable; interpret their misleading keys only
        # through this audited, non-authoritative semantic mapping.
        require(legacy["H3IndependentPlayedMismatch"] == 3, "legacy_count_not_three")
        require(legacy["H3CaseIds"] == somewhat, "legacy_cases_not_confusion_cell")
        require(tuple(somewhat) == EXPECTED_CASES, "expected_played_cases_changed")
        require(not blunder, "H2_good_to_blunder_cell_is_nonzero")
        rows.append({
            "delta": delta,
            "ReferenceGOODdenominator": 15,
            "referenceGOODtoAppSOMEWHAT_WORSE_count": len(somewhat),
            "referenceGOODtoAppSOMEWHAT_WORSE_rate": len(somewhat)/15,
            "referenceGOODtoAppSOMEWHAT_WORSE_positionIds": somewhat,
            "referenceGOODtoAppBLUNDER_count": len(blunder),
            "referenceGOODtoAppBLUNDER_positionIds": blunder,
            "H3_uniqueRecommendationMembershipGate_assessed": False,
            "legacyFieldWasMisnamed": "H3IndependentPlayedMismatch",
        })

    stable_set = set(stability["stable_ids"])
    require(stable_set == {"p08-ply-81", "p09-ply-7",
                           "p10-ply-138", "p12-ply-126"}, "stable_ids")
    cases = []
    eval_by_id = {p["position_id"]: p for p in evaluation["positions"]}
    for pid in EXPECTED_CASES:
        tier = next(t for t in eval_by_id[pid]["tiers"] if t["nodeBudget"] == 200000)
        require(tier["comparisonClass"] == "SOMEWHAT_WORSE", "archived_200k_class")
        cases.append({
            "position_id": pid,
            "app_200k_comparison_loss": tier["comparisonLoss"],
            "app_200k_class": "SOMEWHAT_WORSE",
            "reference_played_class": "CONFIRMED_GOOD",
            "VE1B_stability": "stable" if pid in stable_set else "unstable",
            "actual_product_UI_display_verified": False,
        })

    return {
        "schema_version": "ve1c1-pilot-played-confusion-cell-report-v1",
        "status": "REPORT_ONLY_RECONCILED",
        "pilot_sha256": PILOT_SHA,
        "evaluation_sha256": EVALUATION_SHA,
        "original_merged_run_id": RUN_ID,
        "original_merged_legacy_key": "H3IndependentPlayedMismatch",
        "interpretation_correction": (
            "Reference GOOD to App SOMEWHAT_WORSE is a report-only "
            "played-move confusion cell; it is NOT H3."
        ),
        "gate_meanings_unchanged": True,
        "H3_actual_definition": (
            "An App UNIQUE_RECOMMENDATION that is not in the Reference good set"
        ),
        "H3_formal_gate_assessed": False,
        "H2_report_only_observed_GOOD_to_BLUNDER": 0,
        "H5_reference_BLUNDER_observed_denominator": 0,
        "H5_future_minimum_denominator": 10,
        "H5_denominator_requirement_evaluated_on_pilot": False,
        "reference_classifiable_GOOD": 15,
        "reference_INSUFFICIENT": 1,
        "source_id": SOURCE_ID,
        "source_domain": "computer-shogi-engine-vs-engine-tournament",
        "source_is_human_professional_or_amateur": False,
        "source_population_matches_amateur_end_user": "NOT_ESTABLISHED",
        "pilot_five_source_games": True,
        "amendment_approved": False,
        "C1_freeze_approved": False,
        "selected_delta": None,
        "cases": cases,
        "delta_grid": rows,
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    for key in ("pilot-result", "pilot-evaluation", "merged-report",
                "stability-report", "pilot-manifest", "output"):
        ap.add_argument("--" + key, required=True, type=Path)
    args = ap.parse_args()
    get = lambda attr: json.loads(getattr(args, attr).read_text(encoding="utf-8"))
    report = verify(get("pilot_result"),get("pilot_evaluation"),
                    get("merged_report"),get("stability_report"),
                    get("pilot_manifest"))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(
        json.dumps(report,sort_keys=True,ensure_ascii=False,indent=2)+"\n",
        encoding="utf-8"
    )
    print(json.dumps({
        "status":report["status"],
        "referenceGOOD":report["reference_classifiable_GOOD"],
        "GOOD_to_SOMEWHAT_WORSE":report["delta_grid"][0]["referenceGOODtoAppSOMEWHAT_WORSE_count"],
        "GOOD_to_BLUNDER":report["H2_report_only_observed_GOOD_to_BLUNDER"],
        "H5_reference_BLUNDER_denominator":report["H5_reference_BLUNDER_observed_denominator"],
        "H3_hard_gate_assessed":report["H3_formal_gate_assessed"],
        "all_delta_cases_equal":all(
            len(r["referenceGOODtoAppSOMEWHAT_WORSE_positionIds"])==3
            for r in report["delta_grid"]
        ),
    },ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
