# Ralph Task Converter

Convert a plan file from `plans/` directory into Ralph-format tasks for `tasks.yaml`.

## Usage

```bash
/ralph-it plans/feat-ux-improvement-watchos.md
```

## Process

### Step 1: Read the Plan

Read the plan file specified in the arguments. Extract:
- All tasks from "Implementation Phases" sections
- Acceptance criteria
- File paths mentioned
- Dependencies between tasks

### Step 2: Convert to Ralph Format

For each task in the plan, create a Ralph task entry with:

```yaml
- id: "[PHASE][NUMBER]"  # e.g., "UX1", "UX2"
  title: "[Task title from checkbox]"
  description: |
    [Full description of what needs to be done]
    Include any code examples from the plan.
  priority: [critical|high|medium|low]  # Based on phase priority
  parallel_group: [number]  # Tasks that can run together get same number
  completed: false
  verification: |
    # Bash command to verify task is done
    grep -q '[pattern]' [file] && exit 0 || exit 1
  acceptance_criteria:
    - "[Criteria 1]"
    - "[Criteria 2]"
  files:
    - "[file1.swift]"
    - "[file2.swift]"
  tags:
    - [relevant tags]
  commit_template: "[type](scope): [description]"
```

### Step 3: Priority Mapping

| Plan Phase | Ralph Priority | Parallel Group |
|------------|---------------|----------------|
| Phase 1 (Critical) | critical | 10 |
| Phase 2 (High) | high | 11 |
| Phase 3 (Medium) | medium | 12 |
| Phase 4 (Enhancement) | medium | 13 |
| Phase 5 (Testing) | low | 14 |

### Step 4: Generate Verification Commands

Create verification commands that check for:
- File existence: `[ -f "path/file.swift" ]`
- Content patterns: `grep -q 'pattern' file`
- Line count changes: `[ $(wc -l < file) -lt 250 ]`
- Build success: `xcodebuild ... build 2>&1 | grep -q "BUILD SUCCEEDED"`

### Step 5: Output

1. Read current `.claude/ralph/tasks.yaml`
2. Append new tasks under a new phase header comment
3. Write updated file back

### Step 6: Summary

Display:
```
=== RALPH TASKS GENERATED ===
Phase: [phase name]
Tasks Added: [count]
Next parallel_group: [number]
=============================
```

## Example Output

```yaml
# ═══════════════════════════════════════════════════════════════════════════
# PHASE 7: UX IMPROVEMENTS
# From: plans/feat-ux-improvement-watchos.md
# ═══════════════════════════════════════════════════════════════════════════
- id: "UX1"
  title: "Create centralized design system"
  description: |
    Create DesignSystem/Claude.swift with all color, material, and spacing tokens.
    Extract Claude enum from MainView.swift and create single source of truth.
  priority: critical
  parallel_group: 10
  completed: false
  verification: |
    [ -f "ClaudeWatch/DesignSystem/Claude.swift" ] && \
    grep -q 'public enum Claude' ClaudeWatch/DesignSystem/Claude.swift && exit 0 || exit 1
  acceptance_criteria:
    - "Claude.swift contains all color definitions"
    - "No color definitions outside DesignSystem/"
    - "All views import from centralized design system"
  files:
    - "ClaudeWatch/DesignSystem/Claude.swift"
    - "ClaudeWatch/Views/MainView.swift"
    - "ClaudeWatch/Views/ConsentView.swift"
  tags:
    - design-system
    - refactor
    - ux
  commit_template: "refactor(design): Create centralized Claude design system"
```

## Notes

- Use unique IDs with "UX" prefix to distinguish from existing tasks
- Set `parallel_group` higher than existing tasks (7+)
- Include realistic verification commands
- Reference actual file paths from the plan
