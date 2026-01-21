# Everything OpenCode

**Everything OpenCode** は、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の思想を継承し、OpenCodeプラットフォーム向けに最適化された、包括的な開発ワークフロー強化のための設定集です。AIエージェント、カスタムコマンド、共有スキルを組み合わせることで、開発のあらゆる側面を自動化・高度化します。

この設定集は、特に以下の最新モデルと開発環境での利用を想定して設計されています。

- **基本モデル**: `Codex 5.2 Xhigh` (OpenAI) - 環境変数で任意のモデルに切り替え可能
- **開発環境**: Linux (Ubuntu 24), Ghostty Terminal, tmux

## 主な特徴

- **専門家エージェント群**: 計画、コーディング、レビュー、セキュリティ監査など、各タスクに特化した9種類の専門家AIエージェントを提供します。
- **Arena Competition System**: 複数AIエージェントが並列で競争し、Quality Gate → ランキング → 勝者統合を経て最高品質のコードを生成する革新的なシステム。
- **コンテキストコマンド**: `/plan` や `/code-review` など、直感的なコマンドで各エージェントを呼び出し、開発フローを円滑に進めます。
- **共有スキルセット**: コーディング規約、セキュリティガイドライン、Gitワークフローなどのベストプラクティスを「スキル」として定義し、全エージェントが一貫した品質を維持します。
- **環境変数によるモデル切り替え**: 実行時に任意のモデルを指定可能。tmux/Tmuxp/SDKからの大量一括起動時に外部からモデルを指定できます。
- **ターミナル中心設計**: Ghosttyとtmuxを前提とした設計により、セッションの永続化とログへの容易なアクセスを実現します。

## 対応モデル

環境変数 `OPENCODE_MODEL` で以下のモデルを指定できます：

| プロバイダー | モデル名 |
|:---|:---|
| OpenAI | `openai/gpt-5.2-codex`, `openai/gpt-4o`, `openai/o1`, `openai/o3` |
| Anthropic | `anthropic/claude-sonnet-4-20250514`, `anthropic/claude-opus-4-20250514` |
| Google | `google/gemini-2.5-pro`, `google/gemini-2.5-flash` |
| Z.AI | `z-ai/glm-4.7`, `z-ai/glm-4.7-flash` |
| DeepSeek | `deepseek/deepseek-chat`, `deepseek/deepseek-coder` |
| Mistral | `mistral/mistral-large-latest`, `mistral/codestral-latest` |

## インストールと設定

### 1. リポジトリのクローン

```bash
git clone https://github.com/samurai2891/everything-opencode.git
cd everything-opencode
```

### 2. 設定ファイルの配置

#### オプションA: グローバルインストール（推奨）

すべてのプロジェクトで使用できるように、Opencodeのグローバル設定ディレクトリ（`~/.config/opencode/`）に配置します。

```bash
./install-global.sh
```

これにより、以下がインストールされます：
- エージェント（9個） → `~/.config/opencode/agents/`
- コマンド（9個） → `~/.config/opencode/commands/`
- スキル（5個） → `~/.config/opencode/skills/`
- ツール（Arena System） → `~/.config/opencode/tools/`
- スクリプト（バッチ起動） → `~/.config/opencode/scripts/`
- グローバル設定 → `~/.config/opencode/opencode.json`

**メリット**:
- どのプロジェクトでも即座に利用可能
- 一度設定すれば、すべてのプロジェクトで一貫した開発環境
- tmux/Ghosttyのどのセッションからでもアクセス可能

#### オプションB: プロジェクト単位でインストール

特定のプロジェクトにのみ配置する場合は、プロジェクトルートで以下を実行します。

```bash
./install.sh
```

**メリット**:
- プロジェクトごとにカスタマイズ可能
- Git管理できる
- チーム全体で共有可能

### 3. 環境変数の設定

```bash
cp .env.example .env
# .env ファイルを編集して、各値を設定
```

| 変数名 | 説明 |
| :--- | :--- |
| `OPENCODE_MODEL` | 使用するモデル（デフォルト: `openai/gpt-5.2-codex`） |
| `OPENCODE_SMALL_MODEL` | 軽量タスク用モデル |
| `OPENCODE_PLAN_MODEL` | 計画タスク用モデル |
| `OPENAI_API_KEY` | OpenAIのAPIキー |
| `ANTHROPIC_API_KEY` | AnthropicのAPIキー |
| `GOOGLE_API_KEY` | GoogleのAPIキー |
| `ZAI_API_KEY` | Z.AIのAPIキー |
| `GITHUB_PAT` | GitHubのPersonal Access Token |

## モデルの切り替え

### 方法1: 環境変数で指定

```bash
# Codex 5.2を使用（デフォルト）
export OPENCODE_MODEL="openai/gpt-5.2-codex"
opencode

# Claudeを使用
export OPENCODE_MODEL="anthropic/claude-sonnet-4-20250514"
opencode

# Geminiを使用
export OPENCODE_MODEL="google/gemini-2.5-pro"
opencode
```

### 方法2: .envファイルで設定

```bash
OPENCODE_MODEL=openai/gpt-5.2-codex
OPENCODE_SMALL_MODEL=openai/gpt-5.2-codex
OPENCODE_PLAN_MODEL=openai/gpt-5.2-codex
```

---

## Arena Competition System

**Arena Competition System** は、複数のAIエージェントが並列で競争し、Quality Gate → ランキング → 勝者統合 → 最終評価を経て、最高品質のコードを生成する革新的なシステムです。

### システム概要

```
┌─────────────────────────────────────────────────────────────────┐
│                    Arena Competition System                      │
├─────────────────────────────────────────────────────────────────┤
│  [Central Planner] ─────────────────────────────────────────────│
│         │                                                        │
│         ▼                                                        │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │           Competition Layer (Track A/B/C)                 │   │
│  │  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐  ┌─────┐           │   │
│  │  │ A01 │  │ A02 │  │ A03 │  │ B01 │  │ C01 │  ...      │   │
│  │  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘  └──┬──┘           │   │
│  └─────┼────────┼────────┼────────┼────────┼────────────────┘   │
│        │        │        │        │        │                     │
│        ▼        ▼        ▼        ▼        ▼                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Quality Gate                           │   │
│  │  - Auto tests (make test / pytest / npm test)            │   │
│  │  - Lint / Type check                                      │   │
│  │  - Coverage threshold                                     │   │
│  └─────────────────────────┬────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Ranking & Selection                    │   │
│  │  - PASS > DIRTY > FAIL                                   │   │
│  │  - Faster execution wins (same status)                   │   │
│  │  - winners.json generated                                 │   │
│  └─────────────────────────┬────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Integration                            │   │
│  │  - Merge winners into arena/integration branch           │   │
│  │  - Final gate on integrated code                         │   │
│  │  - Conflict resolution (if needed)                       │   │
│  └─────────────────────────┬────────────────────────────────┘   │
│                            │                                     │
│                            ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                    Final Product                          │   │
│  │  ✅ All gates passed                                      │   │
│  │  ✅ Best implementations merged                           │   │
│  │  ✅ Ready for release                                     │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### アリーナの起動

```bash
# /arena コマンドでアリーナを起動
opencode
> /arena

# または直接gen_tmuxp.pyを使用
python3 tools/gen_tmuxp.py generate --n 3 --gate-cmd "make test"
tmuxp load .tmuxp/arena.json
```

### アリーナエージェント

| エージェント | 役割 |
|:---|:---|
| `central-planner` | 要件分析、タスク分解、競争の監視、最終統合を統括 |
| `comp-a` | Track A競争チーム - コア機能の実装 |
| `comp-b` | Track B競争チーム - データ層とインフラ |
| `comp-c` | Track C競争チーム - API設計と統合 |
| `qa-gate` | Quality Gate - 品質評価とフィードバック |
| `integrator` | 勝者の統合、コンフリクト解決、最終成果物の準備 |

### 自動完走フロー

1. `/arena` コマンドで中央プランナーを起動
2. 要件を入力すると、中央プランナーがタスクを分解
3. `python3 tools/gen_tmuxp.py generate` でアリーナを生成
4. `tmuxp load .tmuxp/arena.json` で全チームを起動
5. 各チームが並列で実装を進める
6. Quality Gateが自動的に評価
7. ランキングが更新され、勝者が決定
8. Integratorが勝者をマージ
9. 最終Gateをパスして完了

### パイプライン実行

```bash
# pipelineウィンドウでEnterを押すと自動実行
# または手動で実行
python3 tools/gen_tmuxp.py pipeline --wait

# 個別に実行
python3 tools/gen_tmuxp.py gate --watch --interval 20
python3 tools/gen_tmuxp.py rank --watch --interval 20
python3 tools/gen_tmuxp.py integrate --reset --final-gate
```

---

## 大量一括起動（組織向け）

tmux、Tmuxp、Opencode SDKを使用して、複数プロジェクトを異なるモデルで一括起動できます。

### tmuxスクリプトを使用

```bash
# プロジェクト一覧を作成
cat > projects.txt << EOF
~/projects/main-app
~/projects/api-server
~/projects/frontend
EOF

# Codex 5.2で一括起動
./scripts/batch-launch.sh -m "openai/gpt-5.2-codex" -p projects.txt

# Claudeで一括起動
./scripts/batch-launch.sh -m "anthropic/claude-sonnet-4-20250514" -p projects.txt

# 特定のコマンドを実行
./scripts/batch-launch.sh -m "openai/gpt-5.2-codex" -p projects.txt -c "/plan"
```

### Tmuxpを使用

```bash
# 設定ファイルを生成
./scripts/generate-tmuxp.sh -m "openai/gpt-5.2-codex" -p projects.txt -o workspace.yaml

# Tmuxpで起動
tmuxp load workspace.yaml
```

### Opencode SDKを使用（Python）

```python
from scripts.sdk_batch_launcher import BatchLauncher, ModelPresets

# ランチャーを作成
launcher = BatchLauncher(model=ModelPresets.CODEX_52)

# プロジェクトを読み込み
projects = launcher.load_projects("projects.txt")

# 一括起動
await launcher.launch_batch(projects, command="/plan")
```

```bash
# コマンドラインから実行
python scripts/sdk_batch_launcher.py -m "openai/gpt-5.2-codex" -p projects.txt
python scripts/sdk_batch_launcher.py -m "anthropic/claude-sonnet-4-20250514" -p projects.txt -c "/plan"
```

---

## 提供されるコンポーネント

### エージェント (Agents)

| エージェント | 役割 |
| :--- | :--- |
| `planner` | 複雑な機能の実装計画を立案する |
| `code-reviewer` | コードの品質、セキュリティ、ベストプラクティスをレビューする |
| `security-reviewer` | セキュリティ脆弱性の詳細な監査を実施する |
| `architect` | システム設計とアーキテクチャに関する指針を提供する |
| `tdd-guide` | テスト駆動開発(TDD)のサイクルを徹底させる |
| `build-error-resolver`| ビルドやコンパイルのエラーを診断・修正する |
| `e2e-runner` | Playwrightを用いたE2Eテストを生成・実行する |
| `refactor-cleaner` | 技術的負債の返済とコードのリファクタリングを行う |
| `doc-updater` | コード変更に伴うドキュメントの同期を維持する |

### コマンド (Commands)

| コマンド | 説明 |
| :--- | :--- |
| `/plan` | 機能やリファクタリングの実装計画を作成します |
| `/code-review` | 最近のコード変更をレビューします |
| `/security-audit`| コードベース全体のセキュリティ監査を実行します |
| `/architect` | アーキテクチャに関する質問に回答し、設計を提案します |
| `/tdd` | TDDワークフローを開始し、テストを先行して実装します |
| `/build-fix` | ビルドエラーを自動的に修正します |
| `/e2e` | ユーザーフローに基づいたE2Eテストを生成します |
| `/refactor` | 指定されたコードのリファクタリングやクリーンアップを行います |
| `/doc-sync` | コードの変更に合わせてドキュメントを更新します |
| `/arena` | Arena Competition Systemを起動し、並列競争を開始します |

### スキル (Skills)

- **coding-standards**: TypeScript/Reactのベストプラクティス集
- **security**: 全てのコード変更に適用されるセキュリティガイドライン
- **tdd-workflow**: テスト駆動開発の具体的な手法と原則
- **tmux-integration**: Ghostty環境でのtmux活用法
- **git-workflow**: Conventional Commitsに基づいたGitのブランチ戦略とコミット規約

## ディレクトリ構造

```
everything-opencode/
├── opencode.json              # メイン設定ファイル
├── AGENTS.md                  # プロジェクトルール
├── .env.example               # 環境変数テンプレート
├── install.sh                 # インストールスクリプト
├── .opencode/
│   ├── agents/                # エージェント定義（15ファイル）
│   │   ├── planner.md
│   │   ├── code-reviewer.md
│   │   ├── security-reviewer.md
│   │   ├── architect.md
│   │   ├── tdd-guide.md
│   │   ├── build-error-resolver.md
│   │   ├── e2e-runner.md
│   │   ├── refactor-cleaner.md
│   │   ├── doc-updater.md
│   │   ├── central-planner.md   # Arena
│   │   ├── comp-a.md            # Arena
│   │   ├── comp-b.md            # Arena
│   │   ├── comp-c.md            # Arena
│   │   ├── qa-gate.md           # Arena
│   │   └── integrator.md        # Arena
│   ├── commands/              # スラッシュコマンド（10ファイル）
│   │   ├── plan.md
│   │   ├── code-review.md
│   │   ├── security-audit.md
│   │   ├── architect.md
│   │   ├── tdd.md
│   │   ├── build-fix.md
│   │   ├── e2e.md
│   │   ├── refactor.md
│   │   ├── doc-sync.md
│   │   └── arena.md             # Arena
│   └── skills/                # スキル定義（5ファイル）
├── tools/                     # アリーナツール
│   └── gen_tmuxp.py           # tmuxp生成・パイプライン実行
└── scripts/                   # バッチ起動スクリプト
    ├── batch-launch.sh        # tmux一括起動
    ├── generate-tmuxp.sh      # Tmuxp設定生成
    ├── tmuxp-template.yaml    # Tmuxpテンプレート
    ├── sdk_batch_launcher.py  # Python SDK起動
    └── projects.txt.example   # プロジェクト一覧サンプル
```

## 推奨ワークフロー

### 通常の開発

1. **計画**: 複雑な機能に着手する前に `/plan` で実装計画を立てます
2. **開発**: `/tdd` を使用して、テストを書きながら機能開発を進めます
3. **レビュー**: コミットする前に `/code-review` を実行し、品質をチェックします
4. **セキュリティ**: リリース前や重要な変更後には `/security-audit` で脆弱性がないか確認します
5. **ドキュメント**: `/doc-sync` を使い、コードとドキュメントの整合性を保ちます

### 大規模開発（Arena使用）

1. **アリーナ起動**: `/arena` で中央プランナーを起動
2. **要件入力**: 実装したい機能の要件を入力
3. **競争開始**: 中央プランナーがタスクを分解し、各チームに割り当て
4. **並列実装**: 複数チームが同時に実装を進める
5. **品質評価**: Quality Gateが自動的に評価
6. **勝者統合**: 最高品質の実装が自動的にマージ
7. **最終確認**: 統合後のコードが最終Gateをパス

## クレジット

このリポジトリは、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の優れたコンセプトに多大な影響を受けています。オリジナルの作者である affaan-m 氏に感謝します。
