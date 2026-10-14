#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest(obj: Any) -> str:
    return hashlib.sha256(canonical_json(obj).encode("utf-8")).hexdigest()


def main() -> int:
    p = argparse.ArgumentParser(description="Compare production Swift 50k shallow output with physical B6 digest")
    p.add_argument("--fixture", required=True)
    p.add_argument("--actual", required=True)
    p.add_argument("--output", required=True)
    args = p.parse_args()

    fixture = json.loads(Path(args.fixture).read_text(encoding="utf-8"))
    actual = json.loads(Path(args.actual).read_text(encoding="utf-8"))
    if fixture.get("schema_version") != "ve1c1-b6-shallow-physical-digest-v1":
        raise SystemExit("fixture_schema_mismatch")
    if actual.get("schema_version") != "ve1c1-b6-swift-shallow-output-v1":
        raise SystemExit("actual_schema_mismatch")
    if actual.get("architecture") != "x86_64":
        raise SystemExit(f"wrong_runner_architecture:{actual.get('architecture')}")
    records = actual.get("records")
    expected = fixture.get("per_ply_semantic_sha256")
    if not isinstance(records, list) or len(records) != 81:
        raise SystemExit("actual_record_count_mismatch")
    if not isinstance(expected, list) or len(expected) != 81:
        raise SystemExit("expected_record_count_mismatch")

    mismatches: list[dict[str, Any]] = []
    for index, (record, expected_hash) in enumerate(zip(records, expected), start=1):
        actual_hash = digest(record)
        if actual_hash != expected_hash:
            mismatches.append({
                "ply": index,
                "expected_semantic_sha256": expected_hash,
                "actual_semantic_sha256": actual_hash,
                "actual": record,
            })
    all_hash = digest(records)
    if all_hash != fixture.get("all_positions_semantic_sha256") and not mismatches:
        mismatches.append({
            "type": "aggregate_digest_mismatch_without_per_ply_mismatch",
            "expected": fixture.get("all_positions_semantic_sha256"),
            "actual": all_hash,
        })

    result = {
        "schema_version": "ve1c1-b6-swift-shallow-parity-result-v1",
        "status": "PASS" if not mismatches else "FAIL",
        "architecture": actual.get("architecture"),
        "physical_report_sha256": fixture["source"]["sha256"],
        "fixture_sha256": fixture["source"]["fixture_sha256"],
        "node_budget": actual.get("node_budget"),
        "matched_positions": 81 - sum(1 for m in mismatches if "ply" in m),
        "mismatch_count": len(mismatches),
        "expected_all_positions_semantic_sha256": fixture.get("all_positions_semantic_sha256"),
        "actual_all_positions_semantic_sha256": all_hash,
        "mismatches": mismatches,
    }
    Path(args.output).write_text(json.dumps(result, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: result[k] for k in ("status", "architecture", "matched_positions", "mismatch_count")}, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
