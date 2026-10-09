import sys
import unittest
from pathlib import Path

TOOL = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL))

from ve1q_harness import deterministic_repro_view, strict_validate_raw_log


class Q3BoundedMultiPVRegression(unittest.TestCase):
    def test_bounded_entries_remain_in_deterministic_multipv_order(self):
        raw = TOOL / "fixtures/parity/selected-fields.log"
        parsed = strict_validate_raw_log(
            raw,
            allow_bounds=True,
            require_complete_fields=True,
        )
        view = deterministic_repro_view(parsed)
        self.assertEqual(
            [pv["multipv"] for pv in view["principalVariations"]],
            [1, 2, 3],
        )
        self.assertEqual(
            view["principalVariations"][0]["score"]["bound"],
            "lower",
        )
        self.assertEqual(
            view["principalVariations"][1]["score"]["bound"],
            "upper",
        )


if __name__ == "__main__":
    unittest.main()
