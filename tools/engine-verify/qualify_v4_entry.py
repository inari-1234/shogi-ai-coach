#!/usr/bin/env python3
"""Formal identity wrapper for Build19-VE1-Q runner v4."""
from __future__ import annotations

import hashlib
from pathlib import Path

import ve1q_harness as harness

TOOL = Path(__file__).resolve().parent
_BASE_TOOL_SOURCE_HASH = harness.tool_source_hash


def formal_tool_source_hash() -> str:
    h = hashlib.sha256()
    h.update(_BASE_TOOL_SOURCE_HASH().encode("ascii"))
    extra = [
        "qualify_v3.py",
        "qualify_v4.py",
        "qualify_v4_entry.py",
        "README.md",
        "VE1_NUMERIC_EVIDENCE_POLICY.md",
        "fixtures/runtime/runtime-calibration-v2.json",
        "fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md",
        "fixtures/repro/repro-cases.json",
        "fixtures/parity/protocol-edge-lines.log",
        "tests/test_q3_bounded.py",
        "tests/test_ve1q.py",
        "tests/test_supplemental_v3.py",
        "tests/test_c1_v4.py"
    ]
    for name in extra:
        p = TOOL / name
        if not p.exists():
            raise harness.ValidationError("missing-tool-source", name)
        h.update(b"\0")
        h.update(name.encode("utf-8"))
        h.update(b"\0")
        h.update(p.read_bytes())
    return h.hexdigest()


harness.tool_source_hash = formal_tool_source_hash
harness.HARNESS_VERSION = "Build19-VE1-Q/1.3"

import qualify_v4  # noqa: E402  (must import after identity patch)


if __name__ == "__main__":
    raise SystemExit(qualify_v4.main())
