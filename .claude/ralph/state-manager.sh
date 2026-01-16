#!/bin/bash
#
# Ralph State Manager - Atomic task state updates
#
# Provides a programmatic interface for updating tasks.yaml,
# preventing manual YAML editing errors.
#
# Usage:
#   ./state-manager.sh complete <task_id>    # Mark task as completed
#   ./state-manager.sh status [task_id]      # Show task status
#   ./state-manager.sh list                  # List all tasks with status
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASKS_FILE="$SCRIPT_DIR/tasks.yaml"

# Colors
if [[ -t 1 ]]; then
    GREEN='\033[0;32m'
    RED='\033[0;31m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' NC=''
fi

# Check for yq
check_yq() {
    if ! command -v yq &> /dev/null; then
        echo -e "${RED}Error: yq is required but not installed${NC}" >&2
        echo "Install with: brew install yq" >&2
        exit 1
    fi
}

# Mark task as completed
mark_complete() {
    local task_id="$1"

    check_yq

    # Verify task exists
    local exists
    exists=$(yq ".tasks[] | select(.id == \"$task_id\") | .id" "$TASKS_FILE" 2>/dev/null || echo "")

    if [[ -z "$exists" ]]; then
        echo -e "${RED}Error: Task '$task_id' not found in tasks.yaml${NC}" >&2
        exit 1
    fi

    # Check if already complete
    local current_status
    current_status=$(yq ".tasks[] | select(.id == \"$task_id\") | .completed" "$TASKS_FILE")

    if [[ "$current_status" == "true" ]]; then
        echo -e "${YELLOW}Task '$task_id' is already marked complete${NC}"
        return 0
    fi

    # Update atomically
    yq -i "(.tasks[] | select(.id == \"$task_id\") | .completed) = true" "$TASKS_FILE"

    # Verify update succeeded
    local new_status
    new_status=$(yq ".tasks[] | select(.id == \"$task_id\") | .completed" "$TASKS_FILE")

    if [[ "$new_status" == "true" ]]; then
        echo -e "${GREEN}✓ Task '$task_id' marked complete${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to update task '$task_id'${NC}" >&2
        return 1
    fi
}

# Show task status
show_status() {
    local task_id="${1:-}"

    check_yq

    if [[ -n "$task_id" ]]; then
        # Show specific task
        local task_data
        task_data=$(yq -o json ".tasks[] | select(.id == \"$task_id\")" "$TASKS_FILE" 2>/dev/null || echo "")

        if [[ -z "$task_data" ]]; then
            echo -e "${RED}Error: Task '$task_id' not found${NC}" >&2
            exit 1
        fi

        local title completed priority
        title=$(echo "$task_data" | yq '.title')
        completed=$(echo "$task_data" | yq '.completed')
        priority=$(echo "$task_data" | yq '.priority')

        if [[ "$completed" == "true" ]]; then
            echo -e "${GREEN}[✓]${NC} $task_id: $title ($priority)"
        else
            echo -e "${RED}[ ]${NC} $task_id: $title ($priority)"
        fi
    else
        # Show all task statuses
        list_tasks
    fi
}

# List all tasks
list_tasks() {
    check_yq

    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  Ralph Task Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo ""

    local total=0
    local completed=0
    local current_group=""

    # Iterate through tasks
    while IFS= read -r line; do
        local id title status priority group
        id=$(echo "$line" | cut -d'|' -f1)
        title=$(echo "$line" | cut -d'|' -f2)
        status=$(echo "$line" | cut -d'|' -f3)
        priority=$(echo "$line" | cut -d'|' -f4)
        group=$(echo "$line" | cut -d'|' -f5)

        # Group header
        if [[ "$group" != "$current_group" ]]; then
            current_group="$group"
            echo ""
            echo -e "${YELLOW}── Group $group ──${NC}"
        fi

        ((total++))

        if [[ "$status" == "true" ]]; then
            ((completed++))
            echo -e "  ${GREEN}[✓]${NC} $id: $title"
        else
            local color="$NC"
            case "$priority" in
                critical) color="$RED" ;;
                high) color="$YELLOW" ;;
                medium) color="$CYAN" ;;
            esac
            echo -e "  ${RED}[ ]${NC} $id: $title ${color}($priority)${NC}"
        fi
    done < <(yq -r '.tasks[] | [.id, .title, .completed, .priority, .parallel_group] | join("|")' "$TASKS_FILE")

    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  Progress: ${GREEN}$completed${NC}/$total tasks complete"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════${NC}"
}

# Run task verification
run_verification() {
    local task_id="$1"
    local project_root
    project_root="$(cd "$SCRIPT_DIR/../.." && pwd)"

    check_yq

    # Get verification script
    local verification
    verification=$(yq ".tasks[] | select(.id == \"$task_id\") | .verification" "$TASKS_FILE" 2>/dev/null)

    if [[ -z "$verification" || "$verification" == "null" ]]; then
        echo -e "${YELLOW}No verification script for task '$task_id'${NC}"
        return 0
    fi

    echo -e "${CYAN}Running verification for task '$task_id'...${NC}"

    # Execute verification in project root
    if (cd "$project_root" && eval "$verification"); then
        echo -e "${GREEN}✓ Verification passed${NC}"
        return 0
    else
        echo -e "${RED}✗ Verification failed${NC}"
        return 1
    fi
}

# Main command dispatcher
case "${1:-}" in
    complete)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 complete <task_id>" >&2
            exit 1
        fi
        mark_complete "$2"
        ;;
    status)
        show_status "${2:-}"
        ;;
    list)
        list_tasks
        ;;
    verify)
        if [[ -z "${2:-}" ]]; then
            echo "Usage: $0 verify <task_id>" >&2
            exit 1
        fi
        run_verification "$2"
        ;;
    *)
        echo "Ralph State Manager"
        echo ""
        echo "Usage:"
        echo "  $0 complete <task_id>   Mark task as completed"
        echo "  $0 status [task_id]     Show task status"
        echo "  $0 list                 List all tasks"
        echo "  $0 verify <task_id>     Run task verification"
        exit 1
        ;;
esac
