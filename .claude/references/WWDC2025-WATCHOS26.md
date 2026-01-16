# watchOS 26 & Liquid Glass Reference (WWDC 2025)

> **Note:** Apple changed version numbering to match the year. watchOS 11 is now **watchOS 26**.

## Key Changes

### Liquid Glass Design System

The beauty of SwiftUI is that developers don't need extensive code changes to adopt Liquid Glass - simply recompiling with Xcode 26 brings the new design automatically.

**Automatic Adaptations:**
- `TabView` automatically gets liquid tab bar
- `NavigationSplitView` becomes liquid glass sidebar
- Partial-height sheets get inset Liquid Glass background
- Toolbar items float on Liquid Glass surface

**New APIs for Customization:**
```swift
// Apply liquid glass material
.background(.liquidGlass)
.liquidGlassMaterial()

// Glass effect modifier
.glassEffect(_:in:isEnabled:)

// Background extension outside safe area
.backgroundExtensionEffect()
```

### watchOS 26 Specific Features

- **Custom Controls** - Mark favorite locations with a tap while walking
- **Widget Relevance APIs** - New APIs for widget relevance scoring
- **New Complications** - Enhanced complication families

## SwiftUI Updates (All Platforms)

### Performance
- Large lists on macOS load **6x faster**
- New SwiftUI Performance Instrument in Xcode

### New Views & APIs

```swift
// WebKit integration
WebView(url: URL(string: "https://...")!)

// 3D Charts
Chart3D { ... }

// Rich Text Editor
RichTextEditor(text: $attributedString)

// Animation macro
@Animatable
struct MyShape: Shape { ... }
```

### Materials & Effects

```swift
// Liquid Glass materials
.background(.ultraThinMaterial)  // Still works
.background(.liquidGlass)         // New in iOS 26

// Controls transform into liquid glass during interaction
Toggle("Option", isOn: $value)
    // Automatically gets liquid glass treatment
```

### Toolbar & Navigation

```swift
// Toolbars float above content
.toolbar {
    ToolbarItem(placement: .automatic) {
        Button("Action") { }
    }
}
// Items automatically grouped on Liquid Glass surface
```

### Sheets

```swift
// Partial height sheets are inset with Liquid Glass
.sheet(isPresented: $showSheet) {
    ContentView()
        .presentationDetents([.medium, .large])
    // Automatically gets curved edges, liquid glass background
}
```

## Design Resources

- **Icon Composer** - Create Liquid Glass icons for all platforms
- **Updated HIG** - Comprehensive Liquid Glass documentation
- **New UI Kits** - Available on Apple Design Resources

## Must-Watch WWDC 2025 Sessions

1. **"Meet Liquid Glass"** - Deep dive into the design material
2. **"Get to know the new design system"** - Best practices
3. **"What's new in SwiftUI"** (Session 256) - All SwiftUI updates
4. **"Build a SwiftUI app with the new design"** (Session 323) - Practical guide

## Migration Checklist for ClaudeWatch

### Automatic (Just Recompile)
- [ ] TabView gets liquid tab bar
- [ ] Sheets get liquid glass background
- [ ] Toolbar items float on glass

### Manual Updates Needed
- [ ] Replace `.background(Color.X.opacity(Y))` with `.background(.liquidGlass)`
- [ ] Update `.ultraThinMaterial` to `.liquidGlass` where appropriate
- [ ] Use new `glassEffect()` modifier for custom glass effects
- [ ] Add `backgroundExtensionEffect()` for content extending to edges

### Deprecated to Remove
- [ ] `WKExtension.shared()` → Use `UIApplication.shared` equivalent
- [ ] `presentTextInputController` → Use SwiftUI text input or Speech framework

## Sources

- [What's new in SwiftUI - WWDC25](https://developer.apple.com/videos/play/wwdc2025/256/)
- [Build a SwiftUI app with the new design - WWDC25](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple introduces Liquid Glass](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [Liquid Glass Reference (Community)](https://github.com/conorluddy/LiquidGlassReference)
- [Liquid Glass UI Components](https://github.com/dambertmunoz/dm-swift-swiftui-liquid-glass)
