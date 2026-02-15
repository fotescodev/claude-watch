# Claude Watch: Detailed User Flows

**Document Version:** 1.0
**Last Updated:** January 2026
**Author:** Design Lead
**Status:** Final

---

## Overview

This document provides step-by-step user flows for all major interactions in Claude Watch. Each flow includes screen states, user actions, system responses, and edge case handling.

---

## Flow Index

| ID | Flow Name | Screens | Est. Time |
|----|-----------|---------|-----------|
| F1 | First Launch & Consent | 4 | 60 sec |
| F2 | Cloud Pairing (Manual Code) | 3 | 45-60 sec |
| F3 | Cloud Pairing (QR Code - iOS) | 5 | 10-15 sec |
| F4 | Single Action Approval | 2 | 3-5 sec |
| F5 | Bulk Approval | 2 | 5-8 sec |
| F6 | Action Rejection | 2 | 3-5 sec |
| F7 | Mode Switching | 2 | 2-3 sec |
| F8 | Voice Command | 3 | 10-15 sec |
| F9 | Quick Command | 1 | 2 sec |
| F10 | Settings Access | 2 | Variable |
| F11 | Notification Approval | 1 | 2-3 sec |
| F12 | Error Recovery | 2-3 | Variable |
| F13 | Demo Mode | 2 | 5 sec |
| F14 | Complication Interaction | 2 | 2 sec |

---

## Flow F1: First Launch & Consent

**Trigger:** User opens Claude Watch for the first time
**Goal:** Accept privacy consent and reach main view
**Screens:** Splash → Consent Page 1 → Consent Page 2 → Consent Page 3 → Main

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Splash    │───▶│  Consent 1  │───▶│  Consent 2  │───▶│  Consent 3  │───▶│  Main View  │
│  (0.5 sec)  │    │ (swipe/tap) │    │ (swipe/tap) │    │  (Accept)   │    │  (Pairing)  │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Tap app icon | Home screen | Launch animation | 0.5s |
| 2 | - | Splash | Auto-advance | 0.5s |
| 3 | Read page 1 | Consent Page 1 | Display privacy info | User-paced |
| 4 | Swipe left or tap | Consent Page 1 | Animate to page 2 | 0.3s |
| 5 | Read page 2 | Consent Page 2 | Display data info | User-paced |
| 6 | Swipe left or tap | Consent Page 2 | Animate to page 3 | 0.3s |
| 7 | Read page 3 | Consent Page 3 | Display terms | User-paced |
| 8 | Tap "Accept & Continue" | Consent Page 3 | Save consent, navigate | 0.3s |
| 9 | - | Main View | Check pairing status | 0.5s |

### Screen States

**Consent Page 1:**
```
┌─────────────────────────┐
│                         │
│    🔒 Privacy First     │
│                         │
│  Claude Watch connects  │
│  to your Claude Code    │
│  session to enable      │
│  action approvals       │
│                         │
│  ● ○ ○                  │
│                         │
│  Continue →             │
└─────────────────────────┘
```

**Consent Page 2:**
```
┌─────────────────────────┐
│                         │
│    📡 Data Handling     │
│                         │
│  • Action titles sent   │
│  • No code content      │
│  • No file contents     │
│  • Encrypted transit    │
│                         │
│  ○ ● ○                  │
│                         │
│  Continue →             │
└─────────────────────────┘
```

**Consent Page 3:**
```
┌─────────────────────────┐
│                         │
│    ✓ Ready to Start     │
│                         │
│  By continuing you      │
│  agree to the Terms     │
│  of Service and         │
│  Privacy Policy         │
│                         │
│  ○ ○ ●                  │
│                         │
│  ┌───────────────────┐  │
│  │ Accept & Continue │  │
│  └───────────────────┘  │
│                         │
│  View Privacy Policy    │
└─────────────────────────┘
```

### Edge Cases

| Condition | Behavior |
|-----------|----------|
| User swipes right on page 1 | No action (already at start) |
| User force-quits during consent | Restart consent on next launch |
| User taps Privacy Policy link | Opens policy in sheet |

---

## Flow F2: Cloud Pairing (Manual Code Entry)

**Trigger:** User needs to pair watch with Claude Code server
**Goal:** Successfully establish connection using 7-character code
**Screens:** Main (Unpaired) → Pairing View → Main (Paired)

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Main     │───▶│   Pairing   │───▶│  Connecting │───▶│    Main     │
│  (Unpaired) │    │  (Code In)  │    │  (Loading)  │    │  (Paired)   │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼ (error)
                   ┌─────────────┐
                   │   Error     │
                   │   State     │
                   └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Tap "Pair with Code" | Main (Unpaired) | Present pairing sheet | 0.3s |
| 2 | - | Pairing View | Show code input field | - |
| 3 | Tap input field | Pairing View | Show watch keyboard | 0.2s |
| 4 | Type code (ABC-123) | Pairing View | Update input field | User-paced |
| 5 | Tap "Connect" | Pairing View | Show loading, validate | 1-3s |
| 6a | - (success) | Pairing View | Haptic success, dismiss | 0.5s |
| 6b | - (failure) | Pairing View | Show error message | - |
| 7 | - | Main (Paired) | Show connected state | - |

### Screen States

**Pairing View (Initial):**
```
┌─────────────────────────┐
│  ← Cancel               │
│                         │
│    Enter Pairing Code   │
│                         │
│  ┌─────────────────────┐│
│  │ _ _ _ - _ _ _       ││
│  └─────────────────────┘│
│                         │
│  Run this in terminal:  │
│  claude --pair          │
│                         │
│  ┌───────────────────┐  │
│  │     Connect       │  │
│  └───────────────────┘  │
│  (disabled)             │
└─────────────────────────┘
```

**Pairing View (Code Entered):**
```
┌─────────────────────────┐
│  ← Cancel               │
│                         │
│    Enter Pairing Code   │
│                         │
│  ┌─────────────────────┐│
│  │ A B C - 1 2 3       ││
│  └─────────────────────┘│
│                         │
│  ✓ Valid format         │
│                         │
│  ┌───────────────────┐  │
│  │     Connect       │  │
│  └───────────────────┘  │
│  (enabled - orange)     │
└─────────────────────────┘
```

**Pairing View (Connecting):**
```
┌─────────────────────────┐
│                         │
│    Connecting...        │
│                         │
│        ◯                │
│       /|\               │
│       ⟳                 │
│       (spinner)         │
│                         │
│  Verifying code         │
│  ABC-123                │
│                         │
└─────────────────────────┘
```

**Pairing View (Error):**
```
┌─────────────────────────┐
│  ← Back                 │
│                         │
│    ⚠️ Pairing Failed    │
│                         │
│  Invalid or expired     │
│  pairing code.          │
│                         │
│  Codes expire after     │
│  10 minutes.            │
│                         │
│  ┌───────────────────┐  │
│  │    Try Again      │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

### Validation Rules

| Rule | Validation | Error Message |
|------|------------|---------------|
| Length | 7 characters (with hyphen) | "Code must be 7 characters" |
| Format | XXX-XXX (alphanumeric) | "Invalid code format" |
| Characters | A-Z, 0-9 only | "Only letters and numbers allowed" |
| Expiry | Code < 10 min old | "Code expired, generate new code" |

---

## Flow F3: Cloud Pairing (QR Code - iOS Companion)

**Trigger:** User wants to pair using iPhone camera
**Goal:** Zero-typing pairing via QR code scan
**Screens:** iOS Welcome → iOS Scanner → iOS Syncing → Watch Receiving → Watch Main

### Flow Diagram

```
iOS App:
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Welcome   │───▶│   Scanner   │───▶│  QR Scanned │───▶│   Syncing   │
│  (iOS)      │    │   (iOS)     │    │   (iOS)     │    │   (iOS)     │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
                                                                │
                                                                │ WatchConnectivity
                                                                ▼
Watch App:                                              ┌─────────────┐
┌─────────────┐                                         │  Receiving  │
│    Main     │◀────────────────────────────────────────│   (Watch)   │
│  (Paired)   │                                         └─────────────┘
└─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Open iOS companion app | iOS Home | Launch app | 0.5s |
| 2 | Tap "Scan QR Code" | iOS Welcome | Request camera permission | 0.3s |
| 3 | Allow camera (first time) | iOS Permission | Grant access | User |
| 4 | Point at terminal QR | iOS Scanner | Start scanning | - |
| 5 | - (auto-detect) | iOS Scanner | QR detected, vibrate | 0.1s |
| 6 | - | iOS Scanned | Show success animation | 0.5s |
| 7 | - | iOS Syncing | Begin WatchConnectivity | 1-3s |
| 8 | - | Watch Receiving | Watch shows receiving | 2-5s |
| 9 | - | iOS Complete | Show success | 0.5s |
| 10 | - | Watch Main | Show connected | - |

### Screen States (iOS)

**iOS Welcome:**
```
┌─────────────────────────────────┐
│                                 │
│         ◯ Claude Watch          │
│         ─────────────           │
│                                 │
│    Pair your Apple Watch with   │
│    Claude Code in seconds       │
│                                 │
│    ┌───────────────────────┐    │
│    │    📷 Scan QR Code    │    │
│    └───────────────────────┘    │
│                                 │
│    ───── or ─────               │
│                                 │
│    Enter code manually          │
│                                 │
└─────────────────────────────────┘
```

**iOS Scanner:**
```
┌─────────────────────────────────┐
│  ✕                              │
│                                 │
│    ┌───────────────────────┐    │
│    │                       │    │
│    │     [Viewfinder]      │    │
│    │                       │    │
│    │    ┌───────────┐      │    │
│    │    │  QR Area  │      │    │
│    │    └───────────┘      │    │
│    │                       │    │
│    └───────────────────────┘    │
│                                 │
│    Point at the QR code         │
│    in your terminal             │
│                                 │
│    ──────────────────────       │
│    Enter code manually          │
└─────────────────────────────────┘
```

**iOS Scanned (Success):**
```
┌─────────────────────────────────┐
│                                 │
│           ✓                     │
│                                 │
│    Code Scanned!                │
│                                 │
│    ABC-123                      │
│                                 │
│    Syncing to Watch...          │
│                                 │
│    ▓▓▓▓▓▓▓▓░░░░░                │
│                                 │
│    Keep this app open           │
│                                 │
└─────────────────────────────────┘
```

**iOS Complete:**
```
┌─────────────────────────────────┐
│                                 │
│           ✓                     │
│       Connected!                │
│                                 │
│    Your Apple Watch is now      │
│    paired with Claude Code      │
│                                 │
│    ┌───────────────────────┐    │
│    │       Done            │    │
│    └───────────────────────┘    │
│                                 │
│    Open Claude Watch on your    │
│    watch to start approving     │
│                                 │
└─────────────────────────────────┘
```

### Screen States (Watch)

**Watch Receiving:**
```
┌─────────────────────────┐
│                         │
│    📲 Receiving         │
│       pairing...        │
│                         │
│    ▓▓▓▓▓▓▓░░░░░         │
│                         │
│    From iPhone          │
│                         │
└─────────────────────────┘
```

### Time Comparison

| Pairing Method | Steps | Time | Friction Level |
|----------------|-------|------|----------------|
| Manual Code (Current) | 8 | 45-60s | High |
| QR Code (iOS) | 5 | 10-15s | Low |
| Improvement | -3 | -75% | Significant |

---

## Flow F4: Single Action Approval

**Trigger:** Claude Code requests approval for a single action
**Goal:** User approves action from watch
**Screens:** Main View with Action Card

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Main     │───▶│   Action    │───▶│    Main     │
│  (Pending)  │    │  (Approve)  │    │  (Clear)    │
└─────────────┘    └─────────────┘    └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | - (notification) | Lock screen | Watch buzzes, notification | - |
| 2 | Raise wrist | Main View | Display action card | 0.3s |
| 3 | Review action | Main View | - | 1-2s |
| 4 | Tap "Approve" | Action Card | Send approval, haptic | 0.3s |
| 5 | - | Main View | Card dismisses, "Approved" toast | 0.5s |
| 6 | - | Main View | Update to next action or clear | 0.3s |

### Screen States

**Main View (Single Action Pending):**
```
┌─────────────────────────┐
│  ⚙️                     │
│                         │
│  ● Running • 42%        │
│  Building feature       │
│  ▓▓▓▓▓▓▓▓░░░░░░░░       │
│                         │
│  ┌─────────────────────┐│
│  │ 📝 Edit             ││
│  │ src/App.tsx         ││
│  │ Add dark mode toggle││
│  │                     ││
│  │ ┌─────┐  ┌────────┐ ││
│  │ │Reject│  │Approve │ ││
│  │ └─────┘  └────────┘ ││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘
```

**Main View (Approval Feedback):**
```
┌─────────────────────────┐
│                         │
│      ✓ Approved         │
│                         │
│   (0.5s toast overlay)  │
│                         │
└─────────────────────────┘
```

**Main View (After Approval):**
```
┌─────────────────────────┐
│  ⚙️                     │
│                         │
│  ● Running • 45%        │
│  Building feature       │
│  ▓▓▓▓▓▓▓▓░░░░░░░░       │
│                         │
│  ┌─────────────────────┐│
│  │                     ││
│  │    ✓ All Clear      ││
│  │                     ││
│  │    No actions       ││
│  │    pending          ││
│  │                     ││
│  └─────────────────────┘│
│                         │
└─────────────────────────┘
```

### Haptic Patterns

| Action | Haptic Type | Description |
|--------|-------------|-------------|
| Approve | Success | Two subtle taps |
| Reject | Warning | Single firm tap |
| Error | Error | Triple rapid taps |

---

## Flow F5: Bulk Approval

**Trigger:** Multiple actions pending, user wants to approve all
**Goal:** Approve all pending actions with one tap
**Screens:** Main View → Confirmation → Main View

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Main     │───▶│  Confirm    │───▶│    Main     │
│  (5 pending)│    │  Dialog     │    │  (Clear)    │
└─────────────┘    └─────────────┘    └─────────────┘
                          │
                          ▼ (cancel)
                   ┌─────────────┐
                   │    Main     │
                   │  (5 pending)│
                   └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | View 5+ pending | Main View | Display action queue | - |
| 2 | Scroll to bottom | Main View | Reveal "Approve All" | 0.5s |
| 3 | Tap "Approve All" | Main View | Show confirmation dialog | 0.3s |
| 4a | Tap "Approve 5" | Dialog | Approve all, haptic | 0.5s |
| 4b | Tap "Cancel" | Dialog | Dismiss dialog | 0.3s |
| 5 | - | Main View | All cards clear | 0.5s |

### Screen States

**Main View (Multiple Actions):**
```
┌─────────────────────────┐
│  ⚙️                     │
│                         │
│  ● Running • 60%        │
│  ──────────────         │
│                         │
│  ┌─────────────────────┐│
│  │ 📝 Edit App.tsx     ││
│  │ ┌─────┐  ┌────────┐ ││
│  │ │Reject│  │Approve │ ││
│  │ └─────┘  └────────┘ ││
│  └─────────────────────┘│
│                         │
│  ┌──────────┬──────────┐│
│  │ 📄 Create│ 📝 Edit  ││
│  │ test.ts  │ index.ts ││
│  └──────────┴──────────┘│
│                         │
│  + 2 more               │
│                         │
│  ┌───────────────────┐  │
│  │   Approve All (5) │  │
│  └───────────────────┘  │
└─────────────────────────┘
```

**Confirmation Dialog:**
```
┌─────────────────────────┐
│                         │
│    Approve All?         │
│                         │
│    This will approve    │
│    5 pending actions    │
│                         │
│  ┌───────────────────┐  │
│  │   Approve 5       │  │
│  └───────────────────┘  │
│                         │
│  Cancel                 │
│                         │
└─────────────────────────┘
```

---

## Flow F6: Action Rejection

**Trigger:** User decides to reject an action
**Goal:** Stop Claude from executing the action
**Screens:** Main View

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Review action | Main View | - | User |
| 2 | Tap "Reject" | Action Card | Show confirmation (optional) | 0.3s |
| 3 | Confirm rejection | Dialog | Send rejection, error haptic | 0.5s |
| 4 | - | Main View | Card removes, "Rejected" toast | 0.5s |

### Screen States

**Rejection Toast:**
```
┌─────────────────────────┐
│                         │
│      ✕ Rejected         │
│                         │
│   (0.5s toast overlay)  │
│                         │
└─────────────────────────┘
```

---

## Flow F7: Mode Switching

**Trigger:** User wants to change permission mode
**Goal:** Switch between Normal, Auto-Accept, and Plan modes
**Screens:** Main View → Mode Selector

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Main     │───▶│    Mode     │───▶│    Main     │
│  (Normal)   │    │  Selector   │    │(Auto-Accept)│
└─────────────┘    └─────────────┘    └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Scroll to mode section | Main View | - | 0.5s |
| 2 | Tap desired mode | Mode Selector | Highlight selection | 0.1s |
| 3 | - | Mode Selector | Send mode to server | 0.3s |
| 4 | - | Main View | Update mode display, haptic | 0.3s |

### Screen States

**Mode Selector:**
```
┌─────────────────────────┐
│                         │
│  Permission Mode        │
│                         │
│  ┌─────┐ ┌─────┐ ┌─────┐│
│  │ 🔵  │ │ 🔴  │ │ 🟣  ││
│  │Norm │ │Auto │ │Plan ││
│  │ ●   │ │     │ │     ││
│  └─────┘ └─────┘ └─────┘│
│                         │
│  Review each action     │
│                         │
└─────────────────────────┘
```

**Mode Descriptions:**

| Mode | Icon | Color | Description |
|------|------|-------|-------------|
| Normal | Shield | Blue | Review each action |
| Auto-Accept | Bolt | Red | Approve automatically |
| Plan | Book | Purple | Read-only planning |

### Warning for Auto-Accept

When switching to Auto-Accept mode, show warning:
```
┌─────────────────────────┐
│                         │
│  ⚠️ Auto-Accept Mode    │
│                         │
│  All actions will be    │
│  approved automatically │
│  without review.        │
│                         │
│  ┌───────────────────┐  │
│  │     Enable        │  │
│  └───────────────────┘  │
│                         │
│  Cancel                 │
│                         │
└─────────────────────────┘
```

---

## Flow F8: Voice Command

**Trigger:** User wants to send a voice command to Claude
**Goal:** Dictate command and send to Claude Code
**Screens:** Main View → Voice Input Sheet → Main View

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Main     │───▶│    Voice    │───▶│   Sending   │───▶│    Main     │
│   View      │    │   Input     │    │   Status    │    │   View      │
└─────────────┘    └─────────────┘    └─────────────┘    └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Tap voice command button | Main View | Present voice sheet | 0.3s |
| 2 | Tap input field or mic | Voice Sheet | Activate dictation | 0.3s |
| 3 | Speak command | Voice Sheet | Transcribe speech | User |
| 4 | Review transcription | Voice Sheet | Display text | - |
| 5 | Tap "Send" | Voice Sheet | Send to server | 0.5s |
| 6 | - | Voice Sheet | Show "Sent" confirmation | 0.5s |
| 7 | - | Main View | Dismiss sheet | 0.3s |

### Screen States

**Voice Input Sheet (Initial):**
```
┌─────────────────────────┐
│  ← Cancel               │
│                         │
│  Voice Command          │
│                         │
│  ┌─────────────────────┐│
│  │ Type or dictate...  ││
│  └─────────────────────┘│
│                         │
│  Suggestions:           │
│                         │
│  ┌──────┐ ┌──────┐      │
│  │ Go   │ │ Test │      │
│  └──────┘ └──────┘      │
│  ┌──────┐ ┌──────┐      │
│  │ Fix  │ │ Stop │      │
│  └──────┘ └──────┘      │
│                         │
│  ┌───────────────────┐  │
│  │       Send        │  │
│  └───────────────────┘  │
│  (disabled)             │
└─────────────────────────┘
```

**Voice Input Sheet (Recording):**
```
┌─────────────────────────┐
│  ← Cancel               │
│                         │
│  Voice Command          │
│                         │
│  ┌─────────────────────┐│
│  │ 🔴 Listening...     ││
│  └─────────────────────┘│
│                         │
│  ▁▃▅▇▅▃▁▃▅▇▅▃▁         │
│  (waveform)             │
│                         │
│  Tap when done          │
│                         │
└─────────────────────────┘
```

**Voice Input Sheet (Text Entered):**
```
┌─────────────────────────┐
│  ← Cancel               │
│                         │
│  Voice Command          │
│                         │
│  ┌─────────────────────┐│
│  │ Run the test suite  ││
│  │ and fix any errors  ││
│  └─────────────────────┘│
│                         │
│  ┌───────────────────┐  │
│  │       Send        │  │
│  └───────────────────┘  │
│  (enabled - orange)     │
│                         │
└─────────────────────────┘
```

**Voice Input Sheet (Sent):**
```
┌─────────────────────────┐
│                         │
│         ✓               │
│                         │
│    Command Sent         │
│                         │
│    "Run the test        │
│    suite and fix..."    │
│                         │
└─────────────────────────┘
```

---

## Flow F9: Quick Command

**Trigger:** User taps a preset command button
**Goal:** Send predefined command to Claude Code
**Screens:** Main View only

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Scroll to command grid | Main View | - | 0.5s |
| 2 | Tap command (e.g., "Go") | Command Grid | Highlight button, send | 0.3s |
| 3 | - | Main View | Success haptic, brief toast | 0.5s |

### Screen States

**Command Grid:**
```
┌─────────────────────────┐
│                         │
│  Quick Commands         │
│                         │
│  ┌──────────┬──────────┐│
│  │ ▶️       │ ⚡       ││
│  │ Go       │ Test     ││
│  └──────────┴──────────┘│
│  ┌──────────┬──────────┐│
│  │ 🔧       │ ⏹️       ││
│  │ Fix      │ Stop     ││
│  └──────────┴──────────┘│
│                         │
│  ┌───────────────────┐  │
│  │ 🎤 Voice Command  │  │
│  └───────────────────┘  │
│                         │
└─────────────────────────┘
```

---

## Flow F10: Settings Access

**Trigger:** User wants to access settings
**Goal:** View and modify app settings
**Screens:** Main View → Settings Sheet

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Tap settings gear | Main View toolbar | Present settings sheet | 0.3s |
| 2 | Browse settings | Settings Sheet | - | User |
| 3 | Modify setting | Settings Sheet | Save immediately | 0.1s |
| 4 | Tap close/swipe down | Settings Sheet | Dismiss sheet | 0.3s |

### Screen States

**Settings Sheet:**
```
┌─────────────────────────┐
│  ✕ Settings             │
│                         │
│  CONNECTION             │
│  ┌─────────────────────┐│
│  │ Status: Connected   ││
│  │ Pairing: ABC-123    ││
│  │                     ││
│  │ ┌─────────────────┐ ││
│  │ │ Re-pair Device  │ ││
│  │ └─────────────────┘ ││
│  └─────────────────────┘│
│                         │
│  PREFERENCES            │
│  ┌─────────────────────┐│
│  │ Demo Mode     [OFF] ││
│  │ Cloud Mode    [ON]  ││
│  └─────────────────────┘│
│                         │
│  ABOUT                  │
│  ┌─────────────────────┐│
│  │ Version 1.0.0       ││
│  │ Privacy Policy      ││
│  │ Terms of Service    ││
│  └─────────────────────┘│
└─────────────────────────┘
```

---

## Flow F11: Notification Approval

**Trigger:** Claude Code sends push notification
**Goal:** Approve action directly from notification
**Screens:** Notification banner/full screen

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐
│ Notification│───▶│    Done     │
│  (Actions)  │    │ (app updated)│
└─────────────┘    └─────────────┘
```

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Watch buzzes | Lock screen | Show notification | - |
| 2 | Read notification | Notification | Display action info | User |
| 3a | Tap "Approve" | Notification | Send approval, haptic | 0.5s |
| 3b | Tap "Reject" | Notification | Send rejection, haptic | 0.5s |
| 4 | - | Lock screen | Notification dismisses | 0.3s |

### Screen States

**Notification (Banner):**
```
┌─────────────────────────┐
│ 🟠 Claude Watch         │
│                         │
│ Edit src/App.tsx        │
│ Add dark mode toggle    │
│                         │
│ ┌───────┐  ┌──────────┐ │
│ │Reject │  │ Approve  │ │
│ └───────┘  └──────────┘ │
└─────────────────────────┘
```

---

## Flow F12: Error Recovery

**Trigger:** Connection fails or error occurs
**Goal:** Return to working state
**Screens:** Error State → Recovery → Main View

### Flow Diagram

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│   Error     │───▶│  Reconnect  │───▶│    Main     │
│   State     │    │   Attempt   │    │   View      │
└─────────────┘    └─────────────┘    └─────────────┘
       │
       ▼ (manual)
┌─────────────┐
│  Re-pair    │
│   Flow      │
└─────────────┘
```

### Screen States

**Offline State:**
```
┌─────────────────────────┐
│                         │
│    📡 Disconnected      │
│                         │
│    Lost connection      │
│    to server            │
│                         │
│    ┌───────────────┐    │
│    │     Retry     │    │
│    └───────────────┘    │
│                         │
│    ┌───────────────┐    │
│    │   Demo Mode   │    │
│    └───────────────┘    │
│                         │
└─────────────────────────┘
```

**Reconnecting State:**
```
┌─────────────────────────┐
│                         │
│    🔄 Reconnecting      │
│                         │
│    Attempt 3 of 10      │
│    Next retry: 8s       │
│                         │
│    ▓▓▓░░░░░░░░░░░░      │
│                         │
│    Cancel               │
│                         │
└─────────────────────────┘
```

---

## Flow F13: Demo Mode

**Trigger:** User wants to explore app without real connection
**Goal:** Load sample data and explore UI
**Screens:** Main View → Demo Data Loaded

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Tap "Load Demo" or Settings toggle | Empty/Settings | Load demo data | 0.3s |
| 2 | - | Main View | Populate with sample actions | 0.5s |
| 3 | Interact with demo | Main View | Simulated responses | User |
| 4 | Tap "Exit Demo" in Settings | Settings | Clear demo data | 0.3s |

---

## Flow F14: Complication Interaction

**Trigger:** User taps watch face complication
**Goal:** Quick access to Claude Watch
**Screens:** Watch Face → Main View

### Step-by-Step

| Step | User Action | Screen | System Response | Duration |
|------|-------------|--------|-----------------|----------|
| 1 | Glance at complication | Watch Face | See status | - |
| 2 | Tap complication | Watch Face | Launch app | 0.5s |
| 3 | - | Main View | Show current state | 0.3s |

### Complication Types

| Type | Display | Information |
|------|---------|-------------|
| Circular | Progress ring | % complete, pending badge |
| Rectangular | Full status | Task name, progress, pending |
| Corner | Arc progress | Percentage only |
| Inline | Text only | Task + percentage |

---

## Appendix: Flow Metrics

### Target Completion Times

| Flow | Target | Maximum Acceptable |
|------|--------|-------------------|
| First Launch | 60s | 120s |
| Manual Pairing | 45s | 90s |
| QR Pairing | 15s | 30s |
| Single Approval | 3s | 5s |
| Bulk Approval | 5s | 10s |
| Mode Switch | 2s | 5s |
| Voice Command | 10s | 20s |

### Error Rate Targets

| Flow | Target Error Rate |
|------|------------------|
| Pairing (Manual) | < 30% |
| Pairing (QR) | < 5% |
| Approval | < 1% |
| Mode Switch | < 1% |
| Voice Command | < 10% (transcription) |

---

*Document maintained by Design Lead. Update when flows change.*
