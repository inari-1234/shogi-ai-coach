#!/usr/bin/env python3
"""Mechanical preregistered VE1-C1 natural-pilot execution-integrity gate.

All results, including INSUFFICIENT blocks and conservative F0/E0, are evidence.
This tool does not tune semantics or replace raw observations with favorable data.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

import ve1c1_block_selector as blocks
import ve1c1_pilot as pilot
import ve1c1_pilot_runner as runner
import ve1c1_pilot_legal_roots as legal_roots


class IntegrityError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise IntegrityError(reason)


def same(a: Any, b: Any) -> bool:
    return blocks.snapshot_full_signature(a) == blocks.snapshot_full_signature(b)


def check_search(search: dict[str, Any], name: str, expected_nodes: int,
                 expected_multipv: int, output: Path) -> str:
    require(isinstance(search, dict), "missing_search:" + name)
    require(search.get("nodeBudget") == expected_nodes, "node_budget:" + name)
    require(search.get("multiPV") == expected_multipv, "effective_multipv:" + name)
    go = search.get("goCommand", "")
    require(isinstance(go, str) and go.startswith(f"go nodes {expected_nodes}"), "go_command:" + name)
    observations = search.get("observations")
    require(isinstance(observations, list) and observations, "missing_observations:" + name)
    require(all(isinstance(x.get("rawUSI"), str) and x["rawUSI"] for x in observations),
            "missing_raw_usi:" + name)
    raw = search.get("rawLogPath")
    require(isinstance(raw, str) and raw, "missing_raw_log_path:" + name)
    raw_path = Path(raw).resolve()
    require(raw_path.is_relative_to(output.resolve()), "raw_log_outside_evidence_root:" + name)
    require(raw_path.is_file() and raw_path.stat().st_size > 0, "raw_log_missing:" + name)
    require(search.get("snapshotSelector") == "coherent_output_block_v1", "coherent_selector_missing:" + name)
    require(search.get("candidateBlockStatus") in ("RESOLVED", "INSUFFICIENT"), "block_status_missing:" + name)
    frozen = blocks.frozen_selector_snapshot(observations, expected_multipv)
    coherent = blocks.deepest_exact_output_block(observations, expected_multipv)
    frozen_recorded = search.get("ve1bFrozenSnapshot") or []
    selected = search.get("selectedSnapshot") or []
    require(same(frozen or [], frozen_recorded), "frozen_snapshot_mismatch:" + name)
    require(same(coherent or [], selected), "coherent_snapshot_mismatch:" + name)
    expected_status = runner.snapshot_evidence_status(selected, expected_multipv)
    require(search.get("selectedSnapshotEvidenceStatus") == expected_status,
            "coherent_block_evidence_status:" + name)
    require(search.get("candidateBlockStatus") ==
            ("RESOLVED" if expected_status == "RESOLVED" else "INSUFFICIENT"),
            "coherent_block_status:" + name)
    return expected_status


def gate(raw: dict[str, Any], evaluation: dict[str, Any], swift: dict[str, Any],
         manifest: dict[str, Any], legal_audit: dict[str, Any],
         admission: dict[str, Any], output: Path) -> dict[str, Any]:
    require(admission.get("computed_natural_pilot_execution_permitted") is True, "precommit_admission_not_pass")
    require(admission.get("frozen_exclusion_snapshot_flag") is False, "frozen_snapshot_flag_changed")
    require(raw.get("schema_version") == pilot.PILOT_RESULT_SCHEMA, "result_schema")
    require(raw.get("run_kind") == "excluded_natural_pilot", "result_not_natural_pilot")
    require(raw.get("authority_commit") == pilot.AUTHORITY_COMMIT, "result_authority")
    require(raw.get("result_sha256") == pilot.sha256_text(
        pilot.canonical_json({k:v for k,v in raw.items() if k != "result_sha256"})
    ), "result_digest")
    rows = legal_roots.validated_rows(manifest, legal_audit)
    positions = raw.get("positions")
    require(isinstance(positions, list) and len(positions) == 16, "natural_position_count")
    require(len(evaluation.get("positions", [])) == 16, "evaluation_position_count")
    require(evaluation.get("source_result_sha256") == raw.get("result_sha256"), "evaluation_source_digest")
    require(evaluation.get("F", {}).get("policy") in ("F0", "F2"), "F_not_preregistered")
    require(evaluation.get("E", {}).get("policy") in ("E0", "E1"), "E_not_preregistered")
    require(swift.get("schema_version") == "ve1c1-swift-raw-usi-parity-v1", "swift_parity_schema")
    require(swift.get("status") == "PASS" and swift.get("mismatch_count") == 0, "swift_parser_parity")
    require(swift.get("position_count") == 16 and swift.get("observation_count", 0) > 0, "swift_parity_counts")

    block_outcomes: dict[str, int] = {}
    total_searches = 0
    for index, (position, selected, root) in enumerate(zip(
        positions, manifest["selected_positions"], rows
    )):
        pid = f"position-{index+1}"
        for key in ("game_sha256", "ply", "position_command", "actual_move"):
            expected_key = key
            require(position.get(key) == selected.get(expected_key), f"position_identity:{pid}:{key}")
        required = root["effectiveRequiredMultiPV"]
        require(position.get("legalRootMoveCount") == root["legalRootMoveCount"],
                "legal_root_provenance:" + pid)
        require(position.get("effectiveRootMultiPV") == required, "effective_root_provenance:" + pid)
        app = position.get("app") or {}
        discoveries = app.get("discoveries", [])
        comparisons = app.get("comparisons", [])
        require(len(discoveries) == 3 and len(comparisons) == 3, "app_search_cardinality:" + pid)
        for n, search in zip(runner.APP_NODE_TIERS, discoveries):
            status = check_search(search, f"{pid}:app:discovery:{n}", n, required, output)
            block_outcomes[status] = block_outcomes.get(status, 0) + 1
            total_searches += 1
        for n, comparison in zip(runner.APP_NODE_TIERS, comparisons):
            require(comparison.get("nodeBudget") == n, "app_comparison_budget:" + pid)
            for key in ("bestSearch", "actualSearch"):
                status = check_search(
                    comparison.get(key), f"{pid}:app:{key}:{n}", n, 1, output
                )
                block_outcomes[status] = block_outcomes.get(status, 0) + 1
                total_searches += 1
        reference = position.get("reference") or {}
        budgets = reference.get("budgets", [])
        require(len(budgets) == 2, "reference_budget_cardinality:" + pid)
        for n, budget in zip(runner.REFERENCE_NODE_BUDGETS, budgets):
            require(budget.get("nodeBudget") == n, "reference_budget:" + pid)
            status = check_search(budget.get("root"), f"{pid}:reference:root:{n}", n, required, output)
            block_outcomes[status] = block_outcomes.get(status, 0) + 1
            total_searches += 1
            for key in ("bestSearch", "actualSearch"):
                if budget.get(key) is not None:
                    status = check_search(budget[key], f"{pid}:reference:{key}:{n}", n, 1, output)
                    block_outcomes[status] = block_outcomes.get(status, 0) + 1
                    total_searches += 1
                else:
                    # Distinguish explicitly documented nonexecuted search from silently lost evidence.
                    require(budget.get("status") == "INSUFFICIENT",
                            "missing_reference_search_without_insufficient_record:" + pid)
    require(swift.get("search_count") == total_searches, "swift_search_count")
    summary = evaluation.get("summary")
    require(isinstance(summary, dict), "missing_feasibility_summary")
    for key in ("inversionByTier", "referenceCrossBudgetStructureStatus",
                "referenceTerminalByBudget", "smallInversionCount",
                "largeInversionCount", "e1OnlyCaseCount", "crossAxisConflictCaseCount"):
        require(key in summary, "missing_feasibility_indicator:" + key)

    return {
        "status": "PILOT_PASS",
        "reason": "preregistered_execution_integrity_only_not_semantic_quality",
        "natural_positions": len(positions),
        "searches_with_raw_evidence": total_searches,
        "swift_mismatch_count": swift["mismatch_count"],
        "block_outcomes": block_outcomes,
        "F": evaluation["F"]["policy"],
        "E": evaluation["E"]["policy"],
        "pool_manifest_sha256": admission.get("pool_sha256"),
        "pilot_manifest_sha256": manifest["manifest_sha256"],
        "result_sha256": raw["result_sha256"],
        "evaluation_sha256": evaluation.get("evaluation_sha256"),
        "unresolved_feasibility": summary["referenceCrossBudgetStructureStatus"],
    }


def main() -> int:
    ap = argparse.ArgumentParser()
    for flag in ("result", "evaluation", "swift-parity", "manifest", "root-audit", "admission", "output"):
        ap.add_argument("--" + flag, required=True, type=Path)
    a = ap.parse_args()
    def data(x: Path) -> dict:
        return json.loads(x.read_text(encoding="utf-8"))
    result = gate(data(a.result), data(a.evaluation), data(a.swift_parity),
                  data(a.manifest), data(a.root_audit), data(a.admission), a.result.parent)
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
