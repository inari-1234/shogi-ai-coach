#!/usr/bin/env python3
"""Build19-VE1-Q formal qualification runner v3.

v3 closes independent-review conditions C1-C5 before FREEZE:
- runtime FV_SCALE known answers for FV16/FV24,
- real app-current execution and explicit scope limitation,
- Swift/Python parity on every generated raw USI log plus protocol edges,
- raw-log-to-provenance FV_SCALE / NNUE evidence binding,
- expanded fixed-node reproducibility with a movetime sensitivity control.

This remains VE1-Q only. It does not start VE1-B implementation, Build20, HDS-H,
or create new 41/49/69 Semantic Authority.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

import qualify as base
from ve1q_harness import (
    Engine,
    EngineRun,
    ValidationError,
    base_provenance,
    canonical_sha,
    compile_swift_probe,
    deterministic_repro_view,
    effective_profile,
    execute_engine_search,
    finalize_run_provenance,
    git_value,
    load_profiles,
    read_json,
    run_provenance,
    run_swift_probe,
    sha256_file,
    strict_validate_raw_log,
    swift_compatible_accumulate,
    utc_now,
    validate_candidate_list,
    validate_provenance,
    write_json,
    REPO_ROOT,
    RESULT_SCHEMA,
)

TOOL = Path(__file__).resolve().parent
CAL_SCHEMA = "ve1q-runtime-calibration-v1"
REPRO_SCHEMA = "ve1q-repro-v2"


def _resolve_raw(path_text: str) -> Path:
    p = Path(path_text)
    return p if p.is_absolute() else REPO_ROOT / p


def _read_raw_lines(path_text: str) -> list[str]:
    p = _resolve_raw(path_text)
    if not p.exists():
        raise ValidationError("missing-raw-log", str(p))
    return p.read_text(encoding="utf-8").splitlines()


def _run_exact_probe(
    work: Path,
    out_dir: Path,
    run_id: str,
    profile_name: str,
    fixture: dict[str, Any],
    position: str,
    go_command: str,
    multipv: int,
) -> tuple[dict[str, Any], dict[str, Any]]:
    cfg = effective_profile(profile_name)
    cfg["multipv"] = multipv
    raw = out_dir / "raw" / f"{run_id}.usi.log"
    run = EngineRun(run_id, profile_name, cfg, raw, utc_now())
    eng: Engine | None = None
    rc = -999
    try:
        eng = Engine(work, profile_name, cfg, raw)
        eng.go(position, go_command, multipv=multipv)
        run.usi_options_reported = eng.usi_options_reported
        run.options_applied = eng.options_applied
        run.exit_status = "PASS"
    except Exception:
        run.exit_status = "FAIL"
        raise
    finally:
        if eng is not None:
            run.usi_options_reported = eng.usi_options_reported
            run.options_applied = eng.options_applied
            rc = eng.close()
        run.ended_at = utc_now()
        if run.exit_status == "PASS" and rc not in (0, -999):
            run.exit_status = f"ENGINE_EXIT_{rc}"

    parsed = strict_validate_raw_log(raw, allow_bounds=False, require_complete_fields=True)
    prov = run_provenance(base_provenance(work), run, fixture)
    prov["actual_go_command"] = go_command
    prov["qualification_probe"] = fixture.get("probe", "exact-go")
    return parsed, prov


def c1_runtime_fv_scale(work: Path, out_dir: Path) -> tuple[base.Gate, list[dict[str, Any]]]:
    gate = base.Gate("C1")
    provenances: list[dict[str, Any]] = []
    fixture = read_json(TOOL / "fixtures/runtime/runtime-calibration.json")
    if fixture.get("schema_version") != CAL_SCHEMA:
        gate.add("calibration-schema", False, fixture.get("schema_version"))
        return gate, provenances

    for profile in ("app-current", "app-candidate"):
        expected = fixture["expected"][profile]
        run_fixture = {
            "id": f"fv-scale-known-answer-{profile}",
            "probe": "fv-scale-depth1-known-answer",
            "position": fixture["position"],
            "go": fixture["go"],
            "expected": expected,
        }
        try:
            parsed, prov = _run_exact_probe(
                work,
                out_dir,
                f"c1-fvscale-{profile}",
                profile,
                run_fixture,
                fixture["position"],
                fixture["go"],
                int(fixture.get("multipv", 1)),
            )
            provenances.append(prov)
            pv = parsed["principalVariations"][0]
            score = pv["score"]
            ok = (
                prov["fv_scale"] == expected["fv_scale"]
                and pv["depth"] == 1
                and score is not None
                and score["type"] == expected["score_type"]
                and score["value"] == expected["score_value"]
                and score["bound"] == expected["bound"]
            )
            gate.add(
                profile,
                ok,
                {
                    "expected": expected,
                    "actual": {"depth": pv["depth"], "score": score, "bestmove": parsed["bestmove"]},
                    "raw": prov["raw_usi_log_path"],
                },
            )
        except Exception as e:
            gate.add(profile, False, {"exception": type(e).__name__, "message": str(e)})
    return gate, provenances


def c2_app_current_runtime(work: Path, out_dir: Path) -> tuple[base.Gate, list[dict[str, Any]]]:
    gate = base.Gate("C2")
    provenances: list[dict[str, Any]] = []
    fixture = {"id": "app-current-default-runtime", "position": "position startpos", "purpose": "profile-runtime-proof"}
    try:
        parsed, meta = execute_engine_search(
            work,
            out_dir,
            "c2-app-current-default",
            "app-current",
            fixture,
            "position startpos",
            movetime=load_profiles()["app-current"]["movetime_ms"],
            multipv=3,
        )
        prov = finalize_run_provenance(work, meta)
        provenances.append(prov)
        gate.add(
            "app-current-engine-execution",
            parsed.get("bestmove") not in {None, "none"} and prov["profile"] == "app-current" and prov["fv_scale"] == 16,
            {"bestmove": parsed.get("bestmove"), "profile": prov["profile"], "fv_scale": prov["fv_scale"], "raw": prov["raw_usi_log_path"]},
        )
    except Exception as e:
        gate.add("app-current-engine-execution", False, {"exception": type(e).__name__, "message": str(e)})

    readme = (TOOL / "README.md").read_text(encoding="utf-8")
    marker = "Profiles reproduce engine settings only; they do not reproduce the app comparison procedure"
    gate.add("profile-scope-limitation-documented", marker in readme, {"required_marker": marker})
    return gate, provenances


def _fixed_repro_case(work: Path, out_dir: Path, case: dict[str, Any]) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    views: list[dict[str, Any]] = []
    provs: list[dict[str, Any]] = []
    rank_issues: list[dict[str, Any]] = []
    expected_ranks = list(range(1, int(case["multipv"]) + 1))
    searchmoves = case.get("searchmoves")
    if searchmoves is not None:
        validate_candidate_list(searchmoves)

    for i in range(int(case["repeats"])):
        run_id = f"c5-{case['id']}-{i+1}"
        _, meta = execute_engine_search(
            work,
            out_dir,
            run_id,
            case["profile"],
            case,
            case["position"],
            searchmoves=searchmoves,
            nodes=int(case["nodes"]),
            multipv=int(case["multipv"]),
        )
        provs.append(finalize_run_provenance(work, meta))
        parsed = strict_validate_raw_log(meta["_run"].raw_log_path, allow_bounds=True, require_complete_fields=True)
        view = deterministic_repro_view(parsed)
        ranks = [pv["multipv"] for pv in view["principalVariations"]]
        if ranks != expected_ranks:
            rank_issues.append({"run": i + 1, "expected": expected_ranks, "actual": ranks})
        views.append(view)

    differences: list[dict[str, Any]] = []
    baseline = views[0]
    for i, view in enumerate(views[1:], start=2):
        if view != baseline:
            differences.append({"run": i, "baseline": baseline, "actual": view})
    return {
        "ok": not differences and not rank_issues,
        "runs": views,
        "differences": differences,
        "rank_issues": rank_issues,
        "required_ranks": expected_ranks,
        "bounded_entries_included": True,
    }, provs


def c5_reproducibility(work: Path, out_dir: Path) -> tuple[base.Gate, list[dict[str, Any]]]:
    gate = base.Gate("Q3")
    provs: list[dict[str, Any]] = []
    cfg = read_json(TOOL / "fixtures/repro/repro-cases.json")
    if cfg.get("schema_version") != REPRO_SCHEMA:
        gate.add("repro-schema", False, cfg.get("schema_version"))
        return gate, provs

    for case in cfg["fixed_node_cases"]:
        try:
            detail, ps = _fixed_repro_case(work, out_dir, case)
            provs.extend(ps)
            gate.add(case["id"], bool(detail["ok"]), detail)
        except Exception as e:
            gate.add(case["id"], False, {"exception": type(e).__name__, "message": str(e)})

    control = cfg["movetime_control"]
    control_views: list[dict[str, Any]] = []
    control_errors: list[dict[str, Any]] = []
    for i in range(int(control["repeats"])):
        try:
            _, meta = execute_engine_search(
                work,
                out_dir,
                f"c5-{control['id']}-{i+1}",
                control["profile"],
                control,
                control["position"],
                movetime=int(control["movetime_ms"]),
                multipv=int(control["multipv"]),
            )
            provs.append(finalize_run_provenance(work, meta))
            parsed = strict_validate_raw_log(meta["_run"].raw_log_path, allow_bounds=True, require_complete_fields=True)
            control_views.append(deterministic_repro_view(parsed))
        except Exception as e:
            control_errors.append({"run": i + 1, "exception": type(e).__name__, "message": str(e)})
    unique = sorted({canonical_sha(v) for v in control_views})
    gate.add(
        control["id"],
        not control_errors and len(control_views) == int(control["repeats"]) and len(unique) >= 2,
        {"unique_deterministic_views": len(unique), "repeats": len(control_views), "errors": control_errors, "runs": control_views},
    )
    return gate, provs


def _raw_provenance_audit(p: dict[str, Any], work: Path) -> dict[str, Any]:
    lines = _read_raw_lines(p["raw_usi_log_path"])
    fv_prefix = "> setoption name FV_SCALE value "
    eval_prefix = "> setoption name EvalDir value "
    load_prefix = "info string loading eval file : "
    fv_values = [line[len(fv_prefix):].strip() for line in lines if line.startswith(fv_prefix)]
    eval_dirs = [line[len(eval_prefix):].strip() for line in lines if line.startswith(eval_prefix)]
    loaded = [line[len(load_prefix):].strip() for line in lines if line.startswith(load_prefix)]
    go_commands = [line[2:].strip() for line in lines if line.startswith("> go ")]

    expected_nnue = (work / "eval" / "nn.bin").resolve()
    loaded_path = Path(loaded[-1]).resolve() if loaded else None
    loaded_sha = sha256_file(loaded_path) if loaded_path is not None and loaded_path.exists() else None
    fv_actual = int(fv_values[-1]) if fv_values and fv_values[-1].lstrip("-").isdigit() else None
    eval_dir = Path(eval_dirs[-1]).resolve() if eval_dirs else None

    checks = {
        "fv_setoption_matches_provenance": fv_actual == p["fv_scale"],
        "evaldir_matches_expected": eval_dir == (work / "eval").resolve(),
        "loaded_nnue_path_matches": loaded_path == expected_nnue,
        "loaded_nnue_sha_matches_provenance": loaded_sha == p["nnue_sha256"],
        "go_command_present": bool(go_commands),
    }
    return {
        "ok": all(checks.values()),
        "checks": checks,
        "fv_scale_raw": fv_actual,
        "fv_scale_provenance": p["fv_scale"],
        "eval_dir_raw": None if eval_dir is None else str(eval_dir),
        "loaded_nnue_raw": None if loaded_path is None else str(loaded_path),
        "loaded_nnue_sha256": loaded_sha,
        "actual_go_commands": go_commands,
    }


def q5_provenance_strict(work: Path, provenances: list[dict[str, Any]]) -> base.Gate:
    gate = base.Gate("Q5")
    if not provenances:
        gate.add("at-least-one-engine-run", False, "no engine provenance")
        return gate
    for i, p in enumerate(provenances):
        run_id = p.get("run_id", str(i))
        try:
            validate_provenance(p)
            audit = _raw_provenance_audit(p, work)
            gate.add(run_id, bool(audit["ok"]), audit)
        except Exception as e:
            gate.add(run_id, False, {"exception": type(e).__name__, "message": str(e)})
    return gate


def q1_runtime_parity(out_dir: Path, gate: base.Gate) -> base.Gate:
    binary = out_dir / "bin" / "swift-parity-probe"
    if not binary.exists():
        compile_swift_probe(binary)
    raw_files = sorted((out_dir / "raw").glob("*.usi.log"))
    if not raw_files:
        gate.add("runtime-raw-logs-present", False, "no generated raw logs")
        return gate
    for raw in raw_files:
        try:
            py = swift_compatible_accumulate(raw.read_text(encoding="utf-8").splitlines())
            sw = run_swift_probe(binary, raw)
            gate.add(
                "runtime:" + raw.name,
                py == sw,
                {"python": py, "swift": sw} if py != sw else {"selected": py, "source": str(raw)},
            )
        except Exception as e:
            gate.add("runtime:" + raw.name, False, {"exception": type(e).__name__, "message": str(e)})
    return gate


def _supplemental_conditions(
    c1: base.Gate,
    c2: base.Gate,
    q1: base.Gate,
    q5: base.Gate,
    q3: base.Gate,
) -> dict[str, dict[str, Any]]:
    runtime_q1 = [c for c in q1.cases if c["id"].startswith("runtime:")]
    protocol_edge = [c for c in q1.cases if c["id"] == "protocol-edge-lines"]
    return {
        "C1": c1.obj(),
        "C2": c2.obj(),
        "C3": {"status": "PASS" if runtime_q1 and protocol_edge and all(c["status"] == "PASS" for c in runtime_q1 + protocol_edge) else "FAIL", "cases": runtime_q1 + protocol_edge},
        "C4": q5.obj(),
        "C5": q3.obj(),
    }


def static_checks_v3() -> base.Gate:
    gate = base.static_checks()
    try:
        cal = read_json(TOOL / "fixtures/runtime/runtime-calibration.json")
        gate.add("runtime-calibration-schema", cal.get("schema_version") == CAL_SCHEMA, cal.get("schema_version"))
        expected = cal.get("expected", {})
        gate.add(
            "runtime-calibration-independent-values",
            expected.get("app-current", {}).get("score_value") == 236 and expected.get("app-candidate", {}).get("score_value") == 157,
            expected,
        )
    except Exception as e:
        gate.add("runtime-calibration-schema", False, str(e))
    try:
        repro = read_json(TOOL / "fixtures/repro/repro-cases.json")
        gate.add("expanded-repro-schema", repro.get("schema_version") == REPRO_SCHEMA and len(repro.get("fixed_node_cases", [])) >= 3, repro.get("schema_version"))
    except Exception as e:
        gate.add("expanded-repro-schema", False, str(e))
    backlog = REPO_ROOT / "Build19/BUILD19_VE1_B_ISSUES_20261009.md"
    gate.add("ve1b-accumulator-defect-recorded", backlog.exists() and "VE1B-001" in backlog.read_text(encoding="utf-8"), str(backlog))
    return gate


def _write_outputs(
    out_dir: Path,
    gates: dict[str, dict[str, Any]],
    conditions: dict[str, dict[str, Any]],
    provenances: list[dict[str, Any]],
    static: base.Gate,
    engine: bool,
) -> dict[str, Any]:
    formal_pass = static.passed and all(gates[q]["status"] == "PASS" for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"))
    condition_pass = all(conditions[c]["status"] == "PASS" for c in ("C1", "C2", "C3", "C4", "C5"))
    verdict = "PASS" if engine and formal_pass and condition_pass else ("HOLD" if not engine else "FAIL")
    results = {
        "schema_version": RESULT_SCHEMA,
        "stage": "Build19-VE1-Q",
        "runner_revision": "v3-independent-review-supplement",
        "verdict": verdict,
        "gates": gates,
        "supplemental_conditions": conditions,
        "provenance_runs": provenances,
        "scope": {
            "build20": "NOT_STARTED",
            "hds_h": "NOT_STARTED",
            "new_41_49_69_semantic_authority": "NOT_STARTED",
            "ve1b_implementation": "NOT_STARTED; issue backlog entry only"
        }
    }
    write_json(out_dir / "ve1q-results.json", results)
    if provenances:
        write_json(out_dir / "provenance-manifest.json", {"schema_version": "ve1q-provenance-v2", "runs": provenances})

    lines = ["# Build19-VE1-Q Qualification Summary", "", f"Result: **{verdict}**", "", "| Gate | Status |", "|---|---|"]
    for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"):
        lines.append(f"| {q} | {gates[q]['status']} |")
    for c in ("C1", "C2", "C3", "C4", "C5"):
        lines.append(f"| {c} | {conditions[c]['status']} |")
    lines += ["", "41 / 49 / 69 old Frozen data remain Historical Diagnostic Fixture only.", "No Build20, HDS-H, VE1-B implementation, or new 41/49/69 Semantic Authority work was performed."]
    (out_dir / "VE1Q_SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    report = [
        "# Build19-VE1-Q Final Qualification Report", "", f"Verdict: **{verdict}**", "",
        "Formal scope: Verification Harness Qualification only.",
        "Independent-review conditions C1-C5 are mandatory for FREEZE in runner v3.",
        "Profiles reproduce engine settings only; they do not reproduce the app comparison procedure (MultiPV candidate generation -> searchmoves comparison -> progressive search extension). That procedure remains for later VE1-E verification.",
        "41/49/69 old Frozen data: Historical Diagnostic Fixture only; not used as new Semantic Authority.",
        "Out of scope and not performed: Build20, HDS-H, VE1-B corrective implementation, new 41/49/69 Semantic Authority.", "",
        "## Formal gates", ""
    ]
    report += [f"- {q}: {gates[q]['status']}" for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6")]
    report += ["", "## Independent-review supplemental conditions", ""]
    report += [f"- {c}: {conditions[c]['status']}" for c in ("C1", "C2", "C3", "C4", "C5")]
    report += ["", "VE1B-001 records the scoreless-info accumulator defect as OPEN; parity PASS is not app-behavior correctness."]
    (out_dir / "VE1Q_FINAL_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8")

    if verdict == "PASS":
        freeze = {
            "schema_version": "ve1q-freeze-candidate-v2",
            "stage": "Build19-VE1-Q",
            "status": "FREEZE_CANDIDATE",
            "qualified_repository_head": git_value("rev-parse", "HEAD") or os.environ.get("GITHUB_SHA"),
            "review_baseline_head": "ae3cb68a195fd16ac049f06c4cafa7cbb6dd220a",
            "gates": {q: gates[q]["status"] for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6")},
            "supplemental_conditions": {c: conditions[c]["status"] for c in ("C1", "C2", "C3", "C4", "C5")},
            "scope_exclusions": ["Build20", "HDS-H", "VE1-B implementation", "new 41/49/69 Semantic Authority"],
            "historical_fixture_policy": "41/49/69 old Frozen data = Historical Diagnostic Fixture only"
        }
        write_json(out_dir / "FREEZE_CANDIDATE_MANIFEST.json", freeze)
        sha_manifest: dict[str, str] = {}
        for f in sorted(x for x in out_dir.rglob("*") if x.is_file() and x.name != "SHA256SUMS.json"):
            sha_manifest[str(f.relative_to(out_dir))] = sha256_file(f)
        write_json(out_dir / "SHA256SUMS.json", {"schema_version": "ve1q-sha-manifest-v1", "files": sha_manifest})
    else:
        for name in ("FREEZE_CANDIDATE_MANIFEST.json", "SHA256SUMS.json"):
            p = out_dir / name
            if p.exists():
                p.unlink()
    return results


def run_all(work: Path, out_dir: Path, engine: bool) -> dict[str, Any]:
    out_dir.mkdir(parents=True, exist_ok=True)
    static = static_checks_v3()
    q1 = base.q1_parity(out_dir)
    q2o, _ = base.q2_offline(out_dir)
    q4 = base.q4_profiles(out_dir)
    provenances: list[dict[str, Any]] = []

    if engine:
        q2e, p2 = base.q2_engine(work, out_dir)
        provenances += p2
        c1, p1 = c1_runtime_fv_scale(work, out_dir)
        provenances += p1
        c2, pcurrent = c2_app_current_runtime(work, out_dir)
        provenances += pcurrent
        q3, p3 = c5_reproducibility(work, out_dir)
        provenances += p3

        q2 = base.Gate("Q2")
        q2.cases = q2o.cases + q2e.cases
        for case in c1.cases:
            q2.cases.append({"id": "runtime-fv-scale:" + case["id"], "status": case["status"], "detail": case["detail"]})

        for case in c2.cases:
            if case["id"] == "app-current-engine-execution":
                q4.cases.append({"id": "app-current-runtime", "status": case["status"], "detail": case["detail"]})

        q1 = q1_runtime_parity(out_dir, q1)
        q5 = q5_provenance_strict(work, provenances)
        q6 = base.q6_negative(work, out_dir, base_provenance(work))
        conditions = _supplemental_conditions(c1, c2, q1, q5, q3)
    else:
        q2 = q2o
        q3 = base.Gate("Q3"); q3.add("engine-required", False, "offline run only")
        q5 = base.Gate("Q5"); q5.add("engine-required", False, "offline run only")
        q6 = base.q6_negative(None, out_dir, None)
        c1 = base.Gate("C1"); c1.add("engine-required", False, "offline run only")
        c2 = base.Gate("C2"); c2.add("engine-required", False, "offline run only")
        conditions = {
            "C1": c1.obj(), "C2": c2.obj(),
            "C3": {"status": "FAIL", "cases": [{"id": "engine-runtime-logs-required", "status": "FAIL", "detail": "offline run only"}]},
            "C4": q5.obj(), "C5": q3.obj()
        }

    gates = {
        "Q1": q1.obj(), "Q2": q2.obj(), "Q3": q3.obj(), "Q4": q4.obj(),
        "Q5": q5.obj(), "Q6": q6.obj(), "STATIC": static.obj()
    }
    return _write_outputs(out_dir, gates, conditions, provenances, static, engine)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("command", choices=["offline", "qualify"])
    ap.add_argument("--work", default=os.environ.get("ENGINE_VERIFY_WORK", str(TOOL / ".work")))
    ap.add_argument("--out", default=str(TOOL / "results/current"))
    args = ap.parse_args()
    r = run_all(Path(args.work), Path(args.out), engine=args.command == "qualify")
    summary = {
        "verdict": r["verdict"],
        "gates": {k: v["status"] for k, v in r["gates"].items()},
        "supplemental_conditions": {k: v["status"] for k, v in r["supplemental_conditions"].items()},
    }
    print(json.dumps(summary, indent=2))
    if args.command == "qualify":
        return 0 if r["verdict"] == "PASS" else 1
    return 0 if r["gates"]["Q1"]["status"] == "PASS" and r["gates"]["Q4"]["status"] == "PASS" and r["gates"]["STATIC"]["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
