# Arena Launcher 修正内容

## 問題点

ユーザーが報告した問題：
- `arena-launcher.sh` を実行すると、tmuxセッションは作成される
- 各ウィンドウでOpencodeは起動する
- しかし、エージェントが実際には動作していない（プロンプトが入力されていない）

## 原因

1. **Opencode起動後の待機時間不足**
   - `opencode` コマンドを実行後、すぐにプロンプトを送信していた
   - Opencodeの完全起動には3-5秒かかるため、プロンプトが失われていた

2. **複数行プロンプトの送信方法**
   - 複数行のプロンプトを一度に `tmux send-keys` で送信していた
   - 改行が正しく処理されず、プロンプトが途中で切れていた

## 修正内容

### 修正版 arena-launcher.sh の変更点

1. **プロンプトファイルの作成**
   - `.arena/prompts/` ディレクトリにプロンプトファイルを保存
   - 各エージェント用のプロンプトを個別のファイルに分離

2. **Opencode起動後の待機時間を増加**
   - `sleep 1` → `sleep 3` に変更
   - Opencodeが完全に起動するまで待機

3. **プロンプトの1行ずつ送信**
   ```bash
   while IFS= read -r line; do
       tmux send-keys -t "$SESSION_NAME:planner" "$line"
       sleep 0.1
   done < "$planner_file"
   tmux send-keys -t "$SESSION_NAME:planner" Enter
   ```
   - プロンプトファイルを1行ずつ読み込み
   - 各行を個別に送信（0.1秒間隔）
   - 最後にEnterキーを送信してプロンプトを確定

## テスト方法

### 1. 既存のarenaセッションを削除

```bash
tmux kill-session -t arena
```

### 2. 修正版を実行

```bash
~/.config/opencode/tools/arena-launcher.sh "3Dブロック崩しゲームを作成してください"
```

### 3. tmuxセッションにアタッチ

```bash
tmux attach -t arena
```

### 4. 各ウィンドウを確認

```
Ctrl+b, 0  # planner
Ctrl+b, 1  # comp-A
Ctrl+b, 2  # comp-B
Ctrl+b, 3  # comp-C
Ctrl+b, 4  # qa-gate
Ctrl+b, 5  # integrator
```

各ウィンドウで以下を確認：
- Opencodeが起動している
- プロンプトが正しく入力されている
- エージェントが応答を開始している

## 期待される動作

### Central Planner (ウィンドウ0)
- 要件を分析
- タスクを分解
- 各チームに割り当て

### Competitor Teams (ウィンドウ1-3)
- comp-A: コア機能実装
- comp-B: データ層・インフラ
- comp-C: API設計・統合

### QA Gate (ウィンドウ4)
- 各チームの実装をレビュー
- コード品質を評価
- 勝者を選定

### Integrator (ウィンドウ5)
- 勝者の実装を統合
- コンフリクトを解決
- 最終実装を完成

## トラブルシューティング

### プロンプトが入力されない場合

1. **待機時間を増やす**
   ```bash
   # arena-launcher.sh の sleep 3 を sleep 5 に変更
   ```

2. **プロンプトファイルを確認**
   ```bash
   ls -la .arena/prompts/
   cat .arena/prompts/planner.txt
   ```

3. **手動でプロンプトを送信**
   ```bash
   tmux attach -t arena
   # ウィンドウ0に移動
   Ctrl+b, 0
   # プロンプトを手動で入力
   ```

### Opencodeが起動しない場合

1. **Opencodeのパスを確認**
   ```bash
   which opencode
   ```

2. **環境変数を確認**
   ```bash
   echo $PATH
   ```

3. **手動でOpencodeを起動**
   ```bash
   opencode
   ```

## 最終的な修正内容（解決済）

### 問題

`tmux send-keys` コマンドでプロンプトテキストを送信する際、テキストに `--` や `-` で始まる行があると、tmuxがそれをオプションとして誤認識してエラーが発生していました。

```
tmux: unknown option --  
usage: send-keys [-FHlMRX] [-N repeat-count] [-t target-pane] key ...
```

### 解決策

`tmux send-keys` コマンドに `--` オプションを追加し、それ以降の引数をすべてテキストとして扱うようにしました。

```bash
# 修正前
tmux send-keys -t "$SESSION_NAME:planner" "$line"

# 修正後
tmux send-keys -t "$SESSION_NAME:planner" -- "$line"
```

### 検証結果

修正後、すべてのウィンドウが正しく作成されることを確認しました。

```
0: planner* (1 panes)
1: comp-A (1 panes)
2: comp-B (1 panes)
3: comp-C (1 panes)
4: qa-gate (1 panes)
5: integrator- (1 panes)
```

---

## 今後の改善案

1. **エージェント指定オプションの使用**
   - `opencode --agent central-planner` のようにエージェントを指定
   - プロンプト送信の必要がなくなる

2. **Opencode APIの使用**
   - Opencode CLIではなく、APIを使用して直接エージェントを起動
   - より確実な制御が可能

3. **ステータス監視機能の追加**
   - 各エージェントの起動状態を監視
   - エラーが発生した場合は自動的に再起動

4. **ログ機能の追加**
   - 各エージェントの出力をログファイルに保存
   - 後から確認・分析が可能
