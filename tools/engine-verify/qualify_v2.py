#!/usr/bin/env python3
"""Build19-VE1-Q formal runner revision 2.

Revision 2 keeps bounded final MultiPV entries in Q3 reproducibility evidence and
requires ranks [1, 2, 3] on every repeat. This closes the evidence gap found by
after-run audit of the initial qualification attempt.
"""
from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

import qualify as base
import ve1q_harness as harness
from ve1q_harness import (
    deterministic_repro_view,
    execute_engine_search,
    finalize_run_provenance,
    strict_validate_raw_log,
)


# Q5 must hash the formal entrypoint too. The base harness source hash predates
# this corrective runner, so revision 2 extends it deterministically with this
# file and publishes a distinct harness version in every formal provenance row.
_BASE_TOOL_SOURCE_HASH = harness.tool_source_hash


def formal_tool_source_hash() -> str:
    h = hashlib.sha256()
    h.update(_BASE_TOOL_SOURCE_HASH().encode("ascii"))
    h.update(b"\0qualify_v2.py\0")
    h.update(Path(__file__).read_bytes())
    return h.hexdigest()


harness.tool_source_hash = formal_tool_source_hash
harness.HARNESS_VERSION = "Build19-VE1-Q/1.1"


def q3_repro(work: Path, out_dir: Path) -> tuple[base.Gate, list[dict[str, Any]]]:
    gate = base.Gate("Q3")
    provenances: list[dict[str, Any]] = []
    views: list[dict[str, Any]] = []
    rank_issues: list[dict[str, Any]] = []
    fixture = {
        "id": "q3-startpos-fixed-nodes",
        "position": "position startpos",
        "repeats": 3,
        "nodes": 50000,
    }
    expected_ranks = [1, 2, 3]

    for i in range(3):
        _result, meta = execute_engine_search(
            work,
            out_dir,
            f"q3-repro-{i + 1}",
            "app-candidate",
            fixture,
            "position startpos",
            nodes=50000,
            multipv=3,
        )
        provenances.append(finalize_run_provenance(work, meta))

        # Q3 formally compares bound and MultiPV ordering. Bounded final entries
        # therefore remain evidence; they must not be silently discarded.
        parsed = strict_validate_raw_log(
            meta["_run"].raw_log_path,
            allow_bounds=True,
            require_complete_fields=True,
        )
        view = deterministic_repro_view(parsed)
        ranks = [pv["multipv"] for pv in view["principalVariations"]]
        if ranks != expected_ranks:
            rank_issues.append(
                {"run": i + 1, "expected": expected_ranks, "actual": ranks}
            )
        views.append(view)

    differences: list[dict[str, Any]] = []
    baseline = views[0]
    for run_number, view in enumerate(views[1:], start=2):
        if view != baseline:
            differences.append(
                {"run": run_number, "baseline": baseline, "actual": view}
            )

    gate.add(
        "threads1-fixed-nodes-three-runs",
        not differences and not rank_issues,
        {
            "runs": views,
            "differences": differences,
            "rank_issues": rank_issues,
            "required_ranks": expected_ranks,
            "bounded_entries_included": True,
        },
    )
    return gate, provenances


# Patch only the formal Q3 gate; all Q1/Q2/Q4/Q5/Q6 behavior remains the
# already-qualified base implementation.
base.q3_repro = q3_repro

if __name__ == "__main__":
    raise SystemExit(base.main())
