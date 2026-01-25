#!/bin/bash
#
# arena-utils.sh - Arena Competition System 共通ユーティリティ
# Tmux-Orchestrator の tmux_utils.py を参考に作成
#

# =============================================================================
# 設定
# =============================================================================

ARENA_SESSION="${ARENA_SESSION:-arena}"
ARENA_DIR="${ARENA_DIR:-.arena}"
OPENCODE_CMD="${OPENCODE_CMD:-opencode}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# タイミング設定（Tmux-Orchestratorの推奨値）
OPENCODE_STARTUP_WAIT=5      # Opencode起動待機時間
MESSAGE_SEND_DELAY=0.5       # メッセージ送信後の待機時間
LINE_SEND_DELAY=0.1          # 行送信間の待機時間
COMMAND_EXEC_WAIT=2          # コマンド実行後の待機時間

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# ログ関数
# =============================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# =============================================================================
# tmux ユーティリティ関数
# =============================================================================

# ウィンドウの内容をキャプチャ
capture_window() {
    local target="$1"
    local lines="${2:-50}"
    tmux capture-pane -t "$target" -p -S "-$lines" 2>/dev/null
}

# ウィンドウの最後のN行を取得
get_last_lines() {
    local target="$1"
    local lines="${2:-20}"
    capture_window "$target" "$lines" | tail -n "$lines"
}

# ウィンドウにコマンドを送信（結果を待たない）
send_keys() {
    local target="$1"
    local keys="$2"
    tmux send-keys -t "$target" -- "$keys"
}

# ウィンドウにコマンドを送信してEnter
send_command() {
    local target="$1"
    local command="$2"
    
    send_keys "$target" "$command"
    sleep "$MESSAGE_SEND_DELAY"
    tmux send-keys -t "$target" Enter
}

# Opencodeエージェントにメッセージを送信
send_message() {
    local target="$1"
    local message="$2"
    
    # メッセージを送信
    send_keys "$target" "$message"
    
    # UIが登録するまで待機
    sleep "$MESSAGE_SEND_DELAY"
    
    # Enterを送信
    tmux send-keys -t "$target" Enter
    
    log_ok "メッセージ送信: $target"
}

# ファイルからプロンプトを送信
send_prompt_from_file() {
    local target="$1"
    local file="$2"
    
    if [ ! -f "$file" ]; then
        log_error "プロンプトファイルが見つかりません: $file"
        return 1
    fi
    
    # ファイルの内容を1行ずつ送信
    while IFS= read -r line || [ -n "$line" ]; do
        send_keys "$target" "$line"
        sleep "$LINE_SEND_DELAY"
    done < "$file"
    
    # 最後にEnterを送信
    sleep "$MESSAGE_SEND_DELAY"
    tmux send-keys -t "$target" Enter
    
    log_ok "プロンプト送信完了: $target"
}

# =============================================================================
# Opencode エージェント管理
# =============================================================================

# Opencodeを起動
start_opencode() {
    local target="$1"
    
    log_info "Opencode起動中: $target"
    
    # Opencodeコマンドを送信
    send_command "$target" "$OPENCODE_CMD"
    
    # 起動を待機
    sleep "$OPENCODE_STARTUP_WAIT"
    
    # 起動確認
    local output=$(get_last_lines "$target" 30)
    if echo "$output" | grep -qi "opencode\|Build\|variants"; then
        log_ok "Opencode起動成功: $target"
        return 0
    else
        log_warn "Opencode起動未確認: $target（続行します）"
        return 0
    fi
}

# エージェントを起動してプロンプトを送信
start_agent() {
    local target="$1"
    local prompt_file="$2"
    local agent_name="$3"
    
    log_info "エージェント起動中: $agent_name ($target)"
    
    # Opencode起動
    if ! start_opencode "$target"; then
        log_error "Opencode起動失敗: $target"
        return 1
    fi
    
    # プロンプト送信
    if [ -n "$prompt_file" ] && [ -f "$prompt_file" ]; then
        send_prompt_from_file "$target" "$prompt_file"
    fi
    
    log_ok "エージェント起動完了: $agent_name"
    return 0
}

# エージェントを起こす（再度プロンプトを送信）
wake_agent() {
    local target="$1"
    local message="${2:-続行してください}"
    
    log_info "エージェントを起こしています: $target"
    send_message "$target" "$message"
}

# =============================================================================
# ステータス管理
# =============================================================================

# ステータスを取得
get_status() {
    local agent="$1"
    local status_file="$ARENA_DIR/status/${agent}.status"
    
    if [ -f "$status_file" ]; then
        cat "$status_file"
    else
        echo "unknown"
    fi
}

# ステータスを設定
set_status() {
    local agent="$1"
    local status="$2"
    
    echo "$status" > "$ARENA_DIR/status/${agent}.status"
}

# 全エージェントのステータスを表示
show_all_status() {
    echo "=== Arena Status ==="
    echo ""
    for f in "$ARENA_DIR/status/"*.status; do
        if [ -f "$f" ]; then
            local agent=$(basename "$f" .status)
            local status=$(cat "$f")
            printf "%-20s: %s\n" "$agent" "$status"
        fi
    done
}

# 特定のステータスを持つエージェント数をカウント
count_status() {
    local status="$1"
    grep -l "^${status}$" "$ARENA_DIR/status/"*.status 2>/dev/null | wc -l
}

# =============================================================================
# セッション管理
# =============================================================================

# セッションが存在するか確認
session_exists() {
    tmux has-session -t "$ARENA_SESSION" 2>/dev/null
}

# ウィンドウ一覧を取得
list_windows() {
    tmux list-windows -t "$ARENA_SESSION" -F "#{window_index}: #{window_name}" 2>/dev/null
}

# ペイン一覧を取得
list_panes() {
    local window="$1"
    tmux list-panes -t "$ARENA_SESSION:$window" -F "#{pane_index}: #{pane_current_command}" 2>/dev/null
}

# =============================================================================
# 監視機能
# =============================================================================

# エージェントの出力をモニタリング
monitor_agent() {
    local target="$1"
    local lines="${2:-30}"
    
    echo "=== $target の出力 ==="
    get_last_lines "$target" "$lines"
    echo ""
}

# 全エージェントの概要を表示
monitor_all() {
    local agents=("planner" "comp-A-1" "comp-B-1" "comp-C-1" "qa-gate" "integrator")
    
    for agent in "${agents[@]}"; do
        local target="$ARENA_SESSION:$agent"
        if tmux has-session -t "$target" 2>/dev/null; then
            echo "=== $agent ==="
            get_last_lines "$target" 10
            echo ""
        fi
    done
}

# エクスポート
export -f log_info log_ok log_warn log_error
export -f capture_window get_last_lines send_keys send_command send_message
export -f send_prompt_from_file start_opencode start_agent wake_agent
export -f get_status set_status show_all_status count_status
export -f session_exists list_windows list_panes
export -f monitor_agent monitor_all
