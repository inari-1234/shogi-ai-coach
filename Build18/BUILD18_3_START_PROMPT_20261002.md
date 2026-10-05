# 将棋AIコーチ

## Build18-3
### 「Grounded WhyNow Limited Implementation」専用

開発引き継ぎ・開始指示

基準日：2026-10-02  
対象リポジトリ：`inari-1234/shogi-ai-coach`

==================================================
1. このチャットの位置づけ
==================================================

Build18-2「Diagnostic Corpus / Annotation Design & Freeze」が
**COMPLETE / FROZEN CANDIDATE** になった後に開始する、
Grounded WhyNow の**限定Production実装工程**です。

Build18-1 / Build18-2で固定した意味境界を実装へ接続します。

この工程では既存Intent Resolverを作り直しません。

==================================================
2. 上流authority
==================================================

Baseline main:
`fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`

Build18-1 specification HEAD:
`ea37b850c72fd07b328adbd046892b647edf8c2f`

Build18-2 Annotation Schema SHA-256:
`3b7453198c25504dbb94226fc9863a2e53a9b86d29b19c1398b5ae6b32884d1a`

Build18-2 status:
**COMPLETE / FROZEN CANDIDATE**

Build18-2 Diagnostic Corpus:
`BUILD18_2_DIAGNOSTIC_CORPUS_20261002.json`

Build18-2 Corpus Validation:
`BUILD18_2_CORPUS_VALIDATION_20261002.json`

Build18-2 Final Report:
`BUILD18_2_FINAL_REPORT_20261002.md`

==================================================
3. 実装目的
==================================================

既存の

Fact -> ContextChange -> Effect -> Intent -> Outcome -> Confidence

を変更せず、その後段へ

GroundedExplanationContext -> Explanation

を限定実装してください。

目的は、

「なぜこの手を今指したのか」

を、既存解析で確認済みのEvidence / Signalだけから安全に説明することです。

==================================================
4. 絶対に変更しないもの
==================================================

- MoveIntent enum
- ContextIntentResolver
- Intent score / evidence weight
- confidence threshold
- Build17 safe Concept detector semantics
- Build17 Concept explanation safety rules
- Locked Regression behavior
- Build18-2 Frozen Annotation Schema
- Build18-2 corpus labels

これらの変更が必要になった場合は実装を続行せず、
**ARCHITECTURE AMENDMENT REQUIRED**
として切り分けてください。

==================================================
5. 実装境界
==================================================

原則として `ContextEngine.swift` のresolver責務へ入らず、
新規projection type / fileを優先してください。

GroundedExplanationContextはresolverではありません。

selectedIntent / confidenceをread-onlyで受け取り、
説明に使用可能なclaimへ投影するだけです。

==================================================
6. 最重要安全規則
==================================================

- Effect -> Intent 自動昇格禁止
- Outcome -> Reason 逆転禁止
- geometry-only purpose禁止
- opening / precedent only purpose禁止
- LOW / UNRESOLVEDでassertive purpose禁止
- previousMoveをgeometryから復元しない
- fictitious opponent plan禁止
- fictitious mate / threatmate禁止
- unsupported Shikenbisha strategy label禁止
- specialized knowledgeはExplanation-only

==================================================
7. Frozen WhyNow Trigger
==================================================

使用可能なのは以下のみです。

- DIRECT_PREVIOUS_MOVE
- IMMEDIATE_THREAT
- FORCING_TACTIC
- EXCHANGE_SEQUENCE
- VERIFIED_SEQUENCE_TIMING
- FORMATION_WINDOW
- ENDGAME_URGENCY
- NONE_IDENTIFIED

Build18-2 corpusの期待値をテストauthorityとして使用してください。

==================================================
8. 初期実装scope
==================================================

まず実装対象を安全な範囲へ限定してください。

優先:

1. DIRECT_PREVIOUS_MOVE
2. 明示的IMMEDIATE_THREAT
3. 明示的FORCING_TACTIC
4. 明示的EXCHANGE_SEQUENCE
5. NONE_IDENTIFIED fallback

VERIFIED_SEQUENCE_TIMING / FORMATION_WINDOW / ENDGAME_URGENCYは、
必要Evidence gateを満たす場合だけ有効化してください。
不足する場合はNONE_IDENTIFIED / limited wordingへ落としてください。

==================================================
9. Diagnostic Corpus回帰
==================================================

Build18-2 corpus 360 unique positionsを回帰authorityとして使用してください。

最低限:

- all required records parse
- Frozen trigger expectation
- forbiddenClaims violation 0
- Effect->Intent violation 0
- LOW/UNRESOLVED assertive claim 0
- Shikenbisha boundary violation 0
- Locked Regression PASS
- high-risk Concept false positive 0

を検証してください。

==================================================
10. Production実装の進め方
==================================================

現状確認
-> 差分設計
-> 最小実装
-> 静的検証
-> Build18-2 corpus回帰
-> Locked Regression
-> 既存Build17回帰
-> Device / Simulator build/test
-> 保存後再検証

の順で進めてください。

途中版をCOMPLETE扱いしないでください。

==================================================
11. 完了条件
==================================================

Build18-3のPASS条件は実装開始後に、Build18-1/2 authorityを基準に具体化してください。
少なくともIntent/Confidenceの不変性とCorpus全回帰はblocking gateです。

Build18-3内でBuild18-4以降へ先行しないでください。