# V3 Design-Code Parity Task

> **Created:** 2026-01-27
> **Status:** IN PROGRESS
> **Problem:** Code does NOT match designs + Design file is a mess

---

## Goal

**TWO-PART CLEANUP:**

1. **Clean up v3.pen** - Remove old V2 cruft, organize into clear V3 structure
2. **Fix code to match** - Update Swift views to match the cleaned-up designs

---

## Current State of v3.pen (The Problem)

The Pencil design file is currently a **mishmash**:

- Old V2 design elements mixed with V3
- Incomplete screens and flows
- Past iterations not cleaned up
- No clear organization or hierarchy
- **Not professional / not ship-ready**

### What v3.pen Contains Now (Messy)

From editor state, these frames exist:
- `Flow A: Onboarding & Session Dashboard`
- `flowsContainer`
- `Flow G: Notification → Task List → Session`
- `Design System`
- `Flow I: Complications`
- `Flow J: Watch Faces`
- `Current Implementation (from Codebase)`
- `V3 Implementation Guide`
- `V3 Dev-Ready Specification`
- `V3 Design Gaps - Missing Flows`
- ...and more

**This needs to be cleaned up to have ONLY:**
1. A clear Design System frame
2. V3 screens organized by flow (A, B, C, D, E, G)
3. Dev-ready specs for handoff

---

## Part 1: Design File Cleanup (v3.pen)

### DELETE or Archive
- [ ] Old V2 flows/screens that are superseded
- [ ] "Current Implementation" reference frames
- [ ] Duplicate components
- [ ] Draft/exploration frames
- [ ] Any frame labeled "old", "v2", "draft", etc.

### KEEP and Organize
- [ ] **Design System** - Clean set of 52 components
- [ ] **Flow A** - 6 screens (Onboarding & Session)
- [ ] **Flow B** - 2 screens (Working & Paused)
- [ ] **Flow C** - 4 screens (Approval Tiers)
- [ ] **Flow D** - 2 screens (Outcomes)
- [ ] **Flow E** - 2 screens (Question & Context)
- [ ] **Flow G** - 5 screens (Full Lifecycle)
- [ ] **Complications** - 4 types (if V3 scope)

### Reorganize Structure
```
v3.pen
├── 00 - Design System (tokens, components)
├── 01 - Flow A: Onboarding
├── 02 - Flow B: Core States
├── 03 - Flow C: Approval
├── 04 - Flow D: Outcomes
├── 05 - Flow E: Special Flows
├── 06 - Flow G: Full Lifecycle
└── 07 - Complications (stretch)
```

---

## Part 2: Code-Design Parity

---

## Problem Statement

The current codebase has drifted from the approved V3 designs. We need:

1. **Design System Audit** - Verify `Claude.swift` matches Pencil design tokens
2. **Screen-by-Screen Parity** - Each view must match its Pencil counterpart exactly
3. **Component Consistency** - Reusable components must use correct specs
4. **Design-Lead Approval** - Final sign-off that implementation matches design

---

## Design File Location

```
.claude/design/v3.pen
```

This file contains:
- **Design System** (Frame ID: `Q0NWg`) - 52 reusable components, 11 color tokens
- **21 Screens** across 6 flows (A, B, C, D, E, G)
- **Component Specs** - Exact sizing, spacing, colors, typography

---

## V3 Screen Inventory (from V3_SCREEN_SPECS.md)

| Flow | Screens | Priority |
|------|---------|----------|
| **A: Onboarding & Session** | Unpaired, Pairing Code, Fresh Session, Dashboard, Long Idle, History | P0 |
| **B: Core States** | Working, Paused | P0 |
| **C: Approval** | Tier 1, Tier 2, Tier 3, Queue | P0 |
| **D: Outcomes** | Success, Error | P0 |
| **E: V2 Kept Flows** | Question, Context Warning | P1 |
| **G: Full Lifecycle** | Notification, Approval, Queue, Working, Complete | P1 |

---

## Design System Tokens (from V3_DESIGN_SYSTEM.md)

### Colors to Verify in Claude.swift

| Token | Hex | Usage |
|-------|-----|-------|
| Brand | `#d97757` | Logo, headers, primary accent |
| Success | `#34C759` | Approve, Tier 1 |
| Warning | `#FF9500` | Attention, Tier 2 |
| Error | `#FF3B30` | Reject, Tier 3 |
| Working | `#007AFF` | Active, progress |
| Plan | `#5E5CE6` | Plan mode |
| Context | `#FFD60A` | Context warning |
| Question | `#BF5AF2` | Question/input needed |
| Muted/Idle | `#8E8E93` | Inactive, secondary |

### Typography

| Size | Weight | Usage |
|------|--------|-------|
| 17pt | 600 Inter | Card titles |
| 15pt | 600 Inter | Card primary |
| 14pt | 600 Inter | Button labels |
| 13pt | normal Inter | Body |
| 12pt | normal Inter | Descriptions |
| 11pt | 600 Inter | Status text |
| 10pt | 700 JetBrains Mono | Badges |

### Spacing

| Element | Radius | Padding |
|---------|--------|---------|
| WatchFrame | 40px | 16px |
| Cards | 16px | 14-16px |
| Buttons | 20px | 12px × 24px |
| Badges | 6px | 2px × 8px |
| Status dots | 4px (8×8) | - |

---

## Parity Checklist

### Phase 1: Design System (Claude.swift)

- [ ] All 11 color tokens present and correct hex values
- [ ] Radius tokens match (40, 16, 20, 6, 4)
- [ ] Card gradient matches spec (`#ffffff12` → `#ffffff08`)
- [ ] Glow specs correct (100×80, 35px blur, 30% opacity)

### Phase 2: Components

- [ ] StatusBar - dot + label + time
- [ ] TaskCard - badge + title + description
- [ ] ApproveButton - green gradient, black text
- [ ] RejectButton - red fill, white text
- [ ] BadgeEdit/Run/Delete - correct colors and sizing
- [ ] StatusDots (8 variants) - 8×8, 4px radius
- [ ] ProgressBar - bar + percentage
- [ ] ActionButtonRow - Yes/No pair

### Phase 3: Screens (P0)

- [ ] A1: Unpaired - Claude icon, "Pair with Code" button
- [ ] A2: Pairing Code - 4 CodeDigits, countdown timer
- [ ] A3: Fresh Session - "Waiting for Claude..."
- [ ] A4: Dashboard - ActivityCard with stats
- [ ] B1: Working - Task checklist, progress bar, pause button at BOTTOM
- [ ] B2: Paused - Resume button, preserved state
- [ ] C1: Tier 1 - Green glow, EDIT badge, double-tap hint
- [ ] C2: Tier 2 - Orange glow, RUN badge
- [ ] C3: Tier 3 - Red glow, DELETE badge, "Review on Mac" primary
- [ ] C4: Queue - Multiple items, "Approve All"
- [ ] D1: Success - Checkmark, bullet summary, "Dismiss"
- [ ] D2: Error - X icon, error details, "Retry"/"View"

### Phase 4: Screens (P1)

- [ ] E1: Question - Purple glow, Yes/No buttons
- [ ] E2: Context Warning - Yellow glow, progress bar, threshold %
- [ ] A5: Long Idle - Dimmer glow, idle indicator
- [ ] A6: History - Timeline events, day grouping

---

## Key Discrepancies to Fix

Based on TRIAGE.md "Fixes Applied", these were marked fixed but need verification against actual Pencil designs:

1. **Pause button position** - Must be at BOTTOM of Working view
2. **State headers** - All screens need "● State" with colored dot + time
3. **Button styling** - Approve=green gradient, Reject=red solid
4. **Badge colors** - EDIT=green, RUN=orange, DELETE=red
5. **Glow effects** - Ambient glow behind cards per state

---

## Process

### Step 1: Open v3.pen in Pencil
```
File: .claude/design/v3.pen
```

### Step 2: Screenshot Each Screen
Use Pencil MCP `get_screenshot` for each screen node ID.

### Step 3: Compare to Code
Read corresponding Swift view file and compare visually.

### Step 4: Document Discrepancies
Create specific issues for each mismatch.

### Step 5: Fix Code to Match Design
Update Swift views to match Pencil exactly.

### Step 6: Design-Lead Review
Get sign-off that implementation matches design.

---

## Files to Modify

| File | What to Check |
|------|---------------|
| `DesignSystem/Claude.swift` | Colors, radii, modifiers |
| `Views/StateViews.swift` | Unpaired, Connected, Idle, Offline |
| `Views/PairingView.swift` | Pairing code screen |
| `Views/WorkingView.swift` | Working state, task list |
| `Views/PausedView.swift` | Paused state |
| `Views/ApprovalQueueView.swift` | Tiered approvals, queue |
| `Views/TaskOutcomeView.swift` | Success/Error outcomes |
| `Views/QuestionResponseView.swift` | Question flow |
| `Views/ContextWarningView.swift` | Context warning |
| `Views/HistoryView.swift` | Timeline history |

---

## Success Criteria

### Part 1: Design File (v3.pen)
- [ ] **Clean structure** - Only V3 content, organized by flow
- [ ] **No cruft** - Old V2 elements removed or archived
- [ ] **Professional** - Ready for developer handoff
- [ ] **Complete** - All 21 screens present with specs
- [ ] **Design System** - Clear, documented component library

### Part 2: Code Implementation
- [ ] **Visual Parity** - Screenshots of running app match Pencil designs
- [ ] **Token Compliance** - All colors, sizes, radii from Claude.swift
- [ ] **Component Reuse** - Shared components used consistently
- [ ] **Design-Lead Approval** - Sign-off from /design-lead skill

---

## What "Professional" Means

A professional design file for handoff should have:

1. **Clear naming** - Frames named by flow/screen (not "Frame 1", "Copy of...")
2. **Consistent spacing** - Screens aligned on a grid
3. **No duplicates** - One source of truth per component
4. **Version clarity** - Clear that this is V3, no V2 remnants
5. **Dev specs visible** - Spacing, colors, typography annotated
6. **Exportable** - Designer could hand this to any developer

---

## Next Steps

1. Restart Claude Code session
2. Reconnect Pencil MCP
3. Open v3.pen
4. Run `/design-lead` to audit screen-by-screen
5. Fix discrepancies in priority order (P0 → P1)
6. Get final approval
