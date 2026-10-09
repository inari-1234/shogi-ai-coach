#!/usr/bin/env python3
"""Build19-VE1-A audit for score/cp dependencies affected by FV_SCALE 16 -> 24.

This is an inventory gate, not a semantic migration. It identifies production thresholds
for explicit review and keeps historical/test fixtures separate so values are never
silently rewritten merely because the engine scale changed.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = ROOT / "build"
OUTPUT_JSON = OUTPUT_DIR / "ve1a-cp-impact.json"
OUTPUT_MD = OUTPUT_DIR / "ve1a-cp-impact.md"

SCAN_ROOTS = [
    ROOT / "Sources" / "ShogiCoachCore",
    ROOT / "iOS" / "ShogiCoachPoC",
    ROOT / "Tests" / "ShogiCoachCoreTests",
    ROOT / "Build17",
    ROOT / "Build18",
]
TEXT_SUFFIXES = {".swift", ".md", ".json", ".py", ".yml", ".yaml", ".txt"}
SIGNAL = re.compile(
    r"(?i)(centipawn|\bcp\b|Cp\b|scoreText|scoreCp|lossCp|gapCp|blackPerspectiveCp|"
    r"estimatedLoss|actualLoss|topCandidateGap|threshold|score\b)"
)
NUMERIC = re.compile(r"(?<![A-Za-z_])-?\d{2,6}(?![A-Za-z_])")
COMPARISON = re.compile(r"(?:<=|>=|==|!=|<|>)")


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def classify(path_text: str, line: str) -> str:
    if path_text.startswith("Build17/") or path_text.startswith("Build18/"):
        return "historical_record"
    if path_text.startswith("Tests/"):
        return "test_fixture"
    if path_text.endswith("SimulatorCIProbe.swift"):
        return "historical_diagnostic_fixture"
    if path_text.endswith("EngineRuntimeVerification.swift"):
        return "ve1a_runtime_authority"
    if path_text.startswith("Sources/") or path_text.startswith("iOS/"):
        if NUMERIC.search(line) and (COMPARISON.search(line) or "threshold" in line.lower()):
            return "production_threshold_review"
        if NUMERIC.search(line) and SIGNAL.search(line):
            return "production_numeric_review"
        return "production_score_dataflow"
    return "other"


def main() -> int:
    records: list[dict[str, object]] = []
    files_scanned = 0

    for scan_root in SCAN_ROOTS:
        if not scan_root.exists():
            continue
        for path in sorted(scan_root.rglob("*")):
            if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
                continue
            if "/eval/" in path.as_posix():
                continue
            files_scanned += 1
            try:
                lines = path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            path_text = rel(path)
            for line_no, line in enumerate(lines, 1):
                if not SIGNAL.search(line):
                    continue
                records.append(
                    {
                        "path": path_text,
                        "line": line_no,
                        "classification": classify(path_text, line),
                        "text": line.strip()[:400],
                    }
                )

    counts: dict[str, int] = {}
    for record in records:
        key = str(record["classification"])
        counts[key] = counts.get(key, 0) + 1

    engine_session = (ROOT / "iOS" / "ShogiCoachPoC" / "EngineUSISession.swift").read_text(
        encoding="utf-8"
    )
    runtime_authority = (
        ROOT / "iOS" / "ShogiCoachPoC" / "EngineRuntimeVerification.swift"
    ).read_text(encoding="utf-8")

    static_assertions = {
        "production_sends_fv_scale_authority": (
            'setoption name FV_SCALE value \\(EngineRuntimeAuthority.fvScale)' in engine_session
        ),
        "authority_is_24": "static let fvScale = 24" in runtime_authority,
        "c1_expected_cp_is_108": "static let c1ExpectedCp = 108" in runtime_authority,
        "c1_expected_bestmove_is_7g7f": (
            'static let c1ExpectedBestMove = "7g7f"' in runtime_authority
        ),
        "nnue_authority_present": (
            "768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"
            in runtime_authority
        ),
        "production_does_not_send_fv16": "setoption name FV_SCALE value 16" not in engine_session,
    }

    payload = {
        "schema": "build19-ve1-a-cp-impact-v1",
        "files_scanned": files_scanned,
        "records": records,
        "counts": counts,
        "static_assertions": static_assertions,
        "policy": {
            "historical_values": "do_not_rescale_silently",
            "production_thresholds": "explicit_review_required",
            "semantic_authority": "not_created_by_this_audit",
        },
    }

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_JSON.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    review_records = [
        record
        for record in records
        if str(record["classification"]).startswith("production_")
        and str(record["classification"]) != "production_score_dataflow"
    ]
    md = [
        "# Build19-VE1-A cp / score impact inventory",
        "",
        f"- Files scanned: {files_scanned}",
        f"- Signal records: {len(records)}",
        f"- Production numeric/threshold review records: {len(review_records)}",
        "- Historical Build17/18 and simulator fixtures are inventory only; values are not rescaled.",
        "- This audit does not establish Semantic Authority.",
        "",
        "## Static assertions",
        "",
    ]
    for name, passed in static_assertions.items():
        md.append(f"- {'PASS' if passed else 'FAIL'} — `{name}`")
    md.extend(["", "## Production review inventory", ""])
    for record in review_records:
        md.append(
            f"- `{record['path']}:{record['line']}` [{record['classification']}] "
            f"`{record['text']}`"
        )
    OUTPUT_MD.write_text("\n".join(md) + "\n", encoding="utf-8")

    print(f"ve1a_cp_impact_files={files_scanned}")
    print(f"ve1a_cp_impact_records={len(records)}")
    print(f"ve1a_cp_impact_production_review={len(review_records)}")
    for record in review_records:
        print(
            "VE1A_REVIEW "
            f"{record['path']}:{record['line']} "
            f"[{record['classification']}] {record['text']}"
        )

    failed = [name for name, passed in static_assertions.items() if not passed]
    if failed:
        print("VE1A_STATIC_ASSERTION_FAIL=" + ",".join(failed))
        return 1
    print("ve1a_cp_impact_static=PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
