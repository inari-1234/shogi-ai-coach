#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

import ve1c1_corpus_manifest as corpus

SCHEMA = "ve1c1-swift-pool-input-v1"


def main() -> int:
    p = argparse.ArgumentParser(description="Pack committed VE1-C1 corpus in seeded order for the Swift production selector")
    p.add_argument("--archive", required=True)
    p.add_argument("--manifest", required=True)
    p.add_argument("--output-dir", required=True)
    args = p.parse_args()

    archive = Path(args.archive)
    manifest = corpus.load_json(Path(args.manifest)) if hasattr(corpus, "load_json") else json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    corpus.validate_manifest(manifest)
    rebuilt = corpus.build_manifest(archive)
    if corpus.canonical_json(manifest) != corpus.canonical_json(rebuilt):
        raise SystemExit("archive_vs_committed_manifest_mismatch")
    plan = corpus.build_seeded_plan(manifest)

    out = Path(args.output_dir)
    games_dir = out / "games"
    games_dir.mkdir(parents=True, exist_ok=True)
    by_sha = {g["game_sha256"]: g for g in manifest["games"]}
    packed = []
    with zipfile.ZipFile(archive, metadata_encoding="cp932") as zf:
        for item in plan["ordered_games"]:
            game_sha = item["game_sha256"]
            source = by_sha[game_sha]
            raw = zf.read(source["archive_member"])
            if corpus.sha256_bytes(raw) != game_sha:
                raise SystemExit(f"packed_game_sha_mismatch:{game_sha}")
            rank = int(item["rank"])
            name = f"game-{rank:04d}.kif"
            (games_dir / name).write_bytes(raw)
            packed.append({
                "rank": rank,
                "file_name": name,
                "archive_member": source["archive_member"],
                "game_sha256": game_sha,
                "game_sampling_sha256": item["game_sampling_sha256"],
                "source_id": manifest["source"]["source_id"],
            })

    index = {
        "schema_version": SCHEMA,
        "sampling_key": corpus.SAMPLING_KEY,
        "corpus_manifest_sha256": manifest["manifest_sha256"],
        "seeded_plan_sha256": plan["plan_sha256"],
        "game_count": len(packed),
        "games": packed,
    }
    (out / "pool-input.json").write_text(
        json.dumps(index, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    (out / "seeded-game-order.json").write_text(
        json.dumps(plan, ensure_ascii=False, sort_keys=True, indent=2) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "status": "PASS",
        "game_count": len(packed),
        "corpus_manifest_sha256": manifest["manifest_sha256"],
        "seeded_plan_sha256": plan["plan_sha256"],
    }, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
