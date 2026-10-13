#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
from pathlib import Path
from typing import Any, Iterable

try:
    from ve1q_harness import parse_info_swift_compatible
except ImportError:  # unit tests may import by file path
    parse_info_swift_compatible = None

AUTHORITY_COMMIT = "8daf78caa2bd5919cc911da21bae80fa3d12a248"
SAMPLING_KEY = "VE1-C1-SAMPLING-v1"
PILOT_TARGET = 16
MIN_SOURCE_GAMES = 4
MAX_POSITIONS_PER_GAME = 4
K_EXPECTED_SCORE = 285.0
TAU_GOOD_REF = 0.050
TAU_BLUNDER_REF = 0.200
DELTA_GRID = tuple(round(i * 0.005, 3) for i in range(11))
MANIFEST_SCHEMA = "ve1c1-pilot-manifest-v1"
POOL_SCHEMA = "ve1c1-pilot-pool-v1"
PILOT_RESULT_SCHEMA = "ve1c1-pilot-result-v1"
HEX64 = re.compile(r"^[0-9a-f]{64}$")


class PilotError(RuntimeError):
    pass


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def expected_score(cp: int | float) -> float:
    return 1.0 / (1.0 + math.exp(-float(cp) / K_EXPECTED_SCORE))


def _sampling_hash(*parts: str) -> str:
    return sha256_text("|".join((SAMPLING_KEY, *parts)))


def position_sampling_hash(game_sha256: str, ply: int) -> str:
    return _sampling_hash(game_sha256, str(ply))


def game_sampling_hash(game_sha256: str) -> str:
    return _sampling_hash("GAME", game_sha256)


def validate_pool(pool: dict[str, Any]) -> None:
    if pool.get("schema_version") != POOL_SCHEMA:
        raise PilotError("pool_schema_mismatch")
    if pool.get("authority_commit") != AUTHORITY_COMMIT:
        raise PilotError("authority_commit_mismatch")
    games = pool.get("games")
    if not isinstance(games, list) or len(games) < MIN_SOURCE_GAMES:
        raise PilotError("insufficient_source_games")
    seen_games: set[str] = set()
    for game in games:
        sha = game.get("game_sha256")
        if not isinstance(sha, str) or not HEX64.fullmatch(sha):
            raise PilotError("invalid_game_sha256")
        if sha in seen_games:
            raise PilotError("duplicate_game_sha256")
        seen_games.add(sha)
        positions = game.get("positions")
        if not isinstance(positions, list) or not positions:
            raise PilotError("game_has_no_positions")
        seen_plies: set[int] = set()
        for pos in positions:
            ply = pos.get("ply")
            cmd = pos.get("position_command")
            actual = pos.get("actual_move")
            if not isinstance(ply, int) or ply < 1 or ply in seen_plies:
                raise PilotError("invalid_or_duplicate_ply")
            seen_plies.add(ply)
            if not isinstance(cmd, str) or not cmd.startswith("position "):
                raise PilotError("invalid_position_command")
            if not isinstance(actual, str) or not actual:
                raise PilotError("missing_actual_move")
            if pos.get("selected_by_production_deep_selector") is not True:
                raise PilotError("position_not_from_production_selector")


def select_pilot_positions(pool: dict[str, Any], target: int = PILOT_TARGET) -> dict[str, Any]:
    validate_pool(pool)
    if target != PILOT_TARGET:
        raise PilotError("pilot_target_is_frozen_at_16")

    per_game: list[tuple[str, list[dict[str, Any]], dict[str, Any]]] = []
    for game in pool["games"]:
        game_sha = game["game_sha256"]
        ranked = sorted(
            game["positions"],
            key=lambda p: (position_sampling_hash(game_sha, p["ply"]), p["ply"]),
        )[:MAX_POSITIONS_PER_GAME]
        per_game.append((game_sha, ranked, game))

    per_game.sort(key=lambda item: (game_sampling_hash(item[0]), item[0]))
    selected: list[dict[str, Any]] = []
    contributing_games: set[str] = set()
    for slot in range(MAX_POSITIONS_PER_GAME):
        for game_sha, ranked, game in per_game:
            if len(selected) >= target:
                break
            if slot >= len(ranked):
                continue
            pos = ranked[slot]
            selected.append({
                "game_sha256": game_sha,
                "source_id": game.get("source_id"),
                "ply": pos["ply"],
                "position_command": pos["position_command"],
                "actual_move": pos["actual_move"],
                "position_sampling_sha256": position_sampling_hash(game_sha, pos["ply"]),
            })
            contributing_games.add(game_sha)
        if len(selected) >= target:
            break

    if len(selected) != target:
        raise PilotError(f"insufficient_positions_after_per_game_cap:{len(selected)}")
    if len(contributing_games) < MIN_SOURCE_GAMES:
        raise PilotError(f"insufficient_contributing_games:{len(contributing_games)}")

    manifest: dict[str, Any] = {
        "schema_version": MANIFEST_SCHEMA,
        "authority_commit": AUTHORITY_COMMIT,
        "sampling_key": SAMPLING_KEY,
        "target_positions": PILOT_TARGET,
        "min_source_games": MIN_SOURCE_GAMES,
        "max_positions_per_game": MAX_POSITIONS_PER_GAME,
        "selected_positions": selected,
        "excluded_from_ve1d_game_sha256": sorted(contributing_games),
        "app_contract": {
            "candidate_discovery_node_tiers": [50_000, 100_000, 200_000],
            "confirmation_node_tiers": [50_000, 100_000, 200_000],
            "candidate_identity_source": "deepest_unrestricted_discovery_200k",
            "threads": 1,
            "hash_mb": 64,
            "fv_scale": 24,
            "book_file": "no_book",
            "pv_interval_ms": 0,
            "cold_tt_boundary": "isready_readyok_then_usinewgame_before_each_independent_search",
        },
        "reference_contract": {
            "node_budgets": [4_000_000, 16_000_000],
            "threads": 1,
            "hash_mb": 512,
            "fv_scale": 24,
            "book_file": "no_book",
            "pv_interval_ms": 0,
            "multipv": 3,
            "cold_tt_boundary": "isready_readyok_then_usinewgame_before_each_independent_search",
            "measurement": "deepest_fully_completed_exact_iteration",
        },
        "semantic_contract": {
            "expected_score_k": 285,
            "tau_good_ref": TAU_GOOD_REF,
            "tau_blunder_ref": TAU_BLUNDER_REF,
            "delta_grid": list(DELTA_GRID),
            "f_candidates": ["F0", "F2"],
            "e_candidates": ["E0", "E1"],
            "zero_case_fallback": {"F": "F0", "E": "E0"},
        },
    }
    manifest["manifest_sha256"] = sha256_text(canonical_json(manifest))
    return manifest


def _swift_parser(line: str) -> dict[str, Any] | None:
    if parse_info_swift_compatible is None:
        raise PilotError("ve1q_harness_import_failed")
    result = parse_info_swift_compatible(line)
    if result is not None:
        result = dict(result)
        result["raw_line"] = line
    return result


def deepest_exact_snapshot(observations: Iterable[dict[str, Any]], required_multipv: int) -> list[dict[str, Any]] | None:
    if required_multipv <= 0:
        return None
    indexed: list[tuple[int, dict[str, Any]]] = []
    for index, info in enumerate(observations):
        rank = info.get("multipv", 1)
        score = info.get("score")
        if (
            info.get("depth") is not None
            and isinstance(rank, int)
            and 1 <= rank <= required_multipv
            and isinstance(score, dict)
            and score.get("bound") is None
            and bool(info.get("pv"))
        ):
            indexed.append((index, info))
    depths = sorted({info["depth"] for _, info in indexed}, reverse=True)
    for depth in depths:
        snapshot: list[dict[str, Any]] = []
        complete = True
        for rank in range(1, required_multipv + 1):
            candidates = [(idx, info) for idx, info in indexed if info["depth"] == depth and info.get("multipv", 1) == rank]
            if not candidates:
                complete = False
                break
            idx, selected = max(
                candidates,
                key=lambda x: (x[1].get("nodes") or 0, x[1].get("time") or 0, x[0]),
            )
            snapshot.append(selected)
        if complete:
            return sorted(snapshot, key=lambda info: info.get("multipv", 1))
    return None


def parse_raw_usi_lines(lines: Iterable[str]) -> list[dict[str, Any]]:
    parsed: list[dict[str, Any]] = []
    for line in lines:
        info = _swift_parser(line.rstrip("\r\n"))
        if info is not None and not line.startswith("info string "):
            parsed.append(info)
    return parsed


def _expected_bound_kind(score: dict[str, Any] | None) -> str | None:
    if score is None:
        return None
    bound = score.get("bound")
    if bound is None:
        return "exact"
    return str(bound)


def verify_evidence_document(document: dict[str, Any]) -> dict[str, Any]:
    mismatches: list[dict[str, Any]] = []
    observation_count = 0
    attempt_count = 0
    for position_index, position in enumerate(document.get("positions", [])):
        for attempt_index, attempt in enumerate(position.get("attempts", [])):
            attempt_count += 1
            parsed_observations: list[dict[str, Any]] = []
            for observation_index, observation in enumerate(attempt.get("observations", [])):
                raw = observation.get("rawUSI")
                if not raw:
                    mismatches.append({"type": "missing_raw_usi", "position": position_index, "attempt": attempt_index, "observation": observation_index})
                    continue
                parsed = _swift_parser(raw)
                observation_count += 1
                if parsed is None:
                    mismatches.append({"type": "raw_parse_failed", "raw": raw})
                    continue
                parsed_observations.append(parsed)
                stored_bound = observation.get("boundKind")
                if stored_bound == "lowerbound": stored_bound = "lower"
                if stored_bound == "upperbound": stored_bound = "upper"
                expected = {
                    "depth": observation.get("depth"),
                    "seldepth": observation.get("seldepth"),
                    "multipv": observation.get("multipv", 1),
                    "nodes": observation.get("nodes"),
                    "nps": observation.get("nps"),
                    "time": observation.get("timeMs"),
                    "pv": observation.get("pv", []),
                    "score_kind": observation.get("scoreKind"),
                    "score_value": observation.get("scoreValue"),
                    "bound_kind": stored_bound,
                }
                actual = {
                    "depth": parsed.get("depth"),
                    "seldepth": parsed.get("seldepth"),
                    "multipv": parsed.get("multipv", 1),
                    "nodes": parsed.get("nodes"),
                    "nps": parsed.get("nps"),
                    "time": parsed.get("time"),
                    "pv": parsed.get("pv", []),
                    "score_kind": None if parsed.get("score") is None else parsed["score"].get("type"),
                    "score_value": None if parsed.get("score") is None else parsed["score"].get("value"),
                    "bound_kind": _expected_bound_kind(parsed.get("score")),
                }
                if actual != expected:
                    mismatches.append({
                        "type": "observation_field_mismatch",
                        "position": position_index,
                        "attempt": attempt_index,
                        "observation": observation_index,
                        "expected": expected,
                        "actual": actual,
                        "raw": raw,
                    })
            required = int(attempt.get("multiPV", 1))
            snapshot = deepest_exact_snapshot(parsed_observations, required)
            if snapshot is None:
                if attempt.get("selectedDepth") is not None:
                    mismatches.append({"type": "selector_missing_snapshot", "position": position_index, "attempt": attempt_index})
                continue
            primary = snapshot[0]
            selected_expected = {
                "depth": attempt.get("selectedDepth"),
                "nodes": attempt.get("selectedNodes"),
                "bound_kind": attempt.get("selectedBoundKind"),
                "pv": attempt.get("selectedPV", []),
            }
            selected_actual = {
                "depth": primary.get("depth"),
                "nodes": primary.get("nodes"),
                "bound_kind": _expected_bound_kind(primary.get("score")),
                "pv": primary.get("pv", []),
            }
            if selected_actual != selected_expected:
                mismatches.append({
                    "type": "selector_primary_mismatch",
                    "position": position_index,
                    "attempt": attempt_index,
                    "expected": selected_expected,
                    "actual": selected_actual,
                })
    return {
        "status": "PASS" if not mismatches else "FAIL",
        "attempt_count": attempt_count,
        "observation_count": observation_count,
        "mismatch_count": len(mismatches),
        "mismatches": mismatches,
    }


def app_allowed_classes(loss: float, delta: float) -> set[str]:
    if delta not in DELTA_GRID:
        raise PilotError("delta_not_in_frozen_grid")
    good_low = round(TAU_GOOD_REF - delta, 12)
    good_high = round(TAU_GOOD_REF + delta, 12)
    blunder_low = round(TAU_BLUNDER_REF - delta, 12)
    blunder_high = round(TAU_BLUNDER_REF + delta, 12)
    if loss <= good_low:
        return {"GOOD"}
    if loss <= good_high:
        return {"GOOD", "SOMEWHAT_WORSE"}
    if loss < blunder_low:
        return {"SOMEWHAT_WORSE"}
    if loss < blunder_high:
        return {"SOMEWHAT_WORSE", "BLUNDER"}
    return {"BLUNDER"}


def classify_reference_loss(loss: float) -> str:
    if loss <= TAU_GOOD_REF:
        return "GOOD"
    if loss < TAU_BLUNDER_REF:
        return "SOMEWHAT_WORSE"
    return "BLUNDER"


def decide_f_policy(cases: list[dict[str, Any]]) -> dict[str, Any]:
    small = [c for c in cases if c.get("kind") == "small_inversion"]
    if not small:
        return {"policy": "F0", "reason": "zero_small_inversion_cases", "n": 0}
    bad: list[str] = []
    for c in small:
        if c.get("reference4m_membership") is not True or c.get("reference16m_membership") is not True:
            bad.append(str(c.get("case_id")))
    if bad:
        return {"policy": "F0", "reason": "f2_reference_counterexample_or_unresolved", "n": len(small), "failed_cases": bad}
    return {"policy": "F2", "reason": "all_small_inversions_good_at_both_reference_budgets", "n": len(small)}


def decide_e_policy(cases: list[dict[str, Any]]) -> dict[str, Any]:
    e1_only = [c for c in cases if c.get("kind") == "e1_only_compatibility"]
    if not e1_only:
        return {"policy": "E0", "reason": "zero_e1_only_cases", "n": 0}
    bad: list[str] = []
    for c in e1_only:
        if c.get("reference4m_compatible") is not True or c.get("reference16m_compatible") is not True:
            bad.append(str(c.get("case_id")))
    if bad:
        return {"policy": "E0", "reason": "e1_reference_counterexample_or_unresolved", "n": len(e1_only), "failed_cases": bad}
    return {"policy": "E1", "reason": "all_e1_only_cases_reference_compatible_at_both_budgets", "n": len(e1_only)}


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def cmd_select(args: argparse.Namespace) -> int:
    manifest = select_pilot_positions(load_json(Path(args.pool)))
    write_json(Path(args.output), manifest)
    print(json.dumps({"status": "PASS", "manifest_sha256": manifest["manifest_sha256"], "positions": len(manifest["selected_positions"]), "games": len(manifest["excluded_from_ve1d_game_sha256"])}, sort_keys=True))
    return 0


def cmd_parity(args: argparse.Namespace) -> int:
    result = verify_evidence_document(load_json(Path(args.evidence)))
    if args.output:
        write_json(Path(args.output), result)
    print(json.dumps({k: result[k] for k in ("status", "attempt_count", "observation_count", "mismatch_count")}, sort_keys=True))
    return 0 if result["status"] == "PASS" else 1


def cmd_decide(args: argparse.Namespace) -> int:
    data = load_json(Path(args.result))
    if data.get("schema_version") != PILOT_RESULT_SCHEMA:
        raise PilotError("pilot_result_schema_mismatch")
    decision = {
        "F": decide_f_policy(data.get("f_cases", [])),
        "E": decide_e_policy(data.get("e_cases", [])),
    }
    print(json.dumps(decision, ensure_ascii=False, sort_keys=True, indent=2))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="Build19 VE1-C1 pre-pilot contract tools")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("select", help="derive frozen 16-position pilot manifest from production-selected pool")
    s.add_argument("--pool", required=True)
    s.add_argument("--output", required=True)
    s.set_defaults(func=cmd_select)
    q = sub.add_parser("parity-evidence", help="verify rawUSI parsing + deepest exact snapshot parity against Swift-exported evidence")
    q.add_argument("--evidence", required=True)
    q.add_argument("--output")
    q.set_defaults(func=cmd_parity)
    d = sub.add_parser("decide", help="apply preregistered F/E pilot adoption rules")
    d.add_argument("--result", required=True)
    d.set_defaults(func=cmd_decide)
    return p


def main() -> int:
    args = build_parser().parse_args()
    try:
        return int(args.func(args))
    except PilotError as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
