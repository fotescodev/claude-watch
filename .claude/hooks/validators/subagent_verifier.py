#!/usr/bin/env python3
"""
SubagentStop Hook: Subagent Task Verifier (Language-Agnostic)

Fires when a subagent completes to verify the task was successful.
Uses agent_transcript_path to identify which task the agent was working on.

Configuration is read from .claude/acceptance-criteria.json which defines:
- build_command: How to build the project (e.g., "xcodebuild ...", "npm run build", "cargo build")
- test_command: How to run tests

CRITICAL NOTES:
- Parallel subagents share session_id, so we MUST use agent_id/agent_transcript_path
- Check stop_hook_active to prevent infinite loops
- This hook runs FULL verification (including build) since it only fires once per task

Exit codes:
  0 - Success (non-blocking)
  2 - Blocking error with feedback via stderr

Input (stdin JSON):
  - session_id: string (shared across parallel agents)
  - agent_id: string (unique per agent)
  - agent_transcript_path: string (path to agent's transcript)
  - stop_hook_active: boolean (for loop prevention)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from datetime import datetime
from typing import Any, Optional


def main():
    # Read hook input from stdin
    try:
        hook_input = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    # CRITICAL: Prevent infinite loops
    if hook_input.get("stop_hook_active"):
        sys.exit(0)

    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")

    # Get agent identification fields
    agent_id = hook_input.get("agent_id")
    transcript_path = hook_input.get("agent_transcript_path")

    if not transcript_path:
        sys.exit(0)

    # Extract task ID from transcript
    task_id = extract_task_id_from_transcript(transcript_path)

    if not task_id:
        # No task ID marker - this might be a built-in subagent (Explore, etc.)
        sys.exit(0)

    # Load project config and task-specific criteria (merged)
    config = load_project_config(project_dir)
    criteria = load_task_criteria(project_dir, task_id, config)

    if not criteria.get("checks"):
        sys.exit(0)

    # Run FULL verification (including build if specified)
    errors = verify_full_criteria(project_dir, task_id, criteria, config, transcript_path)

    if errors:
        # Check retry attempts
        attempts = get_task_attempts(project_dir, task_id)
        max_attempts = criteria.get("max_attempts", 4)

        if attempts >= max_attempts:
            update_task_status(project_dir, task_id, "completed_with_warnings", errors)
            print(f"⚠️ Task {task_id} completed with {len(errors)} unresolved issues after {attempts} attempts.", file=sys.stderr)
            sys.exit(0)

        # Increment attempts and force continuation
        increment_task_attempts(project_dir, task_id)

        feedback = build_continuation_feedback(task_id, errors, attempts + 1, max_attempts)

        output = {
            "decision": "block",
            "reason": feedback
        }
        print(json.dumps(output))
        sys.exit(0)

    # All criteria passed
    update_task_status(project_dir, task_id, "completed_successfully", [])
    reset_task_attempts(project_dir, task_id)

    # Extract and save any discovered bugs/issues from the transcript
    discovered_bugs = extract_discovered_bugs(transcript_path, task_id)
    if discovered_bugs:
        save_discovered_bugs(project_dir, discovered_bugs)
        print(f"📋 Found {len(discovered_bugs)} adjacent issue(s) logged for later triage.", file=sys.stderr)

    print(f"✅ Task {task_id} completed successfully - all criteria verified.", file=sys.stderr)
    sys.exit(0)


def extract_task_id_from_transcript(transcript_path: str) -> Optional[str]:
    """
    Extract TASK_ID marker from agent transcript.

    The orchestrator should include this in the subagent prompt:
    TASK_ID: fix-overflow-001
    """
    try:
        transcript = Path(transcript_path).read_text()

        # Look for TASK_ID marker
        match = re.search(r'TASK_ID:\s*(\S+)', transcript)
        if match:
            return match.group(1)

        # Alternative: JSON format
        match = re.search(r'"task_id"\s*:\s*"([^"]+)"', transcript)
        if match:
            return match.group(1)

    except Exception:
        pass

    return None


def load_project_config(project_dir: str) -> dict[str, Any]:
    """Load project-level configuration."""
    config_file = Path(project_dir) / ".claude" / "acceptance-criteria.json"
    if config_file.exists():
        try:
            return json.loads(config_file.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def load_task_criteria(project_dir: str, task_id: str, config: dict) -> dict[str, Any]:
    """
    Load criteria for a specific task, merging with project config.

    Task-specific values override project defaults, but build_command/test_command
    flow through from config if not specified in task.
    """
    criteria_file = Path(project_dir) / ".claude" / "tasks" / task_id / "criteria.json"

    if criteria_file.exists():
        try:
            task_criteria = json.loads(criteria_file.read_text())
            # Merge: config provides defaults, task_criteria overrides
            merged = {**config, **task_criteria}
            # Preserve checks from task criteria (don't merge arrays)
            merged["checks"] = task_criteria.get("checks", config.get("checks", []))
            return merged
        except json.JSONDecodeError:
            pass

    # Fall back to project-level criteria
    return config


def verify_full_criteria(
    project_dir: str,
    task_id: str,
    criteria: dict,
    config: dict,
    transcript_path: str
) -> list[str]:
    """
    Run FULL verification including build.
    This is appropriate here because SubagentStop only fires once per task.

    Args:
        criteria: Merged task + config criteria
        config: Project-level config (for fallback commands)
    """
    errors = []

    checks = criteria.get("checks", [])

    for check in checks:
        check_type = check.get("type", check.get("check", ""))

        if check_type == "build":
            build_errors = run_build_verification(project_dir, criteria, config, check)
            errors.extend(build_errors)

        elif check_type == "test":
            test_errors = run_test_verification(project_dir, criteria, config, check)
            errors.extend(test_errors)

        elif check_type == "custom":
            cmd = check.get("command", "")
            if cmd:
                custom_errors = run_custom_command(project_dir, cmd, check)
                errors.extend(custom_errors)

        elif check_type == "transcript_contains":
            text = check.get("text", "")
            if text:
                try:
                    transcript = Path(transcript_path).read_text()
                    if text not in transcript:
                        errors.append(f"❌ Expected '{text}' in agent output")
                except Exception:
                    pass

        elif check_type == "transcript_not_contains":
            text = check.get("text", "")
            if text:
                try:
                    transcript = Path(transcript_path).read_text()
                    if text in transcript:
                        errors.append(f"❌ Found '{text}' in agent output (indicates failure)")
                except Exception:
                    pass

        elif check_type == "files_modified":
            expected_files = check.get("files", [])
            modified = extract_modified_files_from_transcript(transcript_path)
            for expected in expected_files:
                if not any(expected in f for f in modified):
                    errors.append(f"❌ Expected file not modified: {expected}")

    return errors


def run_custom_command(project_dir: str, cmd: str, check: dict) -> list[str]:
    """Run a custom verification command."""
    errors = []
    timeout = check.get("timeout", 120)

    try:
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=timeout
        )

        if result.returncode != 0:
            message = check.get("message", "Custom check failed")
            errors.append(f"❌ {message}")
    except subprocess.TimeoutExpired:
        errors.append(f"❌ Command timed out after {timeout}s")
    except Exception as e:
        errors.append(f"❌ Command error: {e}")

    return errors


def run_build_verification(project_dir: str, criteria: dict, config: dict, check: dict) -> list[str]:
    """Run configurable build verification."""
    errors = []

    # Get build command: check > criteria > config
    build_command = check.get("command") or criteria.get("build_command") or config.get("build_command")

    if not build_command:
        # Default to xcodebuild for Swift projects
        scheme = check.get("scheme", "")
        destination = check.get("destination", "platform=iOS Simulator,name=iPhone 15")

        cmd = ["xcodebuild"]
        if scheme:
            cmd.extend(["-scheme", scheme])
        cmd.extend(["-destination", destination, "-quiet", "build"])
    else:
        # Use configurable build command
        cmd = build_command

    # Configurable timeout (check > criteria > config > default 300s)
    timeout = check.get("timeout") or criteria.get("build_timeout") or config.get("build_timeout") or 300

    try:
        if isinstance(cmd, str):
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )
        else:
            result = subprocess.run(
                cmd,
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )

        if result.returncode != 0:
            error_lines = []
            for line in (result.stderr or result.stdout).split("\n"):
                if "error:" in line.lower() or "Error:" in line:
                    error_lines.append(line.strip())

            if error_lines:
                errors.append("❌ Build failed:")
                for line in error_lines[:5]:
                    errors.append(f"   {line}")
            else:
                errors.append("❌ Build failed (check build output)")

    except subprocess.TimeoutExpired:
        errors.append(f"❌ Build timed out after {timeout}s")
    except FileNotFoundError as e:
        errors.append(f"❌ Build command not found: {e}")
    except Exception as e:
        errors.append(f"❌ Build error: {e}")

    return errors


def run_test_verification(project_dir: str, criteria: dict, config: dict, check: dict) -> list[str]:
    """Run configurable test verification."""
    errors = []

    # Get test command: check > criteria > config
    test_command = check.get("command") or criteria.get("test_command") or config.get("test_command")

    if not test_command:
        # Default to xcodebuild test for Swift projects
        scheme = check.get("scheme", "")
        test_plan = check.get("test_plan", "")

        cmd = ["xcodebuild", "test"]
        if scheme:
            cmd.extend(["-scheme", scheme])
        if test_plan:
            cmd.extend(["-testPlan", test_plan])
        cmd.extend(["-quiet"])
    else:
        cmd = test_command

    # Configurable timeout (check > criteria > config > default 600s)
    timeout = check.get("timeout") or criteria.get("test_timeout") or config.get("test_timeout") or 600

    try:
        if isinstance(cmd, str):
            result = subprocess.run(
                cmd,
                shell=True,
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )
        else:
            result = subprocess.run(
                cmd,
                cwd=project_dir,
                capture_output=True,
                text=True,
                timeout=timeout
            )

        if result.returncode != 0:
            errors.append("❌ Tests failed (check test output for details)")
            # Extract test failure details
            output = result.stderr or result.stdout
            for line in output.split("\n")[-10:]:
                if line.strip():
                    errors.append(f"   {line.strip()}")

    except subprocess.TimeoutExpired:
        errors.append(f"❌ Tests timed out after {timeout}s")
    except Exception as e:
        errors.append(f"❌ Test error: {e}")

    return errors


def extract_modified_files_from_transcript(transcript_path: str) -> list[str]:
    """Extract list of modified files from agent transcript."""
    files = []
    try:
        transcript = Path(transcript_path).read_text()

        for match in re.finditer(r'"file_path"\s*:\s*"([^"]+)"', transcript):
            files.append(match.group(1))

    except Exception:
        pass

    return files


def get_task_attempts(project_dir: str, task_id: str) -> int:
    """Get current attempt count for a task."""
    attempts_file = Path(project_dir) / ".claude" / "tasks" / task_id / "attempts.json"
    if attempts_file.exists():
        try:
            data = json.loads(attempts_file.read_text())
            return data.get("attempts", 0)
        except Exception:
            pass
    return 0


def increment_task_attempts(project_dir: str, task_id: str):
    """Increment attempt count for a task."""
    attempts_file = Path(project_dir) / ".claude" / "tasks" / task_id / "attempts.json"
    attempts_file.parent.mkdir(parents=True, exist_ok=True)

    current = get_task_attempts(project_dir, task_id)
    data = {
        "attempts": current + 1,
        "last_attempt": datetime.now().isoformat()
    }
    attempts_file.write_text(json.dumps(data, indent=2))


def reset_task_attempts(project_dir: str, task_id: str):
    """Reset attempt count for a task."""
    attempts_file = Path(project_dir) / ".claude" / "tasks" / task_id / "attempts.json"
    if attempts_file.exists():
        attempts_file.unlink()


def update_task_status(project_dir: str, task_id: str, status: str, issues: list[str]):
    """Update task status file."""
    status_file = Path(project_dir) / ".claude" / "tasks" / task_id / "status.json"
    status_file.parent.mkdir(parents=True, exist_ok=True)

    data = {
        "status": status,
        "completed_at": datetime.now().isoformat(),
        "issues": issues
    }
    status_file.write_text(json.dumps(data, indent=2))


def extract_discovered_bugs(transcript_path: str, source_task: str) -> list[dict]:
    """
    Extract discovered bugs/issues from agent transcript.

    Agents should report discovered issues using markers like:
    - DISCOVERED_BUG: [P1|P2|P3] description
    - FOUND_ISSUE: [priority] description
    - ADJACENT_BUG: description

    Returns list of bug dictionaries with priority, description, source.
    """
    bugs = []
    try:
        transcript = Path(transcript_path).read_text()

        # Pattern: DISCOVERED_BUG: [P1] Some description
        for match in re.finditer(
            r'(?:DISCOVERED_BUG|FOUND_ISSUE|ADJACENT_BUG|NOTE_FOR_LATER):\s*(?:\[?(P[0-3])\]?)?\s*(.+?)(?:\n|$)',
            transcript,
            re.IGNORECASE
        ):
            priority = match.group(1).upper() if match.group(1) else "P2"
            description = match.group(2).strip()

            if description and len(description) > 5:
                bugs.append({
                    "priority": priority,
                    "description": description,
                    "source_task": source_task,
                    "discovered_at": datetime.now().isoformat(),
                    "status": "pending"
                })

        # Also look for TODO/FIXME comments the agent noticed but couldn't fix
        for match in re.finditer(
            r'(?:noticed|found|spotted|saw)\s+(?:a\s+)?(?:TODO|FIXME|BUG)(?:\s+in\s+|\s*:\s*)([^\n]+)',
            transcript,
            re.IGNORECASE
        ):
            description = match.group(1).strip()
            if description and len(description) > 5:
                bugs.append({
                    "priority": "P3",
                    "description": f"Code comment: {description}",
                    "source_task": source_task,
                    "discovered_at": datetime.now().isoformat(),
                    "status": "pending"
                })

    except Exception:
        pass

    # Deduplicate by description
    seen = set()
    unique_bugs = []
    for bug in bugs:
        key = bug["description"].lower()[:50]
        if key not in seen:
            seen.add(key)
            unique_bugs.append(bug)

    return unique_bugs


def save_discovered_bugs(project_dir: str, bugs: list[dict]):
    """
    Save discovered bugs to the backlog for later triage.

    Bugs are appended to .claude/discovered-bugs.json
    """
    bugs_file = Path(project_dir) / ".claude" / "discovered-bugs.json"
    bugs_file.parent.mkdir(parents=True, exist_ok=True)

    existing_bugs = []
    if bugs_file.exists():
        try:
            existing_bugs = json.loads(bugs_file.read_text())
        except json.JSONDecodeError:
            existing_bugs = []

    # Append new bugs
    existing_bugs.extend(bugs)

    # Sort by priority (P0 first, then P1, P2, P3)
    priority_order = {"P0": 0, "P1": 1, "P2": 2, "P3": 3}
    existing_bugs.sort(key=lambda b: priority_order.get(b.get("priority", "P2"), 2))

    bugs_file.write_text(json.dumps(existing_bugs, indent=2))


def build_continuation_feedback(
    task_id: str,
    errors: list[str],
    attempt: int,
    max_attempts: int
) -> str:
    """Build feedback message to force agent continuation."""
    remaining = max_attempts - attempt

    feedback = [
        f"🔄 Task {task_id} verification failed",
        f"   Attempt {attempt}/{max_attempts}, {remaining} remaining",
        "",
        "Issues found:",
    ]

    for error in errors:
        feedback.append(f"  {error}")

    feedback.extend([
        "",
        "Please address these issues and continue working.",
        "The task is not complete until all criteria pass."
    ])

    return "\n".join(feedback)


if __name__ == "__main__":
    main()
