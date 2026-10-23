#!/usr/bin/env python3
import argparse
import json
import subprocess
import tempfile
from pathlib import Path


def run(engine: Path, fixture_path: Path, output: Path) -> None:
    fixture = json.loads(fixture_path.read_text(encoding="utf-8"))
    rows = fixture["fixtures"]

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as handle:
        tmp = Path(handle.name)
        for index, item in enumerate(rows, start=1):
            handle.write(f"{index}\t{item['position_command']}\n")

    try:
        completed = subprocess.run(
            [str(engine), "ve1b_legal_audit", str(tmp)],
            text=True,
            capture_output=True,
            check=False,
        )
    finally:
        tmp.unlink(missing_ok=True)

    if completed.returncode != 0:
        raise SystemExit(
            f"audit engine failed rc={completed.returncode}\nstdout:\n{completed.stdout}\nstderr:\n{completed.stderr}"
        )

    parsed = {}
    for line in completed.stdout.splitlines():
        if not line.startswith("VE1B\t"):
            continue
        fields = line.split("\t", 4)
        if len(fields) != 5:
            raise SystemExit(f"malformed audit line: {line}")
        _, ordinal, legal, legal_all, moves = fields
        parsed[int(ordinal)] = {
            "legalRootMoveCount": int(legal),
            "legalAllMoveCount": int(legal_all),
            "legalAllMoves": [x for x in moves.split(" ") if x],
        }

    if len(parsed) != len(rows):
        raise SystemExit(f"expected {len(rows)} audit rows, observed {len(parsed)}")

    report_rows = []
    failures = []
    configured = fixture["configured_multi_pv"]
    for ordinal, item in enumerate(rows, start=1):
        observed = parsed[ordinal]
        effective = min(configured, observed["legalRootMoveCount"])
        checks = {
            "legalRootMoveCount": observed["legalRootMoveCount"] == item["expected_legal_root_move_count"],
            "legalAllMoveCount": observed["legalAllMoveCount"] == item["expected_legal_all_move_count"],
            "effectiveRequiredMultiPV": effective == item["expected_effective_required_multi_pv"],
        }
        omitted = item.get("required_omitted_nonpromotion_move")
        retained = item.get("required_retained_promotion_move")
        if omitted is not None:
            checks["omittedMovePresentInLegalAll"] = omitted in observed["legalAllMoves"]
        if retained is not None:
            checks["retainedMovePresentInLegalAll"] = retained in observed["legalAllMoves"]

        parity = all(checks.values())
        if not parity:
            failures.append(item["id"])
        report_rows.append(
            {
                "id": item["id"],
                "positionCommand": item["position_command"],
                "configuredMultiPV": configured,
                "legalRootMoveCount": observed["legalRootMoveCount"],
                "legalAllMoveCount": observed["legalAllMoveCount"],
                "effectiveRequiredMultiPV": effective,
                "legalAllMoves": observed["legalAllMoves"],
                "checks": checks,
                "parity": parity,
            }
        )

    report = {
        "status": "PASS" if not failures else "FAIL",
        "authorityParent": fixture["authority_parent"],
        "rootMoveGenerator": fixture["root_move_generator"],
        "fixtureCount": len(rows),
        "failedFixtures": failures,
        "fixtures": report_rows,
        "engineStdErr": completed.stderr,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if failures:
        raise SystemExit(f"fixture root validation failed: {failures}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--engine", required=True, type=Path)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    run(args.engine, args.fixture, args.output)


if __name__ == "__main__":
    main()
