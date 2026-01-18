#!/usr/bin/env python3
"""
Identify tasks that can run in parallel.
Uses simple regex parsing to avoid yaml dependency.
"""

import re
import json
from pathlib import Path

def parse_tasks_yaml():
    """Parse tasks.yaml with simple regex (no yaml module needed)."""
    tasks_file = Path(__file__).parent / "tasks.yaml"
    content = tasks_file.read_text()

    tasks = []
    current_task = None

    # Split into task blocks
    lines = content.split('\n')
    i = 0
    while i < len(lines):
        line = lines[i]

        # New task starts with "- id:"
        if re.match(r'\s*- id:\s*["\']?(\w+)', line):
            if current_task:
                tasks.append(current_task)
            task_id = re.search(r'id:\s*["\']?(\w+)', line).group(1)
            current_task = {"id": task_id, "depends_on": [], "files": [], "tags": []}

        elif current_task:
            # Parse task fields
            if match := re.match(r'\s+title:\s*["\']?(.+?)["\']?\s*$', line):
                current_task["title"] = match.group(1).strip('"\'')
            elif match := re.match(r'\s+priority:\s*(\w+)', line):
                current_task["priority"] = match.group(1)
            elif match := re.match(r'\s+parallel_group:\s*(\d+)', line):
                current_task["parallel_group"] = int(match.group(1))
            elif match := re.match(r'\s+completed:\s*(true|false)', line):
                current_task["completed"] = match.group(1) == "true"
            elif match := re.match(r'\s+blocked:\s*(true|false)', line):
                current_task["blocked"] = match.group(1) == "true"
            elif re.match(r'\s+depends_on:', line):
                # Read depends_on list
                i += 1
                while i < len(lines) and re.match(r'\s+- ["\']?(\w+)', lines[i]):
                    dep = re.search(r'- ["\']?(\w+)', lines[i]).group(1)
                    current_task["depends_on"].append(dep)
                    i += 1
                continue
            elif re.match(r'\s+files:', line):
                # Read files list
                i += 1
                while i < len(lines) and re.match(r'\s+- ', lines[i]):
                    i += 1
                continue
            elif re.match(r'\s+tags:', line):
                # Read tags list
                i += 1
                while i < len(lines) and re.match(r'\s+- ', lines[i]):
                    tag = re.search(r'- (.+)', lines[i]).group(1).strip()
                    current_task["tags"].append(tag)
                    i += 1
                continue

        i += 1

    if current_task:
        tasks.append(current_task)

    return tasks

def get_runnable_tasks(tasks):
    """Find all tasks that can run now (deps met, not completed)."""
    completed_ids = {t["id"] for t in tasks if t.get("completed", False)}

    runnable = []
    for task in tasks:
        if task.get("completed", False):
            continue
        if task.get("blocked", False):
            continue

        # Check dependencies
        deps = task.get("depends_on", [])
        if all(dep in completed_ids for dep in deps):
            runnable.append(task)

    return runnable

def group_by_parallel_group(tasks):
    """Group tasks by parallel_group."""
    groups = {}
    for task in tasks:
        pg = task.get("parallel_group", 99)
        if pg not in groups:
            groups[pg] = []
        groups[pg].append(task)
    return groups

def main():
    tasks = parse_tasks_yaml()
    runnable = get_runnable_tasks(tasks)

    if not runnable:
        print(json.dumps({"status": "all_complete", "tasks": [], "count": 0}))
        return

    # Group by parallel_group
    groups = group_by_parallel_group(runnable)

    # Get lowest parallel_group
    min_group = min(groups.keys())
    parallel_tasks = groups[min_group]

    # Sort by priority within group
    priority_order = {"critical": 0, "high": 1, "medium": 2, "low": 3}
    parallel_tasks.sort(key=lambda t: priority_order.get(t.get("priority", "low"), 3))

    # Categorize tasks by execution type
    verification_tasks = []
    build_tasks = []
    e2e_tasks = []

    for t in parallel_tasks:
        tags = t.get("tags", [])
        if "verification" in tags or "prd-alignment" in tags:
            verification_tasks.append(t)
        elif "e2e" in tags or "simulator" in tags:
            e2e_tasks.append(t)
        else:
            build_tasks.append(t)

    output = {
        "status": "ready",
        "parallel_group": min_group,
        "count": len(parallel_tasks),
        "can_parallel": len(verification_tasks),  # These can truly run in parallel
        "needs_build_lock": len(build_tasks),     # These need sequential builds
        "needs_simulator": len(e2e_tasks),        # These need exclusive simulator
        "tasks": [
            {
                "id": t["id"],
                "title": t.get("title", "Unknown"),
                "priority": t.get("priority", "medium"),
                "tags": t.get("tags", []),
                "execution_type": (
                    "verification" if "verification" in t.get("tags", []) or "prd-alignment" in t.get("tags", [])
                    else "e2e" if "e2e" in t.get("tags", []) or "simulator" in t.get("tags", [])
                    else "build"
                )
            }
            for t in parallel_tasks
        ]
    }

    print(json.dumps(output, indent=2))

if __name__ == "__main__":
    main()
