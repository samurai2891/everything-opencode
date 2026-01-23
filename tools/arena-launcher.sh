#!/bin/bash
#
# Arena Launcher v2 - 並列LLM競争システム
# N数管理・ペイン分割・同期機能対応
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
    echo "       Arena Launcher v2 - 並列LLM競争システム"
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
    echo "  $0 --num 3 '3Dブロック崩しゲームを作成してください'"
    echo ""
    echo "N数による構成:"
    echo "  N=1: comp-A-1, comp-B-1, comp-C-1 (3チーム)"
    echo "  N=2: comp-A-1〜2, comp-B-1〜2, comp-C-1〜2 (6チーム)"
    echo "  N=3: comp-A-1〜3, comp-B-1〜3, comp-C-1〜3 (9チーム)"
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
    
    # 既存のディレクトリを削除
    rm -rf "$ARENA_DIR"
    
    # ディレクトリ構造を作成
    mkdir -p "$ARENA_DIR"/{status,tasks,submissions,evaluations,final/integrated,prompts}
    
    # 要件ファイルを作成
    echo "$REQUIREMENTS" > "$ARENA_DIR/requirements.md"
    
    # ステータスファイルを初期化
    echo "initializing" > "$ARENA_DIR/status/planner.status"
    echo "waiting" > "$ARENA_DIR/status/qa-gate.status"
    echo "waiting" > "$ARENA_DIR/status/integrator.status"
    
    # 各チームのステータスファイルを作成
    for team in A B C; do
        for i in $(seq 1 $NUM_TEAMS); do
            echo "waiting" > "$ARENA_DIR/status/comp-${team}-${i}.status"
            mkdir -p "$ARENA_DIR/submissions/comp-${team}-${i}"
        done
    done
    
    log_ok "Arenaディレクトリを初期化しました"
}

# =============================================================================
# プロンプトファイル作成
# =============================================================================

create_prompts() {
    log_info "プロンプトファイルを作成中..."
    
    local total_teams=$((NUM_TEAMS * 3))
    
    # Planner用プロンプト
    cat > "$ARENA_DIR/prompts/planner.txt" << PLANNER_EOF
あなたはArena Competition Systemの中央プランナーです。

## 役割
1. 要件を分析し、タスクを分解する
2. 各チーム（comp-A, comp-B, comp-C）に適切なタスクを割り当てる
3. 全体の進捗を監視する

## 要件
$REQUIREMENTS

## 現在の構成
- N = $NUM_TEAMS
- 総チーム数 = $total_teams
- comp-A: $NUM_TEAMS チーム (コア機能実装)
- comp-B: $NUM_TEAMS チーム (データ層・インフラ)
- comp-C: $NUM_TEAMS チーム (API設計・統合)

## 手順

### Step 1: タスク分解
要件を以下の3つの領域に分解してください：
- Task-A (コア機能): メイン機能の実装
- Task-B (データ層・インフラ): データ管理、設定、基盤
- Task-C (API設計・統合): インターフェース、統合

### Step 2: タスクファイル作成
以下のファイルを作成してください：
\`\`\`bash
cat > .arena/tasks/task-A.md << 'EOF'
# Task-A: コア機能実装
[タスク詳細をここに記載]
EOF

cat > .arena/tasks/task-B.md << 'EOF'
# Task-B: データ層・インフラ
[タスク詳細をここに記載]
EOF

cat > .arena/tasks/task-C.md << 'EOF'
# Task-C: API設計・統合
[タスク詳細をここに記載]
EOF
\`\`\`

### Step 3: ステータス更新
タスク分解が完了したら、以下を実行：
\`\`\`bash
echo "ready" > .arena/status/planner.status
\`\`\`

### Step 4: 監視
定期的に以下のコマンドでステータスを確認：
\`\`\`bash
for f in .arena/status/*.status; do echo "\$(basename \$f .status): \$(cat \$f)"; done
\`\`\`

全チームが "submitted" になったら、qa-gateの評価を待ちます。

## 重要
- ユーザーへの質問は行わず、自律的に進めてください
- 不明点は合理的に推測して進めてください
- 今すぐタスク分解を開始してください
PLANNER_EOF

    # Competitor用プロンプト（テンプレート）
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

## 役割
チーム${team}（${role}担当）として、割り当てられたタスクを実装します。
同じチーム${team}には $NUM_TEAMS 人のメンバーがいます。あなたは ${i} 番目です。

## 手順

### Step 1: タスク待機
まず、plannerがタスクを準備するまで待機します。
以下のコマンドでステータスを確認：
\`\`\`bash
cat .arena/status/planner.status
\`\`\`
"ready" になるまで5秒ごとに確認してください。

待機中のループ例：
\`\`\`bash
while [ "\$(cat .arena/status/planner.status)" != "ready" ]; do
    echo "Waiting for planner..."
    sleep 5
done
echo "Planner is ready!"
\`\`\`

### Step 2: タスク読み込み
plannerが準備完了したら、タスクを読み込みます：
\`\`\`bash
cat .arena/tasks/task-${team}.md
\`\`\`

### Step 3: 実装開始
タスクに従って実装を行います。
- 作業ディレクトリ: .arena/submissions/comp-${team}-${i}/
- 実装中はステータスを更新：
\`\`\`bash
echo "working" > .arena/status/comp-${team}-${i}.status
\`\`\`

### Step 4: 提出
実装が完了したら：
1. 成果物を .arena/submissions/comp-${team}-${i}/ に配置
2. README.mdを作成（実装内容の説明）
3. ステータスを更新：
\`\`\`bash
echo "submitted" > .arena/status/comp-${team}-${i}.status
\`\`\`

## 要件（参考）
$REQUIREMENTS

## 重要
- ユーザーへの質問は行わず、自律的に進めてください
- 他のチームと競争しています。品質と速度の両方を意識してください
- エラーが発生した場合は、ステータスを "error" に更新してください
- まず Step 1 のタスク待機から開始してください
COMP_EOF
        done
    done

    # QA Gate用プロンプト
    cat > "$ARENA_DIR/prompts/qa-gate.txt" << QA_EOF
あなたはArena Competition SystemのQA Gateです。

## 役割
全チームの提出物を評価し、品質を判定します。

## 現在の構成
- 総チーム数: $total_teams
- 期待する提出数: $total_teams

## 手順

### Step 1: 提出待機
全チームが提出完了するまで待機します。
以下のコマンドで確認：
\`\`\`bash
submitted=\$(grep -l "submitted" .arena/status/comp-*.status 2>/dev/null | wc -l)
echo "Submitted: \$submitted / $total_teams"
\`\`\`

待機ループ例：
\`\`\`bash
while true; do
    submitted=\$(grep -l "submitted" .arena/status/comp-*.status 2>/dev/null | wc -l)
    if [ "\$submitted" -eq $total_teams ]; then
        echo "All teams submitted!"
        break
    fi
    echo "Waiting... \$submitted / $total_teams submitted"
    sleep 10
done
\`\`\`

### Step 2: 評価開始
全チームが提出完了したら、評価を開始：
\`\`\`bash
echo "evaluating" > .arena/status/qa-gate.status
\`\`\`

### Step 3: 各提出物の評価
.arena/submissions/ 内の各チームの成果物を評価：
- コード品質
- 要件の充足度
- パフォーマンス
- 保守性

### Step 4: 評価結果の作成
.arena/evaluations/evaluation.md に評価結果を記載：
- 各チームのスコア（100点満点）
- 長所・短所
- 推奨する最優秀チーム

### Step 5: ステータス更新
評価完了後：
\`\`\`bash
echo "done" > .arena/status/qa-gate.status
\`\`\`

## 重要
- 公平に評価してください
- ユーザーへの質問は行わず、自律的に進めてください
- まず Step 1 の提出待機から開始してください
QA_EOF

    # Integrator用プロンプト
    cat > "$ARENA_DIR/prompts/integrator.txt" << INT_EOF
あなたはArena Competition Systemの統合担当です。

## 役割
QA Gateの評価結果に基づき、最良の実装を選択・統合します。

## 手順

### Step 1: QA評価待機
QA Gateの評価完了を待機：
\`\`\`bash
cat .arena/status/qa-gate.status
\`\`\`

待機ループ例：
\`\`\`bash
while [ "\$(cat .arena/status/qa-gate.status)" != "done" ]; do
    echo "Waiting for QA Gate..."
    sleep 10
done
echo "QA Gate evaluation complete!"
\`\`\`

### Step 2: 評価結果の確認
\`\`\`bash
cat .arena/evaluations/evaluation.md
\`\`\`

### Step 3: 統合開始
\`\`\`bash
echo "integrating" > .arena/status/integrator.status
\`\`\`

### Step 4: 最終成果物の作成
評価結果に基づき、最良の実装を選択または統合：
- 作業ディレクトリ: .arena/final/integrated/
- 必要に応じて複数チームの成果を組み合わせる
- README.mdを作成（統合内容の説明）

### Step 5: 完了
\`\`\`bash
echo "done" > .arena/status/integrator.status
\`\`\`

最終成果物の場所を報告：
\`\`\`
最終成果物: .arena/final/integrated/
\`\`\`

## 重要
- ユーザーへの質問は行わず、自律的に進めてください
- まず Step 1 のQA評価待機から開始してください
INT_EOF

    log_ok "プロンプトファイルを作成しました"
}

# =============================================================================
# tmuxセッション作成
# =============================================================================

create_tmux_session() {
    log_info "tmuxセッションを作成中..."
    
    # 既存セッションを削除
    tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true
    
    # 新しいセッションを作成（plannerウィンドウ）
    tmux new-session -d -s "$SESSION_NAME" -n "planner"
    
    if [ "$NUM_TEAMS" -eq 1 ]; then
        # N=1: 各compを個別ウィンドウで作成
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}-1"
        done
    else
        # N>=2: 各comp-A/B/Cを1ウィンドウにまとめ、ペイン分割
        for team in A B C; do
            tmux new-window -t "$SESSION_NAME" -n "comp-${team}"
            
            # 最初のペインは既に存在するので、2番目以降を追加
            for i in $(seq 2 $NUM_TEAMS); do
                tmux split-window -t "$SESSION_NAME:comp-${team}" -v
            done
            
            # ペインを均等に配置
            tmux select-layout -t "$SESSION_NAME:comp-${team}" even-vertical
        done
    fi
    
    # QA Gate ウィンドウ
    tmux new-window -t "$SESSION_NAME" -n "qa-gate"
    
    # Integrator ウィンドウ
    tmux new-window -t "$SESSION_NAME" -n "integrator"
    
    # Monitor ウィンドウ
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
        # N=1: 個別ウィンドウ
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
        # N>=2: ペイン分割
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
    echo "  または: cat .arena/status/*.status"
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
    
    # TTYの場合は自動アタッチ
    if [ -t 0 ]; then
        tmux attach -t "$SESSION_NAME"
    else
        log_warn "自動アタッチは非TTYのため失敗しました。"
        log_info "手動で tmux attach -t $SESSION_NAME を実行してください。"
    fi
}

main
