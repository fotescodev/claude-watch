# ClaudeWatch Task Breakdown for Autonomous Execution

> **Last Updated:** Post-merge audit (January 2026)
> **Purpose:** Structured tasks for agentic loop execution
> **Total Estimated Time:** 10-12 hours to App Store submission

---

## Task Index

| ID | Task | Priority | Est. Time | Dependencies |
|----|------|----------|-----------|--------------|
| C1 | Replace deprecated WKExtension.shared() | CRITICAL | 15min | None |
| C2 | Replace deprecated presentTextInputController | CRITICAL | 30min | None |
| C3 | Add accessibility labels | CRITICAL | 45min | None |
| C4 | Configure APNs credentials | CRITICAL | 30min | None |
| H1 | Fix text sizes below 11pt | HIGH | 30min | None |
| H2 | Add App Groups and wire complication data | HIGH | 45min | None |
| H3 | Add APNs error handling | HIGH | 30min | None |
| H4 | Add pairingId auth to /respond endpoint | HIGH | 20min | None |
| M1 | Add voice command "Sent" feedback | MEDIUM | 20min | None |
| M2 | Add version/privacy links to settings | MEDIUM | 15min | None |
| M3 | Add Digital Crown support | MEDIUM | 20min | None |
| M4 | Add Always-On Display handling | MEDIUM | 30min | None |
| M5 | Add Dynamic Type support | MEDIUM | 1hr | None |

---

## CRITICAL TASKS (Blocks App Store)

### C1: Replace Deprecated WKExtension.shared()

**File:** `ClaudeWatch/App/ClaudeWatchApp.swift`
**Line:** 68

#### Current Code
```swift
WKExtension.shared().registerForRemoteNotifications()
```

#### Target Code
```swift
WKApplication.shared().registerForRemoteNotifications()
```

#### Acceptance Criteria
- [ ] No references to `WKExtension` in codebase
- [ ] App compiles without WKExtension deprecation warnings
- [ ] Push notification registration still works

#### Definition of Done
1. `grep -r "WKExtension" ClaudeWatch/` returns no results
2. App launches without crash on watchOS 11+ simulator

#### Verification Command
```bash
grep -r "WKExtension" ClaudeWatch/ && echo "FAIL: WKExtension found" || echo "PASS"
```

---

### C2: Replace Deprecated presentTextInputController

**File:** `ClaudeWatch/Views/MainView.swift`
**Lines:** 887-897

#### Current Code
```swift
WKExtension.shared().visibleInterfaceController?.presentTextInputController(
    withSuggestions: suggestions,
    allowedInputMode: .plain
) { results in
    // ...
}
```

#### Target Code
Replace with SwiftUI TextField in VoiceInputSheet (already exists, just remove the deprecated call):
```swift
// Remove the entire presentTextInputController block
// The existing TextField in VoiceInputSheet handles text input
```

#### Acceptance Criteria
- [ ] No references to `presentTextInputController` in codebase
- [ ] No references to `visibleInterfaceController` in codebase
- [ ] Voice input sheet still works with TextField

#### Definition of Done
1. `grep -r "presentTextInputController" ClaudeWatch/` returns no results
2. VoiceInputSheet opens and accepts text input

#### Verification Command
```bash
grep -r "presentTextInputController\|visibleInterfaceController" ClaudeWatch/ && echo "FAIL" || echo "PASS"
```

---

### C3: Add Accessibility Labels

**File:** `ClaudeWatch/Views/MainView.swift`

#### Elements Requiring Labels

| Element | Location | Label | Hint |
|---------|----------|-------|------|
| Settings button | ~line 58 | "Settings" | "Opens server configuration" |
| Approve button | ~line 493 | "Approve" | "Approves this action" |
| Reject button | ~line 520 | "Reject" | "Rejects this action" |
| Approve All button | ~line 450 | "Approve All" | "Approves all pending actions" |
| Voice Command button | ~line 646 | "Voice Command" | "Opens voice input" |
| Mode Selector | ~line 713 | "Mode: {current}" | "Tap to switch to {next} mode" |

#### Code to Add

```swift
// Settings button
.accessibilityLabel("Settings")
.accessibilityHint("Opens server configuration")

// Approve button (in ActionCard/PrimaryActionCard)
.accessibilityLabel("Approve")
.accessibilityHint("Approves \(action.title)")

// Reject button
.accessibilityLabel("Reject")
.accessibilityHint("Rejects \(action.title)")

// Approve All button
.accessibilityLabel("Approve All")
.accessibilityHint("Approves all \(pendingCount) pending actions")

// Voice Command button
.accessibilityLabel("Voice Command")
.accessibilityHint("Opens voice input to send a command")

// Mode Selector
.accessibilityLabel("Current mode: \(mode.displayName)")
.accessibilityHint("Tap to switch to \(mode.next.displayName) mode")
```

#### Acceptance Criteria
- [ ] All 6 interactive elements have accessibilityLabel
- [ ] All 6 interactive elements have accessibilityHint
- [ ] VoiceOver can navigate all buttons

#### Definition of Done
1. `grep -c "accessibilityLabel" ClaudeWatch/Views/MainView.swift` returns 6+
2. VoiceOver testing passes on simulator

#### Verification Command
```bash
count=$(grep -c "accessibilityLabel" ClaudeWatch/Views/MainView.swift); test $count -ge 6 && echo "PASS: $count labels" || echo "FAIL: only $count labels"
```

---

### C4: Configure APNs Credentials

**Location:** Cloudflare Worker configuration
**File:** `MCPServer/worker/wrangler.toml`

#### Steps

1. In Apple Developer Portal:
   - Create APNs Key (Keys → Create Key → Apple Push Notifications service)
   - Download .p8 file
   - Note Key ID (10 characters)

2. Encode key for Cloudflare:
```bash
base64 -i AuthKey_XXXXXXXXXX.p8 | tr -d '\n' | pbcopy
```

3. Set Cloudflare secrets:
```bash
cd MCPServer/worker
wrangler secret put APNS_PRIVATE_KEY  # Paste encoded key
```

4. Update wrangler.toml:
```toml
[vars]
APNS_KEY_ID = "YOUR_KEY_ID"
APNS_TEAM_ID = "YOUR_TEAM_ID"
APNS_BUNDLE_ID = "com.yourcompany.ClaudeWatch"
```

#### Acceptance Criteria
- [ ] APNs key uploaded to Cloudflare secrets
- [ ] wrangler.toml has APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID
- [ ] Push notification received on physical watch

#### Definition of Done
1. `curl https://your-worker.workers.dev/health` returns success
2. Test push delivered within 2 seconds

#### Verification Command
```bash
grep -q "APNS_KEY_ID" MCPServer/worker/wrangler.toml && echo "PASS" || echo "FAIL: APNs not configured"
```

---

## HIGH PRIORITY TASKS

### H1: Fix Text Sizes Below 11pt

**Files:**
- `ClaudeWatch/Views/MainView.swift`
- `ClaudeWatch/Complications/ComplicationViews.swift`

#### Violations Found (10 total)

| File | Current | Replace With |
|------|---------|--------------|
| MainView.swift | `.system(size: 10)` (3×) | `.caption2` or `.system(size: 11)` |
| ComplicationViews.swift | `.system(size: 8)` (1×) | `.system(size: 11)` |
| ComplicationViews.swift | `.system(size: 9)` (3×) | `.system(size: 11)` |
| ComplicationViews.swift | `.system(size: 10)` (3×) | `.system(size: 11)` |

#### Acceptance Criteria
- [ ] No font sizes below 11pt in codebase
- [ ] Text remains readable on 40mm watch

#### Verification Command
```bash
grep -E "size:\s*[89]|size:\s*10[^0-9]" ClaudeWatch/ -r && echo "FAIL" || echo "PASS"
```

---

### H2: Add App Groups and Wire Complication Data

**Files:**
- `ClaudeWatch/Services/WatchService.swift`
- `ClaudeWatch/Complications/ComplicationViews.swift`
- Xcode project capabilities

#### Step 1: Add App Group Capability (in Xcode)
1. Select ClaudeWatch target → Signing & Capabilities
2. Click "+ Capability" → App Groups
3. Add: `group.com.claudewatch`

#### Step 2: Update WatchService.swift

Add near line 35:
```swift
private let sharedDefaults = UserDefaults(suiteName: "group.com.claudewatch")

private func updateComplicationData() {
    sharedDefaults?.set(state.pendingActions.count, forKey: "pendingCount")
    sharedDefaults?.set(state.progress, forKey: "progress")
    sharedDefaults?.set(state.taskName, forKey: "taskName")
    sharedDefaults?.set(state.model, forKey: "model")
    sharedDefaults?.set(connectionStatus == .connected, forKey: "isConnected")

    WidgetCenter.shared.reloadTimelines(ofKind: "ClaudeWatchWidget")
}
```

Call `updateComplicationData()` in:
- `updateState(from:)`
- After connection status changes

#### Step 3: Update ComplicationViews.swift

Replace ClaudeProvider (lines 15-52):
```swift
struct ClaudeProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.claudewatch")

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

#### Acceptance Criteria
- [ ] App Group capability added in Xcode
- [ ] WatchService writes to shared defaults
- [ ] Complications read from shared defaults
- [ ] Complication updates when state changes

#### Verification Command
```bash
grep -q "group.com.claudewatch" ClaudeWatch/Services/WatchService.swift && echo "PASS" || echo "FAIL"
```

---

### H3: Add APNs Error Handling

**File:** `MCPServer/worker/src/index.js`
**Location:** Replace lines 65-69

#### Current Code
```javascript
return { success: response.ok };
```

#### Target Code
```javascript
const responseBody = await response.text();

if (response.ok) {
  return { success: true };
}

// Handle specific APNs errors
const errorData = responseBody ? JSON.parse(responseBody) : {};
const reason = errorData.reason || 'Unknown';

if (reason === 'BadDeviceToken' || reason === 'Unregistered') {
  return { success: false, error: reason, shouldClearToken: true };
}

if (reason === 'TooManyRequests') {
  return { success: false, error: reason, retryAfter: response.headers.get('Retry-After') };
}

return { success: false, error: reason, status: response.status };
```

#### Acceptance Criteria
- [ ] BadDeviceToken returns `shouldClearToken: true`
- [ ] TooManyRequests returns `retryAfter` header
- [ ] Other errors return status code

#### Verification Command
```bash
grep -q "shouldClearToken" MCPServer/worker/src/index.js && echo "PASS" || echo "FAIL"
```

---

### H4: Add pairingId Auth to /respond Endpoint

**File:** `MCPServer/worker/src/index.js`
**Location:** /respond/:id handler (around line 327)

#### Code to Add

After parsing request body, add:
```javascript
// Verify pairingId is required
if (!pairingId) {
  return jsonResponse({ error: 'Missing pairingId' }, 400);
}

const requestData = await env.REQUESTS.get(`request:${requestId}`);
if (!requestData) {
  return jsonResponse({ error: 'Request not found or expired' }, 404);
}

const approvalRequest = JSON.parse(requestData);

// Verify the responder owns this request
if (approvalRequest.pairingId !== pairingId) {
  return jsonResponse({ error: 'Unauthorized' }, 403);
}
```

#### Also Update Watch to Send pairingId

**File:** `ClaudeWatch/Services/WatchService.swift`

In cloud response method, include pairingId:
```swift
let body: [String: Any] = [
    "approved": approved,
    "pairingId": self.pairingId ?? ""
]
```

#### Acceptance Criteria
- [ ] /respond returns 400 if no pairingId
- [ ] /respond returns 403 if wrong pairingId
- [ ] Watch sends pairingId with responses

#### Verification Command
```bash
grep -q "Unauthorized" MCPServer/worker/src/index.js && echo "PASS" || echo "FAIL"
```

---

## MEDIUM PRIORITY TASKS

### M1: Add Voice Command "Sent" Feedback

**File:** `ClaudeWatch/Views/MainView.swift`

#### Changes

1. Add state in VoiceInputSheet:
```swift
@State private var showSentConfirmation = false
```

2. Add UI after TextField:
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

3. After successful send:
```swift
showSentConfirmation = true
WKInterfaceDevice.current().play(.success)
try? await Task.sleep(nanoseconds: 1_000_000_000)
dismiss()
```

#### Acceptance Criteria
- [ ] "Sending..." shown during send
- [ ] "Sent" with checkmark shown for 1 second
- [ ] Success haptic on completion

---

### M2: Add Version/Privacy Links to Settings

**File:** `ClaudeWatch/Views/MainView.swift`
**Location:** SettingsSheet

#### Code to Add
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

#### Acceptance Criteria
- [ ] Version number displayed
- [ ] Privacy Policy link works
- [ ] Support link works

---

### M3: Add Digital Crown Support

**File:** `ClaudeWatch/Views/MainView.swift`

#### Code to Add

On ScrollView containing action list:
```swift
ScrollView {
    // content
}
.digitalCrownRotation($scrollPosition)
```

Or for focus-based navigation:
```swift
.focusable(true)
.digitalCrownRotation(detent: $selectedIndex, from: 0, through: actions.count - 1)
```

#### Acceptance Criteria
- [ ] Digital Crown scrolls action list
- [ ] Rotation feels natural

---

### M4: Add Always-On Display Handling

**Files:**
- `ClaudeWatch/Views/MainView.swift`
- `ClaudeWatch/Complications/ComplicationViews.swift`

#### Code to Add

```swift
@Environment(\.isLuminanceReduced) var isLuminanceReduced

var body: some View {
    content
        .opacity(isLuminanceReduced ? 0.6 : 1.0)
        .animation(.easeInOut, value: isLuminanceReduced)
}
```

For complications, reduce to monochrome in always-on:
```swift
if isLuminanceReduced {
    Circle().stroke(Color.white, lineWidth: 2)
} else {
    Circle().stroke(Color.green, lineWidth: 4)
}
```

#### Acceptance Criteria
- [ ] UI dims in always-on mode
- [ ] Complications use minimal colors in always-on

---

### M5: Add Dynamic Type Support

**Files:** `ClaudeWatch/Views/MainView.swift`

#### Replace hardcoded sizes with semantic styles:

| Current | Replace With |
|---------|--------------|
| `.system(size: 10)` | `.caption2` |
| `.system(size: 11)` | `.caption` |
| `.system(size: 12)` | `.footnote` |
| `.system(size: 14)` | `.subheadline` |
| `.system(size: 16)` | `.body` |
| `.system(size: 18)` | `.headline` |
| `.system(size: 20)` | `.title3` |

#### Acceptance Criteria
- [ ] All text uses semantic styles
- [ ] Text scales with accessibility settings

---

## Execution Order

```
Phase 1: Critical (Parallel)
├── C1: Replace WKExtension ─────────┐
├── C2: Replace text input ──────────┼── Run in parallel
├── C3: Add accessibility ───────────┤
└── C4: Configure APNs ──────────────┘

Phase 2: High Priority (Parallel)
├── H1: Fix text sizes ──────────────┐
├── H2: App Groups + complications ──┼── Run in parallel
├── H3: APNs error handling ─────────┤
└── H4: Auth on /respond ────────────┘

Phase 3: Medium Priority (Parallel)
├── M1: Voice feedback ──────────────┐
├── M2: Settings links ──────────────┼── Run in parallel
├── M3: Digital Crown ───────────────┤
├── M4: Always-On Display ───────────┤
└── M5: Dynamic Type ────────────────┘

Phase 4: App Store Submission
├── Create privacy policy
├── Capture screenshots
├── Write App Store metadata
├── TestFlight beta
└── Submit for review
```

---

## Agent Execution Notes

### For Each Task:
1. Read the task completely
2. Make changes to specified files
3. Run verification command
4. Commit with message: `fix(CX): <description>` or `feat(HX): <description>`

### Success Criteria:
- Verification command returns "PASS"
- No compiler errors
- No new warnings

### Commit Format:
```
fix(C1): Replace deprecated WKExtension.shared() with WKApplication
fix(C2): Remove deprecated presentTextInputController
feat(C3): Add accessibility labels to all interactive elements
chore(C4): Configure APNs credentials in Cloudflare
fix(H1): Increase text sizes to meet 11pt minimum
feat(H2): Wire complications to live data via App Groups
feat(H3): Add APNs error handling for token invalidation
feat(H4): Add pairingId authentication to /respond endpoint
feat(M1): Add voice command "Sent" feedback
feat(M2): Add version and privacy links to settings
feat(M3): Add Digital Crown navigation support
feat(M4): Add Always-On Display handling
feat(M5): Migrate to Dynamic Type semantic styles
```
