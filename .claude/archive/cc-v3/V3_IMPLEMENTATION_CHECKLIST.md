# Claude Watch V3 Implementation Checklist

> **Source**: V3 Pencil Design Analysis + Verification Audit
> **Last Updated**: 2026-01-26
> **Audit Date**: 2026-01-26
> **Estimated Effort**: 2-3 days (revised from 9-12 days after audit)

---

## Audit Summary

A verification audit was performed to identify what already exists vs what needs to be built.

### ✅ Already Implemented (No Work Needed)

| Component | File | Status |
|-----------|------|--------|
| Complications (4 types) | `ComplicationViews.swift` | Circular, Rectangular, Corner, Inline |
| ActionTier enum | `ActionTier.swift` | Full with low/medium/high + TierBadge |
| BreathingAnimation | `BreathingAnimation.swift` | Modifier + BreathingCircle + ClaudeFaceLogo |
| ApprovalQueueView | `ApprovalQueueView.swift` | Tiered cards, Approve All, Tier 3 warnings |
| HistoryView | `HistoryView.swift` | Timeline with day grouping |
| ActivityStore | `ActivityStore.swift` | Persistence layer |
| ActivityEvent | `ActivityEvent.swift` | Event model |

### ❌ Actually Missing (Work Required)

| Component | Priority | Effort |
|-----------|----------|--------|
| 3 new colors in Claude.swift | P0 | 15 min |
| 3 new ClaudeState cases | P0 | 30 min |
| Update ClaudeStateDot | P0 | 15 min |
| Mode Indicators (Normal/Plan/Auto) | P1 | 1 hour |
| AmbientGlow view | P2 | 30 min |
| Update Complications to use Claude colors | P1 | 30 min |

---

## Priority Definitions

| Priority | Meaning | Deadline |
|----------|---------|----------|
| **P0** | Ship blocker - Must complete | Before any release |
| **P1** | Important - Complete before TestFlight | TestFlight release |
| **P2** | Nice to have - Polish items | App Store release |

---

## Phase 1: Design System Updates (P0)

**Files**: `ClaudeWatch/DesignSystem/Claude.swift`, `ClaudeWatch/Models/ClaudeState.swift`
**Estimated**: 1 hour

### Colors (Claude.swift)

- [ ] Add `Claude.plan` color (`#5E5CE6`)
- [ ] Add `Claude.context` color (`#FFD60A`)
- [ ] Add `Claude.question` color (`#BF5AF2`)

### ClaudeState Enum (ClaudeState.swift)

- [ ] Add `.plan` case
- [ ] Add `.context` case
- [ ] Add `.question` case
- [ ] Update `displayName` computed property
- [ ] Update `icon` computed property
- [ ] Update `color` computed property
- [ ] Update `hexColor` computed property
- [ ] Update `init(from sessionStatus:)` if needed

### ClaudeStateDot (Already exists - just needs new colors)

The `ClaudeStateDot` view in `ClaudeState.swift` will automatically work with new states once the enum is updated.

---

## Phase 2: Mode Indicators (P1)

**New File**: `ClaudeWatch/Components/ModeIndicator.swift`
**Estimated**: 1 hour

### Create ModeIndicator Component

- [ ] Create `AgentMode` enum
  ```swift
  enum AgentMode: String, CaseIterable {
      case normal  // Green circle + "N"
      case plan    // Purple square + "P"
      case auto    // Orange pill + "A"
  }
  ```
- [ ] Create `ModeIndicator` view
  - [ ] Normal: Green circle with "N"
  - [ ] Plan: Purple rounded square with "P"
  - [ ] Auto: Orange pill with "A"
- [ ] Add to status bar when mode changes

---

## Phase 3: Complication Styling Update (P1)

**File**: `ClaudeWatch/Complications/ComplicationViews.swift`
**Estimated**: 30 min

### Update to use Claude.swift colors

- [ ] Replace `Color.green` → `Claude.success`
- [ ] Replace `Color.orange` → `Claude.warning`
- [ ] Replace `Color.purple` → `Claude.question` (model color)
- [ ] Test on all complication families

---

## Phase 4: Visual Polish (P2)

**New File**: `ClaudeWatch/Components/AmbientGlow.swift`
**Estimated**: 30 min

### Create AmbientGlow Component

- [ ] Create `AmbientGlow` view
  ```swift
  struct AmbientGlow: View {
      let color: Color

      var body: some View {
          Ellipse()
              .fill(color.opacity(0.18))
              .frame(width: 100, height: 80)
              .blur(radius: 35)
      }
  }
  ```
- [ ] Add convenience initializer for ClaudeState
- [ ] Respect Reduce Motion setting
- [ ] Add to approval screens (optional)

---

## Verification Checklist

### Before TestFlight

- [ ] All P0 items complete
- [ ] All P1 items complete
- [ ] Build succeeds with no warnings
- [ ] Complications update with new colors
- [ ] All states render correctly

### Before App Store

- [ ] All P2 items complete
- [ ] AmbientGlow tested with Reduce Motion

---

## File Summary

### Files to Modify

```
ClaudeWatch/
├── DesignSystem/
│   └── Claude.swift              # ADD 3 colors
├── Models/
│   └── ClaudeState.swift         # ADD 3 cases
└── Complications/
    └── ComplicationViews.swift   # UPDATE color references
```

### New Files to Create

```
ClaudeWatch/
├── Components/
│   ├── ModeIndicator.swift       # NEW - Mode badges
│   └── AmbientGlow.swift         # NEW - Glow effects (P2)
```

---

## Timeline (Revised)

| Day | Phase | Deliverables |
|-----|-------|--------------|
| 1 (AM) | Phase 1 | Colors, states |
| 1 (PM) | Phase 2 | Mode Indicators |
| 2 (AM) | Phase 3 | Complication styling |
| 2 (PM) | Phase 4 | AmbientGlow (if time) |
| 2 (PM) | Testing | All states, complications |

**Total: 1-2 days** (reduced from original 9-12 day estimate)

---

## What Changed from Original Plan

| Original Claim | Reality After Audit |
|----------------|-------------------|
| "No complications" | ✅ 4 types exist in ComplicationViews.swift |
| "Need ActionTier" | ✅ Full implementation in ActionTier.swift |
| "Need BreathingAnimation" | ✅ Exists in BreathingAnimation.swift |
| "Need ApprovalQueue" | ✅ Exists in ApprovalQueueView.swift |
| "Need HistoryView" | ✅ Exists in HistoryView.swift |
| "9-12 days effort" | 1-2 days actual (90% already done) |
