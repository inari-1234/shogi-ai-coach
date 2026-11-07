import copy
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL = HERE.parent
ROOT = TOOL.parent.parent
if str(TOOL) not in sys.path:
    sys.path.insert(0, str(TOOL))

import ve1c1_natural_pilot_admission as adm
import ve1c1_pool_freeze as freeze


class VE1C1NaturalPilotAdmissionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.objects = [
            json.loads((ROOT / path).read_text(encoding="utf-8"))
            for path in (*adm.FROZEN_FILES, adm.CORPUS_FILE, adm.SEED_ORDER_FILE)
        ]

    def altered(self):
        return copy.deepcopy(self.objects)

    def test_frozen_commit_and_exact_exclusion_are_admissible(self):
        self.assertEqual(adm.validate_committed_history(ROOT), adm.git_read(ROOT, "rev-parse", "HEAD").decode().strip())
        result = adm.validate_bound_artifacts(*self.altered())
        self.assertEqual(result["natural_pilot_positions"], 16)
        self.assertEqual(result["excluded_ve1d_games"], 6)
        self.assertEqual(result["processed_games"], 5)

    def test_false_is_precommit_snapshot_not_manual_toggle(self):
        pool, manifest, exclusion, corpus, order = self.altered()
        exclusion["natural_pilot_execution_permitted"] = True
        exclusion["exclusion_authority_sha256"] = freeze.digest_without(exclusion, "exclusion_authority_sha256")
        with self.assertRaisesRegex(adm.AdmissionError, "frozen_precommit_snapshot_flag_modified"):
            adm.validate_bound_artifacts(pool, manifest, exclusion, corpus, order)

    def test_exposed_game_cannot_be_removed_even_if_digest_recomputed(self):
        pool, manifest, exclusion, corpus, order = self.altered()
        exclusion["ve1d_excluded_game_sha256"].remove(freeze.PREVIOUSLY_EXPOSED_SEEDED_GAME_SHA256[1])
        exclusion["exclusion_authority_sha256"] = freeze.digest_without(exclusion, "exclusion_authority_sha256")
        with self.assertRaisesRegex(adm.AdmissionError, "exact_complete_exclusion"):
            adm.validate_bound_artifacts(pool, manifest, exclusion, corpus, order)

    def test_pool_mutation_after_freeze_cannot_be_admitted(self):
        pool, manifest, exclusion, corpus, order = self.altered()
        pool["selector_trace"][-1]["per_game_capped_contribution"] = 1
        pool["pool_sha256"] = freeze.digest_without(pool, "pool_sha256")
        with self.assertRaisesRegex(adm.AdmissionError, "exclusion_pool"):
            adm.validate_bound_artifacts(pool, manifest, exclusion, corpus, order)

    def test_seed_order_mutation_is_rejected(self):
        pool, manifest, exclusion, corpus, order = self.altered()
        order["ordered_games"][0], order["ordered_games"][1] = order["ordered_games"][1], order["ordered_games"][0]
        with self.assertRaisesRegex(adm.AdmissionError, "non_prefix_seed_rank|seed_order_changed"):
            adm.validate_bound_artifacts(pool, manifest, exclusion, corpus, order)


if __name__ == "__main__":
    unittest.main()
