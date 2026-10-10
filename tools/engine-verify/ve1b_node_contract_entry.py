#!/usr/bin/env python3
"""Corrected VE1-B node-contract entry point.

The original verifier named the pinned YaneuraOu source proof file
`yaneuraou-engine.cpp`; at the pinned commit the implementation is in
`yaneuraou-search.cpp`. This wrapper changes only that source-proof lookup and
then delegates all runtime contract checks to `ve1b_node_contract.py`.
"""
from __future__ import annotations

import re
from pathlib import Path

import ve1b_node_contract as base


def verify_tt_source(work: Path) -> dict:
    path = work / "YaneuraOu/source/engine/yaneuraou-engine/yaneuraou-search.cpp"
    text = path.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        r"YaneuraOuEngine::isready\s*\([^)]*\).*?tt\.clear\s*\(\s*threads\s*\)",
        re.S,
    )
    if not pattern.search(text):
        raise base.ContractFailure(
            "pinned YaneuraOu source no longer proves isready -> tt.clear(threads)"
        )
    return {
        "path": str(path),
        "engine_commit_expected": "a5ee2786c0030edc7d4a1cdfe94b04dffec55493",
        "proof": "YaneuraOuEngine::isready contains tt.clear(threads)",
        "status": "PASS",
    }


base.verify_tt_source = verify_tt_source
raise SystemExit(base.main())
