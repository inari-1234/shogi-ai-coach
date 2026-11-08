#!/usr/bin/env python3
"""Report-only v4 §E coverage correction and H1/H3 exposure proxy.

Works ONLY on the immutable, previously exposed natural 16-position pilot.
Does not select delta, revise F/E, count holdout cases, or grant C1 Freeze.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as c
import ve1c1_pilot_evaluator as ev

PILOT_RESULT_SHA = "860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea"
PILOT_EVALUATION_SHA = "10e9d86beca6763bd01bb4aa21bc8b2b105949fbd305a30b4cbe6bc6f3d42d0a"
TIERS = (50_000,100_000,200_000)


def source_allowed(loss: float | None, delta: float) -> set[str] | None:
    if loss is None:
        return None
    return c.app_allowed_classes(max(0.0, loss), delta)


def expected_loss(best: dict[str, Any] | None, played: dict[str, Any] | None) -> float | None:
    return ev._severity_class_from_scores(ev._score(best), ev._score(played)).get("loss")


def source_status(pos: dict[str, Any], tier_index: int, delta: float) -> dict[str, Any]:
    app = pos["app"]
    discovery = app["discoveries"][tier_index]
    comparison = app["comparisons"][tier_index]
    selected = discovery.get("selectedSnapshot") or []
    best_search = comparison.get("bestSearch")
    actual_search = comparison.get("actualSearch")
    binding = {
        "best": ev.searchmoves_target_binding(best_search),
        "actual": ev.searchmoves_target_binding(actual_search),
    }
    if any(v not in ("MATCH","UNRESTRICTED") for v in binding.values()):
        return {"status":"NOT_CLASSIFIABLE","reason":"SEARCHMOVES_TARGET_MISMATCH",
                "bindings":binding,"dualSource":False}
    best = ev._primary(best_search)
    actual = ev._primary(actual_search)
    comparison_loss = expected_loss(best,actual)
    comparison_class = source_allowed(comparison_loss,delta)
    matched = [line for line in selected if (line.get("pv") or [None])[0]==pos["actual_move"]]
    if matched:
        root_loss = expected_loss(selected[0],matched[0]) if selected else None
        root_class = source_allowed(root_loss,delta)
        accepted = (root_class is not None and comparison_class is not None
                    and len(root_class)==len(comparison_class)==1
                    and root_class==comparison_class)
        return {
            "status":"CLASSIFIABLE" if accepted else "NOT_CLASSIFIABLE",
            "reason":"TWO_SOURCE_E0_MATCH" if accepted else "TWO_SOURCE_E0_CONFLICT_OR_UNRESOLVED",
            "dualSource":root_loss is not None and comparison_loss is not None,
            "rootPresent":True, "rootLoss":root_loss,
            "comparisonLoss":comparison_loss,"rootAllowed":sorted(root_class) if root_class else None,
            "comparisonAllowed":sorted(comparison_class) if comparison_class else None,
        }
    accepted=comparison_class is not None and len(comparison_class)==1
    return {
        "status":"CLASSIFIABLE" if accepted else "NOT_CLASSIFIABLE",
        "reason":"INDEPENDENT_ONLY_DEFINITE" if accepted else "INDEPENDENT_ONLY_AMBIGUOUS",
        "dualSource":False, "rootPresent":False,
        "rootLoss":None,"comparisonLoss":comparison_loss,
        "rootAllowed":None, "comparisonAllowed":sorted(comparison_class) if comparison_class else None,
    }


def app_definitive(pos: dict[str, Any], tier_index: int, delta: float) -> tuple[str,bool,bool]:
    discovery=pos["app"]["discoveries"][tier_index]
    comp=pos["app"]["comparisons"][tier_index]
    structural=ev._app_structure_at_delta(discovery,delta)
    actual=source_status(pos,tier_index,delta)
    comp_loss=actual.get("comparisonLoss")
    conflict=(
        structural=="UNIQUE_GOOD"
        and pos["app"]["recommendedMove"]!=pos["actual_move"]
        and (comp.get("comparisonInversion") is True
             or (comp_loss is not None and comp_loss<=c.TAU_GOOD_REF+delta))
    )
    return structural,conflict,structural in ("MULTIPLE_GOOD","UNIQUE_GOOD","NO_SAVING_MOVE") and not conflict


def evaluate_grid(raw: dict[str, Any], baseline: dict[str, Any]) -> dict[str, Any]:
    if raw.get("result_sha256")!=PILOT_RESULT_SHA or baseline.get("evaluation_sha256")!=PILOT_EVALUATION_SHA:
        raise ValueError("frozen_pilot_digest_identity")
    positions=raw.get("positions")
    if not isinstance(positions,list) or len(positions)!=16:
        raise ValueError("not_16_frozen_positions")
    references=[ev.cross_budget_structure(p["reference"]) for p in positions]
    if sum(x["status"]=="RESOLVED" for x in references)!=13:
        raise ValueError("frozen_reference_resolved_count")
    if sum(x["status"]=="RESOLVED" and x.get("label")=="MULTIPLE_GOOD" for x in references)!=12:
        raise ValueError("frozen_reference_multiple_count")

    grid=[]
    for delta in c.DELTA_GRID:
        row={"delta":delta,"playedE0ScoreSourceUpperBound":0,"structureDefinite200k":0,
             "comparisonSingleton200k":0,"finiteDualSource200k":0,
             "E0TwoSourceAgree":0,"E0TwoSourceConflict":0,
             "independentOnlyDefinite":0,"h1h3ExposureRaw":[0,0,0],
             "h1h3ExposureAfterCrossAxisGuard":[0,0,0],
             "h1h3ExposurePositions":{str(t):[] for t in TIERS}}
        for p,reference in zip(positions,references):
            status=source_status(p,2,delta)
            structural,guard,definitive=app_definitive(p,2,delta)
            if definitive:row["structureDefinite200k"]+=1
            if status["status"]=="CLASSIFIABLE":
                row["playedE0ScoreSourceUpperBound"]+=1
                if status["reason"]=="INDEPENDENT_ONLY_DEFINITE":
                    row["independentOnlyDefinite"]+=1
                elif status["reason"]=="TWO_SOURCE_E0_MATCH":
                    row["E0TwoSourceAgree"]+=1
            if status.get("dualSource"):
                row["finiteDualSource200k"]+=1
                if status.get("rootAllowed") and status.get("comparisonAllowed") and len(status["rootAllowed"])==len(status["comparisonAllowed"])==1 and status["rootAllowed"]!=status["comparisonAllowed"]:
                    row["E0TwoSourceConflict"]+=1
            cmp=source_allowed(status.get("comparisonLoss"),delta)
            if cmp is not None and len(cmp)==1:
                row["comparisonSingleton200k"]+=1
            if reference["status"]=="RESOLVED" and reference.get("label")=="MULTIPLE_GOOD":
                for i,tier in enumerate(TIERS):
                    label,cross,_=app_definitive(p,i,delta)
                    if label=="UNIQUE_GOOD":
                        row["h1h3ExposureRaw"][i]+=1
                        row["h1h3ExposurePositions"][str(tier)].append(p["position_id"])
                        if not cross:row["h1h3ExposureAfterCrossAxisGuard"][i]+=1
        grid.append(row)

    first=grid[0]
    if not (first["playedE0ScoreSourceUpperBound"]==13 and
            first["independentOnlyDefinite"]==10 and first["E0TwoSourceAgree"]==3 and
            first["E0TwoSourceConflict"]==2 and first["finiteDualSource200k"]==5 and
            first["comparisonSingleton200k"]==15):
        raise ValueError("v4_E_source_coverage_reconciliation")
    if not all(x["h1h3ExposureRaw"][2]==0 for x in grid):
        raise ValueError("primary_200k_false_unique_unexpected")
    if not (grid[-1]["playedE0ScoreSourceUpperBound"]==6 and grid[-1]["structureDefinite200k"]==1):
        raise ValueError("delta50_endpoint_check")
    return {
        "schema_version":"ve1c1-pilot-feasibility-grid-report-only-v1",
        "status":"REPORT_ONLY_RECONCILED",
        "frozen_result_sha256":PILOT_RESULT_SHA,
        "frozen_evaluation_sha256":PILOT_EVALUATION_SHA,
        "denominator_positions":16,
        "reference_cross_budget_resolved":13,
        "reference_cross_budget_multiple_good":12,
        "principal_App_semantic_tier":200_000,
        "selected_delta":None,
        "played_certainty_including_F2_stability_evaluated":False,
        "definition":"v4_§E_independent_only_out_of_root_else_strict_two_source_E0",
        "h1_h3_exposure_not_full_formal_h1_h3_assertion":True,
        "grid":grid,
    }


def main()->int:
    p=argparse.ArgumentParser()
    p.add_argument("--pilot-result",required=True,type=Path)
    p.add_argument("--pilot-evaluation",required=True,type=Path)
    p.add_argument("--output",required=True,type=Path)
    args=p.parse_args()
    raw=json.loads(args.pilot_result.read_text(encoding="utf-8"))
    eval_=json.loads(args.pilot_evaluation.read_text(encoding="utf-8"))
    doc=evaluate_grid(raw,eval_)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(doc,ensure_ascii=False,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"status":doc["status"],
          "rows":[{"delta":r["delta"],"played":r["playedE0ScoreSourceUpperBound"],
                   "structure":r["structureDefinite200k"],
                   "h1h3raw":r["h1h3ExposureRaw"],"h1h3guarded":r["h1h3ExposureAfterCrossAxisGuard"]}
                  for r in doc["grid"]]},ensure_ascii=False))
    return 0

if __name__=="__main__":
    raise SystemExit(main())
