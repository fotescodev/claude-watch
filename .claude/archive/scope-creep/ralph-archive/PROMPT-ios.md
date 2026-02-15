# iOS-Specific Standards

This module is loaded for tasks tagged with: `ios`, `iphone`, `ipad`

---

## iOS Patterns
- Support Dynamic Type
- Respect Safe Area Insets
- Handle keyboard appearance
- Support Dark Mode
- Use UIKit lifecycle if needed via `@UIApplicationDelegateAdaptor`

## Build Verification

```bash
# Same pattern as watchOS - preserve model suffix like (16.2) or (Pro Max)
SIMULATOR=$(xcrun simctl list devices available | grep -i "iPhone" | head -1 | sed 's/^ *//' | sed 's/ ([A-F0-9-]*).*//')
xcodebuild -project [Project].xcodeproj -scheme [Scheme] \
  -destination "platform=iOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

## iPad Considerations
- Support multitasking (Slide Over, Split View)
- Provide pointer/keyboard support
- Use size classes for adaptive layouts
