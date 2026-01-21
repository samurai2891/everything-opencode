# Everything OpenCode

**Everything OpenCode** は、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の思想を継承し、OpenCodeプラットフォーム向けに最適化された、包括的な開発ワークフロー強化のための設定集です。AIエージェント、カスタムコマンド、共有スキルを組み合わせることで、開発のあらゆる側面を自動化・高度化します。

この設定集は、特に以下の最新モデルと開発環境での利用を想定して設計されています。

- **基本モデル**: `Codex 5.2 Xhigh` (OpenAI), `GLM-4.7` (Z.AI)
- **開発環境**: Linux (Ubuntu 24), Ghostty Terminal, tmux

## 主な特徴

- **専門家エージェント群**: 計画、コーディング、レビュー、セキュリティ監査など、各タスクに特化した9種類の専門家AIエージェントを提供します。
- **コンテキストコマンド**: `/plan` や `/code-review` など、直感的なコマンドで各エージェントを呼び出し、開発フローを円滑に進めます。
- **共有スキルセット**: コーディング規約、セキュリティガイドライン、Gitワークフローなどのベストプラクティスを「スキル」として定義し、全エージェントが一貫した品質を維持します。
- **柔軟なモデル設定**: `Codex 5.2` のような高性能モデルと `GLM-4.7` のような高速モデルをタスクに応じて使い分ける設定が組み込まれています。
- **ターミナル中心設計**: Ghosttyとtmuxを前提とした設計により、セッションの永続化とログへの容易なアクセスを実現します。

## インストールと設定

### 1. リポジトリのクローン

まず、このリポジトリをローカル環境にクローンします。

```bash
git clone https://github.com/samurai2891/everything-opencode.git
cd everything-opencode
```

### 2. 設定ファイルの配置

`install.sh` スクリプトを使用して、設定ファイルをプロジェクト、またはグローバルなOpenCode設定ディレクトリにコピーします。

```bash
# 現在のプロジェクトにインストールする場合
./install.sh

# グローバル設定としてインストールする場合
./install.sh --global
```

### 3. 環境変数の設定

`.env.example` を参考に `.env` ファイルを作成し、APIキーなどの必要な環境変数を設定してください。これらの変数は `opencode.json` から参照されます。

```bash
cp .env.example .env
# .env ファイルを編集して、各値を設定
```

| 変数名 | 説明 |
| :--- | :--- |
| `OPENAI_API_KEY` | OpenAIのAPIキー (`Codex 5.2`用) |
| `ZAI_API_KEY` | Z.AIのAPIキー (`GLM-4.7`用) |
| `ZAI_CODING_API_KEY` | (任意) Z.AIのコーディングプラン用APIキー |
| `GITHUB_PAT` | GitHubのPersonal Access Token (MCPサーバー用) |
| `FIRECRAWL_API_KEY` | (任意) FirecrawlのAPIキー (Webスクレイピング用) |
| `SUPABASE_PROJECT_REF`| (任意) SupabaseのプロジェクトID (DB操作用) |

### 4. OpenCodeでのプロバイダー接続

OpenCodeを起動し、`/connect` コマンドで必要なLLMプロバイダー (OpenAI, Z.AI) に接続します。

```
/connect
```

## 提供されるコンポーネント

### エージェント (Agents)

各開発フェーズを支援するために、以下の専門家エージェントが定義されています。

| エージェント | 役割 | デフォルトモデル |
| :--- | :--- | :--- |
| `planner` | 複雑な機能の実装計画を立案する | `GLM-4.7` |
| `code-reviewer` | コードの品質、セキュリティ、ベストプラクティスをレビューする | `Codex 5.2` |
| `security-reviewer` | セキュリティ脆弱性の詳細な監査を実施する | `Codex 5.2` |
| `architect` | システム設計とアーキテクチャに関する指針を提供する | `Codex 5.2` |
| `tdd-guide` | テスト駆動開発(TDD)のサイクルを徹底させる | `Codex 5.2` |
| `build-error-resolver`| ビルドやコンパイルのエラーを診断・修正する | `Codex 5.2` |
| `e2e-runner` | Playwrightを用いたE2Eテストを生成・実行する | `Codex 5.2` |
| `refactor-cleaner` | 技術的負債の返済とコードのリファクタリングを行う | `GLM-4.7` |
| `doc-updater` | コード変更に伴うドキュメントの同期を維持する | `GLM-4.7` |

### コマンド (Commands)

上記のエージェントを簡単に呼び出すためのカスタムコマンドが用意されています。

| コマンド | 説明 |
| :--- | :--- |
| `/plan` | 機能やリファクタリングの実装計画を作成します。 |
| `/code-review` | 最近のコード変更をレビューします。 |
| `/security-audit`| コードベース全体のセキュリティ監査を実行します。 |
| `/architect` | アーキテクチャに関する質問に回答し、設計を提案します。 |
| `/tdd` | TDDワークフローを開始し、テストを先行して実装します。 |
| `/build-fix` | ビルドエラーを自動的に修正します。 |
| `/e2e` | ユーザーフローに基づいたE2Eテストを生成します。 |
| `/refactor` | 指定されたコードのリファクタリングやクリーンアップを行います。 |
| `/doc-sync` | コードの変更に合わせてドキュメントを更新します。 |

### スキル (Skills)

エージェント群が一貫した高品質なアウトプットを生成するための、共有知識ベース（スキル）です。

- **coding-standards**: TypeScript/Reactのベストプラクティス集。
- **security**: 全てのコード変更に適用されるセキュリティガイドライン。
- **tdd-workflow**: テスト駆動開発の具体的な手法と原則。
- **tmux-integration**: Ghostty環境でのtmux活用法。
- **git-workflow**: Conventional Commitsに基づいたGitのブランチ戦略とコミット規約。

## 推奨ワークフロー

1.  **計画**: 複雑な機能に着手する前に `/plan` で実装計画を立てます。
2.  **開発**: `/tdd` を使用して、テストを書きながら機能開発を進めます。
3.  **レビュー**: コミットする前に `/code-review` を実行し、品質をチェックします。
4.  **セキュリティ**: リリース前や重要な変更後には `/security-audit` で脆弱性がないか確認します。
5.  **ドキュメント**: `/doc-sync` を使い、コードとドキュメントの整合性を保ちます。

## カスタマイズ

このリポジトリは、あなたのプロジェクトに合わせて自由にカスタマイズできます。`.opencode/` ディレクトリ内に新しいMarkdownファイルを追加することで、独自のエージェント、コマンド、スキルを定義できます。

## クレジット

このリポジトリは、[affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) の優れたコンセプトに多大な影響を受けています。オリジナルの作者である affaan-m 氏に感謝します。
