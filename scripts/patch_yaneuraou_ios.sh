#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USI_H="$ROOT/native/third_party/YaneuraOu/source/usi.h"
USI_CPP="$ROOT/native/third_party/YaneuraOu/source/usi.cpp"

python3 - "$USI_H" "$USI_CPP" <<'PY'
from pathlib import Path
import sys

usi_h = Path(sys.argv[1])
usi_cpp = Path(sys.argv[2])

text = usi_h.read_text(encoding="utf-8-sig")
public_method = "    bool mobile_execute_command(const std::string& cmd) { return usi_cmdexec(cmd); }"
if public_method not in text:
    marker = "private:\n\t// 内包している思考エンジン"
    insert = "\n".join([
        "#if !STOCKFISH",
        public_method,
        "#endif",
        "",
        "private:",
        "\t// 内包している思考エンジン",
    ])
    if marker not in text:
        raise SystemExit("USIEngine private marker not found")
    text = text.replace(marker, insert, 1)
    usi_h.write_text(text, encoding="utf-8")

usi_text = usi_cpp.read_text(encoding="utf-8-sig")
old = "limits.searchmoves.push_back(to_lower(token));"
new = "limits.searchmoves.push_back(token);"
if old in usi_text:
    usi_text = usi_text.replace(old, new, 1)
    usi_cpp.write_text(usi_text, encoding="utf-8")
elif new not in usi_text:
    raise SystemExit("searchmoves patch marker not found")

if old in usi_cpp.read_text(encoding="utf-8-sig"):
    raise SystemExit("searchmoves lowercase patch incomplete")
PY
