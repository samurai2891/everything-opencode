#!/bin/bash

# Everything OpenCode Installation Script
# Installs agents, commands, and skills to OpenCode configuration

set -e

echo "=== Everything OpenCode Installer ==="
echo ""

# Determine installation target
if [ "$1" == "--global" ]; then
    TARGET_DIR="$HOME/.config/opencode"
    echo "Installing globally to $TARGET_DIR"
else
    TARGET_DIR="."
    echo "Installing to current directory"
    echo "Use --global flag to install to ~/.config/opencode"
fi

# Create directories if needed
mkdir -p "$TARGET_DIR/.opencode/agents"
mkdir -p "$TARGET_DIR/.opencode/commands"
mkdir -p "$TARGET_DIR/.opencode/skills"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Copy configuration files
echo ""
echo "Copying configuration files..."

if [ "$TARGET_DIR" != "." ]; then
    cp "$SCRIPT_DIR/opencode.json" "$TARGET_DIR/"
    cp "$SCRIPT_DIR/AGENTS.md" "$TARGET_DIR/"
fi

# Copy agents
echo "Copying agents..."
cp "$SCRIPT_DIR/.opencode/agents/"*.md "$TARGET_DIR/.opencode/agents/"

# Copy commands
echo "Copying commands..."
cp "$SCRIPT_DIR/.opencode/commands/"*.md "$TARGET_DIR/.opencode/commands/"

# Copy skills
echo "Copying skills..."
cp "$SCRIPT_DIR/.opencode/skills/"*.md "$TARGET_DIR/.opencode/skills/"

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed components:"
echo "  - $(ls -1 "$TARGET_DIR/.opencode/agents/"*.md 2>/dev/null | wc -l) agents"
echo "  - $(ls -1 "$TARGET_DIR/.opencode/commands/"*.md 2>/dev/null | wc -l) commands"
echo "  - $(ls -1 "$TARGET_DIR/.opencode/skills/"*.md 2>/dev/null | wc -l) skills"
echo ""
echo "Next steps:"
echo "  1. Set environment variables (see .env.example)"
echo "  2. Run 'opencode' and use '/connect' to add providers"
echo "  3. Use '/models' to select your preferred model"
echo ""
echo "Available commands:"
echo "  /plan          - Create implementation plans"
echo "  /code-review   - Review code for issues"
echo "  /security-audit - Security analysis"
echo "  /tdd           - Test-driven development"
echo "  /build-fix     - Fix build errors"
echo "  /e2e           - Generate E2E tests"
echo "  /refactor      - Refactor code"
echo "  /doc-sync      - Sync documentation"
echo "  /architect     - Architecture guidance"
echo ""
