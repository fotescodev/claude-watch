#!/usr/bin/env python3
"""
PostToolUse hook that captures TodoWrite events and sends progress to watch.

When Claude Code updates its todo list, this hook:
1. Parses the todo list from tool input
2. Calculates progress (completed/total)
3. Finds the current in_progress task
4. Sends progress to Cloudflare worker for watch display

Configuration:
- Set CLAUDE_WATCH_PAIRING_ID environment variable, OR
- Create ~/.claude-watch-pairing file with your pairing ID
"""
import json
import os
import sys
import urllib.request
import urllib.error

# Cloud server configuration
CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")


def get_pairing_id() -> str | None:
    """
    Load pairing ID from (in order of priority):
    1. CLAUDE_WATCH_PAIRING_ID environment variable
    2. ~/.claude-watch-pairing config file

    Returns None if not configured.
    """
    # Priority 1: Environment variable
    env_pairing = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if env_pairing:
        return env_pairing

    # Priority 2: Config file
    if os.path.exists(PAIRING_CONFIG_FILE):
        try:
            with open(PAIRING_CONFIG_FILE, 'r') as f:
                file_pairing = f.read().strip()
                if file_pairing:
                    return file_pairing
        except (IOError, OSError) as e:
            print(f"Warning: Could not read {PAIRING_CONFIG_FILE}: {e}", file=sys.stderr)

    return None


def parse_todos(tool_input: dict) -> tuple[list[dict], str | None, float]:
    """
    Parse TodoWrite input and extract progress info.

    Returns:
        (tasks, current_task, progress)
        - tasks: List of {content, status} dicts
        - current_task: Name of in_progress task (or None)
        - progress: Float 0.0-1.0 for completion percentage
    """
    todos = tool_input.get("todos", [])
    if not todos:
        return [], None, 0.0

    tasks = []
    current_task = None
    completed_count = 0

    for todo in todos:
        content = todo.get("content", "")
        status = todo.get("status", "pending")

        tasks.append({
            "content": content,
            "status": status
        })

        if status == "completed":
            completed_count += 1
        elif status == "in_progress":
            current_task = content

    total = len(tasks)
    progress = completed_count / total if total > 0 else 0.0

    return tasks, current_task, progress


def send_progress(pairing_id: str, tasks: list, current_task: str | None, progress: float):
    """Send progress update to Cloudflare worker."""
    completed_count = sum(1 for t in tasks if t["status"] == "completed")
    total_count = len(tasks)

    payload = {
        "pairingId": pairing_id,
        "tasks": tasks,
        "currentTask": current_task,
        "progress": progress,
        "completedCount": completed_count,
        "totalCount": total_count
    }

    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/session-progress",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=5) as resp:
            # We don't need to process the response
            pass

    except urllib.error.URLError as e:
        # Silently fail - don't block Claude Code for progress updates
        print(f"Progress update failed: {e}", file=sys.stderr)
    except Exception as e:
        print(f"Progress update error: {e}", file=sys.stderr)


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")

    # Only process TodoWrite events
    if tool_name != "TodoWrite":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})

    # Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        # Not paired - silently exit
        sys.exit(0)

    # Parse todos and calculate progress
    tasks, current_task, progress = parse_todos(tool_input)

    if not tasks:
        # No tasks to report
        sys.exit(0)

    # Send progress to cloud
    send_progress(pairing_id, tasks, current_task, progress)

    # Exit cleanly - PostToolUse hooks don't need to output anything
    sys.exit(0)


if __name__ == "__main__":
    main()
