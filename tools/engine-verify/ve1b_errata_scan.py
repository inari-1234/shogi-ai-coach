#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path
from typing import Any

import ve1c1_block_selector as blocks

SCHEMA = "ve1b-multipv-block-errata-scan-v1"


def scan_attempts_document(path: Path) -> dict[str, Any]:
    document = json.loads(path.read_text(encoding="utf-8"))
    counts: Counter[str] = Counter()
    mismatch_roles: Counter[str] = Counter()
    mismatches: list[dict[str, Any]] = []
    for position in document.get("positions", []):
        for attempt in position.get("attempts", []):
            counts["attempts"] += 1
            observations = attempt.get("observations", [])
            counts["observations"] += len(observations)
            required = int(attempt.get("multiPV", 1))
            frozen = blocks.frozen_selector_snapshot(observations, required)
            coherent = blocks.deepest_exact_output_block(observations, required)
            if frozen is None: counts["frozen_none"] += 1
            if coherent is None: counts["coherent_none"] += 1
            if blocks.snapshot_full_signature(frozen) == blocks.snapshot_full_signature(coherent):
                continue
            counts["full_snapshot_mismatch"] += 1
            mismatch_roles[f"{attempt.get('role')}|multipv={required}"] += 1
            if blocks.snapshot_payload_signature(frozen) != blocks.snapshot_payload_signature(coherent): counts["semantic_payload_changed"] += 1
            if blocks.snapshot_root_moves(frozen) != blocks.snapshot_root_moves(coherent): counts["ordered_moves_changed"] += 1
            if frozen is not None and coherent is not None and set(blocks.snapshot_root_moves(frozen) or []) != set(blocks.snapshot_root_moves(coherent) or []): counts["move_set_changed"] += 1
            if blocks.snapshot_scores(frozen) != blocks.snapshot_scores(coherent): counts["scores_changed"] += 1
            if frozen is not None and coherent is not None and (blocks.snapshot_root_moves(frozen) or [None])[0] != (blocks.snapshot_root_moves(coherent) or [None])[0]: counts["rank1_changed"] += 1
            mismatches.append({"ply": position.get("ply"), "attempt_id": attempt.get("attemptID"), "role": attempt.get("role"), "multiPV": required, "frozen": blocks.snapshot_brief(frozen), "coherent": blocks.snapshot_brief(coherent)})
    return {"kind": "attempts_document", "path": path.name, "counts": dict(counts), "mismatch_roles": dict(mismatch_roles), "mismatches": mismatches}


def _parse_info_line(line: str) -> dict[str, Any] | None:
    if line.startswith("< "): line = line[2:]
    if not line.startswith("info ") or line.startswith("info string "): return None
    tokens = line.split(); info: dict[str, Any] = {"multipv": 1, "pv": [], "raw_line": line}; i = 1
    while i < len(tokens):
        token = tokens[i]
        if token in {"depth", "seldepth", "multipv", "nodes", "nps", "time"} and i + 1 < len(tokens):
            try: info[token] = int(tokens[i + 1])
            except ValueError: pass
            i += 2; continue
        if token == "score" and i + 2 < len(tokens):
            kind = tokens[i + 1]; raw_value = tokens[i + 2]
            try: value: Any = int(raw_value)
            except ValueError: value = raw_value
            bound = None; i += 3
            if i < len(tokens) and tokens[i] in {"lowerbound", "upperbound"}:
                bound = "lower" if tokens[i] == "lowerbound" else "upper"; i += 1
            info["score"] = {"type": kind, "value": value, "bound": bound}; continue
        if token == "pv": info["pv"] = tokens[i + 1:]; break
        i += 1
    return info


def scan_node_contract_ci(path: Path) -> dict[str, Any]:
    document = json.loads(path.read_text(encoding="utf-8")); counts: Counter[str] = Counter(); mismatches = []
    for run in document.get("candidate_discovery", {}).get("runs", []):
        counts["candidate_discovery_runs"] += 1
        observations = [x for x in (_parse_info_line(line) for line in run.get("transcript", [])) if x is not None]
        counts["observations"] += len(observations)
        frozen = blocks.frozen_selector_snapshot(observations, 3); coherent = blocks.deepest_exact_output_block(observations, 3)
        if blocks.snapshot_full_signature(frozen) == blocks.snapshot_full_signature(coherent): continue
        counts["full_snapshot_mismatch"] += 1
        if blocks.snapshot_payload_signature(frozen) != blocks.snapshot_payload_signature(coherent): counts["semantic_payload_changed"] += 1
        if blocks.snapshot_root_moves(frozen) != blocks.snapshot_root_moves(coherent): counts["ordered_moves_changed"] += 1
        if frozen is not None and coherent is not None and set(blocks.snapshot_root_moves(frozen) or []) != set(blocks.snapshot_root_moves(coherent) or []): counts["move_set_changed"] += 1
        if blocks.snapshot_scores(frozen) != blocks.snapshot_scores(coherent): counts["scores_changed"] += 1
        if frozen is not None and coherent is not None and (blocks.snapshot_root_moves(frozen) or [None])[0] != (blocks.snapshot_root_moves(coherent) or [None])[0]: counts["rank1_changed"] += 1
        mismatches.append({"label": run.get("label"), "frozen": blocks.snapshot_brief(frozen), "coherent": blocks.snapshot_brief(coherent)})
    return {"kind": "node_contract_ci", "path": path.name, "counts": dict(counts), "mismatches": mismatches}


def aggregate(scans: list[dict[str, Any]]) -> dict[str, Any]:
    b6 = Counter(); ci = Counter()
    for scan in scans: (ci if scan["kind"] == "node_contract_ci" else b6).update(scan.get("counts", {}))
    return {"b6_primary": dict(b6), "node_contract_ci": dict(ci), "impact": {"b6_primary_semantic_payload_changed": b6.get("semantic_payload_changed", 0), "b6_primary_rank1_changed": b6.get("rank1_changed", 0), "b6_primary_move_set_changed": b6.get("move_set_changed", 0), "node_contract_ci_semantic_payload_changed": ci.get("semantic_payload_changed", 0)}}


def main() -> int:
    parser = argparse.ArgumentParser(); parser.add_argument("--b6", nargs="*", default=[]); parser.add_argument("--ci"); parser.add_argument("--out", required=True); args = parser.parse_args()
    scans = [scan_attempts_document(Path(item)) for item in args.b6]
    if args.ci: scans.append(scan_node_contract_ci(Path(args.ci)))
    result = {"schema_version": SCHEMA, "scans": scans}; result["aggregate"] = aggregate(scans)
    Path(args.out).parent.mkdir(parents=True, exist_ok=True); Path(args.out).write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps(result["aggregate"], sort_keys=True)); return 0


if __name__ == "__main__":
    raise SystemExit(main())
