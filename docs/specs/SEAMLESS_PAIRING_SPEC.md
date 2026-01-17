# Feature Spec: Seamless Watch Pairing

**Status:** Ready for Implementation
**Priority:** High
**Created:** 2026-01-16
**Target:** Claude Watch v1.1

---

## Problem Statement

Current pairing requires typing a 7-character code (`ABC-123`) on the tiny Apple Watch keyboard. This creates friction:
- Watch keyboards are slow and error-prone
- Users must look at terminal, then type on watch
- Poor first-run experience

## Goal

Reduce pairing friction by implementing multiple seamless alternatives that require minimal or no typing on the watch.

---

## Solution: Two-Phase Approach

### Phase 1: Quick Wins (No New Apps Required)

#### P1: Clipboard-Based Pairing
Add a "Paste Code" button that reads from Universal Clipboard.

**How it works:**
1. Terminal outputs: `Pairing code: ABC-123` (also copies to clipboard)
2. User opens watch app, taps "Paste Code" button
3. Universal Clipboard transfers code automatically
4. Watch parses and pairs with one tap

**Requirements:**
- Add "Paste Code" button to `PairingView.swift`
- Use `UIPasteboard.general.string` (via WatchKit bridge)
- Parse clipboard for code pattern `[A-Z0-9]{3}-[A-Z0-9]{3}`
- Handle case where clipboard is empty or doesn't contain valid code
- Add haptic feedback on success/failure

#### P2: Numeric PIN Codes
Replace alphanumeric codes with 6-digit numeric codes for faster typing.

**How it works:**
1. Server generates `123456` instead of `ABC-123`
2. Watch shows numeric keypad instead of full keyboard
3. Faster, fewer errors

**Requirements:**
- Update `generatePairingCode()` in worker to produce 6-digit numbers
- Update `PairingView.swift` to use numeric TextField
- Change `keyboardType` to `.numberPad`
- Update validation regex
- Maintain backwards compatibility for existing codes

#### P3: Deep Link Support
Enable pairing via URL schemes for future integrations.

**How it works:**
1. Terminal can output: `claude-watch://pair?code=ABC123`
2. Clicking link opens watch app with code pre-filled
3. User just taps "Connect"

**Requirements:**
- Register `claude-watch://` URL scheme in Info.plist
- Handle `onOpenURL` in `ClaudeWatchApp.swift`
- Extract code from URL query parameters
- Auto-navigate to pairing view with pre-filled code
- Works with Universal Links for web-based pairing

---

### Phase 2: iOS Companion App (Future)

#### P4: WatchConnectivity Token Transfer
Build iOS companion app that handles pairing and transfers token to watch.

**How it works:**
1. User installs iOS companion app
2. iPhone scans QR code from terminal (or manual code entry)
3. Token automatically syncs to watch via `WCSession.updateApplicationContext()`
4. Watch is paired - zero typing on watch

**Requirements:**
- Create new iOS app target in Xcode project
- Implement `WCSession` on both iOS and watchOS
- Transfer `pairingId` and `deviceToken` via application context
- Handle session activation states
- Persist credentials in shared App Group

#### P5: QR Code Scanning (iOS)
Add camera-based QR scanning in the iOS companion app.

**How it works:**
1. Terminal displays QR code (ASCII or image)
2. iOS app scans QR containing pairing URL
3. Extracts code and completes pairing
4. Syncs to watch automatically

**Requirements:**
- Use `AVCaptureSession` for camera access
- Parse QR containing `claude-watch://pair?code=...`
- Handle camera permissions
- Fallback to manual entry

---

## Technical Implementation

### Files to Modify (Phase 1)

| File | Changes |
|------|---------|
| `ClaudeWatch/Views/PairingView.swift` | Add paste button, numeric input option |
| `MCPServer/worker/src/index.js` | Add numeric code generation mode |
| `ClaudeWatch/App/ClaudeWatchApp.swift` | Handle deep links via `onOpenURL` |
| `ClaudeWatch/Info.plist` | Register URL scheme |

### Files to Create (Phase 2)

| File | Purpose |
|------|---------|
| `ClaudeWatchCompanion/` | iOS app target directory |
| `ClaudeWatchCompanion/ContentView.swift` | iOS pairing UI |
| `ClaudeWatchCompanion/QRScannerView.swift` | Camera QR scanning |
| `ClaudeWatch/Services/ConnectivityManager.swift` | WatchConnectivity handler |

---

## Verification Criteria

### Phase 1 Tasks

**P1 - Clipboard Pairing:**
```bash
grep -q 'UIPasteboard\|Pasteboard\|pasteFromClipboard\|clipboardCode' ClaudeWatch/Views/PairingView.swift
```

**P2 - Numeric Codes:**
```bash
grep -qE 'keyboardType.*numberPad|\.decimalPad|numericCode' ClaudeWatch/Views/PairingView.swift
```

**P3 - Deep Links:**
```bash
grep -q 'onOpenURL\|claude-watch://' ClaudeWatch/App/ClaudeWatchApp.swift && \
grep -q 'CFBundleURLSchemes' ClaudeWatch/Info.plist
```

---

## User Experience Flow

### Before (Current)
```
Terminal shows code → User reads code → Opens watch app → Types 7 chars → Taps Connect
                                          [Frustrating keyboard typing]
```

### After (Phase 1)
```
Option A: Terminal copies to clipboard → User opens watch → Taps "Paste" → Taps Connect
Option B: Terminal shows 6 digits → User types on number pad → Taps Connect
Option C: User clicks deep link → Watch opens with code → Taps Connect
```

### After (Phase 2)
```
iPhone scans QR → Token syncs to Watch automatically → Done (zero watch typing)
```

---

## Rollout Plan

1. **P1-P3** can be implemented independently in parallel
2. **P2** (numeric codes) requires server-side change
3. **P3** (deep links) requires Info.plist modification
4. **Phase 2** requires new Xcode target and App Store submission

---

## Success Metrics

- Pairing completion rate: Target 95%+ (from ~70% estimated)
- Average pairing time: < 15 seconds (from ~45 seconds)
- User complaints about pairing: Reduced by 80%

---

## Ralph Task IDs

| Task ID | Title | Priority | Phase |
|---------|-------|----------|-------|
| SP1 | Add clipboard paste button for pairing | High | 1 |
| SP2 | Implement numeric-only pairing codes | High | 1 |
| SP3 | Add deep link URL scheme support | Medium | 1 |
| SP4 | Create iOS companion app skeleton | Medium | 2 |
| SP5 | Implement WatchConnectivity token sync | Medium | 2 |
