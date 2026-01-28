---
description: Interactive cloud E2E tests - sends requests and waits for watch response
allowed-tools: Bash
---

# /test-e2e - Interactive Cloud E2E Tests

Run the interactive cloud test suite that sends real requests through the cloud relay and waits for user confirmation at each step.

## Run the tests

```bash
./scripts/test-v2-cloud.sh
```

This script tests:
1. Tier 1 Approval (Green) - approve/reject buttons
2. Tier 2 Approval (Orange) - approve/reject buttons
3. Tier 3 Approval (Red) - reject only, "requires Mac"
4. Question Flow - binary options
5. Context Warning - 85% threshold
6. Progress Update - working view with task list
7. Basic Queue - multiple pending approvals
8. TierQueueView - 3 tiers with swipe navigation
9. CombinedQueueView - colored rows
10. TierReviewView - individual action review
11. Danger Queue - Review Each only

**Requirements:**
- Active pairing (`npx cc-watch`)
- Watch connected (simulator or physical)
- Cloud server healthy
