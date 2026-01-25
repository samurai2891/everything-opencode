#!/bin/bash
#
# send-opencode-message.sh - Opencode エージェントへのメッセージ送信
# Tmux-Orchestrator の send-claude-message.sh を参考に作成
#
# Usage: send-opencode-message.sh <session:window> <message>
# Example: send-opencode-message.sh arena:planner "タスクを分解してください"
#

if [ $# -lt 2 ]; then
    echo "Usage: $0 <session:window> <message>"
    echo "Example: $0 arena:planner 'Hello Opencode!'"
    exit 1
fi

TARGET="$1"
shift  # 最初の引数を削除、残りがメッセージ
MESSAGE="$*"

# メッセージを送信（-- でオプション終了を明示）
tmux send-keys -t "$TARGET" -- "$MESSAGE"

# UIが登録するまで待機（重要！）
sleep 0.5

# Enterを送信して実行
tmux send-keys -t "$TARGET" Enter

echo "[OK] Message sent to $TARGET"
