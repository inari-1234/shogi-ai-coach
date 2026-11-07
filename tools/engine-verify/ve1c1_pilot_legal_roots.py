#!/usr/bin/env python3
"""Count natural pilot root moves using pinned native YaneuraOu MoveList<LEGAL>.

The native material-edition audit uses the same pinned move generator as the
production engine; evaluation is not involved in this semantic count.
This is a pre-search input, never inferred from MultiPV output.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import ve1c1_pilot as pilot

SCHEMA = "ve1c1-natural-pilot-legal-roots-v1"
PINNED_ENGINE = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"


class RootAuditError(ValueError):
    pass


def count_native(engine: Path, manifest: dict[str, Any]) -> dict[str, Any]:
    positions = manifest["selected_positions"]
    if manifest.get("schema_version") != pilot.MANIFEST_SCHEMA or len(positions) != 16:
        raise RootAuditError("pilot_manifest_contract_mismatch")
    if pilot.sha256_text(pilot.canonical_json({k:v for k,v in manifest.items() if k != "manifest_sha256"})) != manifest.get("manifest_sha256"):
        raise RootAuditError("pilot_manifest_digest_mismatch")
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as f:
        input_path = Path(f.name)
        for i, position in enumerate(positions, 1):
            f.write(f"{i}\t{position['position_command']}\n")
    try:
        result = subprocess.run(
            [str(engine), "--ve1b-legal-audit", str(input_path)],
            capture_output=True, text=True, check=False, timeout=240,
        )
    finally:
        input_path.unlink(missing_ok=True)
    if result.returncode != 0:
        raise RootAuditError(f"pinned_native_audit_failed:{result.returncode}:{result.stderr[-500:]}")
    found: dict[int, tuple[int, int, list[str]]] = {}
    for line in result.stdout.splitlines():
        if not line.startswith("VE1B\t"):
            continue
        parts = line.split("\t", 4)
        if len(parts) != 5:
            raise RootAuditError("malformed_native_audit_output")
        _, ordinal, legal, legal_all, moves = parts
        index = int(ordinal)
        if index in found:
            raise RootAuditError("duplicate_native_audit_ordinal")
        found[index] = (int(legal), int(legal_all), [x for x in moves.split() if x])
    if set(found) != set(range(1, len(positions) + 1)):
        raise RootAuditError("native_audit_incomplete")
    rows = []
    for index, position in enumerate(positions, 1):
        legal, all_count, legal_all_moves = found[index]
        if legal < 1 or all_count < legal or len(legal_all_moves) != all_count:
            raise RootAuditError(f"native_root_count_invalid:{index}")
        if position["actual_move"] not in legal_all_moves:
            raise RootAuditError(f"played_move_not_legal_all:{index}:{position['actual_move']}")
        rows.append({
            "ordinal": index,
            "positionCommand": position["position_command"],
            "actualMove": position["actual_move"],
            "legalRootMoveCount": legal,
            "legalAllMoveCount": all_count,
            "legalAllMoves": legal_all_moves,
            "effectiveRequiredMultiPV": min(3, legal),
        })
    result_doc = {
        "schema_version": SCHEMA,
        "authority_generator": "pinned_YaneuraOu_MoveList_LEGAL",
        "engine_commit": PINNED_ENGINE,
        "engine_sha256": hashlib.sha256(engine.read_bytes()).hexdigest(),
        "manifest_sha256": manifest["manifest_sha256"],
        "position_count": len(rows),
        "rows": rows,
        "raw_audit_stdout": result.stdout,
        "raw_audit_stderr": result.stderr,
    }
    return result_doc


def validated_rows(manifest: dict[str, Any], audit: dict[str, Any]) -> list[dict[str, Any]]:
    positions = manifest.get("selected_positions", [])
    if (
        audit.get("schema_version") != SCHEMA
        or audit.get("engine_commit") != PINNED_ENGINE
        or audit.get("authority_generator") != "pinned_YaneuraOu_MoveList_LEGAL"
        or audit.get("manifest_sha256") != manifest.get("manifest_sha256")
        or audit.get("position_count") != len(positions)
        or len(positions) != pilot.PILOT_TARGET
    ):
        raise RootAuditError("native_audit_manifest_or_engine_mismatch")
    rows = audit.get("rows", [])
    if not isinstance(rows, list) or len(rows) != len(positions):
        raise RootAuditError("native_audit_row_count")
    for i, (position, row) in enumerate(zip(positions, rows), 1):
        legal = row.get("legalRootMoveCount")
        if (
            row.get("ordinal") != i
            or row.get("positionCommand") != position.get("position_command")
            or row.get("actualMove") != position.get("actual_move")
            or not isinstance(legal, int)
            or legal < 1
            or row.get("effectiveRequiredMultiPV") != min(3, legal)
            or not isinstance(row.get("legalAllMoves"), list)
            or len(row.get("legalAllMoves")) != row.get("legalAllMoveCount")
            or row.get("legalAllMoveCount") < legal
            or position.get("actual_move") not in row["legalAllMoves"]
        ):
            raise RootAuditError(f"native_audit_row_mismatch:{i}")
    return rows


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--manifest", required=True, type=Path)
    p.add_argument("--engine", required=True, type=Path)
    p.add_argument("--output", required=True, type=Path)
    args = p.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    audit = count_native(args.engine, manifest)
    validated_rows(manifest, audit)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(audit, indent=2, ensure_ascii=False, sort_keys=True) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": "PASS",
        "positions": audit["position_count"],
        "minLegalRootMoveCount": min(row["legalRootMoveCount"] for row in audit["rows"]),
        "effectiveRequiredMultiPV": [row["effectiveRequiredMultiPV"] for row in audit["rows"]],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
