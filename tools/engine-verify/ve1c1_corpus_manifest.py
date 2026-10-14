#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import zipfile
from pathlib import Path
from typing import Any

SAMPLING_KEY = "VE1-C1-SAMPLING-v1"
SCHEMA = "ve1c1-candidate-game-corpus-v1"
PLAN_SCHEMA = "ve1c1-seeded-game-order-v1"
SOURCE = {
    "source_id": "denryusen:dr4-hardware2:2024",
    "title": "第2回マイナビニュース杯電竜戦統一ハードウェア戦",
    "archive_url": "https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip",
    "source_page": "https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php",
    "rights_note": "公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。",
    "retrieved_date_authority": "2026-10-02",
}
B6_FIXTURE_SHA256 = "ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102"
BLOCKED_SHA256 = {B6_FIXTURE_SHA256: "B6_REPEATEDLY_INSPECTED_FIXTURE"}


class CorpusError(RuntimeError):
    pass


def canonical_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sampling_hash(*parts: str) -> str:
    return sha256_bytes("|".join((SAMPLING_KEY, *parts)).encode("utf-8"))


def manifest_digest(document: dict[str, Any]) -> str:
    body = dict(document)
    body.pop("manifest_sha256", None)
    return sha256_bytes(canonical_json(body).encode("utf-8"))


def plan_digest(document: dict[str, Any]) -> str:
    body = dict(document)
    body.pop("plan_sha256", None)
    return sha256_bytes(canonical_json(body).encode("utf-8"))


def build_manifest(archive: Path) -> dict[str, Any]:
    if not archive.is_file():
        raise CorpusError("archive_missing")
    games: list[dict[str, Any]] = []
    seen_hashes: set[str] = set()
    with zipfile.ZipFile(archive, metadata_encoding="cp932") as zf:
        members = sorted(
            (m for m in zf.infolist() if not m.is_dir() and m.filename.lower().endswith(".kif")),
            key=lambda m: m.filename,
        )
        if not members:
            raise CorpusError("no_kif_members")
        for member in members:
            raw = zf.read(member)
            game_sha = sha256_bytes(raw)
            if game_sha in seen_hashes:
                raise CorpusError(f"duplicate_game_content:{game_sha}")
            seen_hashes.add(game_sha)
            games.append({
                "archive_member": member.filename,
                "byte_size": len(raw),
                "game_sha256": game_sha,
                "game_sampling_sha256": sampling_hash("GAME", game_sha),
                "blocked": game_sha in BLOCKED_SHA256,
                "blocked_reason": BLOCKED_SHA256.get(game_sha),
            })
    document: dict[str, Any] = {
        "schema_version": SCHEMA,
        "sampling_key": SAMPLING_KEY,
        "source": SOURCE,
        "archive": {
            "file_name": archive.name,
            "sha256": sha256_file(archive),
        },
        "kif_count": len(games),
        "blocked_game_sha256": [
            {"game_sha256": k, "reason": v} for k, v in sorted(BLOCKED_SHA256.items())
        ],
        "games": games,
    }
    document["manifest_sha256"] = manifest_digest(document)
    return document


def validate_manifest(document: dict[str, Any]) -> None:
    if document.get("schema_version") != SCHEMA:
        raise CorpusError("manifest_schema_mismatch")
    if document.get("sampling_key") != SAMPLING_KEY:
        raise CorpusError("sampling_key_mismatch")
    if document.get("source") != SOURCE:
        raise CorpusError("source_metadata_mismatch")
    games = document.get("games")
    if not isinstance(games, list) or not games:
        raise CorpusError("games_missing")
    if document.get("kif_count") != len(games):
        raise CorpusError("kif_count_mismatch")
    hashes = [g.get("game_sha256") for g in games]
    if len(set(hashes)) != len(hashes):
        raise CorpusError("duplicate_game_hash")
    if document.get("manifest_sha256") != manifest_digest(document):
        raise CorpusError("manifest_digest_mismatch")
    blocked = {x.get("game_sha256") for x in document.get("blocked_game_sha256", [])}
    if B6_FIXTURE_SHA256 not in blocked:
        raise CorpusError("b6_exclusion_missing")


def build_seeded_plan(document: dict[str, Any]) -> dict[str, Any]:
    validate_manifest(document)
    eligible = [g for g in document["games"] if not g.get("blocked")]
    eligible.sort(key=lambda g: (g["game_sampling_sha256"], g["game_sha256"]))
    ordered = [
        {
            "rank": i + 1,
            "archive_member": g["archive_member"],
            "game_sha256": g["game_sha256"],
            "game_sampling_sha256": g["game_sampling_sha256"],
        }
        for i, g in enumerate(eligible)
    ]
    plan: dict[str, Any] = {
        "schema_version": PLAN_SCHEMA,
        "sampling_key": SAMPLING_KEY,
        "corpus_manifest_sha256": document["manifest_sha256"],
        "selection_policy": "ascending SHA256(SAMPLING_KEY|GAME|gameSHA256), then raw gameSHA256",
        "blocked_game_sha256": document["blocked_game_sha256"],
        "eligible_game_count": len(ordered),
        "ordered_games": ordered,
    }
    plan["plan_sha256"] = plan_digest(plan)
    return plan


def load(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def cmd_build(args: argparse.Namespace) -> int:
    doc = build_manifest(Path(args.archive))
    write(Path(args.output), doc)
    print(json.dumps({"status": "PASS", "kif_count": doc["kif_count"], "manifest_sha256": doc["manifest_sha256"]}, sort_keys=True))
    return 0


def cmd_verify(args: argparse.Namespace) -> int:
    committed = load(Path(args.manifest))
    validate_manifest(committed)
    rebuilt = build_manifest(Path(args.archive))
    if canonical_json(committed) != canonical_json(rebuilt):
        raise CorpusError("archive_vs_committed_manifest_mismatch")
    print(json.dumps({"status": "PASS", "kif_count": committed["kif_count"], "manifest_sha256": committed["manifest_sha256"]}, sort_keys=True))
    return 0


def cmd_plan(args: argparse.Namespace) -> int:
    plan = build_seeded_plan(load(Path(args.manifest)))
    write(Path(args.output), plan)
    print(json.dumps({"status": "PASS", "eligible_game_count": plan["eligible_game_count"], "plan_sha256": plan["plan_sha256"]}, sort_keys=True))
    return 0


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="VE1-C1 deterministic candidate-game corpus authority")
    sp = p.add_subparsers(dest="command", required=True)
    b = sp.add_parser("build")
    b.add_argument("--archive", required=True); b.add_argument("--output", required=True); b.set_defaults(func=cmd_build)
    v = sp.add_parser("verify")
    v.add_argument("--archive", required=True); v.add_argument("--manifest", required=True); v.set_defaults(func=cmd_verify)
    s = sp.add_parser("plan")
    s.add_argument("--manifest", required=True); s.add_argument("--output", required=True); s.set_defaults(func=cmd_plan)
    return p


def main() -> int:
    args = parser().parse_args()
    try:
        return int(args.func(args))
    except (CorpusError, zipfile.BadZipFile) as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
