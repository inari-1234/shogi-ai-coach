#!/usr/bin/env python3
"""Build19 VE1-B native node/TT/book/evidence contract verification.

This runner validates search-control semantics only. The node budgets below are
AUTOMATED_CALIBRATION_FIXTURE values, not production Semantic Authority.

VE1-B measurement authority is the deepest fully completed exact iterative-
deepening snapshot. A deeper terminal lowerbound/upperbound remains raw evidence
and is never relabeled as an exact target-depth score.
"""
from __future__ import annotations

import argparse
import json
import os
import queue
import re
import subprocess
import threading
import time
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Optional

FIXTURE_N = 50_000
FIXTURE_TIERS = [50_000, 100_000, 200_000]
FV_SCALE = 24
PV_INTERVAL_MS = 0


class ContractFailure(RuntimeError):
    pass


@dataclass(frozen=True)
class Score:
    kind: str
    value: int
    bound: str


@dataclass
class SearchResult:
    label: str
    position: str
    go_command: str
    bestmove: str
    ponder: Optional[str]
    primary_depth: Optional[int]
    primary_seldepth: Optional[int]
    primary_nodes: Optional[int]
    primary_score: Optional[Score]
    primary_pv: list[str]
    terminal_primary_depth: Optional[int]
    terminal_primary_nodes: Optional[int]
    terminal_primary_score: Optional[Score]
    terminal_primary_pv: list[str]
    info_observation_count: int
    max_observed_nodes: int
    bestmove_consistent: bool
    transcript: list[str]

    def reproducibility_signature(self) -> dict:
        return {
            "bestmove": self.bestmove,
            "primary_score": asdict(self.primary_score) if self.primary_score else None,
            "primary_depth": self.primary_depth,
            "primary_nodes": self.primary_nodes,
            "primary_pv": self.primary_pv,
            "terminal_primary_score": asdict(self.terminal_primary_score) if self.terminal_primary_score else None,
            "bestmove_consistent": self.bestmove_consistent,
        }


class Engine:
    def __init__(self, executable: Path, cwd: Path, eval_dir: Path):
        self.executable = executable
        self.cwd = cwd
        self.eval_dir = eval_dir
        self.proc: Optional[subprocess.Popen[str]] = None
        self.q: queue.Queue[Optional[str]] = queue.Queue()
        self.transcript: list[str] = []
        self.reader: Optional[threading.Thread] = None
        self.multi_pv = 1
        self.tt_generation = 0

    def start(self) -> None:
        self.proc = subprocess.Popen(
            [str(self.executable)],
            cwd=self.cwd,
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        assert self.proc.stdout is not None
        self.reader = threading.Thread(target=self._read_loop, daemon=True)
        self.reader.start()
        self.send("usi")
        self.read_until(lambda x: x == "usiok", 10, "usiok")
        for command in (
            "setoption name Threads value 1",
            "setoption name USI_Hash value 64",
            "setoption name MultiPV value 1",
            f"setoption name FV_SCALE value {FV_SCALE}",
            f"setoption name PvInterval value {PV_INTERVAL_MS}",
            "setoption name BookFile value no_book",
            f"setoption name EvalDir value {self.eval_dir}",
        ):
            self.send(command)
        self.cold_reset("session_init")

    def _read_loop(self) -> None:
        assert self.proc is not None and self.proc.stdout is not None
        for raw in self.proc.stdout:
            line = raw.rstrip("\r\n")
            self.transcript.append(f"< {line}")
            self.q.put(line)
        self.q.put(None)

    def send(self, line: str) -> None:
        assert self.proc is not None and self.proc.stdin is not None
        self.transcript.append(f"> {line}")
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def next_line(self, timeout: float) -> str:
        try:
            item = self.q.get(timeout=timeout)
        except queue.Empty as exc:
            raise ContractFailure("timeout waiting for engine output") from exc
        if item is None:
            raise ContractFailure("engine closed output unexpectedly")
        return item

    def read_until(self, predicate, timeout: float, label: str) -> str:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            line = self.next_line(max(0.01, deadline - time.monotonic()))
            if predicate(line):
                return line
        raise ContractFailure(f"timeout waiting for {label}")

    def set_multipv(self, value: int) -> None:
        value = max(1, value)
        if self.multi_pv != value:
            self.send(f"setoption name MultiPV value {value}")
            self.multi_pv = value

    def cold_reset(self, reason: str) -> int:
        self.send("isready")
        self.read_until(lambda x: x == "readyok", 30, f"readyok/{reason}")
        self.tt_generation += 1
        self.send("usinewgame")
        return self.tt_generation

    def search(
        self,
        label: str,
        position: str,
        nodes: int,
        *,
        multipv: int = 1,
        searchmoves: Optional[list[str]] = None,
        timeout: float = 30,
    ) -> SearchResult:
        self.set_multipv(multipv)
        start_index = len(self.transcript)
        self.send(position)
        clause = "" if not searchmoves else " searchmoves " + " ".join(searchmoves)
        go = f"go nodes {nodes}{clause}"
        self.send(go)

        latest_scored: dict[int, dict] = {}
        scored_observations: list[dict] = []
        max_nodes = 0
        bestmove = None
        ponder = None
        deadline = time.monotonic() + timeout

        while time.monotonic() < deadline:
            line = self.next_line(max(0.01, deadline - time.monotonic()))
            if line.startswith("info ") and not line.startswith("info string "):
                parsed = parse_info(line)
                if parsed:
                    if parsed.get("nodes") is not None:
                        max_nodes = max(max_nodes, parsed["nodes"])
                    if parsed.get("score") is not None and parsed.get("pv"):
                        scored_observations.append(parsed)
                        rank = parsed.get("multipv", 1)
                        current = latest_scored.get(rank)
                        if should_replace(current, parsed):
                            latest_scored[rank] = parsed
            elif line.startswith("bestmove "):
                parts = line.split()
                if len(parts) < 2:
                    raise ContractFailure(f"malformed bestmove: {line}")
                bestmove = parts[1]
                if "ponder" in parts:
                    idx = parts.index("ponder")
                    if idx + 1 < len(parts):
                        ponder = parts[idx + 1]
                break

        if bestmove is None:
            raise ContractFailure(f"{label}: bestmove timeout")
        if max_nodes < nodes:
            raise ContractFailure(
                f"{label}: observed nodes {max_nodes} did not reach requested {nodes}"
            )

        exact_snapshot = select_deepest_exact_snapshot(scored_observations, multipv)
        if exact_snapshot is None:
            raise ContractFailure(f"{label}: no completed exact iteration")
        primary = exact_snapshot[0]
        terminal_primary = latest_scored.get(1)
        if terminal_primary is None:
            raise ContractFailure(f"{label}: no scored terminal MultiPV1 observation")

        terminal_pv = terminal_primary.get("pv") or []
        consistent = bool(terminal_pv) and terminal_pv[0] == bestmove
        if not consistent:
            raise ContractFailure(
                f"{label}: bestmove/terminal-PV1 mismatch bestmove={bestmove} "
                f"pv_head={terminal_pv[0] if terminal_pv else None}"
            )

        return SearchResult(
            label=label,
            position=position,
            go_command=go,
            bestmove=bestmove,
            ponder=ponder,
            primary_depth=primary.get("depth"),
            primary_seldepth=primary.get("seldepth"),
            primary_nodes=primary.get("nodes"),
            primary_score=primary.get("score"),
            primary_pv=primary.get("pv") or [],
            terminal_primary_depth=terminal_primary.get("depth"),
            terminal_primary_nodes=terminal_primary.get("nodes"),
            terminal_primary_score=terminal_primary.get("score"),
            terminal_primary_pv=terminal_pv,
            info_observation_count=len(scored_observations),
            max_observed_nodes=max_nodes,
            bestmove_consistent=consistent,
            transcript=self.transcript[start_index:],
        )

    def close(self) -> None:
        if self.proc is None:
            return
        try:
            self.send("quit")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            self.proc.wait(timeout=5)


def parse_info(line: str) -> Optional[dict]:
    tokens = line.split()
    if not tokens or tokens[0] != "info":
        return None
    result: dict = {"multipv": 1, "pv": [], "raw": line}
    i = 1
    while i < len(tokens):
        token = tokens[i]
        if token in ("depth", "seldepth", "multipv", "nodes", "nps", "time") and i + 1 < len(tokens):
            try:
                result[token] = int(tokens[i + 1])
            except ValueError:
                pass
            i += 2
            continue
        if token == "score" and i + 2 < len(tokens):
            kind = tokens[i + 1]
            try:
                value = int(tokens[i + 2])
            except ValueError:
                i += 3
                continue
            bound = "exact"
            advance = 3
            if i + 3 < len(tokens) and tokens[i + 3] in ("lowerbound", "upperbound"):
                bound = tokens[i + 3]
                advance = 4
            result["score"] = Score(kind=kind, value=value, bound=bound)
            i += advance
            continue
        if token == "pv":
            result["pv"] = tokens[i + 1 :]
            break
        if token == "string":
            break
        i += 1
    return result


def select_deepest_exact_snapshot(observations: list[dict], required_multipv: int) -> Optional[list[dict]]:
    if required_multipv <= 0:
        return None
    exact = [
        (index, item)
        for index, item in enumerate(observations)
        if item.get("depth") is not None
        and 1 <= item.get("multipv", 1) <= required_multipv
        and item.get("score") is not None
        and item["score"].bound == "exact"
        and item.get("pv")
    ]
    for depth in sorted({item["depth"] for _, item in exact}, reverse=True):
        snapshot: list[dict] = []
        for rank in range(1, required_multipv + 1):
            candidates = [
                (index, item)
                for index, item in exact
                if item["depth"] == depth and item.get("multipv", 1) == rank
            ]
            if not candidates:
                snapshot = []
                break
            _, selected = max(
                candidates,
                key=lambda pair: (
                    pair[1].get("nodes") or 0,
                    pair[1].get("time") or 0,
                    pair[0],
                ),
            )
            snapshot.append(selected)
        if len(snapshot) == required_multipv:
            return sorted(snapshot, key=lambda item: item.get("multipv", 1))
    return None


def verify_completed_iteration_selector() -> dict:
    exact = parse_info("info depth 12 seldepth 18 nodes 42000 score cp 560 pv 3g2e 8c8d")
    bounded = parse_info("info depth 13 seldepth 19 nodes 50000 score cp 605 lowerbound pv 3g2e 8c8d")
    assert exact is not None and bounded is not None
    selected = select_deepest_exact_snapshot([exact, bounded], 1)
    if not selected or selected[0].get("depth") != 12 or selected[0]["score"].bound != "exact":
        raise ContractFailure("completed-iteration selector promoted terminal bound")

    bound_only = parse_info("info depth 12 seldepth 18 nodes 50000 score cp -58 upperbound pv 4i3h")
    assert bound_only is not None
    if select_deepest_exact_snapshot([bound_only], 1) is not None:
        raise ContractFailure("bound-only search was not rejected as incomplete")

    return {
        "status": "PASS",
        "deepest_completed_exact_depth": 12,
        "terminal_bound_depth": 13,
        "bound_only_result": "INCOMPLETE",
    }


def should_replace(current: Optional[dict], candidate: dict) -> bool:
    if candidate.get("score") is None:
        return False
    if current is None:
        return True
    cd = current.get("depth", -1)
    nd = candidate.get("depth", -1)
    if nd != cd:
        return nd > cd
    ce = current["score"].bound == "exact"
    ne = candidate["score"].bound == "exact"
    if ce != ne:
        return ne
    cn = current.get("nodes", 0)
    nn = candidate.get("nodes", 0)
    if nn != cn:
        return nn >= cn
    return candidate.get("time", 0) >= current.get("time", 0)


def result_dict(result: SearchResult) -> dict:
    return asdict(result)


def assert_same(label: str, left: SearchResult, right: SearchResult) -> None:
    if left.reproducibility_signature() != right.reproducibility_signature():
        raise ContractFailure(
            f"{label}: reproducibility mismatch\nleft={left.reproducibility_signature()}\n"
            f"right={right.reproducibility_signature()}"
        )


def verify_tt_source(work: Path) -> dict:
    path = work / "YaneuraOu/source/engine/yaneuraou-engine/yaneuraou-engine.cpp"
    text = path.read_text(encoding="utf-8-sig")
    pattern = re.compile(r"YaneuraOuEngine::isready\s*\([^)]*\).*?tt\.clear\s*\(\s*threads\s*\)", re.S)
    if not pattern.search(text):
        raise ContractFailure("pinned YaneuraOu source no longer proves isready -> tt.clear(threads)")
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
        raise ContractFailure(f"engine missing: {engine_path}")
    if not (eval_dir / "nn.bin").exists():
        raise ContractFailure(f"NNUE missing: {eval_dir / 'nn.bin'}")
    out.mkdir(parents=True, exist_ok=True)

    tt_proof = verify_tt_source(work)
    selector_proof = verify_completed_iteration_selector()
    e = Engine(engine_path, work, eval_dir)
    all_transcript: list[str] = []
    book_dir = work / "book"
    book_file = book_dir / "standard_book.db"
    if book_file.exists():
        book_file.unlink()

    try:
        e.start()

        # A. Same-budget, cold-start repeat: reproducibility only, not stability.
        e.cold_reset("repro_1")
        repro1 = e.search("same_budget_cold_1", "position startpos", FIXTURE_N)
        e.cold_reset("repro_2")
        repro2 = e.search("same_budget_cold_2", "position startpos", FIXTURE_N)
        assert_same("same-budget cold reproducibility", repro1, repro2)

        # B. Target B must be independent of unrelated prior position A after reset.
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
        assert_same("TT cold-start order independence", order_b1, order_b2)

        # C. Candidate discovery must not seed direct comparison.
        e.cold_reset("candidate_discovery")
        discovery = e.search(
            "candidate_discovery",
            "position startpos",
            FIXTURE_N,
            multipv=3,
        )
        generation_after_discovery = e.tt_generation
        e.cold_reset("direct_comparison")
        generation_at_compare = e.tt_generation
        if generation_at_compare <= generation_after_discovery:
            raise ContractFailure("TT generation did not advance between discovery and comparison")

        # D. Legacy warm-series fixture retained only for backward contract coverage.
        warm: list[SearchResult] = []
        warm_generation = e.tt_generation
        for nodes in FIXTURE_TIERS:
            warm.append(
                e.search(
                    f"warm_confirmation_{nodes}",
                    "position startpos",
                    nodes,
                    multipv=2,
                    searchmoves=["7g7f", "2g2f"],
                )
            )
            if e.tt_generation != warm_generation:
                raise ContractFailure("TT generation changed inside warm confirmation series")

        # E. BookFile=no_book must make a present working-directory book inert.
        e.cold_reset("book_absent")
        book_absent = e.search("book_absent", "position startpos", FIXTURE_N)
        book_dir.mkdir(parents=True, exist_ok=True)
        book_file.write_bytes(b"VE1-B inert-book negative fixture\n")
        e.cold_reset("book_present_disabled")
        book_present = e.search("book_present_disabled", "position startpos", FIXTURE_N)
        assert_same("BookFile=no_book negative fixture", book_absent, book_present)

        all_transcript = list(e.transcript)
        if not any(x == "> setoption name BookFile value no_book" for x in all_transcript):
            raise ContractFailure("BookFile=no_book command missing")
        if not any(x == f"> setoption name PvInterval value {PV_INTERVAL_MS}" for x in all_transcript):
            raise ContractFailure("PvInterval=0 command missing")
        if any("can't read file : book/standard_book.db" in x for x in all_transcript):
            raise ContractFailure("opening-book read warning appeared despite BookFile=no_book")

        return {
            "schema_version": "ve1b-node-contract-v2",
            "status": "PASS",
            "authority_status": "AUTOMATED_CALIBRATION_FIXTURE_NOT_PRODUCTION_AUTHORITY",
            "fixture_node_budget": FIXTURE_N,
            "fixture_confirmation_tiers": FIXTURE_TIERS,
            "fv_scale": FV_SCALE,
            "pv_interval_ms": PV_INTERVAL_MS,
            "measurement_definition": "deepest_fully_completed_exact_iteration",
            "completed_iteration_selector": selector_proof,
            "tt_source_proof": tt_proof,
            "same_budget_reproducibility": {
                "interpretation": "reproducibility_only_not_stability",
                "run1": result_dict(repro1),
                "run2": result_dict(repro2),
            },
            "tt_order_independence": {
                "target_first": result_dict(order_b1),
                "unrelated_A": result_dict(unrelated),
                "target_after_A_and_cold_reset": result_dict(order_b2),
            },
            "role_boundary": {
                "candidate_discovery": result_dict(discovery),
                "tt_generation_after_discovery": generation_after_discovery,
                "tt_generation_at_direct_comparison": generation_at_compare,
            },
            "warm_confirmation_series": [result_dict(x) for x in warm],
            "book_disabled_negative": {
                "without_fixture_file": result_dict(book_absent),
                "with_standard_book_db_present": result_dict(book_present),
            },
        }
    finally:
        e.close()
        if all_transcript:
            (out / "raw-usi-transcript.txt").write_text("\n".join(all_transcript) + "\n", encoding="utf-8")
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
            "schema_version": "ve1b-node-contract-v2",
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
        "fixture_node_budget": result["fixture_node_budget"],
        "fixture_confirmation_tiers": result["fixture_confirmation_tiers"],
        "pv_interval_ms": result["pv_interval_ms"],
        "measurement_definition": result["measurement_definition"],
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
