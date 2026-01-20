#!/usr/bin/env python3
"""
SessionStart hook for Claude Watch session tracking.

Fires when Claude Code starts, resumes, or forks a session.
Captures session ID and sends to cloud worker for tracking.

Reference: happy-cli-reference/src/claude/session.ts

Usage in .claude/settings.json:
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.py\""
      }]
    }]
  }
}
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime
from pathlib import Path

# Configuration
CLOUD_SERVER_URL = os.environ.get(
    "CLAUDE_WATCH_SERVER_URL",
    "https://claude-watch.fotescodev.workers.dev"
)
PAIRING_FILE = Path.home() / ".claude-watch-pairing"
SESSION_FILE = Path.home() / ".claude-watch-session"
DEBUG = os.environ.get("CLAUDE_WATCH_DEBUG", "0") == "1"

def debug_log(msg: str):
    """Log debug message if DEBUG is enabled."""
    if DEBUG:
        print(f"[session-start] {msg}", file=sys.stderr)

def get_pairing_id() -> str | None:
    """Read pairing ID from file."""
    if not PAIRING_FILE.exists():
        return None
    return PAIRING_FILE.read_text().strip()

def get_session_id() -> str | None:
    """Get session ID from environment or stdin."""
    # Try environment variable first
    session_id = os.environ.get("CLAUDE_SESSION_ID")
    if session_id:
        debug_log(f"Got session ID from env: {session_id}")
        return session_id

    # Try reading from stdin (hook input)
    try:
        if not sys.stdin.isatty():
            input_data = sys.stdin.read()
            if input_data:
                data = json.loads(input_data)
                session_id = data.get("session_id") or data.get("sessionId")
                if session_id:
                    debug_log(f"Got session ID from stdin: {session_id}")
                    return session_id
    except (json.JSONDecodeError, IOError) as e:
        debug_log(f"Failed to read stdin: {e}")

    return None

def save_session_id(session_id: str):
    """Save session ID to local file for other hooks to use."""
    SESSION_FILE.write_text(session_id)
    debug_log(f"Saved session ID to {SESSION_FILE}")

def send_session_start(pairing_id: str, session_id: str) -> bool:
    """Send session start event to cloud worker."""
    url = f"{CLOUD_SERVER_URL}/session-start"

    payload = json.dumps({
        "pairingId": pairing_id,
        "sessionId": session_id,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        "event": "start"
    }).encode("utf-8")

    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=5) as resp:
            debug_log(f"Session start sent: {resp.status}")
            return resp.status == 200
    except urllib.error.URLError as e:
        debug_log(f"Failed to send session start: {e}")
        return False

def main():
    """Main entry point."""
    # Check if watch session is active (session isolation)
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        debug_log("Watch session not active, skipping")
        sys.exit(0)

    # Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        debug_log("No pairing ID found, skipping")
        sys.exit(0)

    # Get session ID
    session_id = get_session_id()
    if not session_id:
        debug_log("No session ID found, skipping")
        sys.exit(0)

    # Save session ID locally
    save_session_id(session_id)

    # Send to cloud
    success = send_session_start(pairing_id, session_id)
    debug_log(f"Session start result: {success}")

    # Always exit 0 to not block Claude
    sys.exit(0)

if __name__ == "__main__":
    main()
