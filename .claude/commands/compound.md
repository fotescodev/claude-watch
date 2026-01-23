---
description: Capture learnings at session end to compound knowledge
allowed-tools: Read, Edit, Write, Glob, Bash(python3:*)
---

# /compound - Compound Knowledge

**Purpose**: Capture learnings at session end to improve documentation for future sessions. Knowledge should compound - each session makes the next one better.

## Instructions

At the end of your session, run through this checklist to capture valuable learnings.

### Step 1: Identify Learnings

Ask yourself these questions:

1. **Architecture Discovery**: Did you find an undocumented data flow or constraint?
   - Something that caused a "but wait..." moment
   - A constraint you discovered mid-solution
   - A component interaction that wasn't clear

2. **Bug Pattern**: Did you fix a bug that could recur?
   - Root cause wasn't obvious
   - Fix required understanding system internals
   - Other agents might hit the same issue

3. **Process Improvement**: Did you find a better workflow?
   - A reading order that helped
   - A debugging technique that worked
   - A validation step that caught errors

### Step 2: Add to Appropriate Doc

Based on what you learned, add to the right location:

| Learning Type | Where to Add |
|---------------|--------------|
| Architecture constraint | `.claude/ARCHITECTURE.md` → `## Learnings Log` |
| Bug fix pattern | `docs/solutions/` → New file following INDEX.md format |
| Process improvement | `.claude/AGENT_GUIDE.md` → Relevant task type section |

### Step 3: Format Entry

For Learnings Log entries in ARCHITECTURE.md:

```markdown
### YYYY-MM-DD: Brief title (max 60 chars)
- Key insight line 1 (max 100 chars)
- Key insight line 2 (max 100 chars)
- Key insight line 3 (max 100 chars, optional)
```

**Rules:**
- Use today's date
- Title describes the learning, not the task
- 1-3 bullet points only
- Each bullet under 100 characters
- Focus on what future agents need to know

### Step 4: Validate Entry

Run the validator to ensure correct format:

```bash
python3 .claude/hooks/validators/learning_validator.py .claude/ARCHITECTURE.md
```

If it fails, fix the format and try again.

## Example Entries

**Good entry:**
```markdown
### 2026-01-23: Encryption keys exchange during pairing
- Keys must be exchanged in /pair/initiate, not after connection
- Watch stores cliPublicKey from /pair/status response
- CLI stores watchPublicKey from /pair/complete response
```

**Bad entry (too vague):**
```markdown
### 2026-01-23: Fixed bug
- Fixed the encryption bug
- It works now
```

**Bad entry (too long):**
```markdown
### 2026-01-23: I discovered that when implementing encryption for the watch...
- After spending considerable time debugging, I found that the root cause of the issue was related to how we were handling the key exchange process during the pairing flow, specifically...
```

## When to Use

- **Session end**: Always before closing your session
- **Major milestone**: After completing a significant feature
- **After debugging**: When you figured out something non-obvious
- **After "but wait..." moment**: When you discovered a constraint mid-work

## Auto-Validation

After updating ARCHITECTURE.md, the learning_validator.py will automatically check:
- Date format is YYYY-MM-DD
- Title is under 60 characters
- 1-3 bullet points
- Each bullet under 100 characters

If validation fails, you'll see specific errors to fix.

## Philosophy

> "Knowledge compounds when captured. Each session should leave the codebase
> slightly more documented for the next agent."

Don't document everything - document what surprised you, what wasn't obvious,
what you wished you'd known at session start.
