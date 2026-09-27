#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/native/third_party/YaneuraOu"
PIN="a5ee2786c0030edc7d4a1cdfe94b04dffec55493"

if [ -d "$DEST/.git" ] && [ "$(git -C "$DEST" rev-parse HEAD 2>/dev/null || true)" = "$PIN" ]; then
  echo "YaneuraOu cached pin: $PIN"
  exit 0
fi

if [ -d "$DEST/.git" ]; then
  git -C "$DEST" fetch --tags --force
else
  rm -rf "$DEST"
  mkdir -p "$(dirname "$DEST")"
  git clone --filter=blob:none https://github.com/yaneurao/YaneuraOu.git "$DEST"
fi

git -C "$DEST" checkout --detach "$PIN"
test "$(git -C "$DEST" rev-parse HEAD)" = "$PIN"
echo "YaneuraOu pin: $PIN"
