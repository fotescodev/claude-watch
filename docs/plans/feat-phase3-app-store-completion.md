# feat: Complete Phase 3 and App Store Submission (Revised)

**Type**: Enhancement
**Priority**: P0 - Critical Path to Launch
**Estimated Changes**: ~50 lines of code

---

## Overview

Complete the remaining Phase 3 work for Claude Watch App Store submission. Based on code review, most infrastructure already exists:

| Feature | Status | Work Needed |
|---------|--------|-------------|
| APNs Push | ✅ Implemented | Configure credentials, add error handling |
| Complications UI | ✅ Implemented | Connect to live data (~15 lines) |
| Voice Commands | ✅ Implemented | Add "sent" feedback (~10 lines) |
| Settings UI | ✅ Implemented | Add version/privacy links (~5 lines) |
| App Store Assets | ❌ Missing | Screenshots, metadata, privacy policy |

**Key Insight**: The Cloudflare Worker at `MCPServer/worker/src/index.js` already has full APNs implementation (lines 24-104). We don't need to build it—we need to configure and harden it.

---

## Phase 1: APNs Configuration & Security Hardening

**Goal**: Make existing APNs work end-to-end with proper error handling

### Task 1.1: Configure APNs Credentials

The Worker already supports APNs via environment variables. Configure them:

```bash
# In Apple Developer Portal:
# 1. Create APNs Key (Keys > Create Key > Apple Push Notifications service)
# 2. Download .p8 file
# 3. Note Key ID (10 characters)

# Encode key for Cloudflare:
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy

# Set Cloudflare secrets:
cd MCPServer/worker
wrangler secret put APNS_PRIVATE_KEY  # Paste encoded key
```

**In `wrangler.toml`** (add if not present):
```toml
[vars]
APNS_KEY_ID = "YOUR_KEY_ID"
APNS_TEAM_ID = "YOUR_TEAM_ID"
APNS_BUNDLE_ID = "com.yourcompany.ClaudeWatch"
```

### Task 1.2: Add APNs Error Handling

**File**: `MCPServer/worker/src/index.js`

Current code returns `{ success: response.ok }` but ignores error details. Add handling for token invalidation:

```javascript
// MCPServer/worker/src/index.js - Replace lines 65-69

    const responseBody = await response.text();

    if (response.ok) {
      return { success: true };
    }

    // Handle specific APNs errors
    const errorData = responseBody ? JSON.parse(responseBody) : {};
    const reason = errorData.reason || 'Unknown';

    if (reason === 'BadDeviceToken' || reason === 'Unregistered') {
      // Token is invalid - should clear from storage
      return { success: false, error: reason, shouldClearToken: true };
    }

    if (reason === 'TooManyRequests') {
      // Rate limited - caller should retry with backoff
      return { success: false, error: reason, retryAfter: response.headers.get('Retry-After') };
    }

    return { success: false, error: reason, status: response.status };
  } catch (error) {
    console.error('APNs error:', error);
    return { success: false, error: error.message };
  }
```

### Task 1.3: Add Authentication to /respond Endpoint

**Security Issue**: Anyone who guesses a requestId can approve actions.

**File**: `MCPServer/worker/src/index.js` - Modify `/respond/:id` handler (lines 327-357)

```javascript
      // POST /respond/:id - Watch sends response
      if (path.startsWith('/respond/') && request.method === 'POST') {
        const requestId = path.split('/')[2];
        const { approved, pairingId } = await request.json();  // Add pairingId

        if (typeof approved !== 'boolean') {
          return jsonResponse({ error: 'Missing approved field' }, 400);
        }

        // NEW: Verify pairingId is required
        if (!pairingId) {
          return jsonResponse({ error: 'Missing pairingId' }, 400);
        }

        const requestData = await env.REQUESTS.get(`request:${requestId}`);
        if (!requestData) {
          return jsonResponse({ error: 'Request not found or expired' }, 404);
        }

        const approvalRequest = JSON.parse(requestData);

        // NEW: Verify the responder owns this request
        if (approvalRequest.pairingId !== pairingId) {
          return jsonResponse({ error: 'Unauthorized' }, 403);
        }

        // ... rest of handler unchanged
```

### Task 1.4: Restrict CORS

**File**: `MCPServer/worker/src/index.js` - lines 107-111

```javascript
// Replace overly permissive CORS
const corsHeaders = {
  'Access-Control-Allow-Origin': 'null',  // Native apps send 'null' origin
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};
```

### Task 1.5: Update Watch to Send pairingId with Responses

**File**: `ClaudeWatch/Services/WatchService.swift` - in `respondToAction()` method

```swift
// When sending approval response, include pairingId
let body: [String: Any] = [
    "approved": approved,
    "pairingId": self.pairingId ?? ""  // Add this line
]
```

**Acceptance Criteria**:
- [ ] APNs credentials configured in Cloudflare
- [ ] Push notification received on physical watch within 2 seconds
- [ ] BadDeviceToken errors trigger token cleanup
- [ ] /respond requires matching pairingId

**Test**:
```bash
# Verify APNs config
curl https://your-worker.workers.dev/health

# Create test request (should send push)
curl -X POST https://your-worker.workers.dev/request \
  -H "Content-Type: application/json" \
  -d '{"pairingId":"YOUR_PAIRING_ID","type":"file_edit","title":"Test Push"}'
```

---

## Phase 2: Complications Live Data (~15 lines)

**Goal**: Connect existing complication UI to real data from WatchService

### Task 2.1: Add App Group Capability

**In Xcode**:
1. Select ClaudeWatch target → Signing & Capabilities
2. Click "+ Capability" → App Groups
3. Create: `group.com.yourcompany.claudewatch`

### Task 2.2: Write State to Shared Defaults

**File**: `ClaudeWatch/Services/WatchService.swift`

Add property and update method:

```swift
// Add near other private properties (around line 30)
private let sharedDefaults = UserDefaults(suiteName: "group.com.yourcompany.claudewatch")

// Add this method
private func updateComplicationData() {
    sharedDefaults?.set(state.pendingActions.count, forKey: "pendingCount")
    sharedDefaults?.set(state.progress, forKey: "progress")
    sharedDefaults?.set(state.taskName, forKey: "taskName")
    sharedDefaults?.set(state.model, forKey: "model")
    sharedDefaults?.set(connectionStatus == .connected, forKey: "isConnected")

    WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeWatchWidget")
}
```

Call `updateComplicationData()` at the end of:
- `handleStateSync()`
- `handleActionRequested()`
- `handleProgressUpdate()`
- `handleConnectionStatusChange()`

### Task 2.3: Read from Shared Defaults in Provider

**File**: `ClaudeWatch/Complications/ComplicationViews.swift`

Replace the `ClaudeProvider` (lines 15-52) with:

```swift
struct ClaudeProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.yourcompany.claudewatch")

    func placeholder(in context: Context) -> ClaudeEntry {
        ClaudeEntry(date: .now, taskName: "Claude", progress: 0.5, pendingCount: 0, model: "opus", isConnected: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeEntry>) -> Void) {
        let timeline = Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(900)))
        completion(timeline)
    }

    private func currentEntry() -> ClaudeEntry {
        ClaudeEntry(
            date: .now,
            taskName: defaults?.string(forKey: "taskName") ?? "Claude",
            progress: defaults?.double(forKey: "progress") ?? 0,
            pendingCount: defaults?.integer(forKey: "pendingCount") ?? 0,
            model: defaults?.string(forKey: "model") ?? "opus",
            isConnected: defaults?.bool(forKey: "isConnected") ?? false
        )
    }
}
```

**Acceptance Criteria**:
- [ ] Complication shows real pending count
- [ ] Complication updates when action arrives (via `reloadTimelines`)
- [ ] Progress reflects actual task progress

---

## Phase 3: Voice Command Feedback (~10 lines)

**Goal**: Show "Sent" confirmation after voice command

The existing `sendPrompt()` method works. Just add visual feedback.

### Task 3.1: Add Sending State

**File**: `ClaudeWatch/Services/WatchService.swift`

```swift
// Add published property (near other @Published vars)
@Published var isSendingPrompt = false
```

Update `sendPrompt()`:

```swift
func sendPrompt(_ text: String) async {
    isSendingPrompt = true
    defer { isSendingPrompt = false }

    // ... existing implementation

    WKInterfaceDevice.current().play(.success)  // Add haptic on success
}
```

### Task 3.2: Show Status in Voice Input Sheet

**File**: `ClaudeWatch/Views/MainView.swift` - in `VoiceInputSheet`

Add after the TextField:

```swift
if service.isSendingPrompt {
    HStack {
        ProgressView()
        Text("Sending...")
            .font(.caption)
    }
} else if showSentConfirmation {
    HStack {
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        Text("Sent")
            .font(.caption)
    }
}
```

Add state: `@State private var showSentConfirmation = false`

After successful send:
```swift
showSentConfirmation = true
try? await Task.sleep(nanoseconds: 1_000_000_000)
dismiss()
```

**Acceptance Criteria**:
- [ ] "Sending..." shown during send
- [ ] "Sent" with checkmark shown for 1 second
- [ ] Success haptic on completion

---

## Phase 4: Settings & App Store Submission

### Task 4.1: Add Version and Privacy Links

**File**: `ClaudeWatch/Views/MainView.swift` - in `SettingsSheet`

Add to the settings list:

```swift
Section("About") {
    LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")

    Link(destination: URL(string: "https://yoursite.com/claude-watch/privacy")!) {
        Label("Privacy Policy", systemImage: "hand.raised")
    }

    Link(destination: URL(string: "https://yoursite.com/claude-watch/support")!) {
        Label("Support", systemImage: "questionmark.circle")
    }
}
```

### Task 4.2: Create Privacy Policy

Host at `https://yoursite.com/claude-watch/privacy`:

```
Claude Watch Privacy Policy

Data Collected:
- Device token: For push notifications
- Pairing ID: To associate watch with Claude Code session
- Action metadata: Type, title, file path (no file contents)

Data NOT Collected:
- File contents or code
- Personal information
- Analytics or tracking

Data is transmitted to Cloudflare edge servers and retained temporarily (10 minutes max).

Contact: privacy@yoursite.com
```

### Task 4.3: Capture Screenshots

Required sizes:
- 45mm: 396 x 484 px
- 41mm: 352 x 430 px

Scenes to capture:
1. Main view with 2-3 pending actions
2. Empty state ("All Clear")
3. Settings view
4. Complication on watch face

### Task 4.4: App Store Metadata

**Name**: Claude Watch
**Subtitle**: Approve AI code changes from your wrist
**Category**: Developer Tools
**Keywords**: claude, code, ai, developer, approval, automation

**Description**:
```
Claude Watch brings Claude Code approvals to your Apple Watch.

• Instant notifications for code changes
• Approve or reject with one tap
• Monitor progress from your wrist
• Watch face complications

Requires Claude Code CLI with cloud relay.
```

### Task 4.5: Submit

1. Archive in Xcode (Product → Archive)
2. Upload to App Store Connect
3. TestFlight for 1 week
4. Submit for review

**Acceptance Criteria**:
- [ ] Settings shows version and privacy link
- [ ] Privacy policy hosted and accessible
- [ ] Screenshots for all required sizes
- [ ] App Store listing complete
- [ ] TestFlight build distributed

---

## Test Specifications

### APNs Tests (Manual)

| Test | Steps | Expected |
|------|-------|----------|
| Push delivery | Create request via API | Watch receives push < 2s |
| Approve from notification | Tap Approve action | Request status = approved |
| Reject from notification | Tap Reject action | Request status = rejected |
| Invalid token handling | Use fake token | `shouldClearToken: true` in response |

### Complication Tests (Manual)

| Test | Steps | Expected |
|------|-------|----------|
| Shows pending count | Create 3 requests | Complication shows "3" |
| Updates on change | Approve one request | Count decreases to 2 |
| Shows progress | Start task at 50% | Progress ring at 50% |

### Voice Command Tests (Manual)

| Test | Steps | Expected |
|------|-------|----------|
| Shows sending | Tap mic, speak | "Sending..." visible |
| Shows sent | Command completes | Checkmark + "Sent" for 1s |
| Haptic feedback | Command completes | Success haptic fires |

### Security Tests

| Test | Steps | Expected |
|------|-------|----------|
| Respond without pairingId | POST /respond with no pairingId | 400 error |
| Respond with wrong pairingId | POST /respond with different pairingId | 403 error |
| CORS blocked | Fetch from random domain | Request blocked |

---

## Error Handling Matrix

| Error | User Message | Recovery |
|-------|--------------|----------|
| APNs BadDeviceToken | "Please re-pair your watch" | Clear pairing, show pairing flow |
| APNs Unregistered | "Please re-pair your watch" | Clear pairing, show pairing flow |
| APNs TooManyRequests | (silent retry) | Exponential backoff |
| Network timeout | "Connection failed" | Auto-retry with backoff |
| Invalid pairing code | "Code expired or invalid" | Clear input, prompt new code |
| Unauthorized respond | (should not happen) | Log error, ignore |

---

## Security Checklist

- [ ] APNs key stored in Cloudflare secrets (not env vars in code)
- [ ] `/respond` requires pairingId verification
- [ ] CORS restricted to native app origin
- [ ] Request IDs are short-lived (10 min TTL)
- [ ] No sensitive code content transmitted

---

## Summary of Changes

| File | Lines Changed | Description |
|------|---------------|-------------|
| `MCPServer/worker/src/index.js` | +25 | APNs error handling, auth on /respond |
| `ClaudeWatch/Services/WatchService.swift` | +15 | Complication data writes, prompt state |
| `ClaudeWatch/Complications/ComplicationViews.swift` | +20 (replace) | Read from shared defaults |
| `ClaudeWatch/Views/MainView.swift` | +15 | Voice feedback UI, settings links |

**Total new code: ~75 lines** (down from 500+ in original plan)

---

## What Was Removed from Original Plan

| Removed | Reason |
|---------|--------|
| Phase 1 APNs rebuild | Already exists in Worker |
| APNsClient class | Duplicate of existing sendAPNs() |
| JWT helper functions | Already implemented |
| CommandStatus 6-state enum | Overkill - boolean sufficient |
| /command endpoint | Not needed - WebSocket handles prompts |
| Command queue system | Over-engineered |
| App Groups complexity | Simplified to basic UserDefaults |
| Setup scripts | README documentation sufficient |
| Future Considerations section | Either in scope or not |
| Risk Analysis table | Adds no value |

---

*Revised based on feedback from DHH, Kieran, and Simplicity reviewers.*
