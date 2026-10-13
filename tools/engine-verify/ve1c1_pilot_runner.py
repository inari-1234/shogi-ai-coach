#!/usr/bin/env python3
from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import queue
import subprocess
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import ve1c1_pilot as contract

APP_NODE_TIERS = (50_000, 100_000, 200_000)
REFERENCE_NODE_BUDGETS = (4_000_000, 16_000_000)
APP_HASH_MB = 64
REFERENCE_HASH_MB = 512
SEARCH_TIMEOUT_SECONDS = 180.0
EXPECTED_ENGINE_PIN = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"
EXPECTED_NNUE_SHA256 = "768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def score_order_key(score: dict[str, Any]) -> tuple[int, int]:
    value = int(score.get("value", 0))
    if score.get("type") == "cp":
        return (1, value)
    if score.get("type") == "mate":
        return (2, -abs(value)) if value >= 0 else (0, abs(value))
    raise contract.PilotError("unsupported_score_kind")


def export_observation(info: dict[str, Any]) -> dict[str, Any]:
    score = info.get("score")
    bound = None if score is None else score.get("bound")
    return {
        "rawUSI": info.get("raw_line"),
        "depth": info.get("depth"),
        "seldepth": info.get("seldepth"),
        "multipv": info.get("multipv", 1),
        "nodes": info.get("nodes"),
        "nps": info.get("nps"),
        "timeMs": info.get("time"),
        "pv": info.get("pv", []),
        "scoreKind": None if score is None else score.get("type"),
        "scoreValue": None if score is None else score.get("value"),
        "boundKind": "exact" if bound is None else ("lowerbound" if bound == "lower" else "upperbound"),
    }


def selected_primary(search: dict[str, Any]) -> dict[str, Any] | None:
    snapshot = search.get("selectedSnapshot") or []
    return snapshot[0] if snapshot else None


def score_from_export(line: dict[str, Any] | None) -> dict[str, Any] | None:
    if not line or line.get("scoreKind") is None:
        return None
    return {"type": line["scoreKind"], "value": line["scoreValue"]}


def expected_loss(best_search: dict[str, Any], actual_search: dict[str, Any]) -> float | None:
    best = score_from_export(selected_primary(best_search))
    actual = score_from_export(selected_primary(actual_search))
    if not best or not actual or best["type"] != "cp" or actual["type"] != "cp":
        return None
    return contract.expected_score(best["value"]) - contract.expected_score(actual["value"])


def snapshot_evidence_status(snapshot: list[dict[str, Any]], required_multipv: int) -> str:
    if len(snapshot) != required_multipv:
        return "INSUFFICIENT_NO_COMPLETED_EXACT_SNAPSHOT"
    root_moves = [line.get("pv", [None])[0] if line.get("pv") else None for line in snapshot]
    if any(move is None for move in root_moves):
        return "INSUFFICIENT_MISSING_ROOT_MOVE"
    if len(set(root_moves)) != required_multipv:
        return "INSUFFICIENT_DUPLICATE_ROOT_MOVE"
    node_cohort = {line.get("nodes") for line in snapshot}
    if None in node_cohort or len(node_cohort) != 1:
        return "INSUFFICIENT_MIXED_ITERATION_COHORT"
    return "RESOLVED"


def terminal_iteration_state(observations: list[dict[str, Any]], required_multipv: int) -> dict[str, Any]:
    scored = [x for x in observations if x.get("depth") is not None and isinstance(x.get("score"), dict)]
    if not scored:
        return {"depth": None, "ranksObserved": [], "hasBound": None, "completeRanksObserved": False}
    depth = max(int(x["depth"]) for x in scored)
    at_depth = [x for x in scored if int(x["depth"]) == depth and 1 <= int(x.get("multipv", 1)) <= required_multipv]
    ranks = sorted({int(x.get("multipv", 1)) for x in at_depth})
    return {
        "depth": depth,
        "ranksObserved": ranks,
        "hasBound": any(x["score"].get("bound") is not None for x in at_depth),
        "completeRanksObserved": ranks == list(range(1, required_multipv + 1)),
    }


class PilotUSIEngine:
    def __init__(self, work: Path, hash_mb: int):
        self.work = work
        engine = (work / "engine").resolve()
        eval_dir = (work / "eval").resolve()
        if not engine.exists() or not (eval_dir / "nn.bin").exists():
            raise contract.PilotError("engine_or_nnue_missing")
        self.proc = subprocess.Popen(
            [str(engine)], stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, bufsize=1, cwd=str(work),
        )
        self.lines: queue.Queue[str | None] = queue.Queue()
        assert self.proc.stdout is not None

        def reader() -> None:
            assert self.proc.stdout is not None
            for line in self.proc.stdout:
                self.lines.put(line.rstrip("\r\n"))
            self.lines.put(None)

        self.reader = threading.Thread(target=reader, daemon=True)
        self.reader.start()
        self.current_multipv = 3
        self.tt_generation = 0
        self.send("usi")
        usi = self.read_until(lambda x: x == "usiok")
        options = {
            line.split(" name ", 1)[1].split(" type ", 1)[0]
            for line in usi if line.startswith("option name ") and " type " in line
        }
        for name in ("Threads", "USI_Hash", "MultiPV", "FV_SCALE", "PvInterval", "EvalDir"):
            if name not in options:
                raise contract.PilotError(f"engine_option_missing:{name}")
        for name, value in (
            ("Threads", 1), ("USI_Hash", hash_mb), ("MultiPV", 3),
            ("FV_SCALE", 24), ("PvInterval", 0), ("BookFile", "no_book"),
            ("EvalDir", str(eval_dir)),
        ):
            self.send(f"setoption name {name} value {value}")
        self.send("isready")
        self.read_until(lambda x: x == "readyok")
        self.tt_generation = 1
        self.send("usinewgame")

    def send(self, command: str) -> None:
        if self.proc.stdin is None:
            raise contract.PilotError("engine_stdin_closed")
        self.proc.stdin.write(command + "\n")
        self.proc.stdin.flush()

    def readline(self, timeout: float) -> str:
        try:
            line = self.lines.get(timeout=timeout)
        except queue.Empty as exc:
            raise contract.PilotError("engine_read_timeout") from exc
        if line is None:
            raise contract.PilotError("engine_closed")
        return line

    def read_until(self, predicate) -> list[str]:
        deadline = time.monotonic() + SEARCH_TIMEOUT_SECONDS
        result: list[str] = []
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise contract.PilotError("engine_protocol_timeout")
            line = self.readline(remaining)
            result.append(line)
            if "illegal input move" in line.lower():
                raise contract.PilotError(f"illegal_input_move:{line}")
            if predicate(line):
                return result

    def reset_cold(self) -> int:
        self.send("isready")
        self.read_until(lambda x: x == "readyok")
        self.tt_generation += 1
        self.send("usinewgame")
        return self.tt_generation

    def search(self, position: str, nodes: int, multipv: int, searchmoves: list[str], role: str, log: Path) -> dict[str, Any]:
        tt = self.reset_cold()
        transcript: list[str] = []
        if multipv != self.current_multipv:
            cmd = f"setoption name MultiPV value {multipv}"
            self.send(cmd); transcript.append("> " + cmd)
            self.current_multipv = multipv
        self.send(position); transcript.append("> " + position)
        clause = "" if not searchmoves else " searchmoves " + " ".join(searchmoves)
        go = f"go nodes {nodes}{clause}"
        self.send(go); transcript.append("> " + go)
        started = time.monotonic()
        raw = self.read_until(lambda x: x.startswith("bestmove "))
        elapsed_ms = int(round((time.monotonic() - started) * 1000))
        transcript.extend(raw)
        log.parent.mkdir(parents=True, exist_ok=True)
        log.write_text("\n".join(transcript) + "\n", encoding="utf-8")
        obs = contract.parse_raw_usi_lines(raw)
        snap = contract.deepest_exact_snapshot(obs, multipv)
        scored = [x for x in obs if isinstance(x.get("score"), dict)]
        exported_snapshot = [] if snap is None else [export_observation(x) for x in snap]
        terminal = terminal_iteration_state(obs, multipv)
        evidence_status = snapshot_evidence_status(exported_snapshot, multipv)
        return {
            "role": role, "nodeBudget": nodes, "multiPV": multipv,
            "searchMoves": searchmoves, "goCommand": go, "ttGeneration": tt,
            "elapsedMs": elapsed_ms,
            "bestmove": next((x.split()[1] for x in reversed(raw) if x.startswith("bestmove ")), None),
            "maxObservedNodes": max((int(x.get("nodes") or 0) for x in obs), default=0),
            "terminalLastInfoBound": None if not scored else scored[-1]["score"].get("bound") is not None,
            "terminalIteration": terminal,
            "hasCompletedExactIteration": snap is not None,
            "selectedSnapshotEvidenceStatus": evidence_status,
            "completedExactRecoveredAfterTerminalBound": bool(terminal["hasBound"] and snap is not None),
            "selectedSnapshot": exported_snapshot,
            "observations": [export_observation(x) for x in obs],
            "rawLogPath": str(log),
        }

    def close(self) -> None:
        try: self.send("quit")
        except Exception: pass
        try: self.proc.wait(timeout=10)
        except Exception:
            self.proc.kill(); self.proc.wait(timeout=5)
        self.reader.join(timeout=1)


def comparison_inversion(recommended: str, actual: str, best: dict[str, Any], played: dict[str, Any]) -> bool | None:
    if recommended == actual:
        return False
    a = score_from_export(selected_primary(best)); b = score_from_export(selected_primary(played))
    if not a or not b:
        return None
    return score_order_key(b) > score_order_key(a)


def run_app(engine: PilotUSIEngine, pos: dict[str, Any], out: Path) -> dict[str, Any]:
    pid, command, actual = pos["position_id"], pos["position_command"], pos["actual_move"]
    discoveries = [engine.search(command, n, 3, [], f"app_discovery_{n}", out / "raw" / pid / f"app-discovery-{n}.log") for n in APP_NODE_TIERS]
    primary = selected_primary(discoveries[-1])
    if not primary or not primary.get("pv"):
        raise contract.PilotError(f"app_no_exact_deepest_discovery:{pid}")
    recommended = primary["pv"][0]
    comparisons = []
    for n in APP_NODE_TIERS:
        best = engine.search(command, n, 1, [recommended], f"app_best_{n}", out / "raw" / pid / f"app-best-{n}.log")
        played = engine.search(command, n, 1, [actual], f"app_actual_{n}", out / "raw" / pid / f"app-actual-{n}.log")
        comparisons.append({
            "nodeBudget": n, "recommendedMove": recommended, "actualMove": actual,
            "comparisonInversion": comparison_inversion(recommended, actual, best, played),
            "expectedLoss": expected_loss(best, played), "bestSearch": best, "actualSearch": played,
        })
    return {
        "recommendedMove": recommended, "actualMove": actual,
        "candidateStructureEvidenceStatus": discoveries[-1]["selectedSnapshotEvidenceStatus"],
        "discoveries": discoveries, "comparisons": comparisons,
    }


def run_reference(engine: PilotUSIEngine, pos: dict[str, Any], out: Path) -> dict[str, Any]:
    pid, command, actual = pos["position_id"], pos["position_command"], pos["actual_move"]
    budgets = []
    for n in REFERENCE_NODE_BUDGETS:
        root = engine.search(command, n, 3, [], f"reference_root_{n}", out / "raw" / pid / f"reference-root-{n}.log")
        primary = selected_primary(root)
        if not primary or not primary.get("pv"):
            budgets.append({"nodeBudget": n, "status": "INSUFFICIENT", "root": root}); continue
        rank1 = primary["pv"][0]
        best = engine.search(command, n, 1, [rank1], f"reference_best_{n}", out / "raw" / pid / f"reference-best-{n}.log")
        played = engine.search(command, n, 1, [actual], f"reference_actual_{n}", out / "raw" / pid / f"reference-actual-{n}.log")
        played_status = (
            "RESOLVED"
            if best["selectedSnapshotEvidenceStatus"] == "RESOLVED" and played["selectedSnapshotEvidenceStatus"] == "RESOLVED"
            else "INSUFFICIENT"
        )
        structure_status = (
            "RESOLVED" if root["selectedSnapshotEvidenceStatus"] == "RESOLVED" else root["selectedSnapshotEvidenceStatus"]
        )
        budgets.append({
            "nodeBudget": n, "rank1Move": rank1, "actualMove": actual,
            "status": "RESOLVED" if structure_status == "RESOLVED" and played_status == "RESOLVED" else "INSUFFICIENT",
            "structureStatus": structure_status, "playedStatus": played_status,
            "root": root, "bestSearch": best, "actualSearch": played, "expectedLossActual": expected_loss(best, played),
        })
    return {"actualMove": actual, "budgets": budgets}


def validate_setup(work: Path) -> dict[str, Any]:
    provenance = contract.load_json(work / "provenance.json")
    if provenance.get("engine_commit") != EXPECTED_ENGINE_PIN:
        raise contract.PilotError("engine_pin_mismatch")
    if provenance.get("nnue_sha256") != EXPECTED_NNUE_SHA256:
        raise contract.PilotError("nnue_sha_mismatch")
    if sha256_file((work / "engine").resolve()) != provenance.get("engine_sha256"):
        raise contract.PilotError("engine_binary_sha_mismatch")
    if sha256_file(work / "eval" / "nn.bin") != EXPECTED_NNUE_SHA256:
        raise contract.PilotError("nnue_file_sha_mismatch")
    return provenance


def run_positions(positions: list[dict[str, Any]], work: Path, out: Path, run_kind: str) -> dict[str, Any]:
    out.mkdir(parents=True, exist_ok=True)
    result: dict[str, Any] = {
        "schema_version": contract.PILOT_RESULT_SCHEMA, "run_kind": run_kind,
        "authority_commit": contract.AUTHORITY_COMMIT, "repository_head": os.environ.get("GITHUB_SHA"),
        "started_at": utc_now(),
        "runtime": {"os": platform.platform(), "machine": platform.machine(), "python": platform.python_version()},
        "engine_setup_provenance": validate_setup(work), "positions": [], "f_cases": [], "e_cases": [],
    }
    app = PilotUSIEngine(work, APP_HASH_MB); ref = PilotUSIEngine(work, REFERENCE_HASH_MB)
    try:
        for i, source in enumerate(positions):
            pos = dict(source); pos.setdefault("position_id", f"p{i+1:02d}-ply-{pos.get('ply', 'x')}")
            result["positions"].append({
                "position_id": pos["position_id"], "game_sha256": pos.get("game_sha256"), "ply": pos.get("ply"),
                "position_command": pos["position_command"], "actual_move": pos["actual_move"],
                "app": run_app(app, pos, out), "reference": run_reference(ref, pos, out),
            })
    finally:
        app.close(); ref.close()
    result["ended_at"] = utc_now()
    result["result_sha256"] = contract.sha256_text(contract.canonical_json(result))
    contract.write_json(out / "pilot-result.json", result)
    return result


def controls() -> list[dict[str, Any]]:
    return [
        {"position_id": "control-startpos", "position_command": "position startpos", "actual_move": "7g7f"},
        {"position_id": "control-c1-sfen", "position_command": "position sfen lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8", "actual_move": "2b7g+"},
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="VE1-C1 frozen App/Reference pilot executor")
    parser.add_argument("mode", choices=("controls", "manifest"))
    parser.add_argument("--work", required=True); parser.add_argument("--out", required=True); parser.add_argument("--manifest")
    args = parser.parse_args()
    try:
        if args.mode == "controls":
            positions, kind = controls(), "diagnostic_controls"
        else:
            if not args.manifest: raise contract.PilotError("manifest_required")
            manifest = contract.load_json(Path(args.manifest))
            if manifest.get("schema_version") != contract.MANIFEST_SCHEMA or manifest.get("authority_commit") != contract.AUTHORITY_COMMIT:
                raise contract.PilotError("manifest_contract_mismatch")
            positions = manifest.get("selected_positions")
            if not isinstance(positions, list) or len(positions) != contract.PILOT_TARGET:
                raise contract.PilotError("manifest_must_contain_16_positions")
            kind = "excluded_natural_pilot"
        result = run_positions(positions, Path(args.work), Path(args.out), kind)
        print(json.dumps({"status": "PASS", "positions": len(result["positions"]), "result_sha256": result["result_sha256"]}, sort_keys=True))
        return 0
    except contract.PilotError as exc:
        print(json.dumps({"status": "FAIL", "error": str(exc)}, sort_keys=True))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
