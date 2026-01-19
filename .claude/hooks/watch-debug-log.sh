#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  WATCH DEBUG LOG — Smart Event Injector with Auto-Bug Detection
#  Usage: ./watch-debug-log.sh LEVEL "Message" "details=value"
#
#  Automatically creates Ralph tasks when patterns indicate bugs:
#  - Repeated errors (3+ of same type)
#  - Cloud connectivity failures
#  - Pairing mismatches
#  - Request timeouts
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOG_DIR="$PROJECT_ROOT/.claude/logs/watch-debug"
LATEST_LOG="$LOG_DIR/latest.log"
ALL_EVENTS_LOG="$LOG_DIR/all-events.log"
ERROR_TRACKER="$LOG_DIR/.error-tracker"
TASKS_FILE="$PROJECT_ROOT/.claude/ralph/tasks.yaml"

# Ensure directories exist
mkdir -p "$LOG_DIR"

#───────────────────────────────────────────────────────────────────────────────
# BUG DETECTION PATTERNS
#───────────────────────────────────────────────────────────────────────────────

# Track errors for pattern detection
track_error() {
    local error_type="$1"
    local timestamp=$(date +%s)

    # Append error to tracker
    echo "$timestamp|$error_type" >> "$ERROR_TRACKER"

    # Keep only last 50 errors
    if [[ -f "$ERROR_TRACKER" ]]; then
        tail -50 "$ERROR_TRACKER" > "$ERROR_TRACKER.tmp" && mv "$ERROR_TRACKER.tmp" "$ERROR_TRACKER"
    fi
}

count_recent_errors() {
    local error_type="$1"
    local window_seconds="${2:-300}"  # Default 5 minute window
    local now=$(date +%s)
    local cutoff=$((now - window_seconds))

    if [[ ! -f "$ERROR_TRACKER" ]]; then
        echo "0"
        return
    fi

    grep "|$error_type$" "$ERROR_TRACKER" 2>/dev/null | while IFS='|' read -r ts err; do
        [[ $ts -ge $cutoff ]] && echo "1"
    done | wc -l | tr -d ' '
}

#───────────────────────────────────────────────────────────────────────────────
# RALPH TASK CREATION
#───────────────────────────────────────────────────────────────────────────────

# Check if a bug task already exists for this issue
bug_exists() {
    local bug_id="$1"
    grep -q "id: \"$bug_id\"" "$TASKS_FILE" 2>/dev/null
}

# Generate next bug ID
next_bug_id() {
    local prefix="${1:-DBG}"
    local max_num=0

    # Find highest existing bug number with this prefix
    if [[ -f "$TASKS_FILE" ]]; then
        while IFS= read -r line; do
            if [[ "$line" =~ id:\ *\"${prefix}([0-9]+)\" ]]; then
                local num="${BASH_REMATCH[1]}"
                [[ $num -gt $max_num ]] && max_num=$num
            fi
        done < "$TASKS_FILE"
    fi

    echo "${prefix}$((max_num + 1))"
}

# Create a Ralph bug task
create_bug_task() {
    local bug_id="$1"
    local title="$2"
    local description="$3"
    local tags="${4:-bug,auto-detected,watch-debug}"

    # Check if task already exists
    if bug_exists "$bug_id"; then
        return 0
    fi

    # Get current timestamp
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Append task to tasks.yaml
    cat >> "$TASKS_FILE" << EOF
  - id: "$bug_id"
    title: "$title"
    description: |
      AUTO-DETECTED BUG from Watch Debug Monitor
      Detected at: $timestamp

      $description

      Debug logs: .claude/logs/watch-debug/
    priority: high
    parallel_group: 1
    completed: false
    verification: |
      echo "Verify bug is fixed"
    acceptance_criteria:
      - "Issue no longer occurs"
      - "Debug monitor shows healthy status"
    files: []
    tags:
$(echo "$tags" | tr ',' '\n' | sed 's/^/      - /')
    commit_template: "fix(watch): $title"
EOF

    # Log that we created a task
    log_event "INFO" "🎫 Created Ralph task: $bug_id" "title=$title"
}

#───────────────────────────────────────────────────────────────────────────────
# SMART PATTERN DETECTION
#───────────────────────────────────────────────────────────────────────────────

detect_and_report_issues() {
    local level="$1"
    local message="$2"
    local details="$3"

    # Pattern 1: Cloud connectivity failures
    if [[ "$level" == "ERROR" ]] && [[ "$message" =~ [Cc]loud.*unreachable|server.*unavailable ]]; then
        track_error "cloud_connectivity"
        local count=$(count_recent_errors "cloud_connectivity" 300)

        if [[ $count -ge 3 ]] && ! bug_exists "DBG-CLOUD"; then
            create_bug_task "DBG-CLOUD" \
                "Cloud server connectivity issues detected" \
                "The watch debug monitor detected $count cloud connectivity failures in the last 5 minutes.

Symptoms:
- Cloud server returning non-200 status
- Requests timing out
- Hook failing to create approval requests

Possible causes:
- Cloudflare Worker down
- Network issues
- Rate limiting

To investigate:
\`\`\`bash
curl -v https://claude-watch.fotescodev.workers.dev/health
\`\`\`" \
                "bug,auto-detected,cloud,connectivity"
        fi
    fi

    # Pattern 2: Pairing mismatch
    if [[ "$message" =~ [Pp]airing.*mismatch|ID.*mismatch ]]; then
        if ! bug_exists "DBG-PAIR"; then
            create_bug_task "DBG-PAIR" \
                "Pairing ID mismatch between config files" \
                "The watch debug monitor detected a pairing ID mismatch.

~/.claude-watch-pairing differs from ~/.claude-watch/config.json

This causes:
- Requests sent to wrong pairing ID
- Watch not receiving notifications
- Approvals not reaching Claude Code

Quick fix:
\`\`\`bash
jq -r .pairingId ~/.claude-watch/config.json > ~/.claude-watch-pairing
\`\`\`" \
                "bug,auto-detected,pairing,config"
        fi
    fi

    # Pattern 3: Request timeouts
    if [[ "$level" == "TIMEOUT" ]] || [[ "$message" =~ [Tt]imeout ]]; then
        track_error "request_timeout"
        local count=$(count_recent_errors "request_timeout" 600)

        if [[ $count -ge 2 ]] && ! bug_exists "DBG-TIMEOUT"; then
            create_bug_task "DBG-TIMEOUT" \
                "Multiple request timeouts detected" \
                "The watch debug monitor detected $count request timeouts in the last 10 minutes.

Symptoms:
- Approval requests not being responded to
- Claude Code hanging waiting for approval
- Watch may not be receiving notifications

Possible causes:
- Watch app not running
- Watch not receiving push notifications
- Network issues on watch
- Watch has stale pairing ID

To investigate:
1. Check watch app is running
2. Verify pairing IDs match
3. Send test notification:
   \`\`\`bash
   .claude/hooks/watch-debug-monitor.sh --test
   \`\`\`" \
                "bug,auto-detected,timeout,notifications"
        fi
    fi

    # Pattern 4: Hook failures
    if [[ "$level" == "ERROR" ]] && [[ "$message" =~ [Hh]ook.*error|[Hh]ook.*fail ]]; then
        track_error "hook_failure"
        local count=$(count_recent_errors "hook_failure" 300)

        if [[ $count -ge 3 ]] && ! bug_exists "DBG-HOOK"; then
            create_bug_task "DBG-HOOK" \
                "PreToolUse hook failures detected" \
                "The watch debug monitor detected $count hook failures in the last 5 minutes.

Symptoms:
- Approvals not being requested
- Claude Code proceeding without watch approval
- Error messages in hook output

Possible causes:
- Hook script error
- Missing dependencies (python3, jq)
- Invalid configuration

To investigate:
\`\`\`bash
# Test hook manually
echo '{\"tool_name\": \"Edit\", \"tool_input\": {\"file_path\": \"/test\"}}' | python3 .claude/hooks/watch-approval-cloud.py

# Check hook is registered
jq '.hooks.PreToolUse' .claude/settings.json
\`\`\`" \
                "bug,auto-detected,hooks,configuration"
        fi
    fi

    # Pattern 5: Repeated rejections (might indicate UX issue)
    if [[ "$level" == "REJECT" ]]; then
        track_error "rejection"
        local count=$(count_recent_errors "rejection" 600)

        if [[ $count -ge 5 ]] && ! bug_exists "DBG-UX-REJECT"; then
            create_bug_task "DBG-UX-REJECT" \
                "High rejection rate detected - possible UX issue" \
                "The watch debug monitor detected $count rejections in the last 10 minutes.

This might indicate:
- Accidental rejections (buttons too close)
- Unclear request descriptions
- User confusion about what's being approved

Consider:
- Improving request titles/descriptions
- Adding confirmation for rejections
- Reviewing the approval UX" \
                "enhancement,auto-detected,ux,rejections"
        fi
    fi

    # Pattern 6: APNs failures
    if [[ "$message" =~ [Aa][Pp][Nn]s.*fail|push.*fail|notification.*fail ]]; then
        track_error "apns_failure"
        local count=$(count_recent_errors "apns_failure" 300)

        if [[ $count -ge 2 ]] && ! bug_exists "DBG-APNS"; then
            create_bug_task "DBG-APNS" \
                "Push notification delivery failures" \
                "The watch debug monitor detected APNs delivery failures.

Symptoms:
- Requests created but watch doesn't show them
- No notification sound/haptic on watch
- Watch shows empty when cloud has pending requests

Possible causes:
- APNs certificate issues
- Device token expired
- Watch not registered for notifications

To investigate:
\`\`\`bash
# Check cloud response includes apnsSent: true
curl -X POST https://claude-watch.fotescodev.workers.dev/request \\
  -H 'Content-Type: application/json' \\
  -d '{\"pairingId\": \"\$(cat ~/.claude-watch-pairing)\", \"type\": \"test\", \"title\": \"APNs test\"}'
\`\`\`" \
                "bug,auto-detected,apns,notifications"
        fi
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# LOGGING
#───────────────────────────────────────────────────────────────────────────────

log_event() {
    local level="${1:-INFO}"
    local message="${2:-No message}"
    local details="${3:-}"
    local full_timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    # Emoji based on level
    local emoji
    case "$level" in
        OK|SUCCESS)   emoji="✅" ;;
        WARN)         emoji="⚠️" ;;
        ERROR|FAIL)   emoji="❌" ;;
        INFO)         emoji="ℹ️" ;;
        CLOUD)        emoji="☁️" ;;
        WATCH)        emoji="⌚" ;;
        APNS)         emoji="📲" ;;
        HOOK)         emoji="🪝" ;;
        REQUEST)      emoji="📨" ;;
        RESPONSE)     emoji="📬" ;;
        APPROVE)      emoji="👍" ;;
        REJECT)       emoji="👎" ;;
        TIMEOUT)      emoji="⏰" ;;
        POLL)         emoji="🔄" ;;
        BLOCK)        emoji="🛑" ;;
        UNBLOCK)      emoji="🟢" ;;
        *)            emoji="•" ;;
    esac

    # Build log line
    local log_line
    if [[ -n "$details" ]]; then
        log_line="[$full_timestamp] [$level] $emoji $message — $details"
    else
        log_line="[$full_timestamp] [$level] $emoji $message"
    fi

    # Write to session log if monitor is running
    if [[ -f "$LATEST_LOG" ]]; then
        echo "$log_line" >> "$LATEST_LOG"
    fi

    # Always write to all-events log
    echo "$log_line" >> "$ALL_EVENTS_LOG"

    # Run smart pattern detection (but not for INFO level created-task messages)
    if [[ ! "$message" =~ "Created Ralph task" ]]; then
        detect_and_report_issues "$level" "$message" "$details"
    fi
}

#───────────────────────────────────────────────────────────────────────────────
# MAIN
#───────────────────────────────────────────────────────────────────────────────

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    log_event "$@"
fi
