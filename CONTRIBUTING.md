# Contributing to Remmy

Thanks for your interest in contributing to Remmy -- the Apple Watch interface for Claude Code.

## Project Overview

Remmy has four components:

| Component | Language | Location | Purpose |
|-----------|----------|----------|---------|
| **Watch App** | Swift/SwiftUI | `ClaudeWatch/` | watchOS app (approve/reject, UI, complications) |
| **CLI** | TypeScript | `remmy-cli/` | Pairing, hook installation, launches Claude |
| **Cloud Worker** | TypeScript/Hono | `claude-watch-cloud/` | Cloudflare Worker relay between hook and watch |
| **Hook** | Python | `remmy-cli/hooks/watch-approval-cloud.py` | PreToolUse hook that intercepts Claude tool calls |
| **Bridge** (advanced) | Python | `MCPServer/bridge/` | Optional WebSocket bridge for richer capabilities |

## Getting Started

### Prerequisites

- **Xcode 15+** with watchOS SDK
- **Bun** runtime (`curl -fsSL https://bun.sh/install | bash`)
- **Python 3.10+** (for bridge tests)
- **Node.js 18+** (for Cloudflare Worker)

### Setup

```bash
# Clone the repo
git clone https://github.com/fotescodev/claude-watch.git
cd claude-watch

# Build the CLI
cd remmy-cli && bun install && bun run build && cd ..

# Build the watch app (simulator)
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)'
```

### Running Tests

```bash
# Bridge tests (Python)
python -m pytest MCPServer/bridge/tests/ -q

# CLI tests (TypeScript) -- must split due to bun mock isolation
cd remmy-cli && bun test src/ui/ src/lib/ src/cli.test.ts && bun test src/commands/
```

## Architecture

**Read [ARCHITECTURE.md](.claude/ARCHITECTURE.md) before proposing changes.** It maps every component, data flow, and file location.

The primary architecture is **hooks-based**:

```
Claude CLI  --PreToolUse hook-->  Cloud Worker  <--polls--  Apple Watch
```

Most features touch 2-3 components. Check the architecture doc for which files to modify for common tasks.

## Key Documentation

| Doc | When to Read |
|-----|-------------|
| [ARCHITECTURE.md](.claude/ARCHITECTURE.md) | Before proposing any solution |
| [DATA_FLOW.md](.claude/DATA_FLOW.md) | When working with API endpoints |
| [Solutions Index](docs/solutions/INDEX.md) | Before debugging (may already be solved) |
| [Getting Started](docs/GETTING_STARTED.md) | First-time setup |

## Coding Standards

### Swift (Watch App)

- Swift 5.9+, prefer `async/await` for all async operations
- Follow Apple's Swift API Design Guidelines
- Use `guard` for early exits, prefer value types (structs)
- Use `@Observable` macro for view models (watchOS 10+)
- Keep views under 100 lines where possible
- No force unwrapping (`!`) without justification
- No UIKit -- watchOS uses WatchKit/SwiftUI only

### TypeScript (CLI)

- Strict mode, no `any` types
- Tests colocated with source (`*.test.ts`)
- Bun runtime for tests and dev

### Python (Bridge/Hook)

- Type hints throughout
- `pytest` for testing
- `asyncio`/`aiohttp` for async operations

## Workflow

1. **Read the architecture doc** before writing code
2. **Check solutions index** before debugging
3. **Create a branch** from `main`
4. **Make focused changes** -- one concern per PR
5. **Run tests** before pushing
6. **Write clear commit messages** -- what and why, not how

## Common Tasks

| Task | Components to Modify |
|------|---------------------|
| Add new approval type | Hook + Cloud Worker + Watch |
| Change notification content | Hook + Cloud Worker (APNs payload) |
| Add new UI element | Watch app only |
| Change polling interval | Watch app only (`WatchService.swift`) |
| Add new API endpoint | Cloud Worker + caller (Hook or Watch) |
| Change hook behavior | `remmy-cli/hooks/watch-approval-cloud.py` |

## Environment Variables

| Variable | Purpose |
|----------|---------|
| `CLAUDE_WATCH_SESSION_ACTIVE=1` | Gates watch approval mode (set by `remmy` CLI) |
| `REMMY_CLOUD_URL` | Override cloud relay URL |
| `REMMY_DEBUG` | Enable verbose hook logging |

## Questions?

- Check [docs/solutions/INDEX.md](docs/solutions/INDEX.md) for known issues
- Open an issue on GitHub
