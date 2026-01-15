#!/usr/bin/env python3
"""
PreToolUse hook that routes permission requests to Apple Watch.

When Claude Code tries to use Bash, Edit, Write, etc., this hook:
1. Sends the action to the watch server
2. Waits for approval from the watch
3. Returns allow/deny decision to Claude Code
"""
import json
import sys
import urllib.request
import urllib.error

# REST API runs on port+1 from WebSocket
WATCH_SERVER = "http://localhost:8788"

# Tools that require watch approval
TOOLS_REQUIRING_APPROVAL = {"Bash", "Edit", "Write", "MultiEdit", "NotebookEdit"}


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        # No input or invalid JSON, allow by default
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Skip tools that don't need approval
    if tool_name not in TOOLS_REQUIRING_APPROVAL:
        sys.exit(0)

    # Build approval request
    request_data = {
        "type": map_tool_type(tool_name),
        "title": build_title(tool_name, tool_input),
        "description": build_description(tool_name, tool_input),
        "file_path": tool_input.get("file_path"),
        "command": tool_input.get("command"),
    }

    try:
        # Step 1: Create the action on watch server
        action_id = create_action(request_data)
        if not action_id:
            # Server error, fall back to normal prompt
            sys.exit(0)

        # Step 2: Wait for approval (blocking)
        approved = wait_for_response(action_id)

        if approved:
            # Allow the tool to proceed
            output = {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": "allow"
                }
            }
            print(json.dumps(output))
            sys.exit(0)
        else:
            # Block the tool
            print("Action rejected by watch", file=sys.stderr)
            sys.exit(2)

    except urllib.error.URLError as e:
        # Server unavailable, fall back to normal permission prompt
        print(f"Watch server unavailable: {e}", file=sys.stderr)
        sys.exit(0)
    except Exception as e:
        # Any other error, fall back to normal prompt
        print(f"Hook error: {e}", file=sys.stderr)
        sys.exit(0)


def map_tool_type(tool_name: str) -> str:
    """Map Claude tool names to watch action types."""
    mapping = {
        "Bash": "bash",
        "Edit": "file_edit",
        "Write": "file_create",
        "MultiEdit": "file_edit",
        "NotebookEdit": "file_edit",
    }
    return mapping.get(tool_name, "tool_use")


def build_title(tool_name: str, tool_input: dict) -> str:
    """Build a concise title for the watch display."""
    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        # Get first line, truncate
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
    """Build a description showing what will change."""
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


def create_action(request_data: dict) -> str:
    """Create an action on the watch server, return action_id."""
    req = urllib.request.Request(
        f"{WATCH_SERVER}/test/action",
        data=json.dumps(request_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        return result.get("action_id")


def wait_for_response(action_id: str, timeout: int = 300) -> bool:
    """Wait for watch to approve/reject the action."""
    request_data = {"action_id": action_id, "timeout": timeout}
    req = urllib.request.Request(
        f"{WATCH_SERVER}/action/wait",
        data=json.dumps(request_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    # Add extra time for network latency
    with urllib.request.urlopen(req, timeout=timeout + 10) as resp:
        result = json.loads(resp.read())
        return result.get("approved", False)


if __name__ == "__main__":
    main()
