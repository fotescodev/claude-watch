# watchOS Build Commands

Build and run Claude Watch on the watchOS simulator.

## Quick Commands

### List Available Watch Simulators
```bash
xcrun simctl list devices | grep -i watch
```

### Build for Simulator
```bash
xcodebuild -project ClaudeWatch/ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build
```

### Build and Run
```bash
# Boot simulator first
xcrun simctl boot "Apple Watch Series 11 (46mm)"

# Build
xcodebuild -project ClaudeWatch/ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' \
  build

# Install and launch
xcrun simctl install booted ClaudeWatch/build/Debug-watchsimulator/ClaudeWatch.app
xcrun simctl launch booted com.anthropic.claudecode
```

### Clean Build
```bash
xcodebuild -project ClaudeWatch/ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  clean
```

## AXe UI Automation

### Get Simulator UDID
```bash
WATCH_UDID=$(xcrun simctl list devices | grep "Apple Watch Series 11 (46mm)" | grep -oE '[A-F0-9-]{36}' | head -1)
```

### Describe UI Hierarchy
```bash
axe describe-ui --udid $WATCH_UDID
```

### Tap Element by Accessibility ID
```bash
axe tap --id "ApproveButton" --udid $WATCH_UDID
```

### Take Screenshot
```bash
axe screenshot --udid $WATCH_UDID --output watch-screenshot.png
```

## Common Issues

### Simulator Not Booted
```bash
xcrun simctl boot "Apple Watch Series 11 (46mm)"
```

### Derived Data Issues
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/ClaudeWatch-*
```

### Code Signing Issues (Simulator)
Simulator builds don't require code signing. If you see signing errors, ensure destination is set to simulator.
