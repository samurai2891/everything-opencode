#!/bin/bash
# =============================================================================
# Arena Launcher V2 - 改善版（要件ファイルベース）
# =============================================================================
# 使用方法:
#   arena-launcher-v2.sh "要件テキスト"
#   arena-launcher-v2.sh --file requirements.md
#   arena-launcher-v2.sh --teams 3 "要件テキスト"
# =============================================================================

set -e

# デフォルト設定
SESSION_NAME="arena"
NUM_TEAMS=3
REQUIREMENTS=""
REQUIREMENTS_FILE=""
OPENCODE_CMD="opencode"
ARENA_DIR=".arena"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"

# 色付き出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ヘルプ表示
show_help() {
    cat << EOF
Arena Launcher V2 - 複数LLMエージェントを並列実行するtmuxセッションを起動（改善版）

使用方法:
  arena-launcher-v2.sh [オプション] "要件テキスト"

オプション:
  -t, --teams NUM      競争チーム数 (デフォルト: 3)
  -f, --file FILE      要件ファイルのパス
  -s, --session NAME   tmuxセッション名 (デフォルト: arena)
  -h, --help           このヘルプを表示

例:
  arena-launcher-v2.sh "ECサイトのカート機能を実装してください"
  arena-launcher-v2.sh -t 5 -f requirements.md
  arena-launcher-v2.sh --teams 3 --session my-arena "3Dゲームを作成"

EOF
}

# 引数解析
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -t|--teams)
                NUM_TEAMS="$2"
                shift 2
                ;;
            -f|--file)
                REQUIREMENTS_FILE="$2"
                shift 2
                ;;
            -s|--session)
                SESSION_NAME="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "不明なオプション: $1"
                show_help
                exit 1
                ;;
            *)
                REQUIREMENTS="$1"
                shift
                ;;
        esac
    done
}

# 要件の取得
get_requirements() {
    if [[ -n "$REQUIREMENTS_FILE" && -f "$REQUIREMENTS_FILE" ]]; then
        REQUIREMENTS=$(cat "$REQUIREMENTS_FILE")
        log_info "要件ファイルを読み込みました: $REQUIREMENTS_FILE"
    elif [[ -z "$REQUIREMENTS" ]]; then
        log_error "要件が指定されていません"
        echo ""
        show_help
        exit 1
    fi
}

# 要件ファイルを保存
save_requirements() {
    mkdir -p "$ARENA_DIR"
    echo "$REQUIREMENTS" > "$ARENA_DIR/requirements.md"
    log_success "要件を保存しました: $ARENA_DIR/requirements.md"
}

# プロンプトファイルを作成
create_prompt_files() {
    mkdir -p "$ARENA_DIR/prompts"
    
    # Central Planner用プロンプト
    cat > "$ARENA_DIR/prompts/planner.txt" << EOF
以下の要件に基づいてアリーナ競争を開始してください。各チームにタスクを割り当て、進捗を監視してください。

## 要件
$REQUIREMENTS

## あなたの役割
1. 要件を分析し、タスクを分解する
2. 各競争チーム（comp-A, comp-B, comp-C）にタスクを割り当てる
3. 進捗を監視し、必要に応じて調整する
4. 最終的な統合を指示する
EOF
    
    # 各チーム用プロンプト
    local team_names=("comp-A" "comp-B" "comp-C")
    local team_roles=("コア機能実装" "データ層・インフラ" "API設計・統合")
    
    for i in "${!team_names[@]}"; do
        local team="${team_names[$i]}"
        local role="${team_roles[$i]}"
        
        cat > "$ARENA_DIR/prompts/${team}.txt" << EOF
あなたは競争チーム $team（$role担当）です。

## 要件
$REQUIREMENTS

## あなたの役割
- $role を担当
- 高品質なコードを実装
- テストを作成
- 他チームより優れた実装を目指す

実装を開始してください。
EOF
    done
    
    # QA Gate用プロンプト
    cat > "$ARENA_DIR/prompts/qa-gate.txt" << EOF
あなたはQA Gateです。各チームの実装を評価してください。

## 要件
$REQUIREMENTS

## あなたの役割
1. 各チームの実装をレビュー
2. コード品質を評価（0-100点）
3. テストカバレッジを確認
4. セキュリティをチェック
5. 最も優れた実装を選定

評価を開始してください。
EOF
    
    # Integrator用プロンプト
    cat > "$ARENA_DIR/prompts/integrator.txt" << EOF
あなたはIntegratorです。勝者の実装を統合してください。

## 要件
$REQUIREMENTS

## あなたの役割
1. QA Gateが選定した勝者の実装を取得
2. 各チームの優れた部分を統合
3. コンフリクトを解決
4. 最終的な実装を完成させる

統合準備を開始してください。
EOF
    
    log_success "プロンプトファイルを作成しました: $ARENA_DIR/prompts/"
}

# 既存セッションの確認と削除
cleanup_existing_session() {
    if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        log_warn "既存のセッション '$SESSION_NAME' を削除します..."
        tmux kill-session -t "$SESSION_NAME"
    fi
}

# tmuxセッションを作成
create_arena_session() {
    log_info "Arenaセッションを作成中..."
    
    # 1. メインセッションを作成（Central Planner）
    tmux new-session -d -s "$SESSION_NAME" -n "planner"
    log_success "セッション '$SESSION_NAME' を作成しました"
    
    # 2. Central Plannerを起動（プロンプトファイルを使用）
    local planner_file="$(pwd)/$ARENA_DIR/prompts/planner.txt"
    tmux send-keys -t "$SESSION_NAME:planner" "$OPENCODE_CMD" Enter
    sleep 3
    # プロンプトファイルの内容を1行ずつ送信
    while IFS= read -r line; do
        tmux send-keys -t "$SESSION_NAME:planner" "$line"
        sleep 0.1
    done < "$planner_file"
    tmux send-keys -t "$SESSION_NAME:planner" Enter
    log_success "Central Plannerを起動しました"
    
    # 3. 競争チームウィンドウを作成
    local team_names=("comp-A" "comp-B" "comp-C")
    
    for i in "${!team_names[@]}"; do
        if [[ $i -lt $NUM_TEAMS ]]; then
            local team="${team_names[$i]}"
            local team_file="$(pwd)/$ARENA_DIR/prompts/${team}.txt"
            
            tmux new-window -t "$SESSION_NAME" -n "$team"
            tmux send-keys -t "$SESSION_NAME:$team" "$OPENCODE_CMD" Enter
            sleep 3
            # プロンプトファイルの内容を1行ずつ送信
            while IFS= read -r line; do
                tmux send-keys -t "$SESSION_NAME:$team" "$line"
                sleep 0.1
            done < "$team_file"
            tmux send-keys -t "$SESSION_NAME:$team" Enter
            log_success "チーム $team を起動しました"
        fi
    done
    
    # 4. QA Gateウィンドウを作成
    tmux new-window -t "$SESSION_NAME" -n "qa-gate"
    local qa_file="$(pwd)/$ARENA_DIR/prompts/qa-gate.txt"
    tmux send-keys -t "$SESSION_NAME:qa-gate" "$OPENCODE_CMD" Enter
    sleep 3
    while IFS= read -r line; do
        tmux send-keys -t "$SESSION_NAME:qa-gate" "$line"
        sleep 0.1
    done < "$qa_file"
    tmux send-keys -t "$SESSION_NAME:qa-gate" Enter
    log_success "QA Gateを起動しました"
    
    # 5. Integratorウィンドウを作成
    tmux new-window -t "$SESSION_NAME" -n "integrator"
    local integrator_file="$(pwd)/$ARENA_DIR/prompts/integrator.txt"
    tmux send-keys -t "$SESSION_NAME:integrator" "$OPENCODE_CMD" Enter
    sleep 3
    while IFS= read -r line; do
        tmux send-keys -t "$SESSION_NAME:integrator" "$line"
        sleep 0.1
    done < "$integrator_file"
    tmux send-keys -t "$SESSION_NAME:integrator" Enter
    log_success "Integratorを起動しました"
    
    # 6. 最初のウィンドウ（planner）に戻る
    tmux select-window -t "$SESSION_NAME:planner"
}

# ステータス表示
show_status() {
    echo ""
    echo "=============================================="
    echo -e "${GREEN}Arena セッションが起動しました！${NC}"
    echo "=============================================="
    echo ""
    echo "セッション名: $SESSION_NAME"
    echo "チーム数: $NUM_TEAMS"
    echo ""
    echo "ウィンドウ一覧:"
    tmux list-windows -t "$SESSION_NAME" -F "  #{window_index}: #{window_name}"
    echo ""
    echo "=============================================="
    echo "確認方法:"
    echo "  tmux attach -t $SESSION_NAME"
    echo ""
    echo "ウィンドウ切り替え:"
    echo "  Ctrl+b, n  (次のウィンドウ)"
    echo "  Ctrl+b, p  (前のウィンドウ)"
    echo "  Ctrl+b, 0-5 (番号でウィンドウ選択)"
    echo ""
    echo "セッション終了:"
    echo "  tmux kill-session -t $SESSION_NAME"
    echo "=============================================="
}

# 自動アタッチ
auto_attach() {
    # 現在tmux内にいるかチェック
    if [[ -n "$TMUX" ]]; then
        log_info "tmux内から実行されています。新しいウィンドウに切り替えます..."
        tmux switch-client -t "$SESSION_NAME"
    else
        log_info "Arenaセッションにアタッチします..."
        tmux attach -t "$SESSION_NAME" || log_warn "自動アタッチは非TTYのため失敗しました。手動で tmux attach -t $SESSION_NAME を実行してください。"
    fi
}

# メイン処理
main() {
    echo ""
    echo "=============================================="
    echo "   Arena Launcher V2 - 並列LLM競争システム"
    echo "=============================================="
    echo ""
    
    # 引数解析
    parse_args "$@"
    
    # 要件取得
    get_requirements
    
    # 要件保存
    save_requirements
    
    # プロンプトファイル作成
    create_prompt_files
    
    # 既存セッションのクリーンアップ
    cleanup_existing_session
    
    # Arenaセッション作成
    create_arena_session
    
    # ステータス表示
    show_status
    
    # 自動アタッチ
    auto_attach
}

# スクリプト実行
main "$@"
