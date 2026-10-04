#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DATE=20261004
OUT="build/build18-6"
KIF="$OUT/kif"
mkdir -p "$OUT/gate-a" "$OUT/gate-b" "$OUT/gate-c" "$OUT/full" "$KIF"

echo "== Gate A: authority audit =="
git merge-base --is-ancestor 054f30a54463d472cc96a16c49cd14d6e0e28b45 HEAD
git merge-base --is-ancestor 3ef903e5762e695646204987196e8b8fff500155 HEAD
git merge-base --is-ancestor 3443b3cb0830783b325fca4bd82fd374a185dc6a HEAD

if git diff --name-only 054f30a54463d472cc96a16c49cd14d6e0e28b45...HEAD -- Sources/ShogiCoachCore | grep -q .; then
  echo "AUTHORITY MISMATCH: production code changed after Build18-3 freeze" >&2
  git diff --name-only 054f30a54463d472cc96a16c49cd14d6e0e28b45...HEAD -- Sources/ShogiCoachCore >&2
  exit 1
fi

python3 - <<'PY'
import json
from pathlib import Path
p=Path("Build18/BUILD18_5A_DECISION_MANIFEST_20261004.json")
d=json.loads(p.read_text(encoding="utf-8"))
expected={
  "respond_to_rapid_attack":"HOLD",
  "sabai":"HOLD",
  "trade_to_transform":"HOLD",
  "multi_threat":"HOLD",
  "tempo_management":"HOLD",
}
assert d["decisions"] == expected
assert d["decisionCounts"]["PROMOTE_TO_LIMITED_EXPLANATION"] == 0
assert d["decisionCounts"]["HOLD"] == 5
assert d["build18_5bAllowed"] is False
assert d["authority"]["corpusSha256"] == "433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0"
print("build18_5a_authority=PASS")
PY

CORPUS_REF='origin/candidate/build18-2-diagnostic-corpus'
CORPUS_PATH='Build18/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json'
git show "$CORPUS_REF:$CORPUS_PATH" > "$OUT/gate-a/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json"
ACTUAL="$(shasum -a 256 "$OUT/gate-a/BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json" | awk '{print $1}')"
test "$ACTUAL" = "433438a81e94863a08fde83fb4c3659d660390576198df9f3d2e17a58d3b86f0"
printf '%s\n' "$CORPUS_REF:$CORPUS_PATH" > "$OUT/gate-a/corpus-path.txt"
printf '%s\n' "$ACTUAL" > "$OUT/gate-a/corpus-sha256.txt"
printf '%s\n' "054f30a54463d472cc96a16c49cd14d6e0e28b45" > "$OUT/gate-a/build18-3-freeze-head.txt"
printf '%s\n' "3ef903e5762e695646204987196e8b8fff500155" > "$OUT/gate-a/build18-3-production-head.txt"
printf '%s\n' "3443b3cb0830783b325fca4bd82fd374a185dc6a" > "$OUT/gate-a/build18-5a-head.txt"
printf '%s\n' "3f298c3c87bf43d40365fb53196d4e5649cb2fa352a592b6d5489f50a69c39c4" > "$OUT/gate-a/build18-4v-parent-attested-package-sha256.txt"
echo "AUTHORITY_AUDIT_PASS"

echo "== Fetch official real-game KIF =="
curl --fail --location --retry 3 --retry-delay 2   'https://denryu-sen.jp/denryusen/dr4_hardware2/kif_dr4_hdw2.zip'   --output "$OUT/denryusen.zip"
shasum -a 256 "$OUT/denryusen.zip" | tee "$OUT/BUILD18_6_SOURCE_ARCHIVE_SHA256.txt"
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
if len(files)<10:
    raise SystemExit(f"insufficient KIF files: {len(files)}")
print(f"kif_files={len(files)}")
PY

run_gate() {
  local label="$1"
  local positions="$2"
  local per_game="$3"
  local min_games="$4"
  local dir="$5"
  echo "== $label =="
  swift run -c release Build17RealGameRegression --     --input-dir "$KIF"     --output-json "$dir/real-game.json"     --output-markdown "$dir/real-game.md"     --target-positions "$positions"     --max-positions-per-game "$per_game"     --min-games "$min_games"     --max-ply 140     --game-sampling-policy deterministic-hash-v1     --position-sampling-policy evenly-spaced-v1     --source-id 'denryusen:dr4-hardware2:2024'     --source-title '第2回マイナビニュース杯電竜戦統一ハードウェア戦'     --source-url 'https://denryu-sen.jp/denryusen/dr4_hardware2/dr1_live.php'     --rights-note '公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。'     --retrieved-date '2026-10-04'     2>&1 | tee "$dir/run.log"
  python3 scripts/build18_6_audit.py     --input "$dir/real-game.json"     --output-dir "$dir"     --min-games "$min_games"     --min-positions "$positions"     --label "$label"
}

run_gate pilot 100 25 4 "$OUT/gate-b"
run_gate mid 300 30 10 "$OUT/gate-c"
run_gate full 720 60 12 "$OUT/full"

echo "== Gate F: existing regression =="
swift test 2>&1 | tee "$OUT/full/swift-test.log"
./scripts/verify.sh 2>&1 | tee "$OUT/full/static-verify.log"
python3 - "$OUT/full/real-game.json" "$OUT/full/BUILD18_6_REGRESSION_RESULTS_20261004.json" <<'PY'
import json, sys
from pathlib import Path
raw=json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
mandatory={x["id"]:x["passed"] for x in raw["summary"]["mandatoryRegressions"]}
expected={
  "C_build16_r1_ply59_overflow",
  "A_locked_rook_pawn_response",
  "B_bishop_line_multi_concept_priority",
}
assert set(mandatory)==expected
assert all(mandatory.values())
out={
  "LockedRegression":"PASS",
  "Build16-R1":"PASS",
  "Build17MandatoryRegression":"PASS",
  "Build18-3DedicatedTests":"PASS_VIA_SWIFT_TEST",
  "Build18-2_360_CorpusAuthority":"PASS_VIA_GATE_A_SHA",
  "staticVerify":"PASS",
  "productionCodeChangedAfterBuild18-3Freeze":False,
}
Path(sys.argv[2]).write_text(json.dumps(out,ensure_ascii=False,indent=2,sort_keys=True)+"\n",encoding="utf-8")
PY

cp Build18/BUILD18_6_SOURCE_SAMPLING_PLAN_20261004.md "$OUT/full/"
cp -R "$OUT/gate-a" "$OUT/full/GATE_A_AUTHORITY"
cp "$OUT/BUILD18_6_SOURCE_ARCHIVE_SHA256.txt" "$OUT/full/"
(
  cd "$OUT/full"
  zip -qr "../BUILD18_6_AUTOMATED_EVIDENCE_20261004.zip" .
)
shasum -a 256 "$OUT/BUILD18_6_AUTOMATED_EVIDENCE_20261004.zip"   > "$OUT/BUILD18_6_AUTOMATED_EVIDENCE_20261004.zip.sha256"

echo "BUILD18_6_AUTOMATED_AUDIT_PASS"
