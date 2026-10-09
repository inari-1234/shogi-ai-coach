import sys
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))

import qualify_v3 as q3
from ve1q_harness import read_json, swift_compatible_accumulate


class VE1QSupplementalV3Tests(unittest.TestCase):
    def test_runtime_calibration_fixture(self):
        d = read_json(TOOL / "fixtures/runtime/runtime-calibration.json")
        self.assertEqual(d["schema_version"], q3.CAL_SCHEMA)
        self.assertEqual(d["position"], "position startpos")
        self.assertEqual(d["go"], "depth 1")
        self.assertEqual(d["expected"]["app-current"]["fv_scale"], 16)
        self.assertEqual(d["expected"]["app-current"]["score_value"], 236)
        self.assertEqual(d["expected"]["app-candidate"]["fv_scale"], 24)
        self.assertEqual(d["expected"]["app-candidate"]["score_value"], 157)

    def test_expanded_repro_fixture(self):
        d = read_json(TOOL / "fixtures/repro/repro-cases.json")
        self.assertEqual(d["schema_version"], q3.REPRO_SCHEMA)
        ids = {c["id"] for c in d["fixed_node_cases"]}
        self.assertEqual(ids, {"startpos-50k", "middlegame-250k", "searchmoves-100k"})
        self.assertEqual(d["movetime_control"]["expected_relation"], "at-least-two-distinct-deterministic-views")

    def test_protocol_edge_parity_fixture_contains_negative_mate_and_noise(self):
        p = TOOL / "fixtures/parity/protocol-edge-lines.log"
        text = p.read_text(encoding="utf-8")
        self.assertIn("score mate -3", text)
        self.assertIn("info string", text)
        self.assertIn("currmove", text)
        result = swift_compatible_accumulate(text.splitlines())
        self.assertEqual(result["bestmove"], "2g2f")
        self.assertEqual(result["principalVariations"][0]["score"], {"type": "mate", "value": -3, "bound": None})

    def test_profile_scope_limitation_is_documented(self):
        text = (TOOL / "README.md").read_text(encoding="utf-8")
        self.assertIn("Profiles reproduce engine settings only; they do not reproduce the app comparison procedure", text)

    def test_ve1b_issue_is_backlogged_not_implemented(self):
        p = TOOL.parent.parent / "Build19/BUILD19_VE1_B_ISSUES_20261009.md"
        text = p.read_text(encoding="utf-8")
        self.assertIn("VE1B-001", text)
        self.assertIn("OPEN / NOT IMPLEMENTED", text)


if __name__ == "__main__":
    unittest.main()
