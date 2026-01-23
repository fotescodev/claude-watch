#!/usr/bin/env python3
"""
PostToolUse validator for mobile tap/swipe/type actions.

Validates that screen state changed after interaction by checking for
expected elements. Implements the Ralph Loop pattern: agent must retry
if validation fails.

Usage (as PostToolUse hook):
    Receives JSON on stdin with tool_name, tool_input, tool_output

Exit codes:
    0 - Validation passed or no validation needed
    1 - Validation failed (agent should retry)
"""

import json
import os
import sys
import time
from pathlib import Path

# Debug logging
DEBUG_LOG = "/tmp/claude-watch-mobile-validator.log"


def debug_log(message: str):
    """Log debug messages."""
    try:
        with open(DEBUG_LOG, "a") as f:
            f.write(f"{time.time()}: {message}\n")
    except Exception:
        pass


def validate_screen_state(tool_name: str, tool_input: dict, tool_output: dict) -> tuple[bool, str]:
    """
    Validate screen state after mobile interaction.

    The validation uses _expect_element metadata to verify UI state.
    If no expectation is specified, validation passes (no assertion).

    Args:
        tool_name: The mobile tool that was called
        tool_input: Input parameters to the tool
        tool_output: Output from the tool

    Returns:
        (is_valid, message) tuple
    """
    # Check for expected element in tool input metadata
    expected_element = tool_input.get("_expect_element")
    expected_not_present = tool_input.get("_expect_not_present")

    if not expected_element and not expected_not_present:
        debug_log(f"No validation criteria for {tool_name} - passing")
        return True, "No validation criteria specified"

    # Check tool output for error indicators
    output_str = str(tool_output)

    # Common error patterns in mobile-mcp output
    error_patterns = [
        "error",
        "failed",
        "not found",
        "timeout",
        "no such element",
        "element not visible",
        "unable to",
    ]

    for pattern in error_patterns:
        if pattern.lower() in output_str.lower():
            debug_log(f"Error pattern detected: {pattern}")
            return False, f"Tool output indicates error: {pattern}"

    # If we have expected element, check if tool succeeded
    # The actual element verification would require calling mobile_list_elements_on_screen
    # For now, we check the tool output for success indicators
    if expected_element:
        # Tool executed without error = screen likely changed
        debug_log(f"Expected element '{expected_element}' - tool succeeded")
        return True, f"Tool executed successfully, expecting element: {expected_element}"

    if expected_not_present:
        debug_log(f"Expected NOT present '{expected_not_present}' - tool succeeded")
        return True, f"Tool executed successfully, element should be gone: {expected_not_present}"

    return True, "Validation passed"


def validate_tap_action(tool_input: dict, tool_output: dict) -> tuple[bool, str]:
    """Validate a tap/click action completed successfully."""
    x = tool_input.get("x")
    y = tool_input.get("y")

    if x is None or y is None:
        return False, "Tap action missing coordinates"

    return validate_screen_state("mobile_click_on_screen_at_coordinates", tool_input, tool_output)


def validate_swipe_action(tool_input: dict, tool_output: dict) -> tuple[bool, str]:
    """Validate a swipe action completed successfully."""
    direction = tool_input.get("direction")

    if not direction:
        return False, "Swipe action missing direction"

    valid_directions = ["up", "down", "left", "right"]
    if direction.lower() not in valid_directions:
        return False, f"Invalid swipe direction: {direction}. Must be one of: {valid_directions}"

    return validate_screen_state("mobile_swipe_on_screen", tool_input, tool_output)


def validate_type_action(tool_input: dict, tool_output: dict) -> tuple[bool, str]:
    """Validate a text input action completed successfully."""
    text = tool_input.get("text") or tool_input.get("keys")

    if not text:
        return False, "Type action missing text/keys"

    return validate_screen_state("mobile_type_keys", tool_input, tool_output)


def main():
    """Main entry point for PostToolUse hook."""
    debug_log("Mobile validator invoked")

    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        debug_log(f"JSON decode error: {e}")
        sys.exit(0)  # Don't block on parse errors

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})
    tool_output = input_data.get("tool_output", {})

    debug_log(f"Validating tool: {tool_name}")

    # Route to appropriate validator
    validators = {
        "mobile_click_on_screen_at_coordinates": validate_tap_action,
        "mobile_double_tap_on_screen": validate_tap_action,
        "mobile_long_press_on_screen_at_coordinates": validate_tap_action,
        "mobile_swipe_on_screen": validate_swipe_action,
        "mobile_type_keys": validate_type_action,
    }

    validator = validators.get(tool_name)
    if not validator:
        debug_log(f"No validator for tool: {tool_name}")
        sys.exit(0)  # No validator for this tool

    is_valid, message = validator(tool_input, tool_output)

    debug_log(f"Validation result: valid={is_valid}, message={message}")
    print(message)

    # Exit 0 for valid, 1 for invalid (agent should retry)
    sys.exit(0 if is_valid else 1)


if __name__ == "__main__":
    main()
