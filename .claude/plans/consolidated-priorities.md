# Claude Watch - Consolidated Priority Plan

**Generated**: 2026-01-17
**Deepened**: 2026-01-17 (with parallel research agents)
**Purpose**: Single source of truth for all pending work, organized for Ralph loop execution

---

## Enhancement Summary

**Research agents used**: 7 parallel agents (clipboard, deep links, server patterns, security, simplicity, architecture, performance)
**Key discoveries**: 3 critical findings, 2 blockers, 1 new infrastructure task

### Critical Findings

1. **🚨 BLOCKER: UIPasteboard NOT available on watchOS** - SP1 cannot work as designed
2. **⚠️ SECURITY: Numeric codes (SP2/SP4) reduce entropy from ~30 to ~20 bits** - Rate limiting required
3. **💡 SIMPLIFICATION: SP3 (deep links) may be unnecessary** - SP1 alone could solve friction

### Recommended Changes

| Original Task | Recommendation | Reason |
|--------------|----------------|--------|
| SP1 (Clipboard) | **REDESIGN** | UIPasteboard unavailable; use WatchConnectivity |
| SP2 (Numeric input) | KEEP with security | Add server-side rate limiting |
| SP3 (Deep links) | DEFER | Adds complexity; SP1+SP2 sufficient for MVP |
| SP4 (Server numeric) | KEEP | Required for SP2 |
| SP5 (QR hint) | DEFER | Nice-to-have after core works |

---

## Executive Summary

The Claude Watch project has completed **14 of 19 tasks** with **5 remaining** (Seamless Pairing feature):

| Workstream | Status | Next Action |
|------------|--------|-------------|
| **Core Features** | 14/14 Complete | Done |
| **Ralph Infrastructure** | All Fixes Applied | Ready to run |
| **Seamless Pairing** | 0/5 Complete | Ralph can start now |
| **APNs Setup** | Blocked | Requires manual Apple Portal action |

---

## Current State (2026-01-17)

### All P0 Blockers RESOLVED

The following issues from [008-pending-p0-ralph-failure-root-cause-analysis.md](/todos/008-pending-p0-ralph-failure-root-cause-analysis.md) have been fixed:

| Issue | Resolution | Verified |
|-------|------------|----------|
| R1: Validation timing bug | `git_has_code_changes()` now checks last commit | Lines 225-232 in ralph.sh |
| R2: LG1 impossible API | Changed to `ultraThinMaterial` verification | Task completed, verified |
| R3: LG2 grep pattern | Updated to match `animation(.bouncy)` | Task completed, verified |
| R4: T1 file path | Fixed to `ClaudeWatch/Tests/` | Task completed, verified |

### Completed Tasks (14/19)

All core functionality implemented:

| Phase | Tasks | Status |
|-------|-------|--------|
| Phase 0 (Test) | TEST1 | Complete |
| Phase 1 (Critical) | C1, C2 | Complete |
| Phase 2 (Dependencies) | C3 | Complete |
| Phase 3 (Quality) | H1, H2, H3, H4 | Complete |
| Phase 4 (Enhancement) | M1, M2, M3 | Complete |
| Phase 5 (Liquid Glass) | LG1, LG2 | Complete |
| Phase 6 (Testing) | T1 | Complete |

---

## Next Priority: Seamless Pairing (REVISED)

### ⚠️ IMPORTANT: Task Redesign Required

Research discovered that **UIPasteboard is NOT available on watchOS**. The original SP1 task ("clipboard paste button") cannot be implemented as specified.

### Revised Task Plan (MVP Focus)

Only execute SP2 and SP4 for now. The others need redesign or deferral.

| ID | Title | Priority | Status | Action |
|----|-------|----------|--------|--------|
| **SP2** | Add numeric-only pairing code input | high | READY | Execute now |
| **SP4** | Server-side numeric code generation | high | READY | Execute now (with rate limiting) |
| **SP1** | ~~Clipboard paste~~ → WatchConnectivity sync | medium | NEEDS REDESIGN | Defer to Phase 8 |
| **SP3** | Deep link URL scheme | low | DEFER | Not needed for MVP |
| **SP5** | QR URL hint | low | DEFER | Not needed for MVP |

### Research Insights for Each Task

#### SP2: Numeric Input (READY)
**Best Practice**: Use `TextField` with `.keyboardType(.numberPad)` - but watchOS doesn't have keyboard types. Use `TextFieldLink` (watchOS 10+) with custom input validation.

```swift
// Recommended implementation
TextFieldLink("Enter Code", prompt: Text("6-digit code")) {
    // On submit, validate and pair
}
.textContentType(.oneTimeCode)  // Helps with autofill
```

**Edge Cases**:
- Leading zeros must be preserved (e.g., "012345")
- Validate exactly 6 digits before submission
- Show inline error for invalid input

#### SP4: Server Numeric Codes (READY + SECURITY)
**Security Requirement**: Add rate limiting to prevent brute force.

```javascript
// Required additions to worker/src/index.js
const RATE_LIMIT = {
  maxAttempts: 5,
  windowMs: 15 * 60 * 1000  // 15 minutes
};

// Generate secure 6-digit code
const numericCode = crypto.getRandomValues(new Uint32Array(1))[0] % 1000000;
const paddedCode = numericCode.toString().padStart(6, '0');
```

**Rate Limiting Pattern** (via Cloudflare KV or Durable Objects):
```javascript
async function checkRateLimit(pairingId, env) {
  const key = `rate:${pairingId}`;
  const attempts = await env.RATE_LIMIT_KV.get(key) || 0;
  if (attempts >= RATE_LIMIT.maxAttempts) {
    return { blocked: true, retryAfter: RATE_LIMIT.windowMs };
  }
  await env.RATE_LIMIT_KV.put(key, attempts + 1, { expirationTtl: 900 });
  return { blocked: false };
}
```

#### SP1: Clipboard (NEEDS REDESIGN)
**Problem**: `UIPasteboard.general` is iOS-only. watchOS cannot access system clipboard.

**Alternative Approach**: Use WatchConnectivity to sync clipboard from paired iPhone.

```swift
// On iPhone (companion app needed)
func sendClipboardToWatch() {
    if let code = UIPasteboard.general.string {
        WCSession.default.sendMessage(["pairingCode": code], replyHandler: nil)
    }
}

// On watchOS
func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
    if let code = message["pairingCode"] as? String {
        self.pairingCode = code
    }
}
```

**This requires**:
- iPhone companion app (new project target)
- WatchConnectivity session setup
- User action on iPhone to share clipboard

**Recommendation**: Defer to Phase 8 after core pairing works.

#### SP3: Deep Links (DEFERRED)
**Implementation** (if needed later):

1. Add to `Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>claude-watch</string>
        </array>
    </dict>
</array>
```

2. Handle in SwiftUI:
```swift
.onOpenURL { url in
    if url.scheme == "claude-watch",
       let code = URLComponents(url: url, resolvingAgainstBaseURL: false)?
           .queryItems?.first(where: { $0.name == "code" })?.value {
        pairingCode = code
    }
}
```

**Why defer**: Requires QR code generation on server, adds complexity, and users still need to type or scan. Numeric input (SP2) is simpler.

### Parallel Group 7 (Revised): Execute Now
| ID | Title | Priority | Files |
|----|-------|----------|-------|
| **SP2** | Add numeric-only pairing code input | high | `ClaudeWatch/Views/PairingView.swift` |
| **SP4** | Server-side numeric code generation with rate limiting | high | `MCPServer/worker/src/index.js` |

### To Start Ralph on Seamless Pairing:
```bash
# Run Ralph loop (will execute SP2 and SP4)
./.claude/ralph/ralph.sh

# Or run single session
./.claude/ralph/ralph.sh --single
```

---

## Development Infrastructure: PreToolUse Hook Toggle

### Problem Statement

During development, the PreToolUse hooks that push notifications to the watch become a nuisance - every file edit triggers a notification flow. We need a way to toggle between:

- **DEV mode**: Hooks disabled, normal development workflow
- **TESTING mode**: Hooks enabled, testing actual notifications to watch

### Current State

The `.claude/settings.json` has PreToolUse hooks **disabled** (empty array):
```json
"PreToolUse": []
```

When enabled, the hook configuration would be:
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

### Solution: Environment-Based Toggle

Create a simple toggle script and environment variable approach.

#### Option A: Toggle Script (Recommended)

Create `.claude/hooks/toggle-watch-hooks.sh`:

```bash
#!/bin/bash
# Toggle PreToolUse hooks between DEV and TESTING modes

SETTINGS_FILE=".claude/settings.json"

# Check current state
current_state=$(jq -r '.hooks.PreToolUse | length' "$SETTINGS_FILE")

if [ "$current_state" -eq 0 ]; then
    echo "🔔 Enabling watch notification hooks (TESTING mode)..."
    jq '.hooks.PreToolUse = [
      {
        "matcher": "Bash|Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "python3 \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/watch-approval-cloud.py"
          }
        ]
      }
    ]' "$SETTINGS_FILE" > tmp.$$ && mv tmp.$$ "$SETTINGS_FILE"
    echo "✅ Hooks ENABLED - notifications will be sent to watch"
else
    echo "🔕 Disabling watch notification hooks (DEV mode)..."
    jq '.hooks.PreToolUse = []' "$SETTINGS_FILE" > tmp.$$ && mv tmp.$$ "$SETTINGS_FILE"
    echo "✅ Hooks DISABLED - normal development workflow"
fi
```

**Usage**:
```bash
# Toggle hooks on/off
./.claude/hooks/toggle-watch-hooks.sh

# Check current state
jq '.hooks.PreToolUse | length' .claude/settings.json
# 0 = DEV mode (disabled), 1 = TESTING mode (enabled)
```

#### Option B: Environment Variable in Hook Script

Modify `.claude/hooks/watch-approval-cloud.py` to check an environment variable:

```python
import os

# At the top of the script
if os.environ.get('CLAUDE_WATCH_DEV_MODE', '').lower() in ('1', 'true', 'yes'):
    # In dev mode, skip notification and auto-approve
    print('{"decision": "approve", "reason": "DEV_MODE: auto-approved"}')
    sys.exit(0)

# ... rest of the hook logic
```

**Usage**:
```bash
# Enable dev mode (skip notifications)
export CLAUDE_WATCH_DEV_MODE=1

# Disable dev mode (send notifications)
unset CLAUDE_WATCH_DEV_MODE
```

#### Option C: Dotfile Toggle

Check for a dotfile that controls behavior:

```python
# In watch-approval-cloud.py
from pathlib import Path

dev_mode_file = Path.home() / '.claude-watch-dev-mode'
if dev_mode_file.exists():
    print('{"decision": "approve", "reason": "DEV_MODE file present"}')
    sys.exit(0)
```

**Usage**:
```bash
# Enable dev mode
touch ~/.claude-watch-dev-mode

# Disable dev mode (enable notifications)
rm ~/.claude-watch-dev-mode
```

### Recommended Approach

Use **Option A (Toggle Script)** for these reasons:
1. Explicit state change with clear feedback
2. No hidden environment variables to forget
3. Settings file shows current state
4. Works across terminal sessions

### Implementation Task

Add to Phase 8 (Infrastructure):
| ID | Title | Priority | Files |
|----|-------|----------|-------|
| **INF1** | Create PreToolUse hook toggle script | low | `.claude/hooks/toggle-watch-hooks.sh` |

---

## Later Priority: APNs Setup (Manual Action Required)

From [plans/feat-apns-and-hooks-setup.md](/plans/feat-apns-and-hooks-setup.md).

**Status**: Code complete, requires manual configuration

### Manual Steps (User Must Do):
1. **Apple Developer Portal**: Create APNs key at https://developer.apple.com/account/resources/authkeys/list
2. **Cloudflare Secrets**: Set `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`
3. **Deploy Worker**: `cd MCPServer/worker && npx wrangler deploy`
4. **Test**: `curl -X POST https://claude-watch.fotescodev.workers.dev/request ...`

### Verification Checklist:
- [ ] APNs key created in Apple Developer Portal
- [ ] Cloudflare secrets configured
- [ ] Worker deployed
- [ ] Test request returns `apnsSent: true`
- [ ] Physical watch receives push notification

---

## Infrastructure Todo Issues (Historical)

The following `/todos/` files were created during debugging. Most are now resolved:

| File | Status | Notes |
|------|--------|-------|
| `001-pending-p1-state-consistency-violation.md` | Resolved | state-manager.sh exists |
| `002-pending-p1-metrics-updated-before-verification.md` | Resolved | Validation order fixed |
| `003-pending-p1-agent-enters-plan-mode.md` | Resolved | PROMPT.md is action-oriented |
| `004-pending-p1-git-diff-counts-docs-as-code.md` | Resolved | git_has_code_changes scoped |
| `005-pending-p1-task-verification-never-executed.md` | Resolved | run_task_verification exists |
| `006-pending-p1-ralph-lg1-lg2-t1-failures.md` | Resolved | Tasks completed |
| `007-pending-p2-impossible-task-definitions.md` | Resolved | Task definitions fixed |
| `008-pending-p0-ralph-failure-root-cause-analysis.md` | Reference | Comprehensive analysis doc |

---

## Monitoring Ralph

```bash
# Watch Ralph progress in real-time
./.claude/ralph/monitor-ralph.sh

# Check task status
./.claude/ralph/state-manager.sh list

# View metrics
jq . .claude/ralph/metrics.json

# Run single task for testing
./.claude/ralph/ralph.sh --single
```

---

## References

- [APNs Setup Plan](/plans/feat-apns-and-hooks-setup.md)
- [Ralph Tasks YAML](/.claude/ralph/tasks.yaml)
- [Generated Task List](/.claude/ralph/ralph-context-docs/TASKS.md)
- [Root Cause Analysis](/todos/008-pending-p0-ralph-failure-root-cause-analysis.md)
