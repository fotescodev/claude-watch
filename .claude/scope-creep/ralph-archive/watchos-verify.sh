#!/bin/bash
#
# watchOS Verification Harness
# Validates watchOS app against Apple requirements and best practices
#
# Usage: ./watchos-verify.sh [OPTIONS]
#   --skip-build    Skip build check (for CI without Xcode)
#   --quick         Only run quick checks (no build)
#
# Exit Codes:
#   0 - All checks passed
#   1 - Warning (non-blocking issues found)
#   2 - Build failure
#   3 - Critical verification failure
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Options
SKIP_BUILD=false
QUICK_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --skip-build) SKIP_BUILD=true; shift ;;
        --quick) QUICK_MODE=true; SKIP_BUILD=true; shift ;;
        *) shift ;;
    esac
done

# Colors
if [[ -t 1 ]] && [[ "${TERM:-dumb}" != "dumb" ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED='' GREEN='' YELLOW='' CYAN='' NC=''
fi

# Counters
ERRORS=0
WARNINGS=0

log_check() {
    echo -e "${CYAN}[check]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}  [PASS]${NC} $*"
}

log_fail() {
    echo -e "${RED}  [FAIL]${NC} $*"
    ((ERRORS++))
}

log_warn() {
    echo -e "${YELLOW}  [WARN]${NC} $*"
    ((WARNINGS++))
}

log_info() {
    echo -e "  [INFO] $*"
}

# ═══════════════════════════════════════════════════════════════════════════════
# VERIFICATION CHECKS
# ═══════════════════════════════════════════════════════════════════════════════

check_build() {
    if [[ "$SKIP_BUILD" == "true" ]]; then
        log_check "Build check (SKIPPED)"
        log_info "Use without --skip-build to run build verification"
        return 0
    fi

    # Check if xcodebuild is available
    if ! command -v xcodebuild &> /dev/null; then
        log_check "Build check (SKIPPED - Xcode not available)"
        log_info "Install Xcode to enable build verification"
        return 0
    fi

    log_check "Building for watchOS Simulator..."

    cd "$PROJECT_ROOT"

    # Find available watch simulator dynamically
    local simulator
    simulator=$(xcrun simctl list devices available 2>/dev/null | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ ([A-F0-9-]*).*//')

    if [[ -z "$simulator" ]]; then
        log_warn "No watchOS simulator found, using generic destination"
        simulator="Apple Watch Series 11 (42mm)"
    fi

    log_info "Using simulator: $simulator"

    local build_output
    build_output=$(mktemp)

    if xcodebuild -project ClaudeWatch.xcodeproj \
        -scheme ClaudeWatch \
        -destination "platform=watchOS Simulator,name=$simulator" \
        -quiet \
        build 2>&1 | tee "$build_output" | tail -5; then

        if grep -q "BUILD SUCCEEDED" "$build_output" || grep -q "Build Succeeded" "$build_output"; then
            log_pass "Build succeeded"
            rm -f "$build_output"
            return 0
        fi
    fi

    log_fail "Build failed"
    log_info "See build output above for details"
    rm -f "$build_output"
    return 2
}

check_deprecated_apis() {
    log_check "Checking for deprecated APIs..."

    cd "$PROJECT_ROOT"

    local deprecated_found=false

    # Check for WKExtension.shared()
    if grep -r "WKExtension\.shared" ClaudeWatch/ --include="*.swift" 2>/dev/null | grep -v "^Binary"; then
        log_fail "Found deprecated WKExtension.shared() - use WKApplication.shared()"
        deprecated_found=true
    fi

    # Check for presentTextInputController
    if grep -r "presentTextInputController" ClaudeWatch/ --include="*.swift" 2>/dev/null | grep -v "^Binary"; then
        log_fail "Found deprecated presentTextInputController - use SwiftUI TextField"
        deprecated_found=true
    fi

    # Check for WKInterfaceController
    if grep -r "WKInterfaceController" ClaudeWatch/ --include="*.swift" 2>/dev/null | grep -v "^Binary"; then
        log_fail "Found deprecated WKInterfaceController - use SwiftUI View"
        deprecated_found=true
    fi

    # Check for WKAlertAction
    if grep -r "WKAlertAction" ClaudeWatch/ --include="*.swift" 2>/dev/null | grep -v "^Binary"; then
        log_fail "Found deprecated WKAlertAction - use SwiftUI .alert()"
        deprecated_found=true
    fi

    if [[ "$deprecated_found" == "false" ]]; then
        log_pass "No deprecated APIs found"
    fi
}

check_accessibility_labels() {
    log_check "Checking accessibility labels..."

    cd "$PROJECT_ROOT"

    # Count accessibility labels in Views
    local label_count
    label_count=$(grep -r "accessibilityLabel" ClaudeWatch/Views/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

    # Count interactive elements (rough estimate)
    local button_count
    button_count=$(grep -r "Button\|NavigationLink\|Toggle" ClaudeWatch/Views/ --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

    log_info "Found $label_count accessibility labels"
    log_info "Found approximately $button_count interactive elements"

    if [[ "$label_count" -lt 10 ]]; then
        log_warn "Low accessibility label count ($label_count) - consider adding more"
    else
        log_pass "Accessibility labels present ($label_count found)"
    fi
}

check_font_sizes() {
    log_check "Checking font sizes (minimum 11pt)..."

    cd "$PROJECT_ROOT"

    # Look for font sizes below 11pt (single digit or 10)
    local small_fonts
    small_fonts=$(grep -rE '\.font\(.*size:\s*([0-9]|10)\.' ClaudeWatch/ --include="*.swift" 2>/dev/null || true)

    if [[ -n "$small_fonts" ]]; then
        log_warn "Found font sizes below 11pt:"
        echo "$small_fonts" | head -5
        log_info "Consider using semantic font styles (.caption, .footnote)"
    else
        log_pass "All font sizes meet 11pt minimum"
    fi
}

check_always_on_support() {
    log_check "Checking Always-On Display support..."

    cd "$PROJECT_ROOT"

    if grep -r "isLuminanceReduced" ClaudeWatch/Views/ --include="*.swift" 2>/dev/null | grep -q .; then
        log_pass "Always-On Display support found"
    else
        log_warn "No Always-On Display support detected"
        log_info "Consider using @Environment(\\.isLuminanceReduced)"
    fi
}

check_swift_version() {
    log_check "Checking Swift version..."

    cd "$PROJECT_ROOT"

    local swift_version
    swift_version=$(grep "SWIFT_VERSION" ClaudeWatch.xcodeproj/project.pbxproj | head -1 | grep -oE '[0-9]+\.[0-9]+' || echo "unknown")

    if [[ "$swift_version" == "5.9" ]] || [[ "$swift_version" == "5.10" ]] || [[ "$swift_version" == "6.0" ]]; then
        log_pass "Swift version $swift_version"
    elif [[ "$swift_version" == "5.0" ]]; then
        log_warn "Swift version $swift_version - consider upgrading to 5.9+"
    else
        log_info "Swift version: $swift_version"
    fi
}

check_liquid_glass() {
    log_check "Checking Liquid Glass adoption..."

    cd "$PROJECT_ROOT"

    local glass_found=false

    if grep -r "glassBackgroundEffect\|\.glass\|ultraThinMaterial\|thinMaterial" ClaudeWatch/Views/ --include="*.swift" 2>/dev/null | grep -q .; then
        log_pass "Liquid Glass/material effects found"
        glass_found=true
    fi

    if grep -r "\.spring\|interpolatingSpring\|\.bouncy" ClaudeWatch/Views/ --include="*.swift" 2>/dev/null | grep -q .; then
        log_pass "Spring animations found"
        glass_found=true
    fi

    if [[ "$glass_found" == "false" ]]; then
        log_info "No Liquid Glass adoption detected (optional for watchOS 26)"
    fi
}

check_app_icons() {
    log_check "Checking app icon assets..."

    cd "$PROJECT_ROOT"

    local icon_dir="ClaudeWatch/Assets.xcassets/AppIcon.appiconset"

    if [[ -d "$icon_dir" ]]; then
        local png_count
        png_count=$(ls "$icon_dir"/*.png 2>/dev/null | wc -l | tr -d ' ')

        if [[ "$png_count" -ge 8 ]]; then
            log_pass "App icons present ($png_count PNG files)"
        elif [[ "$png_count" -gt 0 ]]; then
            log_warn "Only $png_count app icon files found (need 8+)"
        else
            log_warn "No app icon PNG files found"
        fi
    else
        log_warn "App icon directory not found"
    fi
}

check_entitlements() {
    log_check "Checking entitlements..."

    cd "$PROJECT_ROOT"

    local entitlements_file
    entitlements_file=$(find ClaudeWatch -name "*.entitlements" -type f 2>/dev/null | head -1)

    if [[ -n "$entitlements_file" ]]; then
        log_pass "Entitlements file found: $entitlements_file"

        if grep -q "aps-environment" "$entitlements_file" 2>/dev/null; then
            log_pass "Push notification entitlement configured"
        else
            log_info "No push notification entitlement (may be needed)"
        fi

        if grep -q "group\." "$entitlements_file" 2>/dev/null; then
            log_pass "App Groups configured"
        else
            log_info "No App Groups configured (needed for complications)"
        fi
    else
        log_warn "No entitlements file found"
    fi
}

check_project_sync() {
    log_check "Checking Xcode project sync (all Swift files in project)..."

    cd "$PROJECT_ROOT"

    local project_file="ClaudeWatch.xcodeproj/project.pbxproj"
    local missing_files=()
    local checked=0

    # Find all .swift files in ClaudeWatch/ (excluding Tests for now)
    while IFS= read -r -d '' swift_file; do
        local filename
        filename=$(basename "$swift_file")
        ((checked++))

        # Check if filename appears in project.pbxproj
        if ! grep -q "$filename" "$project_file" 2>/dev/null; then
            missing_files+=("$swift_file")
        fi
    done < <(find ClaudeWatch -name "*.swift" ! -path "*/Tests/*" -print0 2>/dev/null)

    log_info "Checked $checked Swift files against project.pbxproj"

    if [[ ${#missing_files[@]} -gt 0 ]]; then
        log_fail "Found ${#missing_files[@]} Swift files NOT in Xcode project:"
        for f in "${missing_files[@]}"; do
            log_info "  MISSING: $f"
        done
        log_info "Files exist on disk but won't compile - add them to the Xcode project!"
        return 1
    else
        log_pass "All Swift files are in Xcode project"
        return 0
    fi
}

get_available_simulator() {
    # Return the first available watchOS simulator name
    local sim_name
    sim_name=$(xcrun simctl list devices available 2>/dev/null | grep -i "Apple Watch" | head -1 | sed 's/^ *//' | sed 's/ (.*$//')

    if [[ -z "$sim_name" ]]; then
        echo "Apple Watch Series 11 (42mm)"  # Fallback
    else
        echo "$sim_name"
    fi
}

# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

main() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║       watchOS Verification Harness                            ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo ""

    # Run all checks - project sync FIRST (before build, catches missing files)
    check_project_sync || { echo ""; echo "Project sync failed - files missing from Xcode project!"; exit 3; }
    echo ""
    check_build || { echo ""; echo "Build failed - stopping verification"; exit 2; }
    echo ""
    check_deprecated_apis
    echo ""
    check_accessibility_labels
    echo ""
    check_font_sizes
    echo ""
    check_swift_version
    echo ""
    check_always_on_support
    echo ""
    check_liquid_glass
    echo ""
    check_app_icons
    echo ""
    check_entitlements

    # Summary
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "SUMMARY"
    echo "═══════════════════════════════════════════════════════════════"

    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}Errors: $ERRORS${NC}"
    else
        echo -e "${GREEN}Errors: 0${NC}"
    fi

    if [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
    else
        echo "Warnings: 0"
    fi

    echo ""

    if [[ $ERRORS -gt 0 ]]; then
        echo -e "${RED}VERIFICATION FAILED${NC}"
        exit 3
    elif [[ $WARNINGS -gt 0 ]]; then
        echo -e "${YELLOW}VERIFICATION PASSED WITH WARNINGS${NC}"
        exit 0
    else
        echo -e "${GREEN}VERIFICATION PASSED${NC}"
        exit 0
    fi
}

main "$@"
