# Agent Guide

> How to work effectively on Claude Watch. Read this to know what to read.

---

## Before You Solve Anything

1. **Read** `.claude/ARCHITECTURE.md` (5 min) - System skeleton, data flows, constraints
2. **Read** `.claude/state/SESSION_STATE.md` (2 min) - Current phase, handoff notes
3. **Check** watch mode: Is `CLAUDE_WATCH_SESSION_ACTIVE=1` set?

**If you skip step 1, you will propose incomplete solutions.**

---

## Reading Order by Task Type

### Debugging

```
1. .claude/ARCHITECTURE.md → Which component is failing?
2. .claude/DATA_FLOW.md → Trace the exact endpoint flow
3. docs/solutions/INDEX.md → Is there a known fix?
4. /tmp/claude-watch-hook-debug.log → Hook-specific errors
```

### New Feature

```
1. .claude/ARCHITECTURE.md → Where does this fit?
2. .claude/state/SESSION_STATE.md → Current phase context
3. .claude/plans/phase{N}-CONTEXT.md → Relevant decisions
4. Identify ALL components that need changes (usually 2-3)
```

### Bug Fix

```
1. .claude/ARCHITECTURE.md → Which flow is affected?
2. .claude/DATA_FLOW.md → File locations for that flow
3. Implement fix in CORRECT component
4. If fix spans components, update ALL of them
```

### Refactoring

```
1. .claude/ARCHITECTURE.md → Understand current structure
2. .claude/DATA_FLOW.md → Find all callers/callees
3. Verify changes don't break data flows
```

---

## Documentation Hierarchy

| Audience | Primary Docs | When to Read |
|----------|--------------|--------------|
| **Agents** | `ARCHITECTURE.md`, `AGENT_GUIDE.md` | ALWAYS first |
| **Agents** | `DATA_FLOW.md` | When tracing API flows |
| **Agents** | `SESSION_STATE.md` | Session start |
| **Developers** | `phase{N}-CONTEXT.md` | Implementation decisions |
| **Users** | `docs/GETTING_STARTED.md` | Setup, troubleshooting |

---

## Context Update Protocol

### MUST Update (Immediately)

- New endpoint added → Update `DATA_FLOW.md`
- New component added → Update `ARCHITECTURE.md` diagram
- New constraint discovered → Add to `ARCHITECTURE.md` Learnings Log

### SHOULD Update (Before Session End)

- Bug fixed → Add to `docs/solutions/`
- Process changed → Update `AGENT_GUIDE.md`

### MAY Update (When Stable)

- User-facing changes → Update `docs/GETTING_STARTED.md`
- CLI changes → Update `README.md`

---

## Compounding Knowledge

Before ending your session, run `/compound` to capture learnings.

### What to Document

1. **Architecture Discovery**: Found an undocumented data flow or constraint?
   → Add to `ARCHITECTURE.md` under `## Learnings Log`

2. **Bug Pattern**: Fixed a bug that could recur?
   → Add to `docs/solutions/` following INDEX.md format

3. **Process Improvement**: Found a better workflow?
   → Add to `AGENT_GUIDE.md` under relevant task type

### Learnings Log Format

```markdown
### YYYY-MM-DD: Brief title
- Key insight line 1
- Key insight line 2
- Key insight line 3 (max)
```

---

## Quick Reference

### Key Commands

| Command | Purpose |
|---------|---------|
| `/progress` | Session orientation |
| `/build` | Build for simulator |
| `/deploy-device` | Deploy to physical watch |
| `/ship-check` | Pre-submission validation |
| `/compound` | Capture learnings |

### Key Directories

| Path | Contains |
|------|----------|
| `ClaudeWatch/` | watchOS app (Swift) |
| `claude-watch-cloud/` | Cloudflare Worker (TypeScript) |
| `claude-watch-npm/` | CLI tool (TypeScript) |
| `.claude/hooks/` | Claude Code hooks (Python) |

### Environment Variables

| Variable | Meaning |
|----------|---------|
| `CLAUDE_WATCH_SESSION_ACTIVE=1` | Watch mode active |
| `CLAUDE_WATCH_PAIRING_ID` | Current pairing |
| `CLAUDE_WATCH_DEBUG=1` | Verbose logging |

---

## Common Mistakes

### Mistake 1: Incomplete Solutions

**Wrong:** "I'll add the endpoint to the cloud worker"
**Right:** "This needs changes in: hook (send), cloud (route), watch (poll)"

### Mistake 2: Not Reading Architecture First

**Wrong:** "Let me explore the codebase to understand..."
**Right:** "According to ARCHITECTURE.md, approvals flow Hook → Cloud → Watch"

### Mistake 3: Forgetting Watch Constraints

**Wrong:** "I'll add a multi-select question"
**Right:** "Watch can only tap approve/reject, so I'll ask yes/no"

### Mistake 4: Not Updating Docs

**Wrong:** Complete fix, move on
**Right:** Complete fix, add to Learnings Log if it was undocumented

---

## Files You Should Never Ignore

1. `.claude/ARCHITECTURE.md` - System structure
2. `.claude/state/SESSION_STATE.md` - Handoff context
3. `CLAUDE.md` - Project constraints and standards
4. `.claude/DATA_FLOW.md` - API reference

---

*Last updated: 2026-01-23*
