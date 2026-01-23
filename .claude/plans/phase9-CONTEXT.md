# Phase 9: Yes/No Question Constraints

> **Created**: 2026-01-22
> **Status**: Ready to implement
> **Replaces**: Phase 10 (complex stdout interception) with simpler prompt-based approach

---

## Problem Statement

Claude's `AskUserQuestion` outputs to stdout with no hook. Multiple choice questions like "Which approach? 1/2/3" cannot be intercepted or answered from the watch.

**Two days blocked** on Phase 10's approach: stdout parsing, stdin injection, escape sequences.

## The Insight

**Don't intercept questions. Prevent them from being asked.**

If Claude only asks yes/no questions, the watch's existing approve/reject UI works perfectly.

---

## Goals

1. Constrain Claude to yes/no questions when watch session is active
2. Achieve ~95% binary question coverage
3. Zero new infrastructure required
4. Leverage existing approve/reject watch UI

## Non-Goals

- 100% coverage (5% terminal fallback is acceptable)
- Complex stdout interception
- stdin injection
- New cloud endpoints

---

## Implementation Plan

### Step 1: CLAUDE.md Instructions (10 min)

Add watch-compatible question section to project CLAUDE.md:

```markdown
## Watch Approval Mode

When `CLAUDE_WATCH_SESSION_ACTIVE=1` (set by cc-watch):

**CRITICAL: Only ask yes/no questions.**

1. When you need user input, recommend ONE approach and ask "Proceed? (y/n)"
2. NEVER present numbered option lists (watch cannot select from them)
3. If user says "no", offer the next best alternative
4. For open-ended inputs (naming), use a sensible default: "I'll name it `UserService`. OK? (y/n)"

### Question Transformations

| Instead of... | Ask... |
|---------------|--------|
| "Which approach? 1. A  2. B  3. C" | "I recommend A because [reason]. Proceed? (y/n)" |
| "Where should I save this? 1. New file  2. Existing" | "I'll create `foo.ts`. OK? (y/n)" |
| "What should I name the function?" | "I'll call it `processData`. OK? (y/n)" |

### Why This Matters

The Apple Watch can only approve or reject. It cannot:
- Select from numbered options
- Type text input
- See multi-line question context

By asking yes/no questions, you enable seamless watch-based code review.
```

### Step 2: Test Basic Flow (15 min)

1. Enable watch session: `export CLAUDE_WATCH_SESSION_ACTIVE=1`
2. Start Claude with a task requiring decisions
3. Verify questions come as yes/no
4. Test approve/reject on watch

### Step 3: cc-watch run Enhancement (Optional, 30 min)

If CLAUDE.md alone isn't reliable enough, enhance `cc-watch run` to inject context:

```typescript
// In claude-watch-npm/src/cli/run.ts
const watchContext = `
[WATCH SESSION ACTIVE]
You are being controlled from an Apple Watch. The watch can only approve or reject.
ONLY ask yes/no questions. Never use numbered options.
`;

// Prepend to user's prompt
const enhancedPrompt = watchContext + userPrompt;
```

### Step 4: Fallback Handling (Optional, 15 min)

For the ~5% of questions that can't be binary:

```typescript
// Detect non-binary question in stdout
if (hasNumberedOptions(output)) {
  console.log('[Watch] Complex question detected - please respond in terminal');
  // Don't send to watch, let terminal handle it
}
```

---

## Success Criteria

| Metric | Target |
|--------|--------|
| Yes/No question rate | ≥95% |
| Watch approval success | 100% of yes/no questions |
| Implementation time | <1 hour |
| New code lines | <50 |

---

## Verification Checklist

- [x] CLAUDE.md instructions added (lines 161-193)
- [x] Phase 10 code cleanup (removed ClaudeQuestion, QuestionView, fetchPendingQuestions)
- [x] EncryptionService.swift added to Xcode project
- [x] Build succeeds (simulator)
- [ ] Test: Simple task with watch hooks enabled
- [ ] Test: Task requiring approach selection → yes/no question
- [ ] Test: Task requiring naming → default + yes/no question
- [ ] Test: Approve from watch works
- [ ] Test: Reject from watch offers alternative

---

## Comparison to Phase 10

| Aspect | Phase 10 (Complex) | Phase 9 (Simple) |
|--------|-------------------|------------------|
| Approach | Intercept stdout, parse, inject stdin | Prevent multi-choice via prompts |
| Cloud changes | New endpoints needed | None |
| Watch changes | New QuestionView UI | None |
| CLI changes | Escape sequence injection | Optional prompt injection |
| Reliability | Fragile (parsing/timing) | Robust (prompt following) |
| Coverage | 100% (theoretical) | 95% (practical) |
| Time to implement | Days | Hour |

**Phase 9 is the 80/20 solution.** Get 95% of the value with 5% of the effort.

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Claude ignores instructions | Low | Medium | Add to cc-watch prompt injection |
| Complex decisions need options | Medium | Low | Accept terminal fallback |
| User expects full options | Low | Low | Document limitation |

---

## Dependencies

- None (uses existing infrastructure)

## Files to Modify

1. `CLAUDE.md` - Add watch approval mode section
2. (Optional) `claude-watch-npm/src/cli/run.ts` - Prompt injection

## Files to Create

- None required

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Use CLAUDE.md over hooks | Simpler, no code, Claude follows project instructions |
| Accept 95% coverage | Perfection is enemy of done; 2 days already lost |
| Make cc-watch enhancement optional | CLAUDE.md may be sufficient alone |
| Skip Phase 10 complexity | ROI not justified for remaining 5% |

---

## Next Steps

1. Add instructions to CLAUDE.md
2. Quick test with watch session
3. Ship it
