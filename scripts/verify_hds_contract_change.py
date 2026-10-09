#!/usr/bin/env python3
import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

FIXTURE = Path("tools/engine-verify/fixtures/build19-hds-41-49-69.json")
PROBE = Path("iOS/ShogiCoachPoC/SimulatorCIProbe.swift")
WORKFLOW = Path(".github/workflows/ios-simulator.yml")


def fail(message: str) -> None:
    print(f"hds_contract_guard=FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def plies_from_document(text: str, source: str) -> list[int]:
    try:
        doc = json.loads(text)
        plies = [int(item["ply"]) for item in doc["positions"]]
    except Exception as exc:
        fail(f"cannot parse canonical plies from {source}: {exc}")
    if not plies or len(set(plies)) != len(plies):
        fail(f"canonical plies must be non-empty and unique in {source}")
    return plies


def git_text(ref: str, path: Path) -> str | None:
    completed = subprocess.run(
        ["git", "show", f"{ref}:{path.as_posix()}"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    return completed.stdout if completed.returncode == 0 else None


def git_changed_files(base: str) -> set[str]:
    completed = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...HEAD"],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    return {line.strip() for line in completed.stdout.splitlines() if line.strip()}


def verify_surfaces(plies: list[int]) -> None:
    compact = ",".join(str(p) for p in plies)
    swift_list = "[" + ", ".join(str(p) for p in plies) + "]"
    probe = PROBE.read_text(encoding="utf-8")
    workflow = WORKFLOW.read_text(encoding="utf-8")

    required_probe = [
        f"hdsPlies == {swift_list}",
        f"hdsContinuation.entries.map(\\.ply) == {swift_list}",
    ]
    for needle in required_probe:
        if needle not in probe:
            fail(f"SimulatorCIProbe contract surface does not match fixture: {needle}")

    if f'hds_m_positions={compact}' not in workflow:
        fail("ios-simulator result assertion does not match canonical fixture")

    normalized = re.sub(r"\s+", "", workflow)
    expected_json_assert = (
        'assert[p["ply"]forpinpositions]=='
        + "[" + ",".join(str(p) for p in plies) + "]"
    )
    if expected_json_assert not in normalized:
        fail("ios-simulator JSON position assertion does not match canonical fixture")


def verify_change_evidence(base: str, previous: list[int], current: list[int]) -> None:
    changed = git_changed_files(base)
    candidates = sorted(Path("Build19").glob("HDS_CONTRACT_CHANGE_EVIDENCE_*.json"))
    candidates = [p for p in candidates if p.as_posix() in changed]
    if not candidates:
        fail("canonical plies changed without a changed HDS contract evidence record")

    for path in candidates:
        try:
            doc = json.loads(path.read_text(encoding="utf-8"))
        except Exception as exc:
            print(f"hds_contract_guard=INFO invalid evidence {path}: {exc}")
            continue
        if (
            doc.get("schema") == "HDS-CONTRACT-CHANGE-EVIDENCE-1.0"
            and doc.get("contract") == "HDS-M_REAL_POSITION_SELECTION"
            and doc.get("previousPlies") == previous
            and doc.get("newPlies") == current
            and doc.get("authorityStatus") == "REGRESSION_CONTRACT_ONLY"
            and isinstance(doc.get("rationale"), str)
            and bool(doc["rationale"].strip())
            and isinstance(doc.get("evidence"), list)
            and bool(doc["evidence"])
            and doc.get("reviewStatus") == "APPROVED"
        ):
            print(f"hds_contract_evidence={path}")
            return
    fail("no changed evidence record satisfies the HDS contract evidence policy")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="")
    args = parser.parse_args()

    current_text = FIXTURE.read_text(encoding="utf-8")
    current = plies_from_document(current_text, FIXTURE.as_posix())
    verify_surfaces(current)

    base = args.base.strip()
    if base and set(base) != {"0"}:
        previous_text = git_text(base, FIXTURE)
        if previous_text is not None:
            previous = plies_from_document(previous_text, f"{base}:{FIXTURE}")
            if previous != current:
                verify_change_evidence(base, previous, current)

    print("hds_contract_guard=PASS")
    print("hds_contract_plies=" + ",".join(str(p) for p in current))
    print("hds_contract_authority=REGRESSION_CONTRACT_ONLY")


if __name__ == "__main__":
    main()
