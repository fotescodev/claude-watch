#!/usr/bin/env python3
"""
PostToolUse hook that captures TodoWrite events and sends progress to watch.

When Claude Code updates its todo list, this hook:
1. Parses the todo list from tool input
2. Calculates progress (completed/total)
3. Finds the current in_progress task
4. Tracks elapsed time since session started
5. Sends progress to Cloudflare worker for watch display

Configuration:
- Set CLAUDE_WATCH_PAIRING_ID environment variable, OR
- Create ~/.claude-watch-pairing file with your pairing ID

NOTE: Unlike approval requests (watch-approval-cloud.py), progress updates
are sent from ALL Claude Code sessions when paired. This enables passive
monitoring of any session from the watch. Session isolation only applies
to approval/rejection actions, not progress tracking.
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

# Cloud server configuration
CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")
SESSION_STATE_FILE = os.path.expanduser("~/.claude-watch-session")


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


def get_session_state() -> dict:
    """
    Load or create session state tracking elapsed time.

    Session state is stored per-pairing to track:
    - Session start time (first TodoWrite in this session)
    - Previous tasks hash (to detect new sessions)

    Returns dict with:
    - startTime: Unix timestamp when session started
    - elapsedSeconds: Seconds since session started
    """
    if os.path.exists(SESSION_STATE_FILE):
        try:
            with open(SESSION_STATE_FILE, 'r') as f:
                state = json.load(f)
                elapsed = int(time.time() - state.get("startTime", time.time()))
                return {
                    "startTime": state.get("startTime"),
                    "elapsedSeconds": elapsed
                }
        except (IOError, OSError, json.JSONDecodeError):
            pass

    # New session - record start time
    start_time = time.time()
    save_session_state(start_time)
    return {
        "startTime": start_time,
        "elapsedSeconds": 0
    }


def save_session_state(start_time: float):
    """Save session start time to state file."""
    try:
        with open(SESSION_STATE_FILE, 'w') as f:
            json.dump({"startTime": start_time}, f)
    except (IOError, OSError):
        pass


def reset_session_if_needed(tasks: list):
    """
    Reset session if tasks changed significantly (new session detected).

    Heuristic: If all tasks are pending (fresh start), reset the timer.
    """
    if not tasks:
        return

    all_pending = all(t.get("status") == "pending" for t in tasks)
    if all_pending:
        # Fresh task list - new session
        save_session_state(time.time())


def parse_todos(tool_input: dict) -> tuple[list[dict], str | None, str | None, float]:
    """
    Parse TodoWrite input and extract progress info.

    Returns:
        (tasks, current_task, current_activity, progress)
        - tasks: List of {content, status} dicts
        - current_task: Name of in_progress task (or None)
        - current_activity: Active form of in_progress task for display (or None)
        - progress: Float 0.0-1.0 for completion percentage
    """
    todos = tool_input.get("todos", [])
    if not todos:
        return [], None, None, 0.0

    tasks = []
    current_task = None
    current_activity = None
    completed_count = 0

    for todo in todos:
        content = todo.get("content", "")
        status = todo.get("status", "pending")
        active_form = todo.get("activeForm", "")

        tasks.append({
            "content": content,
            "status": status,
            "activeForm": active_form
        })

        if status == "completed":
            completed_count += 1
        elif status == "in_progress":
            current_task = content
            # Use activeForm for activity display (e.g., "Running tests" instead of "Run tests")
            current_activity = active_form if active_form else content

    total = len(tasks)
    progress = completed_count / total if total > 0 else 0.0

    return tasks, current_task, current_activity, progress


def send_progress(pairing_id: str, tasks: list, current_task: str | None, current_activity: str | None, progress: float, elapsed_seconds: int):
    """Send progress update to Cloudflare worker."""
    completed_count = sum(1 for t in tasks if t["status"] == "completed")
    total_count = len(tasks)

    payload = {
        "pairingId": pairing_id,
        "tasks": tasks,
        "currentTask": current_task,
        "currentActivity": current_activity,  # Active form for display (e.g., "Running tests")
        "progress": progress,
        "completedCount": completed_count,
        "totalCount": total_count,
        "elapsedSeconds": elapsed_seconds
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
    # PROGRESS ALWAYS SENT: Unlike approval requests, progress updates are
    # sent from ALL Claude Code sessions. This allows passive monitoring of
    # any session from the watch.
    #
    # For approval requests (watch-approval-cloud.py), session isolation still
    # applies - only cc-watch sessions can approve/reject from the watch.

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
    tasks, current_task, current_activity, progress = parse_todos(tool_input)

    if not tasks:
        # No tasks to report
        sys.exit(0)

    # Check for new session (all pending = fresh start)
    reset_session_if_needed(tasks)

    # Get elapsed time
    session_state = get_session_state()
    elapsed_seconds = session_state.get("elapsedSeconds", 0)

    # Send progress to cloud
    send_progress(pairing_id, tasks, current_task, current_activity, progress, elapsed_seconds)

    # Exit cleanly - PostToolUse hooks don't need to output anything
    sys.exit(0)


if __name__ == "__main__":
    main()
