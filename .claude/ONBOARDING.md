# Claude Watch - Session Onboarding

> **IMPORTANT**: This document is your starting point. Read it, run `/progress`, then start working.

---

## Instant Orientation (Do This First)

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Run /progress                                               │
│     → Shows: current phase, next tasks, blockers, recent work   │
│                                                                 │
│  2. Read .claude/state/SESSION_STATE.md                         │
│     → Shows: handoff notes, decisions, what happened last time  │
│                                                                 │
│  3. Check tasks.yaml for your specific task                     │
│     → Shows: detailed task description, acceptance criteria     │
└─────────────────────────────────────────────────────────────────┘
```

**DO NOT** randomly explore the codebase. Use the structured context above.

---

## What is Claude Watch?

A watchOS app that lets developers approve/reject Claude Code changes from their Apple Watch via:
- Real-time WebSocket communication
- Push notifications with actionable buttons
- Voice commands
- Watch face complications

**Current Status**: ~90% feature complete, preparing for TestFlight

---

## Session Workflow

```
SESSION START
│
├─→ /progress            # See phase, tasks, blockers
│
├─→ SESSION_STATE.md     # Read handoff notes
│
├─→ Pick a task from tasks.yaml
│
│   BEFORE NEW PHASE
│   └─→ /discuss-phase N  # Capture decisions first
│
│   DURING IMPLEMENTATION
│   └─→ Commit atomically per task
│
│   BEFORE SHIPPING
│   └─→ /ship-check       # Validate submission readiness
│
SESSION END
│
└─→ Update SESSION_STATE.md with handoff notes
```

---

## Key Commands

| Command | Purpose | When |
|---------|---------|------|
| `/progress` | Quick status overview | **Session start** |
| `/discuss-phase N` | Capture decisions | Before new phase |
| `/ship-check` | Pre-submission validation | Before TestFlight |
| `/build` | Build for simulator | Development |
| `/deploy-device` | Deploy to watch | Device testing |
| `/fix-build` | Diagnose build errors | When build fails |

---

## File Hierarchy (What to Read When)

### Orientation (read first)
| File | Purpose |
|------|---------|
| `.claude/state/SESSION_STATE.md` | **Handoff context** - what happened, what's next |
| `.claude/ralph/tasks.yaml` | **Task queue** - current work definitions |

### Context (read as needed)
| File | Purpose |
|------|---------|
| `CLAUDE.md` | Coding standards, project structure |
| `.claude/context/PRD.md` | Product requirements |
| `.claude/plans/APPSTORE-ROADMAP.md` | 8-10 week shipping plan |
| `.claude/plans/phase5-CONTEXT.md` | Current phase decisions |

### Reference (read when debugging)
| Directory | Purpose |
|-----------|---------|
| `docs/solutions/` | Documented fixes for past issues |
| `.claude/decisions/` | Architecture Decision Records |

---

## Directory Structure

```
.claude/
├── state/
│   └── SESSION_STATE.md    # ← START HERE (handoff persistence)
├── ralph/
│   └── tasks.yaml          # ← Task definitions
├── commands/               # Slash commands
│   ├── progress.md         # /progress
│   ├── discuss-phase.md    # /discuss-phase
│   └── ship-check.md       # /ship-check
├── plans/                  # Roadmaps and phase context
│   ├── APPSTORE-ROADMAP.md
│   └── phase5-CONTEXT.md
├── context/                # Always-on context
│   └── PRD.md
├── hooks/                  # Integration with Claude Code
├── agents/                 # Specialized subagents
├── inbox/                  # Raw ideas (unprocessed)
├── scope-creep/            # Future dreams (ignore)
└── archive/                # Completed work
```

---

## Don't Waste Tokens

**DON'T:**
- Explore random directories looking for context
- Read old session logs in `.specstory/` or `archive/`
- Hunt through multiple plan directories
- Search the entire codebase to "understand the project"

**DO:**
1. Run `/progress` for instant orientation
2. Read `SESSION_STATE.md` for handoff context
3. Read the specific task from `tasks.yaml`
4. Read source files only when implementing

---

## Ralph + GSD Integration

**Ralph** handles task execution. **GSD practices** handle session management.

```
┌─────────────────────────────────────────────────────────────────┐
│                        SESSION LIFECYCLE                         │
│                                                                 │
│  GSD: /progress              Ralph: tasks.yaml                  │
│       ↓                            ↓                            │
│  "You're in Phase 5"         "BF1: Fix notifications"           │
│  "3 blockers exist"          "Priority: critical"               │
│       ↓                            ↓                            │
│  GSD: /discuss-phase         Ralph: Execute task                │
│       ↓                            ↓                            │
│  phase5-CONTEXT.md           Commit atomically                  │
│       ↓                            ↓                            │
│  GSD: /ship-check            Ralph: Mark complete               │
│       ↓                            ↓                            │
│  "Ready to ship"             Update tasks.yaml                  │
│       ↓                            ↓                            │
│  GSD: Update SESSION_STATE   Ralph: Archive completed           │
└─────────────────────────────────────────────────────────────────┘
```

**Key principle**: GSD provides the "where are we" context. Ralph provides the "what to do" details.

---

## Pairing Flow (CRITICAL)

**Watch shows code → CLI receives code**

```bash
# 1. On watch: Tap "Pair Now" → watch displays code
# 2. On Mac:
npx cc-watch
# 3. Enter the code from watch into CLI
```

---

## Quick Reference

```bash
# Build for simulator
xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'

# Find incomplete tasks
grep -A5 'completed: false' .claude/ralph/tasks.yaml | head -30

# Check session state
cat .claude/state/SESSION_STATE.md
```

---

*Last updated: 2026-01-19*
