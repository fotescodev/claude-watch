#!/usr/bin/env python3
"""
PreToolUse hook that routes permission requests to Apple Watch via Cloud Server.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the cloud server
2. Sends a simulated push notification to the watch simulator
3. Waits for approval from the watch (polling)
4. Returns allow/deny decision to Claude Code

Configuration:
- Set CLAUDE_WATCH_PAIRING_ID environment variable, OR
- Create ~/.claude-watch-pairing file with your pairing ID
- Run: claude-watch-pair to set up pairing interactively

SESSION ISOLATION:
- Only runs when CLAUDE_WATCH_SESSION_ACTIVE=1 is set
- This env var is set by `npx cc-watch` when starting a watch-enabled session
- Other Claude Code sessions will not interact with the watch
"""
import json
import os
import sys
import time
import subprocess
import urllib.request
import urllib.error

# Cloud server configuration
CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")

# Notification debouncing - prevent barrage of notifications
# Only send a notification if this many seconds have passed since the last one
NOTIFICATION_DEBOUNCE_SECONDS = 3
LAST_NOTIFICATION_FILE = "/tmp/claude-watch-last-notification"

# Debug logging
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
DEBUG_LOG_SCRIPT = os.path.join(SCRIPT_DIR, "watch-debug-log.sh")


def debug_log(level: str, message: str, details: str = ""):
    """Inject event into watch debug monitor."""
    if os.path.exists(DEBUG_LOG_SCRIPT):
        try:
            cmd = [DEBUG_LOG_SCRIPT, level, message]
            if details:
                cmd.append(details)
            subprocess.run(cmd, capture_output=True, timeout=1)
        except Exception:
            pass  # Silent fail - don't break the hook

# Simulator configuration
SIMULATOR_NAME = "Apple Watch Series 11 (46mm)"
BUNDLE_ID = "com.edgeoftrust.claudewatch"

# Tools that require watch approval
TOOLS_REQUIRING_APPROVAL = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"}


def should_send_notification() -> bool:
    """
    Check if enough time has passed to send another notification.
    Returns True if we should send, False if debounced.
    Also updates the timestamp if returning True.
    """
    try:
        if os.path.exists(LAST_NOTIFICATION_FILE):
            with open(LAST_NOTIFICATION_FILE, 'r') as f:
                last_time = float(f.read().strip())
                if time.time() - last_time < NOTIFICATION_DEBOUNCE_SECONDS:
                    return False  # Debounced - don't send
    except (IOError, ValueError):
        pass  # File doesn't exist or invalid - send notification

    # Update timestamp
    try:
        with open(LAST_NOTIFICATION_FILE, 'w') as f:
            f.write(str(time.time()))
    except IOError:
        pass  # Non-critical if we can't write

    return True


def get_pending_count() -> int:
    """Get count of pending requests from cloud server."""
    pairing_id = get_pairing_id()
    if not pairing_id:
        return 0

    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/requests/{pairing_id}",
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read())
            requests = result.get("requests", [])
            return len(requests)
    except Exception:
        return 0


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


def main():
    # Session isolation: Only run if this session was started with cc-watch
    # This prevents other Claude Code sessions from interacting with the watch
    if not os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE"):
        sys.exit(0)

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Skip tools that don't need approval
    if tool_name not in TOOLS_REQUIRING_APPROVAL:
        sys.exit(0)

    debug_log("HOOK", f"PreToolUse triggered: {tool_name}", f"tool={tool_name}")

    # Get pairing ID from config
    pairing_id = get_pairing_id()
    if not pairing_id:
        print("Claude Watch not configured. Run 'claude-watch-pair' or set CLAUDE_WATCH_PAIRING_ID", file=sys.stderr)
        # Allow the action to proceed if watch is not configured (fail open)
        sys.exit(0)

    # Build approval request
    request_data = {
        "pairingId": pairing_id,
        "type": map_tool_type(tool_name),
        "title": build_title(tool_name, tool_input),
        "description": build_description(tool_name, tool_input),
        "filePath": tool_input.get("file_path"),
        "command": tool_input.get("command"),
    }

    try:
        # Step 1: Create the request on cloud server
        debug_log("CLOUD", "Creating approval request", f"title={request_data['title'][:30]}")
        request_id = create_request(request_data)
        if not request_id:
            debug_log("ERROR", "Failed to create request")
            print("Failed to create request", file=sys.stderr)
            sys.exit(0)

        debug_log("REQUEST", f"Request created: {request_id[:8]}", f"id={request_id}")

        # Step 2: Send simulated push notification to simulator (with debouncing)
        if should_send_notification():
            pending_count = get_pending_count()
            debug_log("APNS", f"Sending notification ({pending_count} pending)", f"id={request_id[:8]}")
            send_simulator_notification(request_id, request_data, pending_count)
        else:
            debug_log("APNS", "Notification debounced (recent notification sent)", f"id={request_id[:8]}")

        # Step 3: Poll for approval (blocking)
        debug_log("BLOCK", "Waiting for watch response...", f"id={request_id[:8]}")
        approved = wait_for_response(request_id)

        if approved:
            debug_log("APPROVE", f"✓ Approved: {request_data['title'][:25]}", f"id={request_id[:8]}")
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow"
                }
            }
            print(json.dumps(output))
            sys.exit(0)
        else:
            debug_log("REJECT", f"✗ Rejected: {request_data['title'][:25]}", f"id={request_id[:8]}")
            print("Action rejected by watch", file=sys.stderr)
            sys.exit(2)

    except urllib.error.URLError as e:
        debug_log("ERROR", "Cloud server unavailable", str(e)[:50])
        print(f"Cloud server unavailable: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        debug_log("ERROR", "Hook error", str(e)[:50])
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


def map_tool_type(tool_name: str) -> str:
    mapping = {
        "Bash": "bash",
        "Edit": "file_edit",
        "Write": "file_create",
        "MultiEdit": "file_edit",
        "NotebookEdit": "file_edit",
    }
    return mapping.get(tool_name, "tool_use")


def build_title(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        first_line = cmd.split("\n")[0][:40]
        return f"Run: {first_line}"
    elif tool_name in ("Edit", "MultiEdit"):
        path = tool_input.get("file_path", "unknown")
        filename = path.split("/")[-1]
        return f"Edit: {filename}"
    elif tool_name == "Write":
        path = tool_input.get("file_path", "unknown")
        filename = path.split("/")[-1]
        return f"Create: {filename}"
    elif tool_name == "NotebookEdit":
        path = tool_input.get("notebook_path", "unknown")
        filename = path.split("/")[-1]
        return f"Edit: {filename}"
    return f"{tool_name}"


def build_description(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Bash":
        return tool_input.get("command", "")[:200]
    elif tool_name == "Edit":
        old = tool_input.get("old_string", "")[:30]
        new = tool_input.get("new_string", "")[:30]
        if old and new:
            return f"'{old}' → '{new}'"
        return "Edit file content"
    elif tool_name == "Write":
        content = tool_input.get("content", "")
        return f"Write {len(content)} characters"
    elif tool_name == "MultiEdit":
        edits = tool_input.get("edits", [])
        return f"{len(edits)} edits"
    return ""


def create_request(request_data: dict) -> str:
    """Create a request on the cloud server, return request_id."""
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/request",
        data=json.dumps(request_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        return result.get("requestId")


def send_simulator_notification(request_id: str, request_data: dict, pending_count: int = 1):
    """Send a simulated push notification to the watch simulator."""
    import tempfile

    # Show count in title if multiple pending
    if pending_count > 1:
        title = f"Claude: {pending_count} actions pending"
        body = f"Latest: {request_data['title']}"
    else:
        title = f"Claude: {request_data['type'].replace('_', ' ')}"
        body = request_data["title"]

    payload = {
        "aps": {
            "alert": {
                "title": title,
                "body": body,
                "subtitle": request_data.get("description", "")[:50] if pending_count == 1 else ""
            },
            "sound": "default",
            "category": "CLAUDE_ACTION",
            "badge": pending_count  # Show badge count on app icon
        },
        "requestId": request_id,
        "type": request_data["type"],
        "title": request_data["title"],
        "description": request_data.get("description"),
        "filePath": request_data.get("filePath"),
        "command": request_data.get("command"),
        "pendingCount": pending_count
    }

    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        json.dump(payload, f)
        temp_path = f.name

    try:
        subprocess.run(
            ["xcrun", "simctl", "push", SIMULATOR_NAME, BUNDLE_ID, temp_path],
            capture_output=True,
            timeout=5
        )
    except Exception as e:
        print(f"Failed to send notification: {e}", file=sys.stderr)


def wait_for_response(request_id: str, timeout: int = 300) -> bool:
    """Poll the cloud server for the response."""
    start_time = time.time()
    poll_interval = 1.0  # Poll every second

    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(
                f"{CLOUD_SERVER}/request/{request_id}",
                method="GET"
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read())
                status = result.get("status")

                if status == "approved":
                    return True
                elif status == "rejected":
                    return False
                # Still pending, continue polling

        except Exception as e:
            print(f"Poll error: {e}", file=sys.stderr)

        time.sleep(poll_interval)

    # Timeout - treat as rejection
    debug_log("TIMEOUT", f"Request timed out after {timeout}s", f"id={request_id[:8]}")
    return False


if __name__ == "__main__":
    main()
