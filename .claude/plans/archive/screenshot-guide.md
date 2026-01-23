# Screenshot Capture Guide

> For App Store submission - Apple Watch Series 10 46mm (416x496px)

## Setup

### Simulator
```bash
# Open Simulator
open -a Simulator

# Select: File → Open Simulator → watchOS 11.0 → Apple Watch Series 10 (46mm)
```

### Screenshot Command
```bash
# Take screenshot (saves to Desktop)
xcrun simctl io booted screenshot ~/Desktop/screenshot-$(date +%s).png
```

### Or Use Xcode
1. Window → Devices and Simulators
2. Select watch simulator
3. Click camera icon

---

## 5 Required Screenshots

### 1. Main View with Pending Action
**Goal:** Show the core approval interface

**Setup:**
1. Pair watch with CLI
2. Trigger a tool request (e.g., file edit)
3. Wait for notification to appear on main view

**What to capture:**
- Tool name visible (e.g., "Edit: src/index.ts")
- Approve/Reject buttons visible
- Session status (connected indicator)

**Filename:** `01-pending-action.png`

---

### 2. Action Approval Flow
**Goal:** Show the approval in progress or confirmation

**Setup:**
1. Have a pending action
2. Tap "Approve" button
3. Capture the confirmation/success state

**What to capture:**
- Success checkmark or "Approved" text
- Visual feedback that action was taken

**Filename:** `02-approval-flow.png`

---

### 3. Mode Switcher
**Goal:** Show the three operating modes

**Setup:**
1. Open Settings/Mode view
2. Show all three modes visible

**What to capture:**
- Normal mode
- Auto-approve mode (YOLO)
- Plan mode
- Current selection highlighted

**Filename:** `03-mode-switcher.png`

---

### 4. Watch Face Complications
**Goal:** Show complications on a watch face

**Setup:**
1. Add CC Watch complication to watch face
2. Use Modular, Infograph, or similar face
3. Show complication displaying status

**What to capture:**
- Watch face with complication visible
- Status indicator (connected/pending count)

**Tip:** Use Simulator → Features → Trigger Complication Update

**Filename:** `04-complications.png`

---

### 5. Voice Input Sheet
**Goal:** Show voice command capability

**Setup:**
1. Trigger voice input (microphone button)
2. Show dictation interface

**What to capture:**
- Dictation waveform/interface
- Input field
- Send/cancel buttons

**Filename:** `05-voice-input.png`

---

## Screenshot Checklist

- [ ] Screenshot 1: Main view with pending action
- [ ] Screenshot 2: Approval confirmation
- [ ] Screenshot 3: Mode switcher
- [ ] Screenshot 4: Watch face with complication
- [ ] Screenshot 5: Voice input sheet

## Post-Processing

### Resize (if needed)
```bash
# Should already be 416x496 from Series 10 simulator
sips -z 496 416 screenshot.png
```

### Verify dimensions
```bash
sips -g pixelHeight -g pixelWidth *.png
```

## Upload to App Store Connect

1. Go to appstoreconnect.apple.com
2. My Apps → CC Watch → App Store → Prepare for Submission
3. Scroll to "Apple Watch Screenshots"
4. Select "Series 10 - 46mm"
5. Upload all 5 screenshots in order
6. Add optional captions

## Screenshot Captions (Optional)

| # | Caption |
|---|---------|
| 1 | "Approve code changes instantly" |
| 2 | "One tap to keep Claude working" |
| 3 | "Choose your approval style" |
| 4 | "Status at a glance" |
| 5 | "Voice commands on your wrist" |

---

*Ready to capture? Start the simulator and pair with cc-watch!*
