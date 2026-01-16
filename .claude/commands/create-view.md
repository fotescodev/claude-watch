---
description: Create a new SwiftUI view for watchOS
argument-hint: <ViewName>
allowed-tools: Read, Write
---

# Create SwiftUI View: $ARGUMENTS

Create a new SwiftUI view for watchOS following project patterns:

1. Read existing views in `ClaudeWatch/Views/` for style reference
2. Create `$ARGUMENTS.swift` in `ClaudeWatch/Views/`
3. Follow these watchOS SwiftUI patterns:
   - Keep views compact for watch screen
   - Use `ScrollView` sparingly
   - Leverage `NavigationStack` for navigation
   - Use system colors and SF Symbols
   - Add haptic feedback where appropriate

Template:
```swift
import SwiftUI

struct $ARGUMENTSView: View {
    var body: some View {
        VStack {
            // View content here
        }
    }
}

#Preview {
    $ARGUMENTSView()
}
```

4. Add any necessary state properties
5. Consider adding a preview with sample data
