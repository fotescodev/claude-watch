#!/bin/bash
# Toggle PreToolUse hooks between DEV and TESTING modes
#
# Usage:
#   ./.claude/hooks/toggle-watch-hooks.sh        # Toggle current state
#   ./.claude/hooks/toggle-watch-hooks.sh on     # Enable hooks (TESTING mode)
#   ./.claude/hooks/toggle-watch-hooks.sh off    # Disable hooks (DEV mode)
#   ./.claude/hooks/toggle-watch-hooks.sh status # Show current state
#
# NOTE: After toggling, you must restart Claude Code for changes to take effect.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Install with: brew install jq"
    exit 1
fi

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Error: Settings file not found at $SETTINGS_FILE"
    exit 1
fi

# Get current state (0 = disabled, >0 = enabled)
get_state() {
    jq -r '.hooks.PreToolUse | length' "$SETTINGS_FILE" 2>/dev/null || echo "0"
}

# Enable hooks (TESTING mode)
enable_hooks() {
    echo "Enabling watch notification hooks (TESTING mode)..."

    # Create the hook configuration
    local hook_config='[
      {
        "matcher": "Bash|Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/watch-approval-cloud.py"
          }
        ]
      }
    ]'

    # Update settings file
    jq --argjson hooks "$hook_config" '.hooks.PreToolUse = $hooks' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    echo "Hooks ENABLED - notifications will be sent to watch"
    echo ""
    echo "IMPORTANT: Restart Claude Code for changes to take effect."
}

# Disable hooks (DEV mode)
disable_hooks() {
    echo "Disabling watch notification hooks (DEV mode)..."

    # Set PreToolUse to empty array
    jq '.hooks.PreToolUse = []' "$SETTINGS_FILE" > "$SETTINGS_FILE.tmp"
    mv "$SETTINGS_FILE.tmp" "$SETTINGS_FILE"

    echo "Hooks DISABLED - normal development workflow"
    echo ""
    echo "IMPORTANT: Restart Claude Code for changes to take effect."
}

# Show current state
show_status() {
    local state=$(get_state)
    echo "PreToolUse Hook Status"
    echo "======================"
    if [ "$state" -eq 0 ]; then
        echo "Mode: DEV (hooks disabled)"
        echo "Behavior: Claude Code operates normally without watch notifications"
    else
        echo "Mode: TESTING (hooks enabled)"
        echo "Behavior: File edits trigger watch notification approval flow"
    fi
    echo ""
    echo "Settings file: $SETTINGS_FILE"
}

# Main logic
case "${1:-}" in
    on|enable)
        enable_hooks
        ;;
    off|disable)
        disable_hooks
        ;;
    status)
        show_status
        ;;
    *)
        # Toggle based on current state
        current_state=$(get_state)
        if [ "$current_state" -eq 0 ]; then
            enable_hooks
        else
            disable_hooks
        fi
        ;;
esac
