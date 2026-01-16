#!/bin/bash
# Pre-edit hook - protects sensitive files from modification

# Read file path from stdin JSON
FILE=$(cat | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null)

# Protected file patterns
PROTECTED_PATTERNS=(
    ".env"
    "Secrets.swift"
    "GoogleService-Info.plist"
    ".git/"
    "Podfile.lock"
    ".p8"
    ".p12"
    ".mobileprovision"
)

for pattern in "${PROTECTED_PATTERNS[@]}"; do
    if [[ "$FILE" == *"$pattern"* ]]; then
        echo "Protected file: $FILE" >&2
        exit 2  # Block the operation
    fi
done

exit 0  # Allow the operation
