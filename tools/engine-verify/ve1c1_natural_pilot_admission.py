#!/usr/bin/env python3
"""Derive, never hand-edit, VE1-C1 natural-pilot execution admission.

The frozen VE1-D exclusion snapshot contains natural_pilot_execution_permitted=false
because it was generated *before* commit. This independent check may report true
only after the exact pool, pilot and exclusion are committed in Git history.
"""
from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import ve1c1_pilot as pilot
import ve1c1_pool_freeze as freeze

FREEZE_COMMIT = "4eb3bce7264f3f56f05b93c03a8bebc7f990d4eb"
FROZEN_FILES = (
    "Build19/BUILD19_VE1_C1_PRODUCTION_POOL_20261014.json",
    "Build19/BUILD19_VE1_C1_NATURAL_PILOT_MANIFEST_20261014.json",
    "Build19/BUILD19_VE1_D_EXCLUSION_AUTHORITY_20261014.json",
)
CORPUS_FILE = "Build19/BUILD19_VE1_C1_CANDIDATE_GAME_CORPUS_20261014.json"
SEED_ORDER_FILE = "Build19/BUILD19_VE1_C1_SEEDED_GAME_ORDER_20261014.json"
SCHEMA = "ve1c1-natural-pilot-admission-v1"


class AdmissionError(ValueError):
    pass


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise AdmissionError(reason)


def digest_correct(obj: dict, digest_field: str) -> bool:
    return freeze.digest_without(obj, digest_field) == obj.get(digest_field)


def validate_bound_artifacts(
    pool: dict, manifest: dict, exclusion: dict, corpus: dict, order: dict
) -> dict:
    require(pool.get("schema_version") == freeze.POOL_SCHEMA, "pool_schema")
    require(manifest.get("schema_version") == pilot.MANIFEST_SCHEMA, "pilot_schema")
    require(exclusion.get("schema_version") == freeze.EXCLUSION_SCHEMA, "exclusion_schema")
    require(digest_correct(pool, "pool_sha256"), "pool_digest_mismatch")
    require(digest_correct(manifest, "manifest_sha256"), "pilot_digest_mismatch")
    require(digest_correct(exclusion, "exclusion_authority_sha256"), "exclusion_digest_mismatch")

    require(pool.get("authority_commit") == pilot.AUTHORITY_COMMIT, "pool_authority")
    require(manifest.get("authority_commit") == pilot.AUTHORITY_COMMIT, "pilot_authority")
    require(exclusion.get("authority_commit") == pilot.AUTHORITY_COMMIT, "exclusion_authority")
    require(pool.get("sampling_key") == pilot.SAMPLING_KEY, "pool_sampling_key")
    require(manifest.get("sampling_key") == pilot.SAMPLING_KEY, "pilot_sampling_key")
    require(exclusion.get("sampling_key") == pilot.SAMPLING_KEY, "exclusion_sampling_key")

    require(pool.get("corpus_manifest_sha256") == corpus.get("manifest_sha256"), "corpus_binding")
    require(pool.get("seeded_plan_sha256") == order.get("plan_sha256"), "order_binding")
    require(exclusion.get("corpus_manifest_sha256") == pool.get("corpus_manifest_sha256"), "exclusion_corpus")
    require(exclusion.get("seeded_plan_sha256") == pool.get("seeded_plan_sha256"), "exclusion_order")
    require(exclusion.get("pool_sha256") == pool.get("pool_sha256"), "exclusion_pool")
    require(exclusion.get("pilot_manifest_sha256") == manifest.get("manifest_sha256"), "exclusion_pilot")

    require(
        exclusion.get("natural_pilot_execution_permitted") is False,
        "frozen_precommit_snapshot_flag_modified",
    )
    require(exclusion.get("ve1d_exclusion_scope") == ["tuning", "holdout", "reserve"], "exclusion_scope")
    require(len(manifest.get("selected_positions", [])) == pilot.PILOT_TARGET, "pilot_count")
    require(pool.get("selector_implementation") == "actual_ShallowAnalysisViewModel_to_DeepAnalysisViewModel_to_DeepImportanceSelector", "selector_identity")

    pilot.validate_pool(pool)
    recomputed_pilot = pilot.select_pilot_positions(pool)
    require(pilot.canonical_json(recomputed_pilot) == pilot.canonical_json(manifest), "pilot_round_robin_or_content_mismatch")

    trace = pool.get("selector_trace", [])
    ordered = order.get("ordered_games", [])
    require(len(trace) == pool.get("processed_game_count"), "processed_trace_count")
    require(len(trace) <= len(ordered), "processed_exceeds_seed_plan")
    for i, row in enumerate(trace):
        expect = ordered[i]
        require(row.get("seed_rank") == i + 1 == expect.get("rank"), "non_prefix_seed_rank")
        require(row.get("game_sha256") == expect.get("game_sha256"), "seed_order_changed")
        if i != len(trace) - 1:
            prefix = trace[: i + 1]
            count = sum(x.get("per_game_capped_contribution", 0) for x in prefix)
            contributors = sum(x.get("production_selected_count", 0) > 0 for x in prefix)
            require(not (count >= pilot.PILOT_TARGET and contributors >= pilot.MIN_SOURCE_GAMES), "not_shortest_prefix")
    producers, zeros = freeze.classify_processed_games(pool)
    expected_exclusion = freeze.derive_ve1d_exclusions(pool, producers, zeros)
    require(
        pool.get("capped_eligible_position_count") ==
        sum(row["per_game_capped_contribution"] for row in trace),
        "capped_position_count",
    )
    require(sum(row["production_selected_count"] > 0 for row in trace) >= 4, "insufficient_contributing_games")
    require(sum(row["per_game_capped_contribution"] for row in trace) >= 16, "insufficient_candidates")
    require(exclusion.get("candidate_producing_game_sha256") == producers, "candidate_producer_exclusion")
    require(exclusion.get("zero_candidate_processed_game_sha256") == zeros, "zero_candidate_exclusion")
    require(
        exclusion.get("previously_exposed_seeded_game_sha256") ==
        list(freeze.PREVIOUSLY_EXPOSED_SEEDED_GAME_SHA256), "exposed_rank_1_2_exclusion",
    )
    require(exclusion.get("ve1d_excluded_game_sha256") == expected_exclusion, "exact_complete_exclusion")
    require(exclusion.get("processed_game_count") == len(trace), "exclusion_processed_count")
    require(exclusion.get("candidate_producing_game_count") == len(producers), "exclusion_producer_count")
    selected_game_hashes = sorted({p["game_sha256"] for p in manifest["selected_positions"]})
    require(exclusion.get("pilot_game_sha256") == selected_game_hashes, "pilot_game_exclusion")
    require(exclusion.get("permanent_excluded_game_sha256") == [freeze.B6_SHA256], "b6_exclusion")
    return {
        "processed_games": len(trace),
        "candidate_producing_games": len(producers),
        "natural_pilot_positions": len(manifest["selected_positions"]),
        "excluded_ve1d_games": len(expected_exclusion),
        "pool_sha256": pool["pool_sha256"],
        "pilot_manifest_sha256": manifest["manifest_sha256"],
        "exclusion_authority_sha256": exclusion["exclusion_authority_sha256"],
    }


def git_read(repo_root: Path, *args: str) -> bytes:
    done = subprocess.run(["git", *args], cwd=repo_root, capture_output=True)
    if done.returncode != 0:
        raise AdmissionError("git_" + "_".join(args[:2]) + "_failed")
    return done.stdout


def validate_committed_history(repo_root: Path) -> str:
    head = git_read(repo_root, "rev-parse", "HEAD").decode().strip()
    git_read(repo_root, "merge-base", "--is-ancestor", FREEZE_COMMIT, head)
    for path in FROZEN_FILES:
        frozen = git_read(repo_root, "show", FREEZE_COMMIT + ":" + path)
        require((repo_root / path).read_bytes() == frozen, "frozen_file_modified:" + path)
    changed = set(
        git_read(repo_root, "diff-tree", "--no-commit-id", "--name-only", "-r", FREEZE_COMMIT)
        .decode().splitlines()
    )
    require(set(FROZEN_FILES).issubset(changed), "freeze_commit_missing_artifacts")
    return head


def run(repo_root: Path, output: Path) -> dict:
    head = validate_committed_history(repo_root)
    objects = [
        json.loads((repo_root / p).read_text(encoding="utf-8"))
        for p in (*FROZEN_FILES, CORPUS_FILE, SEED_ORDER_FILE)
    ]
    result = validate_bound_artifacts(*objects)
    admission = {
        "schema_version": SCHEMA,
        "status": "PASS",
        "computed_natural_pilot_execution_permitted": True,
        "frozen_exclusion_snapshot_flag": False,
        "freeze_commit": FREEZE_COMMIT,
        "execution_head": head,
        **result,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(admission, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")
    return admission


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", default=".", type=Path)
    ap.add_argument("--output", required=True, type=Path)
    args = ap.parse_args()
    try:
        admission = run(args.repo_root.resolve(), args.output)
    except (AdmissionError, ValueError, OSError, pilot.PilotError, RuntimeError) as exc:
        print(json.dumps({"status": "STOP", "failure_class": "D-AUTHORITY", "reason": str(exc)}))
        return 2
    print(json.dumps(admission, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
