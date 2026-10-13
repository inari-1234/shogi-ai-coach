#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import statistics
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import ve1c1_pilot as contract

EVALUATION_SCHEMA = "ve1c1-pilot-evaluation-v1"


def _score(line: dict[str, Any] | None) -> tuple[str, int] | None:
    if not line:
        return None
    kind = line.get("scoreKind")
    value = line.get("scoreValue")
    if kind not in ("cp", "mate") or not isinstance(value, int):
        return None
    return kind, value


def _root_move(line: dict[str, Any] | None) -> str | None:
    if not line:
        return None
    pv = line.get("pv") or []
    return pv[0] if pv else None


def _selected(search: dict[str, Any] | None) -> list[dict[str, Any]]:
    if not search:
        return []
    return list(search.get("selectedSnapshot") or [])


def _primary(search: dict[str, Any] | None) -> dict[str, Any] | None:
    snapshot = _selected(search)
    return snapshot[0] if snapshot else None


def _finite_loss(best_cp: int, candidate_cp: int) -> float:
    return contract.expected_score(best_cp) - contract.expected_score(candidate_cp)


def _severity_class_from_scores(best: tuple[str, int] | None, candidate: tuple[str, int] | None) -> dict[str, Any]:
    if best is None or candidate is None:
        return {"class": "UNRESOLVED", "loss": None, "reason": "MISSING_SCORE"}
    bk, bv = best
    ck, cv = candidate
    if bk == "mate" and bv < 0:
        return {"class": "NOT_CLASSIFIABLE", "loss": None, "reason": "NO_SAVING_MOVE"}
    if ck == "mate" and cv < 0 and not (bk == "mate" and bv < 0):
        return {"class": "BLUNDER", "loss": 1.0, "reason": "ENTERED_FORCED_LOSS"}
    if bk == "mate" and bv > 0:
        if ck == "mate" and cv > 0:
            return {"class": "GOOD", "loss": 0.0, "reason": "PRESERVES_POSITIVE_MATE"}
        if ck == "cp":
            loss = 1.0 - contract.expected_score(cv)
            return {"class": contract.classify_reference_loss(loss), "loss": loss, "reason": "MISSED_FORCED_MATE_NONMATE"}
        return {"class": "UNRESOLVED", "loss": None, "reason": "MATE_KIND_UNRESOLVED"}
    if bk == "cp":
        if ck == "mate" and cv > 0:
            return {"class": "GOOD", "loss": 0.0, "reason": "COMPARISON_INVERSION_TO_MATE"}
        if ck == "cp":
            raw = _finite_loss(bv, cv)
            loss = max(0.0, raw)
            return {
                "class": contract.classify_reference_loss(loss),
                "loss": loss,
                "rawLoss": raw,
                "reason": "COMPARISON_INVERSION" if raw < 0 else None,
            }
    return {"class": "UNRESOLVED", "loss": None, "reason": "UNSUPPORTED_SCORE_TRANSITION"}


def reference_root_structure(root: dict[str, Any]) -> dict[str, Any]:
    status = root.get("selectedSnapshotEvidenceStatus")
    if status != "RESOLVED":
        return {"status": "INSUFFICIENT", "label": "UNKNOWN", "reason": status, "goodSet": []}
    lines = _selected(root)
    if not lines:
        return {"status": "INSUFFICIENT", "label": "UNKNOWN", "reason": "NO_SNAPSHOT", "goodSet": []}
    best = _score(lines[0])
    if best is None:
        return {"status": "INSUFFICIENT", "label": "UNKNOWN", "reason": "NO_BEST_SCORE", "goodSet": []}
    if best[0] == "mate" and best[1] < 0:
        return {"status": "RESOLVED", "label": "NO_SAVING_MOVE", "reason": "CONFIRMED_NEGATIVE_MATE", "goodSet": []}

    good: list[str] = []
    for line in lines:
        move = _root_move(line)
        score = _score(line)
        if move is None or score is None:
            return {"status": "INSUFFICIENT", "label": "UNKNOWN", "reason": "MISSING_CANDIDATE_SCORE", "goodSet": []}
        if best[0] == "mate" and best[1] > 0:
            if score[0] == "mate" and score[1] > 0:
                good.append(move)
            continue
        cls = _severity_class_from_scores(best, score)
        if cls["class"] == "GOOD":
            good.append(move)
    if not good:
        return {"status": "INSUFFICIENT", "label": "UNKNOWN", "reason": "EMPTY_GOOD_SET", "goodSet": []}
    return {
        "status": "RESOLVED",
        "label": "UNIQUE_GOOD" if len(good) == 1 else "MULTIPLE_GOOD",
        "reason": None,
        "goodSet": good,
        "rank1Move": _root_move(lines[0]),
    }


def reference_played_budget(budget: dict[str, Any]) -> dict[str, Any]:
    best_search = budget.get("bestSearch")
    actual_search = budget.get("actualSearch")
    if budget.get("playedStatus") != "RESOLVED" or not best_search or not actual_search:
        return {"status": "INSUFFICIENT", "class": "UNRESOLVED", "reason": "PLAYED_EVIDENCE_INSUFFICIENT"}
    best_line = _primary(best_search)
    actual_line = _primary(actual_search)
    severity = _severity_class_from_scores(_score(best_line), _score(actual_line))
    if severity["class"] in ("UNRESOLVED", "NOT_CLASSIFIABLE"):
        return {"status": "INSUFFICIENT", **severity}
    actual = budget.get("actualMove")
    rank1 = budget.get("rank1Move")
    if severity["class"] == "GOOD":
        label = "MATCH" if actual == rank1 and severity.get("reason") != "COMPARISON_INVERSION" else "WITHIN_GOOD_SET"
    else:
        label = severity["class"]
    return {"status": "RESOLVED", "class": severity["class"], "label": label, **{k: v for k, v in severity.items() if k != "class"}}


def reference_actual_membership(budget: dict[str, Any]) -> bool | None:
    root = budget.get("root") or {}
    structure = reference_root_structure(root)
    if structure["status"] != "RESOLVED":
        return None
    played = reference_played_budget(budget)
    if played["status"] != "RESOLVED":
        return None
    if structure["label"] == "NO_SAVING_MOVE":
        return None
    return played["class"] == "GOOD"


def cross_budget_structure(reference: dict[str, Any]) -> dict[str, Any]:
    budgets = reference.get("budgets") or []
    if len(budgets) != 2:
        return {"status": "INSUFFICIENT", "reason": "REFERENCE_BUDGET_COUNT"}
    structures = [reference_root_structure(b.get("root") or {}) for b in budgets]
    if any(x["status"] != "RESOLVED" for x in structures):
        return {"status": "INSUFFICIENT", "reason": "STRUCTURE_EVIDENCE_INSUFFICIENT", "budgets": structures}
    a, b = structures
    if a["label"] != b["label"]:
        return {"status": "DISPUTED", "reason": "STRUCTURE_LABEL_CHANGED", "budgets": structures}
    if a["label"] == "UNIQUE_GOOD" and a.get("rank1Move") != b.get("rank1Move"):
        return {"status": "DISPUTED", "reason": "UNIQUE_IDENTITY_CHANGED", "budgets": structures}
    if a["label"] == "MULTIPLE_GOOD" and not (set(a["goodSet"]) & set(b["goodSet"])):
        return {"status": "DISPUTED", "reason": "GOOD_SET_DISJOINT", "budgets": structures}
    return {"status": "RESOLVED", "label": a["label"], "goodSetIntersection": sorted(set(a["goodSet"]) & set(b["goodSet"])), "budgets": structures}


def _discovery_for_tier(app: dict[str, Any], nodes: int) -> dict[str, Any] | None:
    return next((x for x in app.get("discoveries", []) if x.get("nodeBudget") == nodes), None)


def _comparison_for_tier(app: dict[str, Any], nodes: int) -> dict[str, Any] | None:
    return next((x for x in app.get("comparisons", []) if x.get("nodeBudget") == nodes), None)


def _actual_line_from_root(discovery: dict[str, Any], actual_move: str) -> dict[str, Any] | None:
    return next((line for line in _selected(discovery) if _root_move(line) == actual_move), None)


def _app_structure_at_delta(discovery: dict[str, Any], delta: float) -> str:
    if discovery.get("selectedSnapshotEvidenceStatus") != "RESOLVED":
        return "UNKNOWN"
    lines = _selected(discovery)
    if not lines:
        return "UNKNOWN"
    best = _score(lines[0])
    if best is None:
        return "UNKNOWN"
    if best[0] == "mate" and best[1] < 0:
        return "NO_SAVING_MOVE"
    if best[0] == "mate" and best[1] > 0:
        preserving = sum(1 for line in lines if (_score(line) or (None, 0))[0] == "mate" and (_score(line) or (None, 0))[1] > 0)
        return "UNIQUE_GOOD" if preserving == 1 else "MULTIPLE_GOOD"
    if len(lines) < 2:
        return "UNKNOWN"
    rank2 = _severity_class_from_scores(best, _score(lines[1]))
    loss = rank2.get("loss")
    if loss is None:
        return "UNKNOWN"
    if loss <= contract.TAU_GOOD_REF - delta:
        return "MULTIPLE_GOOD"
    if loss <= contract.TAU_GOOD_REF + delta:
        return "UNKNOWN"
    return "UNIQUE_GOOD"


def _allowed_from_loss(loss: float | None, delta: float) -> set[str] | None:
    if loss is None:
        return None
    return contract.app_allowed_classes(max(0.0, loss), delta)


def evaluate_position(position: dict[str, Any]) -> dict[str, Any]:
    app = position.get("app") or {}
    reference = position.get("reference") or {}
    pid = position.get("position_id")
    actual = position.get("actual_move")
    ref_budgets = {b.get("nodeBudget"): b for b in reference.get("budgets", [])}
    ref4 = ref_budgets.get(4_000_000)
    ref16 = ref_budgets.get(16_000_000)
    result: dict[str, Any] = {
        "position_id": pid,
        "referenceStructure": cross_budget_structure(reference),
        "referencePlayed4M": reference_played_budget(ref4 or {}),
        "referencePlayed16M": reference_played_budget(ref16 or {}),
        "tiers": [],
        "f_cases": [],
        "e_cases": [],
        "cross_axis_cases": [],
    }
    recommended = app.get("recommendedMove")
    for nodes in (50_000, 100_000, 200_000):
        discovery = _discovery_for_tier(app, nodes)
        comparison = _comparison_for_tier(app, nodes)
        if not discovery or not comparison:
            result["tiers"].append({"nodeBudget": nodes, "status": "INSUFFICIENT"})
            continue
        best_line = _primary(comparison.get("bestSearch"))
        actual_line = _primary(comparison.get("actualSearch"))
        best_score = _score(best_line)
        actual_score = _score(actual_line)
        severity = _severity_class_from_scores(best_score, actual_score)
        inversion = comparison.get("comparisonInversion") is True
        inversion_magnitude = None
        if inversion and best_score and actual_score and best_score[0] == "cp" and actual_score[0] == "cp":
            inversion_magnitude = max(0.0, contract.expected_score(actual_score[1]) - contract.expected_score(best_score[1]))
            kind = "small_inversion" if inversion_magnitude <= contract.TAU_GOOD_REF else "large_inversion"
            fcase = {
                "kind": kind,
                "case_id": f"{pid}:{nodes}",
                "position_id": pid,
                "nodeBudget": nodes,
                "inversionMagnitude": inversion_magnitude,
                "reference4m_membership": reference_actual_membership(ref4 or {}),
                "reference16m_membership": reference_actual_membership(ref16 or {}),
            }
            result["f_cases"].append(fcase)
        root_actual = _actual_line_from_root(discovery, actual) if actual else None
        root_best = _primary(discovery)
        root_severity = _severity_class_from_scores(_score(root_best), _score(root_actual)) if root_actual else None
        tier_entry = {
            "nodeBudget": nodes,
            "status": "RESOLVED" if discovery.get("selectedSnapshotEvidenceStatus") == "RESOLVED" else discovery.get("selectedSnapshotEvidenceStatus"),
            "comparisonInversion": comparison.get("comparisonInversion"),
            "inversionMagnitude": inversion_magnitude,
            "comparisonClass": severity.get("class"),
            "comparisonLoss": severity.get("loss"),
            "rootActualClass": None if root_severity is None else root_severity.get("class"),
            "rootActualLoss": None if root_severity is None else root_severity.get("loss"),
        }
        result["tiers"].append(tier_entry)

        if discovery.get("selectedSnapshotEvidenceStatus") == "RESOLVED" and root_actual is not None:
            for delta in contract.DELTA_GRID:
                root_allowed = _allowed_from_loss(root_severity.get("loss") if root_severity else None, delta)
                cmp_allowed = _allowed_from_loss(severity.get("loss"), delta)
                if root_allowed is None or cmp_allowed is None:
                    continue
                e0_accepts = len(root_allowed) == 1 and root_allowed == cmp_allowed
                intersection = sorted(root_allowed & cmp_allowed)
                e1_accepts = bool(intersection)
                if e1_accepts and not e0_accepts:
                    ref4_played = reference_played_budget(ref4 or {})
                    ref16_played = reference_played_budget(ref16 or {})
                    ref4_class = ref4_played.get("class") if ref4_played.get("status") == "RESOLVED" else None
                    ref16_class = ref16_played.get("class") if ref16_played.get("status") == "RESOLVED" else None
                    ecase = {
                        "kind": "e1_only_compatibility",
                        "case_id": f"{pid}:{nodes}:d{delta:.3f}",
                        "position_id": pid,
                        "nodeBudget": nodes,
                        "delta": delta,
                        "intersection": intersection,
                        "reference4m_class": ref4_class,
                        "reference16m_class": ref16_class,
                        "reference4m_compatible": None if ref4_class is None else ref4_class in intersection,
                        "reference16m_compatible": None if ref16_class is None else ref16_class in intersection,
                    }
                    result["e_cases"].append(ecase)

        if recommended and actual and recommended != actual:
            for delta in contract.DELTA_GRID:
                structure = _app_structure_at_delta(discovery, delta)
                cmp_loss = severity.get("loss")
                actual_may_be_good = inversion or (cmp_loss is not None and cmp_loss <= contract.TAU_GOOD_REF + delta)
                if structure == "UNIQUE_GOOD" and actual_may_be_good:
                    result["cross_axis_cases"].append({
                        "case_id": f"{pid}:{nodes}:d{delta:.3f}",
                        "position_id": pid,
                        "nodeBudget": nodes,
                        "delta": delta,
                        "reason": "CROSS_AXIS_CONFLICT",
                    })
    return result


def _searches(position: dict[str, Any]) -> list[dict[str, Any]]:
    searches: list[dict[str, Any]] = []
    app = position.get("app") or {}
    searches.extend(app.get("discoveries", []))
    for c in app.get("comparisons", []):
        if c.get("bestSearch"): searches.append(c["bestSearch"])
        if c.get("actualSearch"): searches.append(c["actualSearch"])
    for budget in (position.get("reference") or {}).get("budgets", []):
        for key in ("root", "bestSearch", "actualSearch"):
            if budget.get(key): searches.append(budget[key])
    return searches


def summarize(raw: dict[str, Any], evaluated_positions: list[dict[str, Any]]) -> dict[str, Any]:
    inversion = defaultdict(lambda: {"observed": 0, "inversions": 0})
    app_structure_status = Counter()
    reference_structure_status = Counter()
    terminal_by_budget = defaultdict(lambda: {"searches": 0, "terminalBound": 0, "recoveredExactAfterTerminalBound": 0, "noExact": 0})
    divergences: list[int] = []

    for p in raw.get("positions", []):
        app = p.get("app") or {}
        actual = p.get("actual_move")
        for d in app.get("discoveries", []):
            if d.get("nodeBudget") == 200_000:
                app_structure_status[d.get("selectedSnapshotEvidenceStatus", "MISSING")] += 1
            if d.get("selectedSnapshotEvidenceStatus") == "RESOLVED" and actual:
                root_actual = _actual_line_from_root(d, actual)
                comp = _comparison_for_tier(app, d.get("nodeBudget"))
                if root_actual and comp:
                    independent_actual = _primary(comp.get("actualSearch"))
                    rs, ss = _score(root_actual), _score(independent_actual)
                    if rs and ss and rs[0] == ss[0] == "cp":
                        divergences.append(abs(rs[1] - ss[1]))
        for c in app.get("comparisons", []):
            n = c.get("nodeBudget")
            if isinstance(c.get("comparisonInversion"), bool):
                inversion[n]["observed"] += 1
                if c["comparisonInversion"]: inversion[n]["inversions"] += 1
        ref = p.get("reference") or {}
        cross = cross_budget_structure(ref)
        reference_structure_status[cross.get("status", "MISSING")] += 1
        for b in ref.get("budgets", []):
            n = b.get("nodeBudget")
            for key in ("root", "bestSearch", "actualSearch"):
                s = b.get(key)
                if not s: continue
                agg = terminal_by_budget[n]
                agg["searches"] += 1
                terminal = s.get("terminalIteration") or {}
                if terminal.get("hasBound") is True: agg["terminalBound"] += 1
                if s.get("completedExactRecoveredAfterTerminalBound") is True: agg["recoveredExactAfterTerminalBound"] += 1
                if s.get("hasCompletedExactIteration") is False: agg["noExact"] += 1

    for n, v in inversion.items():
        v["rate"] = None if v["observed"] == 0 else v["inversions"] / v["observed"]
    divergence_summary = {
        "n": len(divergences),
        "medianCp": None if not divergences else statistics.median(divergences),
        "maxCp": None if not divergences else max(divergences),
        "valuesCp": divergences,
    }
    return {
        "inversionByTier": dict(sorted(inversion.items())),
        "app200kStructureEvidenceStatus": dict(app_structure_status),
        "referenceCrossBudgetStructureStatus": dict(reference_structure_status),
        "referenceTerminalByBudget": dict(sorted(terminal_by_budget.items())),
        "multiPVVsIndependentActualDivergence": divergence_summary,
        "smallInversionCount": sum(1 for e in evaluated_positions for c in e["f_cases"] if c["kind"] == "small_inversion"),
        "largeInversionCount": sum(1 for e in evaluated_positions for c in e["f_cases"] if c["kind"] == "large_inversion"),
        "e1OnlyCaseCount": sum(len(e["e_cases"]) for e in evaluated_positions),
        "crossAxisConflictCaseCount": sum(len(e["cross_axis_cases"]) for e in evaluated_positions),
    }


def evaluate_document(raw: dict[str, Any]) -> dict[str, Any]:
    positions = [evaluate_position(p) for p in raw.get("positions", [])]
    f_cases = [c for p in positions for c in p["f_cases"]]
    e_cases = [c for p in positions for c in p["e_cases"]]
    natural = raw.get("run_kind") == "excluded_natural_pilot"
    result = {
        "schema_version": EVALUATION_SCHEMA,
        "source_result_sha256": raw.get("result_sha256"),
        "run_kind": raw.get("run_kind"),
        "authority_commit": raw.get("authority_commit"),
        "positions": positions,
        "summary": summarize(raw, positions),
        "F": contract.decide_f_policy(f_cases) if natural else {"policy": "NOT_DECIDED", "reason": "diagnostic_controls_are_not_adoption_data"},
        "E": contract.decide_e_policy(e_cases) if natural else {"policy": "NOT_DECIDED", "reason": "diagnostic_controls_are_not_adoption_data"},
    }
    result["evaluation_sha256"] = contract.sha256_text(contract.canonical_json(result))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Evaluate VE1-C1 pilot evidence under preregistered semantics")
    parser.add_argument("--result", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    raw = contract.load_json(Path(args.result))
    if raw.get("schema_version") != contract.PILOT_RESULT_SCHEMA:
        raise SystemExit("pilot_result_schema_mismatch")
    evaluation = evaluate_document(raw)
    contract.write_json(Path(args.output), evaluation)
    print(json.dumps({
        "status": "PASS",
        "run_kind": evaluation["run_kind"],
        "F": evaluation["F"],
        "E": evaluation["E"],
        "evaluation_sha256": evaluation["evaluation_sha256"],
    }, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
