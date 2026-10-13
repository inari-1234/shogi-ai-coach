import importlib.util
import sys
import types
import unittest
from pathlib import Path

# Local fallback used only when this test file is executed outside the repository.
# In-repo CI imports the real tools/engine-verify/ve1q_harness.py.
def _fallback_parse_info(line):
    tokens = line.split()
    if not tokens or tokens[0] != "info":
        return None
    r = {"depth": None, "seldepth": None, "multipv": 1, "score": None,
         "nodes": None, "nps": None, "time": None, "pv": []}
    i = 1
    while i < len(tokens):
        t = tokens[i]
        if t in ("depth", "seldepth", "multipv", "nodes", "nps", "time"):
            if i + 1 < len(tokens):
                try:
                    value = int(tokens[i + 1])
                except ValueError:
                    value = None
                if t == "multipv":
                    value = value or 1
                r[t] = value
                i += 2
            else:
                i += 1
        elif t == "score":
            if i + 2 >= len(tokens):
                i += 1
                continue
            kind = tokens[i + 1]
            try:
                raw = int(tokens[i + 2])
            except ValueError:
                i += 3
                continue
            bound = None
            advance = 3
            if i + 3 < len(tokens) and tokens[i + 3] in ("lowerbound", "upperbound"):
                bound = "lower" if tokens[i + 3] == "lowerbound" else "upper"
                advance = 4
            if kind in ("cp", "mate"):
                r["score"] = {"type": kind, "value": raw, "bound": bound}
            i += advance
        elif t == "pv":
            r["pv"] = tokens[i + 1:]
            i = len(tokens)
        elif t == "string":
            i = len(tokens)
        else:
            i += 1
    return r

HERE = Path(__file__).resolve().parent
TOOL_DIR = HERE.parent if HERE.name == "tests" else HERE
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))
try:
    import ve1q_harness  # noqa: F401
except ImportError:
    fallback = types.ModuleType("ve1q_harness")
    fallback.parse_info_swift_compatible = _fallback_parse_info
    sys.modules["ve1q_harness"] = fallback

spec = importlib.util.spec_from_file_location("ve1c1_pilot", TOOL_DIR / "ve1c1_pilot.py")
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
parse_info = sys.modules["ve1q_harness"].parse_info_swift_compatible


def fake_sha(ch):
    return ch * 64


class VE1C1PilotTests(unittest.TestCase):
    def test_sampling_is_deterministic_and_capped(self):
        games = []
        for gi, ch in enumerate("abcdef"):
            games.append({
                "game_sha256": fake_sha(ch),
                "source_id": f"g{gi}",
                "positions": [
                    {
                        "ply": p,
                        "position_command": "position startpos moves 7g7f",
                        "actual_move": "7g7f",
                        "selected_by_production_deep_selector": True,
                    }
                    for p in range(1, 7)
                ],
            })
        pool = {"schema_version": mod.POOL_SCHEMA, "authority_commit": mod.AUTHORITY_COMMIT, "games": games}
        a = mod.select_pilot_positions(pool)
        b = mod.select_pilot_positions(pool)
        self.assertEqual(a, b)
        self.assertEqual(len(a["selected_positions"]), 16)
        counts = {}
        for pos in a["selected_positions"]:
            counts[pos["game_sha256"]] = counts.get(pos["game_sha256"], 0) + 1
        self.assertLessEqual(max(counts.values()), 4)
        self.assertGreaterEqual(len(counts), 4)

    def test_deepest_exact_snapshot_ignores_deeper_bound(self):
        lines = [
            "info depth 10 multipv 1 score cp 100 nodes 1000 time 10 pv 7g7f",
            "info depth 10 multipv 2 score cp 90 nodes 1000 time 10 pv 2g2f",
            "info depth 10 multipv 3 score cp 80 nodes 1000 time 10 pv 6g6f",
            "info depth 11 multipv 1 score cp 110 lowerbound nodes 1200 time 12 pv 7g7f",
            "info depth 11 multipv 2 score cp 95 nodes 1200 time 12 pv 2g2f",
            "info depth 11 multipv 3 score cp 85 nodes 1200 time 12 pv 6g6f",
        ]
        snapshot = mod.deepest_exact_snapshot([parse_info(x) for x in lines], 3)
        self.assertEqual([x["depth"] for x in snapshot], [10, 10, 10])
        self.assertEqual([x["pv"][0] for x in snapshot], ["7g7f", "2g2f", "6g6f"])

    def test_expected_score_known_values(self):
        self.assertAlmostEqual(mod.expected_score(0), 0.5, places=12)
        self.assertAlmostEqual(mod.expected_score(57), 0.5498, delta=0.001)

    def test_allowed_classes_boundaries(self):
        self.assertEqual(mod.app_allowed_classes(0.04, 0.01), {"GOOD"})
        self.assertEqual(mod.app_allowed_classes(0.05, 0.01), {"GOOD", "SOMEWHAT_WORSE"})
        self.assertEqual(mod.app_allowed_classes(0.19, 0.01), {"SOMEWHAT_WORSE", "BLUNDER"})
        self.assertEqual(mod.app_allowed_classes(0.21, 0.01), {"BLUNDER"})

    def test_zero_case_falls_back(self):
        self.assertEqual(mod.decide_f_policy([])["policy"], "F0")
        self.assertEqual(mod.decide_e_policy([])["policy"], "E0")

    def test_f2_requires_both_budgets(self):
        good = [{"kind": "small_inversion", "case_id": "x", "reference4m_membership": True, "reference16m_membership": True}]
        bad = [{"kind": "small_inversion", "case_id": "x", "reference4m_membership": True, "reference16m_membership": False}]
        self.assertEqual(mod.decide_f_policy(good)["policy"], "F2")
        self.assertEqual(mod.decide_f_policy(bad)["policy"], "F0")

    def test_e1_requires_both_budgets(self):
        good = [{"kind": "e1_only_compatibility", "case_id": "x", "reference4m_compatible": True, "reference16m_compatible": True}]
        bad = [{"kind": "e1_only_compatibility", "case_id": "x", "reference4m_compatible": None, "reference16m_compatible": True}]
        self.assertEqual(mod.decide_e_policy(good)["policy"], "E1")
        self.assertEqual(mod.decide_e_policy(bad)["policy"], "E0")

    def test_evidence_parity_including_bound_normalization(self):
        raw = "info depth 9 seldepth 2 multipv 1 score cp 93 upperbound nodes 50042 nps 329223 time 152 pv 2h3i"
        doc = {
            "positions": [{
                "attempts": [{
                    "multiPV": 1,
                    "selectedDepth": None,
                    "selectedNodes": None,
                    "selectedBoundKind": None,
                    "selectedPV": [],
                    "observations": [{
                        "rawUSI": raw,
                        "boundKind": "upperbound",
                        "depth": 9,
                        "seldepth": 2,
                        "multipv": 1,
                        "nodes": 50042,
                        "nps": 329223,
                        "timeMs": 152,
                        "pv": ["2h3i"],
                        "scoreKind": "cp",
                        "scoreValue": 93,
                    }],
                }],
            }],
        }
        result = mod.verify_evidence_document(doc)
        self.assertEqual(result["mismatch_count"], 0)


if __name__ == "__main__":
    unittest.main()
