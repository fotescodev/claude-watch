---
description: Build and launch the app on watchOS Simulator
allowed-tools: Bash(xcodebuild:*), Bash(xcrun simctl:*), Bash(open:*), Read
---

# Build and Run App

Build and launch ClaudeWatch on the watchOS Simulator:

1. List available watchOS simulators
2. Boot an Apple Watch simulator if none running
3. Build the app for simulator
4. Install the app on the simulator
5. Launch the app
6. Open Simulator.app for visibility

Steps:
```bash
# List simulators
xcrun simctl list devices available | grep -i watch

# Boot simulator (if needed)
xcrun simctl boot "Apple Watch Series 9 (45mm)"

# Build
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' build

# Get bundle ID and install
xcrun simctl install booted /path/to/ClaudeWatch.app

# Launch
xcrun simctl launch booted com.example.ClaudeWatch

# Open Simulator
open -a Simulator
```

Report any errors with suggested fixes.
