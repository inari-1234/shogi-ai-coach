# Shogi AI Coach

iPhone上で棋譜を読み込み、やねうら王 + NNUE の解析結果を根拠に重要局面を振り返る将棋AIコーチです。

## 現在の解析フロー

KIF取込 → 全局面の浅解析 → 重要局面抽出 → MultiPV深掘り → 盤面上の最善手表示 → 根拠付き理由解析

最善手・評価値・PVはやねうら王が担当し、アプリ側は実戦手との差分、盤面変化、理由候補を組み立てます。理由表示は「エンジン確認」「PV観測」「解釈候補」を分離し、エンジンで確認できない理由を事実として断定しません。

## Build 10 candidate

- App: v0.6.0 / Build 10
- YaneuraOu: V9.00 pinned
- NNUE: Suisho5
- Threads: 1
- Hash: 64MB
- iPhone / Simulator とも generic NNUE path（USE_NEON無効）
- KIF: 平手・本譜のUSI変換
- 全局面浅解析: 150ms/局面
- 深掘り: 重要3〜5局面 / MultiPV 3 / 800ms
- 診断JSON: schema 4

## Repository structure

通常のソースファイルをそのままGit管理し、Actionsでも同じファイルをビルドします。旧PoCの埋め込みZIPや工程別ソースの上書きは使用しません。

- `Sources/ShogiCoachCore/`: KIF / USI / 盤面モデル
- `Tests/ShogiCoachCoreTests/`: Core回帰
- `iOS/ShogiCoachPoC/`: iPhoneアプリ、解析ViewModel、診断
- `native/`: やねうら王ブリッジとPodspec
- `scripts/`: pinned engine / NNUE取得とiOS向け最小パッチ
- `.github/workflows/`: iPhone build / Simulator E2E
