# Documentation Restructuring Plan

> **Context**: After the SDK-URL bridge migration (Phase 11), the project has accumulated ~67+ markdown files with stale references (42 files still say `cc-watch`, 23 reference `ralph/tasks.yaml`, `AGENT_GUIDE.md` referenced but never created). This plan cleans up all documentation into 3 tiers and fixes all broken/stale references.

## Goal

Organize all docs into 3 tiers:
1. **User-facing** (`docs/`) — end users, contributors
2. **Developer/Manager** (root + `.claude/` top-level) — you, the project owner
3. **Agent/Team** (`.claude/` subdirectories) — Claude Code agents

## Execution: 4 Parallel Agents

### Agent 1: "Archiver" — Bulk file moves + cleanup
**~15 min, no dependencies**

Move stale files to `.claude/archive/docs-cleanup-2026-02/`:

| File | Reason |
|------|--------|
| `.claude/design/DESIGN_REVIEW_V3.md` | V3 review complete |
| `.claude/design/FIXES_APPLIED.md` | V3 fixes complete |
| `.claude/tasks/V3_PARALLEL_TASKS.md` | V3 tasks complete |
| `.claude/tasks/v3-colors/` | V3 sub-tasks done |
| `.claude/tasks/v3-glow/` | V3 sub-tasks done |
| `.claude/tasks/v3-states/` | V3 sub-tasks done |
| `.claude/tasks/TEMPLATE.json` | No longer used |
| `.claude/research/api-contract-audit.md` | Pre-bridge, stale |
| `.claude/research/api-contract-audit-comprehensive.md` | Pre-bridge, stale |
| `.claude/inbox/rebrand-research.md` | Rebrand done |
| `.claude/standardization-plan.md` | Completed (STANDARDIZATION_COMPLETE.md exists) |
| `.claude/plans/testflight-readiness-analysis.md` | Superseded by TESTFLIGHT_READINESS.md |
| `.claude/plans/session-activity-indicator.md` | Stale, hook-based |
| `.claude/plans/review-user-journey-design-CONTEXT.md` | Old journey review |
| `.claude/plans/user-journey-design-CONTEXT.md` | Old journey design |
| `.claude/plans/zazzy-fluttering-island.md` | Stale plan |
| `.claude/plans/pure-churning-moore.md` | Stale plan |
| `.claude/plans/phase10-V2-CONTEXT.md` | Old phase, duplicate in archive |
| `.claude/plans/archive/` (entire subdir) | Move all to main archive |
| `.claude/context/FIGMA_IMPLEMENTATION_GUIDE.md` | Stale Figma guide |
| `.claude/context/COMPONENT_LIBRARY.md` | Pre-bridge spec |
| `.claude/context/JOURNEY_MAPS.md` | Stale (Jan 17) |
| `.claude/context/USER_FLOWS.md` | Stale (Jan 17) |
| `.claude/context/USER_PERSONAS.md` | Stale (Jan 17) |
| `.claude/references/UPDATED-ASSESSMENT.md` | Old assessment |
| `.claude/ONBOARDING.md` | Replaced by AGENT_GUIDE.md |
| `.claude/discovered-bugs.json` | Old tracking artifact |
| `.claude/acceptance-criteria.json` | Old tracking artifact |

Also:
- Delete `.claude/archive/ralphie/ralphie-monitor/node_modules/` (55MB of npm deps in archive)
- Clean up empty directories after moves
- Keep `.claude/references/WWDC2025-WATCHOS26.md` in place (still useful reference)

---

### Agent 2: "Core Docs Updater" — CLAUDE.md + ARCHITECTURE.md + README.md
**~45 min, can start immediately**

#### CLAUDE.md — 10 specific fixes:
1. Replace `.claude/AGENT_GUIDE.md` reference with working path (Agent 4 creates it)
2. Replace `.claude/ralph/tasks.yaml` with `.claude/plans/MIGRATION_PROGRESS.md`
3. Remove `.claude/scope-creep/` from directory table
4. Update Project Structure to add `MCPServer/bridge/` and `remmy-cli/`
5. Replace `Apple Watch Series 9 (45mm)` with `Apple Watch Series 11 (46mm)` in build commands
6. Replace all `npx cc-watch` / `cc-watch` with `remmy-cli` in pairing flow and watch mode sections
7. Update Server Commands to show bridge startup (`python -m bridge.main`)
8. Update Key Files to include bridge modules
9. Update Documentation Structure table (remove ralph, add MIGRATION_PROGRESS.md)
10. Add `remmy-cli/` to project structure tree

#### ARCHITECTURE.md:
- Make bridge architecture the PRIMARY diagram (not "Phase 11 in-progress")
- Update all `cc-watch` -> `remmy-cli`
- Update `claude-watch-npm/` -> `remmy-cli/`

#### README.md:
- Update CLI references (`cc-watch` -> `remmy-cli`)
- Update architecture overview to show bridge

---

### Agent 3: "User Docs Fixer" — docs/ directory cleanup
**~20 min, can start immediately**

1. **Fix `docs/solutions/INDEX.md`** broken links:
   - Copy 3 files from `.claude/archive/phase10/` back to `docs/solutions/integration-issues/`:
     - `comp5-question-proxy-failure-analysis.md`
     - `question-flow-prevention-strategies.md`
     - `missing-cloud-endpoints-e2e-failure.md`
   - Remove duplicate entries if any
   - Update `cc-watch` references

2. **Update `cc-watch` -> `remmy-cli`** in:
   - `docs/GETTING_STARTED.md`
   - `docs/landing.md`
   - `docs/USER_JOURNEYS.md`
   - `docs/solutions/integration-issues/cc-watch-session-isolation.md`
   - `docs/solutions/integration-issues/multi-session-progress-conflicts.md`

3. **Update stale references** in:
   - `docs/CONNECTION_TROUBLESHOOTING.md` (references `ralph/tasks.yaml`)
   - Any docs referencing old architecture

---

### Agent 4: "Agent Guide Creator" — New AGENT_GUIDE.md + DATA_FLOW.md
**~30 min, can start immediately**

#### Create `.claude/AGENT_GUIDE.md`:
Reading order by task type for agents:

```
Watch UI Task → LAYOUT_STANDARDS.md → ARCHITECTURE.md → SWIFTUI_DESIGN_SYSTEM.md
Bridge Task   → ARCHITECTURE.md → sdk-url-agent-execution-spec.md → DATA_FLOW.md
CLI Task      → ARCHITECTURE.md → remmy-watch-cli-spec.md
Bug Fix       → docs/solutions/INDEX.md → ARCHITECTURE.md → DATA_FLOW.md
New Feature   → ARCHITECTURE.md → MIGRATION_PROGRESS.md → SESSION_STATE.md
Shipping      → TESTFLIGHT_READINESS.md → MIGRATION_PROGRESS.md
```

Include "Don't Waste Tokens" guidance from old ONBOARDING.md.

#### Update `.claude/DATA_FLOW.md`:
- Add bridge REST API endpoints
- Mark old hook-based flows as "Legacy"
- Update system diagram to show bridge architecture

---

## Verification (after all agents complete)

Run these checks:
```bash
# No remaining cc-watch references (outside archive/)
grep -r "cc-watch\|npx cc-watch" --include="*.md" . | grep -v archive/ | grep -v node_modules

# No remaining ralph/tasks.yaml references (outside archive/)
grep -r "ralph/tasks\.yaml\|APPSTORE-ROADMAP\|phase5-CONTEXT" --include="*.md" . | grep -v archive/

# AGENT_GUIDE.md exists
test -f .claude/AGENT_GUIDE.md && echo "OK" || echo "MISSING"

# All INDEX.md links resolve
# (manual spot-check of docs/solutions/INDEX.md links)
```

## What We DON'T Touch
- `.claude/commands/` — slash commands are current
- `.claude/skills/` — agent skills are current
- `.claude/agents/` — agent definitions are current
- `.claude/hooks/` — still functional, even if some become legacy later
- `.claude/context/PRD.md` — historical product requirements, still valid
- `.claude/plans/MIGRATION_PROGRESS.md` — single source of truth, current
- Source code directories (`ClaudeWatch/`, `MCPServer/`, `remmy-cli/`)
- `.claude/design/v3.pen` — design file, current

## Final Directory Structure

```
docs/                              # Tier 1: User-facing
  ├── GETTING_STARTED.md           # (updated)
  ├── APNS_SETUP_GUIDE.md
  ├── CONNECTION_TROUBLESHOOTING.md
  ├── SIMULATOR_SETUP_GUIDE.md
  ├── USER_JOURNEYS.md             # (updated)
  ├── landing.md                   # (updated)
  ├── privacy.md
  └── solutions/INDEX.md           # (fixed links)

CLAUDE.md                          # Tier 2: Developer (updated)
README.md                          # Tier 2: Developer (updated)
.claude/ARCHITECTURE.md            # Tier 2: Developer (updated)
.claude/TESTFLIGHT_READINESS.md    # Tier 2: Developer
.claude/state/SESSION_STATE.md     # Tier 2: Developer

.claude/AGENT_GUIDE.md             # Tier 3: Agent (NEW)
.claude/DATA_FLOW.md               # Tier 3: Agent (updated)
.claude/LAYOUT_STANDARDS.md        # Tier 3: Agent
.claude/plans/                     # Tier 3: Agent (cleaned, only current plans)
.claude/context/PRD.md             # Tier 3: Agent (only file remaining)
.claude/commands/                   # Tier 3: Agent (untouched)
.claude/skills/                     # Tier 3: Agent (untouched)
.claude/agents/                     # Tier 3: Agent (untouched)
.claude/archive/                    # Historical (expanded with cleanup batch)
```
