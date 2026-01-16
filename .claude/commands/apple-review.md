# Apple Platform Code Review

Review the current codebase against Apple's latest best practices.

## Instructions

1. **Search Apple Documentation** for the relevant frameworks being used
2. **Check WWDC sessions** for recent updates (especially WWDC 2024-2025)
3. **Verify HIG compliance** for the target platform
4. **Identify deprecated APIs** and suggest modern replacements

## Focus Areas

- SwiftUI lifecycle and state management
- Concurrency patterns (async/await, actors)
- Platform-specific HIG (watchOS, iOS, macOS)
- Accessibility requirements
- Performance optimization

## Tools to Use

Use the `apple-docs` MCP server tools:
- `search_apple_docs` - Find relevant documentation
- `get_platform_compatibility` - Check API availability
- `search_wwdc_videos` - Find WWDC sessions on topics
- `find_similar_apis` - Discover modern alternatives

Provide specific file:line references and code examples for all recommendations.
