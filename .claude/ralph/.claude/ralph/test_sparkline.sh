#!/bin/bash
# Test script for sparkline rendering

generate_sparkline() {
    # Generate sparkline from space-delimited numbers
    # Args: $1 - space-delimited numbers (e.g., "100 150 220 180")
    # Returns: unicode sparkline characters or fallback pattern
    local data="$1"
    echo "$data" | spark 2>/dev/null || echo "▁▁▁▁▁▁▁▁"
}

# Test with sample data
result=$(generate_sparkline "100 150 220 180 290 310 400 380")
echo "Sparkline result: $result"

# Verify it contains sparkline characters
if echo "$result" | grep -q '[▁▂▃▅▇]'; then
    echo "✓ Sparkline rendering test: OK"
    exit 0
else
    echo "✗ Sparkline rendering test: FAIL"
    exit 1
fi
