# SDK-URL Migration Progress

> **Branch**: `claude/investigate-websocket-terminal-utUEt`
> **Spec**: `.claude/plans/sdk-url-agent-execution-spec.md`
> **Plan**: `.claude/plans/sdk-url-migration-plan.md`
> **Last updated**: 2026-02-11

## Workstream A: Bridge Server
- [x] A1: NDJSON WebSocket Server — DONE (229 lines, 11 tests)
- [x] A2: Message Types & Session State — DONE (317+266 lines, 57 tests)
- [x] A3: Permission Handler — DONE (177 lines, 21 tests)
- [x] A4: AskUserQuestion Handler — DONE (175 lines, 20 tests)
- [x] A5: Progress Tracker — DONE (280 lines, 43 tests)
- [ ] A6: CLI Launcher — PENDING
- [ ] A7: Watch-Facing REST API — PENDING
- [ ] A8: Bridge Entrypoint — PENDING

## Workstream B: cc-watch CLI
- [ ] B1: Launch Bridge + CLI — PENDING
- [ ] B2: Cloud Worker Relay — PENDING

## Workstream C: Watch App
- [ ] C1: Zero Changes for MVP — PENDING
- [ ] C2: Direct WebSocket (Post-MVP) — PENDING

## Workstream D: Integration Tests
- [ ] D1: End-to-End Approval Flow — PENDING
- [ ] D2: End-to-End Question Flow — PENDING
- [ ] D3: End-to-End Progress Flow — PENDING
- [ ] D4: End-to-End Interrupt Flow — PENDING
- [ ] D5: CLI Launcher Integration — PENDING
- [ ] D6: Regression Test Against Current Watch API Contract — PENDING

## Workstream E: New Capabilities
- [ ] E1: Permission Learning ("Always Allow" Button) — PENDING
- [ ] E2: Model Switching from Watch — PENDING
- [ ] E3: Real-Time Streaming — PENDING
- [ ] E4: Session Resume on Crash — PENDING
- [ ] E5: File Undo from Watch — PENDING

## Workstream F: Cleanup
- [ ] F1: Remove Legacy Hooks — PENDING
- [ ] F2: Remove Cloud Worker Approval Endpoints — PENDING
- [ ] F3: Remove Temp Files & Config — PENDING

## Quality Reviews

| Task | Rating | Tests | Reviewer Notes |
|------|--------|-------|---------------|
| A1: NDJSON Server | 9/10 | 11/11 | Clean async server, proper error handling, path validation, keep_alive filtering. Minor: could add configurable path prefix. |
| A2: Types & Session | 8/10 | 57/57 | All message types covered, camelCase conversion works. Minor: some protocol fields not yet mapped (compact_boundary, task_notification). Good enough for MVP. |
| A3: Permissions | 9/10 | 21/21 | Approve/deny/approve_all all correct. Auto-accept mode works. updatedInput passthrough correct. Clean separation of concerns. |
| A4: Questions | 9/10 | 20/20 | Recommendation extraction, updatedInput.answers construction, deny fallback all per spec. Multi-question support works. Key Phase 10 fix validated. |
| A5: Progress | 8/10 | 43/43 | TodoWrite extraction, context %, compaction lifecycle, tool activity formatting all working. Minor: session_to_watch_progress could include isCompacting field. |

## Execution Timeline

```
WEEK 1: Foundation
  A1 -> A2 -> A3 (NDJSON server + types + permissions)
  A4 (questions handler, parallel with A3)
  A5 (progress tracker, parallel with A3)

WEEK 2: Integration
  A6 (CLI launcher)
  A7 (REST API matching current cloud contract)
  A8 (entrypoint + initialize)
  D6 (API compatibility regression tests)

WEEK 3: CLI + E2E
  B1 (cc-watch launches bridge)
  D1-D5 (all E2E integration tests)
  C1 (verify watch works with zero changes)

WEEK 4: New capabilities
  E1-E5 (permission learning, model switch, streaming, resume, undo)

WEEK 5: Cleanup
  F1-F3 (remove hooks, cloud endpoints, temp files)
  C2 (optional: direct WebSocket from watch)
```

## Commits

| Commit | Description | Tasks |
|--------|-------------|-------|
| `2198da5` | research: analyze --sdk-url WebSocket protocol | Research/analysis |
| `8183c66` | plan: comprehensive --sdk-url migration with feature parity matrix | Planning |
| `d6d354d` | spec: agent-executable --sdk-url migration with AC and tests | Spec (all tasks) |
