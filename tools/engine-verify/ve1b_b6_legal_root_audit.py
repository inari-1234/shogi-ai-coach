#!/usr/bin/env python3
import argparse
import hashlib
import json
import queue
import subprocess
import sys
import threading
from pathlib import Path

AUTHORITY_BASE = "8daf78caa2bd5919cc911da21bae80fa3d12a248"
ENGINE_COMMIT = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"
COUNT_PREFIX = "info string ve1b_legal_move_count "
ALL_PREFIX = "info string ve1b_legal_all_moves"
_EOF = object()


def canonical_sha256(value):
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


class EngineProcess:
    def __init__(self, executable: Path):
        self.proc = subprocess.Popen(
            [str(executable)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            bufsize=1,
        )
        assert self.proc.stdin is not None
        assert self.proc.stdout is not None
        self.lines = queue.Queue()
        self.transcript = []
        self.reader = threading.Thread(target=self._drain_stdout, daemon=True)
        self.reader.start()

    def _drain_stdout(self):
        try:
            for raw in self.proc.stdout:
                self.lines.put(raw.rstrip("\r\n"))
        finally:
            self.lines.put(_EOF)

    def send(self, command: str):
        self.transcript.append(f"> {command}")
        self.proc.stdin.write(command + "\n")
        self.proc.stdin.flush()

    def read_until(self, predicate, timeout: float, label: str):
        while True:
            try:
                item = self.lines.get(timeout=timeout)
            except queue.Empty as exc:
                raise RuntimeError(f"timeout waiting for {label}") from exc
            if item is _EOF:
                try:
                    return_code = self.proc.wait(timeout=1)
                except subprocess.TimeoutExpired:
                    return_code = self.proc.poll()
                raise RuntimeError(
                    f"engine EOF while waiting for {label}; returncode={return_code}"
                )
            line = item
            self.transcript.append(line)
            if predicate(line):
                return line

    def close(self):
        if self.proc.poll() is None:
            try:
                self.send("quit")
            except Exception:
                pass
            try:
                self.proc.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.proc.kill()
                self.proc.wait(timeout=5)
        self.reader.join(timeout=1)


def validate_input(data):
    expected = data.get("input_sha256")
    body = dict(data)
    body.pop("input_sha256", None)
    actual = canonical_sha256(body)
    if actual != expected:
        raise ValueError(f"input SHA mismatch: {actual} != {expected}")
    if data.get("authority_base") != AUTHORITY_BASE:
        raise ValueError("authority_base mismatch")
    if data.get("unique_position_count") != 9 or len(data.get("positions", [])) != 9:
        raise ValueError("expected exactly 9 unique B6 positions")
    if data.get("standard_attempt_count") != 315:
        raise ValueError("standard attempt count mismatch")
    if data.get("stress_attempt_count") != 189:
        raise ValueError("stress attempt count mismatch")
    if data.get("total_attempt_count") != 504:
        raise ValueError("total attempt count mismatch")
    if sum(p["total_attempt_count"] for p in data["positions"]) != 504:
        raise ValueError("position attempt mapping does not sum to 504")


def initialize_engine(engine: EngineProcess):
    engine.send("usi")
    engine.read_until(lambda line: line == "usiok", 10, "usiok")

    # Match the production VE1-B runtime contract before touching positions.
    # In pinned YaneuraOu, isready performs thread/TT/search-manager/book
    # initialization, so bypassing it is not a valid audit lifecycle.
    for command in (
        "setoption name Threads value 1",
        "setoption name USI_Hash value 64",
        "setoption name MultiPV value 3",
        "setoption name GenerateAllLegalMoves value false",
        "setoption name FV_SCALE value 24",
        "setoption name PvInterval value 0",
        "setoption name BookFile value no_book",
    ):
        engine.send(command)

    engine.send("isready")
    engine.read_until(lambda line: line == "readyok", 30, "readyok")
    engine.send("usinewgame")


def audit(engine_path: Path, input_data, transcript_path: Path):
    engine = EngineProcess(engine_path)
    try:
        initialize_engine(engine)

        results = []
        for item in sorted(input_data["positions"], key=lambda value: value["ply"]):
            engine.send(item["position_command"])

            engine.send("ve1b_legal_move_count")
            count_line = engine.read_until(
                lambda line: line.startswith(COUNT_PREFIX),
                5,
                f"LEGAL count ply {item['ply']}",
            )
            legal_count = int(count_line[len(COUNT_PREFIX):].strip())

            engine.send("ve1b_legal_all_moves")
            all_line = engine.read_until(
                lambda line: line.startswith(ALL_PREFIX),
                5,
                f"LEGAL_ALL moves ply {item['ply']}",
            )
            suffix = all_line[len(ALL_PREFIX):].strip()
            legal_all_moves = suffix.split() if suffix else []

            results.append(
                {
                    "ply": item["ply"],
                    "positionCommand": item["position_command"],
                    "legalRootMoveCount": legal_count,
                    "legalAllRootMoveCount": len(legal_all_moves),
                    "legalAllMoves": legal_all_moves,
                    "standardAttemptCount": item["standard_attempt_count"],
                    "stressAttemptCount": item["stress_attempt_count"],
                    "totalAttemptCount": item["total_attempt_count"],
                    "affectedAttemptCount": item["total_attempt_count"] if legal_count < 3 else 0,
                }
            )

        affected_standard = sum(
            p["standardAttemptCount"] for p in results if p["legalRootMoveCount"] < 3
        )
        affected_stress = sum(
            p["stressAttemptCount"] for p in results if p["legalRootMoveCount"] < 3
        )
        minimum = min(p["legalRootMoveCount"] for p in results)
        reasons = [
            f"PLY_{p['ply']}_LEGAL_ROOT_COUNT_{p['legalRootMoveCount']}_AFFECTS_{p['totalAttemptCount']}_ATTEMPTS"
            for p in results
            if p["legalRootMoveCount"] < 3
        ]
        return {
            "schemaVersion": 2,
            "status": "PASS" if not reasons else "FAIL",
            "authorityBase": AUTHORITY_BASE,
            "engineCommit": ENGINE_COMMIT,
            "inputSHA256": input_data["input_sha256"],
            "rootMoveGenerator": "YaneuraOu MoveList<LEGAL>",
            "crosscheckUniverse": "YaneuraOu MoveList<LEGAL_ALL>",
            "generateAllLegalMoves": False,
            "runtimeContract": {
                "threads": 1,
                "hashMB": 64,
                "configuredMultiPV": 3,
                "fvScale": 24,
                "pvIntervalMs": 0,
                "bookFile": "no_book",
            },
            "uniquePositionCount": len(results),
            "standardAttemptCount": input_data["standard_attempt_count"],
            "stressAttemptCount": input_data["stress_attempt_count"],
            "totalAttemptCount": input_data["total_attempt_count"],
            "affectedStandardAttemptCount": affected_standard,
            "affectedStressAttemptCount": affected_stress,
            "affectedTotalAttemptCount": affected_standard + affected_stress,
            "minimumLegalRootMoveCount": minimum,
            "positions": results,
            "failureReasons": reasons,
        }
    finally:
        engine.close()
        transcript_path.write_text("\n".join(engine.transcript) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--transcript", required=True, type=Path)
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.transcript.parent.mkdir(parents=True, exist_ok=True)

    if not args.engine.is_file():
        raise SystemExit(f"engine not found: {args.engine}")
    data = json.loads(args.input.read_text(encoding="utf-8"))
    validate_input(data)

    try:
        report = audit(args.engine, data, args.transcript)
    except Exception as exc:
        (args.output.parent / "error.txt").write_text(
            f"{type(exc).__name__}: {exc}\n",
            encoding="utf-8",
        )
        raise

    args.output.write_text(
        json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    print(json.dumps({
        "status": report["status"],
        "minimumLegalRootMoveCount": report["minimumLegalRootMoveCount"],
        "affectedTotalAttemptCount": report["affectedTotalAttemptCount"],
    }, sort_keys=True))
    return 0 if report["status"] == "PASS" else 2


if __name__ == "__main__":
    sys.exit(main())
