#!/usr/bin/env python3
from __future__ import annotations

import copy
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
TOOL_DIR = HERE.parent
REPO_ROOT = TOOL_DIR.parent.parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import ve1c1_pool_freeze as freeze


def sha(ch: str) -> str:
    return ch * 64


class VE1C1PoolFreezeTests(unittest.TestCase):
    def base_pool(self) -> dict:
        producers = [sha("a"), sha("c"), sha("d"), sha("e")]
        zero = sha("b")
        games = [
            {"game_sha256": producers[0]},
            {"game_sha256": producers[1]},
            {"game_sha256": producers[2]},
            {"game_sha256": producers[3]},
        ]
        trace = [
            {
                "seed_rank": 1,
                "game_sha256": producers[0],
                "selector_outcome": "CANDIDATES_AVAILABLE",
                "production_selected_count": 4,
                "per_game_capped_contribution": 4,
            },
            {
                "seed_rank": 2,
                "game_sha256": zero,
                "selector_outcome": "NO_ELIGIBLE_POSITIONS",
                "production_selected_count": 0,
                "per_game_capped_contribution": 0,
            },
            {
                "seed_rank": 3,
                "game_sha256": producers[1],
                "selector_outcome": "CANDIDATES_AVAILABLE",
                "production_selected_count": 5,
                "per_game_capped_contribution": 4,
            },
            {
                "seed_rank": 4,
                "game_sha256": producers[2],
                "selector_outcome": "CANDIDATES_AVAILABLE",
                "production_selected_count": 2,
                "per_game_capped_contribution": 2,
            },
            {
                "seed_rank": 5,
                "game_sha256": producers[3],
                "selector_outcome": "CANDIDATES_AVAILABLE",
                "production_selected_count": 3,
                "per_game_capped_contribution": 3,
            },
        ]
        return {
            "processed_game_count": len(trace),
            "candidate_producing_game_count": len(games),
            "games": games,
            "selector_trace": trace,
        }

    def test_classifies_candidate_producers_and_zero_candidate_games_in_processed_order(self) -> None:
        pool = self.base_pool()
        producers, zero = freeze.classify_processed_games(pool)
        self.assertEqual(producers, [sha("a"), sha("c"), sha("d"), sha("e")])
        self.assertEqual(zero, [sha("b")])
        self.assertNotIn(sha("b"), producers)

    def test_rejects_pool_games_that_do_not_exactly_match_trace_producers(self) -> None:
        pool = self.base_pool()
        pool["games"] = pool["games"][:-1]
        pool["candidate_producing_game_count"] = len(pool["games"])
        with self.assertRaisesRegex(RuntimeError, "pool_games_vs_trace_candidate_producers_mismatch"):
            freeze.classify_processed_games(pool)

    def test_rejects_zero_candidate_outcome_labeled_as_candidate_producer(self) -> None:
        pool = self.base_pool()
        pool["selector_trace"][1]["selector_outcome"] = "CANDIDATES_AVAILABLE"
        with self.assertRaisesRegex(RuntimeError, "zero_candidate_outcome_mismatch"):
            freeze.classify_processed_games(pool)

    def test_rejects_candidate_producer_outcome_labeled_zero(self) -> None:
        pool = self.base_pool()
        pool["selector_trace"][0]["selector_outcome"] = "NO_ELIGIBLE_POSITIONS"
        with self.assertRaisesRegex(RuntimeError, "candidate_producer_outcome_mismatch"):
            freeze.classify_processed_games(pool)

    def test_rejects_processed_count_mismatch(self) -> None:
        pool = self.base_pool()
        pool["processed_game_count"] -= 1
        with self.assertRaisesRegex(RuntimeError, "processed_game_count_mismatch"):
            freeze.classify_processed_games(pool)

    def test_rejects_non_increasing_seed_rank(self) -> None:
        pool = self.base_pool()
        pool["selector_trace"][2]["seed_rank"] = 2
        with self.assertRaisesRegex(RuntimeError, "non_increasing_seed_rank_in_trace"):
            freeze.classify_processed_games(pool)


    def test_rank_two_zero_candidate_stays_excluded_but_unexposed_zero_does_not(self) -> None:
        pool = self.base_pool()
        exposed1, exposed2 = freeze.PREVIOUSLY_EXPOSED_SEEDED_GAME_SHA256
        pool["selector_trace"][0]["game_sha256"] = exposed1
        pool["games"][0]["game_sha256"] = exposed1
        pool["selector_trace"][1]["game_sha256"] = exposed2  # current rerun: zero
        # Also include an ordinary later zero, which must NOT be excluded.
        pool["selector_trace"].append({
            "seed_rank": 6, "game_sha256": sha("f"),
            "selector_outcome": "NO_ELIGIBLE_POSITIONS",
            "production_selected_count": 0, "per_game_capped_contribution": 0,
        })
        pool["processed_game_count"] = len(pool["selector_trace"])
        producers, zero = freeze.classify_processed_games(pool)
        exclusion = freeze.derive_ve1d_exclusions(pool, producers, zero)
        self.assertEqual(exclusion, [exposed1, exposed2, sha("c"), sha("d"), sha("e"), freeze.B6_SHA256])
        self.assertIn(exposed2, zero)
        self.assertNotIn(sha("f"), exclusion)

    def test_both_exposed_seed_games_are_excluded_when_both_produce_candidates(self) -> None:
        pool = self.base_pool()
        exposed1, exposed2 = freeze.PREVIOUSLY_EXPOSED_SEEDED_GAME_SHA256
        pool["selector_trace"][0]["game_sha256"] = exposed1
        pool["games"][0]["game_sha256"] = exposed1
        pool["selector_trace"][1].update({
            "game_sha256": exposed2, "selector_outcome": "CANDIDATES_AVAILABLE",
            "production_selected_count": 1, "per_game_capped_contribution": 1,
        })
        pool["games"].insert(1, {"game_sha256": exposed2})
        pool["candidate_producing_game_count"] = len(pool["games"])
        producers, zero = freeze.classify_processed_games(pool)
        exclusion = freeze.derive_ve1d_exclusions(pool, producers, zero)
        self.assertEqual(exclusion, producers + [freeze.B6_SHA256])

    def test_preexposed_seed_prefix_mismatch_fails_closed(self) -> None:
        pool = self.base_pool()
        producers, zero = freeze.classify_processed_games(pool)
        with self.assertRaisesRegex(RuntimeError, "pre_exposed_seed_prefix_mismatch"):
            freeze.derive_ve1d_exclusions(pool, producers, zero)

    def test_swift_probe_preserves_exact_production_zero_candidate_outcome(self) -> None:
        source = (REPO_ROOT / "iOS/ShogiCoachPoC/VE1C1PoolSimulatorProbe.swift").read_text(encoding="utf-8")
        self.assertIn('productionZeroCandidateMessage = "重要局面候補を抽出できません"', source)
        self.assertIn('selectorOutcome = "NO_ELIGIBLE_POSITIONS"', source)
        self.assertIn('"processed_game_count": trace.count', source)
        self.assertIn('"candidate_producing_game_count": poolGames.count', source)
        self.assertNotIn('guard deep.status == "深掘り PASS",\n                      deep.runState.isCompleted,\n                      !deep.entries.isEmpty', source)

    def test_exclusion_schema_records_preexposed_seed_exception(self) -> None:
        self.assertEqual(freeze.EXCLUSION_SCHEMA, "ve1c1-ve1d-exclusion-authority-v3")
        self.assertEqual(len(freeze.PREVIOUSLY_EXPOSED_SEEDED_GAME_SHA256), 2)
        self.assertEqual(
            freeze.B6_SHA256,
            "ea8a9e4b0211c5c6fde7514987df74d17508f8b59f72b7969a1105ce1fd94102",
        )


if __name__ == "__main__":
    unittest.main(verbosity=2)
