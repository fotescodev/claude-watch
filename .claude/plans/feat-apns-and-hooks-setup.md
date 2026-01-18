# Plan: Enable APNs Push Notifications + Claude Code Hooks

## Overview

All code is already implemented. This plan focuses on **configuration only**:
1. Configure APNs credentials in Cloudflare Worker for instant push notifications
2. Enable the PreToolUse hook so Claude Code permission prompts route to the watch

## Current State

✅ **Already Working:**
- MCP Server (`MCPServer/server.py`) configured in `.mcp.json`
- Cloudflare Worker with APNs code at `MCPServer/worker/src/index.js`
- Watch app with notification handling
- PreToolUse hook script at `.claude/hooks/watch-approval-cloud.py`
- Cloud pairing flow tested and working

❌ **Not Configured:**
- APNs secrets in Cloudflare (returns `apnsSent: false`)
- Hook not enabled in `.claude/settings.local.json`
- Hook has hardcoded `PAIRING_ID`

---

## Part 1: APNs Setup

### 1.1 Create APNs Key in Apple Developer Portal

1. Go to https://developer.apple.com/account/resources/authkeys/list
2. Click "+" to create a new key
3. Name: "Claude Watch APNs"
4. Check "Apple Push Notifications service (APNs)"
5. Download the `.p8` file (save it securely - only downloadable once)
6. Note the **Key ID** (10 characters, shown on the keys page)
7. Note your **Team ID** (from Membership page or top-right of portal)

### 1.2 Configure Cloudflare Worker Secrets

```bash
cd MCPServer/worker

# Set APNs Key ID (from step 1.6)
npx wrangler secret put APNS_KEY_ID
# Enter: <your 10-char key ID>

# Set Team ID (from step 1.7)
npx wrangler secret put APNS_TEAM_ID
# Enter: <your team ID>

# Set Private Key (base64 encoded p8 file)
# First encode the key:
base64 -i ~/Downloads/AuthKey_XXXXXXXXXX.p8 | pbcopy
# Then set the secret:
npx wrangler secret put APNS_PRIVATE_KEY
# Paste the base64 string
```

### 1.3 Deploy Updated Worker

```bash
cd MCPServer/worker
npx wrangler deploy
```

### 1.4 Verify APNs Works

```bash
# Get a fresh pairing code
curl -X POST https://claude-watch.fotescodev.workers.dev/pair

# Pair your physical watch with the code

# Send a test request (use the pairingId from pairing)
curl -X POST https://claude-watch.fotescodev.workers.dev/request \
  -H "Content-Type: application/json" \
  -d '{"pairingId":"<YOUR_PAIRING_ID>","type":"bash","title":"APNs Test","description":"Testing push notifications"}'

# Should return: {"requestId":"xxx","apnsSent":true}
```

---

## Part 2: Enable Claude Code Hook

### 2.1 Pairing Setup (One-Time)

The hook now reads the pairing ID from a config file. Run the pairing helper:

```bash
# Run the interactive pairing script
python3 .claude/hooks/claude-watch-pair.py
```

This will:
1. Generate a pairing code from the cloud server
2. Display the code for you to enter on your watch
3. Wait for pairing completion
4. Save the pairing ID to `~/.claude-watch-pairing`

**Alternative: Manual Setup**
```bash
# Generate pairing code
curl -X POST https://claude-watch.fotescodev.workers.dev/pair
# Returns: {"code":"ABC-123","pairingId":"your-uuid-here",...}

# Enter code on watch, then save the pairingId:
echo "your-uuid-here" > ~/.claude-watch-pairing
chmod 600 ~/.claude-watch-pairing
```

**Alternative: Environment Variable**
```bash
export CLAUDE_WATCH_PAIRING_ID="your-uuid-here"
```

### 2.2 Hook Configuration (Already Enabled)

The hook is already enabled in `.claude/settings.json`:

```json
{
  "hooks": {
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
  }
}
```

### 2.3 Test the Hook

1. Ensure your physical watch is paired and app is open
2. In Claude Code, run any bash command
3. You should receive a push notification on your watch
4. Approve/reject from watch
5. Claude Code should proceed/stop accordingly

---

## Files Modified

| File | Change |
|------|--------|
| `.claude/hooks/watch-approval-cloud.py` | ✅ Now reads pairing ID from `~/.claude-watch-pairing` or env var |
| `.claude/hooks/claude-watch-pair.py` | ✅ NEW: Interactive pairing helper script |
| `.claude/hooks/test_watch_approval.py` | ✅ NEW: Unit tests (22 tests) |
| `.claude/settings.json` | ✅ Hook already enabled |

## External Actions Required

| Action | Where |
|--------|-------|
| Create APNs Key | Apple Developer Portal |
| Set `APNS_KEY_ID` secret | Cloudflare Worker |
| Set `APNS_TEAM_ID` secret | Cloudflare Worker |
| Set `APNS_PRIVATE_KEY` secret | Cloudflare Worker |
| Deploy worker | `npx wrangler deploy` |

---

## Verification Checklist

### APNs Setup (Cloud)
- [ ] APNs key created in Apple Developer Portal
- [ ] Cloudflare secrets configured (`wrangler secret list` shows 3 secrets)
- [ ] Worker deployed
- [ ] Test request returns `apnsSent: true`
- [ ] Physical watch receives push notification

### Hook Setup (Local)
- [ ] Run unit tests: `python3 .claude/hooks/test_watch_approval.py` (22 tests pass)
- [ ] Run pairing: `python3 .claude/hooks/claude-watch-pair.py`
- [ ] Verify config saved: `cat ~/.claude-watch-pairing`
- [ ] Hook enabled in settings (already done)

### End-to-End Test
- [ ] Claude Code bash command triggers watch notification
- [ ] Approve on watch allows command to proceed
- [ ] Reject on watch blocks command

---

## Optional Improvements (Future)

1. ~~**Dynamic Pairing ID** - Read from a config file or environment variable instead of hardcoding~~ ✅ DONE
2. **YOLO Mode Toggle** - Add way to temporarily bypass watch approval
3. **Selective Approval** - Only require approval for certain commands (e.g., destructive ones)
4. **Approval History** - Log approvals for audit trail

---

## TODO: Manual macOS Testing

**Status**: Pending user testing on macOS environment

### Prerequisites
- macOS with Xcode installed
- Apple Watch (physical or simulator)
- Claude Code CLI installed

### Test Steps

#### 1. Run Unit Tests
```bash
cd /path/to/claude-watch
python3 .claude/hooks/test_watch_approval.py
# Expected: 22 tests pass
```

#### 2. Test Pairing Flow (Simulator)
```bash
# Start watch simulator
open -a Simulator

# Build and install app
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build

# Run pairing helper
python3 .claude/hooks/claude-watch-pair.py

# Enter the displayed code in the watch app
# Verify: ~/.claude-watch-pairing contains the pairing ID
```

#### 3. Test Hook Without Watch (Fail-Open)
```bash
# Remove pairing config temporarily
mv ~/.claude-watch-pairing ~/.claude-watch-pairing.bak

# In a Claude Code session, try a Bash command
# Expected: Command runs immediately (no watch configured = fail open)
# Expected stderr: "Claude Watch not configured..."

# Restore config
mv ~/.claude-watch-pairing.bak ~/.claude-watch-pairing
```

#### 4. Test Hook With Watch (Full Flow)
```bash
# Ensure watch app is running in simulator
# Ensure ~/.claude-watch-pairing exists

# In Claude Code, run: echo "test"
# Expected: Request appears on watch simulator
# Approve → command runs
# Reject → command blocked

# Test with Edit tool too
```

#### 5. Test Environment Variable Override
```bash
export CLAUDE_WATCH_PAIRING_ID="test-override-id"
# Hook should use env var instead of file
# Unset to restore normal behavior
unset CLAUDE_WATCH_PAIRING_ID
```

### Expected Results

| Test | Pass Criteria |
|------|---------------|
| Unit tests | 22/22 pass |
| Pairing helper | Creates `~/.claude-watch-pairing` |
| No config = fail open | Commands proceed with warning |
| With config + approve | Commands proceed |
| With config + reject | Commands blocked (exit 2) |
| Env var override | Uses env var over file |

### Notes
- Physical watch requires APNs configuration (see Part 1)
- Simulator uses `xcrun simctl push` for notifications
- Hook timeout is 5 minutes (300 seconds)
