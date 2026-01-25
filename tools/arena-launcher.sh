#!/bin/bash
#
# Arena Launcher v3.0 - 並列LLM競争システム
# Tmux-Orchestrator (https://github.com/Jedward23/Tmux-Orchestrator) を参考に作成
#
# 主な改善点:
# - メッセージ送信の分離（メッセージとEnterを別々に送信）
# - 適切な待機時間（Opencode起動5秒、メッセージ後0.5秒）
# - 作業ディレクトリの明示的指定
# - 実行結果の検証
# - 短いプロンプト（詳細は別ファイル参照）
#

# エラーで即座に終了しない（個別にハンドリング）
set +e

# =============================================================================
# スクリプトディレクトリとユーティリティ読み込み
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ユーティリティが存在すれば読み込む
if [ -f "$SCRIPT_DIR/arena-utils.sh" ]; then
    source "$SCRIPT_DIR/arena-utils.sh"
else
    # 最小限のログ関数を定義
    log_info() { echo "[INFO] $1"; }
    log_ok() { echo "[OK] $1"; }
    log_warn() { echo "[WARN] $1"; }
    log_error() { echo "[ERROR] $1"; }
fi

# =============================================================================
# 設定
# =============================================================================

SESSION_NAME="arena"
ARENA_DIR=".arena"
OPENCODE_CMD="opencode"
WORK_DIR="$(pwd)"

# タイミング設定（Tmux-Orchestratorの推奨値に基づく）
OPENCODE_STARTUP_WAIT=5      # Opencode起動待機時間（秒）
MESSAGE_SEND_DELAY=0.5       # メッセージ送信後の待機時間（秒）
LINE_SEND_DELAY=0.1          # 行送信間の待機時間（秒）

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# =============================================================================
# ヘルパー関数
# =============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}=============================================="
    echo "       Arena Launcher v3.0"
    echo "       Tmux-Orchestrator Pattern"
    echo "==============================================${NC}"
    echo ""
}

usage() {
    echo "Usage: $0 [OPTIONS] <requirements>"
    echo ""
    echo "Options:"
    echo "  -n, --num <N>     チーム数 (default: 1)"
    echo "  -h, --help        このヘルプを表示"
    echo ""
    echo "Examples:"
    echo "  $0 '3Dブロック崩しゲームを作成してください'"
    echo "  $0 -n 2 '3Dブロック崩しゲームを作成してください'"
    exit 1
}

# =============================================================================
# メッセージ送信関数（Tmux-Orchestrator方式）
# =============================================================================

# 重要: メッセージとEnterを分離し、間に待機を入れる
send_to_opencode() {
    local target="$1"
    local message="$2"
    
    # メッセージを送信（-- でオプション終了を明示）
    tmux send-keys -t "$target" -- "$message"
    
    # UIが登録するまで待機（重要！）
    sleep "$MESSAGE_SEND_DELAY"
    
    # Enterを送信
    tmux send-keys -t "$target" Enter
}

# ファイルからプロンプトを送信
send_prompt_file() {
    local target="$1"
    local file="$2"
    
    if [ ! -f "$file" ]; then
        log_error "ファイルが見つかりません: $file"
        return 1
    fi
    
    # ファイルの内容を1行ずつ送信
    while IFS= read -r line || [ -n "$line" ]; do
        tmux send-keys -t "$target" -- "$line"
        sleep "$LINE_SEND_DELAY"
    done < "$file"
    
    # 最後に待機してからEnter
    sleep "$MESSAGE_SEND_DELAY"
    tmux send-keys -t "$target" Enter
}

# ウィンドウの出力をキャプチャ
capture_output() {
    local target="$1"
    local lines="${2:-30}"
    tmux capture-pane -t "$target" -p -S "-$lines" 2>/dev/null | tail -n "$lines"
}

# Opencode起動確認
verify_opencode_started() {
    local target="$1"
    local output=$(capture_output "$target" 30)
    
    if echo "$output" | grep -qi "opencode\|Build\|variants\|agents"; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# 引数解析
# =============================================================================

NUM_TEAMS=1
REQUIREMENTS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -n|--num)
            NUM_TEAMS="$2"
            shift 2
            ;;
        -h|--help)
            usage
            ;;
        *)
            REQUIREMENTS="$1"
            shift
            ;;
    esac
done

if [ -z "$REQUIREMENTS" ]; then
    log_error "要件が指定されていません"
    usage
fi

# =============================================================================
# ディレクトリ初期化
# =============================================================================

init_arena_dir() {
    log_info "Arenaディレクトリを初期化中..."
    
    rm -rf "$ARENA_DIR"
    mkdir -p "$ARENA_DIR"/{status,tasks,submissions,evaluations,final/integrated,prompts,logs}
    
    # 要件を保存
    echo "$REQUIREMENTS" > "$ARENA_DIR/requirements.md"
    
    # ステータスファイルを初期化
    echo "initializing" > "$ARENA_DIR/status/planner.status"
    echo "waiting" > "$ARENA_DIR/status/qa-gate.status"
    echo "waiting" > "$ARENA_DIR/status/integrator.status"
    
    for team in A B C; do
        for i in $(seq 1 $NUM_TEAMS); do
            echo "waiting" > "$ARENA_DIR/status/comp-${team}-${i}.status"
            mkdir -p "$ARENA_DIR/submissions/comp-${team}-${i}"
        done
    done
    
    log_ok "Arenaディレクトリを初期化しました"
}

# =============================================================================
# プロンプト作成（短く、明確に）
# =============================================================================

create_prompts() {
    log_info "プロンプトファイルを作成中..."
    
    local total_teams=$((NUM_TEAMS * 3))
    
    # -----------------------------------------------------------------
    # Planner用プロンプト（短く、最初のアクションを明確に）
    # -----------------------------------------------------------------
    cat > "$ARENA_DIR/prompts/planner.txt" << PLANNER_EOF
あなたはArena Plannerです。要件を読んでタスクを分解してください。

【要件】
$REQUIREMENTS

【今すぐ実行してください】
1. cat .arena/requirements.md で要件を確認
2. 以下の3つのタスクファイルを作成:

cat > .arena/tasks/task-A.md << 'EOF'
# Task-A: コア機能実装
（具体的なタスク内容を記載）
EOF

cat > .arena/tasks/task-B.md << 'EOF'
# Task-B: データ層・インフラ
（具体的なタスク内容を記載）
EOF

cat > .arena/tasks/task-C.md << 'EOF'
# Task-C: API設計・統合
（具体的なタスク内容を記載）
EOF

3. 完了したら: echo "ready" > .arena/status/planner.status

ユーザーに質問せず、自律的に進めてください。
PLANNER_EOF

    # -----------------------------------------------------------------
    # Competitor用プロンプト
    # -----------------------------------------------------------------
    for team in A B C; do
        local role=""
        case $team in
            A) role="コア機能実装" ;;
            B) role="データ層・インフラ" ;;
            C) role="API設計・統合" ;;
        esac
        
        for i in $(seq 1 $NUM_TEAMS); do
            cat > "$ARENA_DIR/prompts/comp-${team}-${i}.txt" << COMP_EOF
あなたは comp-${team}-${i} です。役割: ${role}

【今すぐ実行してください】
1. plannerの準備を確認: cat .arena/status/planner.status
   - "ready"なら次へ進む
   - "initializing"なら10秒後に再確認

2. タスクを読む: cat .arena/tasks/task-${team}.md

3. ステータス更新: echo "working" > .arena/status/comp-${team}-${i}.status

4. 実装を開始（作業ディレクトリ: .arena/submissions/comp-${team}-${i}/）

5. 完了したら: echo "submitted" > .arena/status/comp-${team}-${i}.status

ユーザーに質問せず、自律的に進めてください。
COMP_EOF
        done
    done

    # -----------------------------------------------------------------
    # QA Gate用プロンプト
    # -----------------------------------------------------------------
    cat > "$ARENA_DIR/prompts/qa-gate.txt" << QA_EOF
あなたはQA Gateです。全チームの提出を評価してください。

【今すぐ実行してください】
1. 提出状況を確認: ls .arena/status/comp-*.status | xargs -I {} sh -c 'echo "\$(basename {} .status): \$(cat {})"'
   - 全チーム（${total_teams}チーム）が"submitted"なら次へ
   - まだなら30秒後に再確認

2. ステータス更新: echo "evaluating" > .arena/status/qa-gate.status

3. 各チームの提出物を評価: ls -la .arena/submissions/

4. 評価結果を作成:
cat > .arena/evaluations/evaluation.md << 'EOF'
# 評価結果
## 各チームの評価
（評価内容を記載）
## 推奨チーム: （最優秀チーム名）
EOF

5. 完了したら: echo "done" > .arena/status/qa-gate.status

ユーザーに質問せず、自律的に進めてください。
QA_EOF

    # -----------------------------------------------------------------
    # Integrator用プロンプト
    # -----------------------------------------------------------------
    cat > "$ARENA_DIR/prompts/integrator.txt" << INT_EOF
あなたはIntegratorです。最終成果物を作成してください。

【今すぐ実行してください】
1. QA Gateの完了を確認: cat .arena/status/qa-gate.status
   - "done"なら次へ進む
   - それ以外なら30秒後に再確認

2. 評価結果を読む: cat .arena/evaluations/evaluation.md

3. ステータス更新: echo "integrating" > .arena/status/integrator.status

4. 最終成果物を作成（作業ディレクトリ: .arena/final/integrated/）
   - 評価結果に基づき、最良の実装を選択または統合

5. 完了したら: echo "done" > .arena/status/integrator.status

ユーザーに質問せず、自律的に進めてください。
INT_EOF

    log_ok "プロンプトファイルを作成しました"
}

# =============================================================================
# tmuxセッション作成（作業ディレクトリを明示的に指定）
# =============================================================================

create_tmux_session() {
    log_info "tmuxセッションを作成中..."
    
    # 既存セッションを削除
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    
    # 新しいセッションを作成（作業ディレクトリを指定）
    tmux new-session -d -s "$SESSION_NAME" -n "planner" -c "$WORK_DIR"
    
    # Competitorウィンドウを作成
    if [ "$NUM_TEAMS" -eq 1 ]; then
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}-1" -c "$WORK_DIR"
        done
    else
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}" -c "$WORK_DIR"
            for i in $(seq 2 $NUM_TEAMS); do
                tmux split-window -t "$SESSION_NAME:comp-${team}" -v -c "$WORK_DIR"
            done
            tmux select-layout -t "$SESSION_NAME:comp-${team}" even-vertical
        done
    fi
    
    # QA Gate, Integrator, Monitorウィンドウを作成
    tmux new-window -t "$SESSION_NAME" -n "qa-gate" -c "$WORK_DIR"
    tmux new-window -t "$SESSION_NAME" -n "integrator" -c "$WORK_DIR"
    tmux new-window -t "$SESSION_NAME" -n "monitor" -c "$WORK_DIR"
    
    log_ok "tmuxセッションを作成しました"
}

# =============================================================================
# エージェント起動（Tmux-Orchestrator方式）
# =============================================================================

start_single_agent() {
    local target="$1"
    local prompt_file="$2"
    local agent_name="$3"
    
    log_info "  $agent_name を起動中..."
    
    # Step 1: Opencodeを起動
    tmux send-keys -t "$target" "$OPENCODE_CMD"
    sleep "$MESSAGE_SEND_DELAY"
    tmux send-keys -t "$target" Enter
    
    # Step 2: Opencode起動を待機（重要！）
    log_info "    Opencode起動待機中... (${OPENCODE_STARTUP_WAIT}秒)"
    sleep "$OPENCODE_STARTUP_WAIT"
    
    # Step 3: 起動確認
    if verify_opencode_started "$target"; then
        log_ok "    Opencode起動確認: $agent_name"
    else
        log_warn "    Opencode起動未確認: $agent_name（続行します）"
    fi
    
    # Step 4: プロンプトを送信
    if [ -f "$prompt_file" ]; then
        log_info "    プロンプト送信中..."
        send_prompt_file "$target" "$prompt_file"
        log_ok "    プロンプト送信完了: $agent_name"
    fi
    
    log_ok "  $agent_name を起動しました"
}

start_agents() {
    log_info "エージェントを起動中..."
    
    local failed_agents=()
    
    # Planner起動
    start_single_agent "$SESSION_NAME:planner" "$ARENA_DIR/prompts/planner.txt" "planner"
    
    # Competitor起動
    if [ "$NUM_TEAMS" -eq 1 ]; then
        for team in A B C; do
            start_single_agent "$SESSION_NAME:comp-${team}-1" "$ARENA_DIR/prompts/comp-${team}-1.txt" "comp-${team}-1"
        done
    else
        for team in A B C; do
            for i in $(seq 1 $NUM_TEAMS); do
                local pane_index=$((i - 1))
                local target="$SESSION_NAME:comp-${team}.${pane_index}"
                start_single_agent "$target" "$ARENA_DIR/prompts/comp-${team}-${i}.txt" "comp-${team}-${i}"
            done
        done
    fi
    
    # QA Gate起動
    start_single_agent "$SESSION_NAME:qa-gate" "$ARENA_DIR/prompts/qa-gate.txt" "qa-gate"
    
    # Integrator起動
    start_single_agent "$SESSION_NAME:integrator" "$ARENA_DIR/prompts/integrator.txt" "integrator"
    
    # Monitor起動
    log_info "  Monitor を起動中..."
    local monitor_cmd="watch -n 5 'echo \"=== Arena Status ===\"; echo \"\"; for f in .arena/status/*.status; do printf \"%-20s: %s\\n\" \"\$(basename \$f .status)\" \"\$(cat \$f)\"; done; echo \"\"; echo \"=== Submissions ===\"; ls -la .arena/submissions/ 2>/dev/null || echo \"No submissions yet\"'"
    tmux send-keys -t "$SESSION_NAME:monitor" "$monitor_cmd"
    sleep "$MESSAGE_SEND_DELAY"
    tmux send-keys -t "$SESSION_NAME:monitor" Enter
    log_ok "  Monitor を起動しました"
    
    log_ok "全エージェントを起動しました"
}

# =============================================================================
# 完了メッセージ
# =============================================================================

print_completion() {
    echo ""
    echo -e "${GREEN}=============================================="
    echo "       Arenaセッションが起動しました！"
    echo "==============================================${NC}"
    echo ""
    echo -e "${CYAN}構成:${NC}"
    echo "  N = $NUM_TEAMS"
    echo "  チーム数 = $((NUM_TEAMS * 3))"
    echo "  作業ディレクトリ = $WORK_DIR"
    echo ""
    echo -e "${CYAN}確認方法:${NC}"
    echo "  tmux attach -t $SESSION_NAME"
    echo ""
    echo -e "${CYAN}ウィンドウ一覧:${NC}"
    tmux list-windows -t "$SESSION_NAME" 2>/dev/null | while read line; do
        echo "  $line"
    done
    echo ""
    echo -e "${CYAN}ウィンドウ切り替え:${NC}"
    echo "  Ctrl+b, n     次のウィンドウ"
    echo "  Ctrl+b, p     前のウィンドウ"
    echo "  Ctrl+b, 0-9   番号でウィンドウ選択"
    echo ""
    if [ "$NUM_TEAMS" -ge 2 ]; then
        echo -e "${CYAN}ペイン切り替え (N>=2の場合):${NC}"
        echo "  Ctrl+b, ↑↓    ペイン間移動"
        echo "  Ctrl+b, o     次のペインへ"
        echo ""
    fi
    echo -e "${CYAN}エージェントにメッセージを送信:${NC}"
    echo "  $SCRIPT_DIR/send-opencode-message.sh arena:planner \"メッセージ\""
    echo ""
    echo -e "${YELLOW}【トラブルシューティング】${NC}"
    echo "  エージェントが動かない場合:"
    echo "    1. 該当ウィンドウに移動 (Ctrl+b, 番号)"
    echo "    2. 出力を確認"
    echo "    3. 手動でコマンドを入力"
    echo "    4. または: send-opencode-message.sh arena:エージェント名 \"続行してください\""
    echo ""
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    print_header
    
    log_info "N = $NUM_TEAMS (チーム数: $((NUM_TEAMS * 3)))"
    log_info "要件: $REQUIREMENTS"
    log_info "作業ディレクトリ: $WORK_DIR"
    echo ""
    
    init_arena_dir
    create_prompts
    create_tmux_session
    start_agents
    print_completion
    
    # TTYの場合は自動アタッチ
    if [ -t 0 ]; then
        tmux attach -t "$SESSION_NAME"
    else
        log_warn "自動アタッチは非TTYのため失敗しました。"
        log_info "手動で tmux attach -t $SESSION_NAME を実行してください。"
    fi
}

main
