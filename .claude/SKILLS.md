# Claude Code Skills & Plugins for ClaudeWatch

This document describes the recommended skills and MCP servers for developing this watchOS application.

## MCP Servers (Configured in settings.json)

### 1. apple-docs-mcp
**Source:** https://github.com/kimsungwhee/apple-docs-mcp

Provides real-time access to Apple's developer documentation, WWDC videos, and framework APIs.

**Available Tools:**
| Tool | Purpose |
|------|---------|
| `search_apple_docs` | Search Apple documentation |
| `get_apple_doc_content` | Get detailed docs with analysis |
| `search_framework_symbols` | Search symbols in frameworks |
| `get_platform_compatibility` | Check API availability/deprecation |
| `find_similar_apis` | Discover modern alternatives |
| `search_wwdc_videos` | Search WWDC sessions |
| `get_wwdc_video_details` | Get video transcripts |

**Usage Examples:**
```
"Search for watchOS WidgetKit complications"
"Get platform compatibility for WKExtension"
"Find WWDC sessions about SwiftUI performance"
"Show similar APIs to presentTextInputController"
```

### 2. claude-watch (Local)
The project's own MCP server for Apple Watch integration.

---

## Axiom Skills (Install Separately)

**Source:** https://github.com/CharlesWiltgen/Axiom
**Docs:** https://charleswiltgen.github.io/Axiom

### Installation

In Claude Code desktop app:
```
/plugin marketplace add CharlesWiltgen/Axiom
```

Then search for "axiom" in `/plugin` menu.

### Recommended Skills for This Project

| Skill | Use Case |
|-------|----------|
| `axiom-liquid-glass` | Implement iOS 26 Liquid Glass materials |
| `axiom-swiftui-performance` | Optimize SwiftUI view updates |
| `axiom-swiftui-26-ref` | Reference for iOS 26 SwiftUI features |
| `axiom-swift-concurrency` | Fix Swift 6 concurrency issues |
| `axiom-xcode-debugging` | Troubleshoot build failures |
| `axiom-memory-debugging` | Find memory leaks with Instruments |
| `accessibility-debugging` | WCAG/VoiceOver compliance |

### When Skills Activate

Skills activate automatically based on context:
- "BUILD FAILED" → `axiom-xcode-debugging`
- "Swift 6 concurrency errors" → `axiom-swift-concurrency`
- "Liquid Glass design" → `axiom-liquid-glass`
- "Memory leak" → `axiom-memory-debugging`

---

## Custom Slash Commands

Located in `.claude/commands/`:

### /apple-review
Comprehensive code review against Apple best practices.
```
/apple-review
```

### /watchos-audit
watchOS-specific HIG and API audit.
```
/watchos-audit
```

### /liquid-glass
Audit for iOS 26 Liquid Glass design readiness.
```
/liquid-glass
```

---

## Recommended Workflow

### For New Features
1. Query `apple-docs` for latest API patterns
2. Check WWDC sessions for implementation guidance
3. Use Axiom skills for platform-specific patterns
4. Run `/watchos-audit` before committing

### For Bug Fixes
1. Use `axiom-xcode-debugging` for build issues
2. Query `get_platform_compatibility` for deprecated APIs
3. Check `find_similar_apis` for modern replacements

### For Design Work
1. Use `axiom-liquid-glass` for material guidance
2. Query WWDC sessions on design system
3. Run `/liquid-glass` audit on views

---

## Environment Requirements

- **macOS:** 15+ (Sequoia)
- **Xcode:** 16+ (26 for iOS 26 features)
- **Node.js:** 18+ (for apple-docs-mcp)
- **Python:** 3.10+ (for claude-watch MCP server)

## Quick Start

```bash
# Install apple-docs-mcp globally (optional, npx works too)
npm install -g @kimsungwhee/apple-docs-mcp

# Install Python dependencies for local MCP server
pip install -r MCPServer/requirements.txt

# Verify MCP servers work
npx @kimsungwhee/apple-docs-mcp --version
python MCPServer/server.py --help
```
