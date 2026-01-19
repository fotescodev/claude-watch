#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
# E2E Verification Script for Ralph TUI Enhancement
# Tests all views, data extraction, and edge cases
#═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
METRICS_FILE="$SCRIPT_DIR/metrics.json"
TUI_SCRIPT="$SCRIPT_DIR/ralph-tui.sh"

# Colors for output
GREEN='\033[38;5;114m'
RED='\033[38;5;203m'
YELLOW='\033[38;5;221m'
CYAN='\033[38;5;116m'
NC='\033[0m'

PASSED=0
FAILED=0

print_test() {
    echo -e "${CYAN}TEST:${NC} $1"
}

print_pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    ((PASSED++))
}

print_fail() {
    echo -e "  ${RED}✗${NC} $1"
    ((FAILED++))
}

print_section() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
}

# Test 1: Syntax Check
print_section "1. Syntax and Structure Verification"

print_test "Bash syntax check"
if bash -n "$TUI_SCRIPT" 2>/dev/null; then
    print_pass "No syntax errors"
else
    print_fail "Syntax errors found"
fi

print_test "metrics.json is valid JSON"
if jq empty "$METRICS_FILE" 2>/dev/null; then
    print_pass "Valid JSON structure"
else
    print_fail "Invalid JSON"
fi

# Test 2: Required Functions
print_section "2. Required Functions Present"

for func in "read_key" "handle_input" "generate_sparkline" "check_spark" \
            "has_metrics_data" "is_terminal_too_small" "render_details" \
            "render_sessions" "render_costs" "get_token_history" "get_cost_history"; do
    print_test "Function $func() exists"
    if grep -q "^${func}()" "$TUI_SCRIPT"; then
        print_pass "Found"
    else
        print_fail "Missing"
    fi
done

# Test 3: Data Extraction
print_section "3. Data Extraction Tests"

print_test "Extract total sessions"
sessions=$(jq -r '.totalSessions // 0' "$METRICS_FILE" 2>/dev/null)
if [[ $sessions -gt 0 ]]; then
    print_pass "Got $sessions sessions"
else
    print_fail "No sessions found"
fi

print_test "Extract token totals"
input_tokens=$(jq -r '.totalTokens.input // 0' "$METRICS_FILE" 2>/dev/null)
output_tokens=$(jq -r '.totalTokens.output // 0' "$METRICS_FILE" 2>/dev/null)
if [[ $input_tokens -gt 0 ]] && [[ $output_tokens -gt 0 ]]; then
    print_pass "Input: $input_tokens, Output: $output_tokens"
else
    print_fail "Token data missing"
fi

print_test "Extract cost estimate"
cost=$(jq -r '.estimatedCost // "0"' "$METRICS_FILE" 2>/dev/null)
if [[ $(echo "$cost > 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
    print_pass "Cost: \$$cost"
else
    print_fail "Cost data missing"
fi

print_test "Extract tokenHistory array"
token_count=$(jq -r '.tokenHistory | length' "$METRICS_FILE" 2>/dev/null)
if [[ $token_count -gt 0 ]]; then
    print_pass "Found $token_count data points"
else
    print_fail "tokenHistory empty or missing"
fi

print_test "Extract costHistory array"
cost_count=$(jq -r '.costHistory | length' "$METRICS_FILE" 2>/dev/null)
if [[ $cost_count -gt 0 ]]; then
    print_pass "Found $cost_count data points"
else
    print_fail "costHistory empty or missing"
fi

print_test "Extract sessions array"
session_count=$(jq -r '.sessions | length' "$METRICS_FILE" 2>/dev/null)
if [[ $session_count -gt 0 ]]; then
    print_pass "Found $session_count session records"
else
    print_fail "sessions array empty or missing"
fi

print_test "Extract success rate"
success_rate=$(jq -r '.successRate // 0' "$METRICS_FILE" 2>/dev/null)
if [[ $(echo "$success_rate > 0" | bc -l 2>/dev/null || echo 0) -eq 1 ]]; then
    print_pass "Success rate: $success_rate%"
else
    print_fail "Success rate missing"
fi

# Test 4: Session Data Integrity
print_section "4. Session Data Integrity"

print_test "First session has required fields"
session_id=$(jq -r '.sessions[0].id // empty' "$METRICS_FILE" 2>/dev/null)
session_status=$(jq -r '.sessions[0].status // empty' "$METRICS_FILE" 2>/dev/null)
session_tokens=$(jq -r '.sessions[0].tokensUsed // 0' "$METRICS_FILE" 2>/dev/null)

if [[ -n "$session_id" ]] && [[ -n "$session_status" ]] && [[ $session_tokens -gt 0 ]]; then
    print_pass "ID: $session_id, Status: $session_status, Tokens: $session_tokens"
else
    print_fail "Missing required fields"
fi

print_test "Session timestamps are valid"
timestamp=$(jq -r '.sessions[0].timestamp // empty' "$METRICS_FILE" 2>/dev/null)
if [[ $timestamp =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]; then
    print_pass "Valid ISO8601 timestamp"
else
    print_fail "Invalid timestamp format"
fi

# Test 5: View State Configuration
print_section "5. View State Configuration"

print_test "CURRENT_VIEW variable declared"
if grep -q '^CURRENT_VIEW=' "$TUI_SCRIPT"; then
    view=$(grep '^CURRENT_VIEW=' "$TUI_SCRIPT" | head -1 | cut -d= -f2 | tr -d '"')
    print_pass "Default view: $view"
else
    print_fail "CURRENT_VIEW not found"
fi

print_test "Keyboard input handling present"
if grep -q 'case.*\$key' "$TUI_SCRIPT"; then
    print_pass "Input handler found"
else
    print_fail "No keyboard handler"
fi

print_test "View dispatcher present"
if grep -q 'case.*CURRENT_VIEW' "$TUI_SCRIPT"; then
    print_pass "View dispatcher found"
else
    print_fail "No view dispatcher"
fi

# Test 6: Sparkline Support
print_section "6. Sparkline Integration"

print_test "generate_sparkline() function"
if grep -q 'generate_sparkline()' "$TUI_SCRIPT"; then
    print_pass "Function exists"
else
    print_fail "Function missing"
fi

print_test "Sparkline fallback for missing spark"
if grep -q '▁▁▁▁▁▁▁▁' "$TUI_SCRIPT"; then
    print_pass "Fallback pattern present"
else
    print_fail "No fallback"
fi

print_test "check_spark() dependency check"
if grep -q 'check_spark()' "$TUI_SCRIPT"; then
    print_pass "Dependency check present"
else
    print_fail "No dependency check"
fi

# Test 7: Edge Case Handling
print_section "7. Edge Case Handling"

print_test "Empty data detection (has_metrics_data)"
if grep -q 'has_metrics_data()' "$TUI_SCRIPT"; then
    print_pass "Empty data handler present"
else
    print_fail "No empty data handler"
fi

print_test "Terminal size detection (is_terminal_too_small)"
if grep -q 'is_terminal_too_small()' "$TUI_SCRIPT"; then
    print_pass "Terminal size check present"
else
    print_fail "No size check"
fi

print_test "Minimum terminal dimensions defined"
if grep -q 'MIN_TERMINAL_WIDTH' "$TUI_SCRIPT" && grep -q 'MIN_TERMINAL_HEIGHT' "$TUI_SCRIPT"; then
    width=$(grep 'MIN_TERMINAL_WIDTH=' "$TUI_SCRIPT" | head -1 | cut -d= -f2)
    height=$(grep 'MIN_TERMINAL_HEIGHT=' "$TUI_SCRIPT" | head -1 | cut -d= -f2)
    print_pass "Min width: $width, Min height: $height"
else
    print_fail "Dimensions not defined"
fi

# Test 8: Color Palette
print_section "8. Color Palette (Coral/Cyan Theme)"

for color in "CORAL" "CYAN" "GREEN" "RED" "YELLOW" "WHITE" "GRAY" "NC"; do
    print_test "$color color defined"
    if grep -q "^${color}=" "$TUI_SCRIPT"; then
        print_pass "Present"
    else
        print_fail "Missing"
    fi
done

# Test 9: Real-time Update Loop
print_section "9. Real-time Update Configuration"

print_test "Main loop with sleep interval"
if grep -q 'sleep 0.4' "$TUI_SCRIPT" || grep -q 'sleep 0\.4' "$TUI_SCRIPT"; then
    print_pass "0.4s refresh interval configured"
else
    print_fail "Refresh interval not found or incorrect"
fi

print_test "Cleanup trap handler"
if grep -q 'trap cleanup' "$TUI_SCRIPT"; then
    print_pass "Cleanup handler registered"
else
    print_fail "No cleanup handler"
fi

# Test 10: Simulate sparkline generation
print_section "10. Sparkline Generation Test"

print_test "Sparkline with sample data"
if command -v spark &> /dev/null; then
    sparkline=$(echo "100 150 220 180 290 310 400 380" | spark 2>/dev/null)
    if [[ -n "$sparkline" ]]; then
        print_pass "Generated: $sparkline"
    else
        print_fail "spark command failed"
    fi
else
    print_pass "spark not installed (fallback will be used)"
fi

# Summary
print_section "Verification Summary"

echo ""
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ All automated checks passed!${NC}"
    echo ""
    echo -e "${YELLOW}Next Steps - Manual Verification:${NC}"
    echo "  1. Run: ./ralph-tui.sh"
    echo "  2. Press '1' or 'd' to view Dashboard"
    echo "  3. Press '2' or 'm' to view Metrics (Costs)"
    echo "  4. Press '3' or 's' to view Sessions"
    echo "  5. Press '4' or 't' to view Tasks"
    echo "  6. Verify sparklines display (or fallback pattern)"
    echo "  7. Check success rate color coding"
    echo "  8. Verify no console errors"
    echo "  9. Test for 5+ minutes to check stability"
    echo " 10. Resize terminal to test small screen handling"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Some checks failed. Review errors above.${NC}"
    echo ""
    exit 1
fi
