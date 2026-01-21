# Everything OpenCode

**Everything OpenCode** は、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の思想を継承し、OpenCodeプラットフォーム向けに最適化された、包括的な開発ワークフロー強化のための設定集です。AIエージェント、カスタムコマンド、共有スキルを組み合わせることで、開発のあらゆる側面を自動化・高度化します。

この設定集は、特に以下の最新モデルと開発環境での利用を想定して設計されています。

- **基本モデル**: `Codex 5.2 Xhigh` (OpenAI) - 環境変数で任意のモデルに切り替え可能
- **開発環境**: Linux (Ubuntu 24), Ghostty Terminal, tmux

## 主な特徴

- **専門家エージェント群**: 計画、コーディング、レビュー、セキュリティ監査など、各タスクに特化した9種類の専門家AIエージェントを提供します。
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

```bash
# 現在のプロジェクトにインストールする場合
./install.sh

# グローバル設定としてインストールする場合
./install.sh --global
```

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
│   ├── agents/                # エージェント定義（9ファイル）
│   ├── commands/              # スラッシュコマンド（9ファイル）
│   └── skills/                # スキル定義（5ファイル）
└── scripts/                   # バッチ起動スクリプト
    ├── batch-launch.sh        # tmux一括起動
    ├── generate-tmuxp.sh      # Tmuxp設定生成
    ├── tmuxp-template.yaml    # Tmuxpテンプレート
    ├── sdk_batch_launcher.py  # Python SDK起動
    └── projects.txt.example   # プロジェクト一覧サンプル
```

## 推奨ワークフロー

1. **計画**: 複雑な機能に着手する前に `/plan` で実装計画を立てます
2. **開発**: `/tdd` を使用して、テストを書きながら機能開発を進めます
3. **レビュー**: コミットする前に `/code-review` を実行し、品質をチェックします
4. **セキュリティ**: リリース前や重要な変更後には `/security-audit` で脆弱性がないか確認します
5. **ドキュメント**: `/doc-sync` を使い、コードとドキュメントの整合性を保ちます

## クレジット

このリポジトリは、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の優れたコンセプトに多大な影響を受けています。オリジナルの作者である affaan-m 氏に感謝します。
