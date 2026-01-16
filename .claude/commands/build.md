---
description: Build the watchOS project for simulator
allowed-tools: Bash(xcodebuild:*), Bash(xcrun simctl:*), Read
---

# Build Project

Build the ClaudeWatch watchOS app for simulator:

1. Clean derived data if previous build failed
2. Build using xcodebuild for watchOS Simulator
3. Report build results with any errors or warnings

```bash
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build
```

If build fails:
- Analyze the error messages
- Suggest specific fixes with file locations
- Offer to fix obvious issues
