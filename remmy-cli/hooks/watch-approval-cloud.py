#!/usr/bin/env python3
"""
PreToolUse hook that routes tool approval requests to Apple Watch via Cloud Server.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the cloud server
2. Waits for approval from the watch (polling)
3. Returns allow/deny decision to Claude Code

SESSION ISOLATION:
- Requires BOTH:
  1. ~/.remmy/config.json exists (paired with a watch)
  2. CLAUDE_WATCH_SESSION_ACTIVE=1 env var is set (this session opted in)
- Use `remmy` to opt in — it sets the env var automatically
- Other Claude Code sessions skip this hook instantly

APPROACH A (Ship): Questions (AskUserQuestion) always pass through.
The watch is a tool approval device only. Questions appear in terminal.
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error
import uuid

# =============================================================================
# Constants
# =============================================================================

# Config paths: prefer ~/.remmy/, fallback to ~/.claude-watch/
CONFIG_PATH = os.path.expanduser("~/.remmy/config.json")
LEGACY_CONFIG_PATH = os.path.expanduser("~/.claude-watch/config.json")
USER_AGENT = "remmy/1.0"
DEBUG_LOG_PATH = "/tmp/remmy-hook-debug.log"

# Notification debouncing
NOTIFICATION_DEBOUNCE_SECONDS = 3
LAST_NOTIFICATION_FILE = "/tmp/remmy-last-notification"

# Tools that require watch approval
TOOLS_REQUIRING_APPROVAL = {
    "Bash", "Edit", "Write", "MultiEdit", "NotebookEdit",
    "mobile_install_app", "mobile_uninstall_app",
}

# =============================================================================
# Helpers
# =============================================================================

def log(message: str) -> None:
    """Debug logging, only active when REMMY_DEBUG=1."""
    if os.environ.get("REMMY_DEBUG") != "1":
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


def get_config_path() -> str | None:
    """Return the config file path, checking ~/.remmy/ first, then legacy."""
    if os.path.exists(CONFIG_PATH):
        return CONFIG_PATH
    if os.path.exists(LEGACY_CONFIG_PATH):
        return LEGACY_CONFIG_PATH
    return None


def is_watch_session() -> bool:
    """Check if this is a watch session: env var opted in AND config file exists."""
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        return False
    return get_config_path() is not None


def load_config() -> dict | None:
    """Load config from the first available config path."""
    config_path = get_config_path()
    if not config_path:
        return None
    try:
        with open(config_path, "r") as f:
            return json.load(f)
    except (IOError, OSError, json.JSONDecodeError):
        return None


def get_cloud_url() -> str:
    """Get cloud URL from config, env var, or default."""
    # Priority 1: Environment variable
    env_url = os.environ.get("REMMY_CLOUD_URL", "").strip()
    if env_url:
        return env_url

    # Priority 2: Config file
    config = load_config()
    if config and config.get("cloudUrl"):
        return config["cloudUrl"]

    # Priority 3: Default
    return "https://remmy.watch"


def get_pairing_id() -> str | None:
    """
    Load pairing ID from (in order of priority):
    1. CLAUDE_WATCH_PAIRING_ID environment variable
    2. Config file (checking ~/.remmy/ then ~/.claude-watch/)
    """
    # Priority 1: Environment variable
    env_pairing = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if env_pairing:
        return env_pairing

    # Priority 2: config file
    config = load_config()
    if config:
        pairing_id = config.get("pairingId", "").strip()
        if pairing_id:
            return pairing_id

    return None


# =============================================================================
# Session checks
# =============================================================================

def check_session_ended(cloud_url: str, pairing_id: str) -> bool:
    """Check if the session was ended from the watch."""
    try:
        result = http_request(
            f"{cloud_url}/session-status/{pairing_id}",
            method="GET",
            timeout=5,
        )
        if result is None:
            return False
        return not result.get("sessionActive", True)
    except Exception:
        return False


def check_session_interrupted(cloud_url: str, pairing_id: str) -> tuple[bool, str | None]:
    """Check if the session is paused from the watch."""
    try:
        result = http_request(
            f"{cloud_url}/session-interrupt/{pairing_id}",
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

def create_request(cloud_url: str, request_data: dict) -> str | None:
    """Create a request on the cloud server, return request_id."""
    request_id = str(uuid.uuid4())
    request_data["id"] = request_id

    try:
        result = http_request(
            f"{cloud_url}/approval",
            method="POST",
            data=request_data,
            timeout=10,
        )
        if result is None:
            return None
        return result.get("requestId", request_id)
    except Exception:
        return None


def wait_for_response(cloud_url: str, request_id: str, pairing_id: str, timeout: int = 300) -> bool | None:
    """
    Poll the cloud server for the response.
    Returns: True (approved), False (rejected), None (session ended)
    """
    start_time = time.time()
    poll_interval = 1.0

    while time.time() - start_time < timeout:
        try:
            result = http_request(
                f"{cloud_url}/approval/{pairing_id}/{request_id}",
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
# AskUserQuestion handler
# =============================================================================

def create_question(cloud_url: str, question_data: dict) -> str | None:
    """Create a question on the cloud server, return question_id."""
    try:
        result = http_request(
            f"{cloud_url}/question",
            method="POST",
            data=question_data,
            timeout=10,
        )
        if result is None:
            return None
        return result.get("questionId", question_data.get("questionId"))
    except Exception:
        return None


def wait_for_question_answer(cloud_url: str, pairing_id: str, question_id: str, timeout: int = 300) -> str | None:
    """
    Poll the cloud server for a question answer.
    Returns: answer string, or None on timeout/error.
    """
    start_time = time.time()
    poll_interval = 1.0

    while time.time() - start_time < timeout:
        try:
            result = http_request(
                f"{cloud_url}/question/{pairing_id}/{question_id}",
                method="GET",
                timeout=10,
            )
            if result is not None:
                answer = result.get("answer")
                if answer is not None:
                    log(f"Question {question_id[:8]} answered: {answer}")
                    return answer
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except Exception:
            pass

        time.sleep(poll_interval)

    log(f"Question {question_id[:8]} timed out after {timeout}s")
    return None


def handle_ask_user_question(cloud_url: str, pairing_id: str, tool_input: dict) -> None:
    """
    Route AskUserQuestion to the watch via cloud.
    Sends question + options, waits for answer, then denies the tool
    with the answer so Claude proceeds without re-asking.
    """
    questions = tool_input.get("questions", [])
    if not questions:
        log("AskUserQuestion with no questions, passing through")
        sys.exit(0)

    # Handle first question (most common case)
    q = questions[0]
    question_text = q.get("question", "")
    raw_options = q.get("options", [])

    # Build options in cloud format: [{label, description}]
    options = []
    for opt in raw_options:
        if isinstance(opt, dict):
            options.append({
                "label": opt.get("label", ""),
                "description": opt.get("description", ""),
            })
        elif isinstance(opt, str):
            options.append({"label": opt, "description": ""})

    if not options:
        log("AskUserQuestion with no options, passing through")
        sys.exit(0)

    question_id = str(uuid.uuid4())
    question_data = {
        "pairingId": pairing_id,
        "questionId": question_id,
        "question": question_text,
        "options": options,
    }

    log(f"Sending question to watch: {question_text[:50]}")

    created_id = create_question(cloud_url, question_data)
    if not created_id:
        log("Failed to create question on cloud, falling back to terminal")
        sys.exit(0)

    log(f"Question created: {created_id[:8]}..., waiting for answer")

    answer = wait_for_question_answer(cloud_url, pairing_id, created_id)

    if answer is None:
        log("No answer received, falling back to terminal")
        sys.exit(0)

    if answer == "handle_on_mac":
        log("User chose 'Handle on Mac', falling back to terminal")
        sys.exit(0)

    # Write answer to temp file so Claude can read it after denial
    answer_file = "/tmp/remmy-question-answer.json"
    try:
        import json as _json
        with open(answer_file, "w") as f:
            _json.dump({
                "question": question_text,
                "answer": answer,
                "questionId": question_id,
                "timestamp": time.time(),
            }, f)
        log(f"Wrote answer to {answer_file}")
    except IOError:
        pass

    # Deny the tool — Claude should read /tmp/remmy-question-answer.json
    print(f"User answered via Apple Watch: {answer}", file=sys.stderr)
    log(f"Denying AskUserQuestion with answer: {answer}")

    output = {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "reason": f"User already answered via Apple Watch: {answer}",
        }
    }
    print(json.dumps(output))
    sys.exit(2)


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

    # Skip tools that don't need approval (unless it's AskUserQuestion)
    if tool_name != "AskUserQuestion" and tool_name not in TOOLS_REQUIRING_APPROVAL:
        log(f"Tool {tool_name} does not require approval, skipping")
        sys.exit(0)

    # Get pairing ID from config
    pairing_id = get_pairing_id()
    if not pairing_id:
        log("No pairing ID found")
        print("Remmy not configured. Run 'remmy' to set up.", file=sys.stderr)
        sys.exit(0)

    # Get cloud URL from config (don't hardcode)
    cloud_url = get_cloud_url()
    log(f"Pairing ID: {pairing_id[:8]}..., Cloud: {cloud_url}")

    # AskUserQuestion: route to watch, deny tool with answer
    if tool_name == "AskUserQuestion":
        handle_ask_user_question(cloud_url, pairing_id, tool_input)
        sys.exit(0)  # fallback if handle function doesn't exit

    # Check if session was ended from watch
    if check_session_ended(cloud_url, pairing_id):
        log("Session ended from watch")
        print("Watch session ended. Using terminal mode.", file=sys.stderr)
        sys.exit(0)

    # Check if session is paused
    is_interrupted, _ = check_session_interrupted(cloud_url, pairing_id)
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
        request_id = create_request(cloud_url, request_data)
        if not request_id:
            log("Failed to create request on cloud server")
            print("Failed to create request", file=sys.stderr)
            sys.exit(0)

        log(f"Request created: {request_id[:8]}...")

        # Poll for approval (blocking)
        approved = wait_for_response(cloud_url, request_id, pairing_id)

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
