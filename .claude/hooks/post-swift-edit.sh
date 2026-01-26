#!/bin/bash
# IMMEDIATE DEBUG
echo "$(date '+%Y-%m-%d %H:%M:%S') - post-swift-edit.sh invoked" >> /tmp/post-swift-edit-invoked.log

# Post-edit hook for Swift files - runs linting if available

# Read file path from stdin JSON
FILE=$(cat | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Only process Swift files
if [[ "$FILE" != *.swift ]]; then
    exit 0
fi

# Run SwiftLint if available and configured
if command -v swiftlint &> /dev/null && [ -f ".swiftlint.yml" ]; then
    LINT_OUTPUT=$(swiftlint lint --path "$FILE" --quiet 2>&1 | head -5)
    if [ -n "$LINT_OUTPUT" ]; then
        echo "SwiftLint:" >&2
        echo "$LINT_OUTPUT" >&2
    fi
fi

# Run swift-format check if available
if command -v swift-format &> /dev/null; then
    FORMAT_OUTPUT=$(swift-format lint "$FILE" 2>&1 | head -3)
    if [ -n "$FORMAT_OUTPUT" ]; then
        echo "swift-format:" >&2
        echo "$FORMAT_OUTPUT" >&2
    fi
fi

exit 0
