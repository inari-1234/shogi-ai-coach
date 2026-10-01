# Build17-6 — Real-game E2E / False Explanation Regression FINAL REPORT

基準日: 2026-10-02  
Repository: inari-1234/shogi-ai-coach  
Branch: candidate/build17-6-real-game-e2e  
Build17-5 Frozen authority: `50c136086751e39016c6fecde31c93d8e0088d2a`  
Build17-6 failing validation HEAD: `4f055837f87ba40a3a9fa4c49eaf9744f3020128`

## 最終判定

**Build17-6: FAIL — CORRECTION REQUIRED**

Build17-5 Frozen authority自体は変更していない。  
通常のSwift回帰、Device Build、Simulator E2EはPASSしたが、実戦棋譜を広げたBuild17-6回帰で、Build16由来の `ContextIntentResolver` にblockingなruntime arithmetic overflowを検出した。

このためBuild17-6をCOMPLETE / FROZEN扱いしない。

## 実戦fixture

既存Simulator CIでも利用している公式電竜戦KIFを使用した。

- source_id: `denryusen:dr4-hardware2:2024`
- source: 第2回マイナビニュース杯電竜戦統一ハードウェア戦
- archive内KIF: 250 files observed
- rights note: 「公式ページ: 棋譜利用は制限等ありませんので、ご自由にお使いください。」
- Build17-6では回帰fixture / E2E入力としてのみ使用し、学習データとして恒久保存しない。

計画は240局面、最低4局、1局最大60局面、100手目までだった。

## 実戦監査の到達点

authoritative failure run: `36936518475`

- 1局目: 60局面完了
- 2局目: 58局面完了
- 合計: **118局面完了**
- 119局面目の解析でruntime trap
- したがって100局面の最低確認数は超えたが、予定240局面と最低4局には未到達

failure game:

`dr4hd2+buoy_先手15分減_dr4hd2y1-1-bottom_4_honeywaffle_wanderer-1800-5F+honeywaffle+wanderer+20240113142431`

failure position:

- ply: 59
- previous move: `B*8g`
- current move: `9h8h`
- process result: `Trace/BPT trap: 5` / exit 133

## Mandatory Regression

### A — Locked Regression

`position startpos moves 7g7f 8c8d 2g2f 8d8e`  
move: `8h7g`

mandatory gateを通過後に実戦corpus traversalへ進んでいるため **PASS**。

期待値維持:

- primary Intent: `rook_pawn_response`
- confidence: HIGH
- primary explanation: 相手の飛車先の歩の前進に備える手です。
- geometry_primary=false

### B — Multi-Concept Priority

`position startpos moves 7g7f 3c3d`  
move: `8h2b+`

mandatory gateを通過後に実戦corpus traversalへ進んでいるため **PASS**。

- primary Intent: `bishop_line_response`
- piece_mobility成立
- attack_attacker成立
- shown supplement: `piece_mobility`
- ConceptからIntent変更なし

## Blocking defect

Frozen authority内の `Sources/ShogiCoachCore/ContextEngine.swift` に以下の組合せがある。

- line 275: `let secondScore = candidates.dropFirst().first?.score ?? Int.min`
- line 287: `if top.score >= 100, top.score - secondScore >= 15, hasHighAuthority {`

Intent候補が1件だけの場合、`secondScore = Int.min` になる。  
その状態でtop scoreが100以上なら、`top.score - Int.min` がSwift `Int` の表現範囲を超え、overflow trapになる。

既存resolver matrixの単一候補fixtureは最大でも92点のため、`top.score >= 100` でshort-circuitされ、この境界が既存テストでは露出していなかった。

### 原因分類

**Build16 Intent問題**

現時点で以下を原因とは判定しない。

- Build17-5 explanation selection問題
- Build17-5 UI / suppression問題
- Build17-4 Concept detection問題
- データ不足

したがって、**Build17-4 REOPEN REQUIREDではない**。  
Build17-5の3Concept補足ロジックも、この問題のためにREOPENしない。

## Frozen境界監査

Frozen authority `50c1360…d2a` からfailing validation HEAD `4f05583…0128` までの差分は次の3ファイルだけ。

- `.github/workflows/build17-6-real-game-regression.yml`
- `Package.swift`
- `Sources/Build17RealGameRegression/main.swift`

以下のproduction authorityは変更していない。

- `Sources/ShogiCoachCore/ContextEngine.swift`
- `Sources/ShogiCoachCore/ContextExplanation.swift`
- Build17-4 Concept detection
- Build17-5 supplement policy
- Intent evidence weight
- Intent priority
- main branch

## 通常回帰結果

failing validation HEAD `4f055837f87ba40a3a9fa4c49eaf9744f3020128`

- XCTest: **60 / 60 PASS**
- Swift Testing: **16 PASS**
- STATIC_VERIFY: **PASS**
- Device Build: **PASS** — run `36936518711`
- Simulator Build: **PASS**
- Simulator E2E: **PASS** — run `36936518506`
- Simulator stage: `complete`
- context_semantics_status: PASS
- context_rook_pawn_intent: `rook_pawn_response`
- context_geometry_primary: false
- context_knowledge_records: 1281
- context_schema8_audit: PASS
- context_schema8_target_confidence: high

つまり、既存回帰はすべて通る一方、実戦範囲拡張によって初めてblocking defectが露出した。

## False Explanation / Frequency / Readability監査

最終集計は**未完了**。

runtime trapが最終JSON/Markdown serialization前に発生したため、以下を0件として扱ってはならない。

- Concept補足率: N/A
- piece_mobility件数: N/A
- escape_route_control件数: N/A
- attack_attacker件数: N/A
- 重大False Explanation件数: N/A
- 連続反復問題: INCOMPLETE
- 初心者向け自然さ問題: INCOMPLETE

Build17-6の目的は実戦全体での自然さ・安全性確認なので、blocking crashを回避していない状態で途中118局面だけからPASS判定しない。

## 最小修正工程の設計

次は **Build16-R1「ContextIntentResolver Single-Candidate Overflow Correction」** を別工程として行う。

変更範囲を最小化する。

1. `ContextIntentResolver.resolve` のrunner-up不存在処理だけを修正する。
2. `Int.min` をscore-gap計算用sentinelとして使わない。
3. 2位候補が存在する場合は従来の15点差判定を維持する。
4. 2位候補が存在しない場合は、overflowする減算をせず「明確な単独首位」として扱う。
5. Intent順位、evidence weight、Build17-4 Concept検出、Build17-5説明選択には触れない。

必須追加回帰:

- single high-authority candidate / score >= 100 がtrapしない
- 複数候補時のscore-gap semantics不変
- 上記実戦ply 59をそのまま再生してtrapしない
- Locked Regression A PASS
- Mandatory B PASS
- XCTest / Swift Testing / STATIC_VERIFY PASS
- Device / Simulator PASS

その後、Build17-6へ戻り、同一fixtureで**240局面以上を最初から再実行**する。

## 最終報告形式

- Build17-6: **FAIL**
- 検証棋譜数: **2局に着手**（1局目60局面完了、2局目59手目で停止）
- 検証局面数: **118局面完了 / 119局面目でtrap**
- Concept補足率: **N/A — 監査中断**
- piece_mobility件数: **N/A**
- escape_route_control件数: **N/A**
- attack_attacker件数: **N/A**
- 重大False Explanation件数: **N/A — 0件扱い禁止**
- 連続反復問題: **INCOMPLETE**
- 初心者向け自然さ問題: **INCOMPLETE**
- Locked Regression: **PASS**
- XCTest: **60 / 60 PASS**
- Swift Testing: **16 PASS**
- Device Build: **PASS**
- Simulator Build: **PASS**
- Simulator E2E: **PASS**
- Build17-5 Frozen authority維持: **YES**
- 修正必要: **YES — Build16 Intent resolver**
- 次工程へ進行可能か: **Build17-6継続は不可。Build16-R1最小修正後に再開**

## 結論

Build17-6の実戦回帰は有効にblocking defectを検出した。

Primary Intent / Concept補足の設計を広げる工程には進まない。  
まずBuild16 resolverの単一候補overflowだけを最小修正し、Frozen境界を再検証してからBuild17-6を最初から再実行する。
