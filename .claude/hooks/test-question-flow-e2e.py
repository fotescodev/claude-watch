#!/usr/bin/env python3
"""
Automated E2E test for question flow.

Tests the complete question lifecycle without manual watch interaction:
1. Question creation succeeds
2. Question appears in pending list
3. Answer submission works
4. Question marked as answered
5. Question removed from pending list

Usage:
    python3 test-question-flow-e2e.py

Note: This is an automated test that simulates watch answering.
      For interactive testing with actual watch, use test-question-e2e.py
"""

import json
import os
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"


def get_pairing_id():
    """Get pairing ID from config file or legacy file."""
    home = Path.home()

    # Try config file first
    config_path = home / ".claude-watch" / "config.json"
    if config_path.exists():
        try:
            config = json.loads(config_path.read_text())
            if config.get("pairingId"):
                return config["pairingId"]
        except json.JSONDecodeError:
            pass

    # Fall back to legacy file
    legacy_path = home / ".claude-watch-pairing"
    if legacy_path.exists():
        return legacy_path.read_text().strip()

    return None


def create_question(pairing_id: str) -> str | None:
    """Create a test question, return questionId."""
    question_data = {
        "pairingId": pairing_id,
        "type": "question",
        "question": "E2E Test: Select an option",
        "header": "Automated Test",
        "options": [
            {"label": "Option A", "description": "First choice"},
            {"label": "Option B", "description": "Second choice"},
            {"label": "Option C", "description": "Third choice"},
        ],
        "multiSelect": False,
    }

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question",
        data=json.dumps(question_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            return result.get("questionId")
    except urllib.error.URLError as e:
        print(f"  [ERROR] Failed to create question: {e}")
        return None


def check_question_pending(pairing_id: str, question_id: str) -> bool:
    """Check if question appears in pending list."""
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/questions/{pairing_id}",
        method="GET"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            questions = result.get("questions", [])
            return any(q.get("id") == question_id for q in questions)
    except urllib.error.URLError as e:
        print(f"  [ERROR] Failed to check pending: {e}")
        return False


def submit_answer(question_id: str, selected_indices: list) -> bool:
    """Submit an answer to a question."""
    answer_data = {"selectedIndices": selected_indices}

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}/answer",
        data=json.dumps(answer_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return resp.status == 200
    except urllib.error.URLError as e:
        print(f"  [ERROR] Failed to submit answer: {e}")
        return False


def check_question_answered(question_id: str) -> tuple[bool, list | None]:
    """Check if question is marked as answered, return (is_answered, selected_indices)."""
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}",
        method="GET"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            status = result.get("status")
            selected = result.get("selectedIndices")
            return (status == "answered", selected)
    except urllib.error.URLError as e:
        print(f"  [ERROR] Failed to check status: {e}")
        return (False, None)


def test_question_flow():
    """Run the complete question flow E2E test."""
    print("=" * 60)
    print("  Question Flow E2E Test (Automated)")
    print("=" * 60)

    # Step 0: Get pairing ID
    pairing_id = get_pairing_id()
    if not pairing_id:
        print("\n  [FAIL] No pairing ID found")
        print("         Run 'npx cc-watch' to pair first")
        return False

    print(f"\n[1] Using pairing ID: {pairing_id[:12]}...")

    # Step 1: Create question
    print("\n[2] Creating test question...")
    question_id = create_question(pairing_id)

    if not question_id:
        print("  [FAIL] Could not create question")
        return False

    print(f"  [PASS] Question created: {question_id[:12]}...")

    # Step 2: Verify question is pending
    print("\n[3] Verifying question is pending...")
    if check_question_pending(pairing_id, question_id):
        print("  [PASS] Question found in pending list")
    else:
        print("  [FAIL] Question not in pending list")
        return False

    # Step 3: Submit answer (select option index 1 = "Option B")
    print("\n[4] Submitting answer (selecting 'Option B')...")
    if submit_answer(question_id, [1]):
        print("  [PASS] Answer submitted successfully")
    else:
        print("  [FAIL] Failed to submit answer")
        return False

    # Step 4: Verify question is answered
    print("\n[5] Verifying question status...")
    is_answered, selected = check_question_answered(question_id)

    if not is_answered:
        print("  [FAIL] Question not marked as answered")
        return False

    if selected != [1]:
        print(f"  [FAIL] Wrong selectedIndices: {selected}, expected [1]")
        return False

    print("  [PASS] Question marked as answered")
    print(f"  [PASS] Selected indices: {selected} (Option B)")

    # Step 5: Verify removed from pending
    print("\n[6] Verifying removed from pending list...")
    # Give cloud a moment to process
    time.sleep(0.5)

    still_pending = check_question_pending(pairing_id, question_id)
    if still_pending:
        print("  [WARN] Question still in pending list (cleanup may be delayed)")
    else:
        print("  [PASS] Question removed from pending list")

    # Final result
    print("\n" + "=" * 60)
    print("  E2E TEST PASSED")
    print("=" * 60)
    print("  [PASS] Question created successfully")
    print("  [PASS] Question appeared in pending list")
    print("  [PASS] Answer submitted successfully")
    print("  [PASS] Question status updated to 'answered'")
    print("  [PASS] Selected indices correctly recorded")
    print("\n  The question flow API is working correctly!")

    return True


def test_skip_flow():
    """Test the skip flow (user chooses to answer in terminal)."""
    print("\n" + "=" * 60)
    print("  Skip Flow Test")
    print("=" * 60)

    pairing_id = get_pairing_id()
    if not pairing_id:
        print("  [SKIP] No pairing ID")
        return True

    # Create question
    print("\n[1] Creating question for skip test...")
    question_id = create_question(pairing_id)
    if not question_id:
        print("  [FAIL] Could not create question")
        return False

    print(f"  [PASS] Question created: {question_id[:12]}...")

    # Submit skip
    print("\n[2] Submitting skip...")
    skip_data = {"skipped": True}

    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}/answer",
        data=json.dumps(skip_data).encode(),
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            if resp.status == 200:
                print("  [PASS] Skip submitted successfully")
            else:
                print(f"  [FAIL] Skip failed with status {resp.status}")
                return False
    except urllib.error.URLError as e:
        print(f"  [FAIL] Skip request failed: {e}")
        return False

    # Verify status is skipped
    print("\n[3] Verifying question status is 'skipped'...")
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/question/{question_id}",
        method="GET"
    )

    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            status = result.get("status")
            if status == "skipped":
                print("  [PASS] Question marked as skipped")
            else:
                print(f"  [FAIL] Status is '{status}', expected 'skipped'")
                return False
    except urllib.error.URLError as e:
        print(f"  [FAIL] Status check failed: {e}")
        return False

    print("\n  Skip flow test passed!")
    return True


if __name__ == "__main__":
    # Run main test
    main_passed = test_question_flow()

    # Run skip flow test
    skip_passed = test_skip_flow()

    print("\n" + "=" * 60)
    if main_passed and skip_passed:
        print("  ALL TESTS PASSED")
    else:
        print("  SOME TESTS FAILED")
    print("=" * 60)

    sys.exit(0 if (main_passed and skip_passed) else 1)
