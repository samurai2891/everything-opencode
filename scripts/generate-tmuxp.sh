#!/bin/bash
# =============================================================================
# Generate Tmuxp Configuration Dynamically
# =============================================================================
#
# Usage:
#   ./generate-tmuxp.sh [options]
#
# Options:
#   -m, --model MODEL       Model to use (default: openai/gpt-5.2-codex)
#   -p, --projects FILE     File containing project paths (one per line)
#   -o, --output FILE       Output tmuxp config file (default: generated.yaml)
#   -c, --command CMD       Opencode command to run on startup
#   -h, --help              Show this help message
#
# Examples:
#   # Generate config with Codex 5.2
#   ./generate-tmuxp.sh -p projects.txt -o workspace.yaml
#
#   # Generate config with Claude and auto-run /plan
#   ./generate-tmuxp.sh -m "anthropic/claude-sonnet-4-20250514" -p projects.txt -c "/plan"
#
# =============================================================================

set -euo pipefail

# Default values
MODEL="${OPENCODE_MODEL:-openai/gpt-5.2-codex}"
PROJECTS_FILE=""
OUTPUT_FILE="generated.yaml"
COMMAND=""

show_help() {
    head -25 "$0" | tail -23
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
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$PROJECTS_FILE" ]]; then
    echo "Error: Projects file is required. Use -p or --projects"
    exit 1
fi

if [[ ! -f "$PROJECTS_FILE" ]]; then
    echo "Error: Projects file not found: $PROJECTS_FILE"
    exit 1
fi

# Generate YAML header
cat > "$OUTPUT_FILE" << EOF
# Auto-generated Tmuxp configuration
# Model: $MODEL
# Generated: $(date -Iseconds)

session_name: opencode-batch

environment:
  OPENCODE_MODEL: "$MODEL"
  OPENCODE_SMALL_MODEL: "$MODEL"
  OPENCODE_PLAN_MODEL: "$MODEL"

windows:
EOF

# Generate windows for each project
while IFS= read -r project_path || [[ -n "$project_path" ]]; do
    # Skip empty lines and comments
    [[ -z "$project_path" || "$project_path" =~ ^# ]] && continue
    
    # Expand ~ to home directory
    project_path="${project_path/#\~/$HOME}"
    
    if [[ ! -d "$project_path" ]]; then
        echo "Warning: Directory not found, skipping: $project_path" >&2
        continue
    fi
    
    PROJECT_NAME=$(basename "$project_path")
    
    # Determine opencode command
    if [[ -n "$COMMAND" ]]; then
        OPENCODE_CMD="opencode '$COMMAND'"
    else
        OPENCODE_CMD="opencode"
    fi
    
    cat >> "$OUTPUT_FILE" << EOF
  - window_name: $PROJECT_NAME
    layout: main-vertical
    start_directory: $project_path
    shell_command_before:
      - export OPENCODE_MODEL="$MODEL"
    panes:
      - shell_command:
          - $OPENCODE_CMD
      - shell_command:
          - # Terminal

EOF

done < "$PROJECTS_FILE"

echo "Generated: $OUTPUT_FILE"
echo "Run: tmuxp load $OUTPUT_FILE"
