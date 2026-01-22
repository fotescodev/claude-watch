# COMP5: Interactive Question Response from Watch

> **Status**: PLANNING
> **Blocker**: Cannot answer Claude's `AskUserQuestion` prompts from watch
> **Priority**: HIGH (blocks full Happy parity)

## The Problem

```
Claude Code                          Watch
    │                                  │
    ├─→ AskUserQuestion ─→ stdout      │ ← Can't see this
    │   "Which option? A/B/C"          │
    │                                  │
    ├─← stdin ← user types "A"         │ ← Can't inject this
    │                                  │
    └─→ PreToolUse (Bash) ─→ hook ────→│ ✓ Can see this
```

- `AskUserQuestion` outputs to stdout (no hook)
- User input comes from stdin (no hook)
- Watch can only intercept tool calls via hooks
- **Result**: Watch sees approvals but can't answer questions

## How Happy Solves This

Happy wraps the entire `claude` process:

```javascript
// happy-cli/src/claude/claudeLocal.ts
const child = spawn('node', [claudePath, ...args], {
  stdio: ['pipe', 'pipe', 'pipe', 'pipe'], // stdin, stdout, stderr, fd3
  ...
});

// Intercept ALL output
child.stdout.on('data', (data) => {
  const text = data.toString();

  // Detect question patterns
  if (isAskUserQuestion(text)) {
    // Forward to mobile app
    sendToMobile({ type: 'question', options: parseOptions(text) });
  }

  // Still show output locally
  process.stdout.write(data);
});

// Inject responses from mobile
onMobileResponse((answer) => {
  child.stdin.write(answer + '\n');
});
```

## Solution: cc-watch Launcher Mode

Transform cc-watch from a "monitor alongside" to a "launcher that wraps":

### Current Architecture
```
Terminal 1: claude (runs independently)
Terminal 2: cc-watch watch (monitors via hooks)
```

### New Architecture
```
Terminal 1: cc-watch run (spawns claude, intercepts I/O)
           └─→ claude (child process)
```

## Implementation Plan

### Phase 1: Basic Launcher (cc-watch run)

**File**: `claude-watch-npm/src/cli/run.ts` (NEW)

```typescript
import { spawn, ChildProcess } from 'child_process';
import { CloudClient } from '../cloud/client.js';

interface QuestionDetection {
  type: 'multiple_choice' | 'text_input' | 'confirmation';
  prompt: string;
  options?: string[];
}

export async function runClaudeWithWatch(args: string[]): Promise<void> {
  const config = readPairingConfig();
  if (!config?.pairingId) {
    console.error('Not paired. Run: npx cc-watch');
    process.exit(1);
  }

  const cloud = new CloudClient(config.cloudUrl, config.pairingId);

  // Spawn claude as child process
  const claude = spawn('claude', args, {
    stdio: ['pipe', 'pipe', 'pipe'],
    env: {
      ...process.env,
      CLAUDE_WATCH_SESSION_ACTIVE: '1',
    },
  });

  // Buffer for detecting multi-line questions
  let outputBuffer = '';

  // Intercept stdout
  claude.stdout.on('data', (data: Buffer) => {
    const text = data.toString();
    outputBuffer += text;

    // Check for question patterns
    const question = detectQuestion(outputBuffer);
    if (question) {
      // Send to watch via cloud
      sendQuestionToWatch(cloud, question);
      outputBuffer = ''; // Reset buffer
    }

    // Always pass through to terminal
    process.stdout.write(data);
  });

  // Intercept stderr (pass through)
  claude.stderr.on('data', (data: Buffer) => {
    process.stderr.write(data);
  });

  // Forward local stdin to claude (for local typing)
  process.stdin.pipe(claude.stdin);

  // Listen for watch responses
  cloud.onQuestionResponse((answer: string) => {
    // Inject answer into claude's stdin
    claude.stdin.write(answer + '\n');
    console.log(`\n[Watch answered: ${answer}]`);
  });

  // Handle exit
  claude.on('close', (code) => {
    process.exit(code ?? 0);
  });
}

function detectQuestion(text: string): QuestionDetection | null {
  // Pattern 1: Numbered options (AskUserQuestion)
  // "Which option?\n  1. Option A\n  2. Option B\n  3. Option C"
  const numberedMatch = text.match(
    /([^\n]+\?)\s*\n((?:\s*\d+\.\s+[^\n]+\n?)+)/
  );
  if (numberedMatch) {
    const prompt = numberedMatch[1];
    const optionsText = numberedMatch[2];
    const options = optionsText
      .split('\n')
      .map(line => line.replace(/^\s*\d+\.\s*/, '').trim())
      .filter(Boolean);

    return { type: 'multiple_choice', prompt, options };
  }

  // Pattern 2: Yes/No confirmation
  // "Do you want to proceed? (y/n)"
  const confirmMatch = text.match(/([^\n]+\?)\s*\(y\/n\)/i);
  if (confirmMatch) {
    return {
      type: 'confirmation',
      prompt: confirmMatch[1],
      options: ['Yes', 'No']
    };
  }

  return null;
}

async function sendQuestionToWatch(
  cloud: CloudClient,
  question: QuestionDetection
): Promise<void> {
  await cloud.sendQuestion({
    id: crypto.randomUUID(),
    type: question.type,
    prompt: question.prompt,
    options: question.options,
    timestamp: new Date().toISOString(),
  });
}
```

### Phase 2: Cloud Endpoints

**File**: `MCPServer/worker/src/index.ts`

Add new endpoints:

```typescript
// POST /question - CLI sends question to watch
if (request.method === 'POST' && url.pathname === '/question') {
  const { pairingId, question } = await request.json();

  // Store question
  await env.CLAUDE_WATCH_KV.put(
    `question:${pairingId}`,
    JSON.stringify(question),
    { expirationTtl: 300 } // 5 min expiry
  );

  // Send push notification
  await sendPushNotification(pairingId, {
    title: 'Claude needs input',
    body: question.prompt,
    category: 'CLAUDE_QUESTION',
    data: { questionId: question.id }
  });

  return jsonResponse({ success: true });
}

// GET /question/:pairingId - Watch polls for questions
if (request.method === 'GET' && url.pathname.startsWith('/question/')) {
  const pairingId = url.pathname.split('/')[2];
  const question = await env.CLAUDE_WATCH_KV.get(`question:${pairingId}`);

  return jsonResponse({ question: question ? JSON.parse(question) : null });
}

// POST /question-response - Watch sends answer
if (request.method === 'POST' && url.pathname === '/question-response') {
  const { pairingId, questionId, answer } = await request.json();

  // Store response for CLI to poll
  await env.CLAUDE_WATCH_KV.put(
    `answer:${pairingId}:${questionId}`,
    JSON.stringify({ answer, timestamp: Date.now() }),
    { expirationTtl: 60 }
  );

  // Clear the question
  await env.CLAUDE_WATCH_KV.delete(`question:${pairingId}`);

  return jsonResponse({ success: true });
}

// GET /question-response/:pairingId/:questionId - CLI polls for answer
if (request.method === 'GET' && url.pathname.match(/\/question-response\/[^/]+\/[^/]+/)) {
  const [, , pairingId, questionId] = url.pathname.split('/');
  const answer = await env.CLAUDE_WATCH_KV.get(`answer:${pairingId}:${questionId}`);

  if (answer) {
    // Delete after retrieval (one-time read)
    await env.CLAUDE_WATCH_KV.delete(`answer:${pairingId}:${questionId}`);
    return jsonResponse(JSON.parse(answer));
  }

  return jsonResponse({ answer: null });
}
```

### Phase 3: Watch UI for Questions

**File**: `ClaudeWatch/Views/QuestionView.swift` (NEW)

```swift
struct QuestionView: View {
    let question: PendingQuestion
    let onAnswer: (String) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Question prompt
                Text(question.prompt)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 8)

                // Options
                ForEach(Array(question.options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        onAnswer(String(index + 1)) // Send "1", "2", etc.
                    }) {
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(option)
                                .font(.body)
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
}
```

**File**: `ClaudeWatch/Services/WatchService.swift`

Add question handling:

```swift
// MARK: - Question Handling
@Published var pendingQuestion: PendingQuestion?

struct PendingQuestion: Identifiable {
    let id: String
    let type: String
    let prompt: String
    let options: [String]
    let timestamp: Date
}

func fetchPendingQuestion() async throws {
    let url = URL(string: "\(cloudServerURL)/question/\(pairingId)")!
    let (data, _) = try await urlSession.data(from: url)

    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let questionData = json["question"] as? [String: Any] else {
        pendingQuestion = nil
        return
    }

    pendingQuestion = PendingQuestion(
        id: questionData["id"] as? String ?? "",
        type: questionData["type"] as? String ?? "",
        prompt: questionData["prompt"] as? String ?? "",
        options: questionData["options"] as? [String] ?? [],
        timestamp: Date()
    )
}

func answerQuestion(_ questionId: String, answer: String) async throws {
    let url = URL(string: "\(cloudServerURL)/question-response")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "pairingId": pairingId,
        "questionId": questionId,
        "answer": answer
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (_, response) = try await urlSession.data(for: request)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else {
        throw CloudError.serverError(0)
    }

    pendingQuestion = nil
    playHaptic(.success)
}
```

### Phase 4: CLI Polling for Answers

**File**: `claude-watch-npm/src/cloud/client.ts`

```typescript
async pollForAnswer(questionId: string, timeoutMs: number = 60000): Promise<string | null> {
  const startTime = Date.now();

  while (Date.now() - startTime < timeoutMs) {
    const response = await fetch(
      `${this.cloudUrl}/question-response/${this.pairingId}/${questionId}`
    );

    if (response.ok) {
      const data = await response.json();
      if (data.answer) {
        return data.answer;
      }
    }

    // Poll every 500ms
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return null; // Timeout - user can still type locally
}
```

## Usage

```bash
# Old way (still works, but no question forwarding)
claude "fix the bug"

# New way (with watch question forwarding)
cc-watch run "fix the bug"

# Or just
cc-watch run
# Then interact with Claude normally
```

## Notification Category

Add to APNs categories:

```swift
let questionCategory = UNNotificationCategory(
    identifier: "CLAUDE_QUESTION",
    actions: [], // Dynamic based on options
    intentIdentifiers: [],
    options: [.customDismissAction]
)
```

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Pattern detection fails | Fall back to local typing |
| Latency too high | Show "answering from watch..." in CLI |
| Watch not responding | Timeout after 60s, allow local input |
| Multiple questions queued | Queue on cloud, process in order |

## Verification Criteria

- [ ] `cc-watch run` spawns claude as child process
- [ ] stdout intercepted, questions detected
- [ ] Questions forwarded to watch via cloud
- [ ] Watch displays question with tappable options
- [ ] Answer injected into claude's stdin
- [ ] Falls back gracefully if watch unavailable

## Dependencies

- COMP1 (SessionStart) - for session context ✅ Done
- COMP3 (E2E encryption) - encrypt questions ✅ Done

## Estimated Effort

| Phase | Complexity | Files |
|-------|------------|-------|
| Phase 1: CLI launcher | Medium | 2 new |
| Phase 2: Cloud endpoints | Low | 1 modified |
| Phase 3: Watch UI | Medium | 2 new |
| Phase 4: CLI polling | Low | 1 modified |

**Total**: ~4-6 hours of implementation
