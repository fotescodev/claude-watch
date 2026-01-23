#!/usr/bin/env python3
"""
Context Enforcer Hook for Claude Watch.

Runs on SessionStart to inject mandatory architecture context.
Ensures agents read ARCHITECTURE.md before proposing solutions.

This hook:
1. Reads ARCHITECTURE.md and extracts key constraints
2. Reads SESSION_STATE.md for current phase
3. Runs validators on core docs
4. Outputs mandatory context via additionalContext JSON

Usage in .claude/settings.json:
{
  "hooks": {
    "SessionStart": [{
      "hooks": [{
        "type": "command",
        "command": "python3 \"$CLAUDE_PROJECT_DIR/.claude/hooks/context-enforcer.py\""
      }]
    }]
  }
}
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path


def find_project_root() -> Path:
    """Find project root by looking for CLAUDE.md."""
    current = Path.cwd()
    for parent in [current] + list(current.parents):
        if (parent / "CLAUDE.md").exists():
            return parent
    return current


def extract_constraints(architecture_content: str) -> list[str]:
    """Extract Critical Constraints from ARCHITECTURE.md."""
    constraints = []

    # Find Critical Constraints section
    match = re.search(r'## Critical Constraints\s*\n(.*?)(?=\n## |\n---|\Z)', architecture_content, re.DOTALL)
    if match:
        section = match.group(1)
        # Extract bullet points
        for line in section.split('\n'):
            line = line.strip()
            if line.startswith('- '):
                constraints.append(line[2:])

    return constraints[:5]  # Max 5 constraints


def extract_current_phase(session_state_content: str) -> str:
    """Extract current phase from SESSION_STATE.md."""
    # Look for "## Current Phase" or similar
    match = re.search(r'##\s*Current Phase[:\s]*([^\n]+)', session_state_content, re.IGNORECASE)
    if match:
        return match.group(1).strip()

    # Try "Phase:" pattern
    match = re.search(r'Phase[:\s]+(\d+[^\n]*)', session_state_content, re.IGNORECASE)
    if match:
        return match.group(1).strip()

    return "Unknown"


def run_validator(validator_path: Path, file_path: Path) -> tuple[bool, str]:
    """Run a validator script and return (is_valid, message)."""
    if not validator_path.exists():
        return True, f"Validator not found: {validator_path.name}"

    try:
        result = subprocess.run(
            ["python3", str(validator_path), str(file_path)],
            capture_output=True,
            text=True,
            timeout=5
        )
        return result.returncode == 0, result.stdout.strip() or result.stderr.strip()
    except subprocess.TimeoutExpired:
        return False, "Validator timed out"
    except Exception as e:
        return False, f"Validator error: {e}"


def main():
    """Main entry point."""
    project_root = find_project_root()

    # Read ARCHITECTURE.md
    arch_file = project_root / ".claude" / "ARCHITECTURE.md"
    arch_content = ""
    constraints = []

    if arch_file.exists():
        try:
            arch_content = arch_file.read_text()
            constraints = extract_constraints(arch_content)
        except Exception:
            pass

    # Read SESSION_STATE.md
    session_file = project_root / ".claude" / "state" / "SESSION_STATE.md"
    current_phase = "Unknown"

    if session_file.exists():
        try:
            session_content = session_file.read_text()
            current_phase = extract_current_phase(session_content)
        except Exception:
            pass

    # Check watch mode
    watch_active = os.environ.get("CLAUDE_WATCH_SESSION_ACTIVE") == "1"

    # Run validators
    validators_dir = project_root / ".claude" / "hooks" / "validators"
    validation_errors = []

    if validators_dir.exists() and arch_file.exists():
        arch_validator = validators_dir / "architecture_validator.py"
        is_valid, message = run_validator(arch_validator, arch_file)
        if not is_valid:
            validation_errors.append(f"ARCHITECTURE.md: {message}")

    # Build mandatory context message
    lines = [
        "=" * 70,
        "               CLAUDE WATCH - MANDATORY CONTEXT",
        "=" * 70,
        "",
        "BEFORE PROPOSING ANY SOLUTION, ACKNOWLEDGE:",
        "",
        "[ ] I have read .claude/ARCHITECTURE.md (system skeleton)",
        "[ ] I understand: Hook -> Cloud -> Watch (no direct communication)",
        "[ ] I know which component I'm modifying (Hook/Cloud/Watch/CLI)",
        "[ ] I have traced the data flow in DATA_FLOW.md",
        "",
    ]

    # Add current state
    lines.extend([
        "CURRENT STATE:",
        f"- Phase: {current_phase}",
        f"- Watch Mode: {'ACTIVE' if watch_active else 'inactive'}",
        "",
    ])

    # Add constraints
    if constraints:
        lines.append("CRITICAL CONSTRAINTS:")
        for c in constraints:
            lines.append(f"- {c}")
        lines.append("")

    # Add validation errors
    if validation_errors:
        lines.extend([
            "!!! VALIDATION ERRORS - FIX BEFORE PROCEEDING !!!",
        ])
        for err in validation_errors:
            lines.append(f"- {err}")
        lines.append("")

    # Add reading order reminder
    lines.extend([
        "READING ORDER:",
        "1. .claude/ARCHITECTURE.md - System skeleton (READ FIRST)",
        "2. .claude/state/SESSION_STATE.md - Current phase context",
        "3. .claude/AGENT_GUIDE.md - Task-specific reading order",
        "",
        "If you are about to propose a solution without understanding",
        "the architecture, STOP and read .claude/ARCHITECTURE.md first.",
        "",
        "=" * 70,
    ])

    # Output as additionalContext JSON
    output = {
        "additionalContext": "\n".join(lines)
    }

    print(json.dumps(output))
    sys.exit(0)


if __name__ == "__main__":
    main()
