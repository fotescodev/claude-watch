# Feature: Session Activity Indicator

## Problem

When Claude is actively working (reading files, searching, etc.), the watch shows "Idle" because only approval-required tools (Bash, Edit, Write) trigger cloud requests. The user has no visibility into whether Claude is actively doing work or truly idle.

Screenshot: Watch shows "Idle" + "Session Started 3m ago" while Claude is doing dozens of Read/Grep/Bash calls.

## Proposed Approach

Use the PreToolUse hook to send lightweight activity pings for ALL tools, not just approval-required ones.

### Hook Changes (`watch-approval-cloud.py`)

For non-approval tools (Read, Grep, Glob, etc.):
- Fire-and-forget POST to `/activity/{pairingId}` with tool name + timestamp
- Exit 0 immediately (no blocking, no polling)
- Must be async/non-blocking so it doesn't slow Claude down

For approval tools (Bash, Edit, Write, etc.):
- Existing behavior (block + poll) — unchanged

### Cloud Server Changes (Cloudflare Worker)

New endpoint: `POST /activity/{pairingId}`
- Stores: `{ lastTool, lastActivity, toolCount }`
- TTL: auto-expire after 5 minutes of inactivity

New endpoint: `GET /activity/{pairingId}`
- Returns: `{ active, lastTool, lastActivity, toolCount }`
- `active = true` if `lastActivity` < 30s ago

### Watch App Changes

Poll `/activity/{pairingId}` every 5-10s when on the main screen:
- **Active**: Show "Active" with pulsing indicator + last tool name
  - "Reading files...", "Searching code...", "Running bash..."
- **Idle**: Show "Idle" (current behavior) when no ping for 30s+
- **Waiting**: Show "Waiting for approval" (existing, when pending request)

### Tool Name Mapping (Display)

| Tool | Watch Display |
|------|--------------|
| Read | Reading files... |
| Grep | Searching code... |
| Glob | Finding files... |
| Bash | Running command... |
| Edit | Editing files... |
| Write | Writing files... |
| Task | Running agent... |
| WebFetch | Fetching web... |
| WebSearch | Searching web... |

## Performance Considerations

- Hook must not add latency to non-approval tools
- Use background subprocess or non-blocking HTTP (fire-and-forget)
- Debounce: max 1 ping per second (don't flood server during rapid tool calls)
- Cloud endpoint should be ultra-fast (KV write, no logic)

## Priority

Post-shipping enhancement. Core approval flow works without this.
