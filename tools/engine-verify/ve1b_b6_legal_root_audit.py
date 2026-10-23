#!/usr/bin/env python3
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

AUTHORITY_BASE = "8daf78caa2bd5919cc911da21bae80fa3d12a248"
ENGINE_COMMIT = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"


def canonical_sha256(value):
    payload = json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


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


def run_direct_audit(engine_path: Path, input_data, workdir: Path):
    audit_input = workdir / "native-audit-input.tsv"
    audit_input.write_text(
        "".join(
            f"{item['ply']}\t{item['position_command']}\n"
            for item in sorted(input_data["positions"], key=lambda value: value["ply"])
        ),
        encoding="utf-8",
    )

    proc = subprocess.run(
        [str(engine_path), "--ve1b-legal-audit", str(audit_input)],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    transcript = proc.stdout
    (workdir / "native-transcript.txt").write_text(transcript, encoding="utf-8")
    if proc.returncode != 0:
        raise RuntimeError(
            f"direct engine audit failed: returncode={proc.returncode}"
        )

    parsed = {}
    for line in transcript.splitlines():
        if not line.startswith("VE1B\t"):
            continue
        fields = line.split("\t", 4)
        if len(fields) != 5:
            raise RuntimeError(f"malformed audit row: {line}")
        _, ply_text, legal_text, legal_all_text, moves_text = fields
        ply = int(ply_text)
        if ply in parsed:
            raise RuntimeError(f"duplicate audit ply: {ply}")
        moves = moves_text.split() if moves_text else []
        legal_all_count = int(legal_all_text)
        if legal_all_count != len(moves):
            raise RuntimeError(
                f"LEGAL_ALL payload mismatch at ply {ply}: {legal_all_count} != {len(moves)}"
            )
        parsed[ply] = {
            "legalRootMoveCount": int(legal_text),
            "legalAllRootMoveCount": legal_all_count,
            "legalAllMoves": moves,
        }

    if len(parsed) != 9:
        raise RuntimeError(f"expected 9 audit rows, got {len(parsed)}")
    return parsed


def build_report(input_data, parsed):
    results = []
    for item in sorted(input_data["positions"], key=lambda value: value["ply"]):
        measured = parsed.get(item["ply"])
        if measured is None:
            raise RuntimeError(f"missing audit ply: {item['ply']}")
        legal_count = measured["legalRootMoveCount"]
        results.append(
            {
                "ply": item["ply"],
                "positionCommand": item["position_command"],
                "legalRootMoveCount": legal_count,
                "legalAllRootMoveCount": measured["legalAllRootMoveCount"],
                "legalAllMoves": measured["legalAllMoves"],
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
        "schemaVersion": 3,
        "status": "PASS" if not reasons else "FAIL",
        "authorityBase": AUTHORITY_BASE,
        "engineCommit": ENGINE_COMMIT,
        "inputSHA256": input_data["input_sha256"],
        "measurementPath": "direct C++ Position + MoveList; no USI loop; no NNUE/eval load",
        "rootMoveGenerator": "YaneuraOu MoveList<LEGAL>",
        "crosscheckUniverse": "YaneuraOu MoveList<LEGAL_ALL>",
        "generateAllLegalMoves": False,
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
        parsed = run_direct_audit(args.engine, data, args.output.parent)
        default_transcript = args.output.parent / "native-transcript.txt"
        if default_transcript != args.transcript:
            args.transcript.write_text(default_transcript.read_text(encoding="utf-8"), encoding="utf-8")
        report = build_report(data, parsed)
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
