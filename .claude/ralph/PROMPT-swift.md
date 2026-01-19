# Swift & SwiftUI Code Standards

This module is loaded for tasks tagged with: `swift`, `swiftui`, `build`, `quality`

---

## Swift Style
- Use `async/await` for async operations
- Prefer `guard` for early exits
- Use `@MainActor` for UI updates
- Follow Swift API Design Guidelines
- Use Swift 5.9+ features (macros, parameter packs where applicable)
- Prefer value types (structs) over reference types (classes)

## SwiftUI Patterns
- Use `@State` for local view state
- Use `@Environment` for dependency injection
- Use `@Observable` macro (iOS 17+/watchOS 10+)
- Keep views under 100 lines
- Use `@WKApplicationDelegateAdaptor` for AppDelegate (watchOS)

## Code Quality
- No force unwraps (`!`) without justification in comments
- No new compiler warnings introduced
- Follow existing patterns in codebase
- Prefer `guard` for early exits

## Xcode Project Sync (CRITICAL)

**Xcode projects require explicit file registration.** New files on disk don't automatically compile.

When creating a NEW `.swift` file:

1. Create the file with Write tool
2. Add to `*.xcodeproj/project.pbxproj`:
   - `PBXFileReference` entry
   - `PBXBuildFile` entry
   - Add to appropriate `PBXGroup`
   - Add to `PBXSourcesBuildPhase`

**Verify sync:**
```bash
# Check all Swift files are in project
for f in $(find ClaudeWatch -name "*.swift" ! -path "*/Tests/*"); do
  grep -q "$(basename $f)" ClaudeWatch.xcodeproj/project.pbxproj || echo "MISSING: $f"
done
```
