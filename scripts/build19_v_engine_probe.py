#!/usr/bin/env python3
import argparse
import json
import os
import subprocess
import sys
from pathlib import Path


def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--engine", required=True)
    p.add_argument("--eval-dir", required=True)
    p.add_argument("--requirements", required=True)
    p.add_argument("--human-candidates", required=True)
    p.add_argument("--continuity-real-game", required=True)
    p.add_argument("--output", required=True)
    p.add_argument("--low-ms", type=int, default=40)
    p.add_argument("--high-ms", type=int, default=120)
    p.add_argument("--continuity-count", type=int, default=14)
    return p.parse_args()


class USIEngine:
    def __init__(self, engine_path: str, eval_dir: str):
        self.proc = subprocess.Popen(
            [engine_path],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        self.eval_dir = eval_dir
        self._send("usi")
        self._read_until(lambda line: line.strip() == "usiok")
        self._send("setoption name Threads value 1")
        self._send("setoption name Hash value 128")
        self._send(f"setoption name EvalDir value {eval_dir}")
        self._send("setoption name MultiPV value 2")
        self._send("isready")
        self._read_until(lambda line: line.strip() == "readyok")
        self._send("usinewgame")

    def close(self):
        try:
            self._send("quit")
        except Exception:
            pass
        try:
            self.proc.wait(timeout=5)
        except Exception:
            self.proc.kill()

    def _send(self, line: str):
        if self.proc.stdin is None:
            raise RuntimeError("engine stdin unavailable")
        self.proc.stdin.write(line + "\n")
        self.proc.stdin.flush()

    def _read_until(self, predicate):
        if self.proc.stdout is None:
            raise RuntimeError("engine stdout unavailable")
        while True:
            line = self.proc.stdout.readline()
            if line == "":
                raise RuntimeError(f"engine terminated unexpectedly rc={self.proc.poll()}")
            if predicate(line):
                return line

    @staticmethod
    def _parse_info(line: str):
        parts = line.strip().split()
        if not parts or parts[0] != "info":
            return None
        data = {"multipv": 1, "pv": []}
        i = 1
        while i < len(parts):
            token = parts[i]
            if token in {"depth", "seldepth", "multipv", "nodes", "nps", "time"} and i + 1 < len(parts):
                try:
                    data[token] = int(parts[i + 1])
                except ValueError:
                    pass
                i += 2
                continue
            if token == "score" and i + 2 < len(parts):
                kind = parts[i + 1]
                try:
                    value = int(parts[i + 2])
                except ValueError:
                    i += 3
                    continue
                bound = None
                j = i + 3
                if j < len(parts) and parts[j] in {"lowerbound", "upperbound"}:
                    bound = "lower" if parts[j] == "lowerbound" else "upper"
                    j += 1
                data["score"] = {"kind": kind, "value": value, "bound": bound}
                i = j
                continue
            if token == "pv":
                data["pv"] = parts[i + 1 :]
                break
            i += 1
        if "score" not in data or not data.get("pv"):
            return None
        return data

    def search(self, position: str, movetime_ms: int, multipv: int = 1, searchmove: str | None = None):
        self._send(f"setoption name MultiPV value {multipv}")
        self._send("isready")
        self._read_until(lambda line: line.strip() == "readyok")
        self._send(position)
        command = f"go movetime {movetime_ms}"
        if searchmove:
            command += f" searchmoves {searchmove}"
        self._send(command)
        latest = {}
        bestmove = None
        if self.proc.stdout is None:
            raise RuntimeError("engine stdout unavailable")
        while True:
            line = self.proc.stdout.readline()
            if line == "":
                raise RuntimeError(f"engine terminated during search rc={self.proc.poll()}")
            stripped = line.strip()
            if stripped.startswith("info "):
                info = self._parse_info(stripped)
                if info:
                    latest[int(info.get("multipv", 1))] = info
            elif stripped.startswith("bestmove "):
                pieces = stripped.split()
                bestmove = pieces[1] if len(pieces) >= 2 else None
                break
        return {"bestmove": bestmove, "lines": [latest[k] for k in sorted(latest)]}


def score_order(score):
    if score["kind"] == "cp":
        return score["value"]
    value = score["value"]
    if value >= 0:
        return 10_000_000 - min(abs(value), 9999) * 1000
    return -10_000_000 + min(abs(value), 9999) * 1000


def line_for_move(result, move):
    for line in result["lines"]:
        pv = line.get("pv") or []
        if pv and pv[0] == move:
            return line
    return None


def forced(engine, position, move, movetime):
    result = engine.search(position, movetime, multipv=1, searchmove=move)
    line = result["lines"][0] if result["lines"] else None
    if line is None or not line.get("pv") or line["pv"][0] != move:
        raise RuntimeError(f"candidate-specific PV unavailable for {move}")
    return line


def continuation_stable(low_line, high_line, min_prefix=2):
    low = low_line.get("pv") or []
    high = high_line.get("pv") or []
    if len(low) < min_prefix or len(high) < min_prefix:
        return False
    return low[:min_prefix] == high[:min_prefix]


def build_pair(engine, base, low_ms, high_ms):
    position = base["position"]
    actual = base["currentMove"]

    discovery_low = engine.search(position, low_ms, multipv=2)
    discovery_high = engine.search(position, high_ms, multipv=2)
    if len(discovery_high["lines"]) < 2:
        raise RuntimeError(f"MultiPV2 unavailable for {base['id']}")
    high_top1 = discovery_high["lines"][0]
    high_top2 = discovery_high["lines"][1]
    if not high_top1["pv"] or not high_top2["pv"]:
        raise RuntimeError(f"empty discovery PV for {base['id']}")
    best_move = high_top1["pv"][0]
    second_move = high_top2["pv"][0]
    pair_kind = "BEST_VS_ACTUAL" if actual != best_move else "TOP1_VS_TOP2"
    other_move = actual if pair_kind == "BEST_VS_ACTUAL" else second_move

    best_low = forced(engine, position, best_move, low_ms)
    best_high = forced(engine, position, best_move, high_ms)
    other_low = forced(engine, position, other_move, low_ms)
    other_high = forced(engine, position, other_move, high_ms)

    discovery_best_stable = bool(
        discovery_low["lines"]
        and discovery_low["lines"][0].get("pv")
        and discovery_low["lines"][0]["pv"][0] == best_move
    )
    low_preference = score_order(best_low["score"]) >= score_order(other_low["score"])
    high_preference = score_order(best_high["score"]) >= score_order(other_high["score"])
    comparison_stable = discovery_best_stable and low_preference and high_preference

    best_cont = continuation_stable(best_low, best_high)
    other_cont = continuation_stable(other_low, other_high)
    continuation_stability = best_cont and other_cont

    return {
        **base,
        "pairKind": pair_kind,
        "search": {
            "engineContextID": "yaneuraou-a5ee2786-suisho5",
            "searchConditionID": f"candidate-root-movetime-{high_ms}ms",
            "lowMoveTimeMs": low_ms,
            "highMoveTimeMs": high_ms,
            "threads": 1,
            "hashMB": 128,
            "scorePerspective": "side_to_move",
        },
        "discovery": {
            "lowBestMove": discovery_low["lines"][0]["pv"][0] if discovery_low["lines"] and discovery_low["lines"][0].get("pv") else None,
            "highBestMove": best_move,
            "highSecondMove": second_move,
        },
        "comparisonStable": comparison_stable,
        "continuationStable": continuation_stability,
        "candidateA": {
            "candidateID": f"{base['id']}-A",
            "rank": 1,
            "move": best_move,
            "branchType": "recommended",
            "score": best_high["score"],
            "lowScore": best_low["score"],
            "pv": best_high["pv"],
            "lowPV": best_low["pv"],
            "continuationStable": best_cont,
        },
        "candidateB": {
            "candidateID": f"{base['id']}-B",
            "rank": 2,
            "move": other_move,
            "branchType": "actual" if pair_kind == "BEST_VS_ACTUAL" else "rankedCandidate",
            "score": other_high["score"],
            "lowScore": other_low["score"],
            "pv": other_high["pv"],
            "lowPV": other_low["pv"],
            "continuationStable": other_cont,
        },
    }


def requirement_records(requirements_path, candidate_path):
    req = json.loads(Path(requirements_path).read_text(encoding="utf-8"))
    human = json.loads(Path(candidate_path).read_text(encoding="utf-8"))
    records = human.get("records") or []
    out = []
    for sample in req.get("samples") or []:
        src = int(sample["src"])
        if src < 1 or src > len(records):
            raise RuntimeError(f"invalid Build19-P src index {src} for {sample['id']}")
        record = records[src - 1]
        if int(record.get("ply")) != int(sample["ply"]) or record.get("currentMove") != sample["move"]:
            raise RuntimeError(
                f"Build19-P recovery mismatch {sample['id']}: expected ply/move {sample['ply']}/{sample['move']} "
                f"got {record.get('ply')}/{record.get('currentMove')}"
            )
        out.append({
            "id": sample["id"],
            "group": "requirement",
            "gameID": record["gameID"],
            "ply": record["ply"],
            "position": record["position"],
            "currentMove": record["currentMove"],
            "phase": sample["phase"],
            "build18Intent": sample["intent"],
            "build18Confidence": sample["confidence"],
            "build18Trigger": sample["trigger"],
            "gapCategory": sample["gap"],
            "evidenceProfile": sample["evidenceProfile"],
        })
    if len(out) != 30:
        raise RuntimeError(f"expected 30 requirement records, got {len(out)}")
    return out


def continuity_records(path, count):
    doc = json.loads(Path(path).read_text(encoding="utf-8"))
    records = doc.get("records") or []
    if len(records) < count:
        raise RuntimeError(f"continuity source too small: {len(records)} < {count}")
    chosen = records[:count]
    game_ids = {r["gameID"] for r in chosen}
    if len(game_ids) != 1:
        raise RuntimeError("continuity records are not from one game")
    plies = [int(r["ply"]) for r in chosen]
    if any(b != a + 1 for a, b in zip(plies, plies[1:])):
        raise RuntimeError(f"continuity records are not consecutive: {plies}")
    return [{
        "id": f"B19V-CONT-{i+1:03d}",
        "group": "continuity",
        "gameID": r["gameID"],
        "ply": r["ply"],
        "position": r["position"],
        "currentMove": r["currentMove"],
        "phase": r.get("phase"),
        "build18Intent": r.get("primaryIntent"),
        "build18Confidence": r.get("confidence"),
        "build18Trigger": r.get("whyNowTrigger"),
        "gapCategory": "contiguous_repetition_validation",
        "evidenceProfile": "CONTIGUOUS",
    } for i, r in enumerate(chosen)]


def main():
    args = parse_args()
    requirements = requirement_records(args.requirements, args.human_candidates)
    continuity = continuity_records(args.continuity_real_game, args.continuity_count)
    selected = requirements + continuity

    engine = USIEngine(args.engine, args.eval_dir)
    results = []
    try:
        total = len(selected)
        for idx, base in enumerate(selected, 1):
            print(f"probe {idx}/{total} {base['id']} game={base['gameID']} ply={base['ply']}", flush=True)
            results.append(build_pair(engine, base, args.low_ms, args.high_ms))
    finally:
        engine.close()

    output = {
        "schemaVersion": 1,
        "stage": "Build19-V Independent Real-game / Semantic Validation",
        "engineAuthority": {
            "yaneuraouCommit": "a5ee2786c0030edc7d4a1cdfe94b04dffec55493",
            "evaluation": "Suisho5 via scripts/fetch_eval.sh",
            "lowMoveTimeMs": args.low_ms,
            "highMoveTimeMs": args.high_ms,
            "threads": 1,
            "hashMB": 128,
            "rootPolicy": "candidate-specific root restriction applied equally to both pair candidates",
        },
        "requirementRecordCount": len(requirements),
        "continuityRecordCount": len(continuity),
        "records": results,
    }
    Path(args.output).write_text(json.dumps(output, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"BUILD19_V_ENGINE_PROBE_PASS records={len(results)}")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"BUILD19_V_ENGINE_PROBE_FAIL: {exc}", file=sys.stderr)
        raise
