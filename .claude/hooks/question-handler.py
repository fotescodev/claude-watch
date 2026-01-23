#!/usr/bin/env python3
"""
PreToolUse hook that routes AskUserQuestion to Apple Watch for binary response.

When Claude Code asks a question with a recommended answer, this hook:
1. Detects if there's a recommended option (first option with "(Recommended)")
2. Sends question + recommendation to cloud server
3. Sends push notification to watch
4. Watch shows binary: "Accept" (use recommendation) or "Handle on Mac"
5. Returns the answer or signals to handle in terminal

IMPORTANT: The watch can ONLY handle binary questions!
- It cannot type text
- It cannot select from multiple options
- It can only: Accept recommendation OR Handle on Mac

Configuration:
- Set CLAUDE_WATCH_PAIRING_ID environment variable, OR
- Create ~/.claude-watch-pairing file with your pairing ID

SESSION ISOLATION:
- Only runs when CLAUDE_WATCH_SESSION_ACTIVE=1 is set
- This env var is set by `npx cc-watch` when starting a watch-enabled session
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
                file_pairing = f.read().strip()
                if file_pairing:
                    return file_pairing
        except (IOError, OSError):
            pass

    return None


def extract_recommendation(questions: list) -> tuple[str, str, bool] | None:
    """
    Extract question and recommended answer from AskUserQuestion input.

    Returns:
        (question, recommended_answer, is_binary) or None if no recommendation
    """
    if not questions or len(questions) == 0:
        return None

    # Get the first question (we only handle single questions on watch)
    q = questions[0]
    question_text = q.get("question", "")
    options = q.get("options", [])

    if not question_text or not options:
        return None

    # Look for recommended option (first option or one marked "(Recommended)")
    recommended = None
    for opt in options:
        label = opt.get("label", "")
        if "(Recommended)" in label:
            # Remove the "(Recommended)" suffix for clean display
            recommended = label.replace("(Recommended)", "").strip()
            break

    # If no explicit recommendation, use the first option
    if not recommended and options:
        recommended = options[0].get("label", "")

    if not recommended:
        return None

    # Check if it's a binary question (2 options)
    is_binary = len(options) == 2

    return (question_text, recommended, is_binary)


def create_question_request(pairing_id: str, question: str, recommended: str) -> str | None:
    """Create a question request on the cloud server."""
    import uuid

    request_id = str(uuid.uuid4())[:8]

    payload = {
        "pairingId": pairing_id,
        "questionId": request_id,
        "question": question,
        "recommendedAnswer": recommended
    }

    try:
        req = urllib.request.Request(
            f"{CLOUD_SERVER}/question",
            data=json.dumps(payload).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )

        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            return result.get("questionId", request_id)
    except Exception as e:
        debug_log("ERROR", f"Failed to create question request: {e}")
        return None


def send_simulator_notification(question_id: str, question: str, recommended: str):
    """Send push notification to watch simulator."""
    import tempfile

    payload = {
        "aps": {
            "alert": {
                "title": "Claude: Question",
                "body": question[:100],
                "subtitle": f"Recommend: {recommended[:50]}"
            },
            "sound": "default",
            "category": "CLAUDE_QUESTION"
        },
        "questionId": question_id,
        "type": "question",
        "question": question,
        "recommendedAnswer": recommended
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
        debug_log("ERROR", f"Failed to send notification: {e}")
    finally:
        try:
            os.unlink(temp_path)
        except:
            pass


def wait_for_response(question_id: str, pairing_id: str, timeout: int = 300) -> dict | None:
    """
    Poll for question response.

    Returns:
        {
            "accepted": True/False,
            "handleOnMac": True/False,
            "answer": str (if accepted)
        }
        or None if timeout/error
    """
    start_time = time.time()
    poll_interval = 1.0

    while time.time() - start_time < timeout:
        try:
            req = urllib.request.Request(
                f"{CLOUD_SERVER}/question/{question_id}?pairingId={pairing_id}",
                method="GET"
            )

            with urllib.request.urlopen(req, timeout=10) as resp:
                result = json.loads(resp.read())
                status = result.get("status")

                if status == "accepted":
                    return {
                        "accepted": True,
                        "handleOnMac": False,
                        "answer": result.get("answer")
                    }
                elif status == "handle_on_mac":
                    return {
                        "accepted": False,
                        "handleOnMac": True,
                        "answer": None
                    }
                elif status == "session_ended":
                    return None
                # Still pending, continue polling

        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
        except Exception as e:
            debug_log("ERROR", f"Poll error: {e}")

        time.sleep(poll_interval)

    return None


def main():
    # SESSION ISOLATION: Only run for cc-watch sessions
    if os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") != "1":
        sys.exit(0)

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")

    # Only handle AskUserQuestion
    if tool_name != "AskUserQuestion":
        sys.exit(0)

    tool_input = input_data.get("tool_input", {})
    questions = tool_input.get("questions", [])

    # Extract recommendation
    result = extract_recommendation(questions)
    if not result:
        # No recommendation found - let terminal handle it
        debug_log("SKIP", "No recommendation found in question")
        sys.exit(0)

    question, recommended, is_binary = result
    debug_log("QUESTION", f"Binary question detected", f"rec={recommended[:30]}")

    # Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        debug_log("SKIP", "No pairing ID configured")
        sys.exit(0)

    # Create request on cloud server
    question_id = create_question_request(pairing_id, question, recommended)
    if not question_id:
        debug_log("ERROR", "Failed to create question request")
        sys.exit(0)

    debug_log("QUESTION", f"Question created: {question_id}", f"q={question[:30]}")

    # Send notification to simulator
    send_simulator_notification(question_id, question, recommended)

    # Wait for response
    debug_log("BLOCK", "Waiting for watch response...", f"id={question_id}")
    response = wait_for_response(question_id, pairing_id)

    if response is None:
        # Timeout or error - let terminal handle
        debug_log("TIMEOUT", "Question response timed out")
        sys.exit(0)

    if response.get("handleOnMac"):
        # User wants to handle on Mac - let terminal show the question
        debug_log("MAC", "User chose to handle on Mac")
        sys.exit(0)

    if response.get("accepted"):
        # User accepted the recommendation
        answer = response.get("answer", recommended)
        debug_log("ACCEPT", f"User accepted: {answer[:30]}")

        # Return the answer to Claude Code
        # For AskUserQuestion, we need to return the selected answer(s)
        output = {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "answers": {
                    questions[0].get("header", "question"): answer
                }
            }
        }
        print(json.dumps(output))
        sys.exit(0)

    # Fallback - let terminal handle
    sys.exit(0)


if __name__ == "__main__":
    main()
