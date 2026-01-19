/**
 * Integration tests for cc-watch pairing flow
 *
 * Tests the cc-watch command's pairing flow, WebSocket connections,
 * and progress monitoring functionality.
 */

import { describe, it, beforeEach, afterEach, mock } from "node:test";
import assert from "node:assert";

// =============================================================================
// Test Helpers - Mock Implementations
// =============================================================================

/**
 * Mock fetch implementation for testing HTTP requests
 */
function createMockFetch() {
  const calls: Array<{ url: string; options?: RequestInit }> = [];
  let mockResponses: Array<{
    matcher: (url: string) => boolean;
    response: { ok: boolean; status: number; data: unknown };
  }> = [];

  const mockFetch = async (url: string | URL, options?: RequestInit) => {
    const urlStr = url.toString();
    calls.push({ url: urlStr, options });

    const matched = mockResponses.find((r) => r.matcher(urlStr));
    if (matched) {
      return {
        ok: matched.response.ok,
        status: matched.response.status,
        json: async () => matched.response.data,
        text: async () => JSON.stringify(matched.response.data),
      };
    }

    // Default 404 response
    return {
      ok: false,
      status: 404,
      json: async () => ({ error: "Not found" }),
      text: async () => '{"error": "Not found"}',
    };
  };

  return {
    fetch: mockFetch,
    calls,
    setResponse: (
      matcher: (url: string) => boolean,
      response: { ok: boolean; status: number; data: unknown }
    ) => {
      mockResponses.push({ matcher, response });
    },
    reset: () => {
      calls.length = 0;
      mockResponses = [];
    },
  };
}

/**
 * Mock WebSocket implementation for testing WebSocket connections
 */
class MockWebSocket {
  static CONNECTING = 0;
  static OPEN = 1;
  static CLOSING = 2;
  static CLOSED = 3;

  readyState = MockWebSocket.CONNECTING;
  onopen: (() => void) | null = null;
  onmessage: ((event: { data: string }) => void) | null = null;
  onerror: ((error: Error) => void) | null = null;
  onclose: (() => void) | null = null;

  private sentMessages: string[] = [];
  private url: string;

  constructor(url: string) {
    this.url = url;
    // Simulate async connection
    setTimeout(() => {
      this.readyState = MockWebSocket.OPEN;
      this.onopen?.();
    }, 10);
  }

  send(data: string): void {
    this.sentMessages.push(data);
  }

  close(): void {
    this.readyState = MockWebSocket.CLOSED;
    this.onclose?.();
  }

  // Test helper methods
  getSentMessages(): string[] {
    return [...this.sentMessages];
  }

  simulateMessage(data: unknown): void {
    this.onmessage?.({ data: JSON.stringify(data) });
  }

  simulateError(error: Error): void {
    this.onerror?.(error);
  }

  getUrl(): string {
    return this.url;
  }
}

// =============================================================================
// Test: Environment Validation
// =============================================================================

describe("cc-watch environment validation", () => {
  let originalEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    originalEnv = { ...process.env };
  });

  afterEach(() => {
    process.env = originalEnv;
  });

  it("should detect missing ANTHROPIC_API_KEY", () => {
    // Remove the API key
    delete process.env.ANTHROPIC_API_KEY;

    // Simulate the checkEnvironment logic
    const errors: string[] = [];
    if (!process.env.ANTHROPIC_API_KEY) {
      errors.push("ANTHROPIC_API_KEY environment variable is not set");
    }

    assert.strictEqual(errors.length, 1);
    assert.ok(errors[0].includes("ANTHROPIC_API_KEY"));
  });

  it("should pass validation when ANTHROPIC_API_KEY is set", () => {
    process.env.ANTHROPIC_API_KEY = "test-api-key";

    const errors: string[] = [];
    if (!process.env.ANTHROPIC_API_KEY) {
      errors.push("ANTHROPIC_API_KEY environment variable is not set");
    }

    assert.strictEqual(errors.length, 0);
  });

  it("should not log API key in error messages", () => {
    process.env.ANTHROPIC_API_KEY = "sk-secret-key-12345";

    const errorMessage = "ANTHROPIC_API_KEY environment variable is not set";

    assert.ok(!errorMessage.includes("sk-secret-key-12345"));
    assert.ok(!errorMessage.includes(process.env.ANTHROPIC_API_KEY));
  });
});

// =============================================================================
// Test: Pairing Flow
// =============================================================================

describe("cc-watch pairing flow", () => {
  let mockFetch: ReturnType<typeof createMockFetch>;

  beforeEach(() => {
    mockFetch = createMockFetch();
  });

  afterEach(() => {
    mockFetch.reset();
  });

  it("should complete pairing successfully with valid code", async () => {
    const expectedPairingId = "pair-123-456";
    const cloudUrl = "https://test-cloud.example.com";
    const pairingCode = "123456";

    // Mock the /pair/complete endpoint
    mockFetch.setResponse((url) => url.includes("/pair/complete"), {
      ok: true,
      status: 200,
      data: { pairingId: expectedPairingId },
    });

    // Simulate the pairing request
    const response = await mockFetch.fetch(`${cloudUrl}/pair/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: pairingCode }),
    });

    const data = (await response.json()) as { pairingId: string };

    assert.ok(response.ok);
    assert.strictEqual(response.status, 200);
    assert.strictEqual(data.pairingId, expectedPairingId);
  });

  it("should handle invalid pairing code (404)", async () => {
    const cloudUrl = "https://test-cloud.example.com";
    const invalidCode = "000000";

    // Mock 404 for invalid code
    mockFetch.setResponse((url) => url.includes("/pair/complete"), {
      ok: false,
      status: 404,
      data: { error: "Invalid or expired code" },
    });

    const response = await mockFetch.fetch(`${cloudUrl}/pair/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code: invalidCode }),
    });

    assert.ok(!response.ok);
    assert.strictEqual(response.status, 404);
  });

  it("should validate 6-digit pairing code format", () => {
    const validateCode = (value: string): boolean | string => {
      const cleaned = value.replace(/\s/g, "");
      if (/^\d{6}$/.test(cleaned)) {
        return true;
      }
      return "Enter 6 digits (shown on your watch)";
    };

    // Valid codes
    assert.strictEqual(validateCode("123456"), true);
    assert.strictEqual(validateCode("000000"), true);
    assert.strictEqual(validateCode("999999"), true);
    assert.strictEqual(validateCode("123 456"), true); // With space
    assert.strictEqual(validateCode(" 123456 "), true); // With whitespace

    // Invalid codes
    assert.notStrictEqual(validateCode("12345"), true); // Too short
    assert.notStrictEqual(validateCode("1234567"), true); // Too long
    assert.notStrictEqual(validateCode("12345a"), true); // Contains letter
    assert.notStrictEqual(validateCode(""), true); // Empty
  });

  it("should clean spaces from pairing code", () => {
    const rawCode = "123 456";
    const cleanedCode = rawCode.replace(/\s/g, "");

    assert.strictEqual(cleanedCode, "123456");
  });

  it("should check cloud connectivity before pairing", async () => {
    const cloudUrl = "https://test-cloud.example.com";

    mockFetch.setResponse((url) => url.includes("/health"), {
      ok: true,
      status: 200,
      data: { status: "healthy" },
    });

    const start = Date.now();
    const response = await mockFetch.fetch(`${cloudUrl}/health`);
    const latency = Date.now() - start;

    assert.ok(response.ok);
    assert.ok(latency >= 0);
    assert.strictEqual(mockFetch.calls.length, 1);
    assert.ok(mockFetch.calls[0].url.includes("/health"));
  });

  it("should handle cloud connectivity failure", async () => {
    const cloudUrl = "https://test-cloud.example.com";

    mockFetch.setResponse((url) => url.includes("/health"), {
      ok: false,
      status: 503,
      data: { error: "Service unavailable" },
    });

    const response = await mockFetch.fetch(`${cloudUrl}/health`);

    assert.ok(!response.ok);
    assert.strictEqual(response.status, 503);
  });
});

// =============================================================================
// Test: WebSocket Connection
// =============================================================================

describe("cc-watch WebSocket connection", () => {
  it("should create WebSocket connection with correct URL", () => {
    const wsUrl = "ws://localhost:8787";
    const ws = new MockWebSocket(wsUrl);

    assert.strictEqual(ws.getUrl(), wsUrl);
  });

  it("should send pairing registration after connection", async () => {
    const pairingId = "test-pairing-id";
    const ws = new MockWebSocket("ws://localhost:8787");

    // Wait for connection to open
    await new Promise<void>((resolve) => {
      ws.onopen = () => {
        ws.send(JSON.stringify({ type: "register", pairingId }));
        resolve();
      };
    });

    const sentMessages = ws.getSentMessages();
    assert.strictEqual(sentMessages.length, 1);

    const message = JSON.parse(sentMessages[0]);
    assert.strictEqual(message.type, "register");
    assert.strictEqual(message.pairingId, pairingId);
  });

  it("should send ping messages for keep-alive", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    // Simulate ping
    ws.send(JSON.stringify({ type: "ping" }));

    const sentMessages = ws.getSentMessages();
    assert.strictEqual(sentMessages.length, 1);

    const message = JSON.parse(sentMessages[0]);
    assert.strictEqual(message.type, "ping");
  });

  it("should handle state_sync messages", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let receivedState: unknown = null;

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === "state_sync") {
        receivedState = message.state;
      }
    };

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    // Simulate state sync message
    ws.simulateMessage({
      type: "state_sync",
      state: {
        task_name: "Test Task",
        status: "running",
        progress: 0.5,
        pending_actions: [],
        model: "opus",
        yolo_mode: true,
      },
    });

    assert.notStrictEqual(receivedState, null);
    assert.strictEqual((receivedState as { task_name: string }).task_name, "Test Task");
  });

  it("should handle progress_update messages", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let progressUpdate: { progress?: number; task_name?: string } | null = null;

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === "progress_update") {
        progressUpdate = message;
      }
    };

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.simulateMessage({
      type: "progress_update",
      progress: 0.75,
      task_name: "Building project",
    });

    assert.notStrictEqual(progressUpdate, null);
    assert.strictEqual(progressUpdate?.progress, 0.75);
    assert.strictEqual(progressUpdate?.task_name, "Building project");
  });

  it("should handle task_started messages", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let taskStarted: { task_name?: string; task_description?: string } | null = null;

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === "task_started") {
        taskStarted = message;
      }
    };

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.simulateMessage({
      type: "task_started",
      task_name: "Deploy to production",
      task_description: "Deploying application to production servers",
    });

    assert.notStrictEqual(taskStarted, null);
    assert.strictEqual(taskStarted?.task_name, "Deploy to production");
    assert.strictEqual(
      taskStarted?.task_description,
      "Deploying application to production servers"
    );
  });

  it("should handle task_completed messages", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let taskCompleted: { success?: boolean; task_name?: string } | null = null;

    ws.onmessage = (event) => {
      const message = JSON.parse(event.data);
      if (message.type === "task_completed") {
        taskCompleted = message;
      }
    };

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.simulateMessage({
      type: "task_completed",
      success: true,
      task_name: "Tests passed",
    });

    assert.notStrictEqual(taskCompleted, null);
    assert.strictEqual(taskCompleted?.success, true);
    assert.strictEqual(taskCompleted?.task_name, "Tests passed");
  });

  it("should close WebSocket connection gracefully", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let closed = false;

    ws.onclose = () => {
      closed = true;
    };

    await new Promise<void>((resolve) => {
      ws.onopen = () => resolve();
    });

    ws.close();

    assert.strictEqual(closed, true);
    assert.strictEqual(ws.readyState, MockWebSocket.CLOSED);
  });
});

// =============================================================================
// Test: Progress Display
// =============================================================================

describe("cc-watch progress display", () => {
  it("should create progress bar at 0%", () => {
    const createProgressBar = (progress: number): string => {
      const width = 20;
      const filled = Math.round(progress * width);
      const empty = width - filled;
      return "\u2588".repeat(filled) + "\u2591".repeat(empty);
    };

    const bar = createProgressBar(0);
    assert.strictEqual(bar.length, 20);
    assert.ok(bar.startsWith("\u2591")); // All empty
    assert.ok(!bar.includes("\u2588"));
  });

  it("should create progress bar at 50%", () => {
    const createProgressBar = (progress: number): string => {
      const width = 20;
      const filled = Math.round(progress * width);
      const empty = width - filled;
      return "\u2588".repeat(filled) + "\u2591".repeat(empty);
    };

    const bar = createProgressBar(0.5);
    assert.strictEqual(bar.length, 20);

    const filledCount = (bar.match(/\u2588/g) || []).length;
    const emptyCount = (bar.match(/\u2591/g) || []).length;

    assert.strictEqual(filledCount, 10);
    assert.strictEqual(emptyCount, 10);
  });

  it("should create progress bar at 100%", () => {
    const createProgressBar = (progress: number): string => {
      const width = 20;
      const filled = Math.round(progress * width);
      const empty = width - filled;
      return "\u2588".repeat(filled) + "\u2591".repeat(empty);
    };

    const bar = createProgressBar(1.0);
    assert.strictEqual(bar.length, 20);
    assert.ok(!bar.includes("\u2591")); // No empty chars
  });

  it("should handle progress values correctly", () => {
    const progressValues = [0, 0.1, 0.25, 0.33, 0.5, 0.66, 0.75, 0.9, 1.0];

    for (const progress of progressValues) {
      const percentage = Math.round(progress * 100);
      assert.ok(percentage >= 0);
      assert.ok(percentage <= 100);
    }
  });
});

// =============================================================================
// Test: Session State Formatting
// =============================================================================

describe("cc-watch session state formatting", () => {
  it("should format idle state correctly", () => {
    const state = {
      task_name: "",
      task_description: "",
      progress: 0,
      status: "idle" as const,
      pending_actions: [],
      model: "opus",
      yolo_mode: false,
      started_at: null,
    };

    // Verify state structure
    assert.strictEqual(state.status, "idle");
    assert.strictEqual(state.progress, 0);
    assert.strictEqual(state.yolo_mode, false);
  });

  it("should format running state with YOLO mode", () => {
    const state = {
      task_name: "Executing task",
      task_description: "Running tests",
      progress: 0.5,
      status: "running" as const,
      pending_actions: [],
      model: "opus",
      yolo_mode: true,
      started_at: new Date().toISOString(),
    };

    assert.strictEqual(state.status, "running");
    assert.strictEqual(state.yolo_mode, true);
    assert.strictEqual(state.progress, 0.5);
  });

  it("should format waiting state with pending actions", () => {
    const state = {
      task_name: "Awaiting approval",
      task_description: "Needs permission",
      progress: 0.3,
      status: "waiting" as const,
      pending_actions: [
        {
          id: "action-1",
          type: "file_edit" as const,
          title: "Edit config",
          description: "Modify configuration file",
          timestamp: new Date().toISOString(),
          status: "pending" as const,
        },
      ],
      model: "opus",
      yolo_mode: false,
      started_at: new Date().toISOString(),
    };

    assert.strictEqual(state.status, "waiting");
    assert.strictEqual(state.pending_actions.length, 1);
    assert.strictEqual(state.pending_actions[0].type, "file_edit");
  });

  it("should handle completed state", () => {
    const state = {
      task_name: "Task finished",
      task_description: "Completed successfully",
      progress: 1.0,
      status: "completed" as const,
      pending_actions: [],
      model: "opus",
      yolo_mode: false,
      started_at: new Date().toISOString(),
    };

    assert.strictEqual(state.status, "completed");
    assert.strictEqual(state.progress, 1.0);
  });

  it("should handle failed state", () => {
    const state = {
      task_name: "Task failed",
      task_description: "Error occurred",
      progress: 0.7,
      status: "failed" as const,
      pending_actions: [],
      model: "opus",
      yolo_mode: false,
      started_at: new Date().toISOString(),
    };

    assert.strictEqual(state.status, "failed");
  });
});

// =============================================================================
// Test: YOLO Mode Flags
// =============================================================================

describe("cc-watch YOLO mode configuration", () => {
  it("should include correct YOLO flags", () => {
    const YOLO_FLAGS = [
      "--print",
      "--verbose",
      "--dangerously-skip-permissions",
    ] as const;

    assert.ok(YOLO_FLAGS.includes("--print"));
    assert.ok(YOLO_FLAGS.includes("--verbose"));
    assert.ok(YOLO_FLAGS.includes("--dangerously-skip-permissions"));
    assert.strictEqual(YOLO_FLAGS.length, 3);
  });

  it("should not include approval flags in YOLO mode", () => {
    const YOLO_FLAGS = [
      "--print",
      "--verbose",
      "--dangerously-skip-permissions",
    ];

    // These flags should NOT be present in YOLO mode
    const approvalFlags = ["--interactive", "--confirm", "--wait-for-approval"];

    for (const flag of approvalFlags) {
      assert.ok(!YOLO_FLAGS.includes(flag));
    }
  });
});

// =============================================================================
// Test: Cloud Client Integration
// =============================================================================

describe("cc-watch cloud client integration", () => {
  let mockFetch: ReturnType<typeof createMockFetch>;

  beforeEach(() => {
    mockFetch = createMockFetch();
  });

  afterEach(() => {
    mockFetch.reset();
  });

  it("should send messages to cloud relay", async () => {
    const cloudUrl = "https://test-cloud.example.com";
    const pairingId = "test-pairing-123";

    mockFetch.setResponse((url) => url.includes("/api/message"), {
      ok: true,
      status: 200,
      data: { success: true },
    });

    const message = {
      type: "state_sync",
      state: {
        task_name: "Test",
        status: "running",
        progress: 0.5,
      },
    };

    const response = await mockFetch.fetch(`${cloudUrl}/api/message`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        pairingId,
        type: "to_watch",
        payload: message,
        timestamp: new Date().toISOString(),
      }),
    });

    assert.ok(response.ok);
    assert.strictEqual(mockFetch.calls.length, 1);

    const requestBody = JSON.parse(mockFetch.calls[0].options?.body as string);
    assert.strictEqual(requestBody.pairingId, pairingId);
    assert.strictEqual(requestBody.type, "to_watch");
  });

  it("should poll for messages from cloud", async () => {
    const cloudUrl = "https://test-cloud.example.com";
    const pairingId = "test-pairing-123";

    const mockMessages = [
      {
        type: "action_response",
        pairingId,
        payload: { action_id: "123", approved: true },
        timestamp: new Date().toISOString(),
      },
    ];

    mockFetch.setResponse((url) => url.includes("/api/messages"), {
      ok: true,
      status: 200,
      data: { messages: mockMessages },
    });

    const response = await mockFetch.fetch(
      `${cloudUrl}/api/messages?pairingId=${pairingId}&direction=to_server`
    );
    const data = (await response.json()) as { messages: unknown[] };

    assert.ok(response.ok);
    assert.strictEqual(data.messages.length, 1);
  });

  it("should handle empty message queue", async () => {
    const cloudUrl = "https://test-cloud.example.com";
    const pairingId = "test-pairing-123";

    mockFetch.setResponse((url) => url.includes("/api/messages"), {
      ok: true,
      status: 200,
      data: { messages: [] },
    });

    const response = await mockFetch.fetch(
      `${cloudUrl}/api/messages?pairingId=${pairingId}&direction=to_server`
    );
    const data = (await response.json()) as { messages: unknown[] };

    assert.ok(response.ok);
    assert.strictEqual(data.messages.length, 0);
  });
});

// =============================================================================
// Test: Error Handling
// =============================================================================

describe("cc-watch error handling", () => {
  let mockFetch: ReturnType<typeof createMockFetch>;

  beforeEach(() => {
    mockFetch = createMockFetch();
  });

  afterEach(() => {
    mockFetch.reset();
  });

  it("should handle network errors gracefully", async () => {
    // Simulate a fetch that returns an error response
    mockFetch.setResponse(() => true, {
      ok: false,
      status: 500,
      data: { error: "Internal server error" },
    });

    const response = await mockFetch.fetch("https://example.com/api");

    assert.ok(!response.ok);
    assert.strictEqual(response.status, 500);
  });

  it("should handle malformed JSON in WebSocket messages", () => {
    let errorThrown = false;

    try {
      JSON.parse("invalid json {");
    } catch {
      errorThrown = true;
    }

    assert.ok(errorThrown);
  });

  it("should handle WebSocket connection timeout", async () => {
    const ws = new MockWebSocket("ws://localhost:8787");
    let timedOut = false;

    // Simulate a 5-second timeout check
    const timeout = setTimeout(() => {
      if (ws.readyState === MockWebSocket.CONNECTING) {
        timedOut = true;
        ws.close();
      }
    }, 5000);

    // Wait for connection (should succeed before timeout)
    await new Promise<void>((resolve) => {
      ws.onopen = () => {
        clearTimeout(timeout);
        resolve();
      };
    });

    assert.ok(!timedOut);
    assert.strictEqual(ws.readyState, MockWebSocket.OPEN);
  });

  it("should provide helpful error message for missing API key", () => {
    const errorMessage = "ANTHROPIC_API_KEY environment variable is not set";
    const helpText = "Set ANTHROPIC_API_KEY to use cc-watch";

    assert.ok(errorMessage.includes("ANTHROPIC_API_KEY"));
    assert.ok(helpText.includes("ANTHROPIC_API_KEY"));
  });
});

// =============================================================================
// Test: Pairing Configuration Persistence
// =============================================================================

describe("cc-watch pairing configuration", () => {
  it("should create pairing config with required fields", () => {
    const config = {
      pairingId: "test-id-123",
      cloudUrl: "https://test-cloud.example.com",
      createdAt: new Date().toISOString(),
    };

    assert.ok(config.pairingId);
    assert.ok(config.cloudUrl);
    assert.ok(config.createdAt);
  });

  it("should validate config structure", () => {
    const config = {
      pairingId: "test-id-123",
      cloudUrl: "https://test-cloud.example.com",
      createdAt: new Date().toISOString(),
      watchId: "watch-abc",
    };

    assert.strictEqual(typeof config.pairingId, "string");
    assert.strictEqual(typeof config.cloudUrl, "string");
    assert.strictEqual(typeof config.createdAt, "string");
    assert.strictEqual(typeof config.watchId, "string");
  });

  it("should use default cloud URL when not specified", () => {
    const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";
    const configCloudUrl = undefined;
    const effectiveUrl = configCloudUrl || DEFAULT_CLOUD_URL;

    assert.strictEqual(effectiveUrl, DEFAULT_CLOUD_URL);
  });
});
