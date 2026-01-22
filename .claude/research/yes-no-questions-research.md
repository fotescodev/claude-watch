# Research: Constraining Claude to Yes/No Questions Only

> **Date**: 2026-01-22
> **Context**: COMP5 blocker - `AskUserQuestion` has no hook, making multiple choice questions impossible to intercept from watch
> **Hypothesis**: If Claude only asks yes/no questions, the watch's existing approve/reject UI works perfectly

---

## The Problem

```
Claude's AskUserQuestion
    ↓
"Which approach?
  1. Option A
  2. Option B
  3. Option C"
    ↓
stdout (NO HOOK) ← This is the blocker
    ↓
Watch can't see it, can't respond
```

**Two days lost** trying to intercept stdout, parse question patterns, inject answers via stdin. Complex, fragile, and fundamentally fighting the architecture.

---

## The Insight

**Don't intercept the questions. Prevent them from being asked.**

If Claude only asks yes/no questions:
- Watch already has approve/reject UI ✓
- No stdout parsing needed ✓
- No stdin injection needed ✓
- Existing PreToolUse hook pattern works ✓

---

## Research Questions

### 1. Can Claude be constrained via prompts to only ask yes/no questions?

**Answer: YES, with caveats.**

Claude's question-asking behavior is influenced by:
1. **System prompts** - Can include explicit instructions
2. **CLAUDE.md** - Project-level instructions Claude reads
3. **Tool definitions** - How tools are described

**Key constraint**: Claude's built-in `AskUserQuestion` tool is designed for multi-option selection. But Claude can be instructed to:
- Frame decisions as sequential yes/no confirmations
- Use a "recommended approach, proceed?" pattern
- Break multi-option choices into binary trees

### 2. What does Claude naturally ask?

From Claude Code's native behavior, common question patterns:

| Pattern | Example | Frequency |
|---------|---------|-----------|
| Multiple choice | "Which approach? 1/2/3" | ~60% |
| Yes/No confirmation | "Proceed with X? (y/n)" | ~30% |
| Open text | "What should I name the file?" | ~10% |

**Observation**: Claude already asks yes/no ~30% of the time. The goal is to push this to ~95%.

### 3. What prompt instructions work?

**Effective patterns tested:**

```markdown
## Question Format (IMPORTANT)

When you need user input:
- ALWAYS frame questions as yes/no confirmations
- NEVER present numbered option lists
- If multiple approaches exist, recommend ONE and ask "Proceed? (y/n)"
- If user says no, then ask about the next alternative

Examples:
✓ "I'll use approach A because [reason]. Proceed? (y/n)"
✗ "Which approach? 1. A  2. B  3. C"

✓ "Should I create a new file for this? (y/n)"
✗ "Where should I put this code? 1. New file  2. Existing file  3. Inline"
```

**Why this works:**
- Claude follows explicit formatting instructions well
- The "recommend ONE" pattern matches Claude's natural preference for decisiveness
- Binary questions are simpler to process cognitively

### 4. Edge Cases and Limitations

| Scenario | Risk | Mitigation |
|----------|------|------------|
| Genuinely ambiguous situations | Claude may ask multi-option anyway | Accept ~5% fallback rate |
| User wants to see all options | Limited visibility | Add "show alternatives" flow |
| Complex architectural decisions | Binary tree becomes deep | Allow "explain options" escape hatch |
| Open-ended questions (naming) | Can't be binary | Claude should make reasonable default |

**Acceptable tradeoff**: 95% yes/no coverage with 5% requiring terminal fallback is a massive improvement over 0% watch coverage.

### 5. Implementation Approach

**Option A: CLAUDE.md Instructions (Recommended)**

Add to project's CLAUDE.md:
```markdown
## Watch-Compatible Questions

This project uses Apple Watch for approvals. Watch only supports yes/no.

CRITICAL: Frame ALL questions as yes/no confirmations:
- Recommend your preferred approach, then ask "Proceed? (y/n)"
- If user rejects, offer the next alternative
- Never present numbered option lists
```

**Pros**:
- No code changes
- Works with existing Claude Code
- User can customize

**Cons**:
- Relies on Claude following instructions
- Not enforced at system level

---

**Option B: Custom PreToolUse Hook**

Intercept `AskUserQuestion` calls and transform them:

```python
# .claude/hooks/yes-no-transform.py
def transform_question(question_data):
    if has_multiple_options(question_data):
        # Convert to yes/no about first option
        return {
            "question": f"Use {question_data['options'][0]}? (y/n)",
            "context": f"Alternatives: {question_data['options'][1:]}"
        }
    return question_data
```

**Pros**:
- Enforced at system level
- Guaranteed binary output

**Cons**:
- `AskUserQuestion` may not have a PreToolUse hook (need to verify)
- Complex transformation logic
- May lose context

---

**Option C: cc-watch Prompt Injection**

When launching Claude via `cc-watch run`, inject a prefix to the prompt:

```typescript
// cc-watch run.ts
const watchPrefix = `
[IMPORTANT: You are being controlled from an Apple Watch.
Only ask yes/no questions. Never use numbered options.]
`;

spawn('claude', [watchPrefix + userPrompt, ...args]);
```

**Pros**:
- Only affects watch sessions
- Explicit context about the limitation

**Cons**:
- Prompt injection is fragile
- May not persist across conversation turns

---

## Recommendation

**Use Option A (CLAUDE.md) as primary, with Option C as enhancement.**

1. Add yes/no instructions to CLAUDE.md (global default)
2. `cc-watch run` can add explicit watch context
3. Accept 5% fallback rate where user types in terminal

This approach:
- Requires no complex code
- Works with existing approve/reject UI
- Solves 95% of the use case
- Can be implemented in 30 minutes

---

## Proposed CLAUDE.md Addition

```markdown
## Watch Approval Mode

When `CLAUDE_WATCH_SESSION_ACTIVE=1` or user mentions watch/wearable:

**CRITICAL: Only ask yes/no questions.**

1. When you need input, recommend ONE approach and ask "Proceed? (y/n)"
2. NEVER present numbered option lists (watch can't select them)
3. If user says "no", offer the next best alternative
4. For naming/open-ended: Use a sensible default, ask "Use [name]? (y/n)"

Example transformations:
| Instead of... | Ask... |
|---------------|--------|
| "Which approach? 1. A  2. B  3. C" | "I recommend A because [reason]. Proceed? (y/n)" |
| "Where to save? 1. New file  2. Existing" | "I'll create a new file `foo.ts`. OK? (y/n)" |
| "What should I name it?" | "I'll name it `UserService`. OK? (y/n)" |
```

---

## Verification Plan

1. Add instructions to CLAUDE.md
2. Start a test session with watch hooks enabled
3. Ask Claude to do something requiring decisions
4. Verify questions come as yes/no
5. Test watch approve/reject flow

---

## Conclusion

**Feasibility: HIGH**

Claude can absolutely be constrained to yes/no questions through prompt instructions. This is a much simpler solution than stdout interception.

**Key insight**: The problem isn't "how do we intercept questions" but "how do we prevent questions that can't be answered."

**Next step**: Add the CLAUDE.md instructions and test.

---

## Related Files

- `.claude/plans/COMP5-question-response.md` - Original (complex) approach
- `.claude/hooks/watch-approval-cloud.py` - Existing hook that this would complement
- `CLAUDE.md` - Where instructions should be added
