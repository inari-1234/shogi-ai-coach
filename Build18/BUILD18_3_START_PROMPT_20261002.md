# 将棋AIコーチ

## Build18-3
### 「Grounded WhyNow Limited Implementation」専用

基準日：2026-10-02  
対象リポジトリ：`inari-1234/shogi-ai-coach`

### 1. 位置づけ

Build18-1「Grounded WhyNow Specification / Architecture Freeze」と、
Build18-2「Diagnostic Corpus / Annotation Design & Freeze」が
**COMPLETE / FROZEN CANDIDATE** になった後に開始する、限定実装工程です。

この工程では、既存の正しい Intent / Confidence を変更せず、
`GroundedExplanationContext` を Explanation-only projection layer として実装します。

### 2. Input authority

- baseline main: `fd35c8b990379ebccbf1711d1cc0fa4a8464d53d`
- Build18-1 Frozen Candidate 一式
- Build18-2 Frozen Candidate 一式
- Build17 Locked Regression
- Build17-6R real-game regression assets

### 3. 絶対保護対象

変更禁止:

- `MoveIntent`
- `ContextIntentResolver`
- Intent scoring / evidence weights
- confidence thresholds
- Build17-4 three Concept detector semantics
- Build17-5 Concept explanation safety rules
- Locked Regression expected Intent / Confidence

`ContextEngine.swift` の protected resolver path を変更する必要が生じた場合は、
実装を止めて Architecture Amendment gate を開いてください。

### 4. 実装範囲

優先して新規 projection type / file を作成し、

`Fact -> ContextChange -> Effect -> Intent -> Outcome -> Confidence -> GroundedExplanationContext -> Explanation`

を実装してください。

v1で実装可能な why-now trigger は、実Evidenceで確認できるものに限定します:

- DIRECT_PREVIOUS_MOVE
- IMMEDIATE_THREAT
- FORCING_TACTIC
- EXCHANGE_SEQUENCE
- NONE_IDENTIFIED

以下は必要Evidenceが揃わない限り出力しません:

- VERIFIED_SEQUENCE_TIMING
- FORMATION_WINDOW
- ENDGAME_URGENCY

### 5. Semantic hard blockers

- Effect -> Intent 自動昇格禁止
- Outcome -> reason 逆推論禁止
- geometry-only purpose 禁止
- opening / precedent-only purpose 禁止
- LOW / UNRESOLVED assertive purpose 禁止
- fictitious opponent plan 禁止
- fictitious mate / threatmate 禁止
- unsupported Shikenbisha strategy label 禁止
- waiting_move / prophylaxis / sabai 等を新Intentとして実装しない

### 6. Diagnostic Corpus gate

Build18-2 corpus全体を regression authority として使用してください。

最低条件:

- unique positions >= 300 authorityを保持
- mandatory strataを全て回帰
- every `forbiddenClaims` violation = 0
- Locked Regression PASS
- precedent-only rowsで Intent / previousMove / why-now を捏造しない
- Shikenbisha subsetで specialized provider境界を破らない

### 7. 実装成果物

最低限:

- GroundedExplanationContext implementation
- projection / traceability tests
- trigger selection tests
- uncertainty verbalization tests
- Build18-2 corpus regression runner
- Build18-3 STATIC AUDIT
- Build18-3 FINAL REPORT

### 8. PASS条件

- Production build/test PASS
- Build17 Locked Regression PASS
- Build18-2 corpus mandatory strata PASS
- semantic blocker 0
- resolver path behavior unchanged
- Intent / Confidence mutation 0
- false previous-move causality 0
- LOW / UNRESOLVED assertive purpose 0
- cross-review PASS

PASS後のみ、次工程の独立検証 / Freezeへ進んでください。
