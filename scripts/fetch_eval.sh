#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTDIR="$ROOT/iOS/ShogiCoachPoC/eval"
OUT="$OUTDIR/nn.bin"
URL="https://github.com/yaneurao/YaneuraOu/releases/download/suisho5/Suisho5.7z"
ARCHIVE="$OUTDIR/Suisho5.7z"
EXPECTED_SHA256="768068f0d534a0603a5d38bcd143de6bbca820d5f1c95a14d40863e5b7892d76"

sha256_file() {
  local file="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$file" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$file" | awk '{print $1}'
  else
    echo "No SHA-256 command available" >&2
    return 2
  fi
}

verify_nnue() {
  local file="$1"
  local actual
  actual="$(sha256_file "$file")"
  if [ "$actual" != "$EXPECTED_SHA256" ]; then
    echo "NNUE SHA-256 mismatch" >&2
    echo "expected=$EXPECTED_SHA256" >&2
    echo "actual=$actual" >&2
    return 1
  fi
  echo "NNUE SHA-256 verified: $actual"
}

mkdir -p "$OUTDIR"
if [ -s "$OUT" ]; then
  verify_nnue "$OUT"
  echo "NNUE cached and verified: $OUT"
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
verify_nnue "$OUT"
echo "NNUE installed and verified: $OUT"
