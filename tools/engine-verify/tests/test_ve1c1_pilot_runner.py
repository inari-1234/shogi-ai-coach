import sys
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent.parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import ve1c1_pilot as contract
import ve1c1_pilot_runner as runner


class VE1C1PilotRunnerTests(unittest.TestCase):
    def test_score_order_matches_frozen_ve1b_semantics(self):
        self.assertGreater(runner.score_order_key({"type": "mate", "value": 5}), runner.score_order_key({"type": "cp", "value": 99999}))
        self.assertGreater(runner.score_order_key({"type": "cp", "value": -99999}), runner.score_order_key({"type": "mate", "value": -5}))
        self.assertGreater(runner.score_order_key({"type": "mate", "value": 3}), runner.score_order_key({"type": "mate", "value": 5}))
        self.assertGreater(runner.score_order_key({"type": "mate", "value": -9}), runner.score_order_key({"type": "mate", "value": -3}))

    def test_control_positions_are_not_natural_pilot(self):
        controls = runner.controls()
        self.assertEqual(len(controls), 2)
        self.assertEqual(controls[0]["position_id"], "control-startpos")
        self.assertEqual(controls[1]["position_id"], "control-c1-sfen")
        self.assertNotIn("game_sha256", controls[0])
        self.assertNotIn("game_sha256", controls[1])

    def test_snapshot_guard_rejects_duplicate_and_mixed_cohort(self):
        good = [
            {"pv": ["7g7f"], "nodes": 100},
            {"pv": ["2g2f"], "nodes": 100},
            {"pv": ["6i7h"], "nodes": 100},
        ]
        duplicate = [good[0], good[1], {"pv": ["2g2f"], "nodes": 100}]
        mixed = [good[0], good[1], {"pv": ["6i7h"], "nodes": 101}]
        self.assertEqual(runner.snapshot_evidence_status(good, 3), "RESOLVED")
        self.assertEqual(runner.snapshot_evidence_status(duplicate, 3), "INSUFFICIENT_DUPLICATE_ROOT_MOVE")
        self.assertEqual(runner.snapshot_evidence_status(mixed, 3), "INSUFFICIENT_MIXED_ITERATION_COHORT")

    def test_terminal_iteration_bound_detection_uses_deepest_depth(self):
        obs = [
            {"depth": 10, "multipv": 1, "score": {"type": "cp", "value": 1, "bound": None}},
            {"depth": 10, "multipv": 2, "score": {"type": "cp", "value": 0, "bound": None}},
            {"depth": 10, "multipv": 3, "score": {"type": "cp", "value": -1, "bound": None}},
            {"depth": 11, "multipv": 1, "score": {"type": "cp", "value": 3, "bound": "lower"}},
        ]
        terminal = runner.terminal_iteration_state(obs, 3)
        self.assertEqual(terminal["depth"], 11)
        self.assertTrue(terminal["hasBound"])
        self.assertFalse(terminal["completeRanksObserved"])

    def test_runtime_contract_is_frozen(self):
        self.assertEqual(runner.APP_NODE_TIERS, (50_000, 100_000, 200_000))
        self.assertEqual(runner.REFERENCE_NODE_BUDGETS, (4_000_000, 16_000_000))
        self.assertEqual(runner.APP_HASH_MB, 64)
        self.assertEqual(runner.REFERENCE_HASH_MB, 512)
        self.assertEqual(contract.AUTHORITY_COMMIT, "8daf78caa2bd5919cc911da21bae80fa3d12a248")


if __name__ == "__main__":
    unittest.main()
