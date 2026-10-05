#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

BASE="a81cc5da27713207888bb65c6357b8eb081f4ae3"
OUT="build/build19-v"
KIF="$OUT/kif"
FULL="$OUT/build18-source-full"
CONT="$OUT/build18-source-continuity"
mkdir -p "$OUT" "$KIF" "$FULL" "$CONT"

echo "== Build19-V Gate A: authority / scope =="
git merge-base --is-ancestor "$BASE" HEAD
git diff --exit-code "$BASE"...HEAD -- Sources/ShogiCoachCore
changed="$(git diff --name-only "$BASE"...HEAD)"
unexpected="$(printf '%s\n' "$changed" | grep -Ev '^(Package.swift|Sources/Build19VSemanticAudit/|scripts/build19_v_|scripts/run_build19_v_ci.sh|Build19/BUILD19_V_|\.github/workflows/build19-v-real-game-semantic-validation.yml)' | sed '/^$/d' || true)"
if [ -n "$unexpected" ]; then
  echo "BUILD19_V_SCOPE_VIOLATION" >&2
  printf '%s\n' "$unexpected" >&2
  exit 1
fi
printf '%s\n' "$BASE" > "$OUT/BUILD19_V_UPSTREAM_HEAD.txt"
printf '%s\n' "$changed" > "$OUT/BUILD19_V_CHANGED_FILES.txt"
echo "BUILD19_V_SCOPE_GUARD_PASS"

echo "== Build19-V Gate B: recover official real-game source =="
curl --fail --location --retry 3 --retry-delay 2 \
  'https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip' \
  --output "$OUT/denryusen.zip"
shasum -a 256 "$OUT/denryusen.zip" | tee "$OUT/BUILD19_V_SOURCE_ARCHIVE_SHA256.txt"
python3 - "$OUT/denryusen.zip" "$KIF" <<'PY'
import sys, zipfile
from pathlib import Path
source=Path(sys.argv[1])
destination=Path(sys.argv[2]).resolve()
with zipfile.ZipFile(source, metadata_encoding="cp932") as archive:
    for member in archive.infolist():
        target=(destination/member.filename).resolve()
        if destination not in target.parents and target != destination:
            raise SystemExit(f"unsafe zip path: {member.filename}")
    archive.extractall(destination)
files=sorted(destination.rglob("*.kif"))
if len(files) < 10:
    raise SystemExit(f"insufficient KIF files: {len(files)}")
print(f"kif_files={len(files)}")
PY

echo "== Build19-V Gate C: regenerate deterministic Build18 semantic source =="
swift run -c release Build17RealGameRegression -- \
  --input-dir "$KIF" \
  --output-json "$FULL/real-game.json" \
  --output-markdown "$FULL/real-game.md" \
  --target-positions 720 \
  --max-positions-per-game 60 \
  --min-games 12 \
  --max-ply 140 \
  --game-sampling-policy deterministic-hash-v1 \
  --position-sampling-policy evenly-spaced-v1 \
  --source-id 'denryusen:dr4-hardware2:2024' \
  --source-title '第2回マイナビニュース杯電竜戦統一ハードウェア戦' \
  --source-url 'https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php' \
  --rights-note '公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。' \
  --retrieved-date '2026-10-05' \
  2>&1 | tee "$FULL/run.log"
python3 scripts/build18_6r1_audit.py \
  --input "$FULL/real-game.json" \
  --output-dir "$FULL" \
  --min-games 12 \
  --min-positions 720 \
  --label build19-v-source

test -s "$FULL/BUILD18_6R1_HUMAN_SEMANTIC_REVIEW_CANDIDATES_20261005.json"

swift run -c release Build17RealGameRegression -- \
  --input-dir "$KIF" \
  --output-json "$CONT/real-game.json" \
  --output-markdown "$CONT/real-game.md" \
  --target-positions 14 \
  --max-positions-per-game 14 \
  --min-games 1 \
  --max-ply 140 \
  --game-sampling-policy deterministic-hash-v1 \
  --position-sampling-policy sequential-v1 \
  --source-id 'denryusen:dr4-hardware2:2024' \
  --source-title '第2回マイナビニュース杯電竜戦統一ハードウェア戦' \
  --source-url 'https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php' \
  --rights-note '公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。' \
  --retrieved-date '2026-10-05' \
  2>&1 | tee "$CONT/run.log"

echo "== Build19-V Gate D: recover Build19-P requirement fixture =="
git fetch origin candidate/build19-p-gap-audit:refs/remotes/origin/candidate/build19-p-gap-audit --force
git show origin/candidate/build19-p-gap-audit:Build19/BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json \
  > "$OUT/BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json"
python3 - "$OUT/BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json" <<'PY'
import json,sys
from pathlib import Path
d=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
assert d["sampleCount"] == 30
assert len(d["samples"]) == 30
print("build19_p_requirement_fixture=PASS")
PY

echo "== Build19-V Gate E: prepare pinned engine =="
chmod +x scripts/fetch_yaneuraou.sh scripts/fetch_eval.sh
./scripts/fetch_yaneuraou.sh
if [ ! -s iOS/ShogiCoachPoC/eval/nn.bin ]; then
  command -v 7z >/dev/null 2>&1 || brew install p7zip
fi
./scripts/fetch_eval.sh
ENGINE_SRC="$ROOT/native/third_party/YaneuraOu/source"
CPU="APPLEAVX2"
if [ "$(uname -m)" = "arm64" ]; then CPU="APPLEM1"; fi
make -C "$ENGINE_SRC" -j2 normal TARGET_CPU="$CPU" COMPILER=clang++
ENGINE="$ENGINE_SRC/YaneuraOu-by-gcc"
test -x "$ENGINE"
test -s "$ROOT/iOS/ShogiCoachPoC/eval/nn.bin"
"$ENGINE" <<< $'usi\nquit' | grep -q 'usiok'
echo "pinned_engine_ready=PASS cpu=$CPU"

echo "== Build19-V Gate F: actual engine pair acquisition =="
python3 scripts/build19_v_engine_probe.py \
  --engine "$ENGINE" \
  --eval-dir "$ROOT/iOS/ShogiCoachPoC/eval" \
  --requirements "$OUT/BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json" \
  --human-candidates "$FULL/BUILD18_6R1_HUMAN_SEMANTIC_REVIEW_CANDIDATES_20261005.json" \
  --continuity-real-game "$CONT/real-game.json" \
  --output "$OUT/BUILD19_V_ENGINE_PAIR_DATASET_20261005.json" \
  --low-ms 40 \
  --high-ms 120 \
  --continuity-count 14 \
  2>&1 | tee "$OUT/engine-probe.log"

echo "== Build19-V Gate G: project through Build19 production stack =="
swift run -c release Build19VSemanticAudit -- \
  --input "$OUT/BUILD19_V_ENGINE_PAIR_DATASET_20261005.json" \
  --output "$OUT/BUILD19_V_SEMANTIC_RESULTS_20261005.json" \
  2>&1 | tee "$OUT/core-projection.log"
python3 scripts/build19_v_semantic_audit.py \
  --input "$OUT/BUILD19_V_SEMANTIC_RESULTS_20261005.json" \
  --output-dir "$OUT" \
  --expected-requirement 30 \
  --min-continuity 12 \
  2>&1 | tee "$OUT/semantic-audit.log"

echo "== Build19-V Gate H: regression =="
swift test --filter CandidateComparison 2>&1 | tee "$OUT/build19-1-regression.log"
swift test --filter SequenceCounterfactual 2>&1 | tee "$OUT/build19-2-regression.log"
swift test --filter ComparisonConfidence 2>&1 | tee "$OUT/build19-3a-regression.log"
swift test --filter ComparisonCoaching 2>&1 | tee "$OUT/build19-3b-regression.log"
swift test 2>&1 | tee "$OUT/swift-test.log"
./scripts/verify.sh 2>&1 | tee "$OUT/static-verify.log"

echo "== Build19-V Gate I: authority invariants =="
python3 - <<'PY'
import json
from pathlib import Path
p=Path("Build19/BUILD19_4_DECISION_MANIFEST_20261005.json")
if not p.exists():
    candidates=sorted(Path("Build19").glob("*19_4*DECISION*json"))
    if not candidates:
        raise SystemExit("Build19-4 decision manifest missing")
    p=candidates[0]
d=json.loads(p.read_text(encoding="utf-8"))
raw=json.dumps(d,ensure_ascii=False)
for concept in ["respond_to_rapid_attack","sabai","trade_to_transform","multi_threat","tempo_management"]:
    if concept not in raw or "HOLD" not in raw:
        raise SystemExit(f"HOLD authority missing: {concept}")
print("build19_4_hold_authority_present=PASS")
PY

echo "== Build19-V package =="
cp Build19/BUILD19_V_VALIDATION_PLAN_20261005.md "$OUT/"
(
  cd "$OUT"
  zip -qr BUILD19_V_AUTOMATED_EVIDENCE_20261005.zip \
    BUILD19_V_UPSTREAM_HEAD.txt \
    BUILD19_V_CHANGED_FILES.txt \
    BUILD19_V_SOURCE_ARCHIVE_SHA256.txt \
    BUILD19_P_REAL_GAME_GAP_SAMPLES_20261005.json \
    BUILD19_V_ENGINE_PAIR_DATASET_20261005.json \
    BUILD19_V_SEMANTIC_RESULTS_20261005.json \
    BUILD19_V_MACHINE_AUDIT_20261005.json \
    BUILD19_V_BLOCKING_RECORDS_20261005.json \
    BUILD19_V_HUMAN_SEMANTIC_REVIEW_CANDIDATES_20261005.md \
    BUILD19_V_VALIDATION_PLAN_20261005.md \
    engine-probe.log core-projection.log semantic-audit.log \
    build19-1-regression.log build19-2-regression.log build19-3a-regression.log build19-3b-regression.log \
    swift-test.log static-verify.log
)
shasum -a 256 "$OUT/BUILD19_V_AUTOMATED_EVIDENCE_20261005.zip" | tee "$OUT/BUILD19_V_AUTOMATED_EVIDENCE_SHA256.txt"
echo "BUILD19_V_AUTOMATED_VALIDATION_PASS"
