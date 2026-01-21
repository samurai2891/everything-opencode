#!/bin/bash
# =============================================================================
# Opencode Batch Launch Script for tmux
# =============================================================================
# 
# Usage:
#   ./batch-launch.sh [options]
#
# Options:
#   -m, --model MODEL       Model to use (default: openai/gpt-5.2-codex)
#   -p, --projects FILE     File containing project paths (one per line)
#   -c, --command CMD       Opencode command to run (e.g., /plan, /tdd)
#   -s, --session NAME      tmux session name (default: opencode-batch)
#   -w, --workers N         Number of parallel workers (default: 4)
#   -h, --help              Show this help message
#
# Examples:
#   # Launch with default Codex 5.2
#   ./batch-launch.sh -p projects.txt -c "/plan"
#
#   # Launch with Claude
#   ./batch-launch.sh -m "anthropic/claude-sonnet-4-20250514" -p projects.txt
#
#   # Launch with Gemini
#   ./batch-launch.sh -m "google/gemini-2.5-pro" -p projects.txt -w 8
#
# =============================================================================

set -euo pipefail

# Default values
MODEL="${OPENCODE_MODEL:-openai/gpt-5.2-codex}"
SMALL_MODEL="${OPENCODE_SMALL_MODEL:-$MODEL}"
SESSION_NAME="opencode-batch"
WORKERS=4
PROJECTS_FILE=""
COMMAND=""

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_help() {
    head -30 "$0" | tail -28
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--model)
            MODEL="$2"
            shift 2
            ;;
        -p|--projects)
            PROJECTS_FILE="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -s|--session)
            SESSION_NAME="$2"
            shift 2
            ;;
        -w|--workers)
            WORKERS="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate inputs
if [[ -z "$PROJECTS_FILE" ]]; then
    log_error "Projects file is required. Use -p or --projects"
    exit 1
fi

if [[ ! -f "$PROJECTS_FILE" ]]; then
    log_error "Projects file not found: $PROJECTS_FILE"
    exit 1
fi

# Export environment variables for Opencode
export OPENCODE_MODEL="$MODEL"
export OPENCODE_SMALL_MODEL="$SMALL_MODEL"

log_info "Starting Opencode Batch Launch"
log_info "Model: $MODEL"
log_info "Workers: $WORKERS"
log_info "Session: $SESSION_NAME"

# Kill existing session if exists
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Create new tmux session
tmux new-session -d -s "$SESSION_NAME"

# Read projects and create windows
WINDOW_INDEX=0
while IFS= read -r project_path || [[ -n "$project_path" ]]; do
    # Skip empty lines and comments
    [[ -z "$project_path" || "$project_path" =~ ^# ]] && continue
    
    # Expand ~ to home directory
    project_path="${project_path/#\~/$HOME}"
    
    if [[ ! -d "$project_path" ]]; then
        log_warn "Directory not found, skipping: $project_path"
        continue
    fi
    
    PROJECT_NAME=$(basename "$project_path")
    
    if [[ $WINDOW_INDEX -eq 0 ]]; then
        # Rename first window
        tmux rename-window -t "$SESSION_NAME:0" "$PROJECT_NAME"
    else
        # Create new window
        tmux new-window -t "$SESSION_NAME" -n "$PROJECT_NAME"
    fi
    
    # Send commands to window
    tmux send-keys -t "$SESSION_NAME:$WINDOW_INDEX" "cd '$project_path'" C-m
    tmux send-keys -t "$SESSION_NAME:$WINDOW_INDEX" "export OPENCODE_MODEL='$MODEL'" C-m
    tmux send-keys -t "$SESSION_NAME:$WINDOW_INDEX" "export OPENCODE_SMALL_MODEL='$SMALL_MODEL'" C-m
    
    if [[ -n "$COMMAND" ]]; then
        # Launch opencode with command
        tmux send-keys -t "$SESSION_NAME:$WINDOW_INDEX" "opencode '$COMMAND'" C-m
    else
        # Just launch opencode
        tmux send-keys -t "$SESSION_NAME:$WINDOW_INDEX" "opencode" C-m
    fi
    
    log_success "Created window for: $PROJECT_NAME"
    ((WINDOW_INDEX++))
    
    # Rate limiting to avoid overwhelming the system
    if (( WINDOW_INDEX % WORKERS == 0 )); then
        sleep 1
    fi
    
done < "$PROJECTS_FILE"

log_success "Batch launch complete. $WINDOW_INDEX projects started."
log_info "Attach to session: tmux attach -t $SESSION_NAME"

# Optionally attach to session
read -p "Attach to tmux session now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    tmux attach -t "$SESSION_NAME"
fi
