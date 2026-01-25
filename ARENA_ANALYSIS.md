# Arena Launcher 問題分析レポート

Tmux-Orchestrator (https://github.com/Jedward23/Tmux-Orchestrator.git) を参考に、
arena-launcher.sh の自動化が失敗する原因を分析しました。

## 1. Tmux-Orchestrator の主要な設計パターン

### 1.1 メッセージ送信の分離

```bash
# Tmux-Orchestrator の send-claude-message.sh
tmux send-keys -t "$WINDOW" "$MESSAGE"
sleep 0.5  # ← 重要: UIが登録するまで待機
tmux send-keys -t "$WINDOW" Enter
```

**ポイント**:
- メッセージとEnterキーを**別々に送信**
- 間に**0.5秒の待機**を入れる
- これにより、UIがメッセージを正しく受け取る

### 1.2 コマンド実行後の検証

```bash
# Tmux-Orchestrator のベストプラクティス
tmux send-keys -t session:window "command" Enter
sleep 2  # コマンド実行を待つ
tmux capture-pane -t session:window -p | tail -50  # 結果を確認
```

**ポイント**:
- コマンド実行後に**必ず結果を確認**
- `tmux capture-pane` で出力をキャプチャ
- エラーがあれば対処

### 1.3 ウィンドウ作成時のディレクトリ指定

```bash
# 正しい方法
tmux new-window -t session -n "window-name" -c "/correct/path"

# または作成後にcd
tmux new-window -t session -n "window-name"
tmux send-keys -t session:window-name "cd /correct/path" Enter
```

**ポイント**:
- `-c` フラグで作業ディレクトリを明示的に指定
- 新しいウィンドウはtmux起動時のディレクトリを継承するため

### 1.4 Claude起動後の待機時間

```bash
# Tmux-Orchestrator の推奨
tmux send-keys -t project:0 "claude" Enter
sleep 5  # ← Claude起動を待つ
# その後でメッセージを送信
```

**ポイント**:
- Claude/Opencode起動には**5秒以上**待機
- 起動が完了する前にメッセージを送ると無視される

---

## 2. 現在の arena-launcher.sh の問題点

### 問題1: 待機時間が短すぎる

**現在のコード**:
```bash
tmux send-keys -t "$SESSION_NAME:planner" "$OPENCODE_CMD" Enter
sleep 3  # ← 3秒では不十分な場合がある
```

**問題**:
- Opencodeの起動には環境によって3-10秒かかる
- 起動が完了する前にプロンプトを送信している

### 問題2: メッセージ送信方法

**現在のコード**:
```bash
while IFS= read -r line || [ -n "$line" ]; do
    tmux send-keys -t "$SESSION_NAME:planner" -- "$line"
    sleep 0.05  # ← 短すぎる
done < "$prompt_file"
tmux send-keys -t "$SESSION_NAME:planner" Enter
```

**問題**:
- 行ごとに0.05秒の待機は短すぎる
- 大量の行を高速で送信すると、UIが追いつかない
- 結果として、プロンプトが途中で切れる

### 問題3: 作業ディレクトリの未指定

**現在のコード**:
```bash
tmux new-session -d -s "$SESSION_NAME" -n "planner"
tmux new-window -t "$SESSION_NAME" -n "comp-${team}-1"
```

**問題**:
- `-c` フラグで作業ディレクトリを指定していない
- Opencodeが正しいプロジェクトディレクトリで起動しない可能性

### 問題4: 実行結果の検証がない

**現在のコード**:
- コマンド実行後に結果を確認していない
- Opencodeが正しく起動したか不明
- プロンプトが正しく送信されたか不明

### 問題5: エラーハンドリングの不足

**現在のコード**:
```bash
set -e  # エラーで即座に終了
```

**問題**:
- `set -e` により、小さなエラーでもスクリプト全体が停止
- 部分的な失敗からの回復ができない

### 問題6: プロンプトが長すぎる

**現在のプロンプト**:
- 約50行のプロンプトを送信
- LLMが全体を理解する前に実行を開始する可能性

**Tmux-Orchestratorのアプローチ**:
- 短い初期ブリーフィング
- 必要に応じて追加指示を送信

---

## 3. 改善策

### 改善1: 待機時間の増加

```bash
# Opencode起動後の待機を5秒以上に
tmux send-keys -t "$target" "$OPENCODE_CMD" Enter
sleep 5

# 行送信の間隔を0.1秒以上に
while IFS= read -r line || [ -n "$line" ]; do
    tmux send-keys -t "$target" -- "$line"
    sleep 0.1
done < "$prompt_file"
sleep 0.5  # Enter送信前に待機
tmux send-keys -t "$target" Enter
```

### 改善2: 専用のメッセージ送信スクリプト

```bash
#!/bin/bash
# send-opencode-message.sh

TARGET="$1"
MESSAGE="$2"

# メッセージを送信
tmux send-keys -t "$TARGET" -- "$MESSAGE"

# UIが登録するまで待機
sleep 0.5

# Enterを送信
tmux send-keys -t "$TARGET" Enter

echo "Message sent to $TARGET"
```

### 改善3: 作業ディレクトリの明示的指定

```bash
# 現在のディレクトリを取得
WORK_DIR=$(pwd)

# セッション作成時にディレクトリを指定
tmux new-session -d -s "$SESSION_NAME" -n "planner" -c "$WORK_DIR"

# ウィンドウ作成時にもディレクトリを指定
tmux new-window -t "$SESSION_NAME" -n "comp-${team}-1" -c "$WORK_DIR"
```

### 改善4: 実行結果の検証

```bash
start_agent() {
    local target="$1"
    local prompt_file="$2"
    
    # Opencode起動
    tmux send-keys -t "$target" "$OPENCODE_CMD" Enter
    sleep 5
    
    # 起動確認
    local output=$(tmux capture-pane -t "$target" -p | tail -20)
    if ! echo "$output" | grep -q "opencode"; then
        log_error "Opencode起動失敗: $target"
        return 1
    fi
    
    # プロンプト送信
    send_prompt "$target" "$prompt_file"
    
    # 送信確認
    sleep 2
    output=$(tmux capture-pane -t "$target" -p | tail -10)
    if echo "$output" | grep -q "error\|Error\|ERROR"; then
        log_warn "エラー検出: $target"
    fi
    
    return 0
}
```

### 改善5: エラーハンドリングの改善

```bash
# set -e を削除し、個別にエラー処理
start_agents() {
    local failed_agents=()
    
    for agent in planner comp-A-1 comp-B-1 comp-C-1 qa-gate integrator; do
        if ! start_agent "$SESSION_NAME:$agent" "$ARENA_DIR/prompts/$agent.txt"; then
            failed_agents+=("$agent")
        fi
    done
    
    if [ ${#failed_agents[@]} -gt 0 ]; then
        log_warn "以下のエージェントの起動に失敗しました: ${failed_agents[*]}"
        log_info "手動で再起動してください"
    fi
}
```

### 改善6: プロンプトの簡素化

```bash
# 初期プロンプト（短く）
cat > "$ARENA_DIR/prompts/planner.txt" << 'EOF'
あなたはArena Plannerです。
.arena/requirements.md を読み、タスクを分解してください。
完了したら echo "ready" > .arena/status/planner.status を実行。
EOF

# 詳細指示は別ファイルに
cat > "$ARENA_DIR/instructions/planner-detailed.md" << 'EOF'
# 詳細な指示
...
EOF
```

### 改善7: 自動リカバリー機能

```bash
# 監視スクリプト
monitor_and_recover() {
    while true; do
        for agent in planner comp-A-1 comp-B-1 comp-C-1 qa-gate integrator; do
            local status=$(cat ".arena/status/${agent}.status" 2>/dev/null || echo "unknown")
            local last_update=$(stat -c %Y ".arena/status/${agent}.status" 2>/dev/null || echo "0")
            local now=$(date +%s)
            local age=$((now - last_update))
            
            # 5分以上更新がない場合
            if [ "$age" -gt 300 ] && [ "$status" != "done" ]; then
                log_warn "$agent が応答していません。再起動を試みます..."
                wake_agent "$agent"
            fi
        done
        sleep 60
    done
}
```

---

## 4. 推奨アクション

### 優先度: 高

1. **待機時間の増加** - Opencode起動後5秒、行送信間隔0.1秒
2. **作業ディレクトリの指定** - `-c` フラグを使用
3. **メッセージ送信の分離** - メッセージとEnterを別々に送信

### 優先度: 中

4. **実行結果の検証** - `tmux capture-pane` で確認
5. **エラーハンドリング** - `set -e` を削除し、個別処理
6. **プロンプトの簡素化** - 短い初期プロンプト

### 優先度: 低

7. **自動リカバリー** - 監視スクリプトの追加
8. **専用メッセージスクリプト** - 再利用可能なスクリプト

---

## 5. 参考リンク

- [Tmux-Orchestrator](https://github.com/Jedward23/Tmux-Orchestrator)
- [CLAUDE.md - Critical Lessons Learned](https://github.com/Jedward23/Tmux-Orchestrator/blob/main/CLAUDE.md#critical-lessons-learned)
- [send-claude-message.sh](https://github.com/Jedward23/Tmux-Orchestrator/blob/main/send-claude-message.sh)
