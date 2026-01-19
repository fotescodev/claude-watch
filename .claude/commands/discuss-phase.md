---
description: Capture implementation decisions before starting a phase (GSD-inspired)
allowed-tools: Read, Write, Glob, AskUserQuestion
---

# /discuss-phase [N] - Pre-Implementation Decision Capture

**Purpose**: Before implementing a phase, capture all decisions upfront. This prevents mid-implementation pivots and ensures Claude has full context.

## Arguments

- `[N]` - Phase number (e.g., `5` for TestFlight phase)

## Instructions

### 1. Load Phase Context

```
Read: .claude/plans/APPSTORE-ROADMAP.md
Find: Phase [N] details and deliverables
```

### 2. Identify Decision Points

Based on the phase type, identify gray areas that need decisions:

**For Build/Config phases**:
- Build configuration choices
- Environment-specific settings
- Credential/signing approach

**For UI/UX phases**:
- Layout and visual decisions
- Interaction patterns
- Edge case handling

**For Testing phases**:
- Test scope and coverage targets
- Device/simulator matrix
- Pass/fail criteria

**For Submission phases**:
- App Store metadata choices
- Screenshot scenarios
- Beta tester selection

### 3. Ask Questions

Use `AskUserQuestion` to get decisions on each gray area. Example questions:

```
Phase 5 (TestFlight) decisions needed:

1. Entitlements Strategy
   - [ ] Single entitlements file with build-time substitution
   - [ ] Separate Debug/Release entitlements files

2. Beta Tester Scope
   - [ ] Internal only (team members)
   - [ ] Closed beta (invited users)
   - [ ] Open beta (public link)

3. Privacy Policy
   - [ ] Host on project GitHub Pages
   - [ ] Use existing company privacy policy
   - [ ] Create dedicated landing page
```

### 4. Create CONTEXT File

After collecting decisions, create:

```
.claude/plans/phase{N}-CONTEXT.md
```

With format:

```markdown
# Phase [N] Context: [Phase Name]

> Decisions captured: [date]
> Participants: [user]

## Key Decisions

### [Decision Area 1]
**Choice**: [Selected option]
**Rationale**: [Why this choice]
**Implementation**: [How to implement]

### [Decision Area 2]
...

## Implementation Notes

- [Important detail 1]
- [Important detail 2]

## Out of Scope

- [What we're NOT doing this phase]

## Verification Criteria

- [ ] [How we know phase is complete]
- [ ] [Success metric]
```

### 5. Update SESSION_STATE.md

Add decisions to the session state for persistence.

## When to Use

- **Before starting a new phase**: Always discuss first
- **When requirements are unclear**: Capture decisions before coding
- **After scope change**: Re-discuss affected areas

## Example Usage

```
User: /discuss-phase 5

Claude: Let me gather the Phase 5 (TestFlight) details and identify decisions we need to make...

[Reads roadmap, identifies decision points, asks questions]

Based on your answers, I've created .claude/plans/phase5-CONTEXT.md with:
- Entitlements: Separate files for Debug/Release
- Beta scope: Closed beta with 50 invited users
- Privacy policy: GitHub Pages hosting

Ready to proceed with implementation?
```
