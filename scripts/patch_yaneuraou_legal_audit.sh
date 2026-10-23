#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/native/third_party/YaneuraOu/source"
MAIN_CPP="$SOURCE/main.cpp"
AUDIT_INC_SRC="$ROOT/tools/engine-verify/yaneuraou_ve1b_legal_audit.inc"
AUDIT_INC_DST="$SOURCE/ve1b_legal_audit.inc"

cp "$AUDIT_INC_SRC" "$AUDIT_INC_DST"

python3 - "$MAIN_CPP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8-sig")

include_signature = '#include "ve1b_legal_audit.inc"'
if include_signature not in text:
    marker = 'using namespace YaneuraOu;'
    if marker not in text:
        raise SystemExit("main.cpp namespace marker not found")
    text = text.replace(marker, marker + '\n\n#include "ve1b_legal_audit.inc"', 1)

branch_signature = '--ve1b-legal-audit'
if branch_signature not in text:
    marker = '\tPosition::init();'
    if marker not in text:
        marker = '    Position::init();'
    if marker not in text:
        raise SystemExit("main.cpp Position::init marker not found")
    block = '''\n\n\tif (argc == 3 && std::string(argv[1]) == "--ve1b-legal-audit")\n\t\treturn ve1b_run_legal_audit(argv[2]);'''
    text = text.replace(marker, marker + block, 1)

path.write_text(text, encoding="utf-8")
PY

grep -F '#include "ve1b_legal_audit.inc"' "$MAIN_CPP"
grep -F -- '--ve1b-legal-audit' "$MAIN_CPP"
grep -F 'MoveList<LEGAL>(pos).size()' "$AUDIT_INC_DST"
grep -F 'MoveList<LEGAL_ALL>(pos)' "$AUDIT_INC_DST"
