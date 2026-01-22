import * as pty from "node-pty";
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

/**
 * StdinProxy - Spawns Claude in a PTY and intercepts questions for watch answering.
 *
 * Claude Code requires a TTY to run interactively. This proxy uses node-pty to
 * create a pseudo-terminal, parses question UI patterns from output, sends
 * questions to the watch, and injects answers.
 */
export class StdinProxy {
  private ptyProcess: pty.IPty | null = null;
  private pairingId: string;
  private cloudUrl: string;
  private activeQuestionId: string | null = null;
  private outputBuffer: string = "";

  constructor(pairingId: string, cloudUrl: string = DEFAULT_CLOUD_URL) {
    this.pairingId = pairingId;
    this.cloudUrl = cloudUrl;
  }

  /**
   * Start the proxy with Claude CLI arguments.
   * Returns the exit code when Claude completes.
   */
  async start(claudeArgs: string[]): Promise<number> {
    // Use shell to find and run claude (handles PATH lookup)
    const shell = process.env.SHELL || "/bin/zsh";
    const claudeCommand = ["claude", ...claudeArgs].map(arg =>
      arg.includes(" ") ? `"${arg}"` : arg
    ).join(" ");

    // Spawn shell with claude command in a PTY
    this.ptyProcess = pty.spawn(shell, ["-c", claudeCommand], {
      name: "xterm-256color",
      cols: process.stdout.columns || 120,
      rows: process.stdout.rows || 30,
      cwd: process.cwd(),
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
        CLAUDE_WATCH_PROXY_MODE: "1",
        TERM: "xterm-256color",
        COLORTERM: "truecolor",
      } as { [key: string]: string },
    });

    this.setupOutputParsing();
    this.setupInputPassthrough();
    this.setupResize();

    return new Promise((resolve) => {
      this.ptyProcess?.onExit(({ exitCode }) => {
        this.cleanup();
        resolve(exitCode);
      });
    });
  }

  /**
   * Set up output parsing to detect questions and pass through to terminal.
   */
  private setupOutputParsing(): void {
    this.ptyProcess?.onData((data: string) => {
      // Pass through to terminal immediately
      process.stdout.write(data);

      // Buffer for question detection
      this.outputBuffer += data;

      // Try to parse a question from the buffer
      const question = this.parseQuestion(this.outputBuffer);
      if (question) {
        // Reset buffer after detecting a question
        this.outputBuffer = "";
        // Handle the question asynchronously
        this.handleQuestion(question).catch((err) => {
          console.error(chalk.red(`\nQuestion handling error: ${err.message}`));
        });
      }

      // Prevent buffer from growing too large
      if (this.outputBuffer.length > 10000) {
        this.outputBuffer = this.outputBuffer.slice(-5000);
      }
    });
  }

  /**
   * Pass through terminal stdin to Claude PTY.
   */
  private setupInputPassthrough(): void {
    // Set raw mode to capture individual keypresses
    if (process.stdin.isTTY) {
      process.stdin.setRawMode(true);
    }
    process.stdin.resume();

    process.stdin.on("data", (data: Buffer) => {
      // If we're actively handling a question on watch, still pass through
      // The race will handle which answer wins
      if (this.ptyProcess) {
        this.ptyProcess.write(data.toString());
      }
    });
  }

  /**
   * Handle terminal resize events.
   */
  private setupResize(): void {
    process.stdout.on("resize", () => {
      if (this.ptyProcess) {
        this.ptyProcess.resize(
          process.stdout.columns || 120,
          process.stdout.rows || 30
        );
      }
    });
  }

  /**
   * Parse Claude's output for question UI pattern.
   *
   * Claude's question UI looks like:
   * ? Question text here
   *   1. Option one
   *   2. Option two
   *   3. Option three
   *
   * The cursor position indicates Claude is waiting for input.
   */
  private parseQuestion(buffer: string): ParsedQuestion | null {
    // Match question pattern: ? Question\n  1. Option\n  2. Option
    // Look for the characteristic "?" prefix and numbered options
    const questionRegex = /\? ([^\n]+)\n((?:\s+\d+\.[^\n]+\n?)+)/s;
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

    // Check if we've seen this question before in the current buffer
    // to avoid duplicate handling
    const questionKey = `${text}:${options.join(",")}`;
    if (this.outputBuffer.indexOf(questionKey) !== this.outputBuffer.lastIndexOf(questionKey)) {
      return null;
    }

    return { text, options };
  }

  /**
   * Handle a detected question.
   * Creates question on cloud, races watch answer vs terminal input.
   */
  private async handleQuestion(question: ParsedQuestion): Promise<void> {
    console.log(chalk.cyan("\n  📱 Sending to watch... (or type answer here)"));

    try {
      // Create question on cloud server
      const questionId = await this.createCloudQuestion(question);
      this.activeQuestionId = questionId;

      if (!questionId) {
        console.log(chalk.yellow("  Could not send to watch, answer in terminal."));
        return;
      }

      // Poll for watch answer in background - don't block terminal input
      this.pollWatchAnswerBackground(questionId, question.options.length);
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
   * Poll the cloud server for watch answer in the background.
   * When answer arrives, inject it into the PTY.
   */
  private async pollWatchAnswerBackground(questionId: string, optionCount: number): Promise<void> {
    const timeout = 30000; // 30 seconds
    const pollInterval = 500; // 500ms
    const startTime = Date.now();

    while (Date.now() - startTime < timeout) {
      // Check if question is still active
      if (this.activeQuestionId !== questionId) {
        // User answered in terminal, stop polling
        return;
      }

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
            console.log(chalk.green("\n  ✓ Answered from watch!"));

            // Inject the answer into the PTY
            if (this.ptyProcess && selectedIndex <= optionCount) {
              this.ptyProcess.write(`${selectedIndex}\r`);
            }

            this.activeQuestionId = null;
            return;
          }

          if (result.status === "skipped") {
            // User chose to answer in terminal
            console.log(chalk.yellow("\n  Watch: skipped, answer in terminal"));
            this.activeQuestionId = null;
            return;
          }
        }
      } catch {
        // Ignore poll errors, continue polling
      }

      // Wait before next poll
      await new Promise((resolve) => setTimeout(resolve, pollInterval));
    }

    // Timeout - user will answer in terminal
    if (this.activeQuestionId === questionId) {
      console.log(chalk.dim("\n  Watch timeout, answer in terminal"));
      this.activeQuestionId = null;
    }
  }

  /**
   * Cleanup resources.
   */
  private cleanup(): void {
    this.activeQuestionId = null;

    if (process.stdin.isTTY) {
      process.stdin.setRawMode(false);
    }

    if (this.ptyProcess) {
      this.ptyProcess.kill();
      this.ptyProcess = null;
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
