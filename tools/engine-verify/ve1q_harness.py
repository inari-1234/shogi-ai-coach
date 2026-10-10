#!/usr/bin/env python3
from __future__ import annotations

import dataclasses
import datetime as dt
import hashlib
import json
import os
import platform
import re
import subprocess
from pathlib import Path
from typing import Any, Iterable

TOOL_DIR = Path(__file__).resolve().parent
REPO_ROOT = TOOL_DIR.parent.parent
EXPECTED_ENGINE_PIN = "a5ee2786c0030edc7d4a1cdfe94b04dffec55493"
EXPECTED_NNUE_SHA256 = "768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"
PROFILE_SCHEMA = "ve1q-profile-v1"
PARITY_SCHEMA = "ve1q-parity-v1"
KNOWN_SCHEMA = "ve1q-known-answer-v1"
NEGATIVE_SCHEMA = "ve1q-negative-v1"
RESULT_SCHEMA = "ve1q-results-v1"
HARNESS_VERSION = "Build19-VE1-Q/1.0"

class QualificationError(RuntimeError):
    pass

class ValidationError(QualificationError):
    def __init__(self, code: str, message: str | None = None):
        self.code = code
        super().__init__(message or code)


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def canonical_sha(obj: Any) -> str:
    return sha256_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":")))


def read_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as f:
        return json.load(f)


def write_json(path: Path, obj: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def git_value(*args: str) -> str | None:
    try:
        return subprocess.check_output(["git", "-C", str(REPO_ROOT), *args], text=True, stderr=subprocess.DEVNULL).strip()
    except Exception:
        return None


def tool_source_hash() -> str:
    names = [
        "profiles.json", "ve1q_harness.py", "qualify.py", "swift_parity_probe.swift",
        "fixtures/parity/parity-cases.json", "fixtures/known-answer/known-answer.json",
        "fixtures/negative/negative-cases.json",
    ]
    h = hashlib.sha256()
    for name in names:
        p = TOOL_DIR / name
        if not p.exists():
            raise ValidationError("missing-tool-source", name)
        h.update(name.encode()); h.update(b"\0"); h.update(p.read_bytes()); h.update(b"\0")
    return h.hexdigest()


def load_profiles(path: Path | None = None) -> dict[str, dict[str, Any]]:
    path = path or TOOL_DIR / "profiles.json"
    data = read_json(path)
    if data.get("schema_version") != PROFILE_SCHEMA:
        raise ValidationError("incompatible-schema-version", f"profiles: {data.get('schema_version')}")
    profiles = data.get("profiles")
    if not isinstance(profiles, dict):
        raise ValidationError("broken-profile-set")
    required_names = {"app-current", "app-candidate", "reference"}
    if set(profiles) != required_names:
        raise ValidationError("profile-set-mismatch", repr(sorted(profiles)))
    for name, p in profiles.items(): validate_profile_config(name, p)
    return profiles


def validate_profile_config(name: str, p: dict[str, Any]) -> None:
    expected: dict[str, dict[str, Any]] = {
        "app-current": {"fv_scale": 16, "search_mode": "movetime", "threads": 1, "hash_mb": 64, "multipv": 3, "pv_interval_ms": 0},
        "app-candidate": {"fv_scale": 24, "search_mode": "nodes", "threads": 1, "hash_mb": 64, "multipv": 3, "pv_interval_ms": 0},
        "reference": {"fv_scale": 24, "search_mode": "nodes", "pv_interval_ms": 0},
    }
    if name not in expected: raise ValidationError("unknown-profile", name)
    for k, v in expected[name].items():
        if p.get(k) != v: raise ValidationError("profile-requirement-mismatch", f"{name}.{k}: {p.get(k)!r} != {v!r}")
    for k in ("threads", "hash_mb", "multipv"):
        if not isinstance(p.get(k), int) or p[k] < 1: raise ValidationError("profile-invalid-setting", f"{name}.{k}")
    if not isinstance(p.get("pv_interval_ms"), int) or p["pv_interval_ms"] != 0:
        raise ValidationError("profile-requirement-mismatch", f"{name}.pv_interval_ms must be 0")
    if p["search_mode"] == "nodes":
        if not isinstance(p.get("nodes"), int) or p["nodes"] <= 0: raise ValidationError("profile-missing-budget", name)
    elif p["search_mode"] == "movetime":
        if not isinstance(p.get("movetime_ms"), int) or p["movetime_ms"] <= 0: raise ValidationError("profile-missing-budget", name)
    else: raise ValidationError("profile-invalid-search-mode", name)


def effective_profile(name: str, overrides: dict[str, Any] | None = None) -> dict[str, Any]:
    profiles = load_profiles()
    if name not in profiles: raise ValidationError("unknown-profile", name)
    p = dict(profiles[name])
    if overrides: p.update({k: v for k, v in overrides.items() if v is not None})
    validate_profile_config(name, p)
    return p


def _int_or_none(s: str) -> int | None:
    try: return int(s)
    except (TypeError, ValueError): return None


def parse_info_swift_compatible(line: str) -> dict[str, Any] | None:
    tokens = line.split()
    if not tokens or tokens[0] != "info": return None
    result: dict[str, Any] = {"depth": None, "seldepth": None, "multipv": 1, "score": None, "nodes": None, "nps": None, "time": None, "pv": []}
    i = 1
    while i < len(tokens):
        t = tokens[i]
        if t == "depth":
            if i + 1 < len(tokens): result["depth"] = _int_or_none(tokens[i + 1]); i += 2
            else: i += 1
        elif t == "seldepth":
            if i + 1 < len(tokens): result["seldepth"] = _int_or_none(tokens[i + 1]); i += 2
            else: i += 1
        elif t == "multipv":
            if i + 1 < len(tokens): result["multipv"] = _int_or_none(tokens[i + 1]) or 1; i += 2
            else: i += 1
        elif t == "nodes":
            if i + 1 < len(tokens): result["nodes"] = _int_or_none(tokens[i + 1]); i += 2
            else: i += 1
        elif t == "nps":
            if i + 1 < len(tokens): result["nps"] = _int_or_none(tokens[i + 1]); i += 2
            else: i += 1
        elif t == "time":
            if i + 1 < len(tokens): result["time"] = _int_or_none(tokens[i + 1]); i += 2
            else: i += 1
        elif t == "score":
            if i + 2 >= len(tokens): i += 1; continue
            kind = tokens[i + 1]; raw = _int_or_none(tokens[i + 2])
            if raw is None: i += 3; continue
            bound = None; advance = 3
            if i + 3 < len(tokens):
                if tokens[i + 3] == "lowerbound": bound = "lower"; advance = 4
                if tokens[i + 3] == "upperbound": bound = "upper"; advance = 4
            if kind == "cp": result["score"] = {"type": "cp", "value": raw, "bound": bound}
            if kind == "mate": result["score"] = {"type": "mate", "value": raw, "bound": bound}
            i += advance
        elif t == "pv": result["pv"] = tokens[i + 1:]; i = len(tokens)
        elif t == "string": i = len(tokens)
        else: i += 1
    return result


def parse_bestmove_swift_compatible(line: str) -> dict[str, Any] | None:
    tokens = line.split()
    if len(tokens) < 2 or tokens[0] != "bestmove": return None
    ponder = None
    if "ponder" in tokens:
        i = tokens.index("ponder")
        if i + 1 < len(tokens): ponder = tokens[i + 1]
    return {"move": tokens[1], "ponder": ponder}


def swift_compatible_accumulate(lines: Iterable[str]) -> dict[str, Any]:
    latest: dict[int, dict[str, Any]] = {}
    for line in lines:
        info = parse_info_swift_compatible(line)
        if info is not None and info["pv"]:
            rank = info["multipv"]; current = latest.get(rank)
            if current is None: latest[rank] = info
            else:
                cd = current["depth"] if current["depth"] is not None else -1; nd = info["depth"] if info["depth"] is not None else -1
                ct = current["time"] or 0; nt = info["time"] or 0
                if nd > cd or (nd == cd and nt >= ct): latest[rank] = info
            continue
        best = parse_bestmove_swift_compatible(line)
        if best is not None:
            return {"bestmove": best["move"], "ponder": best["ponder"], "principalVariations": [latest[k] for k in sorted(latest)]}
    return {"bestmove": None, "ponder": None, "principalVariations": []}


def _strict_line_checks(line: str) -> list[str]:
    issues: list[str] = []; tokens = line.split()
    if not tokens or tokens[0] != "info" or (len(tokens) > 1 and tokens[1] == "string"): return issues
    numeric = {"depth", "seldepth", "multipv", "nodes", "nps", "time"}; i = 1
    while i < len(tokens):
        t = tokens[i]
        if t in numeric:
            if i + 1 >= len(tokens) or _int_or_none(tokens[i + 1]) is None: issues.append("malformed-info"); break
            i += 2; continue
        if t == "score":
            if i + 2 >= len(tokens) or tokens[i + 1] not in {"cp", "mate"} or _int_or_none(tokens[i + 2]) is None: issues.append("malformed-info"); break
            i += 3
            if i < len(tokens) and tokens[i] in {"lowerbound", "upperbound"}: i += 1
            continue
        if t == "pv": break
        i += 1
    has_pv = "pv" in tokens and tokens.index("pv") + 1 < len(tokens); has_score = "score" in tokens and tokens.index("score") + 2 < len(tokens)
    if has_pv and not has_score: issues.append("missing-score")
    if has_score and not has_pv: issues.append("missing-pv")
    return issues


def strict_select(lines: Iterable[str], *, allow_bounds: bool = True) -> dict[str, Any]:
    latest: dict[int, dict[str, Any]] = {}; bestmove: dict[str, Any] | None = None
    for line in lines:
        info = parse_info_swift_compatible(line)
        if info is not None and info["pv"] and info["score"] is not None:
            if allow_bounds or info["score"]["bound"] is None: latest[info["multipv"]] = info
        best = parse_bestmove_swift_compatible(line)
        if best is not None: bestmove = best; break
    return {"bestmove": None if bestmove is None else bestmove["move"], "ponder": None if bestmove is None else bestmove["ponder"], "principalVariations": [latest[k] for k in sorted(latest)]}


def strict_validate_raw_log(path: Path, *, allow_bounds: bool = True, require_complete_fields: bool = False) -> dict[str, Any]:
    if not path.exists(): raise ValidationError("missing-raw-log", str(path))
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines: raise ValidationError("empty-raw-log")
    for line in lines:
        for issue in _strict_line_checks(line): raise ValidationError(issue, line)
    result = strict_select(lines, allow_bounds=allow_bounds)
    if result["bestmove"] is None: raise ValidationError("missing-bestmove")
    pvs = result["principalVariations"]
    if not pvs: raise ValidationError("missing-pv")
    if pvs[0]["pv"][0] != result["bestmove"] and result["bestmove"] not in {"resign", "win", "none"}: raise ValidationError("bestmove-primary-pv-mismatch")
    for pv in pvs:
        if pv["score"] is None: raise ValidationError("missing-score")
        if not allow_bounds and pv["score"]["bound"] is not None: raise ValidationError("bound-not-exact")
        if require_complete_fields:
            for k in ("depth", "seldepth", "nodes"):
                if pv[k] is None: raise ValidationError("missing-deterministic-field", k)
            if not pv["pv"]: raise ValidationError("missing-pv")
    return result


def deterministic_repro_view(result: dict[str, Any]) -> dict[str, Any]:
    return {"bestmove": result["bestmove"], "principalVariations": [{"multipv": p["multipv"], "score": p["score"], "depth": p["depth"], "seldepth": p["seldepth"], "nodes": p["nodes"], "pv": p["pv"]} for p in result["principalVariations"]]}


def parse_sfen(sfen: str) -> tuple[dict[tuple[int, int], tuple[str, str]], str]:
    parts = sfen.split()
    if len(parts) != 4: raise ValidationError("illegal-fixture", "SFEN requires 4 fields")
    board_part, side, _hands, move_no = parts
    if side not in {"b", "w"} or not move_no.isdigit(): raise ValidationError("illegal-fixture", "bad side/move number")
    rows = board_part.split("/")
    if len(rows) != 9: raise ValidationError("illegal-fixture", "bad row count")
    board: dict[tuple[int, int], tuple[str, str]] = {}
    for rank, row in enumerate(rows, start=1):
        file = 9; promoted = False
        for ch in row:
            if ch == "+":
                if promoted: raise ValidationError("illegal-fixture", "double promotion marker")
                promoted = True; continue
            if ch.isdigit():
                if promoted: raise ValidationError("illegal-fixture", "promotion before empty")
                file -= int(ch); continue
            base = ch.upper()
            if base not in "PLNSGBRK" or not (1 <= file <= 9): raise ValidationError("illegal-fixture", f"bad piece {ch}")
            color = "b" if ch.isupper() else "w"; piece = ("+" if promoted else "") + base
            board[(file, rank)] = (color, piece); file -= 1; promoted = False
        if promoted or file != 0: raise ValidationError("illegal-fixture", f"bad row width: {row}")
    kings = {c: sum(1 for c2, p in board.values() if c2 == c and p == "K") for c in ("b", "w")}
    if kings != {"b": 1, "w": 1}: raise ValidationError("illegal-fixture", f"king count {kings}")
    return board, side


def _path_clear(board: dict[tuple[int, int], tuple[str, str]], a: tuple[int,int], b: tuple[int,int]) -> bool:
    df = (b[0] > a[0]) - (b[0] < a[0]); dr = (b[1] > a[1]) - (b[1] < a[1]); f, r = a[0] + df, a[1] + dr
    while (f, r) != b:
        if (f, r) in board: return False
        f += df; r += dr
    return True


def attacks(board: dict[tuple[int,int], tuple[str,str]], origin: tuple[int,int], target: tuple[int,int]) -> bool:
    color, piece = board[origin]; df = target[0] - origin[0]; dr = target[1] - origin[1]; forward = -1 if color == "b" else 1; p = piece
    if p in {"+P", "+L", "+N", "+S"}: p = "G"
    if p == "K": return max(abs(df), abs(dr)) == 1
    if p == "G": return (df, dr) in {(-1, forward),(0, forward),(1, forward),(-1,0),(1,0),(0,-forward)}
    if p == "S": return (df, dr) in {(-1, forward),(0, forward),(1, forward),(-1,-forward),(1,-forward)}
    if p == "N": return (df, dr) in {(-1, 2*forward),(1, 2*forward)}
    if p == "P": return (df, dr) == (0, forward)
    if p == "L": return df == 0 and dr * forward > 0 and _path_clear(board, origin, target)
    if p in {"B", "+B"}:
        if abs(df) == abs(dr) and df != 0 and _path_clear(board, origin, target): return True
        return p == "+B" and ((abs(df), abs(dr)) in {(1,0),(0,1)})
    if p in {"R", "+R"}:
        if ((df == 0) != (dr == 0)) and _path_clear(board, origin, target): return True
        return p == "+R" and abs(df) == abs(dr) == 1
    return False


def is_in_check(sfen: str) -> bool:
    board, side = parse_sfen(sfen); king = next(sq for sq, (c,p) in board.items() if c == side and p == "K"); enemy = "w" if side == "b" else "b"
    return any(c == enemy and attacks(board, sq, king) for sq, (c,_p) in board.items())


def threat_probe_allowed(sfen: str) -> bool: return not is_in_check(sfen)

USI_MOVE_RE = re.compile(r"^(?:[1-9][a-i][1-9][a-i]\+?|[PLNSGBR]\*[1-9][a-i])$")

def validate_candidate_list(candidates: Any) -> None:
    if not isinstance(candidates, list) or not candidates: raise ValidationError("broken-candidate-list")
    if any(not isinstance(x, str) or not USI_MOVE_RE.match(x) for x in candidates): raise ValidationError("broken-candidate-list")
    if len(candidates) != len(set(candidates)): raise ValidationError("broken-candidate-list")


def validate_known_fixture(data: dict[str, Any]) -> None:
    if data.get("schema_version") != KNOWN_SCHEMA: raise ValidationError("incompatible-schema-version")
    cases = data.get("cases")
    if not isinstance(cases, list) or len(cases) < 12: raise ValidationError("illegal-fixture", "known-answer cases")
    ids = [c.get("id") for c in cases]
    if any(not isinstance(x, str) or not x for x in ids) or len(ids) != len(set(ids)): raise ValidationError("illegal-fixture", "case ids")
    for c in cases:
        if "sfen" in c: parse_sfen(c["sfen"])
        if "searchmoves" in c: validate_candidate_list(c["searchmoves"])
        if "raw_log" in c and not (TOOL_DIR / c["raw_log"]).exists(): raise ValidationError("missing-raw-log", c["raw_log"])

@dataclasses.dataclass
class EngineRun:
    id: str; profile: str; config: dict[str, Any]; raw_log_path: Path; started_at: str
    ended_at: str | None = None; exit_status: str = "RUNNING"
    usi_options_reported: list[str] = dataclasses.field(default_factory=list); options_applied: dict[str, Any] = dataclasses.field(default_factory=dict)

class Engine:
    def __init__(self, work: Path, profile_name: str, config: dict[str, Any], raw_log: Path):
        self.work = work; self.profile_name = profile_name; self.config = config; raw_log.parent.mkdir(parents=True, exist_ok=True); self.log = raw_log.open("w", encoding="utf-8")
        self.p = subprocess.Popen([str((work / "engine").resolve())], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1, cwd=str(work))
        self.usi_options_reported: list[str] = []
        self.options_applied = {"Threads": config["threads"], "USI_Hash": config["hash_mb"], "MultiPV": config["multipv"], "FV_SCALE": config["fv_scale"], "PvInterval": config["pv_interval_ms"], "EvalDir": str((work / "eval").resolve()), "BookFile": "no_book"}
        self.send("usi")
        for line in self._read_until_prefix("usiok"):
            if line.startswith("option name "): self.usi_options_reported.append(line)
        advertised = {line.split(" name ",1)[1].split(" type ",1)[0] for line in self.usi_options_reported if " type " in line}
        for required in ("Threads", "USI_Hash", "MultiPV", "FV_SCALE", "PvInterval", "EvalDir"):
            if required not in advertised: raise ValidationError("engine-option-missing", required)
        for k, v in self.options_applied.items(): self.send(f"setoption name {k} value {v}")
        self.send("isready"); self._read_until_prefix("readyok"); self.send("usinewgame")

    def send(self, cmd: str) -> None:
        self.log.write("> " + cmd + "\n"); self.log.flush(); assert self.p.stdin is not None; self.p.stdin.write(cmd + "\n"); self.p.stdin.flush()

    def _read_until_prefix(self, prefix: str) -> list[str]:
        out = []; assert self.p.stdout is not None
        while True:
            line = self.p.stdout.readline()
            if not line: raise QualificationError("engine exited before " + prefix)
            line = line.rstrip("\r\n"); self.log.write(line + "\n"); self.log.flush(); out.append(line)
            if "Illegal Input Move" in line or "illegal input move" in line.lower(): raise ValidationError("illegal-move", line)
            if line.startswith(prefix): return out

    def go(self, position: str, search: str, *, multipv: int | None = None) -> list[str]:
        if multipv is not None: self.send(f"setoption name MultiPV value {multipv}")
        self.send(position); self.send("go " + search); return self._read_until_prefix("bestmove")

    def close(self) -> int:
        try: self.send("quit"); rc = self.p.wait(timeout=10)
        except Exception: self.p.kill(); rc = self.p.wait(timeout=5)
        self.log.close(); return rc


def search_command(config: dict[str, Any], *, searchmoves: list[str] | None = None) -> str:
    cmd = f"nodes {config['nodes']}" if config["search_mode"] == "nodes" else f"movetime {config['movetime_ms']}"
    if searchmoves: validate_candidate_list(searchmoves); cmd += " searchmoves " + " ".join(searchmoves)
    return cmd


def base_provenance(work: Path) -> dict[str, Any]:
    setup_path = work / "provenance.json"
    if not setup_path.exists(): raise ValidationError("missing-provenance", str(setup_path))
    setup = read_json(setup_path); required_setup = ["engine_commit", "engine_sha256", "nnue_sha256", "compiler", "target_cpu"]
    if any(not setup.get(k) for k in required_setup): raise ValidationError("missing-provenance", "setup provenance")
    if setup["engine_commit"] != EXPECTED_ENGINE_PIN: raise ValidationError("engine-pin-mismatch")
    if setup["nnue_sha256"] != EXPECTED_NNUE_SHA256: raise ValidationError("nnue-sha-mismatch")
    engine = (work / "engine").resolve(); nnue = work / "eval" / "nn.bin"
    if not engine.exists() or not nnue.exists(): raise ValidationError("missing-engine-artifact")
    if sha256_file(engine) != setup["engine_sha256"]: raise ValidationError("engine-sha-mismatch")
    if sha256_file(nnue) != EXPECTED_NNUE_SHA256: raise ValidationError("nnue-sha-mismatch")
    return {"repository": "inari-1234/shogi-ai-coach", "repository_head": git_value("rev-parse", "HEAD") or os.environ.get("GITHUB_SHA") or "UNKNOWN", "repository_branch": git_value("rev-parse", "--abbrev-ref", "HEAD") or os.environ.get("GITHUB_REF_NAME") or "UNKNOWN", "harness_version": HARNESS_VERSION, "tool_commit": git_value("rev-parse", "HEAD") or os.environ.get("GITHUB_SHA") or "UNKNOWN", "tool_source_sha256": tool_source_hash(), "yaneuraou_commit": setup["engine_commit"], "engine_binary_sha256": setup["engine_sha256"], "nnue_sha256": setup["nnue_sha256"], "compiler": setup.get("compiler"), "compiler_version": setup.get("compiler_version"), "target_cpu": setup.get("target_cpu"), "build_command": setup.get("build_command"), "engine_patches": setup.get("engine_patches", []), "os": platform.platform(), "cpu_architecture": platform.machine(), "cpu_model": platform.processor() or None, "python_version": platform.python_version()}


def run_provenance(base: dict[str, Any], run: EngineRun, fixture_obj: Any) -> dict[str, Any]:
    p = dict(base); p.update({"run_id": run.id, "fixture_sha256": canonical_sha(fixture_obj), "full_usi_options": run.usi_options_reported, "options_applied": run.options_applied, "profile": run.profile, "search_mode": run.config["search_mode"], "node_budget": run.config.get("nodes"), "movetime_ms": run.config.get("movetime_ms"), "threads": run.config["threads"], "hash_mb": run.config["hash_mb"], "multipv": run.config["multipv"], "fv_scale": run.config["fv_scale"], "pv_interval_ms": run.config["pv_interval_ms"], "raw_usi_log_path": str(run.raw_log_path), "start_timestamp": run.started_at, "end_timestamp": run.ended_at, "exit_status": run.exit_status}); validate_provenance(p); return p


def validate_provenance(p: dict[str, Any]) -> None:
    required = ["repository", "harness_version", "tool_commit", "tool_source_sha256", "yaneuraou_commit", "engine_binary_sha256", "nnue_sha256", "fixture_sha256", "full_usi_options", "profile", "search_mode", "threads", "hash_mb", "multipv", "fv_scale", "pv_interval_ms", "os", "cpu_architecture", "python_version", "raw_usi_log_path", "start_timestamp", "end_timestamp", "exit_status"]
    missing = [k for k in required if k not in p or p[k] is None or p[k] == ""]
    if missing: raise ValidationError("missing-provenance", ",".join(missing))
    if not re.fullmatch(r"[0-9a-f]{40}", str(p.get("tool_commit", ""))): raise ValidationError("missing-provenance", "tool_commit")
    if p["yaneuraou_commit"] != EXPECTED_ENGINE_PIN: raise ValidationError("engine-pin-mismatch")
    if p["nnue_sha256"] != EXPECTED_NNUE_SHA256: raise ValidationError("nnue-sha-mismatch")
    profiles = load_profiles()
    if p["profile"] not in profiles: raise ValidationError("unknown-profile")
    if p["fv_scale"] != profiles[p["profile"]]["fv_scale"]: raise ValidationError("profile-requirement-mismatch")
    if p["pv_interval_ms"] != profiles[p["profile"]]["pv_interval_ms"] or p["pv_interval_ms"] != 0: raise ValidationError("profile-requirement-mismatch", "pv_interval_ms")
    if p["search_mode"] == "nodes" and not p.get("node_budget"): raise ValidationError("missing-provenance", "node_budget")
    if p["search_mode"] == "movetime" and not p.get("movetime_ms"): raise ValidationError("missing-provenance", "movetime_ms")


def execute_engine_search(work: Path, out_dir: Path, run_id: str, profile_name: str, fixture_obj: Any, position: str, *, searchmoves: list[str] | None = None, nodes: int | None = None, movetime: int | None = None, multipv: int | None = None) -> tuple[dict[str, Any], dict[str, Any]]:
    cfg = effective_profile(profile_name)
    if nodes is not None and cfg["search_mode"] == "nodes": cfg["nodes"] = nodes
    if movetime is not None and cfg["search_mode"] == "movetime": cfg["movetime_ms"] = movetime
    if multipv is not None: cfg["multipv"] = multipv
    raw = out_dir / "raw" / f"{run_id}.usi.log"; run = EngineRun(run_id, profile_name, cfg, raw, utc_now()); eng: Engine | None = None; rc = -999
    try:
        eng = Engine(work, profile_name, cfg, raw); lines = eng.go(position, search_command(cfg, searchmoves=searchmoves), multipv=cfg["multipv"]); run.usi_options_reported = eng.usi_options_reported; run.options_applied = eng.options_applied; eng.log.flush(); parsed = swift_compatible_accumulate(lines); run.exit_status = "PASS"; return parsed, {"_run": run, "_fixture": fixture_obj}
    except Exception:
        run.exit_status = "FAIL"; raise
    finally:
        if eng is not None: run.usi_options_reported = eng.usi_options_reported; run.options_applied = eng.options_applied; rc = eng.close()
        run.ended_at = utc_now()
        if run.exit_status == "PASS" and rc not in (0, -999): run.exit_status = f"ENGINE_EXIT_{rc}"


def finalize_run_provenance(work: Path, meta: dict[str, Any]) -> dict[str, Any]: return run_provenance(base_provenance(work), meta["_run"], meta["_fixture"])


def compile_swift_probe(output: Path) -> None:
    sources = [REPO_ROOT / "Sources/ShogiCoachCore/USIModels.swift", REPO_ROOT / "Sources/ShogiCoachCore/USIParser.swift", REPO_ROOT / "Sources/ShogiCoachCore/USIAccumulator.swift", TOOL_DIR / "swift_parity_probe.swift"]
    missing = [str(p) for p in sources if not p.exists()]
    if missing: raise ValidationError("missing-swift-source", ", ".join(missing))
    output.parent.mkdir(parents=True, exist_ok=True); subprocess.run(["swiftc", "-parse-as-library", *map(str, sources), "-o", str(output)], check=True)


def run_swift_probe(binary: Path, raw: Path) -> dict[str, Any]:
    cp = subprocess.run([str(binary), str(raw)], check=True, text=True, capture_output=True); return json.loads(cp.stdout)
