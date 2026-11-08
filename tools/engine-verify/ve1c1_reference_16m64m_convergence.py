#!/usr/bin/env python3
"""Pre-VE1-D feasibility diagnostic: re-search ALL exposed 16 natural pilot positions.

Independent, frozen conditions at 16M and 64M nodes; original 4M/16M remain
archived, unchanged. A diagnostic report cannot select new C1 budgets or delta.
"""
from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path
from typing import Any

import ve1c1_pilot as contract
import ve1c1_pilot_evaluator as evaluator
import ve1c1_pilot_runner as base
# Installs the same coherent-block guard used by the frozen natural pilot.
import ve1c1_pilot_block_runner as coherent  # noqa: F401

SCHEMA = "ve1c1-reference-16m64m-feasibility-diagnostic-v1"
EXPECTED_RESULT_SHA = "860cb704e8df15e301b037b9994ff2bb15c3cbcb8a14440cdfa15e46797214ea"
EXPECTED_EVALUATION_SHA = "10e9d86beca6763bd01bb4aa21bc8b2b105949fbd305a30b4cbe6bc6f3d42d0a"
BUDGETS = (16_000_000, 64_000_000)
THRESHOLD = contract.TAU_GOOD_REF


def fail(message: str) -> None:
    raise contract.PilotError(message)


def _require(cond: bool, msg: str) -> None:
    if not cond:
        fail(msg)


def _score(x: dict[str, Any]) -> dict[str, Any]:
    return {"kind": x.get("scoreKind"), "value": x.get("scoreValue"),
            "root": (x.get("pv") or [None])[0]}


def summarize_root(root: dict[str, Any]) -> dict[str, Any]:
    structure = evaluator.reference_root_structure(root)
    lines = root.get("selectedSnapshot") or []
    rank2 = None
    if len(lines) >= 2:
        loss_result = evaluator._severity_class_from_scores(
            evaluator._score(lines[0]), evaluator._score(lines[1])
        )
        rank2 = loss_result.get("loss")
    return {
        "status": structure.get("status"),
        "label": structure.get("label"),
        "reason": structure.get("reason"),
        "goodSet": structure.get("goodSet"),
        "rank1Move": structure.get("rank1Move"),
        "rank1Score": _score(lines[0]) if len(lines) >= 1 else None,
        "rank2Score": _score(lines[1]) if len(lines) >= 2 else None,
        "rank2ExpectedScoreLoss": rank2,
        "rank2DistanceFromTauGood": None if rank2 is None else rank2 - THRESHOLD,
        "snapshotCoherent": root.get("candidateBlockStatus") == "RESOLVED",
        "hasCompletedExactIteration": root.get("hasCompletedExactIteration"),
        "selectedSnapshotEvidenceStatus": root.get("selectedSnapshotEvidenceStatus"),
        "maxObservedNodes": root.get("maxObservedNodes"),
        "terminalBestmove": root.get("bestmove"),
        "rawLogPath": root.get("rawLogPath"),
        "ttGeneration": root.get("ttGeneration"),
    }


def validate_frozen_result(result: dict[str, Any], evaluation: dict[str, Any]) -> None:
    _require(result.get("result_sha256") == EXPECTED_RESULT_SHA, "pilot_result_digest_identity")
    _require(result.get("schema_version") == contract.PILOT_RESULT_SCHEMA, "pilot_result_schema")
    _require(result.get("run_kind") == "excluded_natural_pilot", "pilot_run_kind")
    _require(result.get("authority_commit") == contract.AUTHORITY_COMMIT, "pilot_authority")
    _require(len(result.get("positions", [])) == 16, "pilot_not_16_positions")
    _require(evaluation.get("evaluation_sha256") == EXPECTED_EVALUATION_SHA, "pilot_evaluation_digest_identity")
    _require(evaluation.get("summary", {}).get("referenceCrossBudgetStructureStatus") ==
             {"RESOLVED": 13, "DISPUTED": 3}, "pilot_baseline_3disputed")
    _require(evaluation.get("F", {}).get("policy") == "F2", "pilot_F_was_changed")
    _require(evaluation.get("E", {}).get("policy") == "E0", "pilot_E_was_changed")
    for i, p in enumerate(result["positions"], 1):
        b = (p.get("reference") or {}).get("budgets") or []
        _require([x.get("nodeBudget") for x in b] == [4_000_000, 16_000_000],
                 f"pilot_reference_budget_identity:{i}")
        _require(p.get("effectiveRootMultiPV") in (2, 3), f"pilot_root_cardinality:{i}")
        for budget in b:
            _require(budget.get("root", {}).get("candidateBlockStatus") == "RESOLVED",
                     f"frozen_root_not_resolved:{i}")
    print("frozen_baseline_16_positions_and_4m16m=PASS", flush=True)


def count_cross_budget(roots_a: list[dict[str, Any]],
                       roots_b: list[dict[str, Any]]) -> dict[str, Any]:
    report = evaluator.cross_budget_structure({
        "budgets": [
            {"nodeBudget": BUDGETS[0], "root": roots_a[0]},
            {"nodeBudget": BUDGETS[1], "root": roots_b[0]},
        ]
    })
    return report


def run(result: dict[str, Any], work: Path, out: Path) -> dict[str, Any]:
    provenance = json.loads((work / "provenance.json").read_text(encoding="utf-8"))
    _require(provenance.get("engine_commit") == base.EXPECTED_ENGINE_PIN,
             "engine_pin_mismatch")
    _require(provenance.get("nnue_sha256") == base.EXPECTED_NNUE_SHA256,
             "nnue_digest_mismatch")
    out.mkdir(parents=True, exist_ok=True)
    shutil.copy2(work / "provenance.json", out / "engine-provenance.json")

    base.SEARCH_TIMEOUT_SECONDS = 900.0  # Timeout is diagnostic abort only, not a search budget.
    engine = base.PilotUSIEngine(work, base.REFERENCE_HASH_MB)
    rows: list[dict[str, Any]] = []
    report: dict[str, Any] = {
        "schema_version": SCHEMA, "status": "IN_PROGRESS",
        "authority_pilot_result_sha256": EXPECTED_RESULT_SHA,
        "authority_pilot_evaluation_sha256": EXPECTED_EVALUATION_SHA,
        "engine_provenance": provenance, "search_node_budgets": list(BUDGETS),
        "frozen_budgets_for_comparison": [4_000_000, 16_000_000],
        "threshold_tau_good": THRESHOLD,
        "not_authority_not_amendment": True,
        "processed_positions": 0, "positions": rows,
    }
    try:
        for i, p in enumerate(result["positions"], 1):
            pid = p["position_id"]
            historical = p["reference"]["budgets"]
            row: dict[str, Any] = {
                "index": i, "position_id": pid,
                "game_sha256": p["game_sha256"],
                "ply": p["ply"],
                "position_command": p["position_command"],
                "rootMultiPV": p["effectiveRootMultiPV"],
                "original4M": summarize_root(historical[0]["root"]),
                "original16M": summarize_root(historical[1]["root"]),
                "frozen4M16M": evaluator.cross_budget_structure({"budgets": historical}),
            }
            fresh = []
            for n in BUDGETS:
                attempt = engine.search(
                    p["position_command"], n, p["effectiveRootMultiPV"], [],
                    f"reference_root_{n}", out / "raw" / pid / f"reference-root-{n}.log"
                )
                _require(attempt.get("goCommand") == f"go nodes {n}", f"node_budget_command:{pid}:{n}")
                _require(attempt.get("multiPV") == p["effectiveRootMultiPV"],
                         f"root_multipv:{pid}:{n}")
                _require(attempt.get("rawLogPath"), f"raw_missing:{pid}:{n}")
                _require(Path(attempt["rawLogPath"]).stat().st_size > 0,
                         f"raw_empty:{pid}:{n}")
                fresh.append(attempt)
                row["fresh" + str(n)] = summarize_root(attempt)
                # Persist intermediate evidence after each search; a workflow abort
                # must not masquerade as a completed 16-position diagnostic.
                (out / "stage.json").write_text(json.dumps({
                    "status": "RUNNING", "position": i, "position_id": pid, "budget": n
                }, indent=2) + "\n", encoding="utf-8")
            row["fresh16M64M"] = evaluator.cross_budget_structure({
                "budgets": [
                    {"nodeBudget": BUDGETS[0], "root": fresh[0]},
                    {"nodeBudget": BUDGETS[1], "root": fresh[1]},
                ]
            })
            a = row["original4M"]["rank2ExpectedScoreLoss"]
            b = row["fresh16000000"]["rank2ExpectedScoreLoss"]
            c = row["fresh64000000"]["rank2ExpectedScoreLoss"]
            row["rank2LossTrajectory"] = {"4M": a, "16M": b, "64M": c}
            row["monotonicallyDecreasing4M16M64M"] = (
                a >= b >= c if all(v is not None for v in [a,b,c]) else None
            )
            row["fresh16MMatchesFrozenStructure"] = (
                row["fresh16000000"]["label"] == row["original16M"]["label"]
                and row["fresh16000000"]["goodSet"] == row["original16M"]["goodSet"]
            )
            rows.append(row)
            report["processed_positions"] = i
            (out / "report.json").write_text(
                json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
            )
            print("reference_convergence_position", i, pid,
                  "4M16M=", row["frozen4M16M"]["status"],
                  "16M64M=", row["fresh16M64M"]["status"],
                  "rootLoss=", row["rank2LossTrajectory"], flush=True)
    finally:
        engine.close()
    counts = {k: sum(r["fresh16M64M"]["status"] == k for r in rows)
              for k in ("RESOLVED", "DISPUTED", "INSUFFICIENT")}
    reasons: dict[str, int] = {}
    for row in rows:
        if row["fresh16M64M"]["status"] != "RESOLVED":
            why = row["fresh16M64M"].get("reason") or "unspecified"
            reasons[why] = reasons.get(why, 0) + 1
    report.update({
        "status": "DIAGNOSTIC_COMPLETE", "processed_positions": 16,
        "frozen4M16MCounts": {"RESOLVED": 13, "DISPUTED": 3},
        "fresh16M64MCounts": counts,
        "fresh16M64MReasons": reasons,
        "fresh16M64MDisputedRate": counts["DISPUTED"] / 16,
        "fresh16M64MUnresolvedRate": (counts["DISPUTED"] + counts["INSUFFICIENT"]) / 16,
        "fresh16MMatchesFrozenStructureCount": sum(
            r["fresh16MMatchesFrozenStructure"] for r in rows
        ),
        "decision": "NO_FEASIBILITY_AMENDMENT_DECIDED",
    })
    (out / "report.json").write_text(
        json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    (out / "stage.json").write_text(json.dumps({
        "status": "DIAGNOSTIC_COMPLETE", "processed_positions": 16,
        "disputed": counts["DISPUTED"]
    }, indent=2) + "\n", encoding="utf-8")
    print("reference_convergence_final_counts=" + json.dumps(counts), flush=True)
    return report


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--pilot-result", required=True, type=Path)
    ap.add_argument("--pilot-evaluation", required=True, type=Path)
    ap.add_argument("--work", type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--baseline-only", action="store_true")
    args = ap.parse_args()
    result = json.loads(args.pilot_result.read_text(encoding="utf-8"))
    evaluation = json.loads(args.pilot_evaluation.read_text(encoding="utf-8"))
    validate_frozen_result(result, evaluation)
    if args.baseline_only:
        return 0
    if args.work is None:
        ap.error("--work required when running searches")
    report = run(result, args.work.resolve(), args.out.resolve())
    _require(report["processed_positions"] == 16, "fewer_than_16")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
