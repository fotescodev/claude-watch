# Fix: Reverse Pairing Flow Direction

> **Status:** Ready to Implement
> **Date:** 2026-01-18
> **Priority:** CRITICAL - Blocks testing
> **Scope:** Watch app, CLI, Cloud Worker

---

## Problem Statement

The pairing flow direction is **inverted** from what was agreed:

| Component | Current Behavior | Desired Behavior |
|-----------|------------------|------------------|
| CLI (npm) | Generates & displays code | Accepts code input from user |
| Watch | User enters code | Generates & displays code |
| Cloud | Watch calls `/pair/complete` | CLI calls `/pair/complete` |

**Result:** Watch is waiting for user to enter a code, but CLI is displaying a code. User experience is broken.

---

## Solution Overview

Reverse the flow so:
1. **Watch** generates and displays a 6-digit code
2. **User** reads code from watch, types into CLI
3. **CLI** sends code to cloud to complete pairing

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────┐
│   Watch     │     │  Cloud Worker    │     │    CLI      │
└──────┬──────┘     └────────┬─────────┘     └──────┬──────┘
       │                     │                      │
       │ POST /pair/initiate │                      │
       │ { deviceToken }     │                      │
       │────────────────────>│                      │
       │                     │ Generate code        │
       │<────────────────────│ Store session        │
       │ { code, watchId }   │                      │
       │                     │                      │
       │ DISPLAY CODE        │                      │
       │ "Enter in terminal: │                      │
       │  4 7 2 9 1 3"       │                      │
       │                     │                      │
       │                     │  User types code     │
       │                     │                      │
       │                     │ POST /pair/complete  │
       │                     │<─────────────────────│
       │                     │ { code }             │
       │                     │                      │
       │                     │ Mark paired          │
       │                     │─────────────────────>│
       │                     │ { pairingId }        │
       │                     │                      │
       │ GET /pair/status    │                      │
       │────────────────────>│                      │
       │<────────────────────│                      │
       │ { paired, pairingId }                      │
       │                     │                      │
       ▼                     ▼                      ▼
    PAIRED               RELAY                  PAIRED
```

---

## Implementation Phases

### Phase 1: Cloud Worker Changes (30 min)

**File:** `claude-watch-cloud/src/index.ts`

#### 1.1 Add `/pair/initiate` endpoint (Watch requests code)

```typescript
// Watch requests a code to display
app.post('/pair/initiate', async (c) => {
  const { deviceToken } = await c.req.json<{ deviceToken: string }>();

  // Generate code (6 digits)
  const code = Array.from({ length: 6 }, () =>
    Math.floor(Math.random() * 10)
  ).join('');

  const watchId = crypto.randomUUID();

  const session: PairingSession = {
    code,
    watchId,
    deviceToken,
    createdAt: new Date().toISOString(),
    paired: false,
    pairingId: null,
  };

  // Store by code for CLI lookup
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), {
    expirationTtl: 300 // 5 minutes
  });

  // Store by watchId for watch polling
  await c.env.PAIRING_KV.put(`watch:${watchId}`, JSON.stringify(session), {
    expirationTtl: 300
  });

  return c.json({ code, watchId });
});
```

#### 1.2 Add `/pair/status/:watchId` endpoint (Watch polls for completion)

```typescript
// Watch polls to check if CLI completed pairing
app.get('/pair/status/:watchId', async (c) => {
  const watchId = c.req.param('watchId');

  const session = await c.env.PAIRING_KV.get<PairingSession>(`watch:${watchId}`, 'json');

  if (!session) {
    return c.json({ expired: true });
  }

  return c.json({
    paired: session.paired,
    pairingId: session.pairingId,
  });
});
```

#### 1.3 Modify `/pair/complete` endpoint (CLI enters code)

```typescript
// CLI completes pairing with code from user
app.post('/pair/complete', async (c) => {
  const { code } = await c.req.json<{ code: string }>();

  // Validate code format
  if (!code || !/^\d{6}$/.test(code)) {
    return c.json({ error: 'Invalid code format' }, 400);
  }

  // Find session by code
  const session = await c.env.PAIRING_KV.get<PairingSession>(`code:${code}`, 'json');

  if (!session) {
    return c.json({ error: 'Invalid or expired code' }, 404);
  }

  if (session.paired) {
    return c.json({ error: 'Code already used' }, 409);
  }

  // Generate pairing ID
  const pairingId = crypto.randomUUID();

  // Update session as paired
  session.paired = true;
  session.pairingId = pairingId;

  // Update both keys
  await c.env.PAIRING_KV.put(`code:${code}`, JSON.stringify(session), { expirationTtl: 60 });
  await c.env.PAIRING_KV.put(`watch:${session.watchId}`, JSON.stringify(session), { expirationTtl: 60 });

  // Store connection for future use
  await c.env.CONNECTIONS_KV.put(`pairing:${pairingId}`, JSON.stringify({
    pairingId,
    deviceToken: session.deviceToken,
    createdAt: new Date().toISOString(),
    lastSeen: new Date().toISOString(),
  }), { expirationTtl: 86400 });

  return c.json({ pairingId });
});
```

#### 1.4 Update PairingSession type

```typescript
interface PairingSession {
  code: string;
  watchId: string;      // NEW: Watch's unique ID for polling
  deviceToken: string;  // MOVED: Now set at initiate time
  createdAt: string;
  paired: boolean;
  pairingId: string | null;
}
```

---

### Phase 2: Watch App Changes (45 min)

#### 2.1 Add `initiatePairing()` to WatchService

**File:** `ClaudeWatch/Services/WatchService.swift`

```swift
/// Initiate pairing - watch requests a code to display
func initiatePairing() async throws -> (code: String, watchId: String) {
    let url = URL(string: "\(cloudServerURL)/pair/initiate")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let deviceToken = await getDeviceToken()

    let body: [String: Any] = [
        "deviceToken": deviceToken ?? "simulator-token"
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await urlSession.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw CloudError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let code = json["code"] as? String,
          let watchId = json["watchId"] as? String else {
        throw CloudError.invalidResponse
    }

    return (code, watchId)
}

/// Poll to check if CLI completed pairing
func checkPairingStatus(watchId: String) async throws -> (paired: Bool, pairingId: String?) {
    let url = URL(string: "\(cloudServerURL)/pair/status/\(watchId)")!

    let (data, response) = try await urlSession.data(from: url)

    guard let httpResponse = response as? HTTPURLResponse,
          httpResponse.statusCode == 200 else {
        throw CloudError.serverError((response as? HTTPURLResponse)?.statusCode ?? 0)
    }

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        throw CloudError.invalidResponse
    }

    if json["expired"] as? Bool == true {
        throw CloudError.invalidCode // Code expired
    }

    let paired = json["paired"] as? Bool ?? false
    let pairingId = json["pairingId"] as? String

    return (paired, pairingId)
}
```

#### 2.2 Replace PairingCodeEntryView with PairingCodeDisplayView

**File:** `ClaudeWatch/Views/PairingView.swift`

Replace `PairingCodeEntryView` (lines 118-289) with:

```swift
// MARK: - Pairing Code Display View
struct PairingCodeDisplayView: View {
    @ObservedObject var service: WatchService
    let onBack: () -> Void

    @State private var displayCode: String = ""
    @State private var watchId: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPaired = false
    @State private var pollingTask: Task<Void, Never>?

    var body: some View {
        if isPaired {
            ConnectedSuccessView()
        } else {
            VStack(spacing: Claude.Spacing.sm) {
                // Header with back button
                HStack {
                    Button(action: {
                        WKInterfaceDevice.current().play(.click)
                        pollingTask?.cancel()
                        onBack()
                    }) {
                        HStack(spacing: 2) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.orange)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(Claude.orange)
                    Text("Getting code...")
                        .font(.claudeFootnote)
                        .foregroundStyle(Claude.textSecondary)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: Claude.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(Claude.danger)
                        Text(error)
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.danger)
                            .multilineTextAlignment(.center)
                        Button(action: {
                            WKInterfaceDevice.current().play(.click)
                            requestCode()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.clockwise")
                                Text("Try Again")
                            }
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.orange)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                } else {
                    // CODE DISPLAY
                    VStack(spacing: Claude.Spacing.sm) {
                        Text("Enter in terminal:")
                            .font(.claudeCaption)
                            .foregroundStyle(Claude.textSecondary)

                        Text(formatCode(displayCode))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(Claude.textPrimary)
                            .accessibilityLabel("Pairing code")
                            .accessibilityValue(displayCode.map { String($0) }.joined(separator: " "))

                        Text("Waiting for connection...")
                            .font(.claudeFootnote)
                            .foregroundStyle(Claude.textTertiary)
                    }
                    .padding(Claude.Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Claude.surface1)
                    .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.medium))

                    Spacer()

                    // npx hint
                    Text("npx cc-watch")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Claude.textTertiary)
                }
            }
            .padding(Claude.Spacing.md)
            .task {
                requestCode()
            }
            .onDisappear {
                pollingTask?.cancel()
            }
        }
    }

    private func formatCode(_ code: String) -> String {
        // Format as "4 7 2 9 1 3" for readability
        code.map { String($0) }.joined(separator: " ")
    }

    private func requestCode() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await service.initiatePairing()
                await MainActor.run {
                    displayCode = result.code
                    watchId = result.watchId
                    isLoading = false
                    WKInterfaceDevice.current().play(.click)
                }
                startPolling()
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    WKInterfaceDevice.current().play(.failure)
                }
            }
        }
    }

    private func startPolling() {
        pollingTask?.cancel()
        pollingTask = Task {
            var attempts = 0
            let maxAttempts = 150 // 5 minutes at 2-second intervals

            while !Task.isCancelled && attempts < maxAttempts {
                attempts += 1

                do {
                    let status = try await service.checkPairingStatus(watchId: watchId)

                    if status.paired, let pairingId = status.pairingId {
                        await MainActor.run {
                            service.pairingId = pairingId
                            service.connectionStatus = .connected
                            isPaired = true
                            WKInterfaceDevice.current().play(.success)
                            service.startPolling()
                        }
                        return
                    }
                } catch {
                    // Ignore polling errors, continue trying
                }

                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            }

            // Timeout
            await MainActor.run {
                errorMessage = "Pairing timed out. Try again."
                WKInterfaceDevice.current().play(.failure)
            }
        }
    }
}
```

#### 2.3 Update PairingView to use new component

**File:** `ClaudeWatch/Views/PairingView.swift` (lines 13-14)

Change:
```swift
if showCodeEntry {
    PairingCodeEntryView(service: service, onBack: { showCodeEntry = false })
```

To:
```swift
if showCodeEntry {
    PairingCodeDisplayView(service: service, onBack: { showCodeEntry = false })
```

#### 2.4 Update UnpairedMainView text

**File:** `ClaudeWatch/Views/PairingView.swift` (lines 62-64)

Change:
```swift
Text("Enter code from terminal")
```

To:
```swift
Text("Get code to enter in terminal")
```

---

### Phase 3: CLI Changes (30 min)

#### 3.1 Modify setup.ts to accept code input

**File:** `claude-watch-npm/src/cli/setup.ts`

Replace `runCloudPairing()` function (lines 88-133):

```typescript
/**
 * Run cloud pairing flow - user enters code from watch
 */
async function runCloudPairing(cloudUrl: string): Promise<string | null> {
  console.log();
  console.log(chalk.dim("  Open the Claude Watch app on your Apple Watch."));
  console.log(chalk.dim("  Tap 'Pair Now' to see a 6-digit code."));
  console.log();

  // Ask for code
  const response = await prompts({
    type: "text",
    name: "code",
    message: "Enter the code from your watch:",
    validate: (value) => {
      if (!/^\d{6}$/.test(value.replace(/\s/g, ""))) {
        return "Please enter a 6-digit code";
      }
      return true;
    },
    format: (value) => value.replace(/\s/g, ""), // Remove any spaces
  });

  if (!response.code) {
    return null;
  }

  const code = response.code;

  // Complete pairing
  const spinner = ora("Connecting...").start();

  try {
    const res = await fetch(`${cloudUrl}/pair/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });

    if (res.status === 404) {
      spinner.fail("Invalid or expired code");
      console.log();
      console.log(chalk.yellow("  Make sure the code is still showing on your watch."));
      console.log(chalk.yellow("  Codes expire after 5 minutes."));
      console.log();
      return null;
    }

    if (res.status === 409) {
      spinner.fail("Code already used");
      console.log();
      console.log(chalk.yellow("  This code was already paired. Get a new code from your watch."));
      console.log();
      return null;
    }

    if (!res.ok) {
      spinner.fail(`Server error (${res.status})`);
      return null;
    }

    const data = await res.json() as { pairingId: string };
    spinner.succeed("Connected!");

    return data.pairingId;
  } catch (error) {
    spinner.fail("Connection failed");
    console.error(error);
    return null;
  }
}
```

#### 3.2 Remove PairingSession class (no longer needed in CLI)

**File:** `claude-watch-npm/src/cloud/pairing.ts`

Keep only utility functions, remove polling logic:

```typescript
/**
 * Format pairing code for display (e.g., "4 7 2 9 1 3")
 */
export function formatPairingCode(code: string): string {
  return code.split("").join(" ");
}

/**
 * Validate pairing code format
 */
export function isValidPairingCode(code: string): boolean {
  return /^\d{6}$/.test(code.replace(/\s/g, ""));
}
```

---

## Files to Modify

| File | Changes |
|------|---------|
| `claude-watch-cloud/src/index.ts` | Add `/pair/initiate`, `/pair/status/:watchId`, modify `/pair/complete` |
| `ClaudeWatch/Services/WatchService.swift` | Add `initiatePairing()`, `checkPairingStatus()` |
| `ClaudeWatch/Views/PairingView.swift` | Replace `PairingCodeEntryView` with `PairingCodeDisplayView` |
| `claude-watch-npm/src/cli/setup.ts` | Change to accept code input instead of displaying |
| `claude-watch-npm/src/cloud/pairing.ts` | Simplify to utility functions only |

---

## Testing Plan

### 1. Cloud Worker
```bash
# Deploy
cd claude-watch-cloud && wrangler deploy

# Test initiate
curl -X POST https://claude-watch.fotescodev.workers.dev/pair/initiate \
  -H "Content-Type: application/json" \
  -d '{"deviceToken": "test"}'
# Should return: { "code": "123456", "watchId": "uuid" }

# Test complete
curl -X POST https://claude-watch.fotescodev.workers.dev/pair/complete \
  -H "Content-Type: application/json" \
  -d '{"code": "123456"}'
# Should return: { "pairingId": "uuid" }
```

### 2. Watch App
```bash
# Build and install
cd /Users/dfotesco/claude-watch/claude-watch
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build
xcrun simctl install "Apple Watch Series 11 (46mm)" ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*/Build/Products/Debug-watchsimulator/ClaudeWatch.app
xcrun simctl launch "Apple Watch Series 11 (46mm)" com.edgeoftrust.claudewatch
```

### 3. End-to-End
1. Launch watch app → Tap "Pair Now"
2. Watch displays 6-digit code
3. Run `npx cc-watch` → Enter code
4. Watch shows "Connected!"
5. CLI shows "Connected!"

---

## Acceptance Criteria

- [ ] Watch displays 6-digit code when user taps "Pair Now"
- [ ] Code is clearly readable (large font, spaced digits)
- [ ] CLI prompts user to enter code
- [ ] CLI validates code format (6 digits)
- [ ] Pairing completes within 5 seconds of entering valid code
- [ ] Watch shows success state when CLI completes pairing
- [ ] Error handling works: expired code, invalid code, network error

---

## Security Improvements (from review)

These are documented but NOT in scope for this fix:

1. **Rate limiting** - Add to `/pair/complete` (max 5 attempts per IP per minute)
2. **Cryptographic RNG** - Use `crypto.getRandomValues()` instead of `Math.random()`
3. **Longer codes** - Consider 8 digits or alphanumeric (36^6 = 2.1B combinations)

---

**END OF PLAN**
