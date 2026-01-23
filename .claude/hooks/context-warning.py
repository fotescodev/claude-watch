#!/usr/bin/env python3
"""
PostToolUse hook that monitors context usage and warns the watch at thresholds.

When Claude Code's context reaches 75%, 85%, or 95%, this hook:
1. Detects the context threshold crossing
2. Sends notification to watch via cloud server
3. Watch shows ContextWarningView with percentage

NOTE: Context percentage detection relies on Claude Code exposing this in
tool results or through summarization events. This hook monitors for:
- Tool results that indicate context compaction
- Summarization tool usage
- Memory pressure indicators

Configuration:
- Set CLAUDE_WATCH_PAIRING_ID environment variable, OR
- Create ~/.claude-watch-pairing file with your pairing ID

SESSION ISOLATION:
- Only runs when CLAUDE_WATCH_SESSION_ACTIVE=1 is set
"""
import json
import os
import sys
import subprocess
import urllib.request
import urllib.error

# Cloud server configuration
CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")

# Context thresholds to warn at
CONTEXT_THRESHOLDS = [75, 85, 95]

# Track which thresholds we've already warned about this session
WARNED_THRESHOLDS_FILE = "/tmp/claude-watch-context-warned"

# Simulator configuration
SIMULATOR_NAME = "Apple Watch Series 11 (46mm)"
BUNDLE_ID = "com.edgeoftrust.claudewatch"

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
            pass


def get_pairing_id() -> str | None:
    """Load pairing ID from env or config file."""
    env_pairing = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if env_pairing:
        return env_pairing

    if os.path.exists(PAIRING_CONFIG_FILE):
        try:
            with open(PAIRING_CONFIG_FILE, 'r') as f:
                return f.read().strip() or None
        except (IOError, OSError):
            pass
    return None


def get_warned_thresholds() -> set:
    """Get set of thresholds we've already warned about."""
    try:
        if os.path.exists(WARNED_THRESHOLDS_FILE):
            with open(WARNED_THRESHOLDS_FILE, 'r') as f:
                data = json.load(f)
                return set(data.get("thresholds", []))
    except (IOError, json.JSONDecodeError):
        pass
    return set()


def save_warned_threshold(threshold: int):
    """Record that we've warned about this threshold."""
    warned = get_warned_thresholds()
    warned.add(threshold)
    try:
        with open(WARNED_THRESHOLDS_FILE, 'w') as f:
            json.dump({"thresholds": list(warned)}, f)
    except IOError:
        pass


def reset_warned_thresholds():
    """Reset warned thresholds (call at session start)."""
    try:
        if os.path.exists(WARNED_THRESHOLDS_FILE):
            os.unlink(WARNED_THRESHOLDS_FILE)
    except IOError:
        pass


def detect_context_percentage(tool_name: str, tool_input: dict, tool_result: dict) -> int | None:
    """
    Attempt to detect context usage percentage from tool results.

    Returns percentage (0-100) or None if not detectable.

    Detection methods:
    1. Explicit context_usage field in tool result
    2. Summarization tool invocation (indicates high context)
    3. Message about context compaction
    """
    # Method 1: Explicit field
    if isinstance(tool_result, dict):
        context_usage = tool_result.get("context_usage")
        if context_usage is not None:
            return int(context_usage)

        # Check for context percentage in result text
        result_text = tool_result.get("result", "")
        if isinstance(result_text, str):
            # Look for patterns like "Context: 85%" or "context usage: 90%"
            import re
            match = re.search(r'context[:\s]+(\d+)%', result_text, re.IGNORECASE)
            if match:
                return int(match.group(1))

    # Method 2: Summarization indicates high context
    if tool_name == "Summarize":
        # Summarization happening means we're at or near limit
        return 95

    # Method 3: Check for compaction message in result
    if isinstance(tool_result, dict):
        result_text = str(tool_result.get("result", ""))
        if "context" in result_text.lower() and "compact" in result_text.lower():
            return 90

    return None


def get_threshold_to_warn(percentage: int) -> int | None:
    """
    Get the highest threshold that should trigger a warning.

    Returns the threshold to warn at, or None if already warned or below thresholds.
    """
    warned = get_warned_thresholds()

    for threshold in sorted(CONTEXT_THRESHOLDS, reverse=True):
        if percentage >= threshold and threshold not in warned:
            return threshold

    return None


def send_context_warning(pairing_id: str, percentage: int, threshold: int):
    """Send context warning to cloud server."""
    payload = {
        "pairingId": pairing_id,
        "percentage": percentage,
        "threshold": threshold
    }

    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/context-warning",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=5) as resp:
            debug_log("CONTEXT", f"Warning sent: {percentage}%", f"threshold={threshold}")
    except Exception as e:
        debug_log("ERROR", f"Failed to send context warning: {e}")


def send_simulator_notification(percentage: int, threshold: int):
    """Send push notification to watch simulator."""
    import tempfile

    # Severity-based messaging
    if threshold >= 95:
        title = "⚠️ Context Critical"
        body = f"{percentage}% used - session may compact soon"
    elif threshold >= 85:
        title = "Context Warning"
        body = f"{percentage}% used - approaching limit"
    else:
        title = "Context Notice"
        body = f"{percentage}% of context used"

    payload = {
        "aps": {
            "alert": {
                "title": title,
                "body": body
            },
            "sound": "default" if threshold >= 85 else None,
            "category": "CLAUDE_CONTEXT"
        },
        "type": "context_warning",
        "percentage": percentage,
        "threshold": threshold
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
        pass
    finally:
        try:
            os.unlink(temp_path)
        except:
            pass


def main():
    # SESSION ISOLATION
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        sys.exit(0)

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_result = input_data.get("tool_result", {})

    # Try to detect context percentage
    percentage = detect_context_percentage(tool_name, tool_input, tool_result)
    if percentage is None:
        sys.exit(0)

    debug_log("CONTEXT", f"Detected context usage: {percentage}%")

    # Check if we need to warn
    threshold = get_threshold_to_warn(percentage)
    if threshold is None:
        sys.exit(0)

    # Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        sys.exit(0)

    # Send warning
    debug_log("CONTEXT", f"Threshold {threshold}% crossed", f"actual={percentage}%")
    send_context_warning(pairing_id, percentage, threshold)
    send_simulator_notification(percentage, threshold)

    # Record that we've warned at this threshold
    save_warned_threshold(threshold)

    sys.exit(0)


if __name__ == "__main__":
    main()
