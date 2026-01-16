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

### 2.1 Update Hook Configuration

The hook at `.claude/hooks/watch-approval-cloud.py` has a hardcoded `PAIRING_ID`. Update it:

**File: `.claude/hooks/watch-approval-cloud.py` (line 21)**
```python
# Change from:
PAIRING_ID = "0a7c5684-24a1-49b0-9c20-67ca7056d0c6"

# To your current pairing ID:
PAIRING_ID = "cbc5e577-a96d-4393-ad22-a57d13f4908a"  # From today's session
```

### 2.2 Enable Hook in Settings

**File: `.claude/settings.local.json`**

Update the `hooks` section:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash|Edit|Write|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 .claude/hooks/watch-approval-cloud.py"
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

## Files to Modify

| File | Change |
|------|--------|
| `.claude/hooks/watch-approval-cloud.py:21` | Update `PAIRING_ID` |
| `.claude/settings.local.json` | Add `hooks` configuration |

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

- [ ] APNs key created in Apple Developer Portal
- [ ] Cloudflare secrets configured (`wrangler secret list` shows 3 secrets)
- [ ] Worker deployed
- [ ] Test request returns `apnsSent: true`
- [ ] Physical watch receives push notification
- [ ] Hook pairing ID updated
- [ ] Hook enabled in settings
- [ ] Claude Code bash command triggers watch notification
- [ ] Approve on watch allows command to proceed
- [ ] Reject on watch blocks command

---

## Optional Improvements (Future)

1. **Dynamic Pairing ID** - Read from a config file or environment variable instead of hardcoding
2. **YOLO Mode Toggle** - Add way to temporarily bypass watch approval
3. **Selective Approval** - Only require approval for certain commands (e.g., destructive ones)
4. **Approval History** - Log approvals for audit trail
