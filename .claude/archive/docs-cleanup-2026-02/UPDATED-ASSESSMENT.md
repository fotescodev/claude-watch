# Updated Assessment: ClaudeWatch + WWDC 2025 Best Practices

Based on apple-docs-mcp queries and WWDC 2025 research, here's the updated assessment.

## Good News: Liquid Glass Migration is Easy

Apple designed Liquid Glass to be **automatically adopted** when you recompile with Xcode 26:

| Component | Current State | After Xcode 26 Recompile |
|-----------|---------------|--------------------------|
| TabView | Flat | Liquid glass tab bar (auto) |
| Sheets | Manual styling | Liquid glass background (auto) |
| Toolbar | Manual | Floats on glass (auto) |
| Controls | Flat | Transform during interaction (auto) |

**What this means:** Your app will look modern with minimal code changes.

## Updated Priority Fixes (Post-WWDC 2025)

### Critical (Blocking Issues)

1. **Replace deprecated APIs** - These WILL break:
   ```swift
   // OLD (deprecated)
   WKExtension.shared().registerForRemoteNotifications()
   WKExtension.shared().visibleInterfaceController?.presentTextInputController(...)

   // NEW (iOS 26+)
   // Use SwiftUI-native approaches
   // Speech framework for voice input
   ```

2. **Add accessibility** - Still required for App Store

3. **Fix widget data sharing** - App Groups required
   ```swift
   // Widgets now have relevance APIs in watchOS 26
   // Must use App Groups to share real data
   ```

### High Priority (For Modern UX)

4. **Embrace Liquid Glass** - Enhance automatic adoption:
   ```swift
   // Replace:
   .background(Color.green.opacity(0.2))

   // With:
   .background(.liquidGlass)
   // or for subtle glass:
   .glassEffect(.regular, in: .rect, isEnabled: true)
   ```

5. **Add spring animations** - Liquid Glass expects motion:
   ```swift
   // Add to buttons and state changes:
   .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state)
   ```

6. **Use new SwiftUI Performance Instrument** - Profile view updates

### Medium Priority (Polish)

7. **Consider Chart3D** for progress visualization (new in iOS 26)

8. **Implement WebView** if showing any web content (new SwiftUI API)

9. **Rich Text Editor** for more sophisticated prompt input

## watchOS 26 Specific Opportunities

### New Features to Leverage

1. **Custom Controls** - Add a quick action to mark locations
2. **Widget Relevance APIs** - Make complications smarter
3. **Background Extension Effect** - Content extends to edges

### Example: Modern Liquid Glass ActionCard

```swift
struct ActionCard: View {
    let action: PendingAction
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: action.icon)
                    .symbolRenderingMode(.hierarchical) // Modern SF Symbol
                Text(action.title)
                    .font(.headline)
            }

            Text(action.description)
                .font(.caption)
                .foregroundStyle(.secondary) // Semantic color

            HStack(spacing: 12) {
                Button("Approve") { approve() }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)

                Button("Reject") { reject() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.liquidGlass) // iOS 26 Liquid Glass
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(action.title). \(action.description)")
        .accessibilityHint("Double tap to approve, swipe right to reject")
    }
}
```

## Revised Roadmap

### Week 1: Foundation (Can Do Remotely)
- [x] Add MCP server configurations
- [x] Add slash commands for audits
- [x] Create reference documentation
- [ ] Fix `DEVELOPMENT_TEAM` in project
- [ ] Add basic state persistence (Codable)

### Week 2: Modernization (Needs Mac)
- [ ] Upgrade to Swift 5.10 / Xcode 26
- [ ] Remove deprecated WKExtension APIs
- [ ] Add App Groups for widget data
- [ ] Test Liquid Glass automatic adoption

### Week 3: Polish
- [ ] Add accessibility labels throughout
- [ ] Implement spring animations
- [ ] Add custom glassEffect() where needed
- [ ] Split MainView.swift into components

### Week 4: Ship
- [ ] Full accessibility audit
- [ ] TestFlight beta
- [ ] App Store submission

## Files Added to Repository

```
.claude/
├── settings.json           # MCP server configurations
├── settings.local.json     # Local overrides (gitignored)
├── SKILLS.md               # Skills & plugin documentation
├── commands/
│   ├── apple-review.md     # /apple-review slash command
│   ├── watchos-audit.md    # /watchos-audit slash command
│   └── liquid-glass.md     # /liquid-glass slash command
└── references/
    ├── WWDC2025-WATCHOS26.md   # WWDC 2025 reference
    └── UPDATED-ASSESSMENT.md   # This file
```

## Next Steps

When you're back at your MacBook:

1. **Install apple-docs-mcp** (or let npx handle it)
2. **Install Axiom skills** via `/plugin marketplace add CharlesWiltgen/Axiom`
3. **Run `/watchos-audit`** to get real-time documentation checks
4. **Build with Xcode 26** to see automatic Liquid Glass adoption
