#!/usr/bin/env python3
"""
PostToolUse Hook: Acceptance Criteria Validator (Language-Agnostic)

Fires after Write|Edit to verify acceptance criteria.
Uses FILE-BASED criteria passing (env vars don't persist between commands).

Configuration is read from .claude/acceptance-criteria.json which defines:
- file_extensions: Which file types to validate
- build_command: How to build the project
- lint_command: How to lint files

Exit codes:
  0 - Success (non-blocking)
  2 - Blocking error with feedback via stderr

Input (stdin JSON):
  - tool_name: "Write" | "Edit"
  - tool_input: { file_path: string, ... }
  - stop_hook_active: boolean (for loop prevention)

Criteria sources (in priority order):
  1. .claude/tasks/{task_id}/criteria.json (task-specific)
  2. .claude/current-task-criteria.json (active task)
  3. .claude/acceptance-criteria.json (project defaults)
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from datetime import datetime
from typing import Any


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

    tool_input = hook_input.get("tool_input", {})
    file_path = tool_input.get("file_path", "")

    if not file_path:
        sys.exit(0)

    # Load criteria and check if this file type should be validated
    criteria = load_criteria(project_dir)

    if not criteria:
        sys.exit(0)

    # Get file extensions to validate (configurable)
    file_extensions = criteria.get("file_extensions", [".swift"])
    if isinstance(file_extensions, str):
        file_extensions = [file_extensions]

    # Check if file matches any configured extension
    file_ext = Path(file_path).suffix.lower()
    if file_ext not in file_extensions and not any(file_path.endswith(ext) for ext in file_extensions):
        sys.exit(0)

    # Check attempt tracking
    attempts_file = Path(project_dir) / ".claude" / "hook-state" / "attempts.json"
    attempts = load_attempts(attempts_file)

    file_key = str(Path(file_path).resolve())
    current_attempts = attempts.get(file_key, 0)
    max_attempts = criteria.get("max_attempts", 4)

    if current_attempts >= max_attempts:
        print(f"⚠️ Max attempts ({max_attempts}) reached for {Path(file_path).name}. Proceeding.", file=sys.stderr)
        attempts[file_key] = 0
        save_attempts(attempts_file, attempts)
        sys.exit(0)

    # Run verification
    errors = verify_criteria(project_dir, file_path, criteria)

    if errors:
        attempts[file_key] = current_attempts + 1
        save_attempts(attempts_file, attempts)

        remaining = max_attempts - attempts[file_key]
        feedback = build_feedback(file_path, errors, attempts[file_key], remaining)

        output = {
            "decision": "block",
            "reason": feedback
        }
        print(json.dumps(output))
        sys.exit(0)

    # All criteria passed
    attempts[file_key] = 0
    save_attempts(attempts_file, attempts)

    print(f"✅ All criteria passed for {Path(file_path).name}", file=sys.stderr)
    sys.exit(0)


def load_criteria(project_dir: str) -> dict[str, Any]:
    """
    Load acceptance criteria from files (NOT env vars).
    """
    project_path = Path(project_dir)

    # Check for task-specific criteria
    active_task_file = project_path / ".claude" / "active-task-id.txt"
    if active_task_file.exists():
        task_id = active_task_file.read_text().strip()
        task_criteria = project_path / ".claude" / "tasks" / task_id / "criteria.json"
        if task_criteria.exists():
            try:
                return json.loads(task_criteria.read_text())
            except json.JSONDecodeError:
                pass

    # Check for current task criteria
    current_task = project_path / ".claude" / "current-task-criteria.json"
    if current_task.exists():
        try:
            return json.loads(current_task.read_text())
        except json.JSONDecodeError:
            pass

    # Fall back to project-level defaults
    project_criteria = project_path / ".claude" / "acceptance-criteria.json"
    if project_criteria.exists():
        try:
            return json.loads(project_criteria.read_text())
        except json.JSONDecodeError:
            pass

    return {}


def load_attempts(attempts_file: Path) -> dict[str, int]:
    """Load attempt tracking from file."""
    if attempts_file.exists():
        try:
            return json.loads(attempts_file.read_text())
        except json.JSONDecodeError:
            pass
    return {}


def save_attempts(attempts_file: Path, attempts: dict[str, int]):
    """Save attempt tracking to file."""
    attempts_file.parent.mkdir(parents=True, exist_ok=True)
    attempts_file.write_text(json.dumps(attempts, indent=2))


def verify_criteria(project_dir: str, file_path: str, criteria: dict) -> list[str]:
    """
    Verify file against acceptance criteria.
    Returns list of error messages (empty if all pass).

    LIGHTWEIGHT checks only - build verification is in SubagentStop.
    """
    errors = []

    try:
        full_path = Path(project_dir) / file_path if not Path(file_path).is_absolute() else Path(file_path)
        if not full_path.exists():
            return []
        content = full_path.read_text()
    except Exception as e:
        return [f"Could not read file: {e}"]

    checks = criteria.get("checks", [])

    for check in checks:
        check_type = check.get("type", check.get("check", ""))

        # Skip build/test checks - those are for SubagentStop
        if check_type in ("build", "test"):
            continue

        if check_type == "no_force_unwrap":
            # Swift-specific: force unwrapping
            if re.search(r'[^?]!\s*$|[^?]!\.', content, re.MULTILINE):
                errors.append("❌ Force unwrapping detected. Use optional binding or nil coalescing.")

        elif check_type == "not_contains":
            text = check.get("text", "")
            if text and text in content:
                errors.append(f"❌ File should not contain: '{text}'")

        elif check_type == "contains":
            text = check.get("text", "")
            if text and text not in content:
                errors.append(f"❌ File should contain: '{text}'")

        elif check_type == "pattern_absent":
            pattern = check.get("pattern", "")
            if pattern and re.search(pattern, content):
                message = check.get("message", f"Pattern found: {pattern}")
                errors.append(f"❌ {message}")

        elif check_type == "pattern_present":
            pattern = check.get("pattern", "")
            if pattern and not re.search(pattern, content):
                message = check.get("message", f"Required pattern not found: {pattern}")
                errors.append(f"❌ {message}")

        elif check_type == "lint":
            # Run configurable lint command
            lint_errors = run_lint(project_dir, file_path, criteria)
            errors.extend(lint_errors)

        elif check_type == "swiftlint":
            # Legacy: Swift-specific linting
            lint_errors = run_swiftlint(file_path)
            errors.extend(lint_errors)

        elif check_type == "eslint":
            # JS/TS linting
            lint_errors = run_eslint(file_path)
            errors.extend(lint_errors)

        elif check_type == "custom_command":
            # Run arbitrary command for validation
            cmd = check.get("command", "")
            if cmd:
                cmd_errors = run_custom_command(cmd, file_path)
                errors.extend(cmd_errors)

    return errors


def run_lint(project_dir: str, file_path: str, criteria: dict) -> list[str]:
    """Run configurable lint command."""
    lint_command = criteria.get("lint_command")
    if not lint_command:
        return []

    errors = []
    try:
        # Replace {file} placeholder with actual file path
        cmd = lint_command.replace("{file}", file_path)
        result = subprocess.run(
            cmd,
            shell=True,
            cwd=project_dir,
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode != 0 and result.stdout:
            for line in result.stdout.strip().split("\n")[:3]:
                if line.strip():
                    errors.append(f"❌ Lint: {line.strip()}")
    except Exception:
        pass
    return errors


def run_swiftlint(file_path: str) -> list[str]:
    """Run swiftlint on file."""
    errors = []
    try:
        result = subprocess.run(
            ["swiftlint", "lint", "--path", file_path, "--quiet"],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode != 0 and result.stdout:
            for line in result.stdout.strip().split("\n")[:3]:
                if line.strip():
                    errors.append(f"❌ SwiftLint: {line.strip()}")
    except FileNotFoundError:
        pass
    except Exception:
        pass
    return errors


def run_eslint(file_path: str) -> list[str]:
    """Run eslint on file."""
    errors = []
    try:
        result = subprocess.run(
            ["npx", "eslint", file_path, "--format", "compact"],
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode != 0 and result.stdout:
            for line in result.stdout.strip().split("\n")[:3]:
                if line.strip():
                    errors.append(f"❌ ESLint: {line.strip()}")
    except FileNotFoundError:
        pass
    except Exception:
        pass
    return errors


def run_custom_command(cmd: str, file_path: str) -> list[str]:
    """Run custom validation command."""
    errors = []
    try:
        cmd = cmd.replace("{file}", file_path)
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=30
        )
        if result.returncode != 0:
            output = result.stderr or result.stdout
            if output:
                errors.append(f"❌ {output.strip()[:200]}")
    except Exception as e:
        errors.append(f"❌ Command error: {e}")
    return errors


def build_feedback(file_path: str, errors: list[str], attempt: int, remaining: int) -> str:
    """Build feedback message for Claude."""
    feedback = [
        f"🔄 Acceptance criteria not met for {Path(file_path).name}",
        f"   Attempt {attempt}, {remaining} remaining before auto-proceed",
        "",
        "Issues found:",
    ]

    for error in errors:
        feedback.append(f"  {error}")

    feedback.extend([
        "",
        "Please fix these issues and try again.",
        "The hook will re-verify after your next edit."
    ])

    return "\n".join(feedback)


if __name__ == "__main__":
    main()
