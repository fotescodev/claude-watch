# Claude Watch - Session Onboarding

**Read this first.** This document tells you where to find what you need.

## What is Claude Watch?

A watchOS app that lets developers approve/reject Claude Code changes from their Apple Watch via:
- Real-time WebSocket communication
- Push notifications with actionable buttons
- Voice commands
- Watch face complications

## What's Next?

**Check `ralph/tasks.yaml`** - this is the single source of truth for current work.

```bash
cat .claude/ralph/tasks.yaml | head -100
```

Tasks are organized by:
- `priority`: critical > high > medium > low
- `parallel_group`: Lower numbers = higher priority
- `completed`: true/false

## The Funnel Model

```
inbox/ → plans/ → tasks.yaml → archive/
(ideas)  (refined)  (execute)   (done)
```

| Directory | Purpose |
|-----------|---------|
| `inbox/` | Raw ideas, quick captures (unprocessed) |
| `plans/` | Refined plans ready for review |
| `context/` | Always-on context (PRD, personas, journeys) |
| `ralph/tasks.yaml` | THE source of truth for execution |
| `archive/` | Completed or obsolete content |

## Key Files

| File | Purpose |
|------|---------|
| `/CLAUDE.md` | Coding standards, project structure |
| `/CONTRIBUTING.md` | Developer setup, PR process |
| `.claude/ralph/tasks.yaml` | Current work queue |
| `.claude/plans/` | Active plans under consideration |
| `.claude/decisions/` | Architecture Decision Records (ADRs) |

## Directory Structure

```
.claude/
├── ONBOARDING.md          # You are here
├── inbox/                  # Unprocessed ideas
├── plans/                  # Refined plans
├── context/                # Always-on context (PRD, personas)
├── ralph/
│   ├── tasks.yaml          # THE execution queue
│   ├── ralph.sh            # Task executor
│   └── PROMPT.md           # Working prompts
├── decisions/              # ADRs
├── archive/                # Completed/obsolete
│   ├── plans/
│   ├── ralphie/
│   └── sessions/
├── settings.json           # Claude settings
└── SKILLS.md               # Skill definitions
```

## Quick Start

1. **Check current work**: `cat .claude/ralph/tasks.yaml | grep -A5 'completed: false' | head -30`
2. **Find incomplete tasks**: Look for `completed: false` in tasks.yaml
3. **Read CLAUDE.md**: For coding standards and patterns
4. **Build the app**: `xcodebuild -project ClaudeWatch.xcodeproj -scheme ClaudeWatch -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'`

## Don't Waste Tokens

- Don't explore random directories looking for context
- Don't read old session logs in `.specstory/`
- Don't hunt through multiple plan directories
- **Do** check tasks.yaml first, then CLAUDE.md if needed
