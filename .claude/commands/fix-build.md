---
description: Diagnose and fix build errors
allowed-tools: Bash(xcodebuild:*), Read, Write, Edit
---

# Fix Build Errors

Diagnose and fix watchOS build errors:

1. Run a clean build to get fresh errors:
   ```bash
   xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' clean build 2>&1
   ```

2. Parse the build output for errors and warnings

3. For each error:
   - Read the affected file
   - Understand the context
   - Propose and implement a fix
   - Verify the fix doesn't break other code

4. Re-run build to verify all errors are fixed

5. Report final status

Common watchOS build issues:
- Missing entitlements for push notifications
- Incorrect deployment target
- WatchKit vs SwiftUI API misuse
- Async/await usage in wrong context
