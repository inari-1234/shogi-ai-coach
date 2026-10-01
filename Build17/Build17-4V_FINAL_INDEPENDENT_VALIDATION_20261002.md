# Build17-4V — Safe Concept Integration 最終独立検証・Freeze

基準日: 2026-10-02
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build17-4-safe-concept-integration
Build17-3 final head: 00ff5f69a3c19e46aa26d3fe7a38dfbc03212a25
検証対象SHA: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8

## 最終判定

**Build17-4V: PASS**

**Build17-4: COMPLETE / FROZEN**

検証対象の実装内容は変更していない。mainへのmergeは行っていない。PR #8はDraftのまま維持する。

## 独立差分監査

Build17-3 final head 00ff5f69a3c19e46aa26d3fe7a38dfbc03212a25 から検証対象 484c2596ef5f027738f2cdc0bbf83d65d334e5c8 までのnet変更は4ファイルのみ。

- Sources/ShogiCoachCore/ContextEngine.swift
- Tests/ShogiCoachCoreTests/Build17SafeConceptEffectTests.swift
- Build17/Build17-4_FINAL_REPORT_20261001.md
- Build17/Build17-4_FREEZE_CANDIDATE_MANIFEST_20261001.json

Build17-3 Corpus関連15ファイルはblob SHA map完全一致で変更なし。

validated source head d5e4979baae72b35bebeb6d23ce6abfcafbdbb9c から検証対象 484c2596ef5f027738f2cdc0bbf83d65d334e5c8 までは、FINAL_REPORTとFREEZE_CANDIDATE_MANIFESTの追加のみ。コード差分なし。

## Intent境界静的監査

- MoveIntent enum: Build17-3基準とブロック単位で完全一致
- ContextIntentResolver: Build17-3基準とブロック単位で完全一致
- supportedIntent行: Build17-3基準と完全一致
- Intent weight相当行: Build17-3基準と完全一致
- piece_mobility / escape_route_control / attack_attacker は MoveIntent / ContextIntentResolver 内に存在しない
- 新3ConceptからIntent evidence / supportedIntent / weight追加なし

**PASS**

## 3Concept境界

### piece_mobility
Effect / HumanConcept metadataのみ。
mobilityAfter >= mobilityBefore + 2 の観測差分を必要とし、推測だけでは付与しない。
primary Intentへのevidenceは追加しない。

### escape_route_control
Effect / HumanConcept metadataのみ。
opponentEscapeAfter < opponentEscapeBefore の実測減少を必要とする。
王手そのものを条件にしておらず、primary Intentへのevidenceは追加しない。

### attack_attacker
SubIntent metadataのみ。
直前手で新たに攻撃された駒に対する具体的attacker集合を作り、現在手がそのattackerを取るか直接攻撃する場合だけ付与する。
単なるcapture一般、一般的な反撃、tenukiだけでは付与しない。
primary Intentへのevidenceは追加しない。

## Build17-4専用テスト

最終SHA 484c2596ef5f027738f2cdc0bbf83d65d334e5c8 の iOS Device Build / Core regression 内で再実行。

Build17SafeConceptEffectTests:
- testAttackAttackerIsSubordinateMetadata: PASS
- testEscapeRouteControlEffectDoesNotReplaceAttackContinuation: PASS
- testLockedRegressionPrimaryIntentRemainsRookPawnResponse: PASS
- testPieceMobilityEffectIsSecondaryToBishopLineResponse: PASS
- testTenukiDoesNotGainAttackAttackerMetadata: PASS

結果: **5 / 5 PASS**

## Swift全回帰

最終SHA上で:
- XCTest: **46 / 46 PASS**
- failures: **0**
- Swift Testing: **16 PASS**
- STATIC_VERIFY_PASS

**PASS**

## iOS Device Build

GitHub Actions run: 36878378602
head SHA: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8

- Core regression tests: PASS
- Xcode project generation: PASS
- unsigned iPhone build: PASS
- BUILD SUCCEEDED
- IPA packaging: PASS
- IPA SHA-256: dd61b0b304834e828d2b5b63cc3d6a12c19db20176a9a6b7832c2e0e8fadc751
- artifact upload: PASS
- artifact: ShogiCoachPoC-iPhone
- artifact digest: sha256:2e1f16f5a5eb800a94b66ff7ecffac5c400ee44be2934ff681aeea3fc052fafe

**PASS**

## iOS Simulator E2E

GitHub Actions run: 36878378698
head SHA: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8

- 公式Denryusen KIF再取得: PASS
- ContextKnowledgeBuilder: PASS
- compact knowledge生成: PASS
- context_knowledge_records=1281
- Core regression: PASS
- Simulator app build: PASS
- BUILD SUCCEEDED
- Simulator engine E2E: PASS
- stage=complete
- context_semantics_status=PASS
- context_rook_pawn_intent=rook_pawn_response
- context_geometry_primary=false
- context_knowledge_records=1281
- context_schema8_audit=PASS
- context_schema8_target_intent=rook_pawn_response
- context_schema8_target_confidence=high

**PASS**

## Locked Regression

position startpos moves 7g7f 8c8d 2g2f 8d8e
current move: 8h7g

- primary Intent: rook_pawn_response
- confidence: HIGH
- context_geometry_primary=false
- Build17SafeConceptEffectTestsでPASS
- Simulator E2Eでもrook_pawn_response維持

**PASS**

## False Positive独立確認

- piece_mobility: 実測attack-square増加条件が必要。静かな移動だからという理由だけでは付与しない。
- escape_route_control: 実測safe escape square減少条件が必要。普通の王手だからという理由だけでは付与しない。
- attack_attacker: concrete attacker + capture/direct attack条件が必要。単なる取り返し一般には拡張されていない。
- tenuki: 専用negative test PASS。
- rook_pawn_response: primary Intent維持 test PASS。

重大False Positive問題: **なし**

## 降格Concept

以下をproduction自動判定へ追加していない。

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

## PR / merge状態

PR #8:
- state: open
- draft: true
- merged: false
- head: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8

Build17-4のmain mergeは実施していない。

## 未解決事項

Freezeを妨げる未解決事項なし。

GitHub ActionsにはNode.js 20 deprecation warningがあるが、今回のBuild17-4機能・テスト・build/E2E判定には影響しておらず、Build17-4Vのblocking issueではない。

## Freeze

検証対象SHA 484c2596ef5f027738f2cdc0bbf83d65d334e5c8 を Build17-4 validated authority として固定する。

Build17-4の3Concept境界:
- piece_mobility = Effect / HumanConcept metadata
- escape_route_control = Effect / HumanConcept metadata
- attack_attacker = SubIntent metadata

非変更事項:
- MoveIntent
- ContextIntentResolver
- Intent evidence weight
- Build17-3 Corpus
- UI
- explanation generation
- learning / fine-tuning
- embedding / vector DB

## 次工程

**Build17-5へ進行可能。**
