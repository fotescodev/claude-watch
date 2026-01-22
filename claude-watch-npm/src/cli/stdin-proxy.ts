import { spawn, type ChildProcess } from "child_process";
import * as readline from "readline";
import * as crypto from "crypto";
import chalk from "chalk";
import { readPairingConfig } from "../config/pairing-store.js";

// Cloud server configuration
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";

// Question parsing types
interface ParsedQuestion {
  text: string;
  options: string[];
  header?: string;
}

interface QuestionResponse {
  selected: number[];
  skipped: boolean;
}

/**
 * StdinProxy - Spawns Claude and intercepts questions for watch answering.
 *
 * Claude Code ignores hook responses for AskUserQuestion - it only reads from stdin.
 * This proxy spawns Claude as a child process, parses question UI patterns from stdout,
 * sends questions to the watch, and injects answers into stdin.
 */
export class StdinProxy {
  private claudeProcess: ChildProcess | null = null;
  private pairingId: string;
  private cloudUrl: string;
  private activeQuestionId: string | null = null;
  private terminalInputAbort: AbortController | null = null;

  constructor(pairingId: string, cloudUrl: string = DEFAULT_CLOUD_URL) {
    this.pairingId = pairingId;
    this.cloudUrl = cloudUrl;
  }

  /**
   * Start the proxy with Claude CLI arguments.
   * Returns the exit code when Claude completes.
   */
  async start(claudeArgs: string[]): Promise<number> {
    this.claudeProcess = spawn("claude", claudeArgs, {
      stdio: ["pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
        CLAUDE_WATCH_PROXY_MODE: "1",
      },
    });

    this.setupOutputParsing();
    this.setupTerminalPassthrough();

    return new Promise((resolve) => {
      this.claudeProcess?.on("close", (code) => {
        this.cleanup();
        resolve(code ?? 1);
      });

      this.claudeProcess?.on("error", (error) => {
        console.error(chalk.red(`Failed to start Claude: ${error.message}`));
        this.cleanup();
        resolve(1);
      });
    });
  }

  /**
   * Set up stdout/stderr parsing to detect questions.
   */
  private setupOutputParsing(): void {
    let buffer = "";

    this.claudeProcess?.stdout?.on("data", (data: Buffer) => {
      const text = data.toString();
      buffer += text;

      // Pass through to terminal
      process.stdout.write(data);

      // Try to parse a question from the buffer
      const question = this.parseQuestion(buffer);
      if (question) {
        // Reset buffer after detecting a question
        buffer = "";
        // Handle the question asynchronously
        this.handleQuestion(question).catch((err) => {
          console.error(chalk.red(`Question handling error: ${err.message}`));
        });
      }

      // Prevent buffer from growing too large
      if (buffer.length > 10000) {
        buffer = buffer.slice(-5000);
      }
    });

    this.claudeProcess?.stderr?.on("data", (data: Buffer) => {
      process.stderr.write(data);
    });
  }

  /**
   * Pass through terminal stdin to Claude (when not waiting for question).
   */
  private setupTerminalPassthrough(): void {
    // Set raw mode to capture individual keypresses
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
    }
    process.stdin.resume();

    process.stdin.on("data", (data: Buffer) => {
      // If we're actively handling a question, let the race handle it
      // Otherwise, pass through to Claude
      if (!this.activeQuestionId && this.claudeProcess?.stdin) {
        this.claudeProcess.stdin.write(data);
      }
    });
  }

  /**
   * Parse Claude's stdout for question UI pattern.
   *
   * Claude's question UI looks like:
   * ? Question text here
   *   1. Option one
   *   2. Option two
   *   3. Option three
   * >
   *
   * We also handle the format with "Other" option at the end.
   */
  private parseQuestion(buffer: string): ParsedQuestion | null {
    // Match question pattern: ? Question\n  1. Option\n  2. Option\n>
    // The > prompt indicates Claude is waiting for input
    const questionRegex = /\? ([^\n]+)\n((?:\s+\d+\.[^\n]+\n)+)(?:\s*>\s*)?$/s;
    const match = buffer.match(questionRegex);

    if (!match) {
      return null;
    }

    const text = match[1].trim();
    const optionsBlock = match[2];

    // Parse options
    const optionLines = optionsBlock.split("\n").filter((line) => {
      return /^\s+\d+\./.test(line);
    });

    const options = optionLines.map((line) => {
      // Remove leading whitespace, number, and period
      return line.replace(/^\s+\d+\.\s*/, "").trim();
    });

    if (options.length < 2) {
      return null;
    }

    return { text, options };
  }

  /**
   * Handle a detected question.
   * Creates question on cloud, races watch answer vs terminal input.
   */
  private async handleQuestion(question: ParsedQuestion): Promise<void> {
    console.log(chalk.cyan("\n  Sending to watch... (or type answer here)"));

    try {
      // Create question on cloud server
      const questionId = await this.createCloudQuestion(question);
      this.activeQuestionId = questionId;

      if (!questionId) {
        console.log(chalk.yellow("  Could not send to watch, type your answer:"));
        return;
      }

      // Race between watch answer and terminal input
      const answer = await this.raceForAnswer(questionId, question.options.length);

      // Clear the active question
      this.activeQuestionId = null;

      // Inject the answer into Claude's stdin
      if (this.claudeProcess?.stdin) {
        this.claudeProcess.stdin.write(`${answer}\n`);
        console.log(chalk.dim(`  Answer sent: ${answer}`));
      }
    } catch (error) {
      this.activeQuestionId = null;
      console.error(chalk.red(`  Error: ${(error as Error).message}`));
    }
  }

  /**
   * Create a question request on the cloud server.
   * IMPORTANT: CLI generates the question ID to prevent mismatch issues.
   */
  private async createCloudQuestion(question: ParsedQuestion): Promise<string | null> {
    try {
      // Generate ID locally - this is the single source of truth
      // Prevents the ID mismatch that caused codex-review failure
      const questionId = crypto.randomUUID();

      const requestData = {
        id: questionId,  // Send our ID to cloud
        pairingId: this.pairingId,
        question: question.text,
        header: question.header || "Question",
        options: question.options.map((label) => ({
          label,
          description: "",
        })),
        multiSelect: false,
      };

      const response = await fetch(`${this.cloudUrl}/question`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestData),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      // Use OUR generated ID, not the response
      // Cloud will store under our ID
      return questionId;
    } catch (error) {
      console.error(chalk.dim(`  Cloud error: ${(error as Error).message}`));
      return null;
    }
  }

  /**
   * Race between watch answer and terminal input.
   * Returns the answer (option number) to inject.
   * Falls back to terminal if watch times out or user skips.
   */
  private async raceForAnswer(
    questionId: string,
    optionCount: number
  ): Promise<string> {
    // Create abort controller for cancellation
    this.terminalInputAbort = new AbortController();
    const MASTER_TIMEOUT = 30000; // 30 seconds absolute max

    try {
      const answer = await Promise.race([
        this.pollWatchAnswer(questionId),
        this.readTerminalInput(optionCount),
        // Master timeout prevents any hang
        new Promise<never>((_, reject) =>
          setTimeout(() => reject(new Error("MASTER_TIMEOUT")), MASTER_TIMEOUT)
        ),
      ]);

      return answer;
    } catch (error) {
      const msg = (error as Error).message;

      // Handle known error cases - fall back to terminal
      if (msg === "SKIP_TO_TERMINAL") {
        console.log(chalk.yellow("  Watch: type answer in terminal"));
      } else if (msg === "WATCH_TIMEOUT" || msg === "MASTER_TIMEOUT") {
        console.log(chalk.yellow("  Watch timeout, type answer here:"));
      } else {
        console.log(chalk.yellow(`  ${msg}, type answer here:`));
      }

      // Wait for terminal input as fallback
      return this.readTerminalInput(optionCount);
    } finally {
      // Cancel any pending operations
      this.terminalInputAbort?.abort();
      this.terminalInputAbort = null;
    }
  }

  /**
   * Poll the cloud server for watch answer.
   * Throws on timeout or skip - caller handles fallback to terminal.
   */
  private async pollWatchAnswer(questionId: string): Promise<string> {
    const timeout = 30000; // 30 seconds (matches watch screen timeout)
    const pollInterval = 500; // 500ms for responsive feel
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      try {
        const response = await fetch(`${this.cloudUrl}/question/${questionId}`);

        if (response.ok) {
          const result = (await response.json()) as {
            status: string;
            selectedIndices?: number[];
          };

          if (result.status === "answered" && result.selectedIndices) {
            // Convert 0-based index to 1-based for Claude's input
            const selectedIndex = result.selectedIndices[0] + 1;
            console.log(chalk.green("  ✓ Answered from watch"));
            return selectedIndex.toString();
          }

          if (result.status === "skipped") {
            // User chose to answer in terminal - throw to trigger fallback
            throw new Error("SKIP_TO_TERMINAL");
          }
        }
      } catch (error) {
        // Re-throw skip signal
        if ((error as Error).message === "SKIP_TO_TERMINAL") {
          throw error;
        }
        // Ignore other poll errors, continue polling
      }

      // Wait before next poll
      await new Promise((resolve) => setTimeout(resolve, pollInterval));
    }

    // Timeout - throw to trigger terminal fallback
    throw new Error("WATCH_TIMEOUT");
  }

  /**
   * Read answer from terminal stdin.
   */
  private readTerminalInput(optionCount: number): Promise<string> {
    return new Promise((resolve, reject) => {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false,
      });

      const onData = (data: Buffer): void => {
        const input = data.toString().trim();

        // Check if it's a valid option number
        const num = parseInt(input, 10);
        if (num >= 1 && num <= optionCount) {
          cleanup();
          resolve(input);
        } else if (input.length > 0) {
          // For "Other" text input, just pass through
          cleanup();
          resolve(input);
        }
      };

      const cleanup = (): void => {
        process.stdin.removeListener("data", onData);
        rl.close();
      };

      // Handle abort
      this.terminalInputAbort?.signal.addEventListener("abort", () => {
        cleanup();
        reject(new Error("Aborted"));
      });

      // Listen for terminal input
      process.stdin.on("data", onData);
    });
  }

  /**
   * Cleanup resources.
   */
  private cleanup(): void {
    this.terminalInputAbort?.abort();

    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }
  }
}

/**
 * Run Claude with stdin proxy for watch question support.
 */
export async function runClaudeProxy(claudeArgs: string[]): Promise<number> {
  const config = readPairingConfig();

  if (!config?.pairingId) {
    console.log(chalk.red("Not paired. Run 'npx cc-watch' first to pair."));
    return 1;
  }

  console.log(chalk.dim("  Running Claude with watch question support..."));
  console.log();

  const proxy = new StdinProxy(config.pairingId, config.cloudUrl);
  return proxy.start(claudeArgs);
}
