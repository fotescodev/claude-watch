#!/usr/bin/env python3
"""
Specialized validator for Learnings Log entries.

Validates that new entries in the Learnings Log follow the format:
- ### YYYY-MM-DD: Brief title
- 1-3 bullet points
- Concise (each bullet < 100 chars)

Usage:
    python learning_validator.py <file_path>

Checks the Learnings Log section of ARCHITECTURE.md or similar docs.
"""

import sys
import re
from pathlib import Path
from datetime import datetime


def find_project_root() -> Path:
    """Find project root by looking for CLAUDE.md."""
    current = Path.cwd()
    for parent in [current] + list(current.parents):
        if (parent / "CLAUDE.md").exists():
            return parent
    return current


def validate_learnings(file_path: str) -> tuple[bool, str]:
    """
    Validate Learnings Log entries in a document.

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

    # Find Learnings Log section
    learnings_match = re.search(r'## Learnings Log\s*\n(.*?)(?=\n## |\n---|\Z)', content, re.DOTALL)

    if not learnings_match:
        return False, "No '## Learnings Log' section found"

    learnings_section = learnings_match.group(1)

    # Find all entries (### date: title)
    entries = re.findall(r'### (\d{4}-\d{2}-\d{2}): ([^\n]+)\n((?:- [^\n]+\n?)*)', learnings_section)

    if not entries:
        return False, "No entries found in Learnings Log (need '### YYYY-MM-DD: Title' format)"

    errors = []

    for date_str, title, bullets_block in entries:
        # Validate date format
        try:
            entry_date = datetime.strptime(date_str, "%Y-%m-%d")
            # Check date is not in the future
            if entry_date > datetime.now():
                errors.append(f"Future date: {date_str}")
        except ValueError:
            errors.append(f"Invalid date format: {date_str} (use YYYY-MM-DD)")

        # Validate title length
        if len(title) > 60:
            errors.append(f"Title too long ({len(title)} chars): '{title[:30]}...'")

        # Validate bullets
        bullets = [b.strip() for b in bullets_block.strip().split("\n") if b.strip().startswith("- ")]

        if len(bullets) == 0:
            errors.append(f"Entry '{date_str}' has no bullet points")
        elif len(bullets) > 3:
            errors.append(f"Entry '{date_str}' has too many bullets ({len(bullets)}, max 3)")

        for bullet in bullets:
            # Remove "- " prefix for length check
            bullet_text = bullet[2:] if bullet.startswith("- ") else bullet
            if len(bullet_text) > 100:
                errors.append(f"Bullet too long ({len(bullet_text)} chars): '{bullet_text[:30]}...'")

    if errors:
        return False, f"Invalid entries: {'; '.join(errors[:3])}"

    return True, f"Valid: {len(entries)} entries in Learnings Log"


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        # Default to ARCHITECTURE.md
        project_root = find_project_root()
        file_path = str(project_root / ".claude" / "ARCHITECTURE.md")
    else:
        file_path = sys.argv[1]

    is_valid, message = validate_learnings(file_path)
    print(message)
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
