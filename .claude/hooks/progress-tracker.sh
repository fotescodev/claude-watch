#!/bin/bash
# Wrapper to invoke progress-tracker.py
# Debug log - write FIRST before anything else
echo "$(date '+%Y-%m-%d %H:%M:%S') - progress-tracker.sh invoked" >> /tmp/progress-tracker-sh.log

# Capture stdin to temp file (stdin can only be read once)
STDIN_DATA=$(cat)
echo "$STDIN_DATA" >> /tmp/progress-tracker-sh.log

# Pass to Python script
echo "$STDIN_DATA" | python3 "$CLAUDE_PROJECT_DIR/.claude/hooks/progress-tracker.py" 2>> /tmp/progress-tracker-sh.log

# Always exit 0 - don't block Claude Code
exit 0
