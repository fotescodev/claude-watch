# Code Review Agent Standards

This module is loaded for complex tasks (5+ files changed)

---

## Optional Reviewer Agents

For complex tasks (5+ files changed), consider running reviewers.

### Step 1: Check for compound-engineering plugin

```bash
# Check if compound-engineering is available
if ls ~/.claude/plugins/cache/*/compound-engineering/ 2>/dev/null | head -1; then
  echo "compound-engineering: AVAILABLE"
else
  echo "compound-engineering: NOT INSTALLED (using project-local agents only)"
fi
```

### Step 2: Run project-local reviewers (always available)

```
# Swift code review
Task swift-reviewer: "Review changes for Swift best practices"

# SwiftUI patterns
Task swiftui-specialist: "Review SwiftUI implementation"

# Architecture review
Task watchos-architect: "Review watchOS architecture decisions"
```

### Step 3: Run compound-engineering reviewers (if available)

If the plugin check passed, also run these for deeper analysis:

```
# Code simplicity (YAGNI, over-engineering)
Task code-simplicity-reviewer: "Check for unnecessary complexity"

# Performance analysis
Task performance-oracle: "Analyze performance implications"

# Pattern recognition
Task pattern-recognition-specialist: "Check for anti-patterns and code smells"
```

**Skip reviewers for simple tasks** (1-2 files, straightforward changes).
