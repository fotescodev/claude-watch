#!/usr/bin/env python3
"""
Specialized validator for ARCHITECTURE.md

Validates that the architecture document has all required sections.
Exit 1 with specific error if missing, exit 0 if valid.

Usage:
    python architecture_validator.py [file_path]

Defaults to .claude/ARCHITECTURE.md if no path provided.
"""

import sys
from pathlib import Path


REQUIRED_SECTIONS = [
    "## System Components",
    "## Data Flows",
    "## Before You Change Code",
    "## Critical Constraints",
    "## Learnings Log",
]

REQUIRED_CONTENT = [
    "Hook",
    "Cloud",
    "Watch",
    "CLAUDE_WATCH_SESSION_ACTIVE",
]


def find_project_root() -> Path:
    """Find project root by looking for CLAUDE.md."""
    current = Path.cwd()
    for parent in [current] + list(current.parents):
        if (parent / "CLAUDE.md").exists():
            return parent
    return current


def validate_architecture(file_path: str) -> tuple[bool, str]:
    """
    Validate ARCHITECTURE.md has required sections and content.

    Returns:
        (is_valid, message)
    """
    path = Path(file_path)

    if not path.exists():
        return False, f"File not found: {file_path}"

    try:
        content = path.read_text()
    except Exception as e:
        return False, f"Cannot read file: {e}"

    # Check required sections
    missing_sections = []
    for section in REQUIRED_SECTIONS:
        if section not in content:
            missing_sections.append(section)

    if missing_sections:
        return False, f"Missing sections: {', '.join(missing_sections)}"

    # Check required content
    missing_content = []
    for term in REQUIRED_CONTENT:
        if term not in content:
            missing_content.append(term)

    if missing_content:
        return False, f"Missing key terms: {', '.join(missing_content)}"

    # Check Learnings Log has at least one entry
    learnings_idx = content.find("## Learnings Log")
    if learnings_idx != -1:
        learnings_section = content[learnings_idx:]
        if "###" not in learnings_section:
            return False, "Learnings Log section has no entries (need ### date: title format)"

    return True, "Valid: All required sections and content present"


def main():
    """Main entry point."""
    # Determine file path
    if len(sys.argv) > 1:
        file_path = sys.argv[1]
    else:
        project_root = find_project_root()
        file_path = str(project_root / ".claude" / "ARCHITECTURE.md")

    # Validate
    is_valid, message = validate_architecture(file_path)

    # Output result
    print(message)

    # Exit code: 0 for valid, 1 for invalid
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
