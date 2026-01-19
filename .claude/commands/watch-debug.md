---
description: Debug watch integration - diagnose issues and log bugs for Ralph
allowed-tools: Bash(*), Read, Edit, Write
---

# Watch Debug Session

Diagnose Claude Watch integration issues and log bugs/tasks for Ralph.

## Learnings from Debug Sessions

### Common Issues Discovered

| Issue | Symptom | Root Cause |
|-------|---------|------------|
| **Pairing ID mismatch** | Requests sent but watch shows empty | `~/.claude-watch-pairing` differs from `~/.claude-watch/config.json` |
| **Watch has old pairingId** | Notifications appear then vanish | Watch polls with old ID, gets empty, overwrites local actions |
| **YOLO mode active** | No approval requests | Claude Code in auto-accept mode, hooks don't block |
| **Hook not enabled** | No requests to cloud | PreToolUse hook empty in settings.json |
| **Auto-approved tools** | Edits proceed without asking | Write/Edit in permissions.allow list |
| **Wrong directory** | Hooks not found | Claude started from directory without .claude/settings.json |
| **Cloud unreachable** | Hook timeouts | Network issue or worker down |

## Diagnostic Checklist

Run these checks in order. For each failure, log a task.

### 1. Check Pairing Files Sync
```bash
CLI_PAIRING=$(cat ~/.claude-watch-pairing 2>/dev/null || echo "NOT_FOUND")
CONFIG_PAIRING=$(jq -r .pairingId ~/.claude-watch/config.json 2>/dev/null || echo "NOT_FOUND")
echo "~/.claude-watch-pairing: $CLI_PAIRING"
echo "~/.claude-watch/config.json: $CONFIG_PAIRING"
if [ "$CLI_PAIRING" != "$CONFIG_PAIRING" ]; then
  echo "❌ MISMATCH - Sync with: jq -r .pairingId ~/.claude-watch/config.json > ~/.claude-watch-pairing"
else
  echo "✅ Pairing IDs match"
fi
```

**If mismatch → Log BUG:** "Pairing ID desync between config files"

### 2. Check PreToolUse Hook
```bash
HOOK=$(jq '.hooks.PreToolUse | length' .claude/settings.json 2>/dev/null || echo "0")
if [ "$HOOK" = "0" ] || [ "$HOOK" = "null" ]; then
  echo "❌ PreToolUse hook NOT enabled"
else
  echo "✅ PreToolUse hook enabled ($HOOK matchers)"
  jq '.hooks.PreToolUse[].matcher' .claude/settings.json
fi
```

**If not enabled → Log TASK:** "Enable PreToolUse hook for watch approvals"

### 3. Check Auto-Approved Tools
```bash
ALLOW=$(jq '.permissions.allow' .claude/settings.json 2>/dev/null)
echo "Auto-approved tools:"
echo "$ALLOW" | jq -r '.[]' | head -20
if echo "$ALLOW" | grep -q '"Write"\|"Edit"'; then
  echo "❌ Write/Edit are auto-approved - approvals will be skipped!"
else
  echo "✅ Write/Edit require approval"
fi
```

**If Write/Edit auto-approved → Log TASK:** "Remove Write/Edit from permissions.allow"

### 4. Check Cloud Connectivity
```bash
CLOUD_URL="https://claude-watch.fotescodev.workers.dev"
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" "$CLOUD_URL/health" --max-time 5)
if [ "$HEALTH" = "200" ]; then
  echo "✅ Cloud server reachable"
else
  echo "❌ Cloud server unreachable (HTTP $HEALTH)"
fi
```

**If unreachable → Log BUG:** "Cloud server connectivity issue"

### 5. Check Pending Requests in Cloud
```bash
PAIRING=$(cat ~/.claude-watch-pairing)
PENDING=$(curl -s "$CLOUD_URL/requests/$PAIRING" | jq '.requests | length')
echo "Pending requests in cloud: $PENDING"
if [ "$PENDING" -gt 0 ]; then
  echo "⚠️  Requests pending - watch should be showing them"
  curl -s "$CLOUD_URL/requests/$PAIRING" | jq '.requests[] | {id, title, status}'
fi
```

**If pending > 0 but watch empty → Log BUG:** "Watch not displaying pending requests"

### 6. Test End-to-End Flow
```bash
# Send test request
PAIRING=$(cat ~/.claude-watch-pairing)
RESULT=$(curl -s -X POST "$CLOUD_URL/request" \
  -H "Content-Type: application/json" \
  -d "{\"pairingId\": \"$PAIRING\", \"type\": \"test\", \"title\": \"Debug test\", \"description\": \"Testing e2e flow\"}")
REQUEST_ID=$(echo "$RESULT" | jq -r '.requestId')
APNS_SENT=$(echo "$RESULT" | jq -r '.apnsSent')
echo "Request ID: $REQUEST_ID"
echo "APNs sent: $APNS_SENT"
```

**Expected:** Watch shows notification, MainView displays request with Approve/Reject

### 7. Verify Watch PairingId (Manual)
On watch: Settings → Check pairingId starts with same 8 chars as CLI

```bash
echo "CLI pairingId prefix: $(cat ~/.claude-watch-pairing | cut -c1-8)"
```

**If different → Log BUG:** "Watch has stale pairingId after re-pairing"

## Logging Issues to Ralph

When an issue is found, add to `.claude/ralph/tasks.yaml`:

```yaml
- id: "BUG-xxx"
  title: "<Issue title>"
  description: |
    <What was observed>
    <Root cause if known>
    <Steps to reproduce>
  priority: high
  parallel_group: 1
  completed: false
  tags:
    - bug
    - watch-integration
  commit_template: "fix(watch): <description>"
```

## Quick Fix Commands

### Sync pairing IDs
```bash
jq -r .pairingId ~/.claude-watch/config.json > ~/.claude-watch-pairing
```

### Enable PreToolUse hook
Edit `.claude/settings.json`:
```json
"PreToolUse": [
  {
    "matcher": "Bash|Write|Edit|MultiEdit",
    "hooks": [{"type": "command", "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/watch-approval-cloud.py"}]
  }
]
```

### Remove auto-approve for Write/Edit
```bash
jq '.permissions.allow = [.permissions.allow[] | select(. != "Write" and . != "Edit")]' .claude/settings.json > tmp.json && mv tmp.json .claude/settings.json
```

### Approve all pending (emergency unblock)
```bash
PAIRING=$(cat ~/.claude-watch-pairing)
curl -s "https://claude-watch.fotescodev.workers.dev/requests/$PAIRING" | \
  jq -r '.requests[].id' | \
  xargs -I {} curl -s -X POST "https://claude-watch.fotescodev.workers.dev/respond/{}" \
    -H "Content-Type: application/json" \
    -d "{\"approved\": true, \"pairingId\": \"$PAIRING\"}"
```

### Clear all pending (reject all)
```bash
PAIRING=$(cat ~/.claude-watch-pairing)
curl -s "https://claude-watch.fotescodev.workers.dev/requests/$PAIRING" | \
  jq -r '.requests[].id' | \
  xargs -I {} curl -s -X POST "https://claude-watch.fotescodev.workers.dev/respond/{}" \
    -H "Content-Type: application/json" \
    -d "{\"approved\": false, \"pairingId\": \"$PAIRING\"}"
```

## Success Criteria

A healthy watch integration has ALL of these:

- [ ] `~/.claude-watch-pairing` == `~/.claude-watch/config.json` pairingId
- [ ] PreToolUse hook enabled with watch-approval-cloud.py
- [ ] Write/Edit NOT in permissions.allow
- [ ] Cloud server returns 200 on /health
- [ ] Test request shows on watch within 3 seconds
- [ ] Request stays visible in MainView (doesn't vanish)
- [ ] Approve from watch unblocks Claude Code
- [ ] Reject from watch stops Claude Code with message

## After Running Diagnostics

1. Fix any issues found using Quick Fix Commands
2. Log remaining bugs to Ralph tasks.yaml
3. Restart Claude Code session (hooks load at start)
4. Re-run diagnostics to verify fixes
