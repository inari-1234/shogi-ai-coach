# Build17-4 — Safe Concept Integration FINAL REPORT

基準日: 2026-10-01
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build17-4-safe-concept-integration
Parent Build17-3 head: 00ff5f69a3c19e46aa26d3fe7a38dfbc03212a25
Validated source head: d5e4979baae72b35bebeb6d23ce6abfcafbdbb9c

## 判定

**BUILD17-4 PASS — FREEZE CANDIDATE**

Build17-3で実装許可された3項目のみを安全なEffect/SubIntent metadataとして追加した。
新しいMoveIntentは追加していない。

## 実装

1. piece_mobility
   - Effect / HumanConcept metadata
   - 移動前後のpseudo attack-square countを比較
   - +2以上で effect signal
   - primary Intentへweightを与えない

2. escape_route_control
   - Effect / HumanConcept metadata
   - 相手玉の隣接safe escape square数を前後比較
   - 減少時に effect signal
   - mating/threatmate/control系のprimary Intentを上書きしない

3. attack_attacker
   - SubIntent metadata
   - 直前手で具体的に攻撃を作った相手駒を、現手が取る/攻撃する場合だけ付与
   - capture_threat_response / defense / piece_defense等の親Intentを維持

## 非変更

- MoveIntent enum: UNCHANGED
- ContextIntentResolver: UNCHANGED
- Intent evidence weight: 新3Conceptからの追加なし
- UI: UNCHANGED
- 学習 / fine-tuning: NONE
- embedding / vector DB: NONE
- EXPLANATION_ONLY群のproduction自動判定: NONE

## Static reverse validation

Build17-3との差分比較:
- MoveIntent定義: byte-equivalent section
- ContextIntentResolver: byte-equivalent section
- 新3Conceptは effects のみ
- supportedIntent追加: 0

**PASS**

## Swift regression

専用テスト:
- Build17SafeConceptEffectTests: 5 / 5 PASS
- Locked Regression included

Swift Package:
- XCTest: 46 tests / 0 failures
- Swift Testing: 16 tests PASS

**PASS**

## iOS validation

Validated source head d5e4979baae72b35bebeb6d23ce6abfcafbdbb9c:

- iOS Device Build: PASS
- iOS Simulator app build: PASS
- Simulator engine E2E: PASS
- official Denryusen compact knowledge rebuild: PASS
- knowledge records: 1281
- stage=complete: PASS

Locked Regression:
- position startpos moves 7g7f 8c8d 2g2f 8d8e
- move 8h7g
- primary Intent: rook_pawn_response
- confidence: high
- context_geometry_primary=false
- context_semantics_status=PASS
- schema8 audit=PASS

## Scope result

Build17-4でproductionへ入れるのは以下のみ:
- piece_mobility effect
- escape_route_control effect
- attack_attacker subordinate metadata

以下は引き続き自動production labelへ入れない:
- prophylaxis
- waiting_move
- sabai
- tempo_management
- speed_over_material
- trade_to_transform
- multi_threat
- maintain_counterattack_potential
- deny_ideal_formation
- create_battlefront

## Merge

PR #8 はDraftのまま。
mainへmergeしていない。

## Freeze rule

このFreeze Candidate以降、上記3項目の意味境界を変更する場合は別工程で再検証する。
Build17-3の200局面結果を書き換えない。
