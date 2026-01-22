import chalk from "chalk";
import ora from "ora";
import prompts from "prompts";
import { spawn, type ChildProcess } from "child_process";
import {
  isPaired,
  readPairingConfig,
  savePairingConfig,
  createPairingConfig,
} from "../config/pairing-store.js";
import { CloudClient } from "../cloud/client.js";
import { StdinProxy } from "./stdin-proxy.js";
import type { SessionState, WatchMessage } from "../types/index.js";

// YOLO mode flags for autonomous execution (from ralph.sh pattern)
const YOLO_FLAGS = [
  "--print",
  "--verbose",
  "--dangerously-skip-permissions",
] as const;

// Default URLs
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";
const DEFAULT_WS_URL = "ws://localhost:8787";

/**
 * Display the cc-watch header
 */
function showHeader(): void {
  console.log();
  console.log(chalk.bold.cyan("  cc-watch - Progress Monitor"));
  console.log();
}

/**
 * Check for required environment variables
 */
function checkEnvironment(): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  // Check for ANTHROPIC_API_KEY if we're going to run Claude
  if (!process.env.ANTHROPIC_API_KEY) {
    errors.push("ANTHROPIC_API_KEY environment variable is not set");
  }

  // Check for claude CLI
  try {
    const result = spawn("which", ["claude"], { stdio: "pipe" });
    result.on("error", () => {
      errors.push("Claude CLI not found in PATH");
    });
  } catch {
    // Ignore - we'll check when actually spawning
  }

  return { valid: errors.length === 0, errors };
}

/**
 * Execute Claude CLI in YOLO mode (autonomous execution without approval prompts)
 * This mirrors the pattern from ralph.sh for autonomous task execution
 */
function executeClaudeYolo(
  prompt: string,
  onOutput?: (data: string) => void
): ChildProcess {
  // Build command args following ralph.sh pattern (line 1238)
  const args = [
    ...YOLO_FLAGS,
    prompt,
  ];

  const claudeProcess = spawn("claude", args, {
    stdio: ["pipe", "pipe", "pipe"],
    env: {
      ...process.env,
      // Ensure ANTHROPIC_API_KEY is passed through
    },
  });

  if (onOutput) {
    claudeProcess.stdout?.on("data", (data: Buffer) => {
      onOutput(data.toString());
    });

    claudeProcess.stderr?.on("data", (data: Buffer) => {
      onOutput(data.toString());
    });
  }

  return claudeProcess;
}

/**
 * Execute ralph.sh script with YOLO mode flags
 * Falls back to direct Claude CLI execution if ralph.sh is not available
 */
async function executeRalph(
  taskPrompt: string,
  onProgress?: (message: string) => void
): Promise<{ success: boolean; exitCode: number }> {
  return new Promise((resolve) => {
    const progressHandler = (data: string): void => {
      if (onProgress) {
        // Split by newlines and emit each line
        const lines = data.split("\n").filter((line) => line.trim());
        for (const line of lines) {
          onProgress(line);
        }
      }
    };

    // Execute Claude directly with YOLO flags
    // This mirrors the ralph.sh execution pattern: claude --print --verbose --dangerously-skip-permissions
    const claudeProcess = executeClaudeYolo(taskPrompt, progressHandler);

    claudeProcess.on("close", (code) => {
      resolve({
        success: code === 0,
        exitCode: code ?? 1,
      });
    });

    claudeProcess.on("error", (error) => {
      if (onProgress) {
        onProgress(`Error: ${error.message}`);
      }
      resolve({
        success: false,
        exitCode: 1,
      });
    });
  });
}

/**
 * Verify cloud connectivity
 */
async function verifyCloud(cloudUrl: string): Promise<boolean> {
  const client = new CloudClient(cloudUrl);
  const result = await client.checkConnectivity();

  if (result.connected) {
    console.log(
      chalk.dim(`  Cloud: ${chalk.green("connected")} (${result.latency}ms)`)
    );
    return true;
  } else {
    console.log(
      chalk.dim(`  Cloud: ${chalk.red("not connected")} (${result.error})`)
    );
    return false;
  }
}

/**
 * Run cloud pairing flow - user enters code from watch
 */
async function runPairing(cloudUrl: string): Promise<string | null> {
  console.log();
  console.log(chalk.dim("  Open Claude Watch on your Apple Watch."));
  console.log(chalk.dim("  Tap 'Pair Now' to see a 6-digit code."));
  console.log();

  // Prompt for code from watch
  const response = await prompts({
    type: "text",
    name: "code",
    message: "Enter the code from your watch:",
    validate: (value: string) => {
      const cleaned = value.replace(/\s/g, "");
      if (/^\d{6}$/.test(cleaned)) {
        return true;
      }
      return "Enter 6 digits (shown on your watch)";
    },
  });

  if (!response.code) {
    console.log(chalk.yellow("  Pairing cancelled."));
    return null;
  }

  // Clean up the code (remove spaces)
  const code = response.code.replace(/\s/g, "");

  // Submit code to cloud
  const pairingSpinner = ora("Completing pairing...").start();

  try {
    const res = await fetch(`${cloudUrl}/pair/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });

    if (!res.ok) {
      const error = await res.json().catch(() => ({ error: "Unknown error" }));
      if (res.status === 404) {
        pairingSpinner.fail("Invalid or expired code");
        console.log();
        console.log(
          chalk.yellow("  Make sure your watch is showing a fresh code.")
        );
        console.log();
        return null;
      }
      throw new Error((error as { error: string }).error || `HTTP ${res.status}`);
    }

    const data = (await res.json()) as { pairingId: string };
    pairingSpinner.succeed("Watch paired!");
    return data.pairingId;
  } catch (error) {
    pairingSpinner.fail(`Pairing failed: ${(error as Error).message}`);
    return null;
  }
}

/**
 * Format session state for display
 */
function formatSessionState(state: SessionState): string {
  const statusColors: Record<string, (s: string) => string> = {
    idle: chalk.dim,
    running: chalk.cyan,
    waiting: chalk.yellow,
    completed: chalk.green,
    failed: chalk.red,
  };

  const colorFn = statusColors[state.status] || chalk.white;
  const progressBar = createProgressBar(state.progress);

  let output = "";
  output += `  Task:     ${chalk.white(state.task_name || "No task")}\n`;
  output += `  Status:   ${colorFn(state.status)}\n`;
  output += `  Progress: ${progressBar} ${Math.round(state.progress * 100)}%\n`;

  if (state.yolo_mode) {
    output += `  Mode:     ${chalk.yellow("YOLO")} (auto-approve)\n`;
  }

  if (state.pending_actions.length > 0) {
    output += `  Pending:  ${chalk.yellow(state.pending_actions.length + " action(s)")}`;
  }

  return output;
}

/**
 * Create a simple progress bar
 */
function createProgressBar(progress: number): string {
  const width = 20;
  const filled = Math.round(progress * width);
  const empty = width - filled;
  return chalk.cyan("█".repeat(filled)) + chalk.dim("░".repeat(empty));
}

/**
 * Connect to WebSocket for progress streaming
 */
async function connectWebSocket(
  wsUrl: string,
  onMessage: (message: WatchMessage) => void
): Promise<WebSocket | null> {
  return new Promise((resolve) => {
    try {
      const ws = new WebSocket(wsUrl);

      ws.onopen = () => {
        resolve(ws);
      };

      ws.onmessage = (event) => {
        try {
          const message = JSON.parse(event.data as string) as WatchMessage;
          onMessage(message);
        } catch {
          // Ignore parse errors
        }
      };

      ws.onerror = () => {
        resolve(null);
      };

      ws.onclose = () => {
        // Connection closed
      };

      // Timeout after 5 seconds
      setTimeout(() => {
        if (ws.readyState === WebSocket.CONNECTING) {
          ws.close();
          resolve(null);
        }
      }, 5000);
    } catch {
      resolve(null);
    }
  });
}

/**
 * Start progress monitoring mode
 */
async function startProgressMonitor(
  pairingId: string,
  cloudUrl: string
): Promise<void> {
  const wsUrl = process.env.MCP_SERVER_URL || DEFAULT_WS_URL;

  console.log();
  console.log(chalk.dim("  Connecting to progress stream..."));

  // Try WebSocket connection first
  let ws: WebSocket | null = null;
  let lastState: SessionState | null = null;

  // Message handler
  const handleMessage = (message: WatchMessage): void => {
    if (message.type === "state_sync" && message.state) {
      lastState = message.state;
      // Clear screen and redraw
      console.clear();
      showHeader();
      console.log(chalk.dim(`  Pairing: ${pairingId}`));
      console.log();
      console.log(formatSessionState(message.state));
      console.log();
    } else if (message.type === "progress_update") {
      console.log(
        chalk.dim(
          `  Progress: ${message.task_name} - ${Math.round((message.progress || 0) * 100)}%`
        )
      );
    } else if (message.type === "task_started") {
      console.log();
      console.log(chalk.cyan(`  Task started: ${message.task_name}`));
      if (message.task_description) {
        console.log(chalk.dim(`  ${message.task_description}`));
      }
      console.log();
    } else if (message.type === "task_completed") {
      console.log();
      if (message.success) {
        console.log(chalk.green(`  Task completed: ${message.task_name}`));
      } else {
        console.log(chalk.red(`  Task failed: ${message.task_name}`));
      }
      console.log();
    } else if (message.type === "notification") {
      console.log();
      console.log(chalk.yellow(`  [${message.title}] ${message.message}`));
      console.log();
    }
  };

  ws = await connectWebSocket(wsUrl, handleMessage);

  if (ws) {
    console.log(chalk.green("  Connected to progress stream"));
    console.log();
    console.log(chalk.dim("  Waiting for task updates..."));
    console.log(chalk.dim("  Press Ctrl+C to exit"));
    console.log();

    // Send pairing registration
    ws.send(JSON.stringify({ type: "register", pairingId }));

    // Keep alive with ping/pong
    const pingInterval = setInterval(() => {
      if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({ type: "ping" }));
      }
    }, 20000);

    // Handle cleanup
    const cleanup = (): void => {
      clearInterval(pingInterval);
      if (ws) {
        ws.close();
      }
    };

    process.on("SIGINT", () => {
      console.log();
      console.log(chalk.dim("  Disconnecting..."));
      cleanup();
      process.exit(0);
    });

    // Wait indefinitely (or until disconnection)
    await new Promise<void>((resolve) => {
      if (ws) {
        ws.onclose = () => {
          clearInterval(pingInterval);
          resolve();
        };
      }
    });
  } else {
    // Fall back to polling via cloud client
    console.log(
      chalk.yellow("  WebSocket unavailable, falling back to polling...")
    );
    console.log();

    const client = new CloudClient(cloudUrl, pairingId);

    // Poll for state updates
    console.log(chalk.dim("  Waiting for task updates..."));
    console.log(chalk.dim("  Press Ctrl+C to exit"));
    console.log();

    const pollInterval = setInterval(async () => {
      const messages = await client.pollMessages();
      for (const msg of messages) {
        if (msg.payload) {
          handleMessage(msg.payload as WatchMessage);
        }
      }
    }, 1000);

    process.on("SIGINT", () => {
      console.log();
      console.log(chalk.dim("  Stopping..."));
      clearInterval(pollInterval);
      process.exit(0);
    });

    // Wait indefinitely
    await new Promise<void>(() => {
      // Keep running until interrupted
    });
  }
}

/**
 * Main cc-watch command
 */
export async function runCcWatch(): Promise<void> {
  showHeader();

  // Validate environment variables before proceeding
  const envCheck = checkEnvironment();
  if (!envCheck.valid) {
    console.log(chalk.red("  Environment validation failed:"));
    console.log();
    for (const error of envCheck.errors) {
      console.log(chalk.red(`    • ${error}`));
    }
    console.log();
    console.log(chalk.dim("  Set ANTHROPIC_API_KEY to use cc-watch:"));
    console.log(chalk.dim("    export ANTHROPIC_API_KEY=your-api-key"));
    console.log();
    process.exit(1);
  }

  // Check if already paired
  const paired = isPaired();
  const config = readPairingConfig();

  let pairingId: string | null = null;
  let cloudUrl = DEFAULT_CLOUD_URL;

  if (paired && config) {
    // Already paired - use existing config
    console.log(chalk.dim(`  Already paired: ${config.pairingId}`));
    console.log();

    pairingId = config.pairingId;
    cloudUrl = config.cloudUrl;

    // Verify connectivity
    const cloudConnected = await verifyCloud(cloudUrl);
    if (!cloudConnected) {
      console.log();
      console.log(chalk.yellow("  Cloud relay unavailable."));

      const response = await prompts({
        type: "confirm",
        name: "continue",
        message: "Continue anyway with local WebSocket?",
        initial: true,
      });

      if (!response.continue) {
        return;
      }
    }
  } else {
    // Need to pair first
    console.log(chalk.dim("  Not paired yet. Starting pairing flow..."));
    console.log();

    // Check cloud connectivity
    const cloudConnected = await verifyCloud(cloudUrl);
    if (!cloudConnected) {
      console.log();
      console.log(chalk.red("  Cloud relay unavailable. Cannot pair."));
      console.log(
        chalk.dim("  Try running 'npx claude-watch' for full setup options.")
      );
      console.log();
      return;
    }

    // Run pairing
    pairingId = await runPairing(cloudUrl);

    if (!pairingId) {
      console.log();
      console.log(chalk.red("  Pairing failed."));
      console.log();
      return;
    }

    // Save config
    const newConfig = createPairingConfig(cloudUrl);
    newConfig.pairingId = pairingId;
    savePairingConfig(newConfig);

    console.log();
    console.log(chalk.green("  Pairing saved!"));
  }

  // Prompt for task and run Claude with full watch support
  if (pairingId) {
    console.log();
    console.log(chalk.green("  Ready! Watch connected."));
    console.log();

    const response = await prompts({
      type: "text",
      name: "task",
      message: "What would you like Claude to do?",
    });

    if (!response.task || !response.task.trim()) {
      console.log(chalk.dim("  No task provided. Exiting."));
      return;
    }

    console.log();
    console.log(chalk.dim("  Starting Claude with watch support..."));
    console.log(chalk.dim("  Tool approvals + questions will appear on your watch."));
    console.log();

    const proxy = new StdinProxy();
    const exitCode = await proxy.start([response.task.trim()]);
    process.exit(exitCode);
  }
}
