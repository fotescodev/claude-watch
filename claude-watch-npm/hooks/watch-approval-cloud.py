#!/usr/bin/env python3
"""
PreToolUse hook that routes permission requests to Apple Watch via Cloud Server.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the cloud server
2. Sends a push notification to the watch (simulator or real device)
3. Waits for approval from the watch (polling)
4. Returns allow/deny decision to Claude Code

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

# Notification debouncing - prevent barrage of notifications
NOTIFICATION_DEBOUNCE_SECONDS = 3
LAST_NOTIFICATION_FILE = "/tmp/claude-watch-last-notification"

# Simulator configuration (for development/testing)
SIMULATOR_NAME = "Apple Watch Series 11 (46mm)"
BUNDLE_ID = "com.edgeoftrust.claudewatch"

# Tools that require watch approval
TOOLS_REQUIRING_APPROVAL = {
    "Bash", "Edit", "Write", "MultiEdit", "NotebookEdit",
    "mobile_install_app", "mobile_uninstall_app",
}


def get_pairing_id() -> str | None:
    """
    Load pairing ID from (in order of priority):
    1. CLAUDE_WATCH_PAIRING_ID environment variable
    2. ~/.cc-watch/config.json file
    """
    # Priority 1: Environment variable
    env_pairing = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if env_pairing:
        return env_pairing

    # Priority 2: cc-watch config file
    config_path = os.path.expanduser("~/.cc-watch/config.json")
    if os.path.exists(config_path):
        try:
            with open(config_path, 'r') as f:
                config = json.load(f)
                pairing_id = config.get("pairingId", "").strip()
                if pairing_id:
                    return pairing_id
        except (IOError, OSError, json.JSONDecodeError):
            pass

    return None


def should_send_notification() -> bool:
    """Check if enough time has passed to send another notification."""
    try:
        if os.path.exists(LAST_NOTIFICATION_FILE):
            with open(LAST_NOTIFICATION_FILE, 'r') as f:
                last_time = float(f.read().strip())
                if time.time() - last_time < NOTIFICATION_DEBOUNCE_SECONDS:
                    return False
    except (IOError, ValueError):
        pass

    try:
        with open(LAST_NOTIFICATION_FILE, 'w') as f:
            f.write(str(time.time()))
    except IOError:
        pass

    return True


def get_pending_count(pairing_id: str) -> int:
    """Get count of pending requests from cloud server."""
    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/requests/{pairing_id}",
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read())
            return len(result.get("requests", []))
    except Exception:
        return 0


def main():
    # SESSION ISOLATION: Only run for cc-watch sessions
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        sys.exit(0)  # Not a watch session - let terminal handle permissions

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Skip tools that don't need approval
    if tool_name not in TOOLS_REQUIRING_APPROVAL:
        sys.exit(0)

    # Get pairing ID from config
    pairing_id = get_pairing_id()
    if not pairing_id:
        print("Claude Watch not configured. Run 'npx cc-watch' to set up.", file=sys.stderr)
        sys.exit(0)

    # Check if session was ended from watch
    if check_session_ended(pairing_id):
        print("Watch session ended. Using terminal mode.", file=sys.stderr)
        sys.exit(0)

    # Check if session is paused
    is_interrupted, _ = check_session_interrupted(pairing_id)
    if is_interrupted:
        print("Session paused from watch. Tap Resume on watch to continue.", file=sys.stderr)
        sys.exit(2)

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
        # Create the request on cloud server
        request_id = create_request(request_data)
        if not request_id:
            print("Failed to create request", file=sys.stderr)
            sys.exit(0)

        # Send push notification (with debouncing)
        if should_send_notification():
            pending_count = get_pending_count(pairing_id)
            send_notification(request_id, request_data, pending_count)

        # Poll for approval (blocking)
        approved = wait_for_response(request_id, pairing_id)

        if approved is True:
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow"
                }
            }
            print(json.dumps(output))
            sys.exit(0)
        elif approved is None:
            print("Watch session ended. Falling back to terminal mode.", file=sys.stderr)
            sys.exit(0)
        else:
            print("Action rejected by watch", file=sys.stderr)
            sys.exit(2)

    except urllib.error.URLError as e:
        print(f"Cloud server unavailable: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


def map_tool_type(tool_name: str) -> str:
    mapping = {
        "Bash": "bash",
        "Edit": "file_edit",
        "Write": "file_create",
        "MultiEdit": "file_edit",
        "NotebookEdit": "file_edit",
        "mobile_install_app": "mobile_install",
        "mobile_uninstall_app": "mobile_uninstall",
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
    elif tool_name == "mobile_install_app":
        path = tool_input.get("path", "unknown")
        app_name = path.split("/")[-1] if path else "app"
        return f"Install: {app_name}"
    elif tool_name == "mobile_uninstall_app":
        app = tool_input.get("app", tool_input.get("bundleId", "unknown"))
        return f"Uninstall: {app}"
    return f"{tool_name}"


def build_description(tool_name: str, tool_input: dict) -> str:
    if tool_name == "Bash":
        return tool_input.get("command", "")[:200]
    elif tool_name == "Edit":
        old = tool_input.get("old_string", "")[:30]
        new = tool_input.get("new_string", "")[:30]
        if old and new:
            return f"'{old}' -> '{new}'"
        return "Edit file content"
    elif tool_name == "Write":
        content = tool_input.get("content", "")
        return f"Write {len(content)} characters"
    elif tool_name == "MultiEdit":
        edits = tool_input.get("edits", [])
        return f"{len(edits)} edits"
    elif tool_name == "mobile_install_app":
        path = tool_input.get("path", "")
        device = tool_input.get("device", "simulator")
        return f"Deploy to {device}: {path[:100]}"
    elif tool_name == "mobile_uninstall_app":
        app = tool_input.get("app", tool_input.get("bundleId", ""))
        return f"Remove app: {app}"
    return ""


def create_request(request_data: dict) -> str:
    """Create a request on the cloud server, return request_id."""
    import uuid

    request_id = str(uuid.uuid4())
    request_data["id"] = request_id

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/approval",
        data=json.dumps(request_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        return result.get("requestId", request_id)


def send_notification(request_id: str, request_data: dict, pending_count: int = 1):
    """Send push notification to watch (simulator for now)."""
    import tempfile

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
            "badge": pending_count
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
    except Exception:
        pass  # Non-critical if notification fails


def check_session_ended(pairing_id: str) -> bool:
    """Check if the session was ended from the watch."""
    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/session-status/{pairing_id}",
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read())
            return not result.get("sessionActive", True)
    except Exception:
        return False


def check_session_interrupted(pairing_id: str) -> tuple[bool, str | None]:
    """Check if the session is paused from the watch."""
    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/session-interrupt/{pairing_id}",
            method="GET"
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            result = json.loads(resp.read())
            return (result.get("interrupted", False), result.get("action"))
    except Exception:
        return (False, None)


def wait_for_response(request_id: str, pairing_id: str, timeout: int = 300) -> bool | None:
    """
    Poll the cloud server for the response.
    Returns: True (approved), False (rejected), None (session ended)
    """
    start_time = time.time()
    poll_interval = 1.0

    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(
                f"{CLOUD_SERVER}/approval/{pairing_id}/{request_id}",
                method="GET"
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read())
                status = result.get("status")

                if status == "approved":
                    return True
                elif status == "rejected":
                    return False
                elif status == "session_ended":
                    return None

        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except Exception:
            pass

        time.sleep(poll_interval)

    return False  # Timeout - treat as rejection


if __name__ == "__main__":
    main()
