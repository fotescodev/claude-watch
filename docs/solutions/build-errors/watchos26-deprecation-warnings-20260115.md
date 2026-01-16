---
module: ClaudeWatch
date: 2026-01-15
problem_type: build_error
component: frontend_stimulus
symptoms:
  - "WKExtension.shared() deprecated warning blocking App Store submission"
  - "presentTextInputController deprecated warning in VoiceInputSheet"
  - "Build warnings treated as errors in release configuration"
root_cause: wrong_api
resolution_type: code_fix
severity: critical
tags: [watchos, deprecation, watchos26, wkextension, wkapplication, swiftui, voice-input]
---

# Troubleshooting: watchOS 26 Deprecation Warnings Blocking App Store Submission

## Problem

watchOS 26 deprecation warnings were blocking App Store submission. Two deprecated WatchKit APIs needed to be replaced with modern SwiftUI alternatives before the app could be accepted.

## Environment

- Module: ClaudeWatch
- watchOS Version: 26
- Xcode Version: 16+
- Affected Components: ClaudeWatchApp.swift, MainView.swift (VoiceInputSheet)
- Date: 2026-01-15

## Symptoms

- `WKExtension.shared()` marked as deprecated in watchOS 10, removed in watchOS 26
- `presentTextInputController` deprecated WatchKit API warning
- App Store Connect rejection due to deprecated API usage
- Build warnings treated as errors in release configuration

## What Didn't Work

**Direct solution:** The problems were identified through compiler warnings and fixed systematically.

## Solution

### T01: WKExtension.shared() Replacement

**Location:** `ClaudeWatch/App/ClaudeWatchApp.swift` line 70

**Code changes:**

```swift
// Before (broken):
WKExtension.shared().isAutorotating = true

// After (fixed):
WKApplication.shared().isAutorotating = true
```

### T02: presentTextInputController Replacement

**Location:** `ClaudeWatch/Views/MainView.swift` lines 801-922 (VoiceInputSheet)

**Code changes:**

```swift
// Before (broken):
// Used WKInterfaceController.presentTextInputController with completion handler
// Required isListening state management
// Complex WatchKit integration

// After (fixed):
// Native SwiftUI TextField with built-in dictation support
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
                        Button(suggestion) {
                            inputText = suggestion
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Button("Send") {
                WKInterfaceDevice.current().play(.success) // Haptic feedback
                onSubmit(inputText)
            }
        }
    }
}
```

**Key improvements in T02:**
- Removed `isListening` state (no longer needed with native TextField)
- Added suggestion chips for common commands
- Added haptic feedback on send via `WKInterfaceDevice.current().play(.success)`
- Cleaner SwiftUI-native implementation

## Why This Works

1. **WKExtension to WKApplication (T01):**
   - `WKExtension` was the original watchOS 1-era singleton for accessing extension-level properties
   - Apple consolidated this into `WKApplication` which mirrors the iOS `UIApplication` pattern
   - `WKApplication.shared()` provides the same functionality with modern API design

2. **presentTextInputController to TextField (T02):**
   - `presentTextInputController` was a WatchKit modal API requiring completion handlers
   - SwiftUI's native `TextField` automatically enables dictation on watchOS
   - The microphone button appears automatically in the keyboard
   - No manual speech recognition or listening state management needed
   - SwiftUI handles the entire voice-to-text pipeline

## Prevention

To avoid deprecated API issues in future watchOS releases:

1. **Run `/watchos-audit` command before releases**
   - Scans for deprecated APIs and suggests replacements
   - Should be part of pre-release checklist

2. **Check WWDC deprecation notices yearly**
   - Apple announces deprecations at WWDC each June
   - Review watchOS release notes for deprecated APIs
   - Plan migration during beta period (June-September)

3. **Use `@available` annotations for version-specific code**
   ```swift
   if #available(watchOS 10, *) {
       WKApplication.shared().isAutorotating = true
   } else {
       WKExtension.shared().isAutorotating = true
   }
   ```

4. **Enable "Treat Warnings as Errors" in debug builds**
   - Catches deprecation warnings early in development
   - Prevents accumulation of deprecated API usage

5. **Subscribe to Apple Developer News**
   - Get notifications about platform changes
   - Early warning for API removals

## Files Changed

- `ClaudeWatch/App/ClaudeWatchApp.swift` - WKExtension to WKApplication migration
- `ClaudeWatch/Views/MainView.swift` - VoiceInputSheet SwiftUI modernization

## Related Issues

No related issues documented yet.
