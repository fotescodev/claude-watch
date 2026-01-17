---
title: "Apple's Hidden Xcode 26 Documentation Discovery"
date: 2026-01-17
category: developer-tools
module: DeveloperTools
problem_type: knowledge_gap
component: xcode
symptoms:
  - "iOS 26/watchOS 13 features not in public training data"
  - "Foundation Models (on-device LLM) patterns unknown"
  - "Liquid Glass design system undocumented"
  - "New Swift 26 patterns missing from WWDC coverage"
root_cause: >
  Apple engineers maintain internal documentation inside Xcode's framework bundle
  that is not published to developer.apple.com or included in WWDC sessions
resolution_type: documentation
severity: high
tags:
  - xcode-26
  - ios-26
  - watchos-13
  - foundation-models
  - liquid-glass
  - on-device-ai
  - apple-intelligence
  - hidden-documentation
related_docs:
  - docs/solutions/build-errors/watchos26-deprecation-warnings-20260115.md
  - docs/solutions/workflow-automation/ralph-autonomous-task-execution-20260117.md
---

# Apple's Hidden Xcode 26 Documentation Discovery

## Problem

When implementing iOS 26/watchOS 13 features, Claude Code agents lack knowledge of new APIs like Foundation Models (on-device LLM) and Liquid Glass (new design system) because:

1. Training data has knowledge cutoff before iOS 26 release
2. These patterns aren't fully documented on developer.apple.com
3. WWDC sessions provide overview but not implementation details

## Discovery

Apple engineers maintain comprehensive internal documentation inside Xcode's framework bundle:

```
/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/
```

### Available Documentation (22 files)

| File | Topic |
|------|-------|
| `FoundationModels-Using-on-device-LLM-in-your-app.md` | On-device LLM with @Generable |
| `SwiftUI-Implementing-Liquid-Glass-Design.md` | Liquid Glass for SwiftUI |
| `UIKit-Implementing-Liquid-Glass-Design.md` | Liquid Glass for UIKit |
| `AppKit-Implementing-Liquid-Glass-Design.md` | Liquid Glass for AppKit |
| `WidgetKit-Implementing-Liquid-Glass-Design.md` | Complications with glass |
| `Swift-Concurrency-Updates.md` | Modern async patterns |
| `SwiftUI-AlarmKit-Integration.md` | Alarm/timer integration |
| `Implementing-Visual-Intelligence-in-iOS.md` | Visual AI features |
| `Swift-Charts-3D-Visualization.md` | 3D chart rendering |
| `SwiftData-Class-Inheritance.md` | SwiftData patterns |
| `StoreKit-Updates.md` | In-app purchase changes |
| `MapKit-GeoToolbox-PlaceDescriptors.md` | Location services |
| `SwiftUI-New-Toolbar-Features.md` | Toolbar APIs |
| `SwiftUI-Styled-Text-Editing.md` | Rich text editing |
| `SwiftUI-WebKit-Integration.md` | WebView patterns |
| `AppIntents-Updates.md` | Siri/Shortcuts updates |
| `Foundation-AttributedString-Updates.md` | String formatting |
| `Swift-InlineArray-Span.md` | Performance types |
| `Implementing-Assistive-Access-in-iOS.md` | Accessibility |
| `Widgets-for-visionOS.md` | Vision Pro widgets |

## Solution

### 1. Access the Documentation

```bash
# List all available docs
ls "/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/"

# Read specific doc
cat "/Applications/Xcode.app/Contents/PlugIns/IDEIntelligenceChat.framework/Versions/A/Resources/AdditionalDocumentation/FoundationModels-Using-on-device-LLM-in-your-app.md"
```

### 2. Foundation Models Key Patterns

```swift
import FoundationModels

// Check availability (REQUIRED)
private var model = SystemLanguageModel.default

switch model.availability {
case .available:
    // Use on-device AI
case .unavailable(.deviceNotEligible):
    // Fallback to cloud API
case .unavailable(.appleIntelligenceNotEnabled):
    // Prompt user to enable
case .unavailable(.modelNotReady):
    // Show download progress
}

// Structured generation with @Generable
@Generable(description: "Parsed action request")
struct ActionRequest {
    @Guide(description: "Action type", .options("file_edit", "command"))
    var actionType: String

    @Guide(description: "Risk level 1-5", .range(1...5))
    var riskLevel: Int
}

// Use in session
let session = LanguageModelSession(instructions: "Parse incoming actions")
let result = try await session.respond(to: input, generating: ActionRequest.self)
```

**Context Limit**: 4,096 tokens per session

### 3. Liquid Glass Key Patterns

```swift
// Basic glass effect
Text("Status")
    .padding()
    .glassEffect()

// Interactive glass (responds to touch)
Text("Tap me")
    .glassEffect(.regular.interactive())

// Glass buttons
Button("Approve") { }
    .buttonStyle(.glass)

Button("Primary Action") { }
    .buttonStyle(.glassProminent)

// Multiple glass effects with morphing
@Namespace private var glassNamespace

GlassEffectContainer(spacing: 20) {
    ForEach(items) { item in
        ItemView(item)
            .glassEffect()
            .glassEffectID(item.id, in: glassNamespace)
    }
}
.animation(.spring, value: items)
```

### 4. Created Skill File

Created `.claude/commands/apple-platform-docs.md` skill that:
- Documents the hidden path
- Provides Foundation Models patterns
- Provides Liquid Glass patterns
- Includes review checklist for iOS 26 compliance

## Prevention

### For Future iOS/watchOS Releases

1. **Check Xcode bundle on new releases**:
   ```bash
   find /Applications/Xcode.app/Contents -name "*.md" | grep -i documentation
   ```

2. **Reference hidden docs before implementing new features**

3. **Create skills that embed key patterns from hidden docs**

### Skill Harvesting Pattern

When solving iOS 26+ problems:
1. Read relevant hidden doc
2. Extract key patterns and code examples
3. Create/update skill file with patterns
4. Add tasks referencing the skill

## Impact

This discovery enables:
- **FM1-FM2 tasks**: Foundation Models integration for Claude Watch
- **LG1-LG2 tasks**: Liquid Glass UI adoption
- **Ralph automation**: Can now implement iOS 26 features autonomously

## Related

- [watchOS 26 Deprecation Warnings](../build-errors/watchos26-deprecation-warnings-20260115.md)
- [Ralph Autonomous Task Execution](../workflow-automation/ralph-autonomous-task-execution-20260117.md)
- Skill: `.claude/commands/apple-platform-docs.md`
