# Ralph Self-Improving System Specification

> **Goal**: Each Ralph run should inform future runs, accumulating learnings into skills automatically.

## Current State (No Learning Loop)

```
Task → Execute → Complete → (learnings lost)
Task → Execute → Complete → (learnings lost)
Task → Execute → Complete → (learnings lost)
```

## Target State (Self-Improving)

```
Task → Execute → Capture Learnings → Store
Task → Execute → Capture Learnings → Store
                                      ↓
                            Aggregate Learnings
                                      ↓
                            Pattern Detection
                                      ↓
                         Create/Update Skills
                                      ↓
Task → Load Relevant Skills → Execute (better) → Capture → ...
```

---

## Architecture

### 1. Learning Capture (Per Task)

After each task completion, capture:

```yaml
# .claude/ralph/learnings/learning-{task_id}-{timestamp}.yaml
task_id: "UX13"
timestamp: "2026-01-17T09:00:00Z"
outcome: success | failure | partial
tokens_used: 45000
duration_seconds: 180

# What worked
successes:
  - pattern: "Used .glassEffect() instead of custom materials"
    category: "ios26"
    reusable: true
  - pattern: "Checked SystemLanguageModel.default.availability first"
    category: "foundation-models"
    reusable: true

# What didn't work
failures:
  - pattern: "Tried .background(.ultraThinMaterial) - deprecated"
    category: "ios26"
    lesson: "Use .glassEffect() for iOS 26+"

# Discoveries
discoveries:
  - description: "Liquid Glass requires GlassEffectContainer for morphing"
    source: "Apple hidden docs"
    category: "ios26"

# Context that was needed but missing
missing_context:
  - "Foundation Models 4K token limit"
  - "Liquid Glass button styles"

# Skills that would have helped
wished_for_skills:
  - "ios26-liquid-glass"
  - "foundation-models-availability"
```

### 2. Learning Storage

```
.claude/ralph/learnings/
├── learning-UX13-20260117-090000.yaml
├── learning-UX14-20260117-093000.yaml
├── learning-FM1-20260117-100000.yaml
└── aggregated/
    ├── ios26-patterns.yaml      # Aggregated by category
    ├── foundation-models.yaml
    └── accessibility.yaml
```

### 3. Aggregation Engine

Runs periodically (e.g., every 5 tasks or on `--aggregate`):

```bash
aggregate_learnings() {
    # Group learnings by category
    for category in $(get_learning_categories); do
        # Count occurrences of each pattern
        patterns=$(get_patterns_by_category "$category")

        for pattern in $patterns; do
            count=$(count_pattern_occurrences "$pattern")

            # If pattern appears 3+ times, it's skill-worthy
            if [[ $count -ge 3 ]]; then
                queue_for_skill_creation "$pattern" "$category"
            fi
        done
    done
}
```

### 4. Skill Generation

When patterns reach threshold:

```bash
generate_skill_from_learnings() {
    local category="$1"
    local patterns="$2"

    # Use Claude to synthesize skill from patterns
    cat <<EOF | claude --print
You are a skill generator. Given these patterns that have been learned
across multiple Ralph tasks, create a reusable skill file.

Category: $category
Patterns:
$patterns

Create a skill following this structure:
---
name: $category-patterns
description: One-line description (concise for progressive disclosure)
---

# Title

## When to Use
[Trigger conditions]

## Patterns
[Extracted patterns with code examples]

## Anti-Patterns
[What didn't work]
EOF
}
```

### 5. Skill Loading (Context-Aware)

Before each task, Ralph should:

```bash
load_relevant_skills() {
    local task_id="$1"

    # Get task tags from tasks.yaml
    local tags=$(yq ".tasks[] | select(.id == \"$task_id\") | .tags[]" "$TASKS_FILE")

    # Find skills matching tags
    local relevant_skills=""
    for tag in $tags; do
        skills=$(find_skills_by_tag "$tag")
        relevant_skills+="$skills"
    done

    # Also check learned categories
    local task_files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]" "$TASKS_FILE")
    for file in $task_files; do
        if [[ "$file" == *"Views"* ]]; then
            relevant_skills+=$(find_skills_by_tag "swiftui")
        fi
        if [[ "$file" == *"Service"* ]]; then
            relevant_skills+=$(find_skills_by_tag "async")
        fi
    done

    # Concatenate skill content (progressive disclosure - only load what's needed)
    for skill in $relevant_skills; do
        cat "$skill" >> "$TEMP_PROMPT"
    done
}
```

---

## Implementation in ralph.sh

### New Functions

```bash
# ═══════════════════════════════════════════════════════════════
# SELF-IMPROVEMENT SYSTEM
# ═══════════════════════════════════════════════════════════════

LEARNINGS_DIR="$RALPH_DIR/learnings"
SKILLS_DIR="$PROJECT_ROOT/.claude/commands"

# Capture learnings after task completion
capture_learnings() {
    local task_id="$1"
    local outcome="$2"  # success | failure
    local session_log="$3"

    local learning_file="$LEARNINGS_DIR/learning-${task_id}-$(date +%Y%m%d-%H%M%S).yaml"

    # Extract learnings using Claude
    cat <<EOF | claude --print > "$learning_file"
Analyze this session log and extract learnings in YAML format.

Task ID: $task_id
Outcome: $outcome

Session Log:
$(cat "$session_log")

Output YAML with these fields:
- task_id, timestamp, outcome
- successes: [{pattern, category, reusable}]
- failures: [{pattern, category, lesson}]
- discoveries: [{description, source, category}]
- missing_context: [list of context that would have helped]
- wished_for_skills: [skill names that would have helped]
EOF

    log "Captured learnings to $learning_file"
}

# Check if aggregation needed
should_aggregate() {
    local learning_count=$(ls "$LEARNINGS_DIR"/learning-*.yaml 2>/dev/null | wc -l)
    local last_aggregation=$(cat "$LEARNINGS_DIR/.last_aggregation" 2>/dev/null || echo 0)
    local tasks_since=$((learning_count - last_aggregation))

    [[ $tasks_since -ge 5 ]]  # Aggregate every 5 tasks
}

# Aggregate learnings by category
aggregate_learnings() {
    log "Aggregating learnings..."

    mkdir -p "$LEARNINGS_DIR/aggregated"

    # Get all categories
    local categories=$(grep -h "category:" "$LEARNINGS_DIR"/learning-*.yaml | \
                      sort | uniq | sed 's/.*category: //')

    for category in $categories; do
        local agg_file="$LEARNINGS_DIR/aggregated/${category}.yaml"

        # Combine all learnings for this category
        yq eval-all ". | select(.successes[].category == \"$category\" or
                                .failures[].category == \"$category\" or
                                .discoveries[].category == \"$category\")" \
            "$LEARNINGS_DIR"/learning-*.yaml > "$agg_file"

        # Count pattern occurrences
        check_skill_threshold "$category" "$agg_file"
    done

    echo "$(ls "$LEARNINGS_DIR"/learning-*.yaml | wc -l)" > "$LEARNINGS_DIR/.last_aggregation"
}

# Check if category should become a skill
check_skill_threshold() {
    local category="$1"
    local agg_file="$2"

    local pattern_count=$(yq '.successes | length' "$agg_file")

    if [[ $pattern_count -ge 3 ]]; then
        local skill_file="$SKILLS_DIR/${category}-learned.md"

        if [[ ! -f "$skill_file" ]]; then
            log "Pattern threshold reached for $category, generating skill..."
            generate_skill "$category" "$agg_file" > "$skill_file"
            log_success "Created skill: $skill_file"
        else
            log "Updating existing skill: $skill_file"
            update_skill "$category" "$agg_file" "$skill_file"
        fi
    fi
}

# Generate skill from aggregated learnings
generate_skill() {
    local category="$1"
    local agg_file="$2"

    cat <<EOF | claude --print
Create a skill file from these aggregated learnings.

Category: $category
Learnings:
$(cat "$agg_file")

Output a complete skill markdown file with:
---
name: ${category}-learned
description: [one concise line - this shows in skill list]
---

# ${category} Patterns (Auto-Generated)

## When to Use
[Trigger conditions based on task tags/files]

## Learned Patterns
[Extract successful patterns with code examples]

## Anti-Patterns
[What didn't work and why]

## Source
Auto-generated from Ralph learnings on $(date +%Y-%m-%d)
EOF
}

# Load relevant skills for task
load_relevant_skills() {
    local task_id="$1"
    local temp_prompt="$2"

    # Get task metadata
    local tags=$(yq ".tasks[] | select(.id == \"$task_id\") | .tags[]" "$TASKS_FILE" 2>/dev/null)
    local files=$(yq ".tasks[] | select(.id == \"$task_id\") | .files[]" "$TASKS_FILE" 2>/dev/null)

    local loaded_skills=()

    # Match skills by tag
    for tag in $tags; do
        for skill in "$SKILLS_DIR"/*.md; do
            if grep -q "tags:.*$tag\|$tag" "$skill" 2>/dev/null; then
                if [[ ! " ${loaded_skills[*]} " =~ " ${skill} " ]]; then
                    log_verbose "Loading skill: $(basename "$skill")"
                    echo "" >> "$temp_prompt"
                    echo "# Skill: $(basename "$skill" .md)" >> "$temp_prompt"
                    cat "$skill" >> "$temp_prompt"
                    loaded_skills+=("$skill")
                fi
            fi
        done
    done

    # Match skills by file patterns
    for file in $files; do
        if [[ "$file" == *"Views"* ]]; then
            load_skill_if_exists "swiftui" "$temp_prompt" loaded_skills
            load_skill_if_exists "liquid-glass" "$temp_prompt" loaded_skills
        fi
        if [[ "$file" == *"Service"* ]]; then
            load_skill_if_exists "async" "$temp_prompt" loaded_skills
            load_skill_if_exists "foundation-models" "$temp_prompt" loaded_skills
        fi
    done

    log "Loaded ${#loaded_skills[@]} relevant skills"
}
```

### Modified Run Loop

```bash
run_loop() {
    # ... existing setup ...

    while true; do
        # ... existing task selection ...

        # NEW: Load relevant skills for this task
        local temp_prompt=$(mktemp)
        cat "$PROMPT_FILE" > "$temp_prompt"
        load_relevant_skills "$next_task_id" "$temp_prompt"

        # Run Claude with enriched prompt
        if run_claude_session "$temp_prompt" "$session_id"; then
            # ... existing validation ...

            # NEW: Capture learnings on success
            capture_learnings "$next_task_id" "success" "$progress_log"

            # NEW: Check if aggregation needed
            if should_aggregate; then
                aggregate_learnings
            fi
        else
            # NEW: Capture learnings on failure too
            capture_learnings "$next_task_id" "failure" "$progress_log"
        fi

        rm -f "$temp_prompt"

        # ... rest of loop ...
    done
}
```

---

## New Command-Line Options

```bash
./ralph.sh --aggregate          # Force learning aggregation
./ralph.sh --show-learnings     # Display accumulated learnings
./ralph.sh --generate-skills    # Force skill generation from learnings
./ralph.sh --no-skills          # Run without loading skills (debugging)
./ralph.sh --skill-stats        # Show skill usage statistics
```

---

## Feedback Loop Visualization

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        RALPH SELF-IMPROVEMENT LOOP                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│   ┌──────────┐     ┌──────────────┐     ┌──────────────┐                │
│   │  Task    │────▶│   Execute    │────▶│   Capture    │                │
│   │  Start   │     │   (Claude)   │     │  Learnings   │                │
│   └──────────┘     └──────────────┘     └──────┬───────┘                │
│        ▲                                        │                        │
│        │                                        ▼                        │
│        │           ┌──────────────┐     ┌──────────────┐                │
│        │           │    Load      │     │    Store     │                │
│        │           │   Skills     │     │  Learnings   │                │
│        │           └──────┬───────┘     └──────┬───────┘                │
│        │                  │                     │                        │
│        │                  │                     ▼                        │
│   ┌────┴─────┐     ┌──────┴───────┐     ┌──────────────┐                │
│   │   Next   │◀────│   Match      │     │  Aggregate   │                │
│   │   Task   │     │   by Tags    │     │  (every 5)   │                │
│   └──────────┘     └──────────────┘     └──────┬───────┘                │
│                           ▲                     │                        │
│                           │                     ▼                        │
│                    ┌──────┴───────┐     ┌──────────────┐                │
│                    │   Skills     │◀────│   Generate   │                │
│                    │   Library    │     │   Skills     │                │
│                    └──────────────┘     └──────────────┘                │
│                                         (threshold: 3+)                  │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Metrics Extension

```json
{
  "selfImprovement": {
    "learningsCaptured": 47,
    "learningsAggregated": 42,
    "skillsGenerated": 5,
    "skillsUpdated": 12,
    "avgTokensSaved": 2500,
    "patternCategories": {
      "ios26": 15,
      "accessibility": 8,
      "swiftui": 12,
      "async": 7
    }
  }
}
```

---

## Example: Learning → Skill Evolution

### Run 1: Task UX13 (Liquid Glass)
```yaml
discoveries:
  - description: "Use .glassEffect() not .background(.thinMaterial)"
    category: "ios26"
```

### Run 2: Task LG1 (More Liquid Glass)
```yaml
successes:
  - pattern: "GlassEffectContainer required for morphing"
    category: "ios26"
```

### Run 3: Task LG2 (Glass Transitions)
```yaml
successes:
  - pattern: "@Namespace + glassEffectID for smooth transitions"
    category: "ios26"
```

### Aggregation Triggered (3 patterns)
```bash
# Auto-generates: .claude/commands/ios26-learned.md
```

### Generated Skill
```markdown
---
name: ios26-learned
description: iOS 26 Liquid Glass patterns (auto-learned)
---

# iOS 26 Patterns (Auto-Generated)

## When to Use
Tasks with tags: ios26, liquid-glass, swiftui
Files in: ClaudeWatch/Views/

## Learned Patterns

### Glass Effects
```swift
// Use .glassEffect() not deprecated materials
Text("Status").glassEffect()

// GlassEffectContainer for multiple effects
GlassEffectContainer(spacing: 20) {
    // child views with .glassEffect()
}

// Morphing requires namespace
@Namespace private var ns
view.glassEffectID("id", in: ns)
```

## Anti-Patterns
- `.background(.thinMaterial)` - deprecated in iOS 26
- Missing GlassEffectContainer - breaks morphing

## Source
Auto-generated from Ralph learnings on 2026-01-17
```

---

## Implementation Priority

1. **Phase 1**: Learning capture (capture_learnings function)
2. **Phase 2**: Skill loading (load_relevant_skills function)
3. **Phase 3**: Aggregation engine (aggregate_learnings function)
4. **Phase 4**: Skill generation (generate_skill function)
5. **Phase 5**: Metrics and monitoring
