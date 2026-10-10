#!/usr/bin/env python3
"""Build19 VE1-B corrected native node/TT/book contract.

Comparison authority in this verifier is the independent single-move method:
for each node tier, recommended and actual moves are measured separately with
MultiPV1 and a fresh TT clear before EACH invocation. Node N means N nodes per
move. Numeric fixture budgets remain calibration-only, not production authority.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import ve1b_node_contract as base

FIXTURE_N = 50_000
FIXTURE_TIERS = [50_000, 100_000, 200_000]


def verify_tt_source(work: Path) -> dict:
    path = work / "YaneuraOu/source/engine/yaneuraou-engine/yaneuraou-search.cpp"
    text = path.read_text(encoding="utf-8-sig")
    pattern = re.compile(
        r"YaneuraOuEngine::isready\s*\([^)]*\).*?tt\.clear\s*\(\s*threads\s*\)",
        re.S,
    )
    if not pattern.search(text):
        raise base.ContractFailure(
            "pinned YaneuraOu source no longer proves isready -> tt.clear(threads)"
        )
    return {
        "path": str(path),
        "engine_commit_expected": "a5ee2786c0030edc7d4a1cdfe94b04dffec55493",
        "proof": "YaneuraOuEngine::isready contains tt.clear(threads)",
        "status": "PASS",
    }


def run_contract(work: Path, out: Path) -> dict:
    engine_path = (work / "engine").resolve()
    eval_dir = (work / "eval").resolve()
    if not engine_path.exists():
        raise base.ContractFailure(f"engine missing: {engine_path}")
    if not (eval_dir / "nn.bin").exists():
        raise base.ContractFailure(f"NNUE missing: {eval_dir / 'nn.bin'}")
    out.mkdir(parents=True, exist_ok=True)

    tt_proof = verify_tt_source(work)
    e = base.Engine(engine_path, work, eval_dir)
    all_transcript: list[str] = []
    book_dir = work / "book"
    book_file = book_dir / "standard_book.db"
    if book_file.exists():
        book_file.unlink()

    try:
        e.start()

        # A. Reproducibility is separate from stability.
        e.cold_reset("repro_1")
        repro1 = e.search("same_budget_cold_1", "position startpos", FIXTURE_N)
        e.cold_reset("repro_2")
        repro2 = e.search("same_budget_cold_2", "position startpos", FIXTURE_N)
        base.assert_same("same-budget cold reproducibility", repro1, repro2)

        # B. A cold target must not inherit an unrelated prior position.
        e.cold_reset("order_baseline_B")
        order_b1 = e.search("order_B_first", "position startpos", FIXTURE_N)
        e.cold_reset("order_unrelated_A")
        unrelated = e.search(
            "order_A_unrelated",
            "position startpos moves 7g7f 3c3d",
            FIXTURE_N,
        )
        e.cold_reset("order_target_B_after_A")
        order_b2 = e.search("order_B_after_A", "position startpos", FIXTURE_N)
        base.assert_same("TT cold-start order independence", order_b1, order_b2)

        # C. Every unrestricted candidate-discovery tier starts cold.
        discoveries = []
        discovery_generations = []
        for index, nodes in enumerate(FIXTURE_TIERS):
            e.cold_reset(f"candidate_discovery_{index}")
            discovery_generations.append(e.tt_generation)
            discoveries.append(
                e.search(
                    f"candidate_discovery_{nodes}",
                    "position startpos",
                    nodes,
                    multipv=3,
                )
            )
        if len(set(discovery_generations)) != len(FIXTURE_TIERS):
            raise base.ContractFailure("candidate discovery did not receive distinct cold TT generations")

        # D. Corrected direct comparison: one move per invocation, MultiPV1,
        # same node budget per move, and a cold TT boundary before EACH search.
        comparisons = []
        comparison_generations = []
        for index, nodes in enumerate(FIXTURE_TIERS):
            e.cold_reset(f"comparison_recommended_{index}")
            best_generation = e.tt_generation
            recommended = e.search(
                f"recommended_{nodes}",
                "position startpos",
                nodes,
                multipv=1,
                searchmoves=["7g7f"],
            )

            e.cold_reset(f"comparison_actual_{index}")
            actual_generation = e.tt_generation
            actual = e.search(
                f"actual_{nodes}",
                "position startpos",
                nodes,
                multipv=1,
                searchmoves=["2g2f"],
            )
            comparison_generations.extend([best_generation, actual_generation])

            if recommended.go_command != f"go nodes {nodes} searchmoves 7g7f":
                raise base.ContractFailure(f"unexpected recommended go command: {recommended.go_command}")
            if actual.go_command != f"go nodes {nodes} searchmoves 2g2f":
                raise base.ContractFailure(f"unexpected actual go command: {actual.go_command}")
            if best_generation == actual_generation:
                raise base.ContractFailure("recommended and actual searches shared a TT generation")

            comparisons.append({
                "node_budget_per_move": nodes,
                "recommended_tt_generation": best_generation,
                "actual_tt_generation": actual_generation,
                "recommended": base.result_dict(recommended),
                "actual": base.result_dict(actual),
            })

        if len(set(comparison_generations)) != len(FIXTURE_TIERS) * 2:
            raise base.ContractFailure("comparison searches did not all receive distinct cold TT generations")
        if min(comparison_generations) <= max(discovery_generations):
            raise base.ContractFailure("comparison TT generations did not follow isolated discovery generations")

        # E. BookFile=no_book remains mandatory and a present book is inert.
        e.cold_reset("book_absent")
        book_absent = e.search("book_absent", "position startpos", FIXTURE_N)
        book_dir.mkdir(parents=True, exist_ok=True)
        book_file.write_bytes(b"VE1-B inert-book negative fixture\n")
        e.cold_reset("book_present_disabled")
        book_present = e.search("book_present_disabled", "position startpos", FIXTURE_N)
        base.assert_same("BookFile=no_book negative fixture", book_absent, book_present)

        all_transcript = list(e.transcript)
        if not any(x == "> setoption name BookFile value no_book" for x in all_transcript):
            raise base.ContractFailure("BookFile=no_book command missing")
        if any("can't read file : book/standard_book.db" in x for x in all_transcript):
            raise base.ContractFailure("opening-book read warning appeared despite BookFile=no_book")

        return {
            "schema_version": "ve1b-independent-single-move-contract-v2",
            "status": "PASS",
            "authority_status": "AUTOMATED_CALIBRATION_FIXTURE_NOT_PRODUCTION_AUTHORITY",
            "comparison_method": "independent_cold_single_move_multipv1",
            "nodes_semantics": "per_move",
            "fixture_node_budget": FIXTURE_N,
            "fixture_confirmation_tiers": FIXTURE_TIERS,
            "fv_scale": base.FV_SCALE,
            "tt_source_proof": tt_proof,
            "same_budget_reproducibility": {
                "interpretation": "reproducibility_only_not_stability",
                "run1": base.result_dict(repro1),
                "run2": base.result_dict(repro2),
            },
            "tt_order_independence": {
                "target_first": base.result_dict(order_b1),
                "unrelated_A": base.result_dict(unrelated),
                "target_after_A_and_cold_reset": base.result_dict(order_b2),
            },
            "candidate_discovery": {
                "tt_generations": discovery_generations,
                "runs": [base.result_dict(x) for x in discoveries],
            },
            "independent_single_move_comparisons": comparisons,
            "book_disabled_negative": {
                "without_fixture_file": base.result_dict(book_absent),
                "with_standard_book_db_present": base.result_dict(book_present),
            },
        }
    finally:
        e.close()
        if all_transcript:
            (out / "raw-usi-transcript.txt").write_text(
                "\n".join(all_transcript) + "\n", encoding="utf-8"
            )
        if book_file.exists():
            book_file.unlink()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--work", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    try:
        result = run_contract(args.work.resolve(), args.out.resolve())
    except Exception as exc:
        failure = {
            "schema_version": "ve1b-independent-single-move-contract-v2",
            "status": "FAIL",
            "authority_status": "AUTOMATED_CALIBRATION_FIXTURE_NOT_PRODUCTION_AUTHORITY",
            "error": str(exc),
        }
        (args.out / "result.json").write_text(
            json.dumps(failure, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(json.dumps(failure, indent=2, ensure_ascii=False))
        return 1

    (args.out / "result.json").write_text(
        json.dumps(result, indent=2, ensure_ascii=False, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({
        "status": result["status"],
        "authority_status": result["authority_status"],
        "comparison_method": result["comparison_method"],
        "nodes_semantics": result["nodes_semantics"],
        "fixture_confirmation_tiers": result["fixture_confirmation_tiers"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
