#!/usr/bin/env python3
"""
PreToolUse hook that routes permission requests to Apple Watch via Cloud Server.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the cloud server
2. Sends a simulated push notification to the watch simulator
3. Waits for approval from the watch (polling)
4. Returns allow/deny decision to Claude Code
"""
import json
import sys
import time
import subprocess
import urllib.request
import urllib.error

# Cloud server configuration
CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_ID = "0a7c5684-24a1-49b0-9c20-67ca7056d0c6"

# Simulator configuration
SIMULATOR_NAME = "Apple Watch Series 11 (46mm)"
BUNDLE_ID = "com.edgeoftrust.claudewatch"

# Tools that require watch approval
TOOLS_REQUIRING_APPROVAL = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"}


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Skip tools that don't need approval
    if tool_name not in TOOLS_REQUIRING_APPROVAL:
        sys.exit(0)

    # Build approval request
    request_data = {
        "pairingId": PAIRING_ID,
        "type": map_tool_type(tool_name),
        "title": build_title(tool_name, tool_input),
        "description": build_description(tool_name, tool_input),
        "filePath": tool_input.get("file_path"),
        "command": tool_input.get("command"),
    }

    try:
        # Step 1: Create the request on cloud server
        request_id = create_request(request_data)
        if not request_id:
            print("Failed to create request", file=sys.stderr)
            sys.exit(0)

        # Step 2: Send simulated push notification to simulator
        send_simulator_notification(request_id, request_data)

        # Step 3: Poll for approval (blocking)
        approved = wait_for_response(request_id)

        if approved:
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow"
                }
            }
            print(json.dumps(output))
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


def send_simulator_notification(request_id: str, request_data: dict):
    """Send a simulated push notification to the watch simulator."""
    import tempfile

    payload = {
        "aps": {
            "alert": {
                "title": f"Claude: {request_data['type'].replace('_', ' ')}",
                "body": request_data["title"],
                "subtitle": request_data.get("description", "")[:50]
            },
            "sound": "default",
            "category": "CLAUDE_ACTION"
        },
        "requestId": request_id,
        "type": request_data["type"],
        "title": request_data["title"],
        "description": request_data.get("description"),
        "filePath": request_data.get("filePath"),
        "command": request_data.get("command")
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
    return False


if __name__ == "__main__":
    main()
