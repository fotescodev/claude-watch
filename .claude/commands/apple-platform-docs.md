---
name: apple-review
description: Apple Platform Code Review
---

# Apple Platform Code Review

Access Apple's internal Xcode 26 documentation and enforce iOS 26/watchOS 13 best practices.

## Hidden Documentation Path

Apple engineers maintain additional documentation inside Xcode's framework bundle that isn't in public training data:

```
/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/
```

### Available Docs (Xcode 26.2)

| File | Topic |
|------|-------|
| `FoundationModels-Using-on-device-LLM-in-your-app.md` | On-device LLM with @Generable |
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | Liquid Glass for SwiftUI |
| `WidgetKit-Implementing-Liquid-Glass-Design.md` | Complications with glass |
| `Swift-Concurrency-Updates.md` | Modern async patterns |
| `SwiftUI-AlarmKit-Integration.md` | Alarm/timer integration |
| `Implementing-Visual-Intelligence-in-iOS.md` | Visual AI features |

**Before implementing iOS 26+ features, READ the relevant doc:**
```bash
cat "/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/FoundationModels-Using-on-device-LLM-in-your-app.md"
```

---

## Foundation Models (On-Device LLM)

### Availability Check (Required)
```swift
import FoundationModels

struct AIView: View {
    private var model = SystemLanguageModel.default

    var body: some View {
        switch model.availability {
        case .available:
            // Show AI features
        case .unavailable(.deviceNotEligible):
            // Device doesn't support Apple Intelligence
        case .unavailable(.appleIntelligenceNotEnabled):
            // Prompt user to enable in Settings
        case .unavailable(.modelNotReady):
            // Model downloading, show progress
        case .unavailable(let other):
            // Fallback to cloud API
        }
    }
}
```

### Structured Generation with @Generable
```swift
import FoundationModels

@Generable(description: "Parsed approval request from Claude Code")
struct ApprovalRequest {
    @Guide(description: "The action type", .options("file_edit", "command", "api_call"))
    var actionType: String

    @Guide(description: "File path if applicable")
    var filePath: String?

    @Guide(description: "Risk level 1-5", .range(1...5))
    var riskLevel: Int

    @Guide(description: "One sentence summary")
    var summary: String
}

// Usage
let session = LanguageModelSession(instructions: """
    Parse incoming Claude Code actions into structured approval requests.
    Assess risk level based on action scope and reversibility.
    """)

let request = try await session.respond(
    to: rawNotificationPayload,
    generating: ApprovalRequest.self
)
```

### Tool Calling for Watch Actions
```swift
struct ApproveActionTool: Tool {
    struct Arguments: Codable {
        var actionId: String
        var approved: Bool
        var feedback: String?
    }

    func call(arguments: Arguments) async throws -> ToolOutput {
        await WatchService.shared.sendResponse(
            actionId: arguments.actionId,
            approved: arguments.approved,
            feedback: arguments.feedback
        )
        return .string("Action \(arguments.approved ? "approved" : "rejected")")
    }
}
```

### Context Limits
- 4,096 tokens per session
- ~3-4 characters per token (English)
- Break large operations into chunks
- Use streaming for real-time UI updates

---

## Liquid Glass Design

### Basic Application
```swift
// Simple glass effect
Text("Pending Actions: 3")
    .padding()
    .glassEffect()

// With shape
Button("Approve") { }
    .buttonStyle(.glass)

// Prominent action
Button("Approve All") { }
    .buttonStyle(.glassProminent)
```

### Interactive Glass (Required for Touch Feedback)
```swift
Text("Status")
    .padding()
    .glassEffect(.regular.interactive())
```

### Multiple Glass Effects
```swift
@Namespace private var glassNamespace

GlassEffectContainer(spacing: 20) {
    HStack(spacing: 20) {
        ForEach(actions) { action in
            ActionButton(action: action)
                .glassEffect()
                .glassEffectID(action.id, in: glassNamespace)
        }
    }
}
```

### Morphing Transitions
```swift
@State private var isExpanded = false
@Namespace private var namespace

GlassEffectContainer {
    if isExpanded {
        ExpandedView()
            .glassEffect()
            .glassEffectID("main", in: namespace)
    } else {
        CollapsedView()
            .glassEffect()
            .glassEffectID("main", in: namespace)
    }
}
.animation(.spring, value: isExpanded)
```

---

## Review Checklist

### Foundation Models
- [ ] Check `SystemLanguageModel.default.availability` before using
- [ ] Provide graceful fallback for unsupported devices
- [ ] Use `@Generable` for structured output
- [ ] Keep prompts under 4K tokens
- [ ] Handle `.modelNotReady` state (show download progress)

### Liquid Glass
- [ ] Use `.glassEffect()` instead of custom materials
- [ ] Wrap multiple glass views in `GlassEffectContainer`
- [ ] Add `.interactive()` for touch-responsive elements
- [ ] Use `.buttonStyle(.glass)` or `.glassProminent`
- [ ] Use `@Namespace` + `glassEffectID` for morphing

### Swift Patterns (iOS 26)
- [ ] Use `@Observable` not `ObservableObject`
- [ ] Use `@Environment` for dependency injection
- [ ] No singletons for view state
- [ ] Use `async/await` for all async operations
- [ ] Prefer value types (structs) over classes

---

## When to Use This Skill

1. When implementing iOS 26/watchOS 13 features
2. When asked about Foundation Models or on-device AI
3. When reviewing UI for Liquid Glass compliance
4. When debugging Apple Intelligence availability
5. When optimizing for Apple's design language
