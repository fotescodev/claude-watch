#!/bin/bash
# Session start hook - displays project info

PROJECT_NAME="ClaudeWatch"
SWIFT_VERSION=$(swift --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
XCODE_VERSION=$(xcodebuild -version 2>/dev/null | head -1)

echo "watchOS project: $PROJECT_NAME" >&2
echo "Swift $SWIFT_VERSION | $XCODE_VERSION" >&2

# Check for running simulators
BOOTED_SIMS=$(xcrun simctl list devices booted 2>/dev/null | grep -c "Booted")
if [ "$BOOTED_SIMS" -eq 0 ]; then
    echo "No simulators running. Use /run-app to boot one." >&2
else
    echo "$BOOTED_SIMS simulator(s) running" >&2
fi

# Check if MCP server is running
if lsof -i :8787 >/dev/null 2>&1; then
    echo "MCP server running on :8787" >&2
else
    echo "MCP server not running. Use /start-server to start it." >&2
fi
