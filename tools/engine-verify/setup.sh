#!/usr/bin/env bash
# Build the formally pinned VE1-Q verification engine and install Suisho5 NNUE.
# This prepares engine identity only; semantic authority is never derived from setup.
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${ENGINE_VERIFY_WORK:-$HERE/.work}"
PIN="a5ee2786c0030edc7d4a1cdfe94b04dffec55493"
EXPECTED_NNUE_SHA="768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"
NNUE_URL="https://github.com/yaneurao/YaneuraOu/releases/download/suisho5/Suisho5.7z"
mkdir -p "$WORK"

detect_cpu() {
  local os arch; os="$(uname -s)"; arch="$(uname -m)"
  if [ "$os" = "Darwin" ]; then
    if [ "$arch" = "arm64" ]; then echo APPLEM1
    elif sysctl -n machdep.cpu.leaf7_features 2>/dev/null | grep -q AVX2; then echo APPLEAVX2
    else echo APPLESSE42; fi
  elif [ "$arch" = "x86_64" ]; then
    if grep -q avx2 /proc/cpuinfo 2>/dev/null; then echo AVX2; else echo SSE42; fi
  else echo OTHER; fi
}
TARGET_CPU="${1:-$(detect_cpu)}"
COMPILER="${COMPILER:-$(command -v clang++ >/dev/null 2>&1 && echo clang++ || echo g++)}"
BUILD_COMMAND="make normal TARGET_CPU=$TARGET_CPU YANEURAOU_EDITION=YANEURAOU_ENGINE_NNUE COMPILER=$COMPILER"

sha() { (command -v sha256sum >/dev/null && sha256sum "$1" || shasum -a 256 "$1") | awk '{print $1}'; }

if [ ! -d "$WORK/YaneuraOu/.git" ]; then
  git clone --filter=blob:none https://github.com/yaneurao/YaneuraOu.git "$WORK/YaneuraOu"
fi
git -C "$WORK/YaneuraOu" fetch -q origin "$PIN" 2>/dev/null || true
git -C "$WORK/YaneuraOu" checkout -q --detach "$PIN"
test "$(git -C "$WORK/YaneuraOu" rev-parse HEAD)" = "$PIN"

# Match the app's required searchmoves case-preservation patch. V9.00 otherwise
# lowercases drop moves such as P*2e and can silently discard them.
python3 - "$WORK/YaneuraOu/source/usi.cpp" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1]); t = p.read_text(encoding="utf-8-sig")
old, new = "limits.searchmoves.push_back(to_lower(token));", "limits.searchmoves.push_back(token);"
if old in t:
    p.write_text(t.replace(old, new, 1), encoding="utf-8")
    for f in p.parent.glob("YaneuraOu-by-*"): f.unlink()
elif new not in t:
    sys.exit("searchmoves patch marker not found")
PY
PATCH_SHA="$(git -C "$WORK/YaneuraOu" diff -- source/usi.cpp | (command -v sha256sum >/dev/null && sha256sum || shasum -a 256) | awk '{print $1}')"

if ! ls "$WORK"/YaneuraOu/source/YaneuraOu-by-* >/dev/null 2>&1; then
  make -C "$WORK/YaneuraOu/source" -j"$( (nproc || sysctl -n hw.ncpu) 2>/dev/null || echo 2)" normal \
    TARGET_CPU="$TARGET_CPU" YANEURAOU_EDITION=YANEURAOU_ENGINE_NNUE COMPILER="$COMPILER" > "$WORK/build.log" 2>&1 \
    || { echo "build failed; see $WORK/build.log" >&2; exit 1; }
fi
ENGINE="$(ls "$WORK"/YaneuraOu/source/YaneuraOu-by-* | head -1)"
ln -sf "$ENGINE" "$WORK/engine"

mkdir -p "$WORK/eval"
if [ ! -s "$WORK/eval/nn.bin" ]; then
  curl -fL --retry 3 -o "$WORK/Suisho5.7z" "$NNUE_URL"
  SZ=""
  for c in 7zz 7z 7za 7zr; do command -v "$c" >/dev/null 2>&1 && { SZ="$c"; break; }; done
  if [ -z "$SZ" ]; then
    echo "7-Zip not found; building 7zz from ip7z/7zip" >&2
    [ -d "$WORK/7zip" ] || git clone -q --depth 1 https://github.com/ip7z/7zip.git "$WORK/7zip"
    make -s -C "$WORK/7zip/CPP/7zip/Bundles/Alone2" -f makefile.gcc -j2 >/dev/null 2>&1
    SZ="$WORK/7zip/CPP/7zip/Bundles/Alone2/_o/7zz"
  fi
  "$SZ" e -y -o"$WORK/eval" "$WORK/Suisho5.7z" nn.bin >/dev/null
  rm -f "$WORK/Suisho5.7z"
fi
ACTUAL_NNUE_SHA="$(sha "$WORK/eval/nn.bin")"
if [ "$ACTUAL_NNUE_SHA" != "$EXPECTED_NNUE_SHA" ]; then
  echo "NNUE SHA mismatch: expected $EXPECTED_NNUE_SHA got $ACTUAL_NNUE_SHA" >&2
  exit 1
fi

COMPILER_VERSION="$($COMPILER --version 2>/dev/null | head -1 | sed 's/"/\\"/g')"
cat > "$WORK/provenance.json" <<JSON
{
  "schema_version": "ve1q-setup-provenance-v1",
  "engine_commit": "$PIN",
  "engine_patches": ["searchmoves keeps USI drop-move case"],
  "engine_patch_sha256": "$PATCH_SHA",
  "engine_binary": "$(basename "$ENGINE")",
  "engine_sha256": "$(sha "$ENGINE")",
  "target_cpu": "$TARGET_CPU",
  "compiler": "$COMPILER",
  "compiler_version": "$COMPILER_VERSION",
  "build_command": "$BUILD_COMMAND",
  "nnue": "Suisho5 nn.bin",
  "nnue_sha256": "$ACTUAL_NNUE_SHA",
  "built_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSON
cat "$WORK/provenance.json"
echo "ready: $WORK/engine"
