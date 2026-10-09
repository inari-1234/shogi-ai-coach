#!/usr/bin/env python3
"""Harness-independent C1 diagnostic probe.

This script intentionally does not import ve1q_harness/qualify. It talks to the
pinned USI engine directly and records the depth-1 MultiPV=3 result for FV_SCALE
16 and 24. It is diagnostic evidence only and cannot qualify or freeze VE1-Q.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from typing import Any


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def read_until(p: subprocess.Popen[str], log, prefix: str) -> list[str]:
    out: list[str] = []
    assert p.stdout is not None
    while True:
        line = p.stdout.readline()
        if not line:
            raise RuntimeError(f"engine exited before {prefix}")
        line = line.rstrip("\r\n")
        log.write(line + "\n"); log.flush()
        out.append(line)
        if line.startswith(prefix):
            return out


def send(p: subprocess.Popen[str], log, cmd: str) -> None:
    assert p.stdin is not None
    log.write("> " + cmd + "\n"); log.flush()
    p.stdin.write(cmd + "\n"); p.stdin.flush()


def parse_final_depth1(lines: list[str]) -> dict[str, Any]:
    pvs: dict[int, dict[str, Any]] = {}
    bestmove = None
    for line in lines:
        if line.startswith("bestmove "):
            parts = line.split(); bestmove = parts[1] if len(parts) > 1 else None
            continue
        if not line.startswith("info ") or " depth 1 " not in (" " + line + " ") or " score cp " not in (" " + line + " "):
            continue
        t = line.split()
        try:
            mpv = int(t[t.index("multipv") + 1]) if "multipv" in t else 1
            score = int(t[t.index("score") + 2])
            depth = int(t[t.index("depth") + 1])
            nodes = int(t[t.index("nodes") + 1]) if "nodes" in t else None
            pv = t[t.index("pv") + 1:] if "pv" in t else []
        except Exception:
            continue
        pvs[mpv] = {"multipv": mpv, "depth": depth, "score_cp": score, "nodes": nodes, "pv": pv}
    return {"bestmove": bestmove, "principal_variations": [pvs[k] for k in sorted(pvs)]}


def run_one(work: Path, out_dir: Path, fv: int) -> dict[str, Any]:
    engine = (work / "engine").resolve()
    eval_dir = (work / "eval").resolve()
    raw = out_dir / f"independent-fv{fv}.usi.log"
    with raw.open("w", encoding="utf-8") as log:
        p = subprocess.Popen([str(engine)], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, cwd=str(work))
        try:
            send(p, log, "usi"); usi = read_until(p, log, "usiok")
            options = [x for x in usi if x.startswith("option name ")]
            advertised = {x.split(" name ", 1)[1].split(" type ", 1)[0] for x in options if " type " in x}
            for required in ("Threads", "USI_Hash", "MultiPV", "FV_SCALE", "EvalDir"):
                if required not in advertised:
                    raise RuntimeError("missing option: " + required)
            for cmd in (
                "setoption name Threads value 1",
                "setoption name USI_Hash value 64",
                "setoption name MultiPV value 3",
                f"setoption name FV_SCALE value {fv}",
                f"setoption name EvalDir value {eval_dir}",
                "setoption name BookFile value no_book",
            ):
                send(p, log, cmd)
            send(p, log, "isready"); ready = read_until(p, log, "readyok")
            loaded = [x.split(" : ", 1)[1] for x in ready if x.startswith("info string loading eval file : ")]
            send(p, log, "usinewgame")
            send(p, log, "position startpos")
            send(p, log, "go depth 1")
            search = read_until(p, log, "bestmove")
            parsed = parse_final_depth1(search)
            return {
                "fv_scale": fv,
                "position": "position startpos",
                "go": "depth 1",
                "multipv": 3,
                "loaded_eval_file": loaded[-1] if loaded else None,
                "result": parsed,
                "raw_log": str(raw),
            }
        finally:
            try: send(p, log, "quit")
            except Exception: pass
            try: p.wait(timeout=5)
            except Exception:
                p.kill(); p.wait(timeout=5)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--work", required=True)
    ap.add_argument("--out", required=True)
    args = ap.parse_args()
    work = Path(args.work); out = Path(args.out); out.mkdir(parents=True, exist_ok=True)
    engine = (work / "engine").resolve(); nnue = (work / "eval" / "nn.bin").resolve()
    runs = [run_one(work, out, 16), run_one(work, out, 24)]
    result = {
        "schema_version": "ve1q-c1-independent-diagnostic-v1",
        "status": "DIAGNOSTIC_ONLY_NOT_AUTHORITY",
        "implementation": "standalone subprocess USI; no ve1q_harness/qualify imports",
        "engine_sha256": sha256(engine),
        "nnue_sha256": sha256(nnue),
        "runs": runs,
        "independent_review_observation": {"fv16": 236, "fv24": 157, "position": "UNSPECIFIED_IN_HANDOFF_OR_REVIEW_TEXT"},
        "freeze_effect": "NONE; C1 stays blocked until the fixed position for 236/157 is identified or a new explicit independent calibration authority is supplied."
    }
    (out / "c1-independent-diagnostic.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
