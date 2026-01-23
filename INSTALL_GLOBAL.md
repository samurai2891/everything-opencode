# everything-opencode グローバル設定インストール手順

このドキュメントでは、GitHubリポジトリから `everything-opencode` をグローバル設定として適用する手順を説明します。

## 概要

グローバル設定として適用することで、すべてのプロジェクトで以下の機能が利用可能になります：

- **9つのエージェント**: planner, code-reviewer, security-reviewer, architect, tdd-guide, build-error-resolver, e2e-runner, refactor-cleaner, doc-updater
- **Arena Competition System**: 複数LLMエージェントを並列実行して競争させるシステム（central-planner, comp-a/b/c, qa-gate, integrator）
- **10のコマンド**: /plan, /code-review, /security-audit, /architect, /tdd, /build-fix, /e2e, /refactor, /doc-sync, /arena
- **5つのスキル**: code-quality, security-best-practices, test-driven-development, refactoring-patterns, documentation-standards

## 前提条件

- **Opencode**: インストール済みであること
- **tmux**: Arena Competition Systemを使用する場合は必須
- **GitHub CLI (gh)**: リポジトリをクローンするために推奨

```bash
# tmuxのインストール（Ubuntu/Debian）
sudo apt install tmux

# GitHub CLIのインストール（Ubuntu/Debian）
sudo apt install gh

# macOSの場合
brew install tmux gh
```

## インストール手順

### Step 1: 既存のグローバル設定をバックアップ（オプション）

既存のグローバル設定がある場合は、バックアップを作成します。

```bash
# 既存の設定をバックアップ
if [ -d ~/.config/opencode ]; then
    BACKUP_DIR=~/.config/opencode.backup.$(date +%Y%m%d_%H%M%S)
    cp -r ~/.config/opencode "$BACKUP_DIR"
    echo "バックアップ完了: $BACKUP_DIR"
fi
```

### Step 2: GitHubリポジトリをクローン

一時ディレクトリにリポジトリをクローンします。

```bash
# 一時ディレクトリに移動
cd /tmp

# 既存のクローンを削除（存在する場合）
rm -rf everything-opencode

# GitHubリポジトリをクローン
gh repo clone samurai2891/everything-opencode

# または、HTTPSでクローン
git clone https://github.com/samurai2891/everything-opencode.git
```

### Step 3: グローバル設定をインストール

`install-global.sh` スクリプトを実行して、グローバル設定をインストールします。

```bash
# クローンしたディレクトリに移動
cd /tmp/everything-opencode

# インストールスクリプトを実行
bash install-global.sh
```

インストールスクリプトは以下を実行します：

1. `~/.config/opencode/` ディレクトリを作成
2. エージェント、コマンド、スキルをコピー
3. `opencode.json` をコピー
4. ツール（`arena-launcher.sh`, `gen_tmuxp.py`）をコピー
5. スクリプトをコピー
6. 実行権限を付与

### Step 4: 環境変数を設定（オプション）

APIキーなどの環境変数を設定する場合は、`.env` ファイルを作成します。

```bash
# .env.exampleをコピー
cp /tmp/everything-opencode/.env.example ~/.config/opencode/.env

# .envファイルを編集してAPIキーを設定
vi ~/.config/opencode/.env
```

`.env` ファイルの例：

```bash
# OpenAI API Key
OPENAI_API_KEY=sk-...

# Anthropic API Key
ANTHROPIC_API_KEY=sk-ant-...

# その他の環境変数
```

環境変数を読み込むために、`~/.bashrc` または `~/.zshrc` に以下を追加：

```bash
# Opencode環境変数を読み込む
if [ -f ~/.config/opencode/.env ]; then
    export $(grep -v '^#' ~/.config/opencode/.env | xargs)
fi
```

### Step 5: インストールを確認

グローバル設定が正しくインストールされたか確認します。

```bash
# グローバル設定ディレクトリの内容を確認
ls -la ~/.config/opencode/

# エージェント一覧
ls ~/.config/opencode/agents/

# コマンド一覧
ls ~/.config/opencode/commands/

# ツール一覧
ls -la ~/.config/opencode/tools/
```

### Step 6: Opencodeを起動

Opencodeを起動して、グローバル設定が適用されていることを確認します。

```bash
# Opencodeを起動
opencode
```

起動後、以下のコマンドが利用可能になります：

- `/plan` - プロジェクト計画を立案
- `/code-review` - コードレビューを実施
- `/security-audit` - セキュリティ監査を実施
- `/architect` - アーキテクチャ設計を支援
- `/tdd` - TDD開発を支援
- `/build-fix` - ビルドエラーを解決
- `/e2e` - E2Eテストを実行
- `/refactor` - リファクタリングを実施
- `/doc-sync` - ドキュメントを更新
- **`/arena`** - Arena Competition Systemを起動

## Arena Competition System の使用方法

### 基本的な使い方

```bash
# Opencodeを起動
opencode

# /arenaコマンドを実行
> /arena 3Dブロック崩しゲームを作成してください
```

### 直接スクリプトを実行

```bash
# arena-launcher.shを直接実行
~/.config/opencode/tools/arena-launcher.sh "3Dブロック崩しゲームを作成してください"

# チーム数を指定
~/.config/opencode/tools/arena-launcher.sh --teams 5 "ECサイトのカート機能を実装してください"

# 要件ファイルから読み込み
~/.config/opencode/tools/arena-launcher.sh --file requirements.md
```

### tmuxセッションの確認

```bash
# Arenaセッションにアタッチ
tmux attach -t arena

# ウィンドウ切り替え
Ctrl+b, n  # 次のウィンドウ
Ctrl+b, p  # 前のウィンドウ
Ctrl+b, 0-5  # 番号でウィンドウ選択

# セッション一覧
tmux list-sessions

# セッション終了
tmux kill-session -t arena
```

## アンインストール

グローバル設定を削除する場合は、以下を実行します。

```bash
# グローバル設定を削除
rm -rf ~/.config/opencode

# バックアップから復元（バックアップがある場合）
cp -r ~/.config/opencode.backup.YYYYMMDD_HHMMSS ~/.config/opencode
```

## トラブルシューティング

### スクリプトが見つからない

```bash
# スクリプトの場所を確認
ls -la ~/.config/opencode/tools/arena-launcher.sh

# 実行権限を付与
chmod +x ~/.config/opencode/tools/arena-launcher.sh
chmod +x ~/.config/opencode/tools/gen_tmuxp.py
```

### tmuxがインストールされていない

```bash
# Ubuntu/Debian
sudo apt install tmux

# macOS
brew install tmux
```

### Opencodeが設定を認識しない

```bash
# Opencodeの設定ディレクトリを確認
echo $XDG_CONFIG_HOME

# デフォルトは ~/.config/opencode
ls -la ~/.config/opencode/opencode.json
```

### 環境変数が読み込まれない

```bash
# .envファイルを確認
cat ~/.config/opencode/.env

# 手動で環境変数を読み込む
export $(grep -v '^#' ~/.config/opencode/.env | xargs)

# 環境変数を確認
echo $OPENAI_API_KEY
```

## 更新方法

新しいバージョンが公開された場合は、以下の手順で更新します。

```bash
# 1. 最新版をクローン
cd /tmp
rm -rf everything-opencode
gh repo clone samurai2891/everything-opencode

# 2. 既存の設定をバックアップ（オプション）
BACKUP_DIR=~/.config/opencode.backup.$(date +%Y%m%d_%H%M%S)
cp -r ~/.config/opencode "$BACKUP_DIR"

# 3. 新しい設定をインストール
cd /tmp/everything-opencode
bash install-global.sh

# 4. 環境変数を再設定（必要に応じて）
cp ~/.config/opencode/.env.backup ~/.config/opencode/.env
```

## 参考リンク

- **GitHubリポジトリ**: https://github.com/samurai2891/everything-opencode
- **README**: https://github.com/samurai2891/everything-opencode/blob/main/README.md
- **AGENTS**: https://github.com/samurai2891/everything-opencode/blob/main/AGENTS.md

## サポート

問題が発生した場合は、GitHubのIssuesで報告してください：
https://github.com/samurai2891/everything-opencode/issues
