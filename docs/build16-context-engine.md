# Build 16 — 局面文脈エンジン 設計・外部資産採用記録

基準日: 2026-10-01
対象ブランチ: candidate/build16-context-engine

## 1. 目的

Build 15 の短評は局所差分と幾何特徴を中心にしており、△8五歩→▲7七角を単なる「相手玉へ近づいた攻め」と誤解釈し得た。
Build 16 は文章生成の前に Fact / Context Change / Effect / Intent / Outcome / Confidence を構造化し、「なぜ今この手か」を判定する。

## 2. 根拠優先順位

1. 直前手との因果関係
2. 定跡・前例
3. エンジンPV / 反実仮想比較
4. 具体的な盤面機能変化
5. 幾何特徴

幾何特徴だけでは主Intentを確定しない。

## 3. 初期実装

- 直前手と現在手の前後局面を再構築する。
- 飛車先歩前進への応答を rook_pawn_response として因果検出する。
- 直前手で新しく発生した角筋への応答を bishop_line_response として検出する。
- 新たに狙われた駒が攻撃駒を取る / 逃げる場合を capture_threat_response として扱う。
- 王手から玉が安全地点へ移る場合を king_escape とする。
- 持駒投入を hand_piece_deployment として扱う。
- 駒の可動域増加を piece_activation / major_piece_activation の盤面効果として扱う。
- check / capture / promotion / drop は原則Fact / Effectであり、それだけをIntentとはしない。

## 4. 最重要回帰

- position: position startpos moves 7g7f 8c8d 2g2f 8d8e
- current move: 8h7g
- expected primary intent: rook_pawn_response
- required evidence: previous_move_causality
- forbidden primary intent: geometry-only attack_preparation
- expected confidence: HIGH

角筋回帰は position startpos moves 7g7f 3c3d / current 8h2b+ で bishop_line_response を要求する。

## 5. 外部資産 A/B/C/D

### A — アプリへ直接導入

現時点では大型棋譜DB・大型定跡DBは該当なし。iPhone配布サイズ、更新、出典、局面キー、不要データ量を考えるとフルDB同梱は過大。

### B — 開発時に変換し、小型DBのみ生成

新ペタショック定跡233万局面:
- https://yaneuraou.yaneu.com/2025/06/22/2-33m-book-released-for-free/
- https://github.com/yaneurao/YaneuraOu/releases/tag/new_petabook233
- 公式記事でWCSC35使用定跡233万局面をMIT Licenseとして公開。
- 原本直接同梱ではなく、必要局面のみ正規化・抽出する候補。

電竜戦棋譜:
- https://denryu-sen.jp/dr4/dr4_rule.pdf
- https://denryu-sen.jp/denryusen/dr6_production/dr1_live.php
- https://denryu-sen.jp/denryusen/dr7_tsec7/dr1_live.php
- 大会ルール第27条および公式配布ページで棋譜の自由な使用・公開が明記されている。

WCSC棋譜:
- https://www.computer-shogi.org/wcsc23/rule.html
- 公開ルールには棋譜利用・公開の条項がある。実採用時は対象年度の公式条件をmanifestへ保存する。

### C — 研究・設計・開発用

KiriCompass:
- https://github.com/shuhei-kc/KiriCompass
- software license: MIT
- 2026-07-12 README: full約105.8万局、7z約4.0GB、展開後約7.2GB、sample約6.9万局/466MB。
- normalized SFEN由来の決定的position key、gameとposition indexの分離、candidate frequency、最頻前例PV、SQLite read-only lookupを設計参考にする。
- MITはKiriCompassソフトウェアの条件であり、統合元棋譜すべての再配布条件を一括保証するものとは扱わない。

Floodgate:
- https://wdoor.c.u-tokyo.ac.jp/
- 公開取得可能だが、派生DB再配布条件を明示する一次資料をBuild16調査時点で確認できていない。
- 当面、配布用コンパクトDBの元データには使用しない。

### D — Build 16へ新規直接取り込みしない

YaneuraOu本体はGPL-3.0。本リポジトリは既にYaneuraOu/native bridgeを利用しTHIRD_PARTY.mdへ記録済みだが、文脈エンジン用に外部GPLコードを追加コピーする必要はない。Core側で独立実装する。

## 6. 研究上の根拠

将棋解説研究でも、自然言語を直接自由生成する前に、局面・指し手から解説対象や特徴を抽出する二段階構成が用いられている。

- 2013: 将棋解説の自動生成のための局面からの特徴語生成
- 2014: 対数線形言語モデルを用いた将棋解説文の自動生成
- 2017: 将棋解説文生成のための解説すべき手順の予測
- 2025: 局面に対応したコメント検索を用いた大規模言語モデルによる将棋解説文生成

Build 16もFact/Context/Intent/Evidenceを先に確定し、自然言語は後段の表現層とする。

## 7. 外部知識境界

外部知識は MoveContextKnowledgeProvider 経由のみとし、外部DBがなくても因果・盤面機能で動作する。
将来のcompact knowledgeは normalized position key / candidate move / source kind / source ID / observation count / continuation / supported intent evidence / source manifest を最低限保持する。

## 8. 反実仮想

Build 15 Adaptive v2 のbest move対actual move同条件探索を、Build16初期段階では engine_pv / counterfactual evidence として再利用する。
comparisonStableでない評価差は理由断定へ使わない。追加探索は既存Adaptive情報で不足する低Confidence重要局面に限定する。

## 9. Build 16 完了条件

- Core context model
- previous-move causality
- opening/precedent provider境界
- compact knowledge format
- PV/counterfactual evidence
- confidence
- schema 8 diagnostics
- required intent regression matrix
- Build 15 full regression
- Device Build
- Simulator E2E
- diagnostics inspection
- 実機確認後のpromotion判断

最初のIntent回帰が通っただけではBuild16完成としない。UI文言の置換は内部判定の回帰安定後に行う。
## 10. 第4段階A — 実データ知識生成経路

- 初回の実データ元は、第2回マイナビニュース杯電竜戦統一ハードウェア戦の公式KIF（250局）とする。
- 公式ページは「棋譜利用は制限等ありませんので、ご自由にお使いください。」と明記している。
- GitHub Actionsで公式ZIPを取得し、既存の KIFParser で解析する。
- ContextKnowledgeBuilder が局面を NormalizedPositionKey に正規化し、同一局面・同一指し手の観測数を集約する。
- 初期設定は最大80手、2観測以上のみを出力する。
- 生棋譜から生成するレコードの intent は必ず unresolved とする。
- raw opening/precedent evidence は単独でIntentを作らず、既存の非geometry根拠で検出済みのIntentだけを補強する。
- curatedな意味ラベルを将来追加する場合は、raw生成物とは別の検証済み入力として扱う。
- 生成JSONは schemaVersion=1、source manifest、build statistics、compact recordsを保持する。
- この段階では生成JSONをArtifactとして監査し、内容・容量・回帰を確認した後にアプリ同梱へ進む。
