# Build17-5 — Safe Concept Explanation Integration FINAL REPORT

基準日: 2026-10-02
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build17-5-safe-concept-explanation
Build17-4 Frozen authority: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8
Validated source head: afa07c1d347ddb9c3603e8d770829e293b2e7297

## 判定

**Build17-5: PASS / FREEZE CANDIDATE**

Build17-4でFrozenとなった3Conceptだけを、既存Intent説明の後に付く任意のHuman Concept補足として統合した。

- piece_mobility
- escape_route_control
- attack_attacker

ConceptからIntentへの逆流は行っていない。主説明、Intent confidence、Intent resolverの意味は変更していない。

## 実装

### 説明モデル
ContextMoveExplanationに optional conceptSupplement を追加した。

補足は以下を分離して保持する。

- conceptID
- human-readable text
- observed evidence text

### 安全な補足生成

補足生成は ContextExplanationGenerator 内で既存Primary Intent説明の後段にのみ置いた。

- HIGH / MEDIUM のみ補足候補
- LOW / UNRESOLVED は補足なし
- 1局面最大1Concept
- 複数Concept時の優先順位はPrimary Intent別に決定
  - capture_threat_response / piece_defense / defense / neutralize_threat: attack_attacker優先
  - attack_continuation / attack_preparation / mating_attack / threatmate / control_addition / outpost_creation: escape_route_control優先
  - その他: piece_mobility優先
- 許可されないConceptはIntent gateでスキップし、次候補へフォールバック
- Intent別に補足を出してよい範囲を限定
- piece_activation / major_piece_activation等、主説明と重複する場合はpiece_mobility補足を抑制
- 内部Concept名は通常UIへ表示しない
- 「〜するための手」「目的」「狙い」といった意図断定をConcept補足に使用しない

### 反復抑制

実戦手の時系列説明では、同じConcept候補が連続した場合、2手目以降の連続表示を抑制する。

### UI

既存Context explanation cardに optional「補足」行を追加しただけであり、画面構成・ナビゲーション・主要UIは変更していない。

## Build17-5専用テスト

Build17SafeConceptExplanationTests:

**14 / 14 PASS**

確認内容:

- piece_mobilityは主Intent説明の補足のみ
- piece_mobilityで目的断定しない
- escape_route_controlはattack_continuationを上書きしない
- escape_route_controlで詰み目的を捏造しない
- attack_attackerはcapture_threat_responseを維持
- tenukiではattack_attacker補足なし
- Locked Regressionの主説明はrook_pawn_response
- Conceptなしでは補足なし
- 複数Conceptでも最大1件
- 同一Concept連続表示を抑制可能
- Concept補足でconfidenceを変更しない
- LOW confidenceでは補足なし
- piece_activationへの冗長なpiece_mobility補足なし
- 無関係なdevelopmentへescape_route_control補足なし

初回テストでは、実盤面fixture 8h2b+ がFrozen判定上 piece_mobility と attack_attacker を同時に持つことをテスト側が見落として1ケースFAILした。
その後、複数Concept時の「最も説明価値の高い1件」をPrimary Intentに合わせて選ぶ設計へ改善した。bishop_line_responseではpiece_mobilityを優先し、capture/defense系ではattack_attacker、attack系ではescape_route_controlを優先する。
専用テストは実盤面fixtureへ戻し、2Concept同時成立を確認した上で、主Intentを維持しつつpiece_mobilityだけが補足に選ばれることを固定した。
この変更は説明レイヤ内のみで、Build17-4 Frozen Concept検出ロジック・Intent resolver・Intent evidenceには触れていない。

## Swift全回帰

Validated source head afa07c1d347ddb9c3603e8d770829e293b2e7297:

- XCTest: **60 / 60 PASS**
  - Build17-4以前の既存46件: PASS
  - Build17-5新規14件: PASS
- failures: **0**
- Swift Testing: **16 PASS**
- STATIC_VERIFY_PASS

## iOS Device Build

GitHub Actions run: 36890943386
Head SHA: afa07c1d347ddb9c3603e8d770829e293b2e7297

- Core regression: PASS
- Xcode project generation: PASS
- unsigned iPhone build: PASS
- BUILD SUCCEEDED
- IPA packaging: PASS
- IPA SHA-256: ca1b671fccf9c2f0847f0f4a2c1afca8d6410ab1ff80bdd082c5a29a05ceb747
- artifact upload: PASS
- artifact: ShogiCoachPoC-iPhone
- artifact digest: sha256:ce5eea9ca173e5e2937b8c07902becbd347e033b3c979f7cee317282779e1a1b

## iOS Simulator E2E

GitHub Actions run: 36890943355
Head SHA: afa07c1d347ddb9c3603e8d770829e293b2e7297

- official Denryusen KIF再取得: PASS
- compact knowledge generation: PASS
- generated knowledge repo sync: UNCHANGED
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
- simulator artifact digest: sha256:3516d31c95b916d431abe76785e2e00e5e8eccf9193b5f9a60e6c5bebc4be7b9

## Locked Regression

position startpos moves 7g7f 8c8d 2g2f 8d8e
current move: 8h7g

- primary Intent: rook_pawn_response
- confidence: HIGH
- primary explanation: 相手の飛車先の歩の前進に備える手です。
- context_geometry_primary=false

**PASS**

## Frozen境界・差分監査

Build17-4 Frozen authorityとのblob逆比較で以下は完全一致。

- Sources/ShogiCoachCore/ContextEngine.swift
- Build17-3 Pilot Corpus
- generated context knowledge
- iOS Device workflow
- iOS Simulator workflow

したがって以下は変更なし。

- MoveIntent enum
- ContextIntentResolver
- Intent evidence weight
- Intent優先順位
- Build17-4 Concept判定条件
- piece_mobility検出ロジック
- escape_route_control検出ロジック
- attack_attacker検出ロジック
- Build17-3 Corpus
- Knowledge data/schema generation
- engine / exploration
- training / fine-tuning / embedding / vector DB

Validated source headまでのnet code/test/UI変更は4ファイルのみ。

- Sources/ShogiCoachCore/ContextExplanation.swift
- Tests/ShogiCoachCoreTests/Build17SafeConceptExplanationTests.swift
- iOS/ShogiCoachPoC/ContextAnalysisViewModel.swift
- iOS/ShogiCoachPoC/ContinuationSimulationView.swift

## False Explanation監査

重大False Explanation: **なし**

複数Concept同時成立時はPrimary Intent別の優先順位で1件に絞る。これにより、capture/defense系でattacker対応、attack系で逃げ道制限、その他で可動域変化を優先し、主説明と補足の意味的整合を高めた。

確認済み:

- Concept補足に目的断定語を入れていない
- LOW / UNRESOLVEDでは補足しない
- tenukiにattack_attackerを誤付与しない
- 無関係Intentへのescape_route_control補足を抑制
- 主説明と重複するpiece_mobility補足を抑制
- 1局面最大1件
- 同一Concept連続表示を抑制
- 代表3種の補足文はPrimary conclusion + whyNowより短い
- 内部Concept名は通常UIへ表示しない

Build17-6では実戦棋譜による頻度・反復・自然さを追加回帰する。

なお、packaging後の再検証中に同一ブランチへ intent-aware priority commit が追加され、旧Simulator runはworkflow concurrencyによりcancelされた。差分を独立監査し、説明レイヤ1ファイルのみの変更であることを確認後、実盤面テストを追加して新source HEADでDevice / Simulatorを再PASSさせた。

## UI変更

あり。ただし最小差分。

既存説明カードへoptional「補足」を追加したのみ。
新画面、ナビゲーション変更、Conceptダッシュボード、デザイン刷新はなし。

## PR / main

- PR #8: open / Draft / unmerged
- main: 未変更
- Build17-5をmainへmergeしていない

## 未解決事項

Freeze Candidateを妨げるblocking issueなし。

Build17-6で行う実戦棋譜の大規模False Explanation Regressionは次工程であり、Build17-5のblocking issueではない。

## Packaging rule

このreport / manifest追加コミットはdocumentation-onlyとする。
実装authorityはvalidated source head afa07c1d347ddb9c3603e8d770829e293b2e7297。
packaging後の最終HEADについてもGitHub Actions全回帰を再実行し、PASS後にのみBuild17-5 PASS / FREEZE CANDIDATEを確定する。

## 次工程

Build17-5V
「Safe Concept Explanation Integration 最終独立検証・Freeze」

へ進行可能。
