#!/bin/bash
#
# Arena Launcher v2.1 - 並列LLM競争システム
# N数管理・ペイン分割・同期機能対応
# 修正: プロンプトをシンプルに、最初のアクションを明確に
#

set -e

# =============================================================================
# 設定
# =============================================================================

SESSION_NAME="arena"
ARENA_DIR=".arena"
OPENCODE_CMD="opencode"

# カラー定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# =============================================================================
# ヘルパー関数
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

print_header() {
    echo ""
    echo -e "${CYAN}=============================================="
    echo "       Arena Launcher v2.1 - 並列LLM競争システム"
    echo "==============================================${NC}"
    echo ""
}

# =============================================================================
# 使用方法
# =============================================================================

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
    mkdir -p "$ARENA_DIR"/{status,tasks,submissions,evaluations,final/integrated,prompts}
    
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
# プロンプトファイル作成（シンプル版）
# =============================================================================

create_prompts() {
    log_info "プロンプトファイルを作成中..."
    
    local total_teams=$((NUM_TEAMS * 3))
    
    # Planner用プロンプト（シンプル版）
    cat > "$ARENA_DIR/prompts/planner.txt" << 'PLANNER_EOF'
あなたはArena Competition Systemの中央プランナーです。

【要件】
PLANNER_EOF
    echo "$REQUIREMENTS" >> "$ARENA_DIR/prompts/planner.txt"
    cat >> "$ARENA_DIR/prompts/planner.txt" << PLANNER_EOF2

【あなたのタスク】
1. 上記の要件を3つのタスクに分解してください：
   - Task-A: コア機能実装
   - Task-B: データ層・インフラ
   - Task-C: API設計・統合

2. 以下のコマンドを実行してタスクファイルを作成してください：

cat > .arena/tasks/task-A.md << 'EOF'
# Task-A: コア機能実装
[ここにTask-Aの詳細を記載]
EOF

cat > .arena/tasks/task-B.md << 'EOF'
# Task-B: データ層・インフラ
[ここにTask-Bの詳細を記載]
EOF

cat > .arena/tasks/task-C.md << 'EOF'
# Task-C: API設計・統合
[ここにTask-Cの詳細を記載]
EOF

3. タスクファイル作成後、必ず以下を実行してください：
echo "ready" > .arena/status/planner.status

【重要】
- ユーザーに質問せず、自律的に進めてください
- 今すぐ上記のコマンドを実行してください
PLANNER_EOF2

    # Competitor用プロンプト（シンプル版）
    for team in A B C; do
        local role=""
        case $team in
            A) role="コア機能実装" ;;
            B) role="データ層・インフラ" ;;
            C) role="API設計・統合" ;;
        esac
        
        for i in $(seq 1 $NUM_TEAMS); do
            cat > "$ARENA_DIR/prompts/comp-${team}-${i}.txt" << COMP_EOF
あなたはArena Competition Systemの競争チーム comp-${team}-${i} です。
役割: ${role}

【要件】
$REQUIREMENTS

【あなたのタスク】

Step 1: まず以下を実行してplannerの準備完了を確認：
cat .arena/status/planner.status

"ready"と表示されたらStep 2へ。
"initializing"の場合は10秒後に再度確認してください。

Step 2: タスクを読み込む：
cat .arena/tasks/task-${team}.md

Step 3: 実装を開始（ステータス更新）：
echo "working" > .arena/status/comp-${team}-${i}.status

Step 4: 実装を行う：
- 作業ディレクトリ: .arena/submissions/comp-${team}-${i}/
- 必要なファイルをすべてこのディレクトリに作成

Step 5: 完了したらステータスを更新：
echo "submitted" > .arena/status/comp-${team}-${i}.status

【重要】
- ユーザーに質問せず、自律的に進めてください
- 今すぐStep 1から開始してください
COMP_EOF
        done
    done

    # QA Gate用プロンプト（シンプル版）
    cat > "$ARENA_DIR/prompts/qa-gate.txt" << QA_EOF
あなたはArena Competition SystemのQA Gateです。

【あなたのタスク】

Step 1: 全チームの提出状況を確認：
grep -c "submitted" .arena/status/comp-*.status 2>/dev/null || echo "0"

$total_teams と表示されたらStep 2へ。
それ以外の場合は30秒後に再度確認してください。

Step 2: 評価を開始（ステータス更新）：
echo "evaluating" > .arena/status/qa-gate.status

Step 3: 各チームの提出物を評価：
ls -la .arena/submissions/

各チームのコードを確認し、品質を評価してください。

Step 4: 評価結果を作成：
cat > .arena/evaluations/evaluation.md << 'EOF'
# 評価結果
[各チームの評価をここに記載]
## 推奨チーム: [最優秀チーム名]
EOF

Step 5: 完了したらステータスを更新：
echo "done" > .arena/status/qa-gate.status

【重要】
- ユーザーに質問せず、自律的に進めてください
- 今すぐStep 1から開始してください
QA_EOF

    # Integrator用プロンプト（シンプル版）
    cat > "$ARENA_DIR/prompts/integrator.txt" << INT_EOF
あなたはArena Competition Systemの統合担当です。

【あなたのタスク】

Step 1: QA Gateの評価完了を確認：
cat .arena/status/qa-gate.status

"done"と表示されたらStep 2へ。
それ以外の場合は30秒後に再度確認してください。

Step 2: 評価結果を確認：
cat .arena/evaluations/evaluation.md

Step 3: 統合を開始（ステータス更新）：
echo "integrating" > .arena/status/integrator.status

Step 4: 最終成果物を作成：
- 作業ディレクトリ: .arena/final/integrated/
- 評価結果に基づき、最良の実装を選択または統合

Step 5: 完了したらステータスを更新：
echo "done" > .arena/status/integrator.status

【重要】
- ユーザーに質問せず、自律的に進めてください
- 今すぐStep 1から開始してください
INT_EOF

    log_ok "プロンプトファイルを作成しました"
}

# =============================================================================
# tmuxセッション作成
# =============================================================================

create_tmux_session() {
    log_info "tmuxセッションを作成中..."
    
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    tmux new-session -d -s "$SESSION_NAME" -n "planner"
    
    if [ "$NUM_TEAMS" -eq 1 ]; then
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}-1"
        done
    else
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}"
            for i in $(seq 2 $NUM_TEAMS); do
                tmux split-window -t "$SESSION_NAME:comp-${team}" -v
            done
            tmux select-layout -t "$SESSION_NAME:comp-${team}" even-vertical
        done
    fi
    
    tmux new-window -t "$SESSION_NAME" -n "qa-gate"
    tmux new-window -t "$SESSION_NAME" -n "integrator"
    tmux new-window -t "$SESSION_NAME" -n "monitor"
    
    log_ok "tmuxセッションを作成しました"
}

# =============================================================================
# エージェント起動
# =============================================================================

start_agents() {
    log_info "エージェントを起動中..."
    
    local prompt_file
    local target
    
    # Planner起動
    log_info "  Plannerを起動中..."
    tmux send-keys -t "$SESSION_NAME:planner" "$OPENCODE_CMD" Enter
    sleep 3
    prompt_file="$ARENA_DIR/prompts/planner.txt"
    while IFS= read -r line || [ -n "$line" ]; do
        tmux send-keys -t "$SESSION_NAME:planner" -- "$line"
        sleep 0.05
    done < "$prompt_file"
    tmux send-keys -t "$SESSION_NAME:planner" Enter
    log_ok "  Plannerを起動しました"
    
    # Competitor起動
    if [ "$NUM_TEAMS" -eq 1 ]; then
        for team in A B C; do
            log_info "  comp-${team}-1を起動中..."
            tmux send-keys -t "$SESSION_NAME:comp-${team}-1" "$OPENCODE_CMD" Enter
            sleep 3
            prompt_file="$ARENA_DIR/prompts/comp-${team}-1.txt"
            while IFS= read -r line || [ -n "$line" ]; do
                tmux send-keys -t "$SESSION_NAME:comp-${team}-1" -- "$line"
                sleep 0.05
            done < "$prompt_file"
            tmux send-keys -t "$SESSION_NAME:comp-${team}-1" Enter
            log_ok "  comp-${team}-1を起動しました"
        done
    else
        for team in A B C; do
            for i in $(seq 1 $NUM_TEAMS); do
                pane_index=$((i - 1))
                target="$SESSION_NAME:comp-${team}.${pane_index}"
                log_info "  comp-${team}-${i}を起動中..."
                tmux send-keys -t "$target" "$OPENCODE_CMD" Enter
                sleep 3
                prompt_file="$ARENA_DIR/prompts/comp-${team}-${i}.txt"
                while IFS= read -r line || [ -n "$line" ]; do
                    tmux send-keys -t "$target" -- "$line"
                    sleep 0.05
                done < "$prompt_file"
                tmux send-keys -t "$target" Enter
                log_ok "  comp-${team}-${i}を起動しました"
            done
        done
    fi
    
    # QA Gate起動
    log_info "  QA Gateを起動中..."
    tmux send-keys -t "$SESSION_NAME:qa-gate" "$OPENCODE_CMD" Enter
    sleep 3
    prompt_file="$ARENA_DIR/prompts/qa-gate.txt"
    while IFS= read -r line || [ -n "$line" ]; do
        tmux send-keys -t "$SESSION_NAME:qa-gate" -- "$line"
        sleep 0.05
    done < "$prompt_file"
    tmux send-keys -t "$SESSION_NAME:qa-gate" Enter
    log_ok "  QA Gateを起動しました"
    
    # Integrator起動
    log_info "  Integratorを起動中..."
    tmux send-keys -t "$SESSION_NAME:integrator" "$OPENCODE_CMD" Enter
    sleep 3
    prompt_file="$ARENA_DIR/prompts/integrator.txt"
    while IFS= read -r line || [ -n "$line" ]; do
        tmux send-keys -t "$SESSION_NAME:integrator" -- "$line"
        sleep 0.05
    done < "$prompt_file"
    tmux send-keys -t "$SESSION_NAME:integrator" Enter
    log_ok "  Integratorを起動しました"
    
    # Monitor起動
    log_info "  Monitorを起動中..."
    local monitor_cmd="watch -n 5 'echo \"=== Arena Status ===\"; echo \"\"; for f in .arena/status/*.status; do printf \"%-20s: %s\\n\" \"\$(basename \$f .status)\" \"\$(cat \$f)\"; done; echo \"\"; echo \"=== Submissions ===\"; ls -la .arena/submissions/ 2>/dev/null || echo \"No submissions yet\"'"
    tmux send-keys -t "$SESSION_NAME:monitor" "$monitor_cmd" Enter
    log_ok "  Monitorを起動しました"
    
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
    echo -e "${CYAN}ステータス確認:${NC}"
    echo "  monitorウィンドウで自動更新されます"
    echo ""
    echo -e "${YELLOW}【トラブルシューティング】${NC}"
    echo "  エージェントが動かない場合:"
    echo "    1. 該当ウィンドウに移動"
    echo "    2. Enterキーを押す（プロンプト再送信）"
    echo "    3. または手動でコマンドを入力"
    echo ""
}

# =============================================================================
# メイン処理
# =============================================================================

main() {
    print_header
    
    log_info "N = $NUM_TEAMS (チーム数: $((NUM_TEAMS * 3)))"
    log_info "要件: $REQUIREMENTS"
    echo ""
    
    init_arena_dir
    create_prompts
    create_tmux_session
    start_agents
    print_completion
    
    if [ -t 0 ]; then
        tmux attach -t "$SESSION_NAME"
    else
        log_warn "自動アタッチは非TTYのため失敗しました。"
        log_info "手動で tmux attach -t $SESSION_NAME を実行してください。"
    fi
}

main
