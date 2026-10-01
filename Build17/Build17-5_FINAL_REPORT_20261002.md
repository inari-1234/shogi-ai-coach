# Build17-5 — Safe Concept Explanation Integration FINAL REPORT

基準日: 2026-10-02
Repository: inari-1234/shogi-ai-coach
Branch: candidate/build17-5-safe-concept-explanation
Build17-4 Frozen authority: 484c2596ef5f027738f2cdc0bbf83d65d334e5c8
Validated source head: 6218bfd3f43c70c2fcd76c63fc3e078cabac0013

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
- 優先順: attack_attacker > escape_route_control > piece_mobility
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
実装のIntent境界問題ではなく、複数Concept時により具体的なattack_attackerを1件だけ選ぶ設計どおりの挙動だった。
production codeは変更せず、piece_mobility単独fixtureへテストを修正し、全回帰PASSを確認した。

## Swift全回帰

Validated source head 6218bfd3f43c70c2fcd76c63fc3e078cabac0013:

- XCTest: **60 / 60 PASS**
  - Build17-4以前の既存46件: PASS
  - Build17-5新規14件: PASS
- failures: **0**
- Swift Testing: **16 PASS**
- STATIC_VERIFY_PASS

## iOS Device Build

GitHub Actions run: 36888674213
Head SHA: 6218bfd3f43c70c2fcd76c63fc3e078cabac0013

- Core regression: PASS
- Xcode project generation: PASS
- unsigned iPhone build: PASS
- BUILD SUCCEEDED
- IPA packaging: PASS
- IPA SHA-256: 435a360f7282a67cc2450c41fd7ca681180eec282c331544ae0751fd9680b73a
- artifact upload: PASS
- artifact: ShogiCoachPoC-iPhone
- artifact digest: sha256:81fe75f301cbb31c6e1e4452917fd41b02eb64512fd743789ecabd05c3e82844

## iOS Simulator E2E

GitHub Actions run: 36888674302
Head SHA: 6218bfd3f43c70c2fcd76c63fc3e078cabac0013

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
- simulator artifact digest: sha256:9210c7d25baf2d4ebdca5b3022bddab9c433805fbe72f6c6564c11cd4cd13f30

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
実装authorityはvalidated source head 6218bfd3f43c70c2fcd76c63fc3e078cabac0013。
packaging後の最終HEADについてもGitHub Actions全回帰を再実行し、PASS後にのみBuild17-5 PASS / FREEZE CANDIDATEを確定する。

## 次工程

Build17-5V
「Safe Concept Explanation Integration 最終独立検証・Freeze」

へ進行可能。
