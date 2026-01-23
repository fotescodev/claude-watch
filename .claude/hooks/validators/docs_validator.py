#!/usr/bin/env python3
"""
Specialized validator for documentation files.

Validates that markdown documents have required structure:
- Title (# heading)
- At least one section (## heading)
- No broken internal links

Usage:
    python docs_validator.py <file_path>
"""

import sys
import re
from pathlib import Path


def find_project_root() -> Path:
    """Find project root by looking for CLAUDE.md."""
    current = Path.cwd()
    for parent in [current] + list(current.parents):
        if (parent / "CLAUDE.md").exists():
            return parent
    return current


def validate_doc(file_path: str) -> tuple[bool, str]:
    """
    Validate a markdown document has required structure.

    Returns:
        (is_valid, message)
    """
    path = Path(file_path)

    if not path.exists():
        return False, f"File not found: {file_path}"

    if not path.suffix.lower() == ".md":
        return False, f"Not a markdown file: {file_path}"

    try:
        content = path.read_text()
    except Exception as e:
        return False, f"Cannot read file: {e}"

    lines = content.split("\n")

    # Check for title (# heading)
    has_title = False
    for line in lines:
        if line.startswith("# ") and not line.startswith("## "):
            has_title = True
            break

    if not has_title:
        return False, "Missing title: Document must start with # Title"

    # Check for at least one section (## heading)
    has_section = False
    for line in lines:
        if line.startswith("## "):
            has_section = True
            break

    if not has_section:
        return False, "Missing sections: Document must have at least one ## Section"

    # Check for broken internal links (optional but helpful)
    project_root = find_project_root()
    internal_links = re.findall(r'\[([^\]]+)\]\(([^)]+)\)', content)
    broken_links = []

    for link_text, link_path in internal_links:
        # Skip external links and anchors
        if link_path.startswith(("http://", "https://", "#", "mailto:")):
            continue

        # Resolve relative path
        if link_path.startswith("../"):
            resolved = (path.parent / link_path).resolve()
        elif link_path.startswith("./"):
            resolved = (path.parent / link_path[2:]).resolve()
        else:
            resolved = (path.parent / link_path).resolve()

        # Strip anchor from path
        resolved_str = str(resolved).split("#")[0]
        resolved = Path(resolved_str)

        if not resolved.exists():
            broken_links.append(f"{link_text} -> {link_path}")

    if broken_links:
        return False, f"Broken links: {', '.join(broken_links[:3])}"

    return True, f"Valid: {path.name} has title, sections, and valid links"


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: python docs_validator.py <file_path>")
        sys.exit(1)

    file_path = sys.argv[1]

    is_valid, message = validate_doc(file_path)
    print(message)
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
