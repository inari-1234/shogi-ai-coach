#!/usr/bin/env python3
"""Build19-VE1-Q formal qualification runner v4.

v4 keeps Q1-Q6/C2-C5 behavior from v3 and replaces C1 with the corrected,
evidence-backed dual calibration:
- startpos depth-1 known answers 164/108,
- corrected direct-SFEN depth-1 known answers 236/157,
- per-position FV_SCALE scale invariant with tolerance 40.

This remains VE1-Q only. It does not start VE1-B implementation, Build20, HDS-H,
or establish new 41/49/69 Semantic Authority.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
from typing import Any

import qualify as base
import qualify_v3 as v3
from ve1q_harness import (
    base_provenance,
    git_value,
    read_json,
    sha256_file,
    write_json,
    REPO_ROOT,
    RESULT_SCHEMA,
)

TOOL = Path(__file__).resolve().parent
CAL_SCHEMA = "ve1q-runtime-calibration-v2"
REPRO_SCHEMA = "ve1q-repro-v2"


def c1_runtime_fv_scale(work: Path, out_dir: Path) -> tuple[base.Gate, list[dict[str, Any]]]:
    gate = base.Gate("C1")
    provenances: list[dict[str, Any]] = []
    fixture = read_json(TOOL / "fixtures/runtime/runtime-calibration-v2.json")
    if fixture.get("schema_version") != CAL_SCHEMA:
        gate.add("calibration-schema", False, fixture.get("schema_version"))
        return gate, provenances

    cases = fixture.get("cases", [])
    if len(cases) != 2:
        gate.add("calibration-case-count", False, {"expected": 2, "actual": len(cases)})
        return gate, provenances

    for case in cases:
        actual: dict[str, dict[str, Any]] = {}
        for profile in ("app-current", "app-candidate"):
            expected = case["expected"][profile]
            run_id = f"c1-{case['id']}-{profile}"
            run_fixture = {
                "id": run_id,
                "probe": "fv-scale-depth1-known-answer-v2",
                "position": case["position"],
                "go": case["go"],
                "multipv": case["multipv"],
                "threads": case["threads"],
                "expected": expected,
                "authority": fixture.get("authority"),
                "correction_record": fixture.get("correction_record"),
            }
            try:
                parsed, prov = v3._run_exact_probe(
                    work,
                    out_dir,
                    run_id,
                    profile,
                    run_fixture,
                    case["position"],
                    case["go"],
                    int(case["multipv"]),
                )
                provenances.append(prov)
                pv = parsed["principalVariations"][0]
                score = pv["score"]
                actual[profile] = {
                    "depth": pv["depth"],
                    "score": score,
                    "bestmove": parsed["bestmove"],
                    "raw": prov["raw_usi_log_path"],
                    "fv_scale": prov["fv_scale"],
                }
                ok = (
                    prov["fv_scale"] == expected["fv_scale"]
                    and pv["depth"] == 1
                    and score is not None
                    and score["type"] == expected["score_type"]
                    and score["value"] == expected["score_value"]
                    and score["bound"] == expected["bound"]
                    and parsed["bestmove"] == expected["bestmove"]
                )
                gate.add(
                    f"{case['id']}:{profile}:known-answer",
                    ok,
                    {"expected": expected, "actual": actual[profile], "position": case["position"], "go": case["go"]},
                )
            except Exception as e:
                gate.add(
                    f"{case['id']}:{profile}:known-answer",
                    False,
                    {"exception": type(e).__name__, "message": str(e), "position": case["position"], "go": case["go"]},
                )

        invariant = case.get("scale_invariant", {})
        tolerance = int(invariant.get("tolerance", -1))
        a16 = actual.get("app-current")
        a24 = actual.get("app-candidate")
        v16 = a16.get("score", {}).get("value") if a16 and a16.get("score") else None
        v24 = a24.get("score", {}).get("value") if a24 and a24.get("score") else None
        type16 = a16.get("score", {}).get("type") if a16 and a16.get("score") else None
        type24 = a24.get("score", {}).get("type") if a24 and a24.get("score") else None
        if isinstance(v16, int) and isinstance(v24, int) and type16 == "cp" and type24 == "cp" and tolerance >= 0:
            scaled16 = v16 * 16
            scaled24 = v24 * 24
            delta = abs(scaled16 - scaled24)
            ok = delta <= tolerance
            detail = {
                "formula": invariant.get("formula"),
                "cp16": v16,
                "cp24": v24,
                "scaled16": scaled16,
                "scaled24": scaled24,
                "delta": delta,
                "tolerance": tolerance,
            }
        else:
            ok = False
            detail = {"reason": "missing-cp-known-answer-result", "actual": actual, "tolerance": tolerance}
        gate.add(f"{case['id']}:fv-scale-invariant", ok, detail)

    return gate, provenances


def static_checks_v4() -> base.Gate:
    gate = base.static_checks()
    try:
        cal = read_json(TOOL / "fixtures/runtime/runtime-calibration-v2.json")
        cases = {c.get("id"): c for c in cal.get("cases", [])}
        start = cases.get("startpos-depth1", {})
        corrected = cases.get("corrected-review-sfen-depth1", {})
        gate.add("runtime-calibration-v2-schema", cal.get("schema_version") == CAL_SCHEMA and len(cases) == 2, cal.get("schema_version"))
        gate.add(
            "runtime-calibration-startpos-values",
            start.get("expected", {}).get("app-current", {}).get("score_value") == 164
            and start.get("expected", {}).get("app-candidate", {}).get("score_value") == 108
            and start.get("expected", {}).get("app-current", {}).get("bestmove") == "7g7f"
            and start.get("expected", {}).get("app-candidate", {}).get("bestmove") == "7g7f",
            start.get("expected"),
        )
        gate.add(
            "runtime-calibration-corrected-values",
            corrected.get("position") == "position sfen lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8"
            and corrected.get("expected", {}).get("app-current", {}).get("score_value") == 236
            and corrected.get("expected", {}).get("app-candidate", {}).get("score_value") == 157
            and corrected.get("expected", {}).get("app-current", {}).get("bestmove") == "2b7g+"
            and corrected.get("expected", {}).get("app-candidate", {}).get("bestmove") == "2b7g+",
            {"position": corrected.get("position"), "expected": corrected.get("expected")},
        )
        invariant_ok = all(c.get("scale_invariant", {}).get("tolerance") == 40 for c in cases.values())
        gate.add("runtime-calibration-scale-invariants", invariant_ok, {k: v.get("scale_invariant") for k, v in cases.items()})
    except Exception as e:
        gate.add("runtime-calibration-v2-schema", False, str(e))

    correction = TOOL / "fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md"
    correction_text = correction.read_text(encoding="utf-8") if correction.exists() else ""
    gate.add(
        "c1-review-correction-recorded",
        correction.exists()
        and "Illegal Input Move : 3c3d" in correction_text
        and "lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8" in correction_text,
        str(correction),
    )

    policy = TOOL / "VE1_NUMERIC_EVIDENCE_POLICY.md"
    policy_text = policy.read_text(encoding="utf-8") if policy.exists() else ""
    policy_markers = ["Exact position identity", "Complete relevant command sequence", "Raw USI log", "Runtime provenance", "OBSERVATION_ONLY"]
    gate.add("ve1-numeric-evidence-policy", policy.exists() and all(x in policy_text for x in policy_markers), {"path": str(policy), "markers": policy_markers})

    try:
        repro = read_json(TOOL / "fixtures/repro/repro-cases.json")
        gate.add("expanded-repro-schema", repro.get("schema_version") == REPRO_SCHEMA and len(repro.get("fixed_node_cases", [])) >= 3, repro.get("schema_version"))
    except Exception as e:
        gate.add("expanded-repro-schema", False, str(e))

    backlog = REPO_ROOT / "Build19/BUILD19_VE1_B_ISSUES_20261009.md"
    gate.add("ve1b-accumulator-defect-recorded", backlog.exists() and "VE1B-001" in backlog.read_text(encoding="utf-8"), str(backlog))
    return gate


def _write_outputs_v4(
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
        "runner_revision": "v4-c1-corrected-dual-known-answer",
        "verdict": verdict,
        "gates": gates,
        "supplemental_conditions": conditions,
        "provenance_runs": provenances,
        "c1_authority": {
            "fixture": "fixtures/runtime/runtime-calibration-v2.json",
            "correction_record": "fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md",
            "numeric_evidence_policy": "VE1_NUMERIC_EVIDENCE_POLICY.md",
            "known_answer_positions": 2,
            "scale_invariant_tolerance": 40,
        },
        "scope": {
            "build20": "NOT_STARTED",
            "hds_h": "NOT_STARTED",
            "new_41_49_69_semantic_authority": "NOT_STARTED",
            "ve1b_implementation": "NOT_STARTED; issue backlog entry only",
        },
    }
    write_json(out_dir / "ve1q-results.json", results)
    if provenances:
        write_json(out_dir / "provenance-manifest.json", {"schema_version": "ve1q-provenance-v2", "runs": provenances})

    lines = ["# Build19-VE1-Q Qualification Summary", "", f"Result: **{verdict}**", "", "| Gate | Status |", "|---|---|"]
    for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6"):
        lines.append(f"| {q} | {gates[q]['status']} |")
    for c in ("C1", "C2", "C3", "C4", "C5"):
        lines.append(f"| {c} | {conditions[c]['status']} |")
    lines += [
        "",
        "C1 v4 uses two corrected depth-1 known-answer positions plus FV_SCALE scale invariants; every accepted numeric expectation is bound to fresh raw USI evidence in this run.",
        "41 / 49 / 69 old Frozen data remain Historical Diagnostic Fixture only.",
        "No Build20, HDS-H, VE1-B implementation, or new 41/49/69 Semantic Authority work was performed.",
    ]
    (out_dir / "VE1Q_SUMMARY.md").write_text("\n".join(lines) + "\n", encoding="utf-8")

    report = [
        "# Build19-VE1-Q Final Qualification Report",
        "",
        f"Verdict: **{verdict}**",
        "",
        "Formal scope: Verification Harness Qualification only.",
        "Independent-review conditions C1-C5 are mandatory for FREEZE in runner v4.",
        "C1 correction authority: two direct depth-1 positions (startpos 164/108; corrected SFEN 236/157), plus abs(cp16*16-cp24*24)<=40 for each position.",
        "Numeric expectations follow VE1_NUMERIC_EVIDENCE_POLICY.md and require exact position, relevant command sequence, raw USI log, and runtime provenance before acceptance.",
        "Profiles reproduce engine settings only; they do not reproduce the app comparison procedure (MultiPV candidate generation -> searchmoves comparison -> progressive search extension). That procedure remains for later VE1-E verification.",
        "41/49/69 old Frozen data: Historical Diagnostic Fixture only; not used as new Semantic Authority.",
        "Out of scope and not performed: Build20, HDS-H, VE1-B corrective implementation, new 41/49/69 Semantic Authority.",
        "",
        "## Formal gates",
        "",
    ]
    report += [f"- {q}: {gates[q]['status']}" for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6")]
    report += ["", "## Independent-review supplemental conditions", ""]
    report += [f"- {c}: {conditions[c]['status']}" for c in ("C1", "C2", "C3", "C4", "C5")]
    report += ["", "VE1B-001 records the scoreless-info accumulator defect as OPEN; parity PASS is not app-behavior correctness."]
    (out_dir / "VE1Q_FINAL_REPORT.md").write_text("\n".join(report) + "\n", encoding="utf-8")

    if verdict == "PASS":
        freeze = {
            "schema_version": "ve1q-freeze-candidate-v3",
            "stage": "Build19-VE1-Q",
            "status": "FREEZE_CANDIDATE",
            "qualified_repository_head": git_value("rev-parse", "HEAD") or os.environ.get("GITHUB_SHA"),
            "review_baseline_head": "ae3cb68a195fd16ac049f06c4cafa7cbb6dd220a",
            "gates": {q: gates[q]["status"] for q in ("Q1", "Q2", "Q3", "Q4", "Q5", "Q6")},
            "supplemental_conditions": {c: conditions[c]["status"] for c in ("C1", "C2", "C3", "C4", "C5")},
            "c1_runtime_calibration": {
                "fixture": "fixtures/runtime/runtime-calibration-v2.json",
                "correction_record": "fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md",
                "known_answer_positions": 2,
                "scale_invariant_tolerance": 40,
                "numeric_evidence_policy": "VE1_NUMERIC_EVIDENCE_POLICY.md",
            },
            "scope_exclusions": ["Build20", "HDS-H", "VE1-B implementation", "new 41/49/69 Semantic Authority"],
            "historical_fixture_policy": "41/49/69 old Frozen data = Historical Diagnostic Fixture only",
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
    static = static_checks_v4()
    q1 = base.q1_parity(out_dir)
    q2o, _ = base.q2_offline(out_dir)
    q4 = base.q4_profiles(out_dir)
    provenances: list[dict[str, Any]] = []

    if engine:
        q2e, p2 = base.q2_engine(work, out_dir)
        provenances += p2
        c1, p1 = c1_runtime_fv_scale(work, out_dir)
        provenances += p1
        c2, pcurrent = v3.c2_app_current_runtime(work, out_dir)
        provenances += pcurrent
        q3, p3 = v3.c5_reproducibility(work, out_dir)
        provenances += p3

        q2 = base.Gate("Q2")
        q2.cases = q2o.cases + q2e.cases
        for case in c1.cases:
            q2.cases.append({"id": "runtime-fv-scale:" + case["id"], "status": case["status"], "detail": case["detail"]})

        for case in c2.cases:
            if case["id"] == "app-current-engine-execution":
                q4.cases.append({"id": "app-current-runtime", "status": case["status"], "detail": case["detail"]})

        q1 = v3.q1_runtime_parity(out_dir, q1)
        q5 = v3.q5_provenance_strict(work, provenances)
        q6 = base.q6_negative(work, out_dir, base_provenance(work))
        conditions = v3._supplemental_conditions(c1, c2, q1, q5, q3)
    else:
        q2 = q2o
        q3 = base.Gate("Q3"); q3.add("engine-required", False, "offline run only")
        q5 = base.Gate("Q5"); q5.add("engine-required", False, "offline run only")
        q6 = base.q6_negative(None, out_dir, None)
        c1 = base.Gate("C1"); c1.add("engine-required", False, "offline run only")
        c2 = base.Gate("C2"); c2.add("engine-required", False, "offline run only")
        conditions = {
            "C1": c1.obj(),
            "C2": c2.obj(),
            "C3": {"status": "FAIL", "cases": [{"id": "engine-runtime-logs-required", "status": "FAIL", "detail": "offline run only"}]},
            "C4": q5.obj(),
            "C5": q3.obj(),
        }

    gates = {
        "Q1": q1.obj(),
        "Q2": q2.obj(),
        "Q3": q3.obj(),
        "Q4": q4.obj(),
        "Q5": q5.obj(),
        "Q6": q6.obj(),
        "STATIC": static.obj(),
    }
    return _write_outputs_v4(out_dir, gates, conditions, provenances, static, engine)


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
