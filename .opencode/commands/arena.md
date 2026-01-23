---
description: Arena Competition System - 複数LLMエージェントを並列実行して競争させる
---

# Arena Competition System 起動結果

以下のコマンドを実行してArena Competition Systemを起動しました：

!`~/.config/opencode/tools/arena-launcher.sh "$ARGUMENTS" 2>&1`

## 起動後の確認方法

Arenaセッションが起動しました。以下の手順で確認してください：

### 1. tmuxセッションにアタッチ

**別のターミナルウィンドウ**を開いて、以下のコマンドを実行してください：

```bash
tmux attach -t arena
```

### 2. ウィンドウ一覧

| ウィンドウ | 名前 | 役割 |
|-----------|------|------|
| 0 | planner | 中央プランナー（タスク分解・監視） |
| 1 | comp-A | チームA（コア機能実装） |
| 2 | comp-B | チームB（データ層・インフラ） |
| 3 | comp-C | チームC（API設計・統合） |
| 4 | qa-gate | QA Gate（品質評価） |
| 5 | integrator | 統合担当（最終統合） |

### 3. ウィンドウ切り替え

```
Ctrl+b, n     次のウィンドウ
Ctrl+b, p     前のウィンドウ
Ctrl+b, 0-5   番号でウィンドウ選択
```

## 注意事項

- このOpencodeセッションは終了しても構いません
- 各ウィンドウで別々のOpencodeエージェントが並列で動作しています
- 進捗を確認するには、tmuxセッションにアタッチしてください

## トラブルシューティング

### セッションが見つからない場合

```bash
# セッション一覧を確認
tmux list-sessions

# arenaセッションがない場合は手動で起動
~/.config/opencode/tools/arena-launcher.sh "要件テキスト"
```

### tmuxがインストールされていない場合

```bash
# Ubuntu/Debian
sudo apt install tmux

# macOS
brew install tmux
```
