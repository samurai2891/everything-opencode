#!/bin/bash
#
# Arena Recover - エージェント復旧・監視ツール
#

set -e

SESSION_NAME="arena"
ARENA_DIR=".arena"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# 使用方法
# =============================================================================

usage() {
    echo "Arena Recover - エージェント復旧・監視ツール"
    echo ""
    echo "Usage: $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status              全エージェントのステータスを表示"
    echo "  wake <agent>        待機中のエージェントを起こす"
    echo "  restart <agent>     エラー状態のエージェントを再起動"
    echo "  reset <agent>       エージェントのステータスをリセット"
    echo "  kick <agent>        エージェントにキックメッセージを送信"
    echo "  list                全エージェント一覧を表示"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 wake comp-A-1"
    echo "  $0 restart comp-B-2"
    echo "  $0 kick qa-gate"
    exit 1
}

# =============================================================================
# ステータス表示
# =============================================================================

show_status() {
    echo -e "${CYAN}=== Arena Status ===${NC}"
    echo ""
    
    if [ ! -d "$ARENA_DIR/status" ]; then
        echo -e "${RED}Arenaが初期化されていません${NC}"
        exit 1
    fi
    
    # ステータスアイコンの定義
    get_icon() {
        case $1 in
            "ready"|"done"|"submitted") echo -e "${GREEN}✅${NC}" ;;
            "working"|"evaluating"|"integrating") echo -e "${BLUE}🔄${NC}" ;;
            "waiting"|"initializing") echo -e "${YELLOW}⏸️${NC}" ;;
            "error") echo -e "${RED}❌${NC}" ;;
            *) echo -e "${YELLOW}❓${NC}" ;;
        esac
    }
    
    # 各エージェントのステータスを表示
    for f in "$ARENA_DIR/status"/*.status; do
        if [ -f "$f" ]; then
            agent=$(basename "$f" .status)
            status=$(cat "$f")
            icon=$(get_icon "$status")
            printf "  %-20s %s %s\n" "$agent:" "$icon" "$status"
        fi
    done
    
    echo ""
    
    # 提出状況
    echo -e "${CYAN}=== Submissions ===${NC}"
    if [ -d "$ARENA_DIR/submissions" ]; then
        for d in "$ARENA_DIR/submissions"/*/; do
            if [ -d "$d" ]; then
                team=$(basename "$d")
                files=$(ls -1 "$d" 2>/dev/null | wc -l)
                if [ "$files" -gt 0 ]; then
                    echo -e "  ${GREEN}$team: $files files${NC}"
                else
                    echo -e "  ${YELLOW}$team: empty${NC}"
                fi
            fi
        done
    else
        echo "  No submissions directory"
    fi
    
    echo ""
    
    # 評価状況
    echo -e "${CYAN}=== Evaluation ===${NC}"
    if [ -f "$ARENA_DIR/evaluations/evaluation.md" ]; then
        echo -e "  ${GREEN}Evaluation file exists${NC}"
    else
        echo -e "  ${YELLOW}No evaluation yet${NC}"
    fi
    
    echo ""
    
    # 最終成果物
    echo -e "${CYAN}=== Final Output ===${NC}"
    if [ -d "$ARENA_DIR/final/integrated" ]; then
        files=$(ls -1 "$ARENA_DIR/final/integrated" 2>/dev/null | wc -l)
        if [ "$files" -gt 0 ]; then
            echo -e "  ${GREEN}$files files in final/integrated/${NC}"
        else
            echo -e "  ${YELLOW}No final output yet${NC}"
        fi
    else
        echo -e "  ${YELLOW}No final directory${NC}"
    fi
}

# =============================================================================
# エージェントを起こす
# =============================================================================

wake_agent() {
    local agent="$1"
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エージェント名を指定してください${NC}"
        exit 1
    fi
    
    # ステータスファイルの確認
    local status_file="$ARENA_DIR/status/${agent}.status"
    if [ ! -f "$status_file" ]; then
        echo -e "${RED}エージェント '$agent' が見つかりません${NC}"
        exit 1
    fi
    
    local current_status=$(cat "$status_file")
    if [ "$current_status" != "waiting" ]; then
        echo -e "${YELLOW}エージェント '$agent' は待機中ではありません (現在: $current_status)${NC}"
    fi
    
    # tmuxターゲットを特定
    local target=""
    if [[ "$agent" == "planner" || "$agent" == "qa-gate" || "$agent" == "integrator" ]]; then
        target="$SESSION_NAME:$agent"
    elif [[ "$agent" =~ ^comp-[ABC]-[0-9]+$ ]]; then
        # comp-A-1 などの形式
        local team=$(echo "$agent" | sed 's/comp-\([ABC]\)-.*/\1/')
        local num=$(echo "$agent" | sed 's/comp-[ABC]-//')
        
        # N=1の場合はウィンドウ名がcomp-A-1
        # N>=2の場合はウィンドウ名がcomp-Aでペイン番号がnum-1
        if tmux list-windows -t "$SESSION_NAME" | grep -q "comp-${team}-1"; then
            target="$SESSION_NAME:comp-${team}-1"
        else
            local pane_index=$((num - 1))
            target="$SESSION_NAME:comp-${team}.${pane_index}"
        fi
    else
        echo -e "${RED}不明なエージェント形式: $agent${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}エージェント '$agent' を起こしています...${NC}"
    
    # キックメッセージを送信
    local wake_message="タスクを確認して、作業を続行してください。ステータスファイルを確認し、必要なアクションを実行してください。"
    tmux send-keys -t "$target" -- "$wake_message" Enter
    
    echo -e "${GREEN}キックメッセージを送信しました${NC}"
}

# =============================================================================
# エージェントを再起動
# =============================================================================

restart_agent() {
    local agent="$1"
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エージェント名を指定してください${NC}"
        exit 1
    fi
    
    # ステータスをリセット
    local status_file="$ARENA_DIR/status/${agent}.status"
    if [ -f "$status_file" ]; then
        echo "waiting" > "$status_file"
        echo -e "${GREEN}ステータスを 'waiting' にリセットしました${NC}"
    fi
    
    # エージェントを起こす
    wake_agent "$agent"
}

# =============================================================================
# ステータスをリセット
# =============================================================================

reset_agent() {
    local agent="$1"
    local new_status="${2:-waiting}"
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エージェント名を指定してください${NC}"
        exit 1
    fi
    
    local status_file="$ARENA_DIR/status/${agent}.status"
    if [ ! -f "$status_file" ]; then
        echo -e "${RED}エージェント '$agent' が見つかりません${NC}"
        exit 1
    fi
    
    echo "$new_status" > "$status_file"
    echo -e "${GREEN}エージェント '$agent' のステータスを '$new_status' に設定しました${NC}"
}

# =============================================================================
# キックメッセージを送信
# =============================================================================

kick_agent() {
    local agent="$1"
    local message="${2:-進捗を確認してください。タスクを続行してください。}"
    
    if [ -z "$agent" ]; then
        echo -e "${RED}エージェント名を指定してください${NC}"
        exit 1
    fi
    
    # tmuxターゲットを特定
    local target=""
    if [[ "$agent" == "planner" || "$agent" == "qa-gate" || "$agent" == "integrator" ]]; then
        target="$SESSION_NAME:$agent"
    elif [[ "$agent" =~ ^comp-[ABC]-[0-9]+$ ]]; then
        local team=$(echo "$agent" | sed 's/comp-\([ABC]\)-.*/\1/')
        local num=$(echo "$agent" | sed 's/comp-[ABC]-//')
        
        if tmux list-windows -t "$SESSION_NAME" | grep -q "comp-${team}-1"; then
            target="$SESSION_NAME:comp-${team}-1"
        else
            local pane_index=$((num - 1))
            target="$SESSION_NAME:comp-${team}.${pane_index}"
        fi
    else
        echo -e "${RED}不明なエージェント形式: $agent${NC}"
        exit 1
    fi
    
    echo -e "${BLUE}エージェント '$agent' にメッセージを送信しています...${NC}"
    tmux send-keys -t "$target" -- "$message" Enter
    echo -e "${GREEN}メッセージを送信しました${NC}"
}

# =============================================================================
# エージェント一覧
# =============================================================================

list_agents() {
    echo -e "${CYAN}=== Arena Agents ===${NC}"
    echo ""
    
    if [ ! -d "$ARENA_DIR/status" ]; then
        echo -e "${RED}Arenaが初期化されていません${NC}"
        exit 1
    fi
    
    for f in "$ARENA_DIR/status"/*.status; do
        if [ -f "$f" ]; then
            agent=$(basename "$f" .status)
            echo "  $agent"
        fi
    done
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    local command="$1"
    shift || true
    
    case "$command" in
        status)
            show_status
            ;;
        wake)
            wake_agent "$@"
            ;;
        restart)
            restart_agent "$@"
            ;;
        reset)
            reset_agent "$@"
            ;;
        kick)
            kick_agent "$@"
            ;;
        list)
            list_agents
            ;;
        *)
            usage
            ;;
    esac
}

main "$@"
