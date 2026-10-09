#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any, Callable

from ve1q_harness import *

TOOL = Path(__file__).resolve().parent

class Gate:
    def __init__(self, name: str):
        self.name = name; self.cases: list[dict[str, Any]] = []
    def add(self, case_id: str, ok: bool, detail: Any = None):
        self.cases.append({"id": case_id, "status": "PASS" if ok else "FAIL", "detail": detail})
    @property
    def passed(self): return bool(self.cases) and all(c["status"] == "PASS" for c in self.cases)
    def obj(self): return {"status": "PASS" if self.passed else "FAIL", "cases": self.cases}


def q1_parity(out_dir: Path) -> Gate:
    gate = Gate("Q1")
    binary = out_dir / "bin" / "swift-parity-probe"
    compile_swift_probe(binary)
    fixture = read_json(TOOL / "fixtures/parity/parity-cases.json")
    if fixture.get("schema_version") != PARITY_SCHEMA: raise ValidationError("incompatible-schema-version")
    for case in fixture["cases"]:
        raw = TOOL / case["raw_log"]
        py = swift_compatible_accumulate(raw.read_text(encoding="utf-8").splitlines())
        sw = run_swift_probe(binary, raw)
        ok = py == sw
        gate.add(case["id"], ok, {"python": py, "swift": sw} if not ok else {"selected": py})
    return gate


def q2_offline(out_dir: Path) -> tuple[Gate, list[dict[str, Any]]]:
    gate = Gate("Q2-offline")
    evidence: list[dict[str, Any]] = []
    data = read_json(TOOL / "fixtures/known-answer/known-answer.json")
    validate_known_fixture(data)
    for c in data["cases"]:
        kind = c["kind"]
        if kind == "in_check":
            actual = is_in_check(c["sfen"]); ok = actual is c["expected"]
            gate.add(c["id"], ok, {"actual": actual})
        elif kind == "threat_guard":
            actual = threat_probe_allowed(c["sfen"]); ok = actual is c["expected_allowed"]
            gate.add(c["id"], ok, {"allowed": actual})
        elif kind == "strict_log":
            res = strict_validate_raw_log(TOOL / c["raw_log"], allow_bounds=c.get("allow_bounds", False))
            ok = True; detail: dict[str,Any] = {"selected": res}
            if "expected_bound" in c:
                bound = res["principalVariations"][0]["score"]["bound"]
                translated = None if bound is None else bound + "bound"
                ok = translated == c["expected_bound"]; detail["bound"] = translated
            if "expected_depths" in c:
                depths = [p["depth"] for p in res["principalVariations"]]
                ok = ok and depths == c["expected_depths"]; detail["depths"] = depths
            gate.add(c["id"], ok, detail)
        elif kind == "strict_log_reject":
            try:
                strict_validate_raw_log(TOOL / c["raw_log"])
                gate.add(c["id"], False, "unexpected PASS")
            except ValidationError as e:
                gate.add(c["id"], e.code == c["expected_error"], {"error": e.code})
    return gate, evidence


def q2_engine(work: Path, out_dir: Path) -> tuple[Gate, list[dict[str, Any]]]:
    gate = Gate("Q2-engine"); provs: list[dict[str, Any]] = []
    data = read_json(TOOL / "fixtures/known-answer/known-answer.json"); validate_known_fixture(data)
    for c in data["cases"]:
        try:
            if c["kind"] == "engine_mate":
                res, meta = execute_engine_search(work, out_dir, "q2-" + c["id"], "reference", c,
                    "position sfen " + c["sfen"], multipv=1, nodes=250000)
                p = finalize_run_provenance(work, meta); provs.append(p)
                res = strict_validate_raw_log(meta["_run"].raw_log_path, allow_bounds=False, require_complete_fields=True)
                pv = res["principalVariations"][0] if res["principalVariations"] else None
                ok = bool(pv and pv["score"] and pv["score"]["type"] == "mate"
                          and pv["score"]["bound"] is None and pv["score"]["value"] == c["expected_mate_ply"])
                if c.get("expected_bestmove") is not None: ok = ok and res["bestmove"] == c["expected_bestmove"]
                gate.add(c["id"], ok, {"bestmove": res["bestmove"], "primary": pv})
            elif c["kind"] == "engine_searchmoves":
                res, meta = execute_engine_search(work, out_dir, "q2-" + c["id"], "app-candidate", c,
                    "position sfen " + c["sfen"], searchmoves=c["searchmoves"], multipv=1, nodes=50000)
                p = finalize_run_provenance(work, meta); provs.append(p)
                res = strict_validate_raw_log(meta["_run"].raw_log_path, allow_bounds=False, require_complete_fields=True)
                gate.add(c["id"], res["bestmove"] == c["expected_bestmove"], {"bestmove": res["bestmove"]})
            elif c["kind"] == "in_check":
                res, meta = execute_engine_search(work, out_dir, "q2-in-check-engine", "app-candidate", c,
                    "position sfen " + c["sfen"], multipv=1, nodes=20000)
                p = finalize_run_provenance(work, meta); provs.append(p)
                ok = is_in_check(c["sfen"]) is True and res["bestmove"] not in {None, "none"}
                gate.add("in-check-engine-protocol", ok, {"bestmove": res["bestmove"]})
            elif c["kind"] == "engine_illegal_move":
                cfg = effective_profile("app-candidate"); cfg["nodes"] = 1000
                raw = out_dir / "raw/q2-illegal-move.usi.log"
                run = EngineRun("q2-illegal-move", "app-candidate", cfg, raw, utc_now())
                eng = None; rejected = False
                try:
                    eng = Engine(work, "app-candidate", cfg, raw)
                    eng.go(c["position"], "nodes 1000", multipv=1)
                except ValidationError as e:
                    rejected = e.code == "illegal-move"
                    run.exit_status = "EXPECTED_REJECTION" if rejected else "FAIL"
                finally:
                    if eng:
                        run.usi_options_reported = eng.usi_options_reported
                        run.options_applied = eng.options_applied
                        eng.close()
                    run.ended_at = utc_now()
                provs.append(run_provenance(base_provenance(work), run, c))
                gate.add(c["id"], rejected, {"rejected": rejected})
        except Exception as e:
            gate.add(c["id"], False, {"exception": type(e).__name__, "message": str(e)})
    return gate, provs


def q3_repro(work: Path, out_dir: Path) -> tuple[Gate, list[dict[str,Any]]]:
    gate = Gate("Q3"); provs=[]; views=[]
    fixture = {"id": "q3-startpos-fixed-nodes", "position": "position startpos", "repeats": 3, "nodes": 50000}
    for i in range(3):
        res, meta = execute_engine_search(work, out_dir, f"q3-repro-{i+1}", "app-candidate", fixture,
                                          "position startpos", nodes=50000, multipv=3)
        provs.append(finalize_run_provenance(work, meta))
        parsed = strict_validate_raw_log(meta["_run"].raw_log_path, allow_bounds=False, require_complete_fields=True)
        views.append(deterministic_repro_view(parsed))
    diffs=[]
    base=views[0]
    for i,v in enumerate(views[1:], start=2):
        if v != base: diffs.append({"run": i, "baseline": base, "actual": v})
    gate.add("threads1-fixed-nodes-three-runs", not diffs, {"runs": views, "differences": diffs})
    return gate, provs


def q4_profiles(out_dir: Path) -> Gate:
    gate=Gate("Q4"); profiles=load_profiles()
    required_fields={"fv_scale","search_mode","threads","hash_mb","multipv"}
    for name,p in profiles.items():
        fields=set(p)
        budget_ok = (p["search_mode"]=="nodes" and isinstance(p.get("nodes"),int)) or (p["search_mode"]=="movetime" and isinstance(p.get("movetime_ms"),int))
        gate.add(name, required_fields <= fields and budget_ok, p)
    return gate


def q5_provenance(work: Path, provenances: list[dict[str,Any]]) -> Gate:
    gate=Gate("Q5")
    if not provenances:
        gate.add("at-least-one-engine-run", False, "no engine provenance")
        return gate
    for i,p in enumerate(provenances):
        try:
            validate_provenance(p); gate.add(p.get("run_id",str(i)), True, {k:p.get(k) for k in ("profile","fv_scale","search_mode","node_budget","movetime_ms","raw_usi_log_path","exit_status")})
        except ValidationError as e:
            gate.add(p.get("run_id",str(i)), False, {"error":e.code,"message":str(e)})
    return gate


def _expect_reject(fn: Callable[[], Any], expected: str | set[str]) -> tuple[bool, str | None]:
    expected_set={expected} if isinstance(expected,str) else expected
    try: fn(); return False, None
    except ValidationError as e: return e.code in expected_set, e.code


def q6_negative(work: Path | None, out_dir: Path, base_prov: dict[str,Any] | None) -> Gate:
    gate=Gate("Q6"); neg=read_json(TOOL/"fixtures/negative/negative-cases.json")
    if neg.get("schema_version") != NEGATIVE_SCHEMA: raise ValidationError("incompatible-schema-version")
    good_known=read_json(TOOL/"fixtures/known-answer/known-answer.json")
    good_profiles=read_json(TOOL/"profiles.json")
    for c in neg["cases"]:
        m=c["mutation"]
        if m=="fv_scale_mismatch":
            bad=dict(load_profiles()["app-current"]); bad["fv_scale"]=24
            ok,err=_expect_reject(lambda:validate_profile_config("app-current",bad),"profile-requirement-mismatch")
        elif m=="nnue_sha_mismatch":
            if base_prov is None: ok,err=True,"offline-skipped-runtime-copy"
            else:
                bad=dict(base_prov); bad["nnue_sha256"]="0"*64
                sample=next((x for x in []),None)
                ok,err=_expect_reject(lambda: _validate_mutated_prov(bad),"nnue-sha-mismatch")
        elif m=="engine_pin_mismatch":
            if base_prov is None: ok,err=True,"offline-skipped-runtime-copy"
            else:
                bad=dict(base_prov); bad["yaneuraou_commit"]="0"*40
                ok,err=_expect_reject(lambda:_validate_mutated_prov(bad),"engine-pin-mismatch")
        elif m=="malformed_raw_log":
            ok,err=_expect_reject(lambda:strict_validate_raw_log(TOOL/"fixtures/known-answer/malformed.log"),"malformed-info")
        elif m=="missing_provenance":
            bad={}
            ok,err=_expect_reject(lambda:validate_provenance(bad),"missing-provenance")
        elif m=="illegal_fixture":
            bad=copy.deepcopy(good_known); bad["cases"][0]["sfen"]="9/9/9/9/9/9/9/9/9 b - 1"
            ok,err=_expect_reject(lambda:validate_known_fixture(bad),"illegal-fixture")
        elif m=="unknown_profile":
            ok,err=_expect_reject(lambda:effective_profile("does-not-exist"),"unknown-profile")
        elif m=="missing_raw_log":
            ok,err=_expect_reject(lambda:strict_validate_raw_log(TOOL/"fixtures/no-such.log"),"missing-raw-log")
        elif m=="broken_candidate_list":
            ok,err=_expect_reject(lambda:validate_candidate_list(["not-a-usi-move"]),"broken-candidate-list")
        elif m=="incompatible_schema":
            bad=copy.deepcopy(good_known); bad["schema_version"]="ve1q-known-answer-v999"
            ok,err=_expect_reject(lambda:validate_known_fixture(bad),"incompatible-schema-version")
        else: ok,err=False,"unknown mutation"
        gate.add(c["id"],ok,{"rejection":err})
    return gate


def _validate_mutated_prov(base: dict[str,Any]) -> None:
    p=dict(base)
    p.update({
        "fixture_sha256":"1"*64,"full_usi_options":["option name FV_SCALE type spin default 16 min 1 max 128"],
        "profile":"app-candidate","search_mode":"nodes","node_budget":50000,"movetime_ms":None,
        "threads":1,"hash_mb":64,"multipv":3,"fv_scale":24,"raw_usi_log_path":"raw/x.log",
        "start_timestamp":"2026-10-09T00:00:00Z","end_timestamp":"2026-10-09T00:00:01Z","exit_status":"PASS"
    })
    validate_provenance(p)


def static_checks() -> Gate:
    g=Gate("STATIC")
    try: load_profiles(); g.add("profiles-schema",True)
    except Exception as e: g.add("profiles-schema",False,str(e))
    for path, schema in [
        (TOOL/"fixtures/parity/parity-cases.json",PARITY_SCHEMA),
        (TOOL/"fixtures/known-answer/known-answer.json",KNOWN_SCHEMA),
        (TOOL/"fixtures/negative/negative-cases.json",NEGATIVE_SCHEMA)]:
        d=read_json(path); g.add(path.name,d.get("schema_version")==schema,{"schema":d.get("schema_version")})
    try: validate_known_fixture(read_json(TOOL/"fixtures/known-answer/known-answer.json")); g.add("known-fixture-legality",True)
    except Exception as e: g.add("known-fixture-legality",False,str(e))
    h=read_json(TOOL/"fixtures/build19-hds-41-49-69.json")
    g.add("historical-41-49-69-not-authority", h.get("authority_status")=="HISTORICAL_DIAGNOSTIC_FIXTURE_ONLY", h.get("authority_status"))
    return g


def summarize(results: dict[str,Any]) -> str:
    qnames=["Q1","Q2","Q3","Q4","Q5","Q6"]
    lines=["# Build19-VE1-Q Qualification Summary","",f"Result: **{results['verdict']}**","", "| Gate | Status |", "|---|---|"]
    for q in qnames: lines.append(f"| {q} | {results['gates'][q]['status']} |")
    lines += ["", "41 / 49 / 69 historical data were not used as new semantic truth.",
              "No Build20, HDS-H, or new 41/49/69 Semantic Authority work is included."]
    return "\n".join(lines)+"\n"


def run_all(work: Path, out_dir: Path, engine: bool) -> dict[str,Any]:
    out_dir.mkdir(parents=True,exist_ok=True)
    static=static_checks(); q1=q1_parity(out_dir); q2o,_=q2_offline(out_dir); q4=q4_profiles(out_dir)
    provenances=[]
    if engine:
        q2e,p2=q2_engine(work,out_dir); provenances+=p2
        q3,p3=q3_repro(work,out_dir); provenances+=p3
        q2=Gate("Q2"); q2.cases=q2o.cases+q2e.cases
        q5=q5_provenance(work,provenances)
        base=base_provenance(work)
        q6=q6_negative(work,out_dir,base)
    else:
        q2=q2o; q3=Gate("Q3"); q3.add("engine-required",False,"offline run only")
        q5=Gate("Q5"); q5.add("engine-required",False,"offline run only")
        q6=q6_negative(None,out_dir,None)
    gates={"Q1":q1.obj(),"Q2":q2.obj(),"Q3":q3.obj(),"Q4":q4.obj(),"Q5":q5.obj(),"Q6":q6.obj(),"STATIC":static.obj()}
    verdict="PASS" if static.passed and all(gates[q]["status"]=="PASS" for q in ("Q1","Q2","Q3","Q4","Q5","Q6")) else ("HOLD" if not engine else "FAIL")
    results={"schema_version":RESULT_SCHEMA,"stage":"Build19-VE1-Q","verdict":verdict,"gates":gates,"provenance_runs":provenances}
    write_json(out_dir/"ve1q-results.json",results)
    (out_dir/"VE1Q_SUMMARY.md").write_text(summarize(results),encoding="utf-8")
    if provenances:
        write_json(out_dir/"provenance-manifest.json",{"schema_version":"ve1q-provenance-v1","runs":provenances})
    final_lines = [
        "# Build19-VE1-Q Final Qualification Report", "",
        f"Verdict: **{verdict}**", "",
        "Formal scope: Verification Harness Qualification only.",
        "41/49/69 old Frozen data: Historical Diagnostic Fixture only; not used as new Semantic Authority.",
        "Out of scope and not performed: Build20, HDS-H, new 41/49/69 Semantic Authority.", "",
        "## Gate status", "",
    ]
    for q in ("Q1","Q2","Q3","Q4","Q5","Q6"):
        final_lines.append(f"- {q}: {gates[q]['status']}")
    final_lines += ["", "Machine-readable evidence: `ve1q-results.json`.", "Per-run provenance: `provenance-manifest.json` when engine qualification is executed.", "Raw USI evidence: `raw/*.usi.log`."]
    (out_dir/"VE1Q_FINAL_REPORT.md").write_text("\n".join(final_lines)+"\n",encoding="utf-8")
    if verdict == "PASS":
        freeze = {
            "schema_version":"ve1q-freeze-candidate-v1",
            "stage":"Build19-VE1-Q",
            "status":"FREEZE_CANDIDATE",
            "qualified_repository_head": git_value("rev-parse","HEAD") or os.environ.get("GITHUB_SHA"),
            "review_baseline_head":"ae3cb68a195fd16ac049f06c4cafa7cbb6dd220a",
            "gates":{q:gates[q]["status"] for q in ("Q1","Q2","Q3","Q4","Q5","Q6")},
            "scope_exclusions":["Build20","HDS-H","new 41/49/69 Semantic Authority"],
            "historical_fixture_policy":"41/49/69 old Frozen data = Historical Diagnostic Fixture only"
        }
        write_json(out_dir/"FREEZE_CANDIDATE_MANIFEST.json",freeze)
        sha_manifest={}
        for f in sorted(x for x in out_dir.rglob('*') if x.is_file() and x.name!='SHA256SUMS.json'):
            sha_manifest[str(f.relative_to(out_dir))]=sha256_file(f)
        write_json(out_dir/"SHA256SUMS.json",{"schema_version":"ve1q-sha-manifest-v1","files":sha_manifest})
    else:
        for name in ("FREEZE_CANDIDATE_MANIFEST.json","SHA256SUMS.json"):
            q=out_dir/name
            if q.exists(): q.unlink()
    return results


def main() -> int:
    ap=argparse.ArgumentParser()
    ap.add_argument("command",choices=["offline","qualify"])
    ap.add_argument("--work",default=os.environ.get("ENGINE_VERIFY_WORK",str(TOOL/".work")))
    ap.add_argument("--out",default=str(TOOL/"results/current"))
    args=ap.parse_args()
    r=run_all(Path(args.work),Path(args.out),engine=args.command=="qualify")
    print(json.dumps({"verdict":r["verdict"],"gates":{k:v["status"] for k,v in r["gates"].items()}},indent=2))
    return 0 if (r["verdict"]=="PASS" if args.command=="qualify" else r["gates"]["Q1"]["status"]=="PASS" and r["gates"]["Q4"]["status"]=="PASS" and r["gates"]["STATIC"]["status"]=="PASS") else 1

if __name__=="__main__": raise SystemExit(main())
