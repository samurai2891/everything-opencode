---
name: tmux-integration
description: tmux integration for persistent sessions and log access in Ghostty terminal.
---

# tmux Integration

## Why Use tmux

When working with OpenCode in a terminal environment like Ghostty, tmux provides:

- **Session Persistence**: Processes continue running even if terminal disconnects
- **Log Access**: View output from background processes anytime
- **Multiple Panes**: Split terminal for parallel workflows
- **Session Sharing**: Attach to sessions from different terminals

## Basic Commands

### Session Management

```bash
# Create new session
tmux new-session -s dev

# Create detached session with command
tmux new-session -d -s dev 'npm run dev'

# List sessions
tmux ls

# Attach to session
tmux attach -t dev

# Detach from session
# Press: Ctrl+b, then d

# Kill session
tmux kill-session -t dev
```

### Window Management

```bash
# Create new window
# Press: Ctrl+b, then c

# Switch windows
# Press: Ctrl+b, then 0-9

# Rename window
# Press: Ctrl+b, then ,

# Close window
# Press: Ctrl+b, then &
```

### Pane Management

```bash
# Split horizontally
# Press: Ctrl+b, then "

# Split vertically
# Press: Ctrl+b, then %

# Navigate panes
# Press: Ctrl+b, then arrow keys

# Close pane
# Press: Ctrl+b, then x
```

## Development Workflow

### Starting Dev Server

Always run development servers in tmux:

```bash
# Start dev server in background
tmux new-session -d -s dev 'npm run dev'

# View logs
tmux attach -t dev

# Detach to continue working
# Press: Ctrl+b, then d
```

### Multi-Pane Development Setup

```bash
# Create session with multiple panes
tmux new-session -s work \; \
  split-window -h \; \
  split-window -v \; \
  select-pane -t 0

# Pane 0: Editor
# Pane 1: Dev server
# Pane 2: Tests
```

### Running Tests

```bash
# Run tests in tmux
tmux new-session -d -s test 'npm test -- --watch'

# Check test output
tmux attach -t test
```

## Recommended Session Structure

```
Session: dev
├── Window 0: editor
├── Window 1: server (npm run dev)
├── Window 2: tests (npm test --watch)
└── Window 3: git/misc
```

## Configuration

Create `~/.tmux.conf` for customization:

```bash
# Enable mouse support
set -g mouse on

# Start windows at 1
set -g base-index 1

# Better colors
set -g default-terminal "screen-256color"

# Increase history
set -g history-limit 10000

# Status bar
set -g status-style bg=black,fg=white
set -g status-left '[#S] '
set -g status-right '%H:%M %d-%b'
```

## Integration with OpenCode

### Before Running Dev Server

```bash
# Check if tmux session exists
tmux has-session -t dev 2>/dev/null

# If not, create it
tmux new-session -d -s dev 'npm run dev'
```

### Viewing Logs

```bash
# Capture recent output
tmux capture-pane -t dev -p | tail -50

# Save to file
tmux capture-pane -t dev -p > dev-logs.txt
```

### Sending Commands

```bash
# Send command to running session
tmux send-keys -t dev 'npm run build' Enter
```

## Troubleshooting

### Session Not Found

```bash
# List all sessions
tmux ls

# If empty, create new
tmux new-session -s dev
```

### Process Died

```bash
# Check if process is running
tmux send-keys -t dev '' Enter

# Restart if needed
tmux send-keys -t dev 'npm run dev' Enter
```

### Terminal Issues

```bash
# Reset terminal
tmux kill-server
tmux new-session -s dev
```

## Best Practices

1. **Always use tmux for dev servers** - Ensures logs are accessible
2. **Name sessions descriptively** - Easy to identify purpose
3. **Use detached sessions** - Don't block terminal
4. **Check session before creating** - Avoid duplicates
5. **Clean up old sessions** - Kill unused sessions

Remember: Running dev servers outside tmux means losing access to logs and output. Always use tmux for persistent processes.
