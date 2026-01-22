/**
 * Streaming Claude Runner
 *
 * Uses Claude CLI with `--output-format stream-json` to get clean JSON protocol
 * for permission requests. This replaces the broken stdin-injection approach.
 *
 * Key insight from Happy Coder: You can't inject answers into Claude's interactive
 * terminal UI. Instead, use SDK/streaming mode where Claude sends JSON requests
 * and receives JSON responses.
 *
 * Protocol:
 * - Claude CLI with: --output-format stream-json --input-format stream-json --permission-prompt-tool stdio
 * - Claude sends: {"type": "control_request", "request_id": "...", "request": {"subtype": "can_use_tool", ...}}
 * - We respond: {"type": "control_response", "response": {"subtype": "success", "request_id": "...", "response": {...}}}
 */

import { spawn, type ChildProcess } from "child_process";
import { createInterface, type Interface } from "readline";
import chalk from "chalk";
import { readPairingConfig, getPairingId } from "../config/pairing-store.js";

// Default cloud URL
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";

// Types based on Claude SDK protocol
interface ControlRequest {
  type: "control_request";
  request_id: string;
  request: {
    subtype: "can_use_tool";
    tool_name: string;
    input: unknown;
  };
}

interface ControlCancelRequest {
  type: "control_cancel_request";
  request_id: string;
}

interface ControlResponse {
  type: "control_response";
  response: {
    subtype: "success" | "error";
    request_id: string;
    response?: PermissionResult;
    error?: string;
  };
}

interface PermissionResult {
  behavior: "allow" | "deny";
  updatedInput?: Record<string, unknown>;
  message?: string;
}

interface SDKMessage {
  type: string;
  [key: string]: unknown;
}

interface PendingRequest {
  requestId: string;
  toolName: string;
  input: unknown;
  resolve: (result: PermissionResult) => void;
  reject: (error: Error) => void;
  abortController: AbortController;
}

/**
 * Streaming Claude Runner
 *
 * Spawns Claude with streaming JSON mode and handles permission requests
 * by forwarding to the watch via cloud relay.
 */
export class StreamingClaudeRunner {
  private claudeProcess: ChildProcess | null = null;
  private readline: Interface | null = null;
  private pendingRequests = new Map<string, PendingRequest>();
  private pairingId: string | null = null;
  private cloudUrl: string;
  private pollInterval: NodeJS.Timeout | null = null;
  private isRunning = false;
  private outputCallback: ((message: SDKMessage) => void) | null = null;

  constructor(cloudUrl?: string) {
    this.cloudUrl = cloudUrl || DEFAULT_CLOUD_URL;
    this.pairingId = getPairingId();
  }

  /**
   * Start Claude with streaming JSON mode
   */
  async start(prompt: string, options?: {
    onOutput?: (message: SDKMessage) => void;
    onText?: (text: string) => void;
  }): Promise<number> {
    if (!this.pairingId) {
      const config = readPairingConfig();
      this.pairingId = config?.pairingId || null;
    }

    if (!this.pairingId) {
      console.error(chalk.red("Not paired. Run 'npx cc-watch' first to pair."));
      return 1;
    }

    this.outputCallback = options?.onOutput || null;
    this.isRunning = true;

    // Build Claude args with streaming JSON mode
    // KEY FLAGS:
    // - --output-format stream-json: Claude sends JSON messages to stdout
    // - --input-format stream-json: We send JSON messages via stdin (required for --permission-prompt-tool)
    // - --permission-prompt-tool stdio: Claude sends permission requests as control_request JSON
    // - --permission-mode default: Claude asks for permission on tool use
    const args = [
      "--output-format", "stream-json",
      "--input-format", "stream-json",
      "--permission-prompt-tool", "stdio",
      "--permission-mode", "default",
      "--verbose",
    ];

    console.error(chalk.dim(`[StreamingClaude] Starting with args: claude ${args.join(" ")}`));
    console.error(chalk.dim(`[StreamingClaude] Pairing ID: ${this.pairingId}`));

    // Spawn Claude process
    this.claudeProcess = spawn("claude", args, {
      stdio: ["pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
      },
    });

    // Handle stderr (for debugging)
    this.claudeProcess.stderr?.on("data", (data: Buffer) => {
      const text = data.toString();
      if (options?.onText) {
        options.onText(text);
      }
      // Log stderr in dim
      console.error(chalk.dim(text.trim()));
    });

    // Read JSON messages from stdout line by line
    this.readline = createInterface({
      input: this.claudeProcess.stdout!,
      crlfDelay: Infinity,
    });

    // Process messages
    this.processMessages();

    // Start polling for watch responses
    this.startPollingWatchResponses();

    // Send the initial user message via stdin (required for --input-format stream-json mode)
    // Small delay to ensure process is ready
    await new Promise(resolve => setTimeout(resolve, 100));
    this.sendUserMessage(prompt);

    // Wait for process to complete
    return new Promise((resolve) => {
      this.claudeProcess?.on("close", (code) => {
        this.cleanup();
        resolve(code ?? 0);
      });

      this.claudeProcess?.on("error", (error) => {
        console.error(chalk.red(`Failed to start Claude: ${error.message}`));
        this.cleanup();
        resolve(1);
      });
    });
  }

  /**
   * Send a user message to Claude
   */
  private sendUserMessage(content: string): void {
    const message = {
      type: "user",
      message: {
        role: "user",
        content: content,
      },
    };
    this.writeToStdin(message);
  }

  /**
   * Process JSON messages from Claude's stdout
   */
  private async processMessages(): Promise<void> {
    if (!this.readline) return;

    for await (const line of this.readline) {
      if (!line.trim()) continue;

      try {
        const message = JSON.parse(line) as SDKMessage;
        await this.handleMessage(message);
      } catch (e) {
        // Not valid JSON - might be raw output
        console.error(chalk.dim(`[Non-JSON]: ${line}`));
      }
    }
  }

  /**
   * Handle a message from Claude
   */
  private async handleMessage(message: SDKMessage): Promise<void> {
    // Log message type for debugging
    console.error(chalk.dim(`[Claude] Message type: ${message.type}`));

    if (message.type === "control_request") {
      await this.handleControlRequest(message as unknown as ControlRequest);
    } else if (message.type === "control_cancel_request") {
      this.handleControlCancelRequest(message as unknown as ControlCancelRequest);
    } else if (message.type === "control_response") {
      // Response to our own requests - ignore
    } else {
      // Forward other messages to callback
      if (this.outputCallback) {
        this.outputCallback(message);
      }

      // Pretty print assistant messages
      if (message.type === "assistant") {
        this.printAssistantMessage(message);
      } else if (message.type === "result") {
        this.printResultMessage(message);
      }
    }
  }

  /**
   * Handle a control request (permission request) from Claude
   */
  private async handleControlRequest(request: ControlRequest): Promise<void> {
    const { request_id, request: req } = request;

    if (req.subtype !== "can_use_tool") {
      console.error(chalk.yellow(`[StreamingClaude] Unknown control request subtype: ${req.subtype}`));
      return;
    }

    const toolName = req.tool_name;
    const input = req.input;

    console.error(chalk.cyan(`[StreamingClaude] Permission request: ${toolName}`));
    console.error(chalk.dim(`[StreamingClaude] Input: ${JSON.stringify(input).slice(0, 200)}...`));

    // Create abort controller for this request
    const abortController = new AbortController();

    // Create promise for response
    const resultPromise = new Promise<PermissionResult>((resolve, reject) => {
      this.pendingRequests.set(request_id, {
        requestId: request_id,
        toolName,
        input,
        resolve,
        reject,
        abortController,
      });
    });

    // Send to watch via cloud
    await this.sendToWatch(request_id, toolName, input);

    // Wait for response
    try {
      const result = await resultPromise;
      this.sendControlResponse(request_id, result);
    } catch (error) {
      this.sendControlError(request_id, (error as Error).message);
    }
  }

  /**
   * Handle a control cancel request
   */
  private handleControlCancelRequest(request: ControlCancelRequest): void {
    const pending = this.pendingRequests.get(request.request_id);
    if (pending) {
      pending.abortController.abort();
      pending.reject(new Error("Request cancelled by Claude"));
      this.pendingRequests.delete(request.request_id);
    }
  }

  /**
   * Send permission request to watch via cloud
   */
  private async sendToWatch(requestId: string, toolName: string, input: unknown): Promise<void> {
    if (!this.pairingId) return;

    try {
      // AskUserQuestion uses the /question endpoint for multi-choice
      if (toolName === "AskUserQuestion") {
        await this.sendQuestionToWatch(requestId, input);
        return;
      }

      // Other tools use the /approval endpoint
      const description = this.formatToolDescription(toolName, input);
      const response = await fetch(`${this.cloudUrl}/approval`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          pairingId: this.pairingId,
          id: requestId,
          type: toolName.toLowerCase(),
          title: `Claude wants to use ${toolName}`,
          description,
        }),
      });

      if (!response.ok) {
        console.error(chalk.yellow(`[StreamingClaude] Failed to send to watch: ${response.status}`));
      } else {
        console.error(chalk.green(`[StreamingClaude] Sent to watch, waiting for response...`));
      }
    } catch (error) {
      console.error(chalk.red(`[StreamingClaude] Failed to send to watch: ${(error as Error).message}`));
    }
  }

  /**
   * Send AskUserQuestion to watch via /question endpoint
   */
  private async sendQuestionToWatch(requestId: string, input: unknown): Promise<void> {
    const inputObj = input as {
      questions?: Array<{
        question: string;
        header?: string;
        options: Array<{ label: string; description?: string }>;
        multiSelect?: boolean;
      }>;
    };

    const questions = inputObj.questions || [];
    if (questions.length === 0) {
      console.error(chalk.yellow("[StreamingClaude] AskUserQuestion has no questions"));
      return;
    }

    // Send the first question (Claude typically asks one at a time)
    const q = questions[0];

    const response = await fetch(`${this.cloudUrl}/question`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: requestId,
        pairingId: this.pairingId,
        question: q.question,
        header: q.header || null,
        options: q.options.map(opt => ({
          label: opt.label,
          description: opt.description || null,
        })),
        multiSelect: q.multiSelect || false,
      }),
    });

    if (!response.ok) {
      console.error(chalk.yellow(`[StreamingClaude] Failed to send question: ${response.status}`));
    } else {
      console.error(chalk.green(`[StreamingClaude] Question sent to watch, waiting for answer...`));
    }
  }

  /**
   * Format tool description for display
   */
  private formatToolDescription(toolName: string, input: unknown): string {
    const inputObj = input as Record<string, unknown>;

    switch (toolName) {
      case "Bash":
        return inputObj.command as string || "Execute command";
      case "Write":
      case "Edit":
      case "MultiEdit":
        return `${inputObj.file_path || "file"}`;
      case "Read":
        return `Read ${inputObj.file_path || "file"}`;
      case "AskUserQuestion":
        // Return the question text
        if (inputObj.questions && Array.isArray(inputObj.questions)) {
          const q = inputObj.questions[0] as { question?: string };
          return q?.question || "Claude has a question";
        }
        return "Claude has a question";
      default:
        return JSON.stringify(input).slice(0, 100);
    }
  }

  /**
   * Start polling for watch responses
   */
  private startPollingWatchResponses(): void {
    if (!this.pairingId) return;

    this.pollInterval = setInterval(async () => {
      if (!this.isRunning || this.pendingRequests.size === 0) return;

      // Poll each pending request for its status
      for (const [requestId, pending] of this.pendingRequests.entries()) {
        try {
          // AskUserQuestion uses /question endpoint
          if (pending.toolName === "AskUserQuestion") {
            await this.pollQuestionResponse(requestId, pending);
          } else {
            // Other tools use /approval endpoint
            await this.pollApprovalResponse(requestId, pending);
          }
        } catch (error) {
          // Polling error - ignore and retry next interval
        }
      }
    }, 500);
  }

  /**
   * Poll for question answer
   */
  private async pollQuestionResponse(requestId: string, pending: PendingRequest): Promise<void> {
    const response = await fetch(
      `${this.cloudUrl}/question/${requestId}`,
      { method: "GET" }
    );

    if (response.ok) {
      const data = await response.json() as {
        status: string;
        selectedIndices: number[] | null;
      };

      if (data.status === "answered" && data.selectedIndices) {
        console.error(chalk.green(`[StreamingClaude] Question answered: ${data.selectedIndices}`));
        this.handleQuestionAnswer(requestId, data.selectedIndices);
      } else if (data.status === "skipped") {
        console.error(chalk.yellow(`[StreamingClaude] Question skipped`));
        this.handleWatchResponse(requestId, false);
      }
      // If status is "pending", keep polling
    }
  }

  /**
   * Poll for approval response
   */
  private async pollApprovalResponse(requestId: string, pending: PendingRequest): Promise<void> {
    const response = await fetch(
      `${this.cloudUrl}/approval/${this.pairingId}/${requestId}`,
      { method: "GET" }
    );

    if (response.ok) {
      const data = await response.json() as {
        id: string;
        status: string;
        type: string;
        title: string;
      };

      if (data.status === "approved") {
        this.handleWatchResponse(requestId, true);
      } else if (data.status === "rejected") {
        this.handleWatchResponse(requestId, false);
      }
      // If status is "pending", keep polling
    }
  }

  /**
   * Handle a question answer from the watch
   */
  private handleQuestionAnswer(requestId: string, selectedIndices: number[]): void {
    const pending = this.pendingRequests.get(requestId);
    if (!pending) return;

    console.error(chalk.green(`[StreamingClaude] Watch answered question with indices: ${selectedIndices}`));

    // Remove from pending
    this.pendingRequests.delete(requestId);

    // Resolve with the selected answer
    // For AskUserQuestion, we need to pass the answers in the updatedInput
    pending.resolve({
      behavior: "allow",
      updatedInput: {
        ...(pending.input as Record<string, unknown>),
        answers: { [requestId]: selectedIndices.map(i => String(i)) },
      },
    });
  }

  /**
   * Handle a response from the watch
   */
  private handleWatchResponse(requestId: string, approved: boolean, answer?: string | number): void {
    const pending = this.pendingRequests.get(requestId);
    if (!pending) return;

    console.error(chalk.green(`[StreamingClaude] Watch response: ${approved ? "APPROVED" : "REJECTED"}`));

    // Remove from pending
    this.pendingRequests.delete(requestId);

    // Resolve the promise
    if (approved) {
      // For AskUserQuestion, we need to handle the answer specially
      let updatedInput = pending.input as Record<string, unknown>;

      if (pending.toolName === "AskUserQuestion" && answer !== undefined) {
        // The answer is the selected option index or custom text
        // Update the input with the answer
        updatedInput = { ...updatedInput, _watchAnswer: answer };
      }

      pending.resolve({
        behavior: "allow",
        updatedInput,
      });
    } else {
      pending.resolve({
        behavior: "deny",
        message: "User rejected from Apple Watch",
      });
    }
  }

  /**
   * Send a control response to Claude
   */
  private sendControlResponse(requestId: string, result: PermissionResult): void {
    const response: ControlResponse = {
      type: "control_response",
      response: {
        subtype: "success",
        request_id: requestId,
        response: result,
      },
    };
    this.writeToStdin(response);
    console.error(chalk.green(`[StreamingClaude] Sent response: ${result.behavior}`));
  }

  /**
   * Send a control error to Claude
   */
  private sendControlError(requestId: string, error: string): void {
    const response: ControlResponse = {
      type: "control_response",
      response: {
        subtype: "error",
        request_id: requestId,
        error,
      },
    };
    this.writeToStdin(response);
    console.error(chalk.red(`[StreamingClaude] Sent error: ${error}`));
  }

  /**
   * Write a message to Claude's stdin
   */
  private writeToStdin(message: object): void {
    if (!this.claudeProcess?.stdin) {
      console.error(chalk.red("[StreamingClaude] No stdin available"));
      return;
    }
    const json = JSON.stringify(message) + "\n";
    console.error(chalk.dim(`[StreamingClaude] Writing: ${json.trim().slice(0, 100)}...`));
    this.claudeProcess.stdin.write(json);
  }

  /**
   * Pretty print an assistant message
   */
  private printAssistantMessage(message: SDKMessage): void {
    const content = (message.message as { content?: Array<{ type: string; text?: string }> })?.content;
    if (!content) return;

    for (const block of content) {
      if (block.type === "text" && block.text) {
        console.log(block.text);
      } else if (block.type === "tool_use") {
        // Tool use will be handled via control_request
        console.error(chalk.dim(`[Tool] ${(block as { name?: string }).name}`));
      }
    }
  }

  /**
   * Pretty print a result message
   */
  private printResultMessage(message: SDKMessage): void {
    console.log();
    if (message.is_error) {
      console.log(chalk.red("Task failed"));
    } else {
      console.log(chalk.green("Task completed"));
    }

    if (message.result) {
      console.log(chalk.dim(message.result as string));
    }

    const usage = message.usage as { input_tokens?: number; output_tokens?: number } | undefined;
    if (usage) {
      console.log(chalk.dim(`Tokens: ${usage.input_tokens || 0} in / ${usage.output_tokens || 0} out`));
    }
  }

  /**
   * Cleanup resources
   */
  private cleanup(): void {
    this.isRunning = false;

    if (this.pollInterval) {
      clearInterval(this.pollInterval);
      this.pollInterval = null;
    }

    if (this.readline) {
      this.readline.close();
      this.readline = null;
    }

    // Reject all pending requests
    for (const pending of this.pendingRequests.values()) {
      pending.reject(new Error("Process terminated"));
    }
    this.pendingRequests.clear();
  }

  /**
   * Interrupt the current operation
   */
  async interrupt(): Promise<void> {
    if (!this.claudeProcess?.stdin) return;

    const interruptRequest = {
      type: "control_request",
      request_id: Math.random().toString(36).substring(2, 15),
      request: {
        subtype: "interrupt",
      },
    };
    this.writeToStdin(interruptRequest);
  }

  /**
   * Kill the Claude process
   */
  kill(): void {
    this.claudeProcess?.kill("SIGTERM");
    this.cleanup();
  }
}

/**
 * Run Claude with streaming JSON mode and watch integration
 */
export async function runStreamingClaude(prompt: string): Promise<number> {
  const config = readPairingConfig();

  if (!config?.pairingId) {
    console.log(chalk.red("Not paired. Run 'npx cc-watch' first to pair."));
    return 1;
  }

  console.log(chalk.dim("Running Claude with streaming JSON mode..."));
  console.log(chalk.dim("Permissions will be sent to watch via cloud."));
  console.log();

  const runner = new StreamingClaudeRunner(config.cloudUrl);
  return runner.start(prompt);
}
