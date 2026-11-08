#!/usr/bin/env python3
"""Report-only comparison of frozen App evidence against ALL-16 16M/64M Reference.

No choice of delta, no F/E reselection, no modification of frozen pilot budgets.
Conservative H3 exposure from a move in the 16M/64M shared GOOD set with
a definite E0/F2 App played label SOMEWHAT_WORSE/BLUNDER. This is NOT a
complete H3 gate without independent 64M searchmoves and played certainty.
"""
from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
from typing import Any

import ve1c1_pilot as c
import ve1c1_pilot_feasibility_grid as grid

PILOT_SHA=grid.PILOT_RESULT_SHA
EVALUATION_SHA=grid.PILOT_EVALUATION_SHA
SCHEMA="ve1c1-16m64m-reference-structure-and-h3-exposure-v1"


def require(cond:bool,why:str)->None:
    if not cond:raise ValueError(why)


def app_played_label(pos:dict[str,Any],delta:float)->str|None:
    st=grid.source_status(pos,2,delta)
    if st["status"]!="CLASSIFIABLE":return None
    comparison=pos["app"]["comparisons"][2]
    if comparison["comparisonInversion"] is True:
        best=comparison["bestSearch"]["selectedSnapshot"][0]
        actual=comparison["actualSearch"]["selectedSnapshot"][0]
        require(best["scoreKind"]==actual["scoreKind"]=="cp","inverted_non_cp")
        mag=c.expected_score(actual["scoreValue"])-c.expected_score(best["scoreValue"])
        require(mag>0,"inversion_magnitude_not_positive")
        if mag>c.TAU_GOOD_REF:return None
        return "WITHIN_GOOD_SET"
    allowed=st.get("comparisonAllowed")
    require(isinstance(allowed,list) and len(allowed)==1,"accepted_E0_not_singleton")
    return allowed[0]


def evaluate(raw:dict[str,Any],original_eval:dict[str,Any],diagnostic:dict[str,Any])->dict[str,Any]:
    require(raw.get("result_sha256")==PILOT_SHA,"pilot_identity")
    require(original_eval.get("evaluation_sha256")==EVALUATION_SHA,"pilot_eval_identity")
    require(original_eval.get("F",{}).get("policy")=="F2","F_policy")
    require(original_eval.get("E",{}).get("policy")=="E0","E_policy")
    require(diagnostic.get("status")=="DIAGNOSTIC_COMPLETE","diagnostic_not_complete")
    require(diagnostic.get("authority_pilot_result_sha256")==PILOT_SHA,"diagnostic_pilot_binding")
    require(diagnostic.get("authority_pilot_evaluation_sha256")==EVALUATION_SHA,"diagnostic_eval_binding")
    require(diagnostic.get("processed_positions")==16,"diagnostic_count")
    require(diagnostic.get("fresh16M64MCounts")=={"RESOLVED":16,"DISPUTED":0,"INSUFFICIENT":0},"diagnostic_resolution")
    require(diagnostic.get("search_node_budgets")==[16_000_000,64_000_000],"diagnostic_budget")
    original=raw["positions"]; measured=diagnostic["positions"]
    require(len(original)==len(measured)==16,"natural_16")
    for p,q in zip(original,measured):
        require(p["position_id"]==q["position_id"] and p["position_command"]==q["position_command"],"position_identity")
        require(q["fresh16M64M"]["status"]=="RESOLVED","reference_unresolved")
        require(q["fresh16MMatchesFrozenStructure"] is True,"fresh16_structure_changed")
    require(sum(x["fresh16M64M"]["label"]=="MULTIPLE_GOOD" for x in measured)==15,"ref_multiple_count")
    require(sum(x["fresh16M64M"]["label"]=="NO_SAVING_MOVE" for x in measured)==1,"ref_no_saving_count")

    previous=grid.evaluate_grid(raw,original_eval)
    report=[]
    for base_row in previous["grid"]:
        delta=base_row["delta"]
        ref_counts={"MULTIPLE_GOOD":0,"UNIQUE_GOOD":0,"NO_SAVING_MOVE":0}
        raw=[0,0,0]; guarded=[0,0,0]
        h1_positions={str(t):[] for t in grid.TIERS}
        h3_position_ids=[]
        h3_maybe_unresolved=[]
        for p,q in zip(original,measured):
            ref=q["fresh16M64M"]; label=ref["label"]
            ref_counts[label]+=1
            for i,tier in enumerate(grid.TIERS):
                app_label, guard, _=grid.app_definitive(p,i,delta)
                if label=="MULTIPLE_GOOD" and app_label=="UNIQUE_GOOD":
                    raw[i]+=1
                    h1_positions[str(tier)].append(p["position_id"])
                    if not guard:guarded[i]+=1
            if label=="MULTIPLE_GOOD":
                membership=p["actual_move"] in set(ref.get("goodSetIntersection") or [])
                played=app_played_label(p,delta)
                if membership and played in ("SOMEWHAT_WORSE","BLUNDER"):
                    h3_position_ids.append(p["position_id"])
                elif not membership:
                    # Not in a top-3 good-set intersection cannot be treated as
                    # confirmed NONMEMBER without new same-budget independent targets.
                    h3_maybe_unresolved.append(p["position_id"])
        report.append({
            "delta":delta,
            "referenceCounts":ref_counts,
            "appStructureDefinite200k":base_row["structureDefinite200k"],
            "appPlayedF2E0ScoreEvidenceUpper200k":base_row["playedF2E0ScoreEvidenceUpperBound"],
            "h1FalseUniqueRawByTier":raw,
            "h1FalseUniqueAfterCrossAxisGuardByTier":guarded,
            "h1FalseUniquePositionIds":h1_positions,
            "h3DefiniteExposureFromSharedGoodSet200k":len(h3_position_ids),
            "h3ExposurePositionIds":h3_position_ids,
            "h3MembershipInsufficientFromRootAlone":h3_maybe_unresolved,
            "formalH3Verdict":"NOT_YET_CLASSIFIABLE_UNTIL_REFERENCE_PLAYED_SEARCHMOVES_AND_CERTAINTY",
        })
    require(len(report)==11,"grid_len")
    require(all(x["h1FalseUniqueAfterCrossAxisGuardByTier"][2]==0 for x in report),"200k_false_unique")
    require(all(x["h3ExposurePositionIds"]==["p04-ply-10","p09-ply-7"] for x in report),"h3_reference_member_exposures")
    require(all(x["appStructureDefinite200k"]==previous["grid"][i]["structureDefinite200k"] for i,x in enumerate(report)),"structure_mismatch")
    return {
        "schema_version":SCHEMA,"status":"REPORT_ONLY_RECONCILED",
        "original_pilot_sha256":PILOT_SHA,
        "original_evaluation_sha256":EVALUATION_SHA,
        "reference_diagnostic_run_id":42440362235,
        "reference_budgets":[16_000_000,64_000_000],
        "pilot_amendment_approved":False,
        "delta_selected":None,
        "h1_and_h3_are_distinct_claims":True,
        "H3_warning":"Shared top3 reference good-set membership is sufficient for affirmative membership, but absence is not NONMEMBER; played certainty and independent 64M targets pending.",
        "grid":report,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--pilot-result",type=Path,required=True)
    ap.add_argument("--pilot-evaluation",type=Path,required=True)
    ap.add_argument("--reference-report",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    a=ap.parse_args()
    load=lambda path:json.loads(path.read_text(encoding="utf-8"))
    d=evaluate(load(a.pilot_result),load(a.pilot_evaluation),load(a.reference_report))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(d,ensure_ascii=False,sort_keys=True,indent=2)+"\n",encoding="utf-8")
    for x in d["grid"]:
        print("delta",x["delta"],"structure",x["appStructureDefinite200k"],
              "H1_guarded",x["h1FalseUniqueAfterCrossAxisGuardByTier"],
              "H3_affirmative",x["h3DefiniteExposureFromSharedGoodSet200k"],flush=True)
    print("new_reference_feasibility_grid=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
