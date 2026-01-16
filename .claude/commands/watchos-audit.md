# watchOS App Audit

Comprehensive audit of this watchOS application against Apple's latest guidelines.

## Checklist

### 1. Human Interface Guidelines
- [ ] Glanceable information design
- [ ] Appropriate text sizes (minimum 11pt body)
- [ ] Touch targets (minimum 44x44pt)
- [ ] Digital Crown integration
- [ ] Haptic feedback patterns
- [ ] Always-On Display support

### 2. SwiftUI Best Practices
- [ ] Proper @State, @StateObject, @ObservedObject usage
- [ ] Environment object injection
- [ ] View composition (files < 200 lines)
- [ ] Accessibility modifiers

### 3. Complications (WidgetKit)
- [ ] All required families implemented
- [ ] App Groups for data sharing
- [ ] Timeline provider with real data
- [ ] Always-on rendering mode

### 4. Networking
- [ ] Background URLSession
- [ ] Offline-first architecture
- [ ] Proper error handling
- [ ] Reconnection with backoff

### 5. Modern APIs
- [ ] No deprecated WKExtension usage
- [ ] Swift Concurrency (async/await)
- [ ] Modern text input (not presentTextInputController)

## Tools

Query `apple-docs` MCP server for:
- `search_apple_docs("watchOS Human Interface Guidelines")`
- `search_apple_docs("WidgetKit watchOS complications")`
- `search_wwdc_videos("watchOS")`
- `get_platform_compatibility("WKExtension")`

Output a prioritized fix list with effort estimates.
