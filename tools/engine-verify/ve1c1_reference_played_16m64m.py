#!/usr/bin/env python3
"""Four-shard, all-16 independent Reference played-move feasibility diagnostic.

Uses ONLY the permanently excluded frozen C1 pilot positions. Both 16M and
64M use the pinned YaneuraOu/NNUE and cold per-search TT; raw USI stays in
per-shard evidence. This is not a revised pilot, holdout or §12 amendment.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path
from typing import Any

import ve1c1_pilot as contract
import ve1c1_pilot_runner as runner
import ve1c1_pilot_block_runner as block_runner  # installs coherent search wrapper
import ve1c1_pilot_evaluator as ev

PILOT_SHA="860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea"
DIAG_RUN_ID=42440362235
SCHEMA="ve1c1-reference-played-16m64m-shard-v1"
NODE_BUDGETS=(16_000_000,64_000_000)
SHARD_COUNT=4
SHARD_SIZE=4


def require(condition: bool, reason: str)->None:
    if not condition:raise contract.PilotError(reason)


def sha_file(p:Path)->str:
    digest=hashlib.sha256()
    with p.open("rb") as handle:
        for chunk in iter(lambda:handle.read(1024*1024),b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_inputs(pilot_file:Path,diag_file:Path)->tuple[dict[str,Any],dict[str,Any]]:
    pilot=json.loads(pilot_file.read_text(encoding="utf-8"))
    diag=json.loads(diag_file.read_text(encoding="utf-8"))
    require(pilot.get("result_sha256")==PILOT_SHA,"pilot_identity_changed")
    require(diag.get("status")=="DIAGNOSTIC_COMPLETE","reference_diagnostic_not_complete")
    require(diag.get("authority_pilot_result_sha256")==PILOT_SHA,"reference_diagnostic_wrong_pilot")
    require(diag.get("fresh16M64MCounts")=={"RESOLVED":16,"DISPUTED":0,"INSUFFICIENT":0},
            "reference_diagnostic_not_16_resolved")
    require(len(pilot.get("positions",[]))==len(diag.get("positions",[]))==16,"position_count")
    for p,q in zip(pilot["positions"],diag["positions"]):
        require(p["position_id"]==q["position_id"] and p["position_command"]==q["position_command"],
                "position_order_or_command_mismatch")
        require(q.get("fresh16MMatchesFrozenStructure") is True,"repeated_16M_changed")
    return pilot,diag


def sample_view(search:dict[str,Any],target:str,output:Path)->dict[str,Any]:
    log=Path(search["rawLogPath"])
    require(log.is_file() and log.stat().st_size>0,"target_log_missing")
    roots=search.get("selectedSnapshot") or []
    root=(roots[0].get("pv") or [None])[0] if roots else None
    binding=ev.searchmoves_target_binding(search)
    if search.get("candidateBlockStatus")!="RESOLVED":
        binding="INSUFFICIENT_BLOCK"
    return {
        "requestedMove":target,
        "returnedBestmove":search.get("bestmove"),
        "selectedRootMove":root,
        "searchmovesTargetBinding":binding,
        "goCommand":search.get("goCommand"),
        "nodeBudget":search.get("nodeBudget"),
        "multiPV":search.get("multiPV"),
        "ttGeneration":search.get("ttGeneration"),
        "candidateBlockStatus":search.get("candidateBlockStatus"),
        "selectedSnapshotEvidenceStatus":search.get("selectedSnapshotEvidenceStatus"),
        "selectedSnapshot":roots,
        "elapsedMs":search.get("elapsedMs"),
        "maxObservedNodes":search.get("maxObservedNodes"),
        "terminalIteration":search.get("terminalIteration"),
        "rawLogRelativePath":str(log.relative_to(output)),
        "rawUSISHA256":sha_file(log),
        "rawLogSize":log.stat().st_size,
    }


def main()->int:
    ap=argparse.ArgumentParser()
    ap.add_argument("--pilot-result",type=Path,required=True)
    ap.add_argument("--reference-report",type=Path,required=True)
    ap.add_argument("--work",type=Path,required=True)
    ap.add_argument("--shard",type=int,required=True)
    ap.add_argument("--out",type=Path,required=True)
    args=ap.parse_args()
    require(0<=args.shard<SHARD_COUNT,"shard_index")
    pilot,diag=load_inputs(args.pilot_result,args.reference_report)
    work=args.work.resolve()
    output=args.out.resolve()
    output.mkdir(parents=True,exist_ok=True)
    provenance=json.loads((work/"provenance.json").read_text())
    require(provenance.get("engine_commit")==runner.EXPECTED_ENGINE_PIN,"engine_pin")
    require(provenance.get("nnue_sha256")==runner.EXPECTED_NNUE_SHA256,"nnue_pin")
    shutil.copy2(work/"provenance.json",output/"provenance.json")
    report={
        "schema_version":SCHEMA,"status":"IN_PROGRESS",
        "pilot_result_sha256":PILOT_SHA,
        "root_diagnostic_run_id":DIAG_RUN_ID,
        "reference_budgets":list(NODE_BUDGETS),
        "shard":args.shard,"shard_count":SHARD_COUNT,"shard_size":SHARD_SIZE,
        "position_ordinals_expected":list(range(args.shard*SHARD_SIZE+1,(args.shard+1)*SHARD_SIZE+1)),
        "engine_provenance":provenance,
        "position_reports":[],
        "pilot_amendment_approved":False,
    }
    runner.SEARCH_TIMEOUT_SECONDS=900.0
    engine=runner.PilotUSIEngine(work,runner.REFERENCE_HASH_MB)
    try:
        for index in range(args.shard*SHARD_SIZE,(args.shard+1)*SHARD_SIZE):
            p=pilot["positions"][index];q=diag["positions"][index]
            row={
                "ordinal":index+1,"position_id":p["position_id"],
                "position_command":p["position_command"],"actual_move":p["actual_move"],
                "budget_reports":[],
            }
            for n in NODE_BUDGETS:
                root=q["fresh"+str(n)]
                best=root.get("rank1Move")
                require(isinstance(best,str) and best,"missing_root_rank1")
                budget={"nodeBudget":n,"rootRank1Move":best,"actualMove":p["actual_move"]}
                for kind,target in (("rank1",best),("actual",p["actual_move"])):
                    search=engine.search(p["position_command"],n,1,[target],
                        f"feasibility_{kind}_{n}",
                        output/"raw"/p["position_id"]/f"{kind}-{n}.usi.log")
                    budget[kind+"Search"]=sample_view(search,target,output)
                    require(search["goCommand"]==f"go nodes {n} searchmoves {target}",
                            "unexpected_go_command")
                row["budget_reports"].append(budget)
            report["position_reports"].append(row)
            (output/"report.json").write_text(
                json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8"
            )
            print("reference_played_shard",args.shard,index+1,p["position_id"],
                  [(b["nodeBudget"],b["actualSearch"]["searchmovesTargetBinding"],
                    b["rank1Search"]["searchmovesTargetBinding"]) for b in row["budget_reports"]],
                  flush=True)
    finally:
        engine.close()
    require([r["ordinal"] for r in report["position_reports"]]==report["position_ordinals_expected"],
            "partial_shard")
    report["status"]="SHARD_COMPLETE"
    (output/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print("targeted_16m64m_shard_complete",args.shard,flush=True)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
