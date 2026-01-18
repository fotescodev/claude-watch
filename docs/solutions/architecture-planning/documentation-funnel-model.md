---
title: Documentation Funnel Model
date: 2026-01-18
category: architecture-planning
tags:
  - documentation
  - organization
  - claude-code
  - developer-experience
  - token-efficiency
severity: medium
component: .claude directory structure
symptoms:
  - Documentation scattered across 5+ directories
  - Claude sessions wasting tokens exploring 20+ files
  - Competing sources of truth
  - No clear "what's next" for new sessions
  - Mental overhead finding plans/priorities
root_cause: No clear ownership rules or decision tree for where documentation belongs
---

# Documentation Funnel Model

## Problem

Documentation was scattered across multiple locations causing:
- Mental overhead for developers finding plans/priorities
- Claude sessions wasting 1000+ tokens exploring 20+ files
- Competing sources of truth (docs/plans/, plans/, .claude/ralph/plans/)
- No clear "what's next" indicator for new sessions

## Solution: The Funnel Model

Implement a one-way content funnel with clear ownership at each stage:

```
inbox/ → plans/ → tasks.yaml → archive/
(ideas)  (refined)  (execute)   (done)
```

**Principle:** `tasks.yaml` is the single source of truth for "what's next"

## Implementation

### Directory Structure

```
.claude/
├── ONBOARDING.md          # Entry point for new sessions
├── inbox/                  # Raw ideas, quick captures
├── plans/                  # Refined plans ready for review
├── context/                # Always-on context (PRD, personas, journeys)
├── scope-creep/            # Future dreams - ignore for now
├── ralph/
│   ├── tasks.yaml          # THE execution queue
│   ├── ralph.sh            # Task executor
│   └── PROMPT.md           # Working prompts
├── decisions/              # ADRs
├── archive/                # Completed/obsolete
│   ├── plans/
│   ├── ralphie/
│   ├── todos/
│   └── sessions/
├── settings.json           # Claude settings
└── SKILLS.md               # Skill definitions

docs/                       # User-facing only
├── APNS_SETUP_GUIDE.md
├── SIMULATOR_SETUP_GUIDE.md
├── CONNECTION_TROUBLESHOOTING.md
└── solutions/              # Post-mortem documentation
```

### Key Files Created

1. **ONBOARDING.md** - Single entry point for new Claude sessions
   - Quick project context
   - Points to tasks.yaml for "what's next"
   - Explains the funnel model
   - Directory structure reference

2. **Session-start hook** - Displays doc paths on every session:
   ```
   Documentation: .claude/ONBOARDING.md | Current work: .claude/ralph/tasks.yaml
   ```

3. **Updated CLAUDE.md** - Added documentation structure table

### Files Consolidated

| From | To | Purpose |
|------|-----|---------|
| `plans/USER_PERSONAS.md` | `.claude/context/` | Always-on context |
| `plans/JOURNEY_MAPS.md` | `.claude/context/` | Always-on context |
| `plans/USER_FLOWS.md` | `.claude/context/` | Always-on context |
| `docs/PRD.md` | `.claude/context/` | Always-on context |
| `plans/CARPLAY_MVP_SPEC.md` | `.claude/scope-creep/` | Future dreams |
| `plans/IOS_COMPANION_APP.md` | `.claude/scope-creep/` | Future dreams |
| Completed plans | `.claude/archive/plans/` | Historical |
| Old todos | `.claude/archive/todos/` | Historical |

## Decision Tree: Where Does This File Go?

```
START: New documentation artifact

├─ Is this a bug/feature we just solved?
│  └─ YES → docs/solutions/{category}/{slug}.md
│
├─ Is this completed work?
│  └─ YES → .claude/archive/plans/
│
├─ Is this vague or brainstorm?
│  └─ YES → .claude/inbox/
│
├─ Is this out-of-scope (CarPlay, iOS app)?
│  └─ YES → .claude/scope-creep/
│
├─ Is this a reference doc (style guide, API)?
│  └─ YES → .claude/references/
│
├─ Is this a decision/principle?
│  └─ YES → .claude/decisions/
│
├─ Is this a complete, actionable plan?
│  └─ YES → .claude/plans/
│
└─ Is this a task or execution detail?
   └─ YES → Add to .claude/ralph/tasks.yaml
```

## Prevention Strategies

### Rules to Prevent Sprawl

1. **One file per feature** - Never multiple plans for same thing
2. **Inbox stays empty** - Triage within 1 week
3. **tasks.yaml is truth** - Never create separate task files
4. **Archive completed work** - Don't leave old plans in active directories
5. **Scope-creep quarantine** - Future dreams stay isolated

### Maintenance Schedule

- **Weekly**: Empty inbox (< 2 files)
- **Monthly**: Archive plans > 3 months old
- **Quarterly**: Full audit, remove orphans

### Red Flags

| Signal | Threshold | Action |
|--------|-----------|--------|
| Multiple files for same feature | 2+ exist | Consolidate |
| Inbox never empty | > 3 files | Triage backlog |
| Total doc count | > 150 files | Cleanup needed |
| Plans > 5KB | Any found | Split into phases |

## Results

### Before
- 7+ directories with documentation
- Sessions wasted tokens re-discovering context
- No clear "what's next" indicator

### After
- Single entry point: `.claude/ONBOARDING.md`
- Single execution source: `.claude/ralph/tasks.yaml`
- Clear funnel with defined ownership
- Session hook displays paths automatically

### Token Efficiency
- ONBOARDING.md prevents redundant exploration (87 lines vs 20+ docs)
- scope-creep isolation saves ~100k tokens per session
- Context consolidation reduces search from 5+ locations to 1

## Related

- `.claude/ONBOARDING.md` - Entry point for new sessions
- `.claude/ralph/tasks.yaml` - Execution queue
- `CLAUDE.md` - Project coding standards
- `CONTRIBUTING.md` - Developer onboarding
