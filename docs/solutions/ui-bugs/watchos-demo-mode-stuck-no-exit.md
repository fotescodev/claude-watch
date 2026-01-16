---
title: "watchOS app stuck in Demo Mode - unable to exit or access cloud pairing"
category: ui-bugs
tags:
  - watchOS
  - SwiftUI
  - state-management
  - demo-mode
  - navigation
  - toolbar
component: ClaudeWatch
severity: high
date_solved: 2026-01-15
related_files:
  - ClaudeWatch/App/ClaudeWatchApp.swift
  - ClaudeWatch/Views/MainView.swift
  - ClaudeWatch/Services/WatchService.swift
---

# watchOS App Stuck in Demo Mode

## Problem

Users entering Demo Mode could not exit or access the cloud pairing flow. The app became effectively locked with no escape route.

**Symptoms:**
- Settings toolbar button not visible (no way to access settings)
- Exit Demo Mode button didn't properly reset state
- App kept reverting to demo mode after attempted exit
- "Pair with Code" button not accessible from EmptyStateView

## Root Causes

### 1. Missing NavigationStack Wrapper
On watchOS, toolbar items require a `NavigationStack` context to render. Without it, the settings button was invisible.

```swift
// BROKEN: No NavigationStack
WindowGroup {
    MainView()  // Toolbar items won't appear
}

// FIXED: With NavigationStack
WindowGroup {
    NavigationStack {
        MainView()  // Toolbar now visible
    }
}
```

### 2. Incomplete State Reset on Exit
The Exit Demo Mode button only reset `isDemoMode` and `state`, but not `pairingId` or `connectionStatus`. This caused the app to skip showing `PairingView`.

### 3. Inconsistent Demo Mode Flag
`loadDemoData()` set demo content but didn't always set `isDemoMode = true`, causing state inconsistencies.

### 4. No Pairing Path from EmptyStateView
When unpaired, users saw "All Clear" with only a "Load Demo" button - no way to initiate pairing.

## Solution

### File 1: ClaudeWatchApp.swift
Added `NavigationStack` wrapper:

```swift
var body: some Scene {
    WindowGroup {
        NavigationStack {
            MainView()
        }
    }
}
```

### File 2: MainView.swift - SettingsSheet
Added Exit Demo Mode section with complete state reset:

```swift
if service.isDemoMode {
    Button {
        service.isDemoMode = false
        service.state = WatchState()
        service.connectionStatus = .disconnected
        service.pairingId = ""  // Critical - enables PairingView
        dismiss()
    } label: {
        Text("Exit Demo Mode")
    }
}
```

### File 3: MainView.swift - EmptyStateView
Added conditional "Pair with Code" button:

```swift
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

### File 4: WatchService.swift
Fixed `loadDemoData()` to set flag first:

```swift
func loadDemoData() {
    isDemoMode = true  // Set flag BEFORE loading data
    connectionStatus = .connected
    // ... rest of demo setup
}
```

## Prevention

### watchOS Toolbar Best Practice
Always wrap content in `NavigationStack` when using toolbars:

```swift
NavigationStack {
    Content()
        .toolbar { ToolbarItem { ... } }
}
```

### State Management Best Practice
Group related state changes atomically:

```swift
// Centralized exit method
func exitDemoMode() {
    isDemoMode = false
    state = WatchState()
    connectionStatus = .disconnected
    pairingId = ""
}
```

### Code Review Checklist
- [ ] Is `NavigationStack` at outermost level?
- [ ] Does exit demo mode reset ALL state variables?
- [ ] Do all demo entry points set `isDemoMode = true`?
- [ ] Are there escape paths from every UI state?

## Testing

1. Enter Demo Mode via "Load Demo" button
2. Tap settings icon (top-right) - should be visible
3. Tap "Exit Demo Mode" - should return to PairingView
4. Verify "Pair with Code" button appears when unpaired
