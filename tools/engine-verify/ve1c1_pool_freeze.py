#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as pilot

POOL_SCHEMA = "ve1c1-pilot-pool-v1"
EXCLUSION_SCHEMA = "ve1c1-ve1d-exclusion-authority-v1"
B6_SHA256 = "ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102"


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def digest_without(obj: dict[str, Any], key: str) -> str:
    body = dict(obj)
    body.pop(key, None)
    return hashlib.sha256(canonical_json(body).encode("utf-8")).hexdigest()


def write(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    p = argparse.ArgumentParser(description="Freeze VE1-C1 production pool and pre-register VE1-D exclusions")
    p.add_argument("--pool", required=True)
    p.add_argument("--pilot-manifest", required=True)
    p.add_argument("--pool-output", required=True)
    p.add_argument("--exclusion-output", required=True)
    args = p.parse_args()

    pool_path = Path(args.pool)
    manifest_path = Path(args.pilot_manifest)
    pool = json.loads(pool_path.read_text(encoding="utf-8"))
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if pool.get("schema_version") != POOL_SCHEMA:
        raise SystemExit("pool_schema_mismatch")
    pilot.validate_pool(pool)
    if manifest.get("schema_version") != pilot.MANIFEST_SCHEMA:
        raise SystemExit("pilot_manifest_schema_mismatch")
    if manifest.get("sampling_key") != pilot.SAMPLING_KEY:
        raise SystemExit("sampling_key_mismatch")
    if len(manifest.get("selected_positions", [])) != pilot.PILOT_TARGET:
        raise SystemExit("pilot_position_count_mismatch")

    pool["pool_sha256"] = digest_without(pool, "pool_sha256")
    pilot_games = sorted(set(manifest.get("excluded_from_ve1d_game_sha256", [])))
    selected_games = sorted({p["game_sha256"] for p in manifest["selected_positions"]})
    if selected_games != pilot_games:
        raise SystemExit("selected_games_vs_exclusion_list_mismatch")
    if len(pilot_games) < pilot.MIN_SOURCE_GAMES:
        raise SystemExit("pilot_contributing_game_count_mismatch")
    if B6_SHA256 in selected_games:
        raise SystemExit("b6_fixture_selected_into_pilot")

    exclusion: dict[str, Any] = {
        "schema_version": EXCLUSION_SCHEMA,
        "sampling_key": pilot.SAMPLING_KEY,
        "authority_commit": pilot.AUTHORITY_COMMIT,
        "corpus_manifest_sha256": pool.get("corpus_manifest_sha256"),
        "seeded_plan_sha256": pool.get("seeded_plan_sha256"),
        "pool_sha256": pool["pool_sha256"],
        "pilot_manifest_sha256": manifest.get("manifest_sha256"),
        "pilot_game_sha256": pilot_games,
        "permanent_excluded_game_sha256": [B6_SHA256],
        "ve1d_exclusion_scope": ["tuning", "holdout", "reserve"],
        "natural_pilot_execution_permitted": False,
        "rule": "This authority must be committed before natural pilot execution. A later execution gate may set permission only by verifying exact hash coverage; this file itself is never generated after pilot evidence is observed."
    }
    exclusion["exclusion_authority_sha256"] = digest_without(exclusion, "exclusion_authority_sha256")

    write(Path(args.pool_output), pool)
    write(Path(args.exclusion_output), exclusion)
    print(json.dumps({
        "status": "PASS",
        "pool_sha256": pool["pool_sha256"],
        "pilot_manifest_sha256": manifest.get("manifest_sha256"),
        "contributing_games": len(pilot_games),
        "exclusion_authority_sha256": exclusion["exclusion_authority_sha256"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
