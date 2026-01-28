#!/usr/bin/env python3
"""
PreToolUse hook that routes tool approval requests to Apple Watch via Cloud Server.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the cloud server
2. Sends a push notification to the watch
3. Waits for approval from the watch (polling)
4. Returns allow/deny decision to Claude Code

SESSION ISOLATION:
- Requires BOTH:
  1. ~/.claude-watch/config.json exists (paired with a watch)
  2. CLAUDE_WATCH_SESSION_ACTIVE=1 env var is set (this session opted in)
- Use `npx cc-watch run` or set the env var manually to opt in
- Other Claude Code sessions skip this hook instantly

APPROACH A (Ship): Questions (AskUserQuestion) always pass through.
The watch is a tool approval device only. Questions appear in terminal.
"""
import json
import os
import sys
import time
import subprocess
import urllib.request
import urllib.error
import uuid

# =============================================================================
# Constants
# =============================================================================

CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
CONFIG_PATH = os.path.expanduser("~/.claude-watch/config.json")
USER_AGENT = "cc-watch/1.0"
DEBUG_LOG_PATH = "/tmp/watch-hook-debug.log"

# Notification debouncing
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

# =============================================================================
# Helpers
# =============================================================================

def log(message: str) -> None:
    """Debug logging, only active when CC_WATCH_DEBUG=1."""
    if os.environ.get("CC_WATCH_DEBUG") != "1":
        return
    try:
        with open(DEBUG_LOG_PATH, "a") as f:
            ts = time.strftime("%H:%M:%S")
            f.write(f"[{ts}] {message}\n")
    except IOError:
        pass


def http_request(
    url: str,
    method: str = "GET",
    data: dict | None = None,
    timeout: int = 10,
) -> dict | None:
    """
    Centralized HTTP helper. ALL requests go through here.
    Guarantees User-Agent header on every request (prevents Cloudflare 403).
    Returns parsed JSON dict or None on error.
    """
    headers = {"User-Agent": USER_AGENT}
    body = None

    if data is not None:
        headers["Content-Type"] = "application/json"
        body = json.dumps(data).encode()

    req = urllib.request.Request(url, data=body, headers=headers, method=method)

    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        log(f"HTTP {e.code} from {method} {url}")
        raise
    except Exception as e:
        log(f"Request failed: {method} {url} - {e}")
        return None


def is_watch_session() -> bool:
    """Check if this is a watch session: env var opted in AND config file exists."""
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        return False
    return os.path.exists(CONFIG_PATH)


def get_pairing_id() -> str | None:
    """
    Load pairing ID from (in order of priority):
    1. CLAUDE_WATCH_PAIRING_ID environment variable
    2. ~/.claude-watch/config.json file
    """
    # Priority 1: Environment variable
    env_pairing = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if env_pairing:
        return env_pairing

    # Priority 2: config file
    try:
        with open(CONFIG_PATH, "r") as f:
            config = json.load(f)
            pairing_id = config.get("pairingId", "").strip()
            if pairing_id:
                return pairing_id
    except (IOError, OSError, json.JSONDecodeError):
        pass

    return None


# =============================================================================
# Session checks
# =============================================================================

def check_session_ended(pairing_id: str) -> bool:
    """Check if the session was ended from the watch."""
    try:
        result = http_request(
            f"{CLOUD_SERVER}/session-status/{pairing_id}",
            method="GET",
            timeout=5,
        )
        if result is None:
            return False
        return not result.get("sessionActive", True)
    except Exception:
        return False


def check_session_interrupted(pairing_id: str) -> tuple[bool, str | None]:
    """Check if the session is paused from the watch."""
    try:
        result = http_request(
            f"{CLOUD_SERVER}/session-interrupt/{pairing_id}",
            method="GET",
            timeout=5,
        )
        if result is None:
            return (False, None)
        return (result.get("interrupted", False), result.get("action"))
    except Exception:
        return (False, None)


# =============================================================================
# Request lifecycle
# =============================================================================

def create_request(request_data: dict) -> str | None:
    """Create a request on the cloud server, return request_id."""
    request_id = str(uuid.uuid4())
    request_data["id"] = request_id

    try:
        result = http_request(
            f"{CLOUD_SERVER}/approval",
            method="POST",
            data=request_data,
            timeout=10,
        )
        if result is None:
            return None
        return result.get("requestId", request_id)
    except Exception:
        return None


def get_pending_count(pairing_id: str) -> int:
    """Get count of pending requests from cloud server."""
    try:
        result = http_request(
            f"{CLOUD_SERVER}/requests/{pairing_id}",
            method="GET",
            timeout=5,
        )
        if result is None:
            return 0
        return len(result.get("requests", []))
    except Exception:
        return 0


def wait_for_response(request_id: str, pairing_id: str, timeout: int = 300) -> bool | None:
    """
    Poll the cloud server for the response.
    Returns: True (approved), False (rejected), None (session ended)
    """
    start_time = time.time()
    poll_interval = 1.0

    while time.time() - start_time < timeout:
        try:
            result = http_request(
                f"{CLOUD_SERVER}/approval/{pairing_id}/{request_id}",
                method="GET",
                timeout=10,
            )
            if result is not None:
                status = result.get("status")
                if status == "approved":
                    log(f"Request {request_id[:8]} approved")
                    return True
                elif status == "rejected":
                    log(f"Request {request_id[:8]} rejected")
                    return False
                elif status == "session_ended":
                    log(f"Session ended during poll for {request_id[:8]}")
                    return None
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except Exception:
            pass

        time.sleep(poll_interval)

    log(f"Request {request_id[:8]} timed out after {timeout}s")
    return False  # Timeout - treat as rejection


# =============================================================================
# Notifications
# =============================================================================

def should_send_notification() -> bool:
    """Check if enough time has passed to send another notification."""
    try:
        if os.path.exists(LAST_NOTIFICATION_FILE):
            with open(LAST_NOTIFICATION_FILE, "r") as f:
                last_time = float(f.read().strip())
                if time.time() - last_time < NOTIFICATION_DEBOUNCE_SECONDS:
                    return False
    except (IOError, ValueError):
        pass

    try:
        with open(LAST_NOTIFICATION_FILE, "w") as f:
            f.write(str(time.time()))
    except IOError:
        pass

    return True


def send_notification(request_id: str, request_data: dict, pending_count: int = 1) -> None:
    """Send push notification to watch (simulator for development)."""
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
                "subtitle": request_data.get("description", "")[:50] if pending_count == 1 else "",
            },
            "sound": "default",
            "category": "CLAUDE_ACTION",
            "badge": pending_count,
        },
        "requestId": request_id,
        "type": request_data["type"],
        "title": request_data["title"],
        "description": request_data.get("description"),
        "filePath": request_data.get("filePath"),
        "command": request_data.get("command"),
        "pendingCount": pending_count,
    }

    with tempfile.NamedTemporaryFile(mode="w", suffix=".json", delete=False) as f:
        json.dump(payload, f)
        temp_path = f.name

    try:
        subprocess.run(
            ["xcrun", "simctl", "push", SIMULATOR_NAME, BUNDLE_ID, temp_path],
            capture_output=True,
            timeout=5,
        )
    except Exception:
        pass  # Non-critical if notification fails


# =============================================================================
# Display helpers
# =============================================================================

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


# =============================================================================
# Main
# =============================================================================

def main():
    # Fast path: no config file = not a watch session, exit immediately
    if not is_watch_session():
        log("Not a watch session (missing env var or config file)")
        sys.exit(0)

    log("Watch session detected")

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        log("Failed to parse stdin JSON")
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    log(f"Tool: {tool_name}")

    # AskUserQuestion: always pass through (Approach A)
    # Questions appear in terminal, watch gets no blocking prompt
    if tool_name == "AskUserQuestion":
        log("AskUserQuestion - passthrough (Approach A)")
        sys.exit(0)

    # Skip tools that don't need approval
    if tool_name not in TOOLS_REQUIRING_APPROVAL:
        log(f"Tool {tool_name} does not require approval, skipping")
        sys.exit(0)

    # Get pairing ID from config
    pairing_id = get_pairing_id()
    if not pairing_id:
        log("No pairing ID found")
        print("Claude Watch not configured. Run 'npx cc-watch' to set up.", file=sys.stderr)
        sys.exit(0)

    log(f"Pairing ID: {pairing_id[:8]}...")

    # Check if session was ended from watch
    if check_session_ended(pairing_id):
        log("Session ended from watch")
        print("Watch session ended. Using terminal mode.", file=sys.stderr)
        sys.exit(0)

    # Check if session is paused
    is_interrupted, _ = check_session_interrupted(pairing_id)
    if is_interrupted:
        log("Session paused from watch")
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
            log("Failed to create request on cloud server")
            print("Failed to create request", file=sys.stderr)
            sys.exit(0)

        log(f"Request created: {request_id[:8]}...")

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
                    "permissionDecision": "allow",
                }
            }
            print(json.dumps(output))
            log(f"Emitted allow for {request_id[:8]}")
            sys.exit(0)
        elif approved is None:
            log("Session ended during poll, falling back to terminal")
            print("Watch session ended. Falling back to terminal mode.", file=sys.stderr)
            sys.exit(0)
        else:
            log(f"Request {request_id[:8]} rejected")
            print("Action rejected by watch", file=sys.stderr)
            sys.exit(2)

    except urllib.error.URLError as e:
        log(f"Cloud server unavailable: {e}")
        print(f"Cloud server unavailable: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        log(f"Hook error: {e}")
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
