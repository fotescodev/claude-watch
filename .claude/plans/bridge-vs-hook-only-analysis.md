# Bridge Server vs Hook-Only Approach

**Status:** Not prioritized — revisit when bridge becomes a pain point.

## Current State

`remmy-cli` starts a bridge server as a long-lived background process. It manages WebSocket connections, handles reconnects, and relays approvals between Claude Code hooks and the cloud worker (which pushes to the watch).

## What Hook-Only Would Change

Remove the bridge server entirely. The hook script talks directly to the cloud worker over HTTP. Each approval is a stateless round-trip. `remmy-cli` installs the hook and exits — no daemon to keep alive.

## Why It's Not Worth Doing Now

- The bridge works. Users don't care about the architecture, they care that the watch buzzes.
- The migration effort is non-trivial for zero user-visible improvement.
- Risk of introducing regressions in a working approval flow.

## When It Becomes Worth Doing

- **Distribution:** Simpler setup = fewer support issues if others adopt this.
- **Reliability:** If the bridge server becomes a recurring failure point.
- **Lightweight install:** If we want `remmy-cli` to be a "run and forget" tool, not a "keep this server running" tool.

## TL;DR

Elegance improvement, not a functional one. Ship what works. Revisit when the bridge actually hurts.
