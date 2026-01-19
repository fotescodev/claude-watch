---
description: Enable watch approval mode - all tool calls require Apple Watch approval
allowed-tools: Read, Edit, Bash(cat:*), Bash(jq:*), Bash(python3:*)
---

# Enable Watch Approval Mode

Configure this session so tool calls require Apple Watch approval.

## Execute These Steps

### 1. Verify Pairing
```bash
if [ -f ~/.claude-watch-pairing ]; then
  echo "✓ Paired: $(cat ~/.claude-watch-pairing)"
else
  echo "✗ Not paired - run 'npx cc-watch' first"
  exit 1
fi
```

### 2. Enable PreToolUse Hook
Edit `.claude/settings.json` and set PreToolUse to:
```json
"PreToolUse": [
  {
    "matcher": "Bash|Write|Edit|MultiEdit",
    "hooks": [
      {
        "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/watch-approval-cloud.py"
      }
    ]
  }
]
```

### 3. Remove Write/Edit from Auto-Approve
In `.claude/settings.json`, remove `"Write"` and `"Edit"` from `permissions.allow` array so they require approval.

### 4. Confirm Setup
```bash
echo "Watch mode enabled. Restart Claude Code for changes to take effect."
echo ""
echo "Next steps:"
echo "1. Exit this session (Ctrl+C)"
echo "2. Start new session: claude"
echo "3. Ask Claude to edit a file"
echo "4. Approve from your Apple Watch"
```

## Result
After restarting Claude Code:
- Every Bash/Write/Edit will send approval request to watch
- You approve/reject from your wrist
- Claude proceeds or stops based on your decision
