# Phase 10 Research: Happy Coder Implementation Analysis

## Executive Summary

Happy Coder solves the same problem we're trying to solve (answering Claude questions from mobile), but uses a fundamentally different approach: **SDK/streaming JSON mode** instead of trying to inject into the terminal UI.

## Key Findings

### 1. They DON'T Use Hooks for Permissions/Questions

Instead of PreToolUse hooks, they use Claude Code's **streaming JSON SDK**:

```typescript
// query.ts - lines 287-298
const args = ['--output-format', 'stream-json', '--verbose']
// ...
if (canCallTool) {
    args.push('--permission-prompt-tool', 'stdio')  // KEY FLAG
}
args.push('--input-format', 'stream-json')
```

### 2. Claude Sends Permission Requests as JSON Messages

When Claude needs permission, it sends a `control_request`:

```typescript
// query.ts - lines 101-103
} else if (message.type === 'control_request') {
    await this.handleControlRequest(message as unknown as CanUseToolControlRequest)
    continue
}
```

### 3. They Respond with JSON Control Responses

```typescript
// query.ts - lines 184-194
const response = await this.processControlRequest(request, controller.signal)
const controlResponse: CanUseToolControlResponse = {
    type: 'control_response',
    response: {
        subtype: 'success',
        request_id: request.request_id,
        response  // Contains { behavior: 'allow' } or { behavior: 'deny' }
    }
}
this.childStdin.write(JSON.stringify(controlResponse) + '\n')
```

### 4. PermissionHandler Waits for Mobile Response

```typescript
// permissionHandler.ts - lines 203-213
// Send push notification
this.session.api.push().sendToAllDevices(
    'Permission Request',
    `Claude wants to ${getToolName(toolName)}`,
    { sessionId, requestId, tool, type: 'permission_request' }
);

// Update agent state (mobile polls this)
this.session.client.updateAgentState((currentState) => ({
    ...currentState,
    requests: { ...currentState.requests, [id]: { tool, arguments, createdAt } }
}));
```

### 5. RPC Handler Receives Mobile Response

```typescript
// permissionHandler.ts - lines 378-395
this.session.client.rpcHandlerManager.registerHandler<PermissionResponse, void>('permission', async (message) => {
    const pending = this.pendingRequests.get(message.id);
    // ...
    this.handlePermissionResponse(message, pending);
});
```

## Architecture Comparison

### Our Current Approach (Broken)
```
Claude CLI (interactive)
    ↓
PreToolUse Hook intercepts AskUserQuestion
    ↓
Hook sends to cloud, waits for watch answer
    ↓
Hook writes answer to file
    ↓
StdinProxy tries to inject into terminal
    ↓
❌ FAILS - terminal UI already rendered, timing issues
```

### Happy Coder Approach (Working)
```
Claude CLI (SDK mode: --output-format stream-json)
    ↓
Claude sends control_request JSON via stdout
    ↓
CLI parses JSON, sends to mobile via RPC/push
    ↓
Mobile user responds
    ↓
CLI sends control_response JSON via stdin
    ↓
✅ Claude receives response and continues
```

## Key Differences

| Aspect | Our Approach | Happy Coder |
|--------|--------------|-------------|
| Claude Mode | Interactive (TTY) | SDK (stream-json) |
| Permission Handling | PreToolUse hooks | `--permission-prompt-tool stdio` |
| Question Handling | Try to inject stdin | JSON control messages |
| UI | Claude's built-in TUI | Custom UI or none |
| Complexity | High (timing, injection) | Low (clean JSON protocol) |

## Required Changes for Phase 10

### Option A: Adopt SDK Approach (Recommended)

1. **Use `--output-format stream-json --input-format stream-json`**
   - No terminal UI to fight with
   - Clean JSON message protocol

2. **Use `--permission-prompt-tool stdio`**
   - Permissions come as `control_request` messages
   - We respond with `control_response`

3. **Build Custom UI (or headless)**
   - Either show our own progress UI
   - Or run headless with watch as the only UI

4. **Handle control_request messages**
   - Parse `can_use_tool` requests
   - Send to watch via cloud
   - Wait for response
   - Send `control_response` back

### Option B: Keep Hooks but Fix Injection

1. Don't try to inject into interactive UI
2. Use `--print` mode for non-interactive execution
3. Questions become blocking hook calls
4. This limits interactivity

## Code References

- **SDK Query**: `/tmp/happy-research/happy-main/cli/src/claude/sdk/query.ts`
- **Permission Handler**: `/tmp/happy-research/happy-main/cli/src/claude/utils/permissionHandler.ts`
- **Types**: `/tmp/happy-research/happy-main/cli/src/claude/sdk/types.ts`

## Next Steps

1. [ ] Research Claude Code's `--permission-prompt-tool stdio` documentation
2. [ ] Prototype SDK mode in cc-watch
3. [ ] Implement control_request/control_response handling
4. [ ] Update watch app to work with new message format
5. [ ] Test end-to-end question flow

## Files to Study

```
/tmp/happy-research/happy-main/cli/src/claude/
├── sdk/
│   ├── query.ts          # Core SDK interaction
│   ├── types.ts          # Message types
│   └── utils.ts          # Helpers
├── utils/
│   └── permissionHandler.ts  # Mobile permission handling
├── runClaude.ts          # Main entry point
└── loop.ts               # Session loop
```

## Important: No API Costs

Happy Coder does **NOT** call the Anthropic API directly. They still use the **Claude CLI** but with streaming JSON flags:

```bash
# They spawn this (not direct API calls):
claude --output-format stream-json --input-format stream-json --permission-prompt-tool stdio "prompt"
```

This means:
- ✅ Uses your existing Claude subscription
- ✅ No additional API costs
- ✅ Same claude CLI binary, just different output mode
- ✅ All the existing Claude features work

The "SDK" is just a TypeScript wrapper around the CLI with JSON parsing.

## Conclusion

Our current approach of trying to inject answers into Claude's interactive terminal is fundamentally flawed. Happy Coder shows the correct approach: use Claude's CLI with streaming JSON mode where permissions and questions are handled via clean JSON messages, not terminal UI manipulation.

**Recommendation**: Pivot to streaming JSON approach for Phase 10.

**Key constraint**: Must continue using Claude CLI (no direct API), just with `--output-format stream-json` flags.
