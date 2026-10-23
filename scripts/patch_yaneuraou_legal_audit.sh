#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USI_CPP="$ROOT/native/third_party/YaneuraOu/source/usi.cpp"

python3 - "$USI_CPP" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8-sig")

signature = 'token == "ve1b_legal_move_count"'
if signature not in text:
    marker = '    else if (token == "flip")'
    if marker not in text:
        marker = '\telse if (token == "flip")'
    if marker not in text:
        raise SystemExit("USI flip command marker not found")

    indent = marker[: len(marker) - len(marker.lstrip())]
    block = f'''{indent}else if (token == "ve1b_legal_move_count")
    {{
        auto& pos = engine.get_position();
        sync_cout << "info string ve1b_legal_move_count "
                  << MoveList<LEGAL>(pos).size() << sync_endl;
    }}

{indent}else if (token == "ve1b_legal_all_moves")
    {{
        auto& pos = engine.get_position();
        std::ostringstream oss;
        oss << "info string ve1b_legal_all_moves";
        for (auto m : MoveList<LEGAL_ALL>(pos))
            oss << ' ' << m;
        sync_cout << oss.str() << sync_endl;
    }}

'''
    text = text.replace(marker, block + marker, 1)
    path.write_text(text, encoding="utf-8")

patched = path.read_text(encoding="utf-8-sig")
for required in [
    'token == "ve1b_legal_move_count"',
    'MoveList<LEGAL>(pos).size()',
    'token == "ve1b_legal_all_moves"',
    'MoveList<LEGAL_ALL>(pos)',
]:
    if required not in patched:
        raise SystemExit(f"audit patch incomplete: {required}")
PY
