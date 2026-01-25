# MCP サーバー設定ガイド

このドキュメントでは、Opencodeで使用可能なMCPサーバーの設定方法を説明します。

## 修正内容

### 問題点と解決策

| MCPサーバー | 問題 | 解決策 |
|------------|------|--------|
| **context7** | パッケージ名が間違っていた | `@context7/mcp-server` → `@upstash/context7-mcp@latest` |
| **firecrawl** | 無効化されていた | `enabled: true` に変更 |
| **supabase** | 設定が不完全だった | コマンドとAccess Token設定を修正 |
| **vercel** | 無効化されていた | `enabled: true` に変更 |
| **railway** | 無効化されていた | `enabled: true` に変更 |
| **cloudflare-docs** | 無効化されていた | `enabled: true` に変更 |
| **clickhouse** | 無効化されていた | `enabled: true` に変更 |

---

## 事前準備

### 1. 環境変数の設定

`~/.bashrc` または `~/.zshrc` に以下を追加：

```bash
# GitHub (必須)
export GITHUB_PAT="ghp_xxxxxxxxxxxxxxxxxxxx"

# Firecrawl (オプション - 有料サービス)
# https://firecrawl.dev/ でAPI Keyを取得
export FIRECRAWL_API_KEY="fc-xxxxxxxxxxxxxxxxxxxx"

# Supabase (オプション)
# https://supabase.com/dashboard/account/tokens でAccess Tokenを取得
export SUPABASE_ACCESS_TOKEN="sbp_xxxxxxxxxxxxxxxxxxxx"
```

設定後、シェルを再起動するか以下を実行：
```bash
source ~/.bashrc  # または source ~/.zshrc
```

### 2. Railway CLI のインストールと認証

Railway MCPサーバーを使用する場合：

```bash
# Railway CLIをインストール
npm install -g @railway/cli

# Railwayにログイン
railway login
```

### 3. Vercel の認証

Vercel MCPサーバーは初回接続時にブラウザでOAuth認証を求められます。
特別な事前設定は不要です。

---

## 設定ファイルの適用

### 方法1: 設定ファイルを直接置き換え

```bash
# バックアップを作成
cp ~/.config/opencode/opencode.json ~/.config/opencode/opencode.json.bak

# 修正版を適用
curl -fsSL https://raw.githubusercontent.com/samurai2891/everything-opencode/main/opencode-mcp-fixed.json > ~/.config/opencode/opencode.json
```

### 方法2: 手動で修正

`~/.config/opencode/opencode.json` の `mcp` セクションを以下のように修正：

```json
"mcp": {
  "github": {
    "type": "local",
    "command": ["npx", "-y", "@modelcontextprotocol/server-github"],
    "environment": {
      "GITHUB_PERSONAL_ACCESS_TOKEN": "{env:GITHUB_PAT}"
    },
    "enabled": true
  },
  "memory": {
    "type": "local",
    "command": ["npx", "-y", "@modelcontextprotocol/server-memory"],
    "enabled": true
  },
  "sequential-thinking": {
    "type": "local",
    "command": ["npx", "-y", "@modelcontextprotocol/server-sequential-thinking"],
    "enabled": true
  },
  "context7": {
    "type": "local",
    "command": ["npx", "-y", "@upstash/context7-mcp@latest"],
    "enabled": true
  },
  "firecrawl": {
    "type": "local",
    "command": ["npx", "-y", "firecrawl-mcp"],
    "environment": {
      "FIRECRAWL_API_KEY": "{env:FIRECRAWL_API_KEY}"
    },
    "enabled": true
  },
  "supabase": {
    "type": "local",
    "command": ["npx", "-y", "@supabase/mcp-server-supabase@latest"],
    "environment": {
      "SUPABASE_ACCESS_TOKEN": "{env:SUPABASE_ACCESS_TOKEN}"
    },
    "enabled": true
  },
  "vercel": {
    "type": "remote",
    "url": "https://mcp.vercel.com",
    "enabled": true
  },
  "railway": {
    "type": "local",
    "command": ["npx", "-y", "@railway/mcp-server"],
    "enabled": true
  },
  "cloudflare-docs": {
    "type": "remote",
    "url": "https://docs.mcp.cloudflare.com/mcp",
    "enabled": true
  },
  "clickhouse": {
    "type": "remote",
    "url": "https://mcp.clickhouse.cloud/mcp",
    "enabled": true
  }
}
```

---

## 各MCPサーバーの詳細

### 1. GitHub (✅ 動作確認済み)

**用途**: GitHubリポジトリの操作、Issue/PR管理

**必要な環境変数**:
- `GITHUB_PAT`: GitHub Personal Access Token

**取得方法**:
1. https://github.com/settings/tokens にアクセス
2. "Generate new token (classic)" をクリック
3. 必要なスコープを選択（repo, read:org など）
4. トークンを生成してコピー

---

### 2. Memory (✅ 動作確認済み)

**用途**: 会話の記憶、コンテキストの保持

**必要な環境変数**: なし

---

### 3. Sequential Thinking (✅ 動作確認済み)

**用途**: 段階的な思考プロセスの支援

**必要な環境変数**: なし

---

### 4. Context7 (🔧 修正済み)

**用途**: 最新のライブラリドキュメントとコード例の取得

**修正内容**:
- パッケージ名: `@context7/mcp-server` → `@upstash/context7-mcp@latest`

**必要な環境変数**: なし（オプションでAPI Keyを設定可能）

**使い方**:
```
プロンプトに「use context7」を追加すると、最新のドキュメントを取得
```

---

### 5. Firecrawl (⚠️ API Key必要)

**用途**: Webスクレイピング、ページ内容の取得

**必要な環境変数**:
- `FIRECRAWL_API_KEY`: Firecrawl API Key

**取得方法**:
1. https://firecrawl.dev/ にアクセス
2. アカウントを作成
3. API Keyを取得

**注意**: 有料サービスです。API Keyがない場合は `enabled: false` にしてください。

---

### 6. Supabase (⚠️ Access Token必要)

**用途**: Supabaseプロジェクトの管理

**必要な環境変数**:
- `SUPABASE_ACCESS_TOKEN`: Supabase Access Token

**取得方法**:
1. https://supabase.com/dashboard/account/tokens にアクセス
2. "Generate new token" をクリック
3. トークンを生成してコピー

---

### 7. Vercel (🔐 OAuth認証)

**用途**: Vercelプロジェクトの管理、デプロイ

**必要な環境変数**: なし

**認証方法**:
- 初回接続時にブラウザでVercelにログインを求められます
- ログイン後、自動的に接続されます

---

### 8. Railway (🔐 CLI認証)

**用途**: Railwayプロジェクトの管理、デプロイ

**必要な環境変数**: なし

**事前準備**:
```bash
# Railway CLIをインストール
npm install -g @railway/cli

# Railwayにログイン
railway login
```

---

### 9. Cloudflare Docs (✅ 設定不要)

**用途**: Cloudflareドキュメントの検索

**必要な環境変数**: なし

---

### 10. ClickHouse (✅ 設定不要)

**用途**: ClickHouseデータベースの操作

**必要な環境変数**: なし

---

## トラブルシューティング

### MCPサーバーが接続できない場合

1. **環境変数を確認**
   ```bash
   echo $GITHUB_PAT
   echo $FIRECRAWL_API_KEY
   echo $SUPABASE_ACCESS_TOKEN
   ```

2. **Opencodeを再起動**
   ```bash
   # Opencodeを終了して再起動
   opencode
   ```

3. **MCPサーバーの状態を確認**
   ```
   /mcp
   ```

4. **ログを確認**
   ```bash
   cat ~/.config/opencode/logs/mcp.log
   ```

### Context7が "Connection closed" エラーになる場合

パッケージ名が正しいか確認してください：
- ❌ `@context7/mcp-server`
- ✅ `@upstash/context7-mcp@latest`

### Firecrawlが動作しない場合

API Keyが設定されているか確認：
```bash
echo $FIRECRAWL_API_KEY
```

API Keyがない場合は、`enabled: false` に設定してください。

---

## 参考リンク

- [Opencode MCP Documentation](https://opencode.ai/docs/mcp-servers/)
- [Context7 GitHub](https://github.com/upstash/context7)
- [Firecrawl](https://firecrawl.dev/)
- [Supabase MCP](https://supabase.com/docs/guides/getting-started/mcp)
- [Vercel MCP](https://vercel.com/docs/mcp/vercel-mcp)
- [Railway MCP](https://docs.railway.com/reference/mcp-server)
