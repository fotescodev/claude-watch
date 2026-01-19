#!/bin/bash
# Session start hook - GSD-inspired orientation
# Provides instant context: where we left off, what's next

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
TASKS_FILE="$PROJECT_DIR/.claude/ralph/tasks.yaml"
PLANS_DIR="$PROJECT_DIR/.claude/plans"
STATE_FILE="$PROJECT_DIR/.claude/state/SESSION_STATE.md"

PROJECT_NAME="ClaudeWatch"
SWIFT_VERSION=$(swift --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "  watchOS: $PROJECT_NAME | Swift $SWIFT_VERSION" >&2
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
echo "" >&2

# ═══════════════════════════════════════════════════════════════════════════
# SESSION STATE (GSD-inspired handoff)
# ═══════════════════════════════════════════════════════════════════════════
if [ -f "$STATE_FILE" ]; then
    echo "━━━ Session Handoff ━━━" >&2
    # Extract current phase
    PHASE=$(grep "^\*\*Phase" "$STATE_FILE" 2>/dev/null | head -1 | sed 's/\*//g')
    if [ -n "$PHASE" ]; then
        echo "$PHASE" >&2
    fi
    # Extract next priorities (first 3)
    echo "Next priorities:" >&2
    grep "^\d\." "$STATE_FILE" 2>/dev/null | head -3 | while read -r line; do
        echo "  $line" >&2
    done
    # Check for handoff notes
    if grep -q "Handoff Notes" "$STATE_FILE" 2>/dev/null; then
        echo "Handoff notes available in SESSION_STATE.md" >&2
    fi
    echo "" >&2
fi

# ═══════════════════════════════════════════════════════════════════════════
# RALPH TASK STATUS
# ═══════════════════════════════════════════════════════════════════════════
echo "━━━ Ralph Task Status ━━━" >&2

if [ -f "$TASKS_FILE" ]; then
    # Count tasks
    TOTAL_TASKS=$(grep -c "^  - id:" "$TASKS_FILE" 2>/dev/null || echo "0")
    COMPLETED=$(grep -c "completed: true" "$TASKS_FILE" 2>/dev/null || echo "0")
    INCOMPLETE=$((TOTAL_TASKS - COMPLETED))

    echo "Tasks: $COMPLETED/$TOTAL_TASKS complete ($INCOMPLETE remaining)" >&2

    # Show incomplete task IDs and titles
    if [ "$INCOMPLETE" -gt 0 ]; then
        echo "Pending:" >&2
        # Find incomplete tasks - look for "completed: false" without comments
        awk '
            /^  - id:/ { id = $3; gsub(/"/, "", id) }
            /title:/ { title = $0; gsub(/.*title: "/, "", title); gsub(/".*/, "", title) }
            /completed: false$/ { print "  - " id ": " title }
        ' "$TASKS_FILE" 2>/dev/null | head -5 >&2
        if [ "$INCOMPLETE" -gt 5 ]; then
            echo "  ... and $((INCOMPLETE - 5)) more" >&2
        fi
    fi

    # Check for blocked tasks
    BLOCKED=$(grep -c "blocked: true" "$TASKS_FILE" 2>/dev/null || echo "0")
    if [ "$BLOCKED" -gt 0 ]; then
        echo "⚠️  $BLOCKED blocked task(s)" >&2
    fi

    # Check tasks.yaml freshness vs plans
    TASKS_MTIME=$(stat -f %m "$TASKS_FILE" 2>/dev/null || echo "0")
    NEWEST_PLAN_MTIME=0
    if [ -d "$PLANS_DIR" ]; then
        for plan in "$PLANS_DIR"/*.md; do
            if [ -f "$plan" ]; then
                PLAN_MTIME=$(stat -f %m "$plan" 2>/dev/null || echo "0")
                if [ "$PLAN_MTIME" -gt "$NEWEST_PLAN_MTIME" ]; then
                    NEWEST_PLAN_MTIME=$PLAN_MTIME
                fi
            fi
        done
    fi

    if [ "$NEWEST_PLAN_MTIME" -gt "$TASKS_MTIME" ]; then
        echo "⚠️  Plans updated more recently than tasks.yaml - may need sync" >&2
    fi
else
    echo "⚠️  tasks.yaml not found at $TASKS_FILE" >&2
fi

echo "" >&2
echo "Commands: /progress /discuss-phase /ship-check /build" >&2
echo "Context: .claude/state/SESSION_STATE.md | Tasks: .claude/ralph/tasks.yaml" >&2

# ═══════════════════════════════════════════════════════════════════════════
# ENVIRONMENT STATUS
# ═══════════════════════════════════════════════════════════════════════════
echo "" >&2

# Check for running simulators
BOOTED_SIMS=$(xcrun simctl list devices booted 2>/dev/null | grep -c "Booted")
if [ "$BOOTED_SIMS" -eq 0 ]; then
    echo "No simulators running. Use /run-app to boot one." >&2
else
    echo "$BOOTED_SIMS simulator(s) running" >&2
fi

# Check if MCP server is running
if lsof -i :8787 >/dev/null 2>&1; then
    echo "MCP server running on :8787" >&2
else
    echo "MCP server not running. Use /start-server to start it." >&2
fi
