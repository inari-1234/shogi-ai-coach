#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[1/3] Podspec and shell syntax'
ruby -c native/yaneuraou_engine.podspec
bash -n scripts/fetch_yaneuraou.sh scripts/fetch_eval.sh scripts/patch_yaneuraou_ios.sh

echo '[2/3] Canonical repository structure'
test ! -e artifacts/poc.part.00
test ! -d ci
test ! -e iOS/ShogiCoachPoC/BuildIdentity.swift
test ! -e iOS/ShogiCoachPoC/EngineProbe.swift
test -f iOS/ShogiCoachPoC/ContentView.swift
test -f iOS/ShogiCoachPoC/EngineUSISession.swift
test -f iOS/ShogiCoachPoC/SimulatorCIProbe.swift
test -f Project.yml
test -f Podfile

echo '[3/3] No obsolete overlay references'
! grep -R -n -E 'poc\.part|ContentViewPhase[2-6]|EngineProbeSocketPair|ci/Project\.yml'   .github Project.yml iOS Sources Tests scripts README.md

echo 'STATIC_VERIFY_PASS'
