# feat: Claude Watch UX Improvement

## Enhancement Summary

**Deepened on:** 2026-01-17
**Sections enhanced:** 5 phases + cross-cutting concerns
**Research agents used:** 15 parallel agents (architecture, Swift, SwiftUI, performance, simplicity, patterns, accessibility, component extraction, Liquid Glass, learnings)

### Key Improvements
1. Added over-engineering prevention checklist based on documented learning (80% of planned features often already exist)
2. Integrated watchOS 26 deprecation patterns (WKExtension → WKApplication, native TextField for dictation)
3. Added async state management patterns to prevent loading spinner bugs
4. Enhanced state recovery with NavigationStack and atomic state reset patterns

### New Considerations Discovered
- Pre-planning code review is critical - read existing code before designing new components
- VoiceInputSheet should use native SwiftUI TextField (auto-enables dictation)
- All async operations need `defer { isLoading = false }` pattern
- NavigationStack is required at outermost level for toolbar visibility on watchOS

---

## Overview

Comprehensive UX improvement for Claude Watch, the watchOS companion app for Claude Code. This plan addresses component architecture, Liquid Glass design readiness, enhanced accessibility, and modern SwiftUI patterns to create a distinctive, production-grade wearable interface.

**Aesthetic Direction**: *Refined Minimalism with Claude Identity* - Clean, purposeful interfaces that feel premium and uniquely Claude. Orange as a confident accent, not a dominating theme. Glass materials for depth. Intentional motion that respects attention.

## Problem Statement

The current implementation has several architectural and UX challenges:

1. **Monolithic Architecture**: MainView.swift is 1445 lines containing 15+ embedded view structs
2. **Design System Fragmentation**: Claude color palette duplicated across 3 files with inconsistencies
3. **Accessibility Gaps**: Missing Reduce Motion support, high contrast adaptations, VoiceOver announcement timing
4. **Legacy Patterns**: Using `@ObservedObject` with singleton instead of `@Observable` macro
5. **Animation Inconsistency**: Mix of custom spring animations without centralized configuration
6. **Error Handling**: Silent failures with no user feedback for network errors

## Pre-Planning Checklist

> **Critical Learning**: From `docs/solutions/architecture-decisions/app-store-phase3-overengineering-prevention.md` - 80% of planned features in a previous phase already existed but weren't being utilized. This checklist prevents that.

Before implementing each phase:

- [ ] Identified 3+ key files related to this feature area
- [ ] Searched codebase for similar functionality with `grep`
- [ ] Documented existing implementations that could be reused
- [ ] Read actual code, not just descriptions or comments
- [ ] Plan length < 400 lines (if longer, break into phases)
- [ ] Duplication risk < 20% after modifications

## Proposed Solution

A phased approach to modernize the app while maintaining stability:

1. **Phase 1**: Extract and centralize design system
2. **Phase 2**: Component extraction from MainView.swift
3. **Phase 3**: Accessibility enhancements
4. **Phase 4**: Liquid Glass and animation modernization
5. **Phase 5**: Error handling and state recovery

## Technical Approach

### Architecture

#### Target File Structure (Flattened)
```
ClaudeWatch/
├── App/
│   └── ClaudeWatchApp.swift
├── DesignSystem/
│   └── Claude.swift                    # NEW: Colors, materials, spacing, button styles, animations
├── Views/
│   ├── MainView.swift                  # REFACTORED: ~200 lines, composition only
│   ├── ConsentView.swift
│   ├── PairingView.swift               # ENHANCED: Claude-styled buttons
│   ├── StateViews.swift                # EXTRACTED: Empty, Offline, Reconnecting, AlwaysOn
│   ├── ActionViews.swift               # EXTRACTED: ActionQueue, PrimaryActionCard, CompactActionCard
│   ├── CommandViews.swift              # EXTRACTED: CommandGrid, CommandButton, ModeSelector
│   └── SheetViews.swift                # EXTRACTED: VoiceInputSheet, SettingsSheet
├── Services/
│   └── WatchService.swift
└── Complications/
    └── ComplicationViews.swift
```

> **Note**: Flattened from 14 files across 6 subdirectories to 4 view files + 1 design system file.
> Related views stay together for easier navigation. Extract to subdirectories only if files exceed 300 lines.

### Implementation Phases

#### Phase 1: Design System Centralization

**Tasks:**
- [ ] Create `DesignSystem/Claude.swift` with colors, materials, spacing, button styles, and animations
- [ ] Remove duplicate `Claude` enum from ConsentView.swift and ComplicationViews.swift
- [ ] Update all files to import from centralized design system

**Success Criteria:**
- Single source of truth for all design tokens
- No color definitions outside DesignSystem/

### Research Insights: Phase 1

**Best Practices:**
- Use `public` access modifiers for design tokens to avoid import issues
- Consider using `Color(uiColor:)` for dynamic trait-aware colors
- Static properties on enums have zero allocation overhead

**Simplicity Review:**
- The nested enum structure (Claude.Materials, Claude.Spacing) is well-organized
- Consider if `Claude.Radius` is needed - watchOS uses standard corner radii
- Start with colors only, add spacing/radius if actually used

**Performance Considerations:**
- Static Color values are computed once and cached by SwiftUI
- Materials (.ultraThinMaterial) have GPU cost - use sparingly on older watches

**Key Code: Claude.swift**
```swift
// ClaudeWatch/DesignSystem/Claude.swift
import SwiftUI

public enum Claude {
    // MARK: - Brand Colors
    public static let orange = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let orangeLight = Color(red: 1.0, green: 0.702, blue: 0.251)
    public static let orangeDark = Color(red: 0.8, green: 0.467, blue: 0.0)

    // MARK: - Semantic Colors (Apple System Aligned)
    public static let success = Color(red: 0.204, green: 0.780, blue: 0.349)
    public static let danger = Color(red: 1.0, green: 0.231, blue: 0.188)
    public static let warning = Color(red: 1.0, green: 0.584, blue: 0.0)
    public static let info = Color(red: 0.0, green: 0.478, blue: 1.0)

    // MARK: - Surface Colors
    public static let background = Color.black
    public static let surface1 = Color(red: 0.110, green: 0.110, blue: 0.118)
    public static let surface2 = Color(red: 0.173, green: 0.173, blue: 0.180)
    public static let surface3 = Color(red: 0.227, green: 0.227, blue: 0.235)

    // MARK: - Text Colors
    public static let textPrimary = Color.white
    public static let textSecondary = Color(white: 0.6)
    public static let textTertiary = Color(white: 0.4)

    // MARK: - Materials
    public enum Materials {
        public static let card: some ShapeStyle = .ultraThinMaterial
        public static let overlay: some ShapeStyle = .thinMaterial
        public static let prominent: some ShapeStyle = .regularMaterial
    }

    // MARK: - Spacing
    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 12
        public static let lg: CGFloat = 16
        public static let xl: CGFloat = 20
    }

    // MARK: - Corner Radii
    public enum Radius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 14
        public static let large: CGFloat = 16
        public static let xlarge: CGFloat = 20
    }
}
```

---

#### Phase 2: Component Extraction (Flattened)

**Tasks:**
- [ ] Create `Views/StateViews.swift` with EmptyStateView, OfflineStateView, ReconnectingView, AlwaysOnDisplayView
- [ ] Create `Views/ActionViews.swift` with ActionQueueView, PrimaryActionCard, CompactActionCard, StatusHeader
- [ ] Create `Views/CommandViews.swift` with CommandGrid, CommandButton, ModeSelector
- [ ] Create `Views/SheetViews.swift` with VoiceInputSheet, SettingsSheet
- [ ] Refactor MainView.swift to compose extracted components
- [ ] Add SwiftUI previews to each view file

**Success Criteria:**
- MainView.swift under 250 lines
- Each view file under 300 lines
- All view files have working previews

**Extraction Order:**
1. StateViews.swift (no dependencies)
2. ActionViews.swift (depends on Claude design system)
3. CommandViews.swift (depends on service)
4. SheetViews.swift (depends on multiple components)

### Research Insights: Phase 2

**Component Extraction Best Practices:**
- Extract when a view is used 2+ times OR exceeds 100 lines
- Keep views under 100 lines for watchOS (per project skill: swiftui-components)
- Prefer closures over Bindings for action callbacks
- Use `@Environment(\.dismiss)` for sheet dismissal

**State Passing Strategy:**
```swift
// PREFERRED: Closures for actions
struct PrimaryActionCard: View {
    let action: PendingAction
    let onApprove: () -> Void
    let onReject: () -> Void
}

// AVOID: Passing entire service
struct PrimaryActionCard: View {
    @ObservedObject var service: WatchService  // Too coupled
}
```

**Preview Strategy for Service-Dependent Components:**
```swift
#Preview("Empty State") {
    EmptyStateView(
        onLoadDemo: { },
        onPairWithCode: { }
    )
}

#Preview("With Actions") {
    ActionQueueView(
        actions: [.preview],
        onApprove: { _ in },
        onReject: { _ in }
    )
}
```

**watchOS-Specific Patterns (from project skill):**
- Apple Watch screens are 40-49mm - prefer single-tap interactions
- Use SF Symbols for icons
- Test on multiple watch sizes
- Vertical scrolling should be used sparingly

**Edge Cases:**
- Empty state when no actions pending
- Loading state while fetching
- Error state for network failures
- Transition animations between states

---

#### Phase 3: Accessibility Enhancements

**Tasks:**
- [ ] Add `@Environment(\.accessibilityReduceMotion)` checks to all animated views
- [ ] Add `@Environment(\.accessibilityReduceTransparency)` for material fallbacks
- [ ] Add `@Environment(\.colorSchemeContrast)` for high contrast adaptations
- [ ] Fix VoiceOver announcement timing for recording state changes
- [ ] Add `.accessibilityAction` for AssistiveTouch hand gestures
- [ ] Ensure Approve button comes before Reject in accessibility order
- [ ] Add spoken mode change confirmations for VoiceOver users

**Success Criteria:**
- All animations respect Reduce Motion preference
- VoiceOver navigation order is logical (primary actions first)
- AssistiveTouch users can approve/reject via hand gestures

### Research Insights: Phase 3

**VoiceOver Best Practices for watchOS:**
```swift
// Announce state changes with proper timing
.onChange(of: isRecording) { _, newValue in
    if newValue {
        UIAccessibility.post(notification: .announcement, argument: "Recording started")
    } else {
        UIAccessibility.post(notification: .announcement, argument: "Recording stopped")
    }
}

// Use accessibilityLabel for custom controls
Button { } label: {
    Image(systemName: "checkmark")
}
.accessibilityLabel("Approve this action")
.accessibilityHint("Double tap to approve the pending code change")
```

**AssistiveTouch Hand Gestures:**
```swift
// Enable hand gesture shortcuts for primary actions
.accessibilityAction(.magicTap) {
    // Magic tap (two-finger double-tap) = primary action
    approveCurrentAction()
}
.accessibilityAction(.escape) {
    // Escape (two-finger scrub) = dismiss/cancel
    dismiss()
}
```

**Reduce Motion Implementation:**
```swift
struct AnimatedStatusIcon: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @State private var pulsePhase: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Claude.orange)
            .scaleEffect(reduceMotion ? 1.0 : (1 + pulsePhase * 0.2))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 2).repeatForever(),
                value: pulsePhase
            )
            .onAppear {
                if !reduceMotion {
                    pulsePhase = 1
                }
            }
    }
}
```

**Reduce Transparency Fallback:**
```swift
@Environment(\.accessibilityReduceTransparency) var reduceTransparency

var body: some View {
    content
        .background(
            reduceTransparency
                ? Claude.surface1  // Solid fallback
                : Claude.Materials.card  // Glass material
        )
}
```

**WCAG 2.1 AA Requirements:**
- Minimum contrast ratio: 4.5:1 for normal text
- Large text (18pt+): 3:1 minimum
- Claude.textSecondary (0.6 white on black) = 9.5:1 - passes
- All orange on black = 4.8:1 - passes, but verify light shades

---

#### Phase 4: Liquid Glass & Animation Modernization

**Tasks:**
- [ ] Replace manual haptics with `.sensoryFeedback()` modifier where appropriate
- [ ] Add `.symbolEffect()` to status icons for modern animations
- [ ] Prepare materials for Liquid Glass (iOS/watchOS 26) with conditional checks
- [ ] Migrate to new spring API: `.spring(duration:bounce:)` and presets like `.bouncy`, `.smooth`
- [ ] Add `.contentTransition(.symbolEffect)` for icon state changes
- [ ] Create shared `ClaudeButtonStyle` with unified press feedback

**Success Criteria:**
- Consistent animation language across all views
- Ready for Liquid Glass when watchOS 26 ships
- Modern haptic feedback using SwiftUI modifiers

### Research Insights: Phase 4

**watchOS 26 Deprecation Patterns (from documented learning):**
> From `docs/solutions/build-errors/watchos26-deprecation-warnings-20260115.md`

```swift
// DEPRECATED: WKExtension.shared()
WKExtension.shared().isAutorotating = true

// MODERN: WKApplication.shared()
WKApplication.shared().isAutorotating = true

// Version-safe pattern:
if #available(watchOS 10, *) {
    WKApplication.shared().isAutorotating = true
} else {
    WKExtension.shared().isAutorotating = true
}
```

**VoiceInputSheet Modernization:**
> Native SwiftUI TextField automatically enables dictation on watchOS - no WatchKit APIs needed

```swift
// DEPRECATED: presentTextInputController with completion handlers
// MODERN: Native SwiftUI TextField
struct VoiceInputSheet: View {
    @State private var inputText = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack {
            TextField("Type or dictate...", text: $inputText)
                .focused($isTextFieldFocused)

            // Suggestion chips for common commands
            ScrollView(.horizontal) {
                HStack {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(suggestion) { inputText = suggestion }
                            .buttonStyle(.bordered)
                    }
                }
            }

            Button("Send") {
                WKInterfaceDevice.current().play(.success)
                onSubmit(inputText)
            }
        }
    }
}
```

**Modern Haptic Patterns:**
```swift
// PREFERRED: SwiftUI modifier (declarative)
.sensoryFeedback(.impact(weight: .medium), trigger: isPressed)
.sensoryFeedback(.success, trigger: didApprove)

// FALLBACK: Imperative (when modifier not available)
WKInterfaceDevice.current().play(.success)
```

**Spring Animation Migration:**
```swift
// LEGACY (still works, but verbose)
.animation(.spring(response: 0.3, dampingFraction: 0.6))

// MODERN (watchOS 10+)
.animation(.spring(duration: 0.3, bounce: 0.3))
.animation(.bouncy)   // Preset
.animation(.smooth)   // Preset
.animation(.snappy)   // Preset
```

**Symbol Effects:**
```swift
Image(systemName: isConnected ? "wifi" : "wifi.slash")
    .symbolEffect(.bounce, value: connectionChanged)
    .contentTransition(.symbolEffect(.replace))
```

**Key Code: Modern Button Style**
```swift
// ClaudeWatch/DesignSystem/ClaudeButtonStyle.swift
struct ClaudePrimaryButtonStyle: ButtonStyle {
    let tint: Color

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.bold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [tint, tint.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : .spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .medium), trigger: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ClaudePrimaryButtonStyle {
    static func claudePrimary(tint: Color) -> ClaudePrimaryButtonStyle {
        ClaudePrimaryButtonStyle(tint: tint)
    }
}
```

---

#### Phase 5: Error Handling & State Recovery

**Tasks:**
- [ ] Add inline error banners for network failures
- [ ] Implement optimistic update rollback when server rejects
- [ ] Add connection status indicator to PairingView
- [ ] Show retry countdown during reconnection attempts
- [ ] Add confirmation for "Approve All" with action count
- [ ] Handle expired pairing sessions gracefully

**Success Criteria:**
- Users always know when an operation failed
- Optimistic updates revert on failure
- Clear path to recovery from error states

### Research Insights: Phase 5

**Async State Management Pattern (from documented learning):**
> From `docs/solutions/ui-bugs/pairing-flow-loading-spinner-PairingView-20260116.md`

```swift
// BUG: Success path missing state reset
func submitCode() {
    isSubmitting = true
    Task {
        do {
            try await service.submitCode(code)
            // BUG: Missing success handler!
        } catch {
            isSubmitting = false  // Only error path resets
        }
    }
}

// FIXED: Use @MainActor Task with defer inside
func submitCode() {
    isSubmitting = true
    Task { @MainActor in
        defer { isSubmitting = false }
        do {
            try await service.submitCode(code)
            WKInterfaceDevice.current().play(.success)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

**NavigationStack Requirement (from documented learning):**
> From `docs/solutions/ui-bugs/watchos-demo-mode-stuck-no-exit.md`
> Toolbar items require NavigationStack context to render on watchOS

```swift
// BROKEN: No NavigationStack = invisible toolbar
WindowGroup {
    MainView()  // Toolbar items won't appear
}

// FIXED: NavigationStack at outermost level
WindowGroup {
    NavigationStack {
        MainView()  // Toolbar now visible
    }
}
```

**Complete State Reset Pattern:**
```swift
// BUG: Incomplete state reset leaves app stuck
func exitDemoMode() {
    isDemoMode = false
    state = WatchState()
    // Missing: connectionStatus, pairingId
}

// FIXED: Atomic state reset
func exitDemoMode() {
    isDemoMode = false
    state = WatchState()
    connectionStatus = .disconnected
    pairingId = ""  // Critical - enables PairingView
}
```

**Escape Path from Every State:**
```swift
// Every view state needs an escape route
if !service.isPaired && service.useCloudMode {
    Button { showingPairing = true } label: {
        Text("Pair with Code")
    }
} else {
    Button { service.loadDemoData() } label: {
        Text("Load Demo")
    }
}
```

**Error Banner Pattern:**
```swift
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Claude.danger)
            Text(message)
                .font(.caption)
            Spacer()
            Button { onDismiss() } label: {
                Image(systemName: "xmark")
            }
        }
        .padding(Claude.Spacing.sm)
        .background(Claude.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.small))
    }
}
```

---

## Alternative Approaches Considered

| Approach | Pros | Cons | Decision |
|----------|------|------|----------|
| Full rewrite | Clean slate | Risk, time | Rejected |
| Incremental extraction | Safe, testable | Slower | **Selected** |
| @Observable migration | Modern | Breaking change | Deferred to Phase 6 |
| Environment DI | Better testing | Large refactor | Deferred |

## Acceptance Criteria

### Functional Requirements
- [ ] All existing functionality preserved
- [ ] Components can be previewed in isolation
- [ ] Accessibility labels and hints on all interactive elements
- [ ] Haptic feedback for all significant actions
- [ ] Error states displayed for all failure modes

### Non-Functional Requirements
- [ ] MainView.swift under 250 lines
- [ ] No component file over 150 lines
- [ ] All animations respect Reduce Motion
- [ ] WCAG 2.1 AA contrast ratios for all text
- [ ] Build time unchanged or improved

### Quality Gates
- [ ] All SwiftUI previews render correctly
- [ ] VoiceOver navigation tested on device
- [ ] High Contrast mode tested on device
- [ ] No new warnings introduced
- [ ] Build succeeds on watchOS 10.0 minimum

## Success Metrics

| Metric | Before | Target |
|--------|--------|--------|
| MainView.swift lines | 1445 | <250 |
| Design system files | 3 (duplicated) | 1 (centralized) |
| Components with previews | 1 | 15+ |
| Reduce Motion checks | 0 | All animated views |
| Accessibility actions | Partial | Complete |

## Dependencies & Prerequisites

**Internal:**
- WatchService.swift API stability (no breaking changes during refactor)
- Existing test coverage (manual testing required)

**External:**
- Xcode 15.0+
- watchOS 10.0+ SDK
- iOS 17.0+ for Context7 documentation

## Risk Analysis & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Regression in extracted components | Medium | High | Incremental extraction, test each component |
| Design system import issues | Low | Medium | Use public access modifiers |
| Animation performance degradation | Low | Medium | Profile before/after with Instruments |
| Accessibility feature breakage | Medium | High | Test with VoiceOver at each phase |
| Over-engineering | Medium | Medium | Pre-planning checklist, read existing code first |
| Async state management bugs | Medium | High | Use defer pattern, test success AND error paths |

## Future Considerations

- **@Observable Migration**: Phase 6 could migrate WatchService to @Observable macro
- **Liquid Glass Full Adoption**: When watchOS 26 ships, adopt `.glassEffect()` modifier
- **Widget Redesign**: Complications could use new Smart Stack APIs
- **Multi-Session Support**: Phase 4 feature per PRD

## Documentation Plan

- [ ] Update CLAUDE.md with new file structure
- [ ] Add component documentation with usage examples
- [ ] Create accessibility testing checklist
- [ ] Document design tokens in DesignSystem/

## References & Research

### Internal References
- Existing design system: `ClaudeWatch/Views/MainView.swift:7-29`
- Animation extensions: `ClaudeWatch/Views/MainView.swift:157-173`
- Always-On Display: `ClaudeWatch/Views/MainView.swift:1364-1440`
- WatchService state: `ClaudeWatch/Services/WatchService.swift:12-13`

### Documented Learnings Applied
- `docs/solutions/architecture-decisions/app-store-phase3-overengineering-prevention.md` - Pre-planning code review checklist
- `docs/solutions/build-errors/watchos26-deprecation-warnings-20260115.md` - Modern API replacements
- `docs/solutions/ui-bugs/pairing-flow-loading-spinner-PairingView-20260116.md` - Async state management
- `docs/solutions/ui-bugs/watchos-demo-mode-stuck-no-exit.md` - NavigationStack and state recovery

### Project Skills Used
- `.claude/skills/swiftui-components` - View patterns, 100-line limit
- `.claude/skills/notification-expert` - UNNotificationCategory patterns
- `.claude/skills/watchos-testing` - Test viewmodels separately

### External References
- [Apple HIG - Designing for watchOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
- [Apple HIG - Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [WWDC23 - Design and build apps for watchOS 10](https://developer.apple.com/videos/play/wwdc2023/10138/)
- [WWDC21 - Create accessible experiences for watchOS](https://developer.apple.com/videos/play/wwdc2021/10223/)
- [Liquid Glass Reference](https://github.com/conorluddy/LiquidGlassReference)

### Related Work
- Consent flow implementation: ConsentView.swift
- Complication updates: ComplicationViews.swift

---

*Plan generated with Claude Code using frontend-design + workflows:plan skills*
*Enhanced with /deepen-plan using 15 parallel research agents*
