---
description: Run end-to-end watch approval test after pairing with cc-watch
allowed-tools: Bash, Read
---

# End-to-End Watch Approval Test

Interactive test to verify the complete watch approval flow is working after pairing with `cc-watch`.

## Prerequisites

Before running this test:
1. Run `npx cc-watch` and complete pairing
2. Watch simulator (or physical watch) showing "Connected" / "Ready"
3. This Claude session should be the cc-watch session

## Test Flow

### Step 1: Verify Prerequisites

Run ALL of these checks:

```bash
# 1. Check CLAUDE_WATCH_SESSION_ACTIVE env var
echo "=== Session Check ==="
if [ "$CLAUDE_WATCH_SESSION_ACTIVE" = "1" ]; then
  echo "✓ CLAUDE_WATCH_SESSION_ACTIVE=1 (cc-watch session)"
else
  echo "✗ CLAUDE_WATCH_SESSION_ACTIVE not set - are you running via cc-watch?"
fi

# 2. Check pairing ID exists
echo -e "\n=== Pairing Check ==="
PAIRING_ID=$(cat ~/.claude-watch-pairing 2>/dev/null)
if [ -n "$PAIRING_ID" ]; then
  echo "✓ Pairing ID: ${PAIRING_ID:0:8}..."
else
  echo "✗ No pairing ID found - run pairing flow first"
fi

# 3. Check hooks are enabled
echo -e "\n=== Hooks Check ==="
if jq -e '.hooks.PreToolUse | length > 0' .claude/settings.json >/dev/null 2>&1; then
  echo "✓ PreToolUse hooks enabled"
else
  echo "✗ PreToolUse hooks DISABLED - watch approvals won't work!"
fi

# 4. Check watch simulator or verify pairing is active
echo -e "\n=== Watch Check ==="
if xcrun simctl list devices 2>/dev/null | grep -qi "watch.*booted"; then
  echo "✓ Watch simulator running"
else
  echo "? No watch simulator detected (physical watch may be paired)"
fi

# 5. Check cloud server
echo -e "\n=== Cloud Server ==="
if curl -s --max-time 5 https://claude-watch.fotescodev.workers.dev/health | grep -q '"status":"ok"'; then
  echo "✓ Cloud server healthy"
else
  echo "✗ Cloud server unreachable"
fi
```

If any check fails, fix the issue before proceeding.

### Step 2: Send Test Approval Request

Create a test request that will appear on the watch:

```bash
PAIRING_ID=$(cat ~/.claude-watch-pairing)
TIMESTAMP=$(date +%s)

echo "Sending test approval request to watch..."
RESULT=$(curl -s -X POST "https://claude-watch.fotescodev.workers.dev/request" \
  -H "Content-Type: application/json" \
  -d "{
    \"pairingId\": \"$PAIRING_ID\",
    \"type\": \"bash\",
    \"title\": \"E2E Test: echo hello\",
    \"description\": \"This is a test request from /test-e2e skill. Approve to verify the flow works.\"
  }")

REQUEST_ID=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('requestId',''))" 2>/dev/null)

if [ -n "$REQUEST_ID" ]; then
  echo "✓ Request created: $REQUEST_ID"
  echo "  → Check your watch for the approval request"
  echo "  → Request ID saved for verification"
  echo "$REQUEST_ID" > /tmp/e2e-test-request-id
else
  echo "✗ Failed to create request"
  echo "$RESULT"
fi
```

### Step 3: User Action Required

**ACTION: Go to your watch and APPROVE or REJECT the test request.**

The watch should show:
- Title: "E2E Test: echo hello"
- Type: bash
- Approve/Reject buttons

### Step 4: Verify Response

After approving/rejecting on watch, verify the response was recorded:

```bash
REQUEST_ID=$(cat /tmp/e2e-test-request-id 2>/dev/null)

if [ -z "$REQUEST_ID" ]; then
  echo "✗ No test request ID found. Run Step 2 first."
  exit 1
fi

echo "Checking response for request: $REQUEST_ID"
RESULT=$(curl -s "https://claude-watch.fotescodev.workers.dev/request/$REQUEST_ID")

STATUS=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','unknown'))" 2>/dev/null)

echo ""
if [ "$STATUS" = "approved" ]; then
  echo "════════════════════════════════════════"
  echo "  ✓ E2E TEST PASSED - Approval received!"
  echo "════════════════════════════════════════"
elif [ "$STATUS" = "rejected" ]; then
  echo "════════════════════════════════════════"
  echo "  ✓ E2E TEST PASSED - Rejection received!"
  echo "════════════════════════════════════════"
elif [ "$STATUS" = "pending" ]; then
  echo "⏳ Request still pending - waiting for watch response"
  echo "   Approve or reject on your watch, then run this step again"
else
  echo "✗ Unexpected status: $STATUS"
  echo "$RESULT"
fi

# Cleanup
rm -f /tmp/e2e-test-request-id
```

## Quick One-Liner Test

For fast verification, run the full hook flow with a real Edit:

```bash
# This will trigger the actual PreToolUse hook
echo "If this edit triggers a watch approval, the flow is working!"
```

Then make a small edit to any file - the approval should appear on your watch.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No notification on watch | Hooks disabled | Check `.claude/settings.json` PreToolUse array |
| Request created but watch shows nothing | APNs issue | Try simctl push directly |
| Approval not blocking Claude | Env var not set | Ensure running via `npx cc-watch` |
| "Session ended" message | Watch ended session | Re-pair or tap Resume on watch |

## Clean Up Test State

```bash
rm -f /tmp/e2e-test-* /tmp/claude-watch-*
echo "Test state cleaned up"
```
