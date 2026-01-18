# Contributing to Claude Watch

## Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Apple Watch or watchOS Simulator
- Node.js 18+ (for MCP server/CLI)
- Python 3.11+ (for legacy server)

## Quick Start

### 1. Clone and Open

```bash
git clone https://github.com/your-org/claude-watch.git
cd claude-watch
open ClaudeWatch.xcodeproj
```

### 2. Build for Simulator

```bash
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

### 3. Run the CLI

```bash
npm install -g cc-watch
cc-watch --help
```

## Development Workflow

### Finding Work

1. Check `.claude/ralph/tasks.yaml` for current tasks
2. Look for `completed: false` items
3. Pick tasks by priority: critical > high > medium > low

### Making Changes

1. Create a feature branch: `git checkout -b feat/your-feature`
2. Make changes following `CLAUDE.md` coding standards
3. Build and test on simulator
4. Commit with conventional format: `feat(scope): description`

### Commit Message Format

```
type(scope): short description

- Bullet points for details
- Keep lines under 72 chars

Co-Authored-By: Your Name <email>
```

Types: `feat`, `fix`, `docs`, `refactor`, `test`, `chore`

Scopes: `watch`, `server`, `cli`, `cloud`, `a11y`, `ui`

## Code Style

See `CLAUDE.md` for full standards. Key points:

- Swift: async/await, guard for early exits, value types preferred
- SwiftUI: @State for local, @Observable for view models
- watchOS: Minimal UI, single-glance interactions, haptic feedback

## Testing

### Watch App

```bash
# Build for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

### CLI

```bash
cd cc-watch-npm
npm test
```

## Project Structure

```
claude-watch/
├── ClaudeWatch/           # watchOS app (Swift/SwiftUI)
├── MCPServer/             # Python server (legacy)
├── cc-watch-npm/          # Node.js CLI (npm package)
├── docs/                  # User-facing guides
└── .claude/               # Internal docs (see CLAUDE.md)
```

## Need Help?

- Read `CLAUDE.md` for coding standards
- Check `.claude/ONBOARDING.md` for project context
- Review `.claude/context/PRD.md` for product vision
