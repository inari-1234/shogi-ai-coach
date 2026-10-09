import json
import unittest
from pathlib import Path


TOOL = Path(__file__).resolve().parents[1]


class VE1QC1V4Tests(unittest.TestCase):
    def setUp(self):
        self.fixture = json.loads((TOOL / "fixtures/runtime/runtime-calibration-v2.json").read_text(encoding="utf-8"))
        self.cases = {c["id"]: c for c in self.fixture["cases"]}

    def test_schema_and_two_known_answer_positions(self):
        self.assertEqual(self.fixture["schema_version"], "ve1q-runtime-calibration-v2")
        self.assertEqual(set(self.cases), {"startpos-depth1", "corrected-review-sfen-depth1"})

    def test_startpos_known_answers(self):
        c = self.cases["startpos-depth1"]
        self.assertEqual(c["position"], "position startpos")
        self.assertEqual(c["go"], "depth 1")
        self.assertEqual(c["multipv"], 1)
        self.assertEqual(c["threads"], 1)
        self.assertEqual(c["expected"]["app-current"]["score_value"], 164)
        self.assertEqual(c["expected"]["app-candidate"]["score_value"], 108)
        self.assertEqual(c["expected"]["app-current"]["bestmove"], "7g7f")
        self.assertEqual(c["expected"]["app-candidate"]["bestmove"], "7g7f")

    def test_corrected_review_sfen_known_answers(self):
        c = self.cases["corrected-review-sfen-depth1"]
        self.assertEqual(c["position"], "position sfen lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8")
        self.assertEqual(c["expected"]["app-current"]["score_value"], 236)
        self.assertEqual(c["expected"]["app-candidate"]["score_value"], 157)
        self.assertEqual(c["expected"]["app-current"]["bestmove"], "2b7g+")
        self.assertEqual(c["expected"]["app-candidate"]["bestmove"], "2b7g+")

    def test_scale_invariants_are_fixed_and_pass_on_authority_values(self):
        for c in self.cases.values():
            self.assertEqual(c["scale_invariant"]["tolerance"], 40)
            cp16 = c["expected"]["app-current"]["score_value"]
            cp24 = c["expected"]["app-candidate"]["score_value"]
            self.assertLessEqual(abs(cp16 * 16 - cp24 * 24), 40)

    def test_correction_record_contains_illegal_move_and_effective_sfen(self):
        t = (TOOL / "fixtures/runtime/C1_REVIEW_CORRECTION_20261009.md").read_text(encoding="utf-8")
        self.assertIn("Illegal Input Move : 3c3d", t)
        self.assertIn("lnsgk1snl/1r4gb1/p1pppp1pp/1p4p2/7P1/2P6/PPBPPPP1P/7R1/LNSGKGSNL w - 8", t)
        self.assertIn("236", t)
        self.assertIn("157", t)
        self.assertIn("164", t)
        self.assertIn("108", t)

    def test_numeric_expectation_policy_requires_complete_evidence(self):
        t = (TOOL / "VE1_NUMERIC_EVIDENCE_POLICY.md").read_text(encoding="utf-8")
        for marker in ("Exact position identity", "Complete relevant command sequence", "Raw USI log", "Runtime provenance", "OBSERVATION_ONLY"):
            self.assertIn(marker, t)
        self.assertIn("The expected value must not be changed merely to match the new run.", t)


if __name__ == "__main__":
    unittest.main()
