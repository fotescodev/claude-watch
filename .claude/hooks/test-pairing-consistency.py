#!/usr/bin/env python3
"""
Test that pairing IDs are consistent across all storage locations.

Validates:
1. Legacy file (~/.claude-watch-pairing) matches config file
2. Config file (~/.claude-watch/config.json) has valid pairingId
3. Environment variable matches if set

Usage:
    python3 test-pairing-consistency.py
"""

import json
import os
import sys
from pathlib import Path


def test_pairing_consistency():
    """Check pairing ID consistency across all storage locations."""
    print("=" * 60)
    print("  Pairing ID Consistency Test")
    print("=" * 60)

    home = Path.home()
    all_passed = True

    # Read legacy file
    legacy_path = home / ".claude-watch-pairing"
    legacy_id = None
    if legacy_path.exists():
        legacy_id = legacy_path.read_text().strip()

    # Read config file
    config_path = home / ".claude-watch" / "config.json"
    config_id = None
    if config_path.exists():
        try:
            config = json.loads(config_path.read_text())
            config_id = config.get("pairingId")
        except json.JSONDecodeError:
            print(f"\n  [ERROR] Invalid JSON in {config_path}")
            all_passed = False

    # Check environment variable
    env_id = os.environ.get("CLAUDE_WATCH_PAIRING_ID")

    # Report findings
    print("\nPairing ID Sources:")
    if legacy_id:
        print(f"  Legacy file:  {legacy_id[:12]}...")
    else:
        print("  Legacy file:  NOT SET")

    if config_id:
        print(f"  Config file:  {config_id[:12]}...")
    else:
        print("  Config file:  NOT SET")

    if env_id:
        print(f"  Environment:  {env_id[:12]}...")
    else:
        print("  Environment:  not set (will use file)")

    # Validate consistency
    print("\nConsistency Checks:")

    # Check 1: Both files exist and match
    if legacy_id and config_id:
        if legacy_id == config_id:
            print("  [PASS] Legacy and config files match")
        else:
            print("  [FAIL] Legacy and config files MISMATCH!")
            print(f"         Legacy: {legacy_id}")
            print(f"         Config: {config_id}")
            print("         Fix: rm ~/.claude-watch-pairing && npx cc-watch")
            all_passed = False
    elif legacy_id and not config_id:
        print("  [WARN] Legacy file exists but config.json missing pairingId")
        print("         This may cause issues with stdin-proxy")
    elif config_id and not legacy_id:
        print("  [WARN] Config file has pairingId but legacy file missing")
        print("         Hooks may not find pairing ID")
        print("         Fix: cp config pairingId to ~/.claude-watch-pairing")
    else:
        print("  [INFO] No pairing IDs found (not paired yet)")

    # Check 2: Environment variable matches if set
    if env_id:
        effective_id = legacy_id or config_id
        if effective_id and env_id != effective_id:
            print("  [FAIL] Environment variable does not match file!")
            print(f"         Env: {env_id}")
            print(f"         File: {effective_id}")
            all_passed = False
        elif effective_id:
            print("  [PASS] Environment variable matches file")

    # Final result
    print("\n" + "=" * 60)
    if all_passed:
        print("  PASS: Pairing IDs are consistent")
    else:
        print("  FAIL: Pairing ID inconsistencies detected")
    print("=" * 60)

    return all_passed


if __name__ == "__main__":
    success = test_pairing_consistency()
    sys.exit(0 if success else 1)
