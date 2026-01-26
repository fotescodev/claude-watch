#!/usr/bin/env python3
# IMMEDIATE DEBUG: Write to file before ANYTHING else
import datetime as _dt
with open("/tmp/progress-tracker-invoked.log", "a") as _f:
    _f.write(f"{_dt.datetime.now().isoformat()} - Hook invoked\n")

"""
PostToolUse hook that sends activity heartbeats and progress updates to watch.

This hook serves two purposes:

1. HEARTBEAT (Read, Write, Edit, Grep, Glob, Bash):
   - Sends lightweight activity signals on any tool use
   - Shows what Claude is doing: "Reading files", "Editing code", etc.
   - Prevents watch from showing "Idle" while Claude is actively working
   - Includes cached task progress if available

2. PROGRESS (TodoWrite, TaskCreate, TaskUpdate, TaskList):
   - Full task list updates with progress percentage
   - Saves task state locally for heartbeat context
   - Tracks elapsed time since session started

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
TASK_STATE_FILE = os.path.expanduser("~/.claude-watch-tasks.json")


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


def load_task_state() -> dict:
    """
    Load task state from local state file.

    Returns dict with:
    - tasks: List of {id, subject, status, activeForm} dicts
    - lastUpdated: ISO timestamp
    """
    if os.path.exists(TASK_STATE_FILE):
        try:
            with open(TASK_STATE_FILE, 'r') as f:
                return json.load(f)
        except (IOError, OSError, json.JSONDecodeError):
            pass
    return {"tasks": [], "lastUpdated": None}


def save_task_state(tasks: list):
    """Save task state to local state file."""
    try:
        import datetime
        state = {
            "tasks": tasks,
            "lastUpdated": datetime.datetime.now().isoformat()
        }
        with open(TASK_STATE_FILE, 'w') as f:
            json.dump(state, f, indent=2)
    except (IOError, OSError):
        pass


def update_task_in_state(task_id: str, updates: dict) -> list:
    """
    Update a task in the local state file.

    Args:
        task_id: The task ID to update
        updates: Dict with fields to update (status, subject, activeForm)

    Returns:
        Updated list of all tasks
    """
    state = load_task_state()
    tasks = state.get("tasks", [])

    # Find and update the task
    found = False
    for task in tasks:
        if task.get("id") == task_id:
            task.update(updates)
            found = True
            break

    # If task not found, it may be a task we don't have yet
    # This can happen if session started before this hook was installed
    if not found and updates.get("subject"):
        tasks.append({
            "id": task_id,
            "subject": updates.get("subject", f"Task #{task_id}"),
            "status": updates.get("status", "pending"),
            "activeForm": updates.get("activeForm", "")
        })

    save_task_state(tasks)
    return tasks


def add_task_to_state(task_id: str, subject: str, active_form: str = "") -> list:
    """
    Add a new task to the local state file.

    Args:
        task_id: The task ID (may be generated or placeholder)
        subject: Task subject/title
        active_form: Present continuous form for display

    Returns:
        Updated list of all tasks
    """
    state = load_task_state()
    tasks = state.get("tasks", [])

    # Check if task already exists (avoid duplicates)
    for task in tasks:
        if task.get("id") == task_id:
            return tasks

    tasks.append({
        "id": task_id,
        "subject": subject,
        "status": "pending",
        "activeForm": active_form
    })

    save_task_state(tasks)
    return tasks


def clear_task_state():
    """Clear all tasks from state (for new sessions)."""
    save_task_state([])


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


def parse_task_tools(tool_name: str, tool_input: dict) -> tuple[list[dict], str | None, str | None, float]:
    """
    Parse TaskCreate/TaskUpdate/TaskList input and extract progress info.

    These tools use a different format than TodoWrite.

    IMPORTANT: This function maintains local task state to provide accurate
    progress counts. The watch needs to see the FULL task list, not just
    the single task being created/updated.
    """
    if tool_name == "TaskCreate":
        # New task being created - add to local state
        subject = tool_input.get("subject", "New task")
        active_form = tool_input.get("activeForm", subject)

        # Generate a temporary ID using subject hash since we don't get real ID
        task_id = str(hash(subject) % 100000)

        # Add to local state and get full task list
        all_tasks = add_task_to_state(task_id, subject, active_form)

        # Convert to progress format (return ALL tasks, not just new one)
        tasks = []
        current_task = subject
        current_activity = active_form
        completed_count = 0

        for task in all_tasks:
            status = task.get("status", "pending")
            tasks.append({
                "content": task.get("subject", ""),
                "status": status,
                "activeForm": task.get("activeForm", "")
            })
            if status == "completed":
                completed_count += 1

        progress = completed_count / len(tasks) if tasks else 0.0
        return tasks, current_task, current_activity, progress

    elif tool_name == "TaskUpdate":
        # Task being updated - update in local state and return FULL list
        task_id = tool_input.get("taskId", "")

        # Build updates dict from available fields
        updates = {}
        if "status" in tool_input:
            updates["status"] = tool_input["status"]
        if "subject" in tool_input:
            updates["subject"] = tool_input["subject"]
        if "activeForm" in tool_input:
            updates["activeForm"] = tool_input["activeForm"]

        # Update local state and get full task list
        all_tasks = update_task_in_state(task_id, updates)

        # Convert to progress format (return ALL tasks)
        tasks = []
        current_task = None
        current_activity = None
        completed_count = 0

        for task in all_tasks:
            status = task.get("status", "pending")
            subj = task.get("subject", "")
            af = task.get("activeForm", "")

            tasks.append({
                "content": subj,
                "status": status,
                "activeForm": af
            })

            if status == "completed":
                completed_count += 1
            elif status == "in_progress":
                current_task = subj
                current_activity = af if af else subj

        progress = completed_count / len(tasks) if tasks else 0.0
        return tasks, current_task, current_activity, progress

    elif tool_name == "TaskList":
        # TaskList is called to retrieve tasks - return current local state
        state = load_task_state()
        all_tasks = state.get("tasks", [])

        if not all_tasks:
            # No local state - return placeholder
            return [{
                "content": "Checking task list",
                "status": "in_progress",
                "activeForm": "Checking tasks"
            }], "Checking task list", "Checking tasks", 0.0

        # Convert to progress format
        tasks = []
        current_task = None
        current_activity = None
        completed_count = 0

        for task in all_tasks:
            status = task.get("status", "pending")
            subj = task.get("subject", "")
            af = task.get("activeForm", "")

            tasks.append({
                "content": subj,
                "status": status,
                "activeForm": af
            })

            if status == "completed":
                completed_count += 1
            elif status == "in_progress":
                current_task = subj
                current_activity = af if af else subj

        progress = completed_count / len(tasks) if tasks else 0.0
        return tasks, current_task, current_activity, progress

    return [], None, None, 0.0


# Mapping of tool names to human-readable activity descriptions
TOOL_ACTIVITY_MAP = {
    "Read": "Reading files",
    "Write": "Writing code",
    "Edit": "Editing code",
    "Grep": "Searching code",
    "Glob": "Finding files",
    "Bash": "Running command",
}

# Tools that trigger heartbeats (non-task tools)
HEARTBEAT_TOOLS = {"Read", "Write", "Edit", "Grep", "Glob", "Bash"}


def send_heartbeat(pairing_id: str, tool_name: str, tool_input: dict):
    """
    Send a lightweight heartbeat for non-task tools.

    This keeps the watch showing "Working" status instead of "Idle"
    during any tool use, not just task-related tools.
    """
    # Get human-readable activity from map, fallback to tool name
    activity = TOOL_ACTIVITY_MAP.get(tool_name, tool_name)

    # Add context from tool input if available
    if tool_name == "Read":
        file_path = tool_input.get("file_path", "")
        if file_path:
            # Extract just the filename for brevity
            filename = os.path.basename(file_path)
            activity = f"Reading {filename}"
    elif tool_name == "Write":
        file_path = tool_input.get("file_path", "")
        if file_path:
            filename = os.path.basename(file_path)
            activity = f"Writing {filename}"
    elif tool_name == "Edit":
        file_path = tool_input.get("file_path", "")
        if file_path:
            filename = os.path.basename(file_path)
            activity = f"Editing {filename}"
    elif tool_name == "Bash":
        command = tool_input.get("command", "")
        if command:
            # Get first word of command for context
            first_word = command.split()[0] if command.split() else "command"
            activity = f"Running {first_word}"
    elif tool_name == "Grep":
        pattern = tool_input.get("pattern", "")
        if pattern:
            # Truncate long patterns
            short_pattern = pattern[:20] + "..." if len(pattern) > 20 else pattern
            activity = f"Searching: {short_pattern}"

    # Get elapsed time from session state
    session_state = get_session_state()
    elapsed_seconds = session_state.get("elapsedSeconds", 0)

    # Try to get cached task state for context
    cached_state = load_task_state()
    cached_tasks = cached_state.get("tasks", [])

    # Calculate progress from cached tasks
    completed_count = sum(1 for t in cached_tasks if t.get("status") == "completed")
    total_count = len(cached_tasks)
    progress = completed_count / total_count if total_count > 0 else 0

    # Find current in-progress task from cache
    current_task = None
    for task in cached_tasks:
        if task.get("status") == "in_progress":
            current_task = task.get("subject")
            break

    # Build heartbeat payload
    payload = {
        "pairingId": pairing_id,
        "currentActivity": activity,
        "elapsedSeconds": elapsed_seconds,
        "isHeartbeat": True,
        "progress": progress,
        "completedCount": completed_count,
        "totalCount": total_count
    }

    # Include cached task info if available
    if cached_tasks:
        # Convert task format for API
        payload["tasks"] = [{
            "content": t.get("subject", ""),
            "status": t.get("status", "pending"),
            "activeForm": t.get("activeForm", "")
        } for t in cached_tasks]
        payload["currentTask"] = current_task

    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/session-progress",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=3) as resp:
            pass

    except urllib.error.URLError:
        # Silently fail - heartbeats are best-effort
        pass
    except Exception:
        pass


def main():
    # PROGRESS ALWAYS SENT: Unlike approval requests, progress updates are
    # sent from ALL Claude Code sessions. This allows passive monitoring of
    # any session from the watch.
    #
    # For approval requests (watch-approval-cloud.py), session isolation still
    # applies - only cc-watch sessions can approve/reject from the watch.

    # DEBUG: Log all hook invocations
    debug_log = os.path.expanduser("~/.claude-watch-hook-debug.log")
    try:
        with open(debug_log, "a") as f:
            f.write(f"\n--- {time.strftime('%Y-%m-%d %H:%M:%S')} ---\n")
            raw_input = sys.stdin.read()
            f.write(f"Raw input: {raw_input[:500]}\n")
            input_data = json.loads(raw_input) if raw_input else {}
    except Exception as e:
        with open(debug_log, "a") as f:
            f.write(f"Error: {e}\n")
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Get pairing ID early - needed for both heartbeats and progress
    pairing_id = get_pairing_id()
    if not pairing_id:
        # Not paired - silently exit
        sys.exit(0)

    # Check if this is a heartbeat tool (non-task tool)
    if tool_name in HEARTBEAT_TOOLS:
        # Send heartbeat to keep watch showing "Working" status
        send_heartbeat(pairing_id, tool_name, tool_input)
        sys.exit(0)

    # Process TodoWrite or Task* events (full progress updates)
    task_tools = ["TodoWrite", "TaskCreate", "TaskUpdate", "TaskList"]
    if tool_name not in task_tools:
        sys.exit(0)

    # Parse todos and calculate progress
    if tool_name == "TodoWrite":
        tasks, current_task, current_activity, progress = parse_todos(tool_input)
    else:
        # TaskCreate/TaskUpdate/TaskList
        tasks, current_task, current_activity, progress = parse_task_tools(tool_name, tool_input)

    if not tasks:
        # No tasks to report
        sys.exit(0)

    # Check for new session (all pending = fresh start)
    reset_session_if_needed(tasks)

    # For TodoWrite, save task state for heartbeat use
    # (Task* tools already save state in parse_task_tools)
    if tool_name == "TodoWrite":
        task_state = [{
            "id": str(i),
            "subject": t.get("content", ""),
            "status": t.get("status", "pending"),
            "activeForm": t.get("activeForm", "")
        } for i, t in enumerate(tasks)]
        save_task_state(task_state)

    # Get elapsed time
    session_state = get_session_state()
    elapsed_seconds = session_state.get("elapsedSeconds", 0)

    # Send progress to cloud
    send_progress(pairing_id, tasks, current_task, current_activity, progress, elapsed_seconds)

    # Exit cleanly - PostToolUse hooks don't need to output anything
    sys.exit(0)


if __name__ == "__main__":
    main()
