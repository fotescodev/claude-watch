# FE2b Context: Stop/Play Interrupt Controls

> Decisions captured: 2026-01-19
> Participants: user

## Key Decisions

### Interrupt Mechanism
**Choice**: Worker endpoint + polling hook
**Rationale**: Clean separation, works with existing cloud architecture
**Implementation**:
1. Add `POST /session-interrupt` endpoint to worker
2. Store interrupt state in KV: `interrupt:{pairingId}` = `{ action: "stop"|"resume", timestamp }`
3. Hook polls `GET /session-interrupt/{pairingId}` on each tool call
4. When interrupt detected, hook exits with special code or signals Claude Code

### Resume Functionality
**Choice**: Full implementation (Stop + Resume)
**Rationale**: User wants complete control
**Implementation**:
- Stop: Sets `action: "stop"` in KV, hook reads and triggers interrupt
- Resume: Sets `action: "resume"` in KV, clears interrupt state
- Challenge: How does Claude Code actually resume? Options:
  - After stop: Claude Code pauses, waits for resume signal before next action
  - Or: Stop just logs a message, resume clears it
  - Need to define what "resume" means in practice

### UI Placement
**Choice**: In session progress view (existing location)
**Rationale**: Keep UI clean, button visible when relevant
**Implementation**: Update `sessionProgressView()` in MainView.swift

## Implementation Plan

### 1. Worker: Add `/session-interrupt` endpoint
**File**: `MCPServer/worker/src/index.ts`

```typescript
// POST /session-interrupt - Set interrupt state
// GET /session-interrupt/:pairingId - Check interrupt state
// DELETE /session-interrupt/:pairingId - Clear interrupt state
```

**KV Schema**:
```json
{
  "key": "interrupt:{pairingId}",
  "value": {
    "action": "stop" | "resume",
    "timestamp": "2026-01-19T12:00:00Z",
    "requestedBy": "watch"
  }
}
```

### 2. Hook: Check for interrupts
**File**: `.claude/hooks/progress-tracker.py`

Add to hook execution:
1. Before sending progress update, check for interrupt
2. `GET /session-interrupt/{pairingId}`
3. If `action == "stop"`:
   - Exit with code that Claude Code recognizes as interrupt
   - Or: Print special message that triggers pause
4. If `action == "resume"`:
   - Clear the interrupt flag
   - Continue normal operation

**Challenge**: How to actually interrupt Claude Code?
- Option A: Exit hook with error code (rejected permission)
- Option B: Write to a signal file that Claude Code watches
- Option C: Use PreToolUse hook to block all tools until resume

### 3. Watch: Update UI controls
**File**: `ClaudeWatch/Views/MainView.swift`

Update `sessionProgressView()`:
```swift
// Replace single Stop button with Stop/Resume toggle
HStack(spacing: 12) {
    // Stop button
    Button {
        service.sendInterrupt(action: .stop)
    } label: {
        HStack {
            Image(systemName: "stop.fill")
            Text("Stop")
        }
    }
    .disabled(service.sessionInterrupted)

    // Resume button
    Button {
        service.sendInterrupt(action: .resume)
    } label: {
        HStack {
            Image(systemName: "play.fill")
            Text("Resume")
        }
    }
    .disabled(!service.sessionInterrupted)
}
```

### 4. WatchService: Add interrupt methods
**File**: `ClaudeWatch/Services/WatchService.swift`

```swift
enum InterruptAction: String {
    case stop, resume
}

@Published var sessionInterrupted: Bool = false

func sendInterrupt(action: InterruptAction) async throws {
    let url = URL(string: "\(cloudServerURL)/session-interrupt")!
    // POST with pairingId and action
    // Update sessionInterrupted state based on response
}
```

## Resolved Decisions

### How interrupt works (DECIDED: PreToolUse hook blocks tools)
- **Stop**: PreToolUse hook checks interrupt state BEFORE each tool call
- When `action == "stop"`: Hook returns rejection with "Session paused from watch"
- Claude Code sees this as a user rejection - tools are blocked
- **Resume**: Clears interrupt state, next tool call proceeds normally
- No Claude Code changes needed - uses existing rejection mechanism

## Verification Criteria

- [ ] Stop button sends interrupt to worker
- [ ] Worker stores interrupt state in KV
- [ ] Hook checks for interrupt and responds appropriately
- [ ] Resume button clears interrupt state
- [ ] UI shows correct button states (Stop enabled when running, Resume when stopped)
- [ ] Haptic feedback on button taps

## Out of Scope

- Keyboard shortcuts on Mac
- Auto-resume after timeout
- Multiple concurrent interrupt requests
