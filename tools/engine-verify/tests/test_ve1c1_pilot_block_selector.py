import json
import sys
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent.parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import ve1c1_block_selector as blocks
import ve1c1_pilot as contract


class VE1C1BlockSelectorTests(unittest.TestCase):
    def fixture(self):
        path = TOOL_DIR / "fixtures" / "ve1b_multipv_block_mixing.json"
        return json.loads(path.read_text(encoding="utf-8"))

    def test_reproduces_frozen_mixed_cohort_bug(self):
        fixture = self.fixture()
        observations = contract.parse_raw_usi_lines(fixture["raw_usi_lines"])
        frozen = blocks.frozen_selector_snapshot(observations, fixture["required_multipv"])
        self.assertEqual(
            blocks.snapshot_root_moves(frozen),
            fixture["expected_frozen_selector_bug"]["moves"],
        )
        self.assertEqual(
            [row["nodes"] for row in blocks.snapshot_brief(frozen)],
            fixture["expected_frozen_selector_bug"]["nodes"],
        )

    def test_selects_completed_single_output_block(self):
        fixture = self.fixture()
        observations = contract.parse_raw_usi_lines(fixture["raw_usi_lines"])
        selected = blocks.deepest_exact_output_block(observations, fixture["required_multipv"])
        brief = blocks.snapshot_brief(selected)
        self.assertIsNotNone(brief)
        self.assertEqual([row["move"] for row in brief], fixture["expected_block"]["moves"])
        self.assertEqual([row["score_value"] for row in brief], fixture["expected_block"]["scores_cp"])
        self.assertEqual({row["depth"] for row in brief}, {fixture["expected_block"]["depth"]})
        self.assertEqual({row["nodes"] for row in brief}, {fixture["expected_block"]["nodes"]})
        self.assertEqual({row["time_ms"] for row in brief}, {fixture["expected_block"]["time_ms"]})

    def test_duplicate_root_is_integrity_failure_not_completion_definition(self):
        fixture = self.fixture()
        observations = contract.parse_raw_usi_lines(fixture["raw_usi_lines"][:3])
        observations[1] = dict(observations[1])
        observations[1]["pv"] = list(observations[0]["pv"])
        self.assertIsNone(blocks.deepest_exact_output_block(observations, 3))


if __name__ == "__main__":
    unittest.main()
