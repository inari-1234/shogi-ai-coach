#!/usr/bin/env python3
"""Fail-closed merge of 4 deterministic frozen-pilot 16M/64M played-search shards.

All reference played memberships are derived from independent same-budget
searchmoves(rank1) and searchmoves(actual) at both 16M and 64M.
Never reconstruct good membership from a top-three exclusion alone.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as c
import ve1c1_pilot_evaluator as ev
import ve1c1_reference_played_16m64m as run
import ve1c1_new_reference_feasibility_grid as newref

SCHEMA="ve1c1-reference-played-16m64m-merged-diagnostic-v1"
ARTIFACT_PREFIX="Build19-VE1-C1-Reference-played-targets-shard-"


def require(ok:bool,msg:str)->None:
    if not ok:raise ValueError(msg)


def digest(p:Path)->str:
    h=hashlib.sha256()
    with p.open("rb") as f:
        for block in iter(lambda:f.read(1024*1024),b""):h.update(block)
    return h.hexdigest()


def checked_sample(search:dict[str,Any],folder:Path,n:int,target:str,kind:str)->dict[str,Any]:
    require(search["nodeBudget"]==n and search["multiPV"]==1,"search_budget_multipv")
    require(search["goCommand"]==f"go nodes {n} searchmoves {target}","search_go_command")
    require(search["requestedMove"]==target,"search_target_changed")
    rel=Path(search["rawLogRelativePath"])
    require(not rel.is_absolute() and ".." not in rel.parts,"raw_outside_shard")
    raw=(folder/rel)
    require(raw.is_file() and digest(raw)==search["rawUSISHA256"],"raw_log_or_sha_invalid")
    require(raw.stat().st_size==search["rawLogSize"],"raw_size_invalid")
    txt=raw.read_text(encoding="utf-8")
    require(f"> go nodes {n} searchmoves {target}" in txt,"raw_go_missing")
    require("bestmove " in txt,"raw_bestmove_missing")
    roots=search.get("selectedSnapshot") or []
    root=(roots[0].get("pv") or [None])[0] if roots else None
    valid=(search.get("searchmovesTargetBinding")=="MATCH"
            and search.get("candidateBlockStatus")=="RESOLVED"
            and search.get("selectedSnapshotEvidenceStatus")=="RESOLVED"
            and search.get("returnedBestmove")==target and root==target)
    return {
        "target":target,"kind":kind,"valid":valid,
        "reason":None if valid else "UNBOUND_OR_INSUFFICIENT_TARGET",
        "score":roots[0] if valid and roots else None,
        "rawUSISHA256":search["rawUSISHA256"],
        "rawLogRelativePath":str(rel),
    }


def compare_budgets(position:dict[str,Any], row:dict[str,Any],folder:Path)->dict[str,Any]:
    require(row["position_id"]==position["position_id"],"wrong_position")
    require(row["position_command"]==position["position_command"],"wrong_position_command")
    require(row["actual_move"]==position["actual_move"],"wrong_played_move")
    budgets=row.get("budget_reports") or []
    require([v["nodeBudget"] for v in budgets]==list(run.NODE_BUDGETS),"budgets_not_16_64")
    info=[]
    for b in budgets:
        n=b["nodeBudget"]
        best=checked_sample(b["rank1Search"],folder,n,b["rootRank1Move"],"rank1")
        actual=checked_sample(b["actualSearch"],folder,n,position["actual_move"],"actual")
        if best["valid"] and actual["valid"]:
            severity=ev._severity_class_from_scores(ev._score(best["score"]),ev._score(actual["score"]))
            cls=severity.get("class")
            status="RESOLVED" if cls not in ("UNRESOLVED","NOT_CLASSIFIABLE") else "INSUFFICIENT"
        else:
            severity={"class":"NOT_CLASSIFIABLE","reason":"SEARCHMOVES_TARGET_MISMATCH"}
            status="INSUFFICIENT"
        info.append({
            "nodeBudget":n,"status":status,
            "playedClass":severity.get("class"),
            "playedLoss":severity.get("loss"),
            "reason":severity.get("reason"),
            "rootRank1Move":b["rootRank1Move"],
            "bestSearch":best,"actualSearch":actual,
        })
    a,b=info
    if a["status"]!="RESOLVED" or b["status"]!="RESOLVED":
        membership="INSUFFICIENT"
    elif a["playedClass"]==b["playedClass"]=="GOOD":
        membership="CONFIRMED_GOOD"
    elif a["playedClass"]!="GOOD" and b["playedClass"]!="GOOD":
        membership="CONFIRMED_NON_GOOD"
    else:membership="DISPUTED"
    return {
        "position_id":position["position_id"],"referencePlayedMembership":membership,
        "independentReferenceBudgetClasses":[a["playedClass"],b["playedClass"]],
        "measurements":info,
    }


def merge(shards:Path,pilot:dict[str,Any],diagnostic:dict[str,Any],stability:dict[str,Any])->dict[str,Any]:
    require(pilot.get("result_sha256")==run.PILOT_SHA,"pilot_result_identity")
    require(diagnostic.get("authority_pilot_result_sha256")==run.PILOT_SHA and diagnostic.get("status")=="DIAGNOSTIC_COMPLETE","new_ref_identity")
    require(stability.get("frozen_result_sha256")==run.PILOT_SHA,"VE1B_stability_identity")
    require(stability.get("position_count")==16 and stability.get("explicit_non_promotion") is True,"stability_count")
    require(len(pilot.get("positions",[]))==len(diagnostic.get("positions",[]))==16,"natural_count")
    parts=[]
    engine_digest=None
    for shard in range(run.SHARD_COUNT):
        folder=shards/(ARTIFACT_PREFIX+str(shard))
        report=json.loads((folder/"report.json").read_text(encoding="utf-8"))
        require(report.get("status")=="SHARD_COMPLETE","shard_not_complete")
        require(report.get("schema_version")==run.SCHEMA,"shard_schema")
        require(report.get("pilot_result_sha256")==run.PILOT_SHA,"shard_pilot_sha")
        require(report.get("shard")==shard and report.get("shard_count")==run.SHARD_COUNT,"shard_identity")
        require(report.get("position_ordinals_expected")==list(range(shard*run.SHARD_SIZE+1,(shard+1)*run.SHARD_SIZE+1)),"shard_range")
        rows=report.get("position_reports") or []
        require([x.get("ordinal") for x in rows]==report["position_ordinals_expected"],"missing_or_duplicate_shard_positions")
        prov=report["engine_provenance"]
        engine_id=(prov.get("engine_commit"),prov.get("engine_sha256"),
                   prov.get("nnue_sha256"),prov.get("engine_patch_sha256"))
        require(prov.get("engine_commit")==run.runner.EXPECTED_ENGINE_PIN,"engine_pin")
        require(prov.get("nnue_sha256")==run.runner.EXPECTED_NNUE_SHA256,"nnue_pin")
        require(engine_digest is None or engine_id==engine_digest,"cross_shard_engine_inequivalence")
        engine_digest=engine_id
        for row in rows:
            idx=row["ordinal"]-1
            orig=pilot["positions"][idx];root=diagnostic["positions"][idx]
            require(root["position_id"]==orig["position_id"],"root_position_id")
            require(root["fresh16M64M"]["status"]=="RESOLVED","root_reference_not_resolved")
            for bud in row["budget_reports"]:
                require(bud["rootRank1Move"]==root["fresh"+str(bud["nodeBudget"])]["rank1Move"],"shard_ref_rank1")
            parts.append(compare_budgets(orig,row,folder))
    require(len(parts)==16,"shards_not_all_16")
    require([p["position_id"] for p in parts]==[p["position_id"] for p in pilot["positions"]],"merged_order")
    states={p["position_id"]:p["VE1BStabilityState"] for p in stability["rows"]}
    require(len(states)==16,"stability_positions")
    counters={x:sum(p["referencePlayedMembership"]==x for p in parts)
              for x in ("CONFIRMED_GOOD","CONFIRMED_NON_GOOD","DISPUTED","INSUFFICIENT")}
    grid=[]
    for delta in c.DELTA_GRID:
        h3=[];good_count=0;classified=0;qualified_app_stable=0
        for p,ref in zip(pilot["positions"],parts):
            label=newref.app_played_label(p,delta)
            if label is not None:classified+=1
            if label is not None and states[p["position_id"]]=="stable":
                qualified_app_stable+=1
            if ref["referencePlayedMembership"]=="CONFIRMED_GOOD":
                good_count+=1
                if label in ("SOMEWHAT_WORSE","BLUNDER"):
                    h3.append(p["position_id"])
        grid.append({"delta":delta,"C1PlayedF2E0Classifiable":classified,
                     "VE1BStableAndC1Classifiable":qualified_app_stable,
                     "ReferenceIndependentConfirmedGood":good_count,
                     "H3IndependentPlayedMismatch":len(h3),"H3CaseIds":h3})
    return {
        "schema_version":SCHEMA,"status":"DIAGNOSTIC_COMPLETE",
        "pilot_result_sha256":run.PILOT_SHA,
        "reference_root_diagnostic_run_id":run.DIAG_RUN_ID,
        "reference_budgets":list(run.NODE_BUDGETS),
        "engine_identity":engine_digest,
        "playedMembershipCounts":counters,
        "VE1BStableCount":stability["stable_count"],
        "C1CertaintyIsIndependentOfVE1BStable":True,
        "amendment_approved":False,"selected_delta":None,
        "position_reports":parts,"grid":grid,
        "aggregation":"complete_unique_ordinals_and_raw_SHA256_per_shard",
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--shards",type=Path,required=True)
    ap.add_argument("--pilot-result",type=Path,required=True)
    ap.add_argument("--reference-report",type=Path,required=True)
    ap.add_argument("--stability-report",type=Path,required=True)
    ap.add_argument("--output",type=Path,required=True)
    a=ap.parse_args()
    load=lambda p:json.loads(p.read_text(encoding="utf-8"))
    report=merge(a.shards,load(a.pilot_result),load(a.reference_report),load(a.stability_report))
    a.output.parent.mkdir(parents=True,exist_ok=True)
    a.output.write_text(json.dumps(report,indent=2,ensure_ascii=False,sort_keys=True)+"\n",encoding="utf-8")
    print("reference_played_16m64m_shards_merged",report["playedMembershipCounts"])
    print("frozen_C1_played_delta_grid",[
        [r["delta"],r["C1PlayedF2E0Classifiable"],r["H3IndependentPlayedMismatch"]]
        for r in report["grid"]])
    print("feasibility_decision=NOT_YET_MADE")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
