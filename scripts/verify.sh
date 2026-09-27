#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo '[1/4] Swift core tests'
swift test

echo '[2/4] Podspec syntax'
ruby -c native/yaneuraou_engine.podspec

echo '[3/4] Shell syntax'
bash -n scripts/fetch_yaneuraou.sh scripts/fetch_eval.sh scripts/patch_yaneuraou_ios.sh

echo '[4/4] Repository structure'
test ! -e artifacts/poc.part.00
test ! -e ci/ContentViewPhase2.swift
test ! -e ci/ContentViewPhase3.swift
test ! -e ci/ContentViewPhase4.swift
test ! -e ci/ContentViewPhase5.swift
test -f iOS/ShogiCoachPoC/ContentView.swift
test -f iOS/ShogiCoachPoC/EngineProbe.swift
test -f Project.yml
test -f Podfile

echo 'STATIC_VERIFY_PASS'
