#!/usr/bin/env python3
"""Diagnostic-only locator for the independently supplied C1 values 236 / 157.

This script does not qualify C1 and must never create a freeze result. It scans
legal positions already present in repository fixtures to identify which fixed
position, if any, reproduces the independent review's depth-1 values.
Historical 41/49/69 game data are used only as diagnostic position inputs, never
as semantic truth labels.
"""
from __future__ import annotations

import argparse
from pathlib import Path
from typing import Any

from ve1q_harness import Engine, effective_profile, read_json, swift_compatible_accumulate, write_json

TOOL = Path(__file__).resolve().parent

EXPECTED = {"fv16": 236, "fv24": 157}


def score_value(lines: list[str]) -> tuple[str | None, int | None, str | None]:
    r = swift_compatible_accumulate(lines)
    pvs = r.get("principalVariations", [])
    if not pvs or pvs[0].get("score") is None:
        return None, None, r.get("bestmove")
    s = pvs[0]["score"]
    return s.get("type"), s.get("value"), r.get("bestmove")


def position(prefix: list[str]) -> str:
    return "position startpos" + (" moves " + " ".join(prefix) if prefix else "")


def candidate_sequences() -> list[dict[str, Any]]:
    hist = read_json(TOOL / "fixtures/build19-hds-41-49-69.json")["moves"].split()
    kif = [
        "7g7f", "3c3d", "2g2f", "5c5d", "2f2e", "8b5b", "4i5h", "5d5e",
        "2e2d", "2c2d", "2h2d", "5e5f", "5g5f", "2b8h+", "7i8h", "B*3c",
        "2d2a+", "3c8h+", "N*5e", "5a6b", "2a1a",
    ]
    opening = ["7g7f", "3c3d", "2g2f", "8c8d", "2f2e", "8d8e", "6i7h", "4a3b"]
    return [
        {"id": "historical-hds-game-prefixes", "authority": "DIAGNOSTIC_POSITION_INPUT_ONLY", "moves": hist},
        {"id": "kifparser-realworld-prefixes", "authority": "LEGAL_TEST_SEQUENCE_ONLY", "moves": kif},
        {"id": "kifparser-opening-prefixes", "authority": "LEGAL_TEST_SEQUENCE_ONLY", "moves": opening},
    ]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    work = Path(args.work)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    cfg16 = effective_profile("app-current"); cfg16["multipv"] = 1
    cfg24 = effective_profile("app-candidate"); cfg24["multipv"] = 1
    e16 = Engine(work, "app-current", cfg16, out / "diagnostic-fv16.usi.log")
    e24 = Engine(work, "app-candidate", cfg24, out / "diagnostic-fv24.usi.log")
    rows: list[dict[str, Any]] = []
    try:
        for seq in candidate_sequences():
            moves = seq["moves"]
            for ply in range(0, len(moves) + 1):
                pos = position(moves[:ply])
                try:
                    l16 = e16.go(pos, "depth 1", multipv=1)
                    l24 = e24.go(pos, "depth 1", multipv=1)
                    t16, v16, b16 = score_value(l16)
                    t24, v24, b24 = score_value(l24)
                    distance = None if v16 is None or v24 is None else abs(v16 - EXPECTED["fv16"]) + abs(v24 - EXPECTED["fv24"])
                    rows.append({
                        "sequence": seq["id"], "authority": seq["authority"], "ply": ply,
                        "position": pos, "fv16": {"type": t16, "value": v16, "bestmove": b16},
                        "fv24": {"type": t24, "value": v24, "bestmove": b24},
                        "distance": distance,
                        "exact": t16 == "cp" and t24 == "cp" and v16 == EXPECTED["fv16"] and v24 == EXPECTED["fv24"],
                    })
                except Exception as e:
                    rows.append({"sequence": seq["id"], "ply": ply, "position": pos, "error": f"{type(e).__name__}: {e}"})
                    break
    finally:
        e16.close(); e24.close()

    valid = [r for r in rows if r.get("distance") is not None]
    exact = [r for r in valid if r.get("exact")]
    nearest = sorted(valid, key=lambda r: (r["distance"], r["sequence"], r["ply"]))[:20]
    result = {
        "schema_version": "ve1q-c1-calibration-discovery-v1",
        "status": "DIAGNOSTIC_ONLY_NOT_AUTHORITY",
        "expected": EXPECTED,
        "exact_matches": exact,
        "nearest_matches": nearest,
        "positions_scanned": len(valid),
        "note": "A match is only a locator candidate. C1 remains FAIL until a fixed position is explicitly frozen and rerun with fresh engine sessions."
    }
    write_json(out / "c1-calibration-discovery.json", result)
    print(result)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
