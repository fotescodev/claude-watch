# Claude Watch: GSD Framework Migration Report

> **Generated:** 2026-01-19
> **Purpose:** Evaluate adopting [get-shit-done-cc](https://github.com/glittercowboy/get-shit-done-cc) for accelerating TestFlight and App Store deployment

---

## Executive Summary

| Aspect | Current State | GSD Migration | Recommendation |
|--------|---------------|---------------|----------------|
| **Project Maturity** | ~90% feature complete | Would require restructuring | **Partial adoption** |
| **Documentation** | Comprehensive but scattered | Structured but different format | Migrate key docs |
| **Task System** | `tasks.yaml` + custom Ralph | XML plans + fresh context | Keep Ralph, add GSD commands |
| **Next Milestone** | TestFlight Beta | 3-4 weeks of focused work | **Prioritize shipping** |

**Bottom Line:** Claude Watch is too mature for a full GSD migration. Instead, adopt GSD's **workflow commands** and **context discipline** while preserving your existing architecture.

---

## Part 1: Framework Comparison

### What GSD Provides

```
GSD Workflow:
┌─────────────────────────────────────────────────────────────────┐
│  /gsd:new-project → Questions → Research → Requirements → Plan │
│                              ↓                                  │
│  /gsd:discuss-phase → Capture decisions before implementation   │
│                              ↓                                  │
│  /gsd:plan-phase → 2-3 atomic tasks with XML verification       │
│                              ↓                                  │
│  /gsd:execute-phase → Parallel subagents, fresh 200k contexts   │
│                              ↓                                  │
│  /gsd:verify-work → UAT + automated verification                │
│                              ↓                                  │
│  /gsd:complete-milestone → Archive, tag, ship                   │
└─────────────────────────────────────────────────────────────────┘
```

**Key GSD Innovations:**
1. **Fresh context per task** - Each execution runs in clean 200k token window
2. **XML-structured plans** - Precise task definitions with verification criteria
3. **Parallel research agents** - 4 agents investigate before planning
4. **Atomic git commits** - One commit per task, instantly bisectable
5. **State persistence** - `STATE.md` survives across sessions

### What Claude Watch Already Has

```
Current System:
┌─────────────────────────────────────────────────────────────────┐
│  .claude/ralph/tasks.yaml   → Detailed task definitions        │
│  .claude/context/PRD.md     → Complete product spec            │
│  .claude/plans/*.md         → Feature specs and roadmap        │
│  .claude/agents/*.md        → Specialized subagent definitions │
│  .claude/commands/*.md      → Custom slash commands            │
│  .claude/hooks/*.py         → Integration hooks                │
│  docs/solutions/            → Documented fixes and decisions   │
└─────────────────────────────────────────────────────────────────┘
```

**Existing Strengths:**
1. **tasks.yaml** - Already has 30+ detailed task definitions with verification
2. **PRD.md** - Comprehensive product requirements (574 lines)
3. **APPSTORE-ROADMAP.md** - 8-10 week shipping plan
4. **Specialized agents** - Swift, SwiftUI, WebSocket, watchOS experts
5. **Solution documentation** - Known issues and fixes catalogued

---

## Part 2: Gap Analysis

### What's Missing from Current System

| GSD Feature | Current State | Gap |
|-------------|---------------|-----|
| Fresh context per task | All work in one context | **HIGH** - Context accumulates |
| XML-structured plans | YAML task definitions | LOW - Format difference only |
| Automatic verification | Manual verification | **MEDIUM** - Could automate |
| Phase-based roadmap | Week-based roadmap | LOW - Equivalent structure |
| STATE.md persistence | Implicit via tasks.yaml | **MEDIUM** - No explicit handoff |
| Discussion phase | Ad-hoc decisions | **MEDIUM** - Decisions scattered |

### What Current System Has That GSD Doesn't

| Feature | Value |
|---------|-------|
| watchOS-specific agents | Knows Apple platform patterns |
| Custom slash commands | `/build`, `/deploy-device`, `/fix-build` |
| Integration hooks | Watch approval, progress tracking |
| Solution docs | Past debugging knowledge |
| Physical device testing | Dog walk test verification |

---

## Part 3: Migration Recommendation

### DO: Adopt These GSD Practices

#### 1. Add `/gsd:progress` Equivalent

Create `.claude/commands/progress.md`:
```markdown
# /progress - Current State Summary

Read and synthesize:
1. .claude/ralph/tasks.yaml - What's done, what's pending
2. .claude/plans/APPSTORE-ROADMAP.md - Where we are in roadmap
3. Recent git log - What shipped recently

Output: Current phase, next 3 tasks, any blockers
```

#### 2. Add SESSION_STATE.md

Create `.claude/SESSION_STATE.md` for handoff persistence:
```markdown
# Session State (auto-updated)

## Current Phase
Phase 5: TestFlight Beta Distribution

## Active Work
- Task: FE2b (Stop/Play controls) - Deferred
- Task: DBG-CLOUD - Investigating

## Decisions Made This Session
- [ ] None yet

## Blockers
- None active

## Next Session Priority
1. Entitlements configuration (Release vs Debug)
2. Privacy manifest creation
3. Test build archive
```

#### 3. Use Fresh Subagents for Complex Tasks

When implementing a new feature, use Task tool with explicit context:
```
"Implement feature X. You have access to:
- PRD: .claude/context/PRD.md
- Roadmap: .claude/plans/APPSTORE-ROADMAP.md
- Task: [specific task from tasks.yaml]

Execute in fresh context. Commit atomically."
```

#### 4. Add Phase Discussion Step

Before starting a new phase, create `{phase}-CONTEXT.md`:
```markdown
# Phase 5 Context: TestFlight Distribution

## Key Decisions
- Entitlements: Separate files for Debug/Release
- Privacy: PrivacyInfo.xcprivacy with UserDefaults + Microphone
- Beta testers: Start with 10-person alpha

## Implementation Notes
- Use Xcode Organizer for archive upload
- Test notifications with production APNs before submission
```

### DON'T: Full GSD Migration

**Reasons:**

1. **Project is 90% complete** - GSD is designed for greenfield projects
2. **Existing structure is comprehensive** - Would lose context during migration
3. **Custom tooling is valuable** - Ralph loop, agents, hooks work well
4. **Time cost** - Migration would delay shipping by 2+ weeks

---

## Part 4: Accelerated Path to App Store

### Current Blockers (Prioritized)

```
┌─────────────────────────────────────────────────────────────────┐
│  CRITICAL (Must fix for TestFlight)                             │
│  ├─ [ ] Entitlements: aps-environment=production for Release    │
│  ├─ [ ] Privacy manifest: PrivacyInfo.xcprivacy                 │
│  └─ [ ] Archive builds without error                            │
│                                                                  │
│  HIGH (Should fix for quality)                                  │
│  ├─ [ ] Accessibility labels on all buttons                     │
│  ├─ [ ] Unit test coverage > 75%                                │
│  └─ [ ] Cloud connectivity issues (DBG-CLOUD, DBG-TIMEOUT)      │
│                                                                  │
│  MEDIUM (Nice to have)                                          │
│  ├─ [ ] Stop/Play interrupt controls (FE2b)                     │
│  └─ [ ] VoiceOver testing                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Recommended 4-Week Sprint

**Week 1: Build Configuration**
```yaml
tasks:
  - Create ClaudeWatch-Release.entitlements with aps-environment: production
  - Verify Xcode project uses correct entitlements per build config
  - Create PrivacyInfo.xcprivacy with declared API usages
  - Test archive build locally
  - Validate archive with Xcode Organizer
```

**Week 2: Quality & Testing**
```yaml
tasks:
  - Add accessibility labels to all interactive elements
  - Run VoiceOver through all screens
  - Write unit tests for WatchService critical paths
  - Fix DBG-CLOUD connectivity issues
  - Test on 3 physical watch sizes
```

**Week 3: Alpha TestFlight**
```yaml
tasks:
  - Upload build to App Store Connect
  - Recruit 10 alpha testers
  - Create privacy policy URL
  - Write App Store description
  - Take 5 screenshots (396x484px)
```

**Week 4: Beta & Submission**
```yaml
tasks:
  - Fix critical bugs from alpha feedback
  - Expand to 50 closed beta testers
  - Complete App Store Connect metadata
  - Submit for review
  - Prepare launch announcement
```

---

## Part 5: Hybrid Workflow Proposal

### New Command Structure

Add these GSD-inspired commands to `.claude/commands/`:

| Command | Purpose |
|---------|---------|
| `/progress` | Show current phase, next tasks, blockers |
| `/discuss-phase <N>` | Capture decisions before implementation |
| `/verify-phase <N>` | Run all verification for completed phase |
| `/ship-check` | Pre-submission validation checklist |

### Updated File Structure

```
.claude/
├── ralph/
│   └── tasks.yaml              # Keep as-is (source of truth)
├── context/
│   ├── PRD.md                  # Keep as-is
│   └── USER_PERSONAS.md        # Keep as-is
├── plans/
│   ├── APPSTORE-ROADMAP.md     # Keep as-is
│   ├── phase5-CONTEXT.md       # NEW: Pre-implementation decisions
│   └── phase5-VERIFICATION.md  # NEW: UAT results
├── state/
│   └── SESSION_STATE.md        # NEW: Handoff persistence
└── commands/
    ├── progress.md             # NEW: GSD-style progress
    ├── discuss-phase.md        # NEW: Capture decisions
    └── ship-check.md           # NEW: Pre-submission check
```

---

## Part 6: Decision Matrix

### Should You Install GSD?

| Scenario | Install GSD? | Reasoning |
|----------|--------------|-----------|
| New greenfield project | **YES** | Full benefit of structured workflow |
| Existing mature project | **NO** | Adopt practices, not full system |
| Want fresh context discipline | **PARTIAL** | Use Task tool with explicit context |
| Want atomic commits | **NO** | Already doing this with Ralph |
| Want verification automation | **PARTIAL** | Add verify commands |

### For Claude Watch Specifically

**Recommendation: Don't install GSD. Adopt these practices instead:**

1. Create `SESSION_STATE.md` for handoff
2. Add `/progress` command
3. Use explicit context in Task tool calls
4. Create `{phase}-CONTEXT.md` before new work
5. Keep tasks.yaml + Ralph workflow

---

## Part 7: Immediate Next Steps

### Today

1. **Create SESSION_STATE.md** with current blockers
2. **Create phase5-CONTEXT.md** with TestFlight decisions
3. **Review entitlements configuration** in Xcode

### This Week

1. **Fix entitlements** (Debug vs Release)
2. **Create PrivacyInfo.xcprivacy**
3. **Test archive build**
4. **Push first TestFlight build**

### This Month

1. **Complete alpha testing** (10 users)
2. **Fix critical bugs**
3. **Expand to closed beta** (50 users)
4. **Submit to App Store**

---

## Appendix A: GSD Command Reference

For future reference, these are the GSD commands you'd use if starting fresh:

```bash
# Full workflow
/gsd:new-project          # Initialize (questions, research, requirements)
/gsd:discuss-phase 1      # Capture implementation decisions
/gsd:plan-phase 1         # Create atomic task plans
/gsd:execute-phase 1      # Run plans with fresh contexts
/gsd:verify-work 1        # Manual UAT
/gsd:complete-milestone   # Archive and tag

# Navigation
/gsd:progress             # Current status
/gsd:resume-work          # Continue from last session

# Phase management
/gsd:add-phase            # Append to roadmap
/gsd:insert-phase 2       # Insert urgent work
```

---

## Appendix B: Resources

- [GSD GitHub Repository](https://github.com/glittercowboy/get-shit-done)
- [NPM Package](https://www.npmjs.com/package/get-shit-done-cc)
- Current Project: `.claude/ralph/tasks.yaml`
- Roadmap: `.claude/plans/APPSTORE-ROADMAP.md`

---

*Report generated to inform strategic decision about development workflow optimization.*
