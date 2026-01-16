#!/usr/bin/env python3
"""
Claude Watch Pairing Helper

This script helps you pair Claude Code with your Apple Watch:
1. Generates a pairing code from the cloud server
2. Displays the code for you to enter on your watch
3. Waits for pairing to complete
4. Saves the pairing ID to ~/.claude-watch-pairing

Usage:
    python claude-watch-pair.py
    # Or if installed:
    claude-watch-pair
"""
import json
import os
import sys
import time
import urllib.request
import urllib.error

CLOUD_SERVER = "https://claude-watch.fotescodev.workers.dev"
PAIRING_CONFIG_FILE = os.path.expanduser("~/.claude-watch-pairing")


def create_pairing() -> tuple[str, str]:
    """Create a new pairing, returns (code, pairingId)."""
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/pair",
        data=b"{}",
        headers={"Content-Type": "application/json"},
        method="POST"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        return result["code"], result["pairingId"]


def check_pairing_status(pairing_id: str) -> str:
    """Check if pairing is complete. Returns 'pending', 'active', or error."""
    req = urllib.request.Request(
        f"{CLOUD_SERVER}/pair/{pairing_id}/status",
        method="GET"
    )

    with urllib.request.urlopen(req, timeout=10) as resp:
        result = json.loads(resp.read())
        return result.get("status", "pending")


def save_pairing_id(pairing_id: str):
    """Save pairing ID to config file."""
    with open(PAIRING_CONFIG_FILE, 'w') as f:
        f.write(pairing_id)
    os.chmod(PAIRING_CONFIG_FILE, 0o600)  # Restrict permissions


def load_existing_pairing() -> str | None:
    """Load existing pairing ID if present."""
    if os.path.exists(PAIRING_CONFIG_FILE):
        try:
            with open(PAIRING_CONFIG_FILE, 'r') as f:
                return f.read().strip() or None
        except (IOError, OSError):
            return None
    return None


def test_existing_pairing(pairing_id: str) -> bool:
    """Test if an existing pairing is still valid."""
    try:
        status = check_pairing_status(pairing_id)
        return status == "active"
    except Exception:
        return False


def main():
    print("=" * 50)
    print("  Claude Watch Pairing")
    print("=" * 50)
    print()

    # Check for existing pairing
    existing = load_existing_pairing()
    if existing:
        print(f"Found existing pairing: {existing[:8]}...")
        if test_existing_pairing(existing):
            print("Existing pairing is still active!")
            print()
            response = input("Create new pairing anyway? [y/N]: ").strip().lower()
            if response != 'y':
                print("Keeping existing pairing.")
                return 0
        else:
            print("Existing pairing appears inactive, creating new one...")
        print()

    # Create new pairing
    try:
        print("Requesting pairing code from server...")
        code, pairing_id = create_pairing()
    except urllib.error.URLError as e:
        print(f"Error: Could not reach cloud server: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1

    print()
    print("=" * 50)
    print()
    print(f"  Your pairing code is:  {code}")
    print()
    print("=" * 50)
    print()
    print("On your Apple Watch:")
    print("  1. Open Claude Watch app")
    print("  2. Tap 'Pair with Claude Code'")
    print(f"  3. Enter code: {code}")
    print()
    print("Waiting for pairing to complete (expires in 10 minutes)...")
    print("Press Ctrl+C to cancel")
    print()

    # Poll for completion
    start_time = time.time()
    timeout = 600  # 10 minutes
    poll_interval = 2.0

    try:
        while time.time() - start_time < timeout:
            status = check_pairing_status(pairing_id)

            if status == "active":
                print()
                print("Pairing successful!")
                save_pairing_id(pairing_id)
                print(f"Saved pairing ID to {PAIRING_CONFIG_FILE}")
                print()
                print("Claude Watch is now configured. Approval requests")
                print("will be sent to your watch automatically.")
                return 0

            # Show progress
            elapsed = int(time.time() - start_time)
            remaining = timeout - elapsed
            sys.stdout.write(f"\rWaiting... ({remaining}s remaining)  ")
            sys.stdout.flush()

            time.sleep(poll_interval)

        print()
        print("Pairing code expired. Please run again to get a new code.")
        return 1

    except KeyboardInterrupt:
        print()
        print("Pairing cancelled.")
        return 1


if __name__ == "__main__":
    sys.exit(main())
