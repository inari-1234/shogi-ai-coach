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

    def test_runtime_contract_is_frozen(self):
        self.assertEqual(runner.APP_NODE_TIERS, (50_000, 100_000, 200_000))
        self.assertEqual(runner.REFERENCE_NODE_BUDGETS, (4_000_000, 16_000_000))
        self.assertEqual(runner.APP_HASH_MB, 64)
        self.assertEqual(runner.REFERENCE_HASH_MB, 512)
        self.assertEqual(contract.AUTHORITY_COMMIT, "8daf78caa2bd5919cc911da21bae80fa3d12a248")


if __name__ == "__main__":
    unittest.main()
