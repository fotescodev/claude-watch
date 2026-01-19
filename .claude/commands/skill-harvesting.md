---
name: skill-harvesting
description: Extract reusable skills from successful debugging/implementation sessions
---

# Skill Harvesting

Convert successful problem-solving patterns from conversation history into reusable skills.

## When to Harvest

After you've successfully:
- Debugged a non-trivial issue
- Implemented a complex feature
- Discovered a useful pattern
- Found undocumented API behavior

## Harvesting Process

### 1. Identify the Pattern

Ask yourself:
- Would this help in future similar situations?
- Is this specific enough to be actionable?
- Is this general enough to be reusable?

### 2. Extract the Skill

Create a skill file with:

```markdown
---
name: descriptive-name
description: One-line trigger description (shown in skill list)
---

# Skill Title

## When to Use
[Trigger conditions - when should Claude invoke this?]

## The Pattern
[Core insight/technique extracted from the session]

## Implementation
[Code examples, commands, or steps]

## Gotchas
[What didn't work, common mistakes]
```

### 3. Progressive Disclosure Structure

**Keep descriptions concise** - they're loaded into every context:
```yaml
# BAD - too verbose for description
description: "Use this skill when implementing Foundation Models with @Generable macro for structured output generation including availability checks and error handling"

# GOOD - concise trigger
description: "Foundation Models @Generable patterns"
```

**Full content loads only when skill is invoked** - put details in the body, not the description.

## Example Harvest

**Session**: Debugged watchOS toolbar not appearing

**Extracted Skill**:
```markdown
---
name: watchos-toolbar-fix
description: Fix invisible toolbar items on watchOS
---

# watchOS Toolbar Visibility Fix

## When to Use
Toolbar items not appearing on watchOS, settings button invisible.

## The Pattern
watchOS toolbar items require NavigationStack context at app root.

## Implementation
```swift
// ClaudeWatchApp.swift
WindowGroup {
    NavigationStack {  // REQUIRED for toolbar
        MainView()
    }
}
```

## Gotchas
- NavigationView is deprecated, use NavigationStack
- Toolbar must be inside NavigationStack, not outside
```

## Anti-Patterns

### Token Pollution
```markdown
# BAD - loads entire Apple docs into every context
description: "Complete guide to Foundation Models including SystemLanguageModel.default, @Generable macro, @Guide annotations, LanguageModelSession, tool calling, streaming, context limits of 4096 tokens..."

# GOOD - minimal description, full content in body
description: "Foundation Models on-device LLM patterns"
```

### Over-Harvesting
Not every fix deserves a skill:
- ❌ Simple typo fixes
- ❌ One-off configuration
- ❌ Project-specific constants
- ✅ Patterns that apply to multiple situations
- ✅ Non-obvious solutions
- ✅ Undocumented behaviors

## Skill Locations

| Type | Location |
|------|----------|
| Project skills | `.claude/commands/*.md` |
| User skills | `~/.claude/commands/*.md` |
| Plugin skills | Via MCP servers |

## After Harvesting

1. Test the skill by invoking it
2. Verify it loads only when relevant
3. Check description appears in skill list
4. Confirm full content loads on invocation
