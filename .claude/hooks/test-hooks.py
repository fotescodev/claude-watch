#!/usr/bin/env python3
"""
Hook validation tests for Claude Watch.

Run before deploying to ensure all hooks are properly configured:
    python3 .claude/hooks/test-hooks.py

Checks:
1. All hook files exist and have valid Python syntax
2. settings.json matchers include all required tools
3. Hook handlers match their declared tools
4. Cloud endpoints exist for hook operations
"""
import json
import os
import sys
import urllib.request
import urllib.error

# Colors for output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
SETTINGS_PATH = os.path.join(PROJECT_DIR, ".claude", "settings.json")
CLOUD_URL = "https://claude-watch.fotescodev.workers.dev"

# Expected hook configuration
EXPECTED_HOOKS = {
    "PreToolUse": {
        "file": "watch-approval-cloud.py",
        "required_matchers": ["Bash", "Write", "Edit", "MultiEdit", "AskUserQuestion"],
        "handles_tools": {
            "Bash": "approval",
            "Write": "approval",
            "Edit": "approval",
            "MultiEdit": "approval",
            "AskUserQuestion": "question",
        }
    },
    "PostToolUse": {
        "file": "progress-tracker.py",
        "required_matchers": ["TodoWrite"],
        "handles_tools": {
            "TodoWrite": "progress",
        }
    }
}

# Cloud endpoints that must exist
REQUIRED_ENDPOINTS = [
    # Health
    ("GET", "/health"),
    # Approval flow
    ("POST", "/approval"),
    ("POST", "/approval/{requestId}"),
    ("GET", "/approval/{pairingId}/{requestId}"),
    ("GET", "/approval-queue/{pairingId}"),
    ("DELETE", "/approval-queue/{pairingId}"),
    # Question flow
    ("POST", "/question"),
    ("GET", "/question/{id}"),
    ("POST", "/question/{id}/answer"),
    ("GET", "/questions/{pairingId}"),
    # Session progress
    ("POST", "/session-progress"),
    ("GET", "/session-progress/{pairingId}"),
    # Session control
    ("POST", "/session-end"),
    ("GET", "/session-status/{pairingId}"),
    ("POST", "/session-interrupt"),
    ("GET", "/session-interrupt/{pairingId}"),
]

# Question flow end-to-end test data
QUESTION_E2E_TEST = {
    "pairingId": "test-e2e-pairing",
    "question": "Test question?",
    "header": "Test",
    "options": [
        {"label": "Option A", "description": "First option"},
        {"label": "Option B", "description": "Second option"}
    ],
    "multiSelect": False
}


def print_result(name: str, passed: bool, details: str = ""):
    status = f"{GREEN}✓ PASS{RESET}" if passed else f"{RED}✗ FAIL{RESET}"
    print(f"  {status}: {name}")
    if details and not passed:
        print(f"         {YELLOW}{details}{RESET}")


def check_file_exists(filepath: str) -> bool:
    return os.path.isfile(filepath)


def check_python_syntax(filepath: str) -> tuple[bool, str]:
    """Check if Python file has valid syntax."""
    import py_compile
    try:
        py_compile.compile(filepath, doraise=True)
        return True, ""
    except py_compile.PyCompileError as e:
        return False, str(e)


def check_hook_handles_tool(hook_file: str, tool_name: str, handler_type: str) -> tuple[bool, str]:
    """Check if hook file has code to handle the specified tool."""
    filepath = os.path.join(SCRIPT_DIR, hook_file)

    if not os.path.exists(filepath):
        return False, f"File not found: {hook_file}"

    with open(filepath, 'r') as f:
        content = f.read()

    # Check for tool handling based on type
    if handler_type == "approval":
        # Should have the tool in TOOLS_REQUIRING_APPROVAL
        if f'"{tool_name}"' in content or f"'{tool_name}'" in content:
            return True, ""
        return False, f"Tool '{tool_name}' not found in hook"

    elif handler_type == "question":
        # Should have QUESTION_TOOLS with AskUserQuestion
        if "QUESTION_TOOLS" in content and "AskUserQuestion" in content:
            return True, ""
        return False, "QUESTION_TOOLS or AskUserQuestion handler not found"

    elif handler_type == "progress":
        # Should handle TodoWrite
        if "TodoWrite" in content:
            return True, ""
        return False, "TodoWrite handler not found"

    return False, f"Unknown handler type: {handler_type}"


def check_settings_matcher(settings: dict, hook_type: str, required_tools: list) -> tuple[bool, list]:
    """Check if settings.json has all required tools in matcher."""
    hooks = settings.get("hooks", {}).get(hook_type, [])

    missing = []
    for tool in required_tools:
        found = False
        for hook_config in hooks:
            matcher = hook_config.get("matcher", "")
            if tool in matcher.split("|"):
                found = True
                break
        if not found:
            missing.append(tool)

    return len(missing) == 0, missing


def check_cloud_endpoint(method: str, path: str) -> tuple[bool, str]:
    """Check if cloud endpoint responds."""
    # Replace placeholders with test values
    test_path = path.replace("{id}", "test-id").replace("{pairingId}", "test-pairing").replace("{requestId}", "test-request")
    url = f"{CLOUD_URL}{test_path}"

    try:
        req = urllib.request.Request(url, method=method)
        if method in ["POST", "DELETE"]:
            req.add_header("Content-Type", "application/json")
            if method == "POST":
                req.data = b'{"test": true, "pairingId": "test-pairing", "action": "clear"}'

        with urllib.request.urlopen(req, timeout=5) as resp:
            # 200, 400, 404 are all valid responses (endpoint exists)
            return True, ""
    except urllib.error.HTTPError as e:
        # 400, 404 mean endpoint exists but params invalid - that's OK
        if e.code in [400, 404]:
            return True, ""
        return False, f"HTTP {e.code}"
    except urllib.error.URLError as e:
        return False, str(e.reason)
    except Exception as e:
        return False, str(e)


def test_question_e2e_flow() -> tuple[bool, str]:
    """
    End-to-end test for question flow:
    1. Create question
    2. Check status is 'pending'
    3. Submit answer
    4. Check status is 'answered' with correct selectedIndices
    """
    try:
        # Step 1: Create question
        req = urllib.request.Request(
            f"{CLOUD_URL}/question",
            data=json.dumps(QUESTION_E2E_TEST).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            question_id = result.get("questionId")
            if not question_id:
                return False, "No questionId returned"

        # Step 2: Check pending status
        req = urllib.request.Request(f"{CLOUD_URL}/question/{question_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("status") != "pending":
                return False, f"Expected 'pending', got '{result.get('status')}'"

        # Step 3: Submit answer
        answer_data = {"selectedIndices": [0]}
        req = urllib.request.Request(
            f"{CLOUD_URL}/question/{question_id}/answer",
            data=json.dumps(answer_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("success"):
                return False, "Answer submission failed"

        # Step 4: Check answered status
        req = urllib.request.Request(f"{CLOUD_URL}/question/{question_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("status") != "answered":
                return False, f"Expected 'answered', got '{result.get('status')}'"
            if result.get("selectedIndices") != [0]:
                return False, f"Expected [0], got {result.get('selectedIndices')}"

        return True, ""

    except Exception as e:
        return False, str(e)


def test_progress_e2e_flow() -> tuple[bool, str]:
    """
    End-to-end test for session progress flow:
    1. Post progress
    2. Verify progress is retrievable
    """
    try:
        progress_data = {
            "pairingId": "test-e2e-pairing",
            "currentTask": "Test task",
            "currentActivity": "Testing...",
            "progress": 0.5,
            "completedCount": 1,
            "totalCount": 2,
            "elapsedSeconds": 60,
            "tasks": [
                {"content": "Task 1", "status": "completed", "activeForm": None},
                {"content": "Task 2", "status": "in_progress", "activeForm": "Testing"}
            ]
        }

        # Post progress
        req = urllib.request.Request(
            f"{CLOUD_URL}/session-progress",
            data=json.dumps(progress_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("success"):
                return False, "Progress post failed"

        # Retrieve progress
        req = urllib.request.Request(f"{CLOUD_URL}/session-progress/test-e2e-pairing")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            progress = result.get("progress")
            if not progress:
                return False, "No progress returned"
            if progress.get("currentTask") != "Test task":
                return False, f"Expected 'Test task', got '{progress.get('currentTask')}'"

        return True, ""

    except Exception as e:
        return False, str(e)


def test_approval_e2e_flow() -> tuple[bool, str]:
    """
    End-to-end test for approval flow:
    1. Create approval request
    2. Verify it appears in queue
    3. Poll status (should be pending)
    4. Submit approval
    5. Poll status (should be approved)
    """
    import uuid
    try:
        pairing_id = "test-e2e-approval"
        request_id = str(uuid.uuid4())

        # Step 1: Create approval request
        approval_data = {
            "pairingId": pairing_id,
            "id": request_id,
            "type": "bash",
            "title": "E2E Test Command",
            "description": "echo test"
        }
        req = urllib.request.Request(
            f"{CLOUD_URL}/approval",
            data=json.dumps(approval_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("success"):
                return False, "Approval creation failed"

        # Step 2: Check queue
        req = urllib.request.Request(f"{CLOUD_URL}/approval-queue/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            requests = result.get("requests", [])
            if not any(r.get("id") == request_id for r in requests):
                return False, "Request not found in queue"

        # Step 3: Poll status (should be pending)
        req = urllib.request.Request(f"{CLOUD_URL}/approval/{pairing_id}/{request_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("status") != "pending":
                return False, f"Expected 'pending', got '{result.get('status')}'"

        # Step 4: Submit approval
        approve_data = {"pairingId": pairing_id, "approved": True}
        req = urllib.request.Request(
            f"{CLOUD_URL}/approval/{request_id}",
            data=json.dumps(approve_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("success"):
                return False, "Approval submission failed"

        # Step 5: Poll status (should be approved)
        req = urllib.request.Request(f"{CLOUD_URL}/approval/{pairing_id}/{request_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("status") != "approved":
                return False, f"Expected 'approved', got '{result.get('status')}'"

        return True, ""

    except Exception as e:
        return False, str(e)


def test_session_control_e2e_flow() -> tuple[bool, str]:
    """
    End-to-end test for session control flow:
    1. Check initial session status (should be active)
    2. Check interrupt state (should be not interrupted)
    3. Send stop interrupt
    4. Verify interrupt state is stopped
    5. Send resume interrupt
    6. Verify interrupt state is resumed
    7. End session
    8. Verify session is not active
    """
    try:
        pairing_id = "test-e2e-session-control"

        # Step 1: Check initial session status
        req = urllib.request.Request(f"{CLOUD_URL}/session-status/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            # First call may return True (no session state exists = active by default)
            if "sessionActive" not in result:
                return False, "sessionActive not in response"

        # Step 2: Check initial interrupt state
        req = urllib.request.Request(f"{CLOUD_URL}/session-interrupt/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("interrupted") is not False:
                return False, f"Expected interrupted=false, got {result.get('interrupted')}"

        # Step 3: Send stop interrupt
        stop_data = {"pairingId": pairing_id, "action": "stop"}
        req = urllib.request.Request(
            f"{CLOUD_URL}/session-interrupt",
            data=json.dumps(stop_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("interrupted"):
                return False, "Stop interrupt failed"

        # Step 4: Verify interrupt state
        req = urllib.request.Request(f"{CLOUD_URL}/session-interrupt/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("interrupted"):
                return False, "Interrupt state not persisted"
            if result.get("action") != "stop":
                return False, f"Expected action='stop', got '{result.get('action')}'"

        # Step 5: Send resume interrupt
        resume_data = {"pairingId": pairing_id, "action": "resume"}
        req = urllib.request.Request(
            f"{CLOUD_URL}/session-interrupt",
            data=json.dumps(resume_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("interrupted"):
                return False, "Resume interrupt failed"

        # Step 6: Verify resumed state
        req = urllib.request.Request(f"{CLOUD_URL}/session-interrupt/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("interrupted"):
                return False, "Resume state not persisted"

        # Step 7: End session
        end_data = {"pairingId": pairing_id}
        req = urllib.request.Request(
            f"{CLOUD_URL}/session-end",
            data=json.dumps(end_data).encode(),
            headers={"Content-Type": "application/json"},
            method="POST"
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if not result.get("success"):
                return False, "Session end failed"

        # Step 8: Verify session ended
        req = urllib.request.Request(f"{CLOUD_URL}/session-status/{pairing_id}")
        with urllib.request.urlopen(req, timeout=10) as resp:
            result = json.loads(resp.read())
            if result.get("sessionActive"):
                return False, "Session still active after end"

        return True, ""

    except Exception as e:
        return False, str(e)


def run_tests() -> bool:
    """Run all hook validation tests. Returns True if all pass."""
    all_passed = True

    print("\n" + "=" * 60)
    print("Claude Watch Hook Validation Tests")
    print("=" * 60)

    # Load settings
    print("\n1. Loading settings.json...")
    if not check_file_exists(SETTINGS_PATH):
        print_result("settings.json exists", False, f"Not found at {SETTINGS_PATH}")
        return False

    with open(SETTINGS_PATH, 'r') as f:
        settings = json.load(f)
    print_result("settings.json exists", True)

    # Check each hook type
    print("\n2. Checking hook files...")
    for hook_type, config in EXPECTED_HOOKS.items():
        hook_file = config["file"]
        filepath = os.path.join(SCRIPT_DIR, hook_file)

        # File exists
        exists = check_file_exists(filepath)
        print_result(f"{hook_file} exists", exists)
        if not exists:
            all_passed = False
            continue

        # Valid Python syntax
        valid, error = check_python_syntax(filepath)
        print_result(f"{hook_file} syntax valid", valid, error)
        if not valid:
            all_passed = False

    # Check settings matchers
    print("\n3. Checking settings.json matchers...")
    for hook_type, config in EXPECTED_HOOKS.items():
        required = config["required_matchers"]
        valid, missing = check_settings_matcher(settings, hook_type, required)
        print_result(
            f"{hook_type} matcher includes {required}",
            valid,
            f"Missing: {missing}" if missing else ""
        )
        if not valid:
            all_passed = False

    # Check hook handlers
    print("\n4. Checking hook handlers...")
    for hook_type, config in EXPECTED_HOOKS.items():
        hook_file = config["file"]
        for tool, handler_type in config["handles_tools"].items():
            valid, error = check_hook_handles_tool(hook_file, tool, handler_type)
            print_result(f"{hook_file} handles {tool}", valid, error)
            if not valid:
                all_passed = False

    # Check cloud endpoints
    print("\n5. Checking cloud endpoints...")
    for method, path in REQUIRED_ENDPOINTS:
        valid, error = check_cloud_endpoint(method, path)
        print_result(f"{method} {path}", valid, error)
        if not valid:
            all_passed = False

    # E2E Tests
    print("\n6. Running end-to-end flow tests...")

    valid, error = test_question_e2e_flow()
    print_result("Question flow (create → pending → answer → answered)", valid, error)
    if not valid:
        all_passed = False

    valid, error = test_progress_e2e_flow()
    print_result("Progress flow (post → retrieve)", valid, error)
    if not valid:
        all_passed = False

    valid, error = test_approval_e2e_flow()
    print_result("Approval flow (create → queue → poll → approve → verified)", valid, error)
    if not valid:
        all_passed = False

    valid, error = test_session_control_e2e_flow()
    print_result("Session control (status → interrupt → resume → end)", valid, error)
    if not valid:
        all_passed = False

    # Summary
    print("\n" + "=" * 60)
    if all_passed:
        print(f"{GREEN}All tests passed! Ready to deploy.{RESET}")
    else:
        print(f"{RED}Some tests failed. Fix issues before deploying.{RESET}")
    print("=" * 60 + "\n")

    return all_passed


if __name__ == "__main__":
    success = run_tests()
    sys.exit(0 if success else 1)
