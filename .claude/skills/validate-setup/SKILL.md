# Validate Orchestrator Setup

This skill validates that the orchestrator hook system is correctly configured and ready for autonomous operation.

## When to Use

- After initial installation of orchestrator hooks
- When task verification isn't working as expected
- After modifying hook configuration
- Before starting a large orchestrated workflow

## Validation Steps

Execute each step in order. Stop at first failure and resolve before continuing.

### Step 1: Verify Directory Structure

```bash
echo "=== Directory Structure ==="
ls -la .claude/hooks/validators/ 2>/dev/null && echo "✅ validators/ exists" || echo "❌ MISSING: .claude/hooks/validators/"
ls -la .claude/tasks/ 2>/dev/null && echo "✅ tasks/ exists" || echo "⚠️ tasks/ not yet created (OK for new setup)"
ls -la .claude/hook-state/ 2>/dev/null && echo "✅ hook-state/ exists" || echo "⚠️ hook-state/ not yet created (auto-created on first run)"
```

### Step 2: Verify Hook Files

```bash
echo "=== Hook Files ==="
test -f .claude/hooks/validators/acceptance_criteria.py && echo "✅ acceptance_criteria.py" || echo "❌ MISSING: acceptance_criteria.py"
test -f .claude/hooks/validators/subagent_verifier.py && echo "✅ subagent_verifier.py" || echo "❌ MISSING: subagent_verifier.py"
python3 --version 2>/dev/null && echo "✅ Python3 available" || echo "❌ MISSING: Python3"
```

### Step 3: Verify Configuration

```bash
echo "=== Configuration ==="
python3 << 'EOF'
import json
from pathlib import Path

config_file = Path(".claude/acceptance-criteria.json")
if not config_file.exists():
    print("❌ MISSING: acceptance-criteria.json")
    exit(1)

try:
    config = json.load(open(config_file))
    print("✅ Valid JSON")
    print(f"   File extensions: {config.get('file_extensions', 'NOT SET')}")
    print(f"   Build command: {'SET' if config.get('build_command') else 'NOT SET'}")
    print(f"   Test command: {'SET' if config.get('test_command') else 'NOT SET'}")
    print(f"   Lint command: {'SET' if config.get('lint_command') else 'NOT SET'}")
    print(f"   Max attempts: {config.get('max_attempts', 'NOT SET')}")
    print(f"   Build timeout: {config.get('build_timeout', 'NOT SET')}")
    print(f"   Checks defined: {len(config.get('checks', []))}")
except json.JSONDecodeError as e:
    print(f"❌ INVALID JSON: {e}")
EOF
```

### Step 4: Verify Settings Registration

```bash
echo "=== Hook Registration ==="
python3 << 'EOF'
import json
from pathlib import Path

settings_file = Path(".claude/settings.json")
if not settings_file.exists():
    print("❌ MISSING: settings.json")
    exit(1)

try:
    settings = json.load(open(settings_file))
    hooks = settings.get("hooks", {})

    # Check PostToolUse
    post_tool = hooks.get("PostToolUse", [])
    has_acceptance = any("acceptance_criteria" in str(h) for h in post_tool)
    if has_acceptance:
        print("✅ PostToolUse: acceptance_criteria.py registered")
        # Check matcher includes MultiEdit
        for h in post_tool:
            matcher = h.get("matcher", "")
            if "acceptance_criteria" in str(h.get("hooks", [])):
                if "MultiEdit" in matcher:
                    print("   ✅ Matcher includes MultiEdit")
                else:
                    print("   ⚠️ Matcher missing MultiEdit (bulk edits may bypass)")
    else:
        print("❌ PostToolUse: acceptance_criteria.py NOT registered")

    # Check SubagentStop
    subagent = hooks.get("SubagentStop", [])
    has_verifier = any("subagent_verifier" in str(h) for h in subagent)
    if has_verifier:
        print("✅ SubagentStop: subagent_verifier.py registered")
    else:
        print("❌ SubagentStop: subagent_verifier.py NOT registered")

except json.JSONDecodeError as e:
    print(f"❌ INVALID JSON: {e}")
EOF
```

### Step 5: Test Hook Execution

```bash
echo "=== Hook Execution Test ==="

# Test PostToolUse hook with mock input
echo '{"tool_name": "Write", "tool_input": {"file_path": "test.swift"}}' | python3 .claude/hooks/validators/acceptance_criteria.py 2>&1
echo "   Exit code: $?"

# Test SubagentStop hook with mock input
echo '{"agent_id": "test", "agent_transcript_path": "/nonexistent"}' | python3 .claude/hooks/validators/subagent_verifier.py 2>&1
echo "   Exit code: $?"

echo "   (Both should exit 0 - hooks handle missing files gracefully)"
```

### Step 6: Verify Loop Prevention

```bash
echo "=== Loop Prevention Check ==="
python3 << 'EOF'
import ast
from pathlib import Path

for hook in ['acceptance_criteria.py', 'subagent_verifier.py']:
    hook_path = Path(f'.claude/hooks/validators/{hook}')
    if not hook_path.exists():
        print(f"⚠️ {hook}: Not found")
        continue

    content = hook_path.read_text()

    # Check for stop_hook_active
    if 'stop_hook_active' in content:
        # Verify it's checked early
        try:
            tree = ast.parse(content)
            for node in ast.walk(tree):
                if isinstance(node, ast.FunctionDef) and node.name == 'main':
                    early_check = False
                    for i, stmt in enumerate(node.body[:6]):
                        if 'stop_hook_active' in ast.unparse(stmt):
                            early_check = True
                            print(f"✅ {hook}: stop_hook_active checked at statement {i+1}")
                            break
                    if not early_check:
                        print(f"⚠️ {hook}: stop_hook_active may not be checked early enough")
        except Exception as e:
            print(f"⚠️ {hook}: Could not analyze ({e})")
    else:
        print(f"❌ {hook}: MISSING stop_hook_active check (infinite loop risk!)")
EOF
```

### Step 7: Quick Health Check (All-in-One)

```bash
echo "=== QUICK HEALTH CHECK ==="
python3 << 'EOF'
import json
from pathlib import Path

errors = []
warnings = []

# Check required files
files = [
    (".claude/hooks/validators/acceptance_criteria.py", "PostToolUse hook"),
    (".claude/hooks/validators/subagent_verifier.py", "SubagentStop hook"),
    (".claude/acceptance-criteria.json", "Criteria config"),
    (".claude/settings.json", "Settings file"),
]

for path, name in files:
    if not Path(path).exists():
        errors.append(f"Missing: {name} ({path})")

# Check config
try:
    config = json.load(open(".claude/acceptance-criteria.json"))
    if not config.get("file_extensions"):
        warnings.append("No file_extensions configured")
    if not config.get("build_command"):
        warnings.append("No build_command configured")
    if not config.get("lint_command"):
        warnings.append("No lint_command configured")
except Exception as e:
    errors.append(f"Cannot parse acceptance-criteria.json: {e}")

# Check settings
try:
    settings = json.load(open(".claude/settings.json"))
    hooks = settings.get("hooks", {})
    if not hooks.get("PostToolUse"):
        errors.append("PostToolUse hooks not registered")
    if not hooks.get("SubagentStop"):
        errors.append("SubagentStop hooks not registered")
except Exception as e:
    errors.append(f"Cannot parse settings.json: {e}")

# Report
print()
if errors:
    print("❌ SETUP INVALID")
    for e in errors:
        print(f"   ERROR: {e}")
else:
    print("✅ SETUP VALID")

if warnings:
    for w in warnings:
        print(f"   WARNING: {w}")

print()
print("Remember: Run /hooks in Claude Code to apply configuration changes!")
EOF
```

## Common Issues

### Hooks not firing
1. Run `/hooks` in Claude Code after any config changes
2. Verify hook registration in settings.json
3. Check matcher pattern matches tool names

### Task ID not found
1. Ensure `TASK_ID: xxx` marker is in subagent prompt
2. Format: `TASK_ID:` followed by space and identifier
3. Verify task directory exists: `.claude/tasks/{task-id}/criteria.json`

### Infinite loop / agent stuck
1. Verify `stop_hook_active` check is present and early in hook
2. Check `max_attempts` is set in criteria
3. Look at attempt tracking: `.claude/hook-state/attempts.json`

### Build/test not running
1. Verify `build_command`/`test_command` in config
2. Check `{ "type": "build" }` or `{ "type": "test" }` is in checks array
3. Test commands manually to confirm they work

## Post-Validation

After validation passes:
- [ ] Run `/hooks` to ensure configuration is loaded
- [ ] Create a test task to verify end-to-end flow
- [ ] Confirm build/test commands work for your project
