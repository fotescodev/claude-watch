# Impossible Task Definitions in tasks.yaml

**Status**: pending
**Priority**: P2 (High)
**Category**: Configuration Error
**Created**: 2026-01-16T19:35:00Z

## Summary

Tasks LG1 and LG2 reference SwiftUI APIs that do not exist in watchOS 10.6 (or any current watchOS SDK). Ralph cannot complete these tasks because the required APIs are fictional or from unreleased future versions.

## Affected Tasks

### LG1: "Adopt Liquid Glass materials"

**Task description says**:
> Replace .opacity() backgrounds with .glassBackgroundEffect()

**Reality**:
- `.glassBackgroundEffect()` does NOT exist in SwiftUI for watchOS
- "Liquid Glass" was a rumored iOS 26/watchOS 26 feature that hasn't shipped
- The task references a hypothetical future API

**What DOES exist**:
- `.background(.ultraThinMaterial)` - iOS 15+/watchOS 8+
- `.background(.thinMaterial)` - iOS 15+/watchOS 8+
- `.background(.regularMaterial)` - iOS 15+/watchOS 8+
- `.background(.thickMaterial)` - iOS 15+/watchOS 8+
- `.background(.bar)` - System bar material

### LG2: "Add spring animations"

**Verification includes**:
```bash
grep -q '\.spring\|interpolatingSpring\|\.bouncy' ClaudeWatch/Views/ -r
```

**Reality**:
- `.bouncy` is NOT a SwiftUI animation modifier
- The real API is `.animation(.bouncy)` (iOS 17+) which IS valid
- But the grep pattern `\.bouncy` would never match `animation(.bouncy)`

**What DOES exist**:
```swift
// Pre-iOS 17
.animation(.spring(response: 0.5, dampingFraction: 0.6))
.animation(.interpolatingSpring(stiffness: 100, damping: 10))

// iOS 17+ / watchOS 10+
.animation(.bouncy)           // Works but grep won't find it
.animation(.snappy)           // Also available
.animation(.smooth)           // Also available
```

## Impact

1. Ralph will attempt these tasks indefinitely, always failing
2. Developers following the prompt will be confused by non-existent APIs
3. The session metrics show growing failure counts

## Evidence

Current MainView.swift uses:
```swift
// Line 251-253
.background(
    RoundedRectangle(cornerRadius: 16)
        .fill(Claude.surface1)  // Uses solid color, not material
)
```

There is NO usage of material effects currently, but the verification demands a non-existent API.

## Recommended Fix

### Option A: Update to Use Real APIs

```yaml
- id: "LG1"
  title: "Add translucent material backgrounds"
  description: |
    Replace solid color backgrounds with SwiftUI material effects
    (.ultraThinMaterial, .thinMaterial) for depth and translucency.
    This creates a modern, layered appearance on watchOS.
  verification: |
    grep -q 'ultraThinMaterial\|thinMaterial\|regularMaterial\|thickMaterial' ClaudeWatch/Views/ -r
  acceptance_criteria:
    - "At least one container uses material background"
    - "Maintains readability over varying backgrounds"
    - "Works in both light and dark contexts"
```

### Option B: Mark as Future/Blocked

```yaml
- id: "LG1"
  title: "Adopt Liquid Glass materials"
  status: blocked
  blocked_reason: "API .glassBackgroundEffect() not available in watchOS 10.6"
  completed: true  # Skip this task
```

### Option C: Remove from Task List

If watchOS 26 SDK isn't available, remove these tasks entirely until the APIs are released.

## Verification Pattern Fixes

For LG2, update the grep pattern:
```yaml
# Old (broken)
verification: |
  grep -q '\.spring\|interpolatingSpring\|\.bouncy' ClaudeWatch/Views/ -r

# New (working)
verification: |
  grep -qE '\.spring\(|interpolatingSpring|animation\(\.bouncy|animation\(\.snappy' ClaudeWatch/Views/ -r
```

## Root Cause

The task definitions appear to have been written based on:
1. WWDC announcements or rumors about future APIs
2. Placeholder names for APIs that don't exist yet
3. Confusion between iOS and watchOS APIs

## Action Items

- [ ] Audit all tasks.yaml entries for API existence
- [ ] Test verification commands manually before deploying
- [ ] Add SDK version checks to task definitions
- [ ] Document which watchOS version is being targeted

---
**Assignee**: Unassigned
**Labels**: ralph, configuration, sdk, api-compatibility
