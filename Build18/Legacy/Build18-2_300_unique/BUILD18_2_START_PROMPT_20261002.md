# 将棋AIコーチ

## Build18-2
### 「Diagnostic Corpus / Annotation Design & Freeze」専用

基準日：2026-10-02  
対象リポジトリ：`inari-1234/shogi-ai-coach`

### 1. 位置づけ

Build18-1「Grounded WhyNow Specification / Architecture Freeze」が COMPLETE / FROZEN CANDIDATE になった後に開始する、**Corpus設計・Annotation Freeze専用工程**です。

Production Codeは変更しません。Intent resolver、MoveIntent、weight、confidence threshold、Build17の3Concept意味も変更しません。

### 2. Input authority

- main baseline: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`
- Build18-1成果物一式
- Build17-3 Pilot / false-positive audit
- Build17-6R real-game regression assets

### 3. 目的

件数を増やすのではなく、**どの失敗モードを壊すための局面か**を明示したtargeted Diagnostic Corpusを作り、Grounded WhyNowを安全に実装できるannotation authorityをFreezeします。

### 4. 必須Corpus

Unique positions: **300以上**

cross-tag可。最低strata:

- Direct Previous-Move Causality: 40+
- Timing / Move Order: 40+
- Ambiguous / Multi-Intent: 40+
- Effect / Intent Boundary: 40+
- Counterfactual-demanding: 30+
- Endgame / Forcing: 40+
- Shikenbisha Dedicated: 60+
- Adversarial / Human-natural but Geometry-hard: 60+

### 5. 必須annotation

各positionに最低限:

- phase
- openingFamily
- previousMove
- currentMove
- primaryIntent
- confidence
- whyNowTrigger
- supportingEvidenceIDs
- sourceSignalIDs
- missingEvidence
- claimTypes
- expectedExplanationScope
- forbiddenClaims
- beginnerNote
- negativeOrAdversarialReason
- specializedReferenceDependency

Build18-1 schemaと一致させてください。

### 6. Safety

- 正例を作るためにラベルを捏造しない。
- opening nameだけでIntent/Conceptを確定しない。
- geometryだけで目的を付けない。
- EffectをIntentに昇格しない。
- LOW / UNRESOLVEDで断定しない。
- sabai / prophylaxis / waiting_move / tempo_management等は必要Evidenceが不足する局面を必ずnegative/adversarialへ含める。
- specialized knowledgeはExplanation-onlyの境界を維持する。

### 7. 成果物

最低限:

- BUILD18_2_ANNOTATION_SCHEMA
- BUILD18_2_DIAGNOSTIC_CORPUS
- BUILD18_2_SHIKENBISHA_SUBSET
- BUILD18_2_ADVERSARIAL_SUBSET
- BUILD18_2_CORPUS_AUDIT
- BUILD18_2_FINAL_REPORT

### 8. PASS条件

- unique positions >= 300
- mandatory quotaを全て満たす
- negative/adversarial coverageを満たす
- every position has forbiddenClaims
- Build17 Locked Regressionを含む
- Build18-1 trigger / claim type / evidence compatibilityと整合
- cross-review完了
- Production Code変更0

PASS後のみ、Build18-3「Grounded WhyNow Limited Implementation」開始プロンプトを作成して終了してください。
