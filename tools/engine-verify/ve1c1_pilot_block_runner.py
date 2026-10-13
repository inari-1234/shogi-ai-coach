#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
from typing import Any

import ve1c1_block_selector as blocks
import ve1c1_pilot as contract
import ve1c1_pilot_runner as base

_ORIGINAL_SEARCH = base.PilotUSIEngine.search


def _coherent_search(self, position: str, nodes: int, multipv: int, searchmoves: list[str], role: str, log: Path) -> dict[str, Any]:
    result = _ORIGINAL_SEARCH(self, position, nodes, multipv, searchmoves, role, log)
    frozen = list(result.get("selectedSnapshot") or [])
    coherent = blocks.deepest_exact_output_block(result.get("observations") or [], multipv)
    coherent_export = [] if coherent is None else list(coherent)
    result["ve1bFrozenSnapshot"] = frozen
    result["selectedSnapshot"] = coherent_export
    result["snapshotSelector"] = "coherent_output_block_v1"
    result["selectedSnapshotEvidenceStatus"] = base.snapshot_evidence_status(coherent_export, multipv)
    result["candidateBlockStatus"] = "RESOLVED" if result["selectedSnapshotEvidenceStatus"] == "RESOLVED" else "INSUFFICIENT"
    result["frozenSelectorMismatch"] = (
        blocks.snapshot_full_signature(frozen) != blocks.snapshot_full_signature(coherent_export)
    )
    result["frozenSelectorSemanticPayloadChanged"] = (
        blocks.snapshot_payload_signature(frozen) != blocks.snapshot_payload_signature(coherent_export)
    )
    return result


def _frozen_primary(search: dict[str, Any]) -> dict[str, Any] | None:
    snapshot = search.get("ve1bFrozenSnapshot") or []
    return snapshot[0] if snapshot else None


def _run_app(engine: base.PilotUSIEngine, pos: dict[str, Any], out: Path) -> dict[str, Any]:
    pid, command, actual = pos["position_id"], pos["position_command"], pos["actual_move"]
    discoveries = [
        engine.search(command, n, 3, [], f"app_discovery_{n}", out / "raw" / pid / f"app-discovery-{n}.log")
        for n in base.APP_NODE_TIERS
    ]
    product_primary = _frozen_primary(discoveries[-1])
    if not product_primary or not product_primary.get("pv"):
        raise contract.PilotError(f"app_no_frozen_rank1_discovery:{pid}")
    recommended = product_primary["pv"][0]
    structure_status = "RESOLVED" if base.selected_primary(discoveries[-1]) is not None else "INSUFFICIENT"

    comparisons = []
    for n in base.APP_NODE_TIERS:
        best = engine.search(command, n, 1, [recommended], f"app_best_{n}", out / "raw" / pid / f"app-best-{n}.log")
        played = engine.search(command, n, 1, [actual], f"app_actual_{n}", out / "raw" / pid / f"app-actual-{n}.log")
        comparisons.append({
            "nodeBudget": n,
            "recommendedMove": recommended,
            "actualMove": actual,
            "comparisonInversion": base.comparison_inversion(recommended, actual, best, played),
            "expectedLoss": base.expected_loss(best, played),
            "bestSearch": best,
            "actualSearch": played,
        })
    return {
        "recommendedMove": recommended,
        "actualMove": actual,
        "candidateStructureEvidenceStatus": discoveries[-1]["selectedSnapshotEvidenceStatus"],
        "candidateStructureStatus": structure_status,
        "discoveries": discoveries,
        "comparisons": comparisons,
    }


base.PilotUSIEngine.search = _coherent_search
base.run_app = _run_app


if __name__ == "__main__":
    raise SystemExit(base.main())
