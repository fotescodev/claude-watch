#!/usr/bin/env python3
"""
E2E Test: Question Flow
Tests the complete question → watch → answer → terminal flow.

Usage:
    python3 test-question-e2e.py [--timeout 60]

Flow:
    1. Creates a test question via POST /question
    2. Watch receives and displays the question
    3. User selects an option on watch
    4. Script polls for answer and verifies it
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
import uuid

CLOUD_BASE_URL = "https://claude-watch.fotescodev.workers.dev"
CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")

# ANSI colors
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
BLUE = "\033[94m"
CYAN = "\033[96m"
BOLD = "\033[1m"
RESET = "\033[0m"


def get_pairing_id():
    """Get pairing ID from env var or config file."""
    pairing_id = os.environ.get("CLAUDE_WATCH_PAIRING_ID", "").strip()
    if pairing_id:
        return pairing_id

    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE) as f:
            return f.read().strip()

    return None


def create_question(pairing_id: str, question_text: str, options: list[dict]) -> dict:
    """Create a question via POST /question."""
    payload = {
        "pairingId": pairing_id,
        "type": "question",
        "question": question_text,
        "header": "E2E Test",
        "options": options,
        "multiSelect": False
    }

    req = urllib.request.Request(
        f"{CLOUD_BASE_URL}/question",
        data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def get_question_status(question_id: str) -> dict:
    """Poll question status via GET /question/{id}."""
    req = urllib.request.Request(
        f"{CLOUD_BASE_URL}/question/{question_id}",
        method="GET"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode())


def print_header(text: str):
    print(f"\n{BOLD}{BLUE}{'=' * 60}{RESET}")
    print(f"{BOLD}{BLUE}  {text}{RESET}")
    print(f"{BOLD}{BLUE}{'=' * 60}{RESET}\n")


def print_step(num: int, text: str):
    print(f"{CYAN}[Step {num}]{RESET} {text}")


def print_success(text: str):
    print(f"  {GREEN}✓{RESET} {text}")


def print_error(text: str):
    print(f"  {RED}✗{RESET} {text}")


def print_waiting(text: str):
    print(f"  {YELLOW}⏳{RESET} {text}", end="", flush=True)


def main():
    parser = argparse.ArgumentParser(description="E2E test for question flow")
    parser.add_argument("--timeout", type=int, default=60, help="Timeout in seconds (default: 60)")
    args = parser.parse_args()

    print_header("Claude Watch Question Flow E2E Test")

    # Step 1: Check pairing
    print_step(1, "Checking pairing configuration...")
    pairing_id = get_pairing_id()
    if not pairing_id:
        print_error("No pairing ID found!")
        print(f"       Run pairing flow first or set CLAUDE_WATCH_PAIRING_ID")
        sys.exit(1)
    print_success(f"Pairing ID: {pairing_id[:8]}...")

    # Step 2: Create test question with distinct options
    print_step(2, "Creating test question...")

    test_options = [
        {"label": "Option A", "description": "First choice - pick this to test A"},
        {"label": "Option B", "description": "Second choice - pick this to test B"},
        {"label": "Option C", "description": "Third choice - pick this to test C"},
    ]

    question_text = "E2E Test: Which option do you want to select?"

    try:
        result = create_question(pairing_id, question_text, test_options)
        question_id = result.get("questionId")
        if not question_id:
            print_error(f"Failed to create question: {result}")
            sys.exit(1)
        print_success(f"Question created: {question_id}")
    except Exception as e:
        print_error(f"Failed to create question: {e}")
        sys.exit(1)

    # Step 3: Display what to expect on watch
    print_step(3, "Question sent to watch!")
    print(f"""
    {BOLD}On your Apple Watch, you should see:{RESET}
    ┌─────────────────────────────────┐
    │  {CYAN}E2E Test{RESET}                        │
    │                                 │
    │  {question_text[:30]}...│
    │                                 │
    │  {YELLOW}○ Option A{RESET}                     │
    │  {YELLOW}○ Option B{RESET}                     │
    │  {YELLOW}○ Option C{RESET}                     │
    └─────────────────────────────────┘

    {BOLD}Select any option to continue the test.{RESET}
    """)

    # Step 4: Poll for answer
    print_step(4, f"Waiting for watch response (timeout: {args.timeout}s)...")
    print_waiting("Polling")

    start_time = time.time()
    poll_interval = 1.0
    dots = 0

    while time.time() - start_time < args.timeout:
        try:
            status = get_question_status(question_id)
            current_status = status.get("status", "unknown")

            if current_status == "answered":
                print()  # newline after dots
                answer = status.get("answer", {})
                selected = answer.get("selectedOptions", [])

                print_success(f"Answer received!")
                print()
                print(f"    {BOLD}Selected option(s):{RESET}")
                for opt in selected:
                    print(f"      {GREEN}→ {opt}{RESET}")

                # Verify it's a valid option
                valid_labels = [o["label"] for o in test_options]
                all_valid = all(s in valid_labels for s in selected)

                print()
                if all_valid and len(selected) > 0:
                    print_header("E2E TEST PASSED")
                    print(f"  {GREEN}✓{RESET} Question created successfully")
                    print(f"  {GREEN}✓{RESET} Watch received and displayed question")
                    print(f"  {GREEN}✓{RESET} User selected: {', '.join(selected)}")
                    print(f"  {GREEN}✓{RESET} Answer received back at terminal")
                    print()
                    print(f"  {BOLD}The full question→watch→terminal flow is working!{RESET}")
                    print()
                    sys.exit(0)
                else:
                    print_error(f"Invalid answer received: {selected}")
                    sys.exit(1)

            elif current_status == "pending":
                # Still waiting, print a dot
                print(".", end="", flush=True)
                dots += 1
                if dots % 30 == 0:
                    print()  # newline every 30 dots
                    print_waiting("Still polling")

        except urllib.error.HTTPError as e:
            if e.code == 404:
                print()
                print_error(f"Question not found - may have expired")
                sys.exit(1)
            raise
        except Exception as e:
            print()
            print_error(f"Error polling: {e}")
            # Continue polling despite transient errors

        time.sleep(poll_interval)

    # Timeout
    print()
    print_error(f"Timeout after {args.timeout} seconds")
    print(f"       No response received from watch")
    print(f"       Question ID: {question_id}")
    sys.exit(1)


if __name__ == "__main__":
    main()
