# Claude Watch V3 vs V2 Delta Analysis

> **Source**: `/Users/dfotesco/CLAUDE/v2.pen` vs current implementation
> **Last Updated**: 2026-01-26

---

## Executive Summary

The V3 design adds **3 new colors**, **8 new states**, **4 complication types**, and **6 new screens** compared to the current V2 implementation. This document details every delta requiring implementation.

---

## Color System Delta

### New Colors to Add

| Token | Hex | Current Status | Priority |
|-------|-----|----------------|----------|
| **Plan** | `#5E5CE6` | Missing | P0 |
| **Context** | `#FFD60A` | Missing | P0 |
| **Question** | `#BF5AF2` | Missing | P0 |

### Colors That Match

| Token | V3 Hex | Current Hex | Status |
|-------|--------|-------------|--------|
| Brand | `#d97757` | `#d97757` | ✅ Match |
| Success | `#34C759` | `#34C759` | ✅ Match |
| Warning | `#FF9500` | `#FF9500` | ✅ Match |
| Error | `#FF3B30` | `#FF3B30` | ✅ Match |
| Working | `#007AFF` | `#007AFF` | ✅ Match |
| Idle | `#8E8E93` | `#8E8E93` | ✅ Match |

### Required Claude.swift Changes

```swift
// ADD these new colors
extension Claude {
    /// Plan mode indicator - purple
    static let plan = Color(hex: "#5E5CE6")

    /// Context usage warning - yellow
    static let context = Color(hex: "#FFD60A")

    /// Question/input needed - purple
    static let question = Color(hex: "#BF5AF2")
}
```

---

## ClaudeState Enum Delta

### Current Implementation (5 states)

```swift
enum ClaudeState {
    case idle      // #8E8E93
    case working   // #007AFF
    case approval  // #FF9500
    case success   // #34C759
    case error     // #FF3B30
}
```

### V3 Required (8+ states)

```swift
enum ClaudeState {
    // Existing
    case idle           // #8E8E93
    case working        // #007AFF
    case approval       // #FF9500
    case success        // #34C759
    case error          // #FF3B30

    // NEW
    case plan           // #5E5CE6  - Plan mode active
    case context        // #FFD60A  - Context warning
    case question       // #BF5AF2  - Input needed

    // OPTIONAL sub-states
    case approvalTier1  // #34C759  - Low risk (Edit)
    case approvalTier2  // #FF9500  - Medium risk (Bash)
    case approvalTier3  // #FF3B30  - High risk (Delete)
}
```

### Migration Strategy

**Option A**: Add new cases to existing enum
- Pro: Simple
- Con: Breaking change if switch statements aren't exhaustive

**Option B**: Create `ClaudeVisualState` for UI-only states
- Pro: Non-breaking
- Con: Two enums to manage

**Recommendation**: Option A with exhaustive switch handling

---

## Status Dot Delta

### Current Implementation

```swift
struct ClaudeStateDot: View {
    let state: ClaudeState

    var color: Color {
        switch state {
        case .idle: return Claude.idle
        case .working: return Claude.info
        case .approval: return Claude.warning
        case .success: return Claude.success
        case .error: return Claude.danger
        }
    }
}
```

### V3 Required (8 dots)

| Dot | Color | Node ID | Status |
|-----|-------|---------|--------|
| Success | `#34C759` | `2POpe` | ✅ Exists |
| Warning | `#FF9500` | `vsTAG` | ✅ Exists |
| Error | `#FF3B30` | `gZ7Il` | ✅ Exists |
| Working | `#007AFF` | `EsmaD` | ✅ Exists |
| Idle | `#8E8E93` | `SZbC7` | ✅ Exists |
| **Question** | `#BF5AF2` | `XraV9` | ❌ **Add** |
| **Context** | `#FFD60A` | `qaZyx` | ❌ **Add** |
| **Brand** | `#d97757` | `qKzkx` | ❌ **Add** |

---

## Component Delta

### Missing Components

| Component | V3 Node ID | Current | Priority |
|-----------|------------|---------|----------|
| ModeNormal | `UTp3g` | Missing | P1 |
| ModePlan | `x66K4` | Missing | P1 |
| ModeAuto | `py2vf` | Missing | P1 |
| GlowSuccess | `Js5cj` | Missing | P2 |
| GlowWarning | `vRGO1` | Missing | P2 |
| GlowError | `cxyD9` | Missing | P2 |
| GlowBrand | `6stpW` | Missing | P2 |
| GlowWorking | `jIrsu` | Missing | P2 |
| GlowPlan | `gTjM3` | Missing | P2 |
| GlowContext | `v4qmR` | Missing | P2 |
| GlowQuestion | `5sGcV` | Missing | P2 |
| ActionButtonRow | `s1LF1` | Missing | P1 |

### Components That Exist (verify styling)

| Component | V3 Node ID | Current File | Status |
|-----------|------------|--------------|--------|
| StatusBar | `owt0z` | StateViews.swift | ⚠️ Verify |
| TaskCard | `DyPD1` | ActionViews.swift | ⚠️ Verify |
| ApproveButton | `hRRRh` | ActionViews.swift | ⚠️ Verify |
| RejectButton | `HWrpH` | ActionViews.swift | ⚠️ Verify |
| ProgressBar | `lAs4K` | WorkingView.swift | ⚠️ Verify |
| FooterNav | `bnp90` | MainView.swift | ⚠️ Verify |
| QueueItem | `Zn2U9` | ActionViews.swift | ⚠️ Verify |
| StateCard | `GQAr2` | TaskOutcomeView.swift | ⚠️ Verify |

---

## Screen Delta

### New Screens to Implement

| Screen | Flow | Current | Priority |
|--------|------|---------|----------|
| Fresh Session | A3 | Missing | P1 |
| Long Idle | A5 | Missing | P2 |
| History Timeline | A6 | ✅ Exists | - |
| Tier 3 Dangerous | C3 | Missing | P0 |
| Approval Queue | C4 | Partial | P1 |
| Question Response | E1 | ✅ Exists | ⚠️ Verify |
| Context Warning | E2 | ✅ Exists | ⚠️ Verify |

### Screens to Update

| Screen | Changes Needed | Priority |
|--------|---------------|----------|
| Working | Add progress %, collapsible task list | P0 |
| Paused | Match V3 styling | P1 |
| Task Outcome | Add bullet summary | P0 |
| Approval (Tier 1/2) | Add glow effects, verify colors | P1 |

---

## Typography Delta

### Font Family Changes

| Element | Current | V3 Spec | Decision |
|---------|---------|---------|----------|
| Titles | System | Poppins | **Keep System** (smaller bundle) |
| Body | System | Inter | **Keep System** |
| Code/Badges | `.claudeMono` | JetBrains Mono | **Keep System Mono** |

**Rationale**: System fonts provide better accessibility, smaller bundle size, and native feel on watchOS.

### Font Size Adjustments

| Element | Current | V3 Spec | Action |
|---------|---------|---------|--------|
| Card title | 15pt | 15pt | ✅ Match |
| Badge text | 10pt | 10pt | ✅ Match |
| Status text | 11pt | 11pt | ✅ Match |
| Hint text | 11pt | 9pt | ⚠️ Reduce |
| Progress % | 14pt | 10pt | ⚠️ Reduce |

---

## Glow Effects Delta

### V3 Glow Specification

```swift
// All glows share these specs:
// - Size: 100×80 ellipse
// - Blur: 35px
// - Opacity: 30% (hex suffix 30)

struct AmbientGlow: View {
    let state: ClaudeState

    var body: some View {
        Ellipse()
            .fill(state.color.opacity(0.18))
            .frame(width: 100, height: 80)
            .blur(radius: 35)
    }
}
```

### Implementation Approach

1. Create reusable `AmbientGlow` view
2. Position behind main content cards
3. Animate opacity for breathing effect (optional)
4. Respect Reduce Motion accessibility setting

---

## Complications Delta

### Current Status: ✅ ALREADY IMPLEMENTED

Complications exist in `ClaudeWatch/Complications/ComplicationViews.swift`:
- **CircularWidgetView** - Progress ring with icon/count
- **RectangularWidgetView** - Full status with task name, progress bar
- **CornerWidgetView** - Compact with percentage
- **InlineWidgetView** - Text-only status line

### Styling Gap: V3 vs Current

| Aspect | Current | V3 Spec | Action |
|--------|---------|---------|--------|
| Progress color | `Color.green` | `Claude.success` | ⚠️ Update |
| Icon color (approval) | `Color.orange` | `Claude.warning` | ⚠️ Update |
| Text styling | System fonts | System fonts | ✅ Match |
| Always-on mode | Implemented | Required | ✅ Match |

### Required Updates (Not New Files)

Update `ComplicationViews.swift` to use Claude.swift colors:
- Replace `Color.green` → `Claude.success`
- Replace `Color.orange` → `Claude.warning`
- Consider adding glow effects (P2)

---

## Badge System Delta

### Current Status: ✅ ALREADY IMPLEMENTED

`ActionTier` enum exists in `ClaudeWatch/Models/ActionTier.swift` with:
- **low** (green) - Read, Edit, Create operations
- **medium** (orange) - Write, MCP, simple Bash
- **high** (red) - Delete, rm -rf, sudo, dangerous commands

Includes `TierBadge` view component and full risk classification logic.

### V3 Naming Difference

| V3 Design | Current Implementation | Status |
|-----------|----------------------|--------|
| EDIT badge | TierBadge (low) | ✅ Match |
| RUN badge | TierBadge (medium) | ✅ Match |
| DELETE badge | TierBadge (high) | ✅ Match |

No changes needed - current implementation exceeds V3 spec with automatic risk classification.

---

## Card Background Delta

### Current

```swift
.background(.ultraThinMaterial)
```

### V3 Spec

```swift
// Linear gradient from top to bottom
LinearGradient(
    colors: [
        Color.white.opacity(0.07),  // #ffffff12
        Color.white.opacity(0.03)   // #ffffff08
    ],
    startPoint: .top,
    endPoint: .bottom
)
```

### Recommendation

Keep `.ultraThinMaterial` for native feel, or create hybrid:

```swift
.background {
    RoundedRectangle(cornerRadius: 16)
        .fill(.ultraThinMaterial.opacity(0.8))
        .overlay {
            LinearGradient(...)
                .opacity(0.5)
        }
}
```

---

## Migration Checklist

### Phase 1: Design System (Day 1)
- [ ] Add Plan, Context, Question colors to Claude.swift
- [ ] Expand ClaudeState enum
- [ ] Update ClaudeStateDot with new colors
- [ ] Add ActionTier enum
- [ ] Create ActionBadge component

### Phase 2: Core Updates (Day 2)
- [ ] Update WorkingView with progress % and task list
- [ ] Update TaskOutcomeView with bullet summary
- [ ] Add Tier 3 escape options to ApprovalView
- [ ] Verify Question/Context views match spec

### Phase 3: Complications (Days 3-5)
- [ ] Create ComplicationProvider
- [ ] Implement Corner complication
- [ ] Implement Circular complication
- [ ] Implement Rectangular complication
- [ ] Implement Graphic Extra Large
- [ ] Test on all watch faces

### Phase 4: New Screens (Days 6-7)
- [ ] Fresh Session screen
- [ ] Long Idle screen
- [ ] Approval Queue improvements

### Phase 5: Polish (Days 8-9)
- [ ] Add glow effects
- [ ] Mode indicators (Normal/Plan/Auto)
- [ ] Typography fine-tuning
- [ ] Animation polish

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Enum expansion breaks existing code | High | Exhaustive switches |
| Complications deadline | High | Start early, P0 |
| Typography bundle size | Low | Keep system fonts |
| Glow performance | Medium | Use sparingly, test |

---

## Summary

| Category | Items to Add/Change |
|----------|-------------------|
| Colors | +3 new |
| ClaudeState cases | +3 new |
| Status dots | +3 new |
| Components | +12 new |
| Screens | +3 new, ~5 updates |
| Complications | +4 types (from 0) |
