#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from typing import Any

import ve1c1_pilot as pilot

POOL_SCHEMA = "ve1c1-pilot-pool-v1"
EXCLUSION_SCHEMA = "ve1c1-ve1d-exclusion-authority-v2"
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


def _ordered_unique(values: list[str]) -> list[str]:
    return list(dict.fromkeys(values))


def classify_processed_games(pool: dict[str, Any]) -> tuple[list[str], list[str]]:
    """Return (candidate-producing games, zero-candidate games) in processed order.

    The production pool stores candidate-producing games in ``games`` and every
    processed game in ``selector_trace``.  This function is fail-closed: the two
    representations must agree exactly before exclusion authority can be made.
    """
    trace = pool.get("selector_trace")
    games = pool.get("games")
    if not isinstance(trace, list) or not isinstance(games, list):
        raise RuntimeError("missing_pool_trace_or_games")

    processed_game_count = pool.get("processed_game_count")
    if processed_game_count != len(trace):
        raise RuntimeError("processed_game_count_mismatch")

    producer_games = [game.get("game_sha256") for game in games]
    if any(not isinstance(value, str) for value in producer_games):
        raise RuntimeError("invalid_candidate_producer_game_sha256")
    if len(producer_games) != len(set(producer_games)):
        raise RuntimeError("duplicate_candidate_producer_game_sha256")

    trace_producers: list[str] = []
    zero_candidate_games: list[str] = []
    seen_trace_games: set[str] = set()
    previous_rank = 0
    for row in trace:
        if not isinstance(row, dict):
            raise RuntimeError("invalid_selector_trace_row")
        game_sha = row.get("game_sha256")
        rank = row.get("seed_rank")
        count = row.get("production_selected_count")
        capped = row.get("per_game_capped_contribution")
        outcome = row.get("selector_outcome")
        if not isinstance(game_sha, str) or not pilot.HEX64.fullmatch(game_sha):
            raise RuntimeError("invalid_trace_game_sha256")
        if game_sha in seen_trace_games:
            raise RuntimeError("duplicate_trace_game_sha256")
        seen_trace_games.add(game_sha)
        if not isinstance(rank, int) or rank <= previous_rank:
            raise RuntimeError("non_increasing_seed_rank_in_trace")
        previous_rank = rank
        if not isinstance(count, int) or count < 0:
            raise RuntimeError("invalid_production_selected_count")
        if capped != min(pilot.MAX_POSITIONS_PER_GAME, count):
            raise RuntimeError("per_game_capped_contribution_mismatch")

        if count > 0:
            if outcome != "CANDIDATES_AVAILABLE":
                raise RuntimeError("candidate_producer_outcome_mismatch")
            trace_producers.append(game_sha)
        else:
            if outcome != "NO_ELIGIBLE_POSITIONS":
                raise RuntimeError("zero_candidate_outcome_mismatch")
            zero_candidate_games.append(game_sha)

    if producer_games != trace_producers:
        raise RuntimeError("pool_games_vs_trace_candidate_producers_mismatch")
    if pool.get("candidate_producing_game_count") != len(producer_games):
        raise RuntimeError("candidate_producing_game_count_mismatch")
    if set(producer_games) & set(zero_candidate_games):
        raise RuntimeError("candidate_zero_and_producer_overlap")

    return producer_games, zero_candidate_games


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

    try:
        candidate_producing_games, zero_candidate_games = classify_processed_games(pool)
    except RuntimeError as exc:
        raise SystemExit(str(exc)) from exc

    pool["pool_sha256"] = digest_without(pool, "pool_sha256")
    pilot_games = sorted(set(manifest.get("excluded_from_ve1d_game_sha256", [])))
    selected_games = sorted({position["game_sha256"] for position in manifest["selected_positions"]})
    if selected_games != pilot_games:
        raise SystemExit("selected_games_vs_manifest_pilot_list_mismatch")
    if len(pilot_games) < pilot.MIN_SOURCE_GAMES:
        raise SystemExit("pilot_contributing_game_count_mismatch")
    if not set(pilot_games).issubset(set(candidate_producing_games)):
        raise SystemExit("selected_pilot_game_not_in_candidate_producers")
    if B6_SHA256 in candidate_producing_games or B6_SHA256 in selected_games:
        raise SystemExit("b6_fixture_selected_into_pool_or_pilot")

    full_ve1d_exclusion = _ordered_unique(candidate_producing_games + [B6_SHA256])
    if set(zero_candidate_games) & set(full_ve1d_exclusion):
        raise SystemExit("zero_candidate_game_in_ve1d_exclusion")

    exclusion: dict[str, Any] = {
        "schema_version": EXCLUSION_SCHEMA,
        "sampling_key": pilot.SAMPLING_KEY,
        "authority_commit": pilot.AUTHORITY_COMMIT,
        "corpus_manifest_sha256": pool.get("corpus_manifest_sha256"),
        "seeded_plan_sha256": pool.get("seeded_plan_sha256"),
        "pool_sha256": pool["pool_sha256"],
        "pilot_manifest_sha256": manifest.get("manifest_sha256"),
        "processed_game_count": pool.get("processed_game_count"),
        "candidate_producing_game_count": len(candidate_producing_games),
        "candidate_producing_game_sha256": candidate_producing_games,
        "zero_candidate_processed_game_sha256": zero_candidate_games,
        "selected_pilot_game_count": len(pilot_games),
        "pilot_game_sha256": pilot_games,
        "permanent_excluded_game_sha256": [B6_SHA256],
        "ve1d_excluded_game_sha256": full_ve1d_exclusion,
        "ve1d_exclusion_scope": ["tuning", "holdout", "reserve"],
        "natural_pilot_execution_permitted": False,
        "rule": (
            "Before natural pilot execution, exclude from every VE1-D partition all games in the "
            "processed seeded prefix that produced one or more production-selector candidates, plus "
            "the permanent B6 fixture. Processed games with zero eligible candidates remain eligible "
            "for VE1-D and must not appear in ve1d_excluded_game_sha256."
        ),
    }
    exclusion["exclusion_authority_sha256"] = digest_without(exclusion, "exclusion_authority_sha256")

    write(Path(args.pool_output), pool)
    write(Path(args.exclusion_output), exclusion)
    print(json.dumps({
        "status": "PASS",
        "pool_sha256": pool["pool_sha256"],
        "pilot_manifest_sha256": manifest.get("manifest_sha256"),
        "processed_games": pool.get("processed_game_count"),
        "candidate_producing_games": len(candidate_producing_games),
        "zero_candidate_processed_games": len(zero_candidate_games),
        "selected_pilot_games": len(pilot_games),
        "ve1d_excluded_games": len(full_ve1d_exclusion),
        "exclusion_authority_sha256": exclusion["exclusion_authority_sha256"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
