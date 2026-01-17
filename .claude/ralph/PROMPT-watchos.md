# watchOS-Specific Standards

This module is loaded for tasks tagged with: `watchos`, `complications`, `always-on`

---

## watchOS Patterns
- Use `.sensoryFeedback()` for haptics
- Prefer single-tap interactions
- Use SF Symbols for icons
- Support Always-On Display states
- Use `WKExtension` for system APIs
- Keep UI minimal - single glance interactions
- Handle `UNUserNotificationCenter` for push notifications
- Use `UNNotificationAction` for approve/reject actions

## Complications
- Use `WKComplicationProvider` for watch face widgets
- Support all complication families
- Provide placeholder and snapshot data
- Handle timeline entries efficiently

## Build Verification

```bash
# IMPORTANT: The sed must only strip the UUID, NOT the size suffix like (46mm)
# Wrong: sed 's/ (.*//'        → "Apple Watch Series 11" (FAILS)
# Right: sed 's/ ([A-F0-9-]*).*//' → "Apple Watch Series 11 (46mm)" (WORKS)
SIMULATOR=$(xcrun simctl list devices available | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ ([A-F0-9-]*).*//')
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination "platform=watchOS Simulator,name=$SIMULATOR" build 2>&1 | tail -30
```

## Known Pitfalls

### Simulator Name Extraction
**Problem**: `xcrun simctl list` outputs simulator names with UUIDs in parentheses:
```
Apple Watch Series 11 (46mm) (17ED8A4B-F6F7-44A9-94D7-AB0E4C7E5C8D)
```

**Wrong approach**: `sed 's/ (.*//'` strips EVERYTHING after the first `(`, giving:
```
Apple Watch Series 11  ← Missing size suffix, xcodebuild FAILS
```

**Correct approach**: `sed 's/ ([A-F0-9-]*).*//'` only strips the UUID pattern:
```
Apple Watch Series 11 (46mm)  ← Complete name, xcodebuild WORKS
```

**Rule**: When parsing simulator names, always test the extracted name against available destinations before using it in xcodebuild.
