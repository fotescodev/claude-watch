# PRD: Ralph Resilience & Learning System

> **Status:** Draft
> **Date:** 2026-01-17
> **Scope:** Circuit breaker, response analyzer, self-learning
> **Priority:** High
> **Related:** prd-ralphie-monitor.md (TUI display)

---

## Executive Summary

Add resilience patterns and self-learning capabilities to ralph.sh. This covers the "backend" intelligence that prevents runaway loops and captures learnings for compound improvement.

### Research Foundation

Patterns adopted from production implementations:
- **Circuit Breaker** (frankbria/ralph) - Prevent runaway token consumption
- **Response Analyzer** (frankbria/ralph) - Semantic completion detection
- **progress.txt** (snarktank/ralph) - Append-only learnings
- **Session Continuity** (ralph-tui) - Context preservation

---

## Part 1: Circuit Breaker

### Purpose

Detect stagnation and halt execution before burning tokens on a stuck loop.

### States

```
CLOSED (normal) → HALF_OPEN (monitoring) → OPEN (halted)
                      ↑                        │
                      └────────────────────────┘
                           (manual reset)
```

### Thresholds

| Metric | Threshold | Action |
|--------|-----------|--------|
| No-progress loops | 3 consecutive | OPEN |
| Same-error loops | 5 consecutive | OPEN |
| Output decline | >70% decrease | OPEN |

### Implementation

**File:** `.claude/ralph/lib/circuit_breaker.sh`

```bash
#!/bin/bash
# Circuit Breaker for Ralph

CB_STATE_FILE="${RALPH_DIR}/circuit_breaker.state"
CB_HISTORY_FILE="${RALPH_DIR}/circuit_breaker.history"

# Thresholds
CB_NO_PROGRESS_THRESHOLD=3
CB_SAME_ERROR_THRESHOLD=5
CB_OUTPUT_DECLINE_PERCENT=70

# States
CB_CLOSED="CLOSED"
CB_HALF_OPEN="HALF_OPEN"
CB_OPEN="OPEN"

cb_init() {
    if [[ ! -f "$CB_STATE_FILE" ]]; then
        echo "$CB_CLOSED" > "$CB_STATE_FILE"
    fi
}

cb_get_state() {
    cat "$CB_STATE_FILE" 2>/dev/null || echo "$CB_CLOSED"
}

cb_set_state() {
    local new_state="$1"
    local reason="$2"

    echo "$new_state" > "$CB_STATE_FILE"
    echo "$(date -Iseconds) $new_state: $reason" >> "$CB_HISTORY_FILE"
}

cb_record_iteration() {
    local task_id="$1"
    local outcome="$2"  # success|failure|no_progress
    local output_chars="$3"
    local error_hash="$4"  # md5 of error message if failure

    echo "$task_id|$outcome|$output_chars|$error_hash" >> "$CB_HISTORY_FILE"
}

cb_check() {
    local state
    state=$(cb_get_state)

    if [[ "$state" == "$CB_OPEN" ]]; then
        echo "HALT: Circuit breaker is OPEN. Run 'ralph --cb-reset' to continue."
        return 1
    fi

    # Check no-progress streak
    local no_progress_count
    no_progress_count=$(tail -"$CB_NO_PROGRESS_THRESHOLD" "$CB_HISTORY_FILE" 2>/dev/null | grep -c "no_progress")
    if [[ "$no_progress_count" -ge "$CB_NO_PROGRESS_THRESHOLD" ]]; then
        cb_set_state "$CB_OPEN" "No progress in $CB_NO_PROGRESS_THRESHOLD consecutive loops"
        return 1
    fi

    # Check same-error streak
    local last_errors
    last_errors=$(tail -"$CB_SAME_ERROR_THRESHOLD" "$CB_HISTORY_FILE" 2>/dev/null | cut -d'|' -f4 | sort | uniq -c | sort -rn | head -1)
    local error_count
    error_count=$(echo "$last_errors" | awk '{print $1}')
    if [[ "$error_count" -ge "$CB_SAME_ERROR_THRESHOLD" ]]; then
        cb_set_state "$CB_OPEN" "Same error $CB_SAME_ERROR_THRESHOLD times"
        return 1
    fi

    return 0
}

cb_reset() {
    cb_set_state "$CB_CLOSED" "Manual reset"
    echo "Circuit breaker reset to CLOSED"
}
```

### Integration Points

Add to ralph.sh main loop:

```bash
source "${RALPH_DIR}/lib/circuit_breaker.sh"

cb_init

while true; do
    # Check circuit breaker before each iteration
    if ! cb_check; then
        log "Circuit breaker tripped - halting execution"
        exit 1
    fi

    # ... run iteration ...

    # Record outcome
    cb_record_iteration "$task_id" "$outcome" "${#output}" "$error_hash"
done
```

---

## Part 2: Response Analyzer

### Purpose

Semantically detect completion vs. stuck states without relying solely on exit codes.

### Detection Patterns

| Pattern Type | Examples | Action |
|--------------|----------|--------|
| Completion | "done", "complete", "all tasks finished" | Mark complete |
| Testing-only | "npm test", "bats", "pytest" | Continue (test run != done) |
| No-work | "nothing to do", "no changes needed" | Mark complete |
| Stuck | "error", "failed", repeated messages | Increment failure counter |

### EXIT_SIGNAL Gate

**Key insight from frankbria/ralph:** Require BOTH completion indicator AND explicit exit signal.

```bash
# WRONG: Exit on any completion indicator
if [[ "$status" == "COMPLETE" ]]; then exit; fi

# RIGHT: Dual condition
if [[ "$status" == "COMPLETE" && "$exit_signal" == "true" ]]; then exit; fi
```

The exit signal is a task file marker: `exit_signal: true` in tasks.yaml

### Implementation

**File:** `.claude/ralph/lib/response_analyzer.sh`

```bash
#!/bin/bash
# Response Analyzer for Ralph

# Completion indicators (case-insensitive)
COMPLETION_PATTERNS=(
    "done"
    "complete"
    "finished"
    "all tasks complete"
    "implementation complete"
)

# Testing-only patterns (doesn't mean done)
TEST_ONLY_PATTERNS=(
    "running tests"
    "npm test"
    "bun test"
    "pytest"
    "xcodebuild test"
)

# No-work patterns (acceptable completion)
NO_WORK_PATTERNS=(
    "nothing to do"
    "no changes needed"
    "already implemented"
    "no further action"
)

# Stuck/error patterns
STUCK_PATTERNS=(
    "error:"
    "failed:"
    "cannot find"
    "permission denied"
)

ra_analyze() {
    local output="$1"
    local output_lower
    output_lower=$(echo "$output" | tr '[:upper:]' '[:lower:]')

    # Check for test-only (not complete)
    for pattern in "${TEST_ONLY_PATTERNS[@]}"; do
        if [[ "$output_lower" == *"$pattern"* ]]; then
            echo "TESTING"
            return
        fi
    done

    # Check for no-work (complete)
    for pattern in "${NO_WORK_PATTERNS[@]}"; do
        if [[ "$output_lower" == *"$pattern"* ]]; then
            echo "COMPLETE_NO_WORK"
            return
        fi
    done

    # Check for completion
    for pattern in "${COMPLETION_PATTERNS[@]}"; do
        if [[ "$output_lower" == *"$pattern"* ]]; then
            echo "COMPLETE"
            return
        fi
    done

    # Check for stuck
    for pattern in "${STUCK_PATTERNS[@]}"; do
        if [[ "$output_lower" == *"$pattern"* ]]; then
            echo "STUCK"
            return
        fi
    done

    echo "IN_PROGRESS"
}

ra_should_exit() {
    local status="$1"
    local task_id="$2"

    # Check for explicit exit signal in tasks.yaml
    local exit_signal
    exit_signal=$(yq ".tasks[] | select(.id == \"$task_id\") | .exit_signal" "${RALPH_DIR}/tasks.yaml" 2>/dev/null)

    if [[ "$status" == "COMPLETE"* && "$exit_signal" == "true" ]]; then
        return 0  # Should exit
    fi

    return 1  # Should continue
}
```

### Integration Points

Add to ralph.sh task completion check:

```bash
source "${RALPH_DIR}/lib/response_analyzer.sh"

check_completion() {
    local output="$1"
    local task_id="$2"

    local status
    status=$(ra_analyze "$output")

    if ra_should_exit "$status" "$task_id"; then
        return 0  # Task complete
    fi

    return 1  # Continue
}
```

---

## Part 3: Self-Learning System

Reference: `SELF-IMPROVING-SPEC.md`

### Learning Capture

After each task, extract learnings:

```bash
capture_learnings() {
    local task_id="$1"
    local outcome="$2"  # success | failure
    local session_log="$3"

    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local output_file="${RALPH_DIR}/learnings/learning-${task_id}-${timestamp}.yaml"

    # Use Claude to extract structured learnings
    cat <<EOF | claude --print > "$output_file"
Analyze this task execution and extract learnings in YAML format.

Task ID: $task_id
Outcome: $outcome
Session excerpt:
$(tail -100 "$session_log")

Output YAML with this structure:
---
task_id: "$task_id"
outcome: "$outcome"
timestamp: "$(date -Iseconds)"
successes:
  - pattern: "description of what worked"
    category: "swiftui|watchos|api|testing|etc"
    reusable: true
failures:
  - pattern: "what went wrong"
    lesson: "what to do instead"
discoveries:
  - description: "new insight about the codebase"
    category: "architecture|pattern|gotcha"
EOF
}
```

### Learning Aggregation

Every N tasks, aggregate similar patterns:

```bash
aggregate_learnings() {
    local category="$1"
    local threshold="${2:-3}"  # Default: 3 patterns to trigger

    # Count patterns by category
    local count
    count=$(find "${RALPH_DIR}/learnings" -name "*.yaml" -exec grep -l "category: \"$category\"" {} \; | wc -l)

    if [[ "$count" -ge "$threshold" ]]; then
        generate_skill "$category"
    fi
}
```

### Skill Generation

Generate a Claude command from aggregated learnings:

```bash
generate_skill() {
    local category="$1"
    local skill_file="${CLAUDE_COMMANDS_DIR}/${category}-learned.md"

    # Collect all learnings for this category
    local learnings
    learnings=$(find "${RALPH_DIR}/learnings" -name "*.yaml" -exec grep -A5 "category: \"$category\"" {} \;)

    cat <<EOF | claude --print > "$skill_file"
Generate a Claude Code skill from these learnings. The skill should help future tasks.

Category: $category
Learnings:
$learnings

Output a SKILL.md file with:
1. Description of when to use this skill
2. Key patterns discovered
3. Common gotchas to avoid
4. Example code snippets where helpful
EOF

    echo "Generated skill: $skill_file"
}
```

### progress.txt Pattern (Quick Win)

Simple append-only file for immediate cross-iteration context:

```bash
append_progress() {
    local task_id="$1"
    local outcome="$2"
    local summary="$3"

    cat <<EOF >> "${RALPH_DIR}/progress.txt"
## Iteration $(date +%Y%m%d-%H%M%S)
Task: $task_id
Outcome: $outcome
Summary: $summary
---
EOF
}
```

This feeds into the next iteration's prompt:

```bash
build_prompt() {
    local task="$1"

    # Include recent progress
    local recent_progress
    recent_progress=$(tail -50 "${RALPH_DIR}/progress.txt" 2>/dev/null || echo "")

    cat <<EOF
## Task
$task

## Recent Progress (for context)
$recent_progress

## Instructions
Complete the task above.
EOF
}
```

---

## Part 4: Session Continuity

### Context Preservation

Inspired by ralph-tui's session persistence:

```bash
SESSION_FILE="${RALPH_DIR}/.ralph_session"
SESSION_EXPIRY_HOURS=24

session_init() {
    if [[ -f "$SESSION_FILE" ]]; then
        local session_time
        session_time=$(stat -f %m "$SESSION_FILE" 2>/dev/null || stat -c %Y "$SESSION_FILE")
        local current_time
        current_time=$(date +%s)
        local age_hours=$(( (current_time - session_time) / 3600 ))

        if [[ $age_hours -lt $SESSION_EXPIRY_HOURS ]]; then
            SESSION_ID=$(cat "$SESSION_FILE")
            log "Resuming session: $SESSION_ID"
            return 0
        fi
    fi

    SESSION_ID="session-$(date +%Y%m%d-%H%M%S)"
    echo "$SESSION_ID" > "$SESSION_FILE"
    log "New session: $SESSION_ID"
}

session_invoke() {
    local prompt="$1"

    if [[ -n "$SESSION_ID" ]]; then
        claude --continue "$SESSION_ID" "$prompt"
    else
        claude "$prompt"
    fi
}
```

---

## Implementation Phases

### Phase 0: Quick Wins (1 day)

1. [ ] Add progress.txt capture
2. [ ] Add CLAUDE.md auto-update for discovered patterns
3. [ ] Add `--monitor` flag for tmux split-pane

### Phase 1: Circuit Breaker (1 day)

1. [ ] Create lib/circuit_breaker.sh
2. [ ] Integrate into ralph.sh main loop
3. [ ] Add `--cb-reset` CLI flag
4. [ ] Add `--cb-status` CLI flag

### Phase 2: Response Analyzer (1 day)

1. [ ] Create lib/response_analyzer.sh
2. [ ] Add EXIT_SIGNAL support to tasks.yaml schema
3. [ ] Integrate into completion detection
4. [ ] Test with various output patterns

### Phase 3: Learning Capture (2 days)

1. [ ] Create learnings/ directory structure
2. [ ] Implement capture_learnings()
3. [ ] Add post-task learning hook to ralph.sh
4. [ ] Test learning YAML generation

### Phase 4: Skill Generation (2 days)

1. [ ] Implement aggregate_learnings()
2. [ ] Implement generate_skill()
3. [ ] Add `--aggregate` CLI flag
4. [ ] Test skill generation flow

---

## Files to Create

```
.claude/ralph/
├── lib/
│   ├── circuit_breaker.sh
│   └── response_analyzer.sh
├── learnings/
│   └── .gitkeep
├── progress.txt
├── circuit_breaker.state
└── circuit_breaker.history
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Runaway loops prevented | 100% |
| Learnings captured | 80%+ of tasks |
| Skills auto-generated | 3+ after 20 tasks |
| Token savings from skills | 10%+ reduction |

---

## Testing Plan

### Circuit Breaker Tests

```bash
# Test no-progress detection
./test_circuit_breaker.sh --scenario no_progress

# Test same-error detection
./test_circuit_breaker.sh --scenario same_error

# Test manual reset
./test_circuit_breaker.sh --scenario reset
```

### Response Analyzer Tests

```bash
# Test completion detection
./test_response_analyzer.sh --scenario complete

# Test testing-only detection
./test_response_analyzer.sh --scenario testing

# Test EXIT_SIGNAL gate
./test_response_analyzer.sh --scenario exit_signal
```

---

## References

- frankbria/ralph-claude-code: Circuit breaker and response analyzer
- snarktank/ralph: progress.txt pattern
- ralph-tui: Session persistence
- SELF-IMPROVING-SPEC.md: Learning system design

---

**END OF PRD**
