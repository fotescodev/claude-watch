# Apple Documentation Lookup

Access Apple's internal framework documentation for iOS 26/watchOS 11+ features.

## Documentation Path
```
/Applications/Xcode.app/Contents/Plugins/IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/
```

## Available Documentation

### UI & Design (Liquid Glass)
- `SwiftUI-Implementing-Liquid-Glass-Design.md` - Liquid Glass for SwiftUI views
- `WidgetKit-Implementing-Liquid-Glass-Design.md` - Liquid Glass for complications/widgets
- `UIKit-Implementing-Liquid-Glass-Design.md` - Liquid Glass for UIKit
- `AppKit-Implementing-Liquid-Glass-Design.md` - Liquid Glass for macOS

### Swift & Concurrency
- `Swift-Concurrency-Updates.md` - Modern async/await patterns
- `Swift-InlineArray-Span.md` - InlineArray and Span types
- `SwiftData-Class-Inheritance.md` - SwiftData best practices

### AI & Intelligence
- `FoundationModels-Using-on-device-LLM-in-your-app.md` - On-device LLM integration
- `Implementing-Visual-Intelligence-in-iOS.md` - Visual intelligence features
- `Implementing-Assistive-Access-in-iOS.md` - Accessibility features

### Frameworks
- `AppIntents-Updates.md` - App Intents and Shortcuts
- `StoreKit-Updates.md` - StoreKit changes
- `MapKit-GeoToolbox-PlaceDescriptors.md` - MapKit updates
- `Swift-Charts-3D-Visualization.md` - 3D charts
- `SwiftUI-AlarmKit-Integration.md` - AlarmKit integration
- `SwiftUI-WebKit-Integration.md` - WebKit in SwiftUI
- `SwiftUI-New-Toolbar-Features.md` - Toolbar updates
- `SwiftUI-Styled-Text-Editing.md` - Styled text editing
- `Foundation-AttributedString-Updates.md` - AttributedString updates
- `Widgets-for-visionOS.md` - visionOS widgets

## Usage

When asked about any of these topics, read the relevant documentation file first:

```
Read /Applications/Xcode.app/Contents/Plugins/IDEIntelligenceChat.framework/Resources/AdditionalDocumentation/[filename].md
```

## Key Patterns for watchOS

### Liquid Glass on Watch
```swift
// From WidgetKit-Implementing-Liquid-Glass-Design.md
Text("Status")
    .glassEffect()
    .glassEffect(in: .rect(cornerRadius: 12))
```

### Modern Concurrency
```swift
// From Swift-Concurrency-Updates.md
@MainActor
class WatchService {
    func connect() async throws { }
}
```

### Foundation Models (Future)
```swift
// From FoundationModels-Using-on-device-LLM-in-your-app.md
let model = SystemLanguageModel.default
let session = LanguageModelSession(instructions: "...")
```
