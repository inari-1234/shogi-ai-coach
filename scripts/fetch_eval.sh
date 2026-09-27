#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="$ROOT/iOS/ShogiCoachPoC/eval"
OUT="$OUTDIR/nn.bin"
URL="https://github.com/yaneurao/YaneuraOu/releases/download/suisho5/Suisho5.7z"
ARCHIVE="$OUTDIR/Suisho5.7z"

mkdir -p "$OUTDIR"
if [ -s "$OUT" ]; then
  echo "NNUE cached: $OUT"
  exit 0
fi

SEVENZIP=""
for cmd in 7z 7za 7zr; do
  if command -v "$cmd" >/dev/null 2>&1; then
    SEVENZIP="$cmd"
    break
  fi
done
[ -n "$SEVENZIP" ] || { echo "7z is required when nn.bin is not cached" >&2; exit 1; }

curl -fL --retry 3 -o "$ARCHIVE" "$URL"
"$SEVENZIP" e -y -o"$OUTDIR" "$ARCHIVE" nn.bin >/dev/null
rm -f "$ARCHIVE"
[ -s "$OUT" ] || { echo "nn.bin extraction failed" >&2; exit 1; }
echo "NNUE installed: $OUT"
