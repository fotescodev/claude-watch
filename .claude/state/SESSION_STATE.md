# Session State - Claude Watch

> Last updated: 2026-02-19
> Session: Hooks-Based Architecture Pivot
>
> **Branch:** `restructuring`

## Single Source of Truth

**`.claude/plans/MIGRATION_PROGRESS.md`** — all workstream tracking, test counts, timeline.

## Current State

**Architecture pivoted from bridge-based to hooks-based (2026-02-19).**

```
[x] Hooks-based architecture (primary)
    - remmy-cli installs hook → ~/.claude/hooks/watch-approval-cloud.py
    - Registers in ~/.claude/settings.json (PreToolUse)
    - Spawns Claude with CLAUDE_WATCH_SESSION_ACTIVE=1
    - Claude runs with NATIVE TUI (no --sdk-url, no custom UI)
    - Hook talks directly to cloud worker

[x] TUI code removed (~1,754 LOC)
    - remmy-cli/src/tui/ deleted (17 files)
    - 6 npm deps removed (ink, react, @inkjs/ui, marked, marked-terminal, ws)
    - Bridge TUI endpoints removed (api.py, session.py, main.py)

[x] Tests updated
    - CLI: 143 tests passing (was 129)
    - Bridge: 346 tests passing (was 379 — TUI WS tests removed)
    - 14 new hooks-config tests

[ ] Docs updated (ARCHITECTURE.md, DATA_FLOW.md, SESSION_STATE.md)
[ ] CLAUDE.md bridge references need cleanup
[ ] bun install to update lockfile
[ ] .auto-claude/ deletion (617 MB)
[ ] MEMORY.md update
```

## Architecture

```
remmy-cli → install hook → spawn claude (native TUI)
                ↓
     watch-approval-cloud.py (PreToolUse hook)
                ↓
         Cloud Worker ← Watch polls
```

## Key Decision: Why Pivot?

The bridge was over-engineered for MVP. Claude Code's native TUI is excellent — what we need is the watch as a **transparent background notification layer** via hooks. The hook talks directly to the cloud worker. The watch polls the cloud worker directly. No intermediary needed.

The bridge remains available (346 tests, battle-tested) for advanced use cases requiring multi-option questions, exact token tracking, or real-time streaming.

## Key Learnings

1. Hooks-based approach from `claude-watch-npm` was the proven pattern all along
2. `CLAUDE_WATCH_SESSION_ACTIVE=1` env var provides clean session isolation
3. Bun `mock.module()` bleeds across files — hooks-config tests must run in separate invocation
4. Bridge TUI cleanup required careful removal of `broadcast_to_tui` calls across 3 files
