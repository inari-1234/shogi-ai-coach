import sys
import unittest
from pathlib import Path

TOOL_DIR = Path(__file__).resolve().parent.parent
if str(TOOL_DIR) not in sys.path:
    sys.path.insert(0, str(TOOL_DIR))

import ve1c1_pilot as contract
import ve1c1_pilot_evaluator as ev


def line(move, cp, nodes=100):
    return {"pv": [move], "scoreKind": "cp", "scoreValue": cp, "nodes": nodes, "multipv": 1}


def search(move, cp):
    return {"selectedSnapshotEvidenceStatus": "RESOLVED", "selectedSnapshot": [line(move, cp)]}


def root(lines):
    result = []
    for i, (move, cp) in enumerate(lines, 1):
        x = line(move, cp)
        x["multipv"] = i
        result.append(x)
    return {"selectedSnapshotEvidenceStatus": "RESOLVED", "selectedSnapshot": result}


class VE1C1PilotEvaluatorTests(unittest.TestCase):
    def test_reference_unique_and_multiple(self):
        u = ev.reference_root_structure(root([("7g7f", 100), ("2g2f", 0), ("6i7h", -50)]))
        self.assertEqual(u["label"], "UNIQUE_GOOD")
        m = ev.reference_root_structure(root([("7g7f", 100), ("2g2f", 90), ("6i7h", -50)]))
        self.assertEqual(m["label"], "MULTIPLE_GOOD")

    def test_unique_identity_change_is_disputed(self):
        ref = {"budgets": [
            {"nodeBudget": 4_000_000, "root": root([("7g7f", 100), ("2g2f", -100), ("6i7h", -200)])},
            {"nodeBudget": 16_000_000, "root": root([("2g2f", 100), ("7g7f", -100), ("6i7h", -200)])},
        ]}
        r = ev.cross_budget_structure(ref)
        self.assertEqual(r["status"], "DISPUTED")
        self.assertEqual(r["reason"], "UNIQUE_IDENTITY_CHANGED")

    def test_reference_membership_requires_structure_and_played(self):
        b = {
            "rank1Move": "7g7f", "actualMove": "2g2f", "playedStatus": "RESOLVED",
            "root": root([("7g7f", 100), ("2g2f", 95), ("6i7h", -50)]),
            "bestSearch": search("7g7f", 100), "actualSearch": search("2g2f", 95),
        }
        self.assertTrue(ev.reference_actual_membership(b))
        b["root"]["selectedSnapshotEvidenceStatus"] = "INSUFFICIENT_DUPLICATE_ROOT_MOVE"
        self.assertIsNone(ev.reference_actual_membership(b))

    def test_diagnostic_controls_never_select_f_or_e(self):
        raw = {"schema_version": contract.PILOT_RESULT_SCHEMA, "run_kind": "diagnostic_controls", "authority_commit": contract.AUTHORITY_COMMIT, "positions": []}
        r = ev.evaluate_document(raw)
        self.assertEqual(r["F"]["policy"], "NOT_DECIDED")
        self.assertEqual(r["E"]["policy"], "NOT_DECIDED")


    def test_searchmoves_target_binding_fails_closed_on_omitted_nonpromotion(self):
        # Exact frozen-engine observation: searchmoves 3c1c silently returned 1i2i.
        omitted = {
            "searchMoves": ["3c1c"],
            "bestmove": "1i2i",
            "selectedSnapshot": [line("1i2i", 12)],
            "selectedSnapshotEvidenceStatus": "RESOLVED",
        }
        promoted = {
            "searchMoves": ["3c1c+"],
            "bestmove": "3c1c+",
            "selectedSnapshot": [line("3c1c+", 12)],
            "selectedSnapshotEvidenceStatus": "RESOLVED",
        }
        self.assertEqual(ev.searchmoves_target_binding(omitted), "SEARCHMOVES_TARGET_MISMATCH")
        self.assertIsNone(ev._primary(omitted))
        self.assertEqual(ev.searchmoves_target_binding(promoted), "MATCH")
        self.assertEqual(ev._primary(promoted)["pv"], ["3c1c+"])
        budget = {
            "playedStatus": "RESOLVED",
            "bestSearch": promoted,
            "actualSearch": omitted,
            "rank1Move": "3c1c+",
            "actualMove": "3c1c",
        }
        decided = ev.reference_played_budget(budget)
        self.assertEqual(decided["status"], "INSUFFICIENT")
        self.assertEqual(decided["class"], "NOT_CLASSIFIABLE")
        self.assertEqual(decided["reason"], "SEARCHMOVES_TARGET_MISMATCH")
        self.assertIsNone(ev.reference_actual_membership({"root": root([
            ("3c1c+", 100), ("1i2i", 0), ("3c2c", -100)]), **budget}))

    def test_invalid_searchmoves_target_does_not_create_false_F2_case(self):
        valid = {
            "searchMoves": ["3c1c+"],
            "bestmove": "3c1c+",
            "selectedSnapshot": [line("3c1c+", 0)],
            "selectedSnapshotEvidenceStatus": "RESOLVED",
        }
        invalid = {
            "searchMoves": ["3c1c"],
            "bestmove": "1i2i",
            "selectedSnapshot": [line("1i2i", 300)],
            "selectedSnapshotEvidenceStatus": "RESOLVED",
        }
        position = {
            "position_id": "p-edge",
            "actual_move": "3c1c",
            "app": {
                "recommendedMove": "3c1c+",
                "discoveries": [{
                    "nodeBudget": 50000, "selectedSnapshotEvidenceStatus": "RESOLVED",
                    "selectedSnapshot": [line("3c1c+", 0)],
                }],
                "comparisons": [{
                    "nodeBudget": 50000, "comparisonInversion": True,
                    "bestSearch": valid, "actualSearch": invalid,
                }],
            },
            "reference": {"budgets": []},
        }
        assessed = ev.evaluate_position(position)
        self.assertEqual(assessed["tiers"][0]["comparisonClass"], "NOT_CLASSIFIABLE")
        self.assertEqual(assessed["tiers"][0]["comparisonReason"], "SEARCHMOVES_TARGET_MISMATCH")
        self.assertFalse(assessed["tiers"][0]["comparisonInversion"])
        self.assertEqual(assessed["f_cases"], [])
        self.assertEqual(assessed["e_cases"], [])

    def test_matching_target_must_match_both_bestmove_and_root_pv(self):
        search = {
            "searchMoves": ["3c1c+"], "bestmove": "3c1c+",
            "selectedSnapshot": [line("1i2i", 5)],
        }
        self.assertEqual(ev.searchmoves_target_binding(search), "SEARCHMOVES_TARGET_MISMATCH")
        search["selectedSnapshot"] = [line("3c1c+", 5)]
        self.assertEqual(ev.searchmoves_target_binding(search), "MATCH")

    def test_reference_score_classes_follow_fixed_boundaries(self):
        best = ("cp", 0)
        # approximately 57 cp lower is around the 0.05 boundary
        good = ev._severity_class_from_scores(best, ("cp", -50))
        worse = ev._severity_class_from_scores(best, ("cp", -100))
        self.assertEqual(good["class"], "GOOD")
        self.assertEqual(worse["class"], "SOMEWHAT_WORSE")


if __name__ == "__main__":
    unittest.main()
