# Claude Watch: Google AI Studio / Figma Make Design Prompt

## PROJECT BRIEF

**App Name:** Claude Watch
**Platform:** watchOS 10+ (Apple Watch Series 4 and later)
**Purpose:** Companion app for Claude Code CLI that lets developers approve/reject AI code changes from their wrist

---

## VISUAL IDENTITY

### Brand Colors (Use exactly)
- **Primary:** `#FF9500` (Claude Orange)
- **Success:** `#34C759` (Apple Green)
- **Danger:** `#FF3B30` (Apple Red)
- **Info:** `#007AFF` (Apple Blue)
- **Background:** `#000000` (Pure black for OLED)
- **Surface:** `#1C1C1E` (Dark gray cards)
- **Text Primary:** `#FFFFFF`
- **Text Secondary:** `rgba(255,255,255,0.6)`

### Typography
- **Font:** SF Pro (system font)
- **Sizes:** 11pt caption, 13pt body, 15pt headline, 17pt title, 20pt large title

### Visual Style
- Dark mode only (pure black backgrounds)
- Rounded corners (8pt-20pt radius)
- Subtle material/glass effects on cards
- SF Symbols for all icons
- Capsule-shaped buttons with gradients
- Minimal UI, maximum content

---

## WATCH SIZE

**Design for 45mm Apple Watch (198×242 points)**

---

## SCREEN-BY-SCREEN SPECIFICATIONS

### SCREEN 1: Splash Screen

**Description:** App launch animation screen

**Layout:**
- Center: Claude logo (orange mascot, 80×80pt)
- Below logo: "Claude Watch" text (17pt, bold)
- Pure black background
- Show for 0.5 seconds

**Visual reference:**
```
[Black background]

        🟠
   Claude Watch
```

---

### SCREEN 2: Consent Page 1 (Privacy)

**Description:** First privacy consent screen (swipeable)

**Layout:**
- Top icon: Lock icon (🔒) in orange circle
- Headline: "Privacy First" (20pt, bold)
- Body text: "Claude Watch connects to your Claude Code session to enable action approvals" (15pt, secondary color)
- Pagination dots: ● ○ ○ (first active)
- Bottom: "Continue →" link

**Visual reference:**
```
      🔒

  Privacy First

  Claude Watch connects
  to your Claude Code
  session to enable
  action approvals

     ● ○ ○

  Continue →
```

---

### SCREEN 3: Consent Page 2 (Data)

**Description:** Data handling consent screen

**Layout:**
- Top icon: Antenna icon (📡) in blue circle
- Headline: "Data Handling" (20pt, bold)
- Bullet list:
  - "• Action titles sent"
  - "• No code content"
  - "• No file contents"
  - "• Encrypted transit"
- Pagination dots: ○ ● ○ (second active)
- Bottom: "Continue →" link

---

### SCREEN 4: Consent Page 3 (Accept)

**Description:** Final consent with accept button

**Layout:**
- Top icon: Checkmark (✓) in green circle
- Headline: "Ready to Start" (20pt, bold)
- Body: "By continuing you agree to the Terms of Service and Privacy Policy"
- Pagination dots: ○ ○ ● (third active)
- CTA Button: "Accept & Continue" (orange gradient, full width, capsule)
- Link: "View Privacy Policy"

---

### SCREEN 5: Main View - Unpaired State

**Description:** Main screen before pairing is complete

**Layout:**
- Settings gear icon (top right)
- Status header: "○ Not Connected" (gray dot + text)
- Large empty state card with:
  - Link icon (🔗)
  - "Pair with Claude Code" text
  - "Scan QR code or enter pairing code"
- Button: "Pair Now" (orange gradient, full width)
- Secondary button: "Load Demo" (gray outline)

**Visual reference:**
```
                    ⚙️

  ○ Not Connected

  ┌─────────────────────┐
  │                     │
  │        🔗           │
  │                     │
  │  Pair with Claude   │
  │       Code          │
  │                     │
  │  Scan QR or enter   │
  │  pairing code       │
  │                     │
  └─────────────────────┘

  ┌─────────────────────┐
  │      Pair Now       │  ← Orange gradient
  └─────────────────────┘

  ┌─────────────────────┐
  │     Load Demo       │  ← Gray outline
  └─────────────────────┘
```

---

### SCREEN 6: Pairing View

**Description:** Enter pairing code screen

**Layout:**
- Back arrow (top left): "← Cancel"
- Title: "Enter Pairing Code" (17pt, bold)
- Input field: Large, centered, placeholder "_ _ _ - _ _ _"
- Helper text: "Run this in terminal:"
- Code block: `claude --watch --pair`
- Button: "Connect" (disabled when empty, orange when valid)

---

### SCREEN 7: Connecting State

**Description:** Loading state during connection

**Layout:**
- Centered spinner animation
- Text: "Connecting..."
- Subtext: "Verifying code ABC-123"
- Pure black background

---

### SCREEN 8: Main View - Connected, No Actions

**Description:** Main screen when connected but idle

**Layout:**
- Settings gear (top right)
- Status header:
  - Green dot + "Idle"
  - "✓ All Clear" text
- Empty state card:
  - Checkmark icon (✓)
  - "No actions pending"
  - "Claude is ready"
- Button: "Load Demo" (outline style)
- Quick Commands section (see below)
- Mode Selector (see below)

**Visual reference:**
```
                    ⚙️

  ● Idle
  ✓ All Clear

  ┌─────────────────────┐
  │                     │
  │         ✓           │
  │                     │
  │   No actions        │
  │   pending           │
  │                     │
  │   Claude is ready   │
  │                     │
  └─────────────────────┘

  [Quick Commands Grid]

  [Mode Selector]
```

---

### SCREEN 9: Main View - Single Action Pending

**Description:** Main screen with one action awaiting approval

**Layout:**
- Settings gear + badge "1" (top right)
- Status header:
  - Orange dot + "Running" + "• 42%"
  - Task name: "Building feature"
  - Progress bar (42% filled, orange)
- Primary Action Card:
  - Action icon (📝 pencil for edit) in orange rounded square
  - Title: "Edit src/App.tsx" (15pt, bold)
  - Description: "Add dark mode toggle" (13pt, gray)
  - Two buttons side by side:
    - "Reject" (red/pink gradient, left)
    - "Approve" (green gradient, right)
- Quick Commands section
- Mode Selector

**Visual reference:**
```
                    ⚙️ 1

  ● Running • 42%
  Building feature
  ▓▓▓▓▓▓▓▓░░░░░░░░░░

  ┌─────────────────────┐
  │ 📝 Edit             │
  │ src/App.tsx         │
  │ Add dark mode toggle│
  │                     │
  │ ┌──────┐ ┌────────┐ │
  │ │Reject│ │Approve │ │
  │ │ red  │ │ green  │ │
  │ └──────┘ └────────┘ │
  └─────────────────────┘
```

---

### SCREEN 10: Main View - Multiple Actions Pending

**Description:** Queue of multiple pending actions

**Layout:**
- Settings gear + badge "5" (top right)
- Status header with progress
- Primary Action Card (expanded, first in queue)
- Compact Action Cards (2-up grid, remaining actions):
  - Small icon + title only
  - Example: "📄 Create test.ts" | "📝 Edit index.ts"
- "+ 2 more" text if queue exceeds visible
- "Approve All (5)" button (orange gradient)
- Quick Commands section
- Mode Selector

**Visual reference:**
```
                    ⚙️ 5

  ● Running • 60%
  Database migration
  ▓▓▓▓▓▓▓▓▓▓▓░░░░░░░

  ┌─────────────────────┐
  │ 📝 Edit             │
  │ App.tsx             │
  │ Add dark mode toggle│
  │ ┌──────┐ ┌────────┐ │
  │ │Reject│ │Approve │ │
  │ └──────┘ └────────┘ │
  └─────────────────────┘

  ┌────────┬────────┐
  │📄Create│📝 Edit │
  │test.ts │index.ts│
  └────────┴────────┘

  + 2 more

  ┌─────────────────────┐
  │  Approve All (5)    │
  └─────────────────────┘
```

---

### SCREEN 11: Critical Action Alert (Dangerous Operation)

**Description:** Warning screen for destructive operations

**Layout:**
- Red header bar: "⚠️ DANGEROUS OPERATION"
- Action card with red accent:
  - Trash icon (🗑️) in red circle
  - Title: "DELETE Operation"
  - Code block (red text): `DELETE FROM users WHERE inactive=true`
  - Details: "Table: users" | "Est. rows: 1,247" (red number)
- Two buttons:
  - "REJECT" (large, red, emphasized)
  - "Approve" (small, muted/gray)

**Visual reference:**
```
  ⚠️ DANGEROUS OPERATION
  (red background bar)

  ┌─────────────────────┐
  │                     │
  │  🗑️ DELETE          │
  │                     │
  │ ┌─────────────────┐ │
  │ │DELETE FROM users│ │
  │ │WHERE inactive=  │ │
  │ │true             │ │
  │ └─────────────────┘ │
  │                     │
  │ Table: users        │
  │ Est. rows: 1,247    │
  │         (red)       │
  │                     │
  │ ┌────────────────┐  │
  │ │    REJECT      │  │ ← Big, red, bold
  │ └────────────────┘  │
  │                     │
  │     Approve         │ ← Small, muted
  │                     │
  └─────────────────────┘
```

---

### SCREEN 12: Approval Confirmation Toast

**Description:** Brief success overlay after approval

**Layout:**
- Semi-transparent dark overlay
- Centered:
  - Green checkmark (✓)
  - "Approved" text (17pt, bold)
- Duration: 0.5 seconds

---

### SCREEN 13: Rejection Confirmation Toast

**Description:** Brief overlay after rejection

**Layout:**
- Semi-transparent dark overlay
- Centered:
  - Red X (✕)
  - "Rejected" text (17pt, bold)
- Duration: 0.5 seconds

---

### SCREEN 14: Approve All Confirmation Dialog

**Description:** Confirmation before bulk approval

**Layout:**
- Alert-style sheet:
  - Title: "Approve All?"
  - Body: "This will approve 5 pending actions"
  - Primary button: "Approve 5" (green gradient)
  - Secondary: "Cancel" (text link)

---

### SCREEN 15: Voice Command Sheet

**Description:** Voice input for custom commands

**Layout:**
- Header: "← Cancel" | "Voice Command"
- Input field with microphone icon
- Placeholder: "Type or dictate..."
- Suggestion chips: "Go" | "Test" | "Fix" | "Stop"
- "Send" button (disabled until input, orange when ready)

**Active recording state:**
- Input shows: "🔴 Listening..."
- Waveform animation below
- "Tap when done" hint

---

### SCREEN 16: Voice Command Sent Confirmation

**Description:** Success after sending voice command

**Layout:**
- Large green checkmark (✓)
- "Command Sent" (17pt, bold)
- Truncated command preview
- Auto-dismisses after 0.5s

---

### SCREEN 17: Settings Sheet

**Description:** App settings and configuration

**Layout:**
- Header: "✕ Settings"
- Sections:

**CONNECTION**
- Status: "Connected" (green dot)
- Pairing: "ABC-123"
- "Re-pair Device" button

**PREFERENCES**
- "Demo Mode" toggle [OFF]
- "Cloud Mode" toggle [ON]

**ABOUT**
- Version 1.0.0
- Privacy Policy (link)
- Terms of Service (link)

---

### SCREEN 18: Mode Selector Detail

**Description:** Permission mode selection (inline, not sheet)

**Layout:**
- Section title: "Permission Mode"
- Three horizontal options with icons:
  - Normal (🔵 shield): "Review each action"
  - Auto-Accept (🔴 bolt): "Approve automatically"
  - Plan (🟣 book): "Read-only planning"
- Selected mode has dot indicator below
- Description text updates based on selection

**Auto-Accept Warning (if selected):**
- Alert sheet:
  - "⚠️ Auto-Accept Mode"
  - "All actions will be approved automatically without review."
  - "Enable" button (red)
  - "Cancel" link

---

### SCREEN 19: Quick Commands Grid

**Description:** 2x2 grid of quick action buttons + voice

**Layout:**
- Section title: "Quick Commands"
- 2×2 grid:
  - ▶️ "Go" (green tint)
  - ⚡ "Test" (yellow tint)
  - 🔧 "Fix" (orange tint)
  - ⏹ "Stop" (red tint)
- Below grid:
  - 🎤 "Voice Command" (full width, outline style)

---

### SCREEN 20: Disconnected State

**Description:** Connection lost error screen

**Layout:**
- Large antenna icon (📡) with slash
- Title: "Disconnected"
- Body: "Lost connection to server"
- "Retry" button (orange gradient)
- "Demo Mode" button (outline style)

---

### SCREEN 21: Reconnecting State

**Description:** Automatic reconnection in progress

**Layout:**
- Spinning refresh icon (🔄)
- Title: "Reconnecting..."
- Subtext: "Attempt 3 of 10"
- "Next retry: 8s"
- Progress bar (partial fill)
- "Cancel" text link

---

### SCREEN 22: Demo Mode Banner

**Description:** Indicator when running in demo mode

**Layout:**
- Small banner at top: "Demo Mode" with sparkle icon (✨)
- Orange background, white text
- Persistent during demo session

---

## COMPONENT LIBRARY

### Action Type Icons (40×40pt containers with gradients)

| Type | Icon | Background Gradient |
|------|------|---------------------|
| Edit | pencil (SF Symbol) | Orange gradient |
| Create | doc.badge.plus | Blue gradient |
| Delete | trash | Red gradient |
| Bash | terminal | Purple gradient |
| Tool | gearshape | Orange gradient |

### Button Styles

**Primary (CTA):**
- Height: 44pt
- Corner radius: 22pt (capsule)
- Fill: Linear gradient (color → color 80%)
- Text: 15pt bold, white

**Secondary (Outline):**
- Height: 44pt
- Corner radius: 22pt
- Border: 1pt white 30%
- Text: 15pt, secondary color

**Destructive:**
- Same as primary but red gradient
- Use for reject/delete actions

### Status Dots

- 8pt diameter circle
- Colors: Green (idle), Orange (running), Red (error), Gray (disconnected)
- Pulse animation for "running" state

### Progress Bars

- Height: 4pt
- Track: white 20%
- Fill: Orange gradient
- Corner radius: 2pt

### Cards

- Background: `#1C1C1E` (surface)
- Corner radius: 12pt
- Padding: 14pt all sides
- Optional: subtle background blur/material effect

---

## iOS COMPANION APP SCREENS

Design at iPhone 14 size (390×844pt).

### iOS SCREEN 1: Welcome

- Top third: Claude logo (80pt) + "Claude Watch" title
- Middle: "Pair your Apple Watch with Claude Code in seconds"
- Primary CTA: "📷 Scan QR Code" (orange, full width)
- Divider: "── or ──"
- Secondary: "Enter code manually" (text link)
- Footer: "Already paired? Check status"

### iOS SCREEN 2: QR Scanner

- Close button (top left)
- Full-width camera viewfinder
- QR target frame (200×200pt, orange corners)
- Instructions: "Point camera at the QR code in your Claude Code terminal"
- Fallback: "Enter code manually"

### iOS SCREEN 3: QR Scanned Success

- Green checkmark animation
- "Code Verified!" title
- Code display: "ABC-123"
- Progress card: "📲 Syncing to Apple Watch..."
- Progress bar with percentage
- "Keep this app open"

### iOS SCREEN 4: Connected

- Large green checkmark
- "Connected!" title
- Card showing:
  - Watch icon
  - Status: "● Connected"
  - Paired time
  - Code
- "Done" button (orange)
- "Pair a different device" link

---

## COMPLICATIONS

Design for:
- **Circular** (42×42pt): Progress ring with Claude icon center
- **Rectangular** (160×52pt): Status text + task name + progress
- **Corner** (arc): Progress percentage arc
- **Inline** (text): "Claude: 67%"

States: Idle (green check), Running (orange pulse), Error (red warning)

---

## PROTOTYPING FLOWS

### Flow 1: First Launch
Splash → Consent 1 → Consent 2 → Consent 3 → Main (Unpaired)

### Flow 2: Pairing
Main (Unpaired) → Pair Now → Pairing View → Connecting → Main (Connected)

### Flow 3: Single Approval
Notification → Main (1 Pending) → Tap Approve → Toast → Main (Clear)

### Flow 4: Bulk Approval
Main (5 Pending) → Approve All → Confirm Dialog → Toast → Main (Clear)

### Flow 5: Rejection
Main (Pending) → Tap Reject → Toast → Main (Updated Queue)

### Flow 6: Error Recovery
Main → Disconnected → Retry → Reconnecting → Main (Connected)

---

## ACCESSIBILITY NOTES

- All touch targets: minimum 44×44pt
- Text contrast: minimum 4.5:1 ratio
- Don't use color alone for meaning (add icons)
- Support Dynamic Type scaling
- VoiceOver labels for all interactive elements

---

## OUTPUT REQUEST

Generate high-fidelity mockups for all screens listed above, following:
1. Apple Watch 45mm dimensions (198×242pt)
2. Pure black (#000000) backgrounds
3. Claude Orange (#FF9500) as primary accent
4. SF Pro typography
5. watchOS native styling (no iOS/Android influences)
6. Dark mode only

For iOS companion screens, use iPhone 14 dimensions (390×844pt) with matching color system.

---

*Use this prompt with Google AI Studio or Figma Make to generate the complete Claude Watch design system.*
