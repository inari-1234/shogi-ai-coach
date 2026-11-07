#!/usr/bin/env python3
"""Incident preflight: find one LEGAL=1 root that can reach 50k nodes.

Uses a pinned material-edition YaneuraOu solely for cheap candidate elimination.
Production NNUE/Simulator fixture remains the formal acceptance gate.
"""
import argparse
import json
import os
import re
import selectors
import subprocess
import tempfile
import time
from pathlib import Path

CANDIDATES = [
    ("rook-pawn", "k7r/9/9/9/9/9/7p1/9/8K"),
    ("rook-pawn-defender-rook", "k7r/9/9/9/9/9/7p1/9/1R6K"),
    ("rook-pawn-defender-gold", "k7r/9/9/9/9/9/6Gp1/9/8K"),
    ("rook-pawn-defender-silver", "k7r/9/9/9/9/9/6Sp1/9/8K"),
    ("rook-pawn-defender-bishop", "k7r/9/1B7/9/9/9/7p1/9/8K"),
    ("rook-pawn-two-defenders", "k7r/9/1B7/9/9/9/6Gp1/9/1R6K"),
    ("rook-silver", "k7r/9/9/9/9/9/7s1/9/8K"),
    ("lance-pawn", "k7l/9/9/9/9/9/7p1/9/8K"),
]
BUDGET = 50000


def audit(engine, positions):
    with tempfile.NamedTemporaryFile(mode="w", delete=False, encoding="utf-8") as fh:
        input_path = Path(fh.name)
        for idx, (_, sfen) in enumerate(positions, 1):
            fh.write(f"{idx}\tposition sfen {sfen} b - 1\n")
    try:
        cmd = subprocess.run(
            [str(engine), "--ve1b-legal-audit", str(input_path)],
            text=True, capture_output=True, timeout=30, check=False
        )
    finally:
        input_path.unlink(missing_ok=True)
    if cmd.returncode:
        raise RuntimeError(f"root audit rc={cmd.returncode}: {cmd.stderr[-2000:]}")
    counts = {}
    for line in cmd.stdout.splitlines():
        if not line.startswith("VE1B\t"):
            continue
        items = line.split("\t", 4)
        if len(items) != 5:
            raise RuntimeError("unexpected native root audit output")
        counts[int(items[1])] = (int(items[2]), int(items[3]))
    if len(counts) != len(positions):
        raise RuntimeError(f"native root audit returned {len(counts)} of {len(positions)} rows")
    return counts


def probe_search(engine, position):
    proc = subprocess.Popen(
        [str(engine)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT, bufsize=0
    )
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    buf = bytearray()
    lines = []
    def send(command):
        proc.stdin.write((command + "\n").encode("utf-8"))
        proc.stdin.flush()
    def recv(deadline):
        while time.monotonic() < deadline:
            split = buf.find(b"\n")
            if split != -1:
                line = bytes(buf[:split]).decode("utf-8", errors="replace").strip()
                del buf[:split + 1]
                return line
            ready = selector.select(max(0, min(0.5, deadline - time.monotonic())))
            if ready:
                piece = os.read(proc.stdout.fileno(), 8192)
                if not piece:
                    break
                buf.extend(piece)
            elif proc.poll() is not None:
                break
        return None
    def expect(marker, seconds):
        deadline = time.monotonic() + seconds
        while time.monotonic() < deadline:
            line = recv(deadline)
            if line is None:
                break
            if line == marker:
                return
        raise RuntimeError(f"engine handshake missing {marker}")
    try:
        send("usi")
        expect("usiok", 15)
        send("setoption name Threads value 1")
        send("setoption name MultiPV value 3")
        send("setoption name BookFile value no_book")
        send("isready")
        expect("readyok", 15)
        send("usinewgame")
        send(position)
        send(f"go nodes {BUDGET}")
        deadline = time.monotonic() + 25
        max_nodes = 0
        bestmove = None
        has_rank1 = False
        mate_scores = []
        while time.monotonic() < deadline:
            line = recv(deadline)
            if line is None:
                break
            if line.startswith("info "):
                lines.append(line)
                nodes = re.search(r"\bnodes (\d+)\b", line)
                if nodes:
                    max_nodes = max(max_nodes, int(nodes.group(1)))
                if " multipv 1 " in f" {line} " and " score " in f" {line} ":
                    has_rank1 = True
                    if " score mate " in f" {line} ":
                        mate_scores.append(line)
            if line.startswith("bestmove "):
                bestmove = line
                break
        return {
            "maxObservedNodes": max_nodes,
            "bestmove": bestmove,
            "rank1Scored": has_rank1,
            "earlyMateObservations": len(mate_scores),
            "passed": bool(bestmove and has_rank1 and max_nodes >= BUDGET),
            "rawUSIInfoLines": lines,
        }
    finally:
        try:
            send("quit")
        except (BrokenPipeError, OSError):
            pass
        try:
            proc.wait(timeout=2)
        except subprocess.TimeoutExpired:
            proc.kill()
            proc.wait()
        selector.close()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--engine", type=Path, required=True)
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    candidates = list(CANDIDATES)
    counts = audit(args.engine, candidates)
    rows = []
    selected = None
    for idx, (name, sfen) in enumerate(candidates, 1):
        command = f"position sfen {sfen} b - 1"
        legal, legal_all = counts[idx]
        row = {"name": name, "positionCommand": command,
               "legalRootMoveCount": legal, "legalAllMoveCount": legal_all}
        if legal == 1:
            row.update(probe_search(args.engine, command))
            if row["passed"]:
                selected = row.copy()
                rows.append(row)
                break
        else:
            row["passed"] = False
            row["skipReason"] = "LEGAL_ROOT_NOT_ONE"
        rows.append(row)
    report = {
        "schemaVersion": 1,
        "status": "PASS" if selected is not None else "FAIL",
        "purpose": "fixture_selection_diagnostic_only",
        "runtime": "pinned_yaneuraou_material_not_production_nnue",
        "requiredNodes": BUDGET,
        "selectedCandidate": selected,
        "candidates": rows,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps({
        "status": report["status"],
        "selected": selected and {k: selected[k] for k in (
            "name", "positionCommand", "maxObservedNodes", "bestmove")},
        "tested": [{"name": r["name"], "legal": r["legalRootMoveCount"],
                    "nodes": r.get("maxObservedNodes"), "passed": r["passed"]} for r in rows],
    }, indent=2))
    if selected is None:
        raise SystemExit("no LEGAL=1 candidate reached 50k in pinned material-engine preflight")


if __name__ == "__main__":
    main()
