#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as contract
from ve1c1_pilot_runner import APP_HASH_MB, PilotUSIEngine, selected_primary

SCHEMA = "ve1c1-b6-x86-shallow-parity-v1"
NODE_BUDGET = 50_000
EXPECTED_AUTHORITY_COMMIT = "8daf78caa2bd5919cc911da21bae80fa3d12a248"
EXPECTED_PHYSICAL_REPORT_SHA256 = "fe63385d97293ae8cb7a577618ae66d7592d57b2960dcc899bcf93b51ff4a2a9"
EXPECTED_B6_SHA256 = "ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102"


class ParityError(RuntimeError):
    pass


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def load_fixture(path: Path) -> dict[str, Any]:
    fixture = json.loads(path.read_text(encoding="utf-8"))
    if fixture.get("schema_version") != "ve1c1-b6-shallow-physical-digest-v1":
        raise ParityError("fixture_schema_mismatch")
    source = fixture.get("source") or {}
    if source.get("authority_commit") != EXPECTED_AUTHORITY_COMMIT:
        raise ParityError("physical_authority_commit_mismatch")
    if source.get("sha256") != EXPECTED_PHYSICAL_REPORT_SHA256:
        raise ParityError("physical_report_sha256_mismatch")
    if source.get("fixture_sha256") != EXPECTED_B6_SHA256:
        raise ParityError("b6_fixture_sha256_mismatch")
    if source.get("shallow_node_budget") != NODE_BUDGET:
        raise ParityError("shallow_node_budget_mismatch")
    moves = fixture.get("actual_moves")
    hashes = fixture.get("per_ply_semantic_sha256")
    if not isinstance(moves, list) or len(moves) != 81:
        raise ParityError("physical_move_count_mismatch")
    if not isinstance(hashes, list) or len(hashes) != 81:
        raise ParityError("physical_semantic_hash_count_mismatch")
    return fixture


def position_command(moves: list[str], ply: int) -> str:
    before = moves[: ply - 1]
    return "position startpos" if not before else "position startpos moves " + " ".join(before)


def normalized_score(line: dict[str, Any]) -> tuple[str, int]:
    kind = line.get("scoreKind")
    value = line.get("scoreValue")
    if not isinstance(value, int):
        raise ParityError("selected_score_value_missing")
    if kind == "cp":
        return "cp", value
    if kind == "mate":
        return ("mate_win" if value >= 0 else "mate_loss"), value
    raise ParityError(f"selected_score_kind_unsupported:{kind}")


def classify_completion(search: dict[str, Any], score_kind: str) -> str:
    max_nodes = int(search.get("maxObservedNodes") or 0)
    if max_nodes >= NODE_BUDGET:
        return "node_budget_reached"
    if score_kind in ("mate_win", "mate_loss"):
        return "proven_mate_termination"
    return "incomplete_before_node_budget"


def semantic_record(ply: int, moves: list[str], search: dict[str, Any]) -> dict[str, Any]:
    line = selected_primary(search)
    if line is None or not line.get("pv"):
        raise ParityError(f"missing_completed_exact_snapshot:ply={ply}")
    if search.get("selectedSnapshotEvidenceStatus") != "RESOLVED":
        raise ParityError(f"shallow_snapshot_not_resolved:ply={ply}:{search.get('selectedSnapshotEvidenceStatus')}")
    score_kind, score_value = normalized_score(line)
    cp = score_value if score_kind == "cp" else None
    black_cp = None if cp is None else (cp if ply % 2 == 1 else -cp)
    return {
        "actualMove": moves[ply - 1],
        "bestMove": search.get("bestmove"),
        "blackPerspectiveCp": black_cp,
        "completion": classify_completion(search, score_kind),
        "nodeBudget": NODE_BUDGET,
        "ply": ply,
        "positionCommand": position_command(moves, ply),
        "scoreKind": score_kind,
        "scoreValue": score_value,
    }


def run(work: Path, fixture_path: Path, output: Path, raw_dir: Path) -> dict[str, Any]:
    fixture = load_fixture(fixture_path)
    moves: list[str] = fixture["actual_moves"]
    expected_hashes: list[str] = fixture["per_ply_semantic_sha256"]
    engine = PilotUSIEngine(work=work, hash_mb=APP_HASH_MB)
    actual_records: list[dict[str, Any]] = []
    mismatches: list[dict[str, Any]] = []
    try:
        for ply in range(1, len(moves) + 1):
            command = position_command(moves, ply)
            search = engine.search(
                position=command,
                nodes=NODE_BUDGET,
                multipv=1,
                searchmoves=[],
                role="ve1c1_b6_x86_shallow_parity",
                log=raw_dir / f"ply-{ply:03d}.log",
            )
            record = semantic_record(ply, moves, search)
            actual_records.append(record)
            actual_hash = sha256_text(canonical_json(record))
            expected_hash = expected_hashes[ply - 1]
            if actual_hash != expected_hash:
                mismatches.append({
                    "ply": ply,
                    "expected_semantic_sha256": expected_hash,
                    "actual_semantic_sha256": actual_hash,
                    "actual": record,
                    "selectedSnapshot": search.get("selectedSnapshot"),
                    "maxObservedNodes": search.get("maxObservedNodes"),
                })
    finally:
        engine.close()

    actual_all_hash = sha256_text(canonical_json(actual_records))
    expected_all_hash = fixture["all_positions_semantic_sha256"]
    if actual_all_hash != expected_all_hash and not mismatches:
        mismatches.append({
            "type": "aggregate_digest_mismatch_without_per_ply_mismatch",
            "expected": expected_all_hash,
            "actual": actual_all_hash,
        })

    result: dict[str, Any] = {
        "schema_version": SCHEMA,
        "status": "PASS" if not mismatches else "FAIL",
        "authority_commit": EXPECTED_AUTHORITY_COMMIT,
        "physical_report_sha256": EXPECTED_PHYSICAL_REPORT_SHA256,
        "fixture_sha256": EXPECTED_B6_SHA256,
        "node_budget": NODE_BUDGET,
        "required_positions": 81,
        "matched_positions": 81 - len([m for m in mismatches if isinstance(m.get("ply"), int)]),
        "mismatch_count": len(mismatches),
        "expected_all_positions_semantic_sha256": expected_all_hash,
        "actual_all_positions_semantic_sha256": actual_all_hash,
        "mismatches": mismatches,
        "actual_records": actual_records,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return result


def main() -> int:
    p = argparse.ArgumentParser(description="VE1-C1 x86 50k shallow parity against physical B6 Authority")
    p.add_argument("--work", required=True)
    p.add_argument("--fixture", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--raw-dir", required=True)
    args = p.parse_args()
    try:
        result = run(Path(args.work), Path(args.fixture), Path(args.output), Path(args.raw_dir))
        print(json.dumps({k: result[k] for k in ("status", "matched_positions", "mismatch_count", "actual_all_positions_semantic_sha256")}, sort_keys=True))
        return 0 if result["status"] == "PASS" else 1
    except (ParityError, contract.PilotError) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
