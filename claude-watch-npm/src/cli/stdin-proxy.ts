import { spawn, type ChildProcess } from "child_process";
import * as readline from "readline";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import chalk from "chalk";
import { readPairingConfig } from "../config/pairing-store.js";

// Cloud server configuration
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";

// Debug logging configuration
const DEBUG_LOG_FILE = path.join(os.tmpdir(), "claude-watch-stdin-proxy.log");
const DEBUG_VERBOSE = process.env.DEBUG_STDIN_PROXY === "1";
const DEBUG_LOG_TAIL_LIMIT = 800;
const STARTUP_OUTPUT_TIMEOUT_MS = 10000;
const CLAUDE_AUTH_PATH = path.join(os.homedir(), ".claude.json");

/**
 * Write debug message to file (always) and console (if DEBUG_STDIN_PROXY=1).
 */
function debugLog(message: string): void {
  const timestamp = new Date().toISOString();
  const logLine = `[${timestamp}] ${message}\n`;

  // Always append to log file
  try {
    fs.appendFileSync(DEBUG_LOG_FILE, logLine);
  } catch {
    // Ignore file write errors
  }

  // Only write to console if verbose mode enabled
  if (DEBUG_VERBOSE) {
    console.error(chalk.dim(message));
  }
}

function debugLogChunk(streamName: "stdout" | "stderr", text: string): void {
  const tail = text.length > DEBUG_LOG_TAIL_LIMIT
    ? text.slice(-DEBUG_LOG_TAIL_LIMIT)
    : text;
  const escaped = tail.replace(/\r/g, "\\r").replace(/\n/g, "\\n");
  debugLog(`[DEBUG] ${streamName} chunk: ${escaped}`);
}

// Question parsing types
interface ParsedQuestion {
  text: string;
  options: string[];
  header?: string;
  multiSelect: boolean;
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
  private isHandlingQuestion = false;
  private startupTimer: NodeJS.Timeout | null = null;

  constructor(pairingId: string, cloudUrl: string = DEFAULT_CLOUD_URL) {
    this.pairingId = pairingId;
    this.cloudUrl = cloudUrl;
  }

  /**
   * Start the proxy with Claude CLI arguments.
   * Returns the exit code when Claude completes.
   */
  async start(claudeArgs: string[]): Promise<number> {
    debugLog(`[DEBUG] Launching Claude: args=${JSON.stringify(claudeArgs)}`);
    debugLog(
      `[DEBUG] Env: ANTHROPIC_API_KEY=${process.env.ANTHROPIC_API_KEY ? "set" : "missing"}`
    );
    debugLog(`[DEBUG] Auth file: ${fs.existsSync(CLAUDE_AUTH_PATH) ? "present" : "missing"}`);
    const childEnv = {
      ...process.env,
      CLAUDE_WATCH_SESSION_ACTIVE: "1",
      CLAUDE_WATCH_PROXY_MODE: "1",
    } as Record<string, string | undefined>;
    delete childEnv.DEBUG_STDIN_PROXY;

    this.claudeProcess = spawn("claude", claudeArgs, {
      stdio: ["pipe", "pipe", "pipe"],
      env: childEnv,
    });

    this.setupOutputParsing();
    this.setupTerminalPassthrough();

    return new Promise((resolve) => {
      this.claudeProcess?.on("close", (code) => {
        if (this.startupTimer) {
          clearTimeout(this.startupTimer);
          this.startupTimer = null;
        }
        debugLog(`[DEBUG] Claude exited: code=${code ?? "null"}`);
        this.cleanup();
        resolve(code ?? 1);
      });

      this.claudeProcess?.on("error", (error) => {
        debugLog(`[DEBUG] Claude spawn error: ${error.message}`);
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
    let stdoutBuffer = "";
    let stderrBuffer = "";

    debugLog(`[DEBUG] StdinProxy started - pairingId: ${this.pairingId}`);
    debugLog(`[DEBUG] Log file: ${DEBUG_LOG_FILE}`);
    this.startupTimer = setTimeout(() => {
      debugLog(
        "[DEBUG] No Claude output detected within 10s. Check CLI auth or run `claude` directly."
      );
    }, STARTUP_OUTPUT_TIMEOUT_MS);

    const handleOutput = (
      data: Buffer,
      streamName: "stdout" | "stderr"
    ): void => {
      const text = data.toString();
      const buffer = streamName === "stdout" ? stdoutBuffer : stderrBuffer;
      const nextBuffer = buffer + text;

      if (streamName === "stdout") {
        stdoutBuffer = nextBuffer;
        process.stdout.write(data);
      } else {
        stderrBuffer = nextBuffer;
        process.stderr.write(data);
      }

      debugLogChunk(streamName, text);
      if (this.startupTimer) {
        clearTimeout(this.startupTimer);
        this.startupTimer = null;
      }

      if (this.activeQuestionId || this.isHandlingQuestion) {
        return;
      }

      // Debug: log when we see potential question indicators
      if (text.includes("Enter to select")) {
        debugLog(`\n[DEBUG] Detected 'Enter to select' in ${streamName}`);
        debugLog(`[DEBUG] Buffer length (${streamName}): ${nextBuffer.length}`);
        debugLog(
          `[DEBUG] Buffer preview (${streamName}): ${nextBuffer
            .slice(-500)
            .replace(/\n/g, "\\n")}`
        );
      }

      // Try to parse a question from the buffer
      const question = this.parseQuestion(nextBuffer);
      if (question) {
        debugLog(`\n[DEBUG] Parsed question (${streamName}): ${question.text.slice(0, 50)}...`);
        debugLog(`[DEBUG] Options: ${question.options.join(", ")}`);
        debugLog(`[DEBUG] Multi-select: ${question.multiSelect}`);
        // Reset buffer after detecting a question
        if (streamName === "stdout") {
          stdoutBuffer = "";
        } else {
          stderrBuffer = "";
        }
        this.isHandlingQuestion = true;
        // Handle the question asynchronously
        this.handleQuestion(question)
          .catch((err) => {
            console.error(chalk.red(`Question handling error: ${err.message}`));
          })
          .finally(() => {
            this.isHandlingQuestion = false;
          });
      }

      // Prevent buffer from growing too large
      if (streamName === "stdout" && stdoutBuffer.length > 10000) {
        stdoutBuffer = stdoutBuffer.slice(-5000);
      } else if (streamName === "stderr" && stderrBuffer.length > 10000) {
        stderrBuffer = stderrBuffer.slice(-5000);
      }
    };

    this.claudeProcess?.stdout?.on("data", (data: Buffer) => {
      handleOutput(data, "stdout");
    });

    this.claudeProcess?.stderr?.on("data", (data: Buffer) => {
      handleOutput(data, "stderr");
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
   * Claude's actual question UI looks like:
   * ❯ Header
   *
   * Question text here
   * (possibly multiple lines)
   *
   * ❯ 1. Option one
   *      Description
   *   2. Option two
   *      Description
   *
   * Enter to select · ↑/↓ to navigate · Esc to cancel
   *
   * Or the simpler format:
   * ? Which framework?
   *   1. React
   *   2. Vue
   * >
   */
  private parseQuestion(buffer: string): ParsedQuestion | null {
    const normalized = this.normalizeBuffer(buffer);
    // Check for prompt indicators
    const hasInteractivePrompt =
      /enter to select|use .*arrow|esc to cancel|press enter|return to select/i.test(normalized) ||
      /\n>\s*$/.test(normalized);

    if (!hasInteractivePrompt) {
      // Allow fallback if the question header + options are clearly present
      const headerMatch = normalized.match(/[❯?]\s*([^\n]+?)\s*\n/);
      if (!headerMatch) {
        return null;
      }
    }

    // Try to extract header (line starting with ❯ followed by text, or ? for simple format)
    const headerMatch = normalized.match(/[❯?]\s*([^\n]+?)\s*\n/);
    const header = headerMatch ? headerMatch[1].trim() : "Question";

    // Extract question text
    let questionText = "Question from Claude";

    // For ? format: the header line IS the question
    if (header && header.includes("?")) {
      questionText = header;
    } else {
      // For ❯ format: text is between header and first numbered option
      const questionMatch = normalized.match(/[❯]\s*[^\n]+\s*\n\n?([\s\S]*?)\n\s*[❯>\s]*1\./);
      if (questionMatch) {
        questionText = questionMatch[1].trim().replace(/\s+/g, " ");
      }
    }

    // Extract options - lines with "❯ N." or "  N." pattern
    const optionRegex = /[❯>\s]*(\d+)\.\s+([^\n]+)/g;
    const options: string[] = [];
    let optMatch;

    while ((optMatch = optionRegex.exec(normalized)) !== null) {
      const label = optMatch[2].trim();
      // Skip description lines (they're indented more and follow an option)
      if (label && !label.match(/^\s{4,}/)) {
        options.push(label);
      }
    }

    if (options.length < 2) {
      return null;
    }

    const multiSelect =
      /(^|\n)\s*[>❯]?\s*\[[ xX]\]\s*\d+\./.test(normalized) ||
      /(^|\n)\s*[>❯]?\s*[☐☑◻◼]\s*\d+\./.test(normalized);

    return { text: questionText, options, header, multiSelect };
  }

  /**
   * Handle a detected question.
   * Creates question on cloud, races watch answer vs terminal input.
   */
  private async handleQuestion(question: ParsedQuestion): Promise<void> {
    console.log(chalk.cyan("\n  ⌚ Sending to watch... (or type answer here)"));

    try {
      debugLog(`[DEBUG] Handling question: ${question.text.slice(0, 80)}...`);
      // Create question on cloud server
      debugLog(`[DEBUG] Creating cloud question...`);
      const questionId = await this.createCloudQuestion(question);
      this.activeQuestionId = questionId;

      if (!questionId) {
        console.log(chalk.yellow("  Could not send to watch, type your answer:"));
        debugLog("[DEBUG] Question create failed - falling back to terminal input");
        return;
      }

      debugLog(`[DEBUG] Question created: ${questionId}`);

      // Race between watch answer and terminal input
      const answer = await this.raceForAnswer(
        questionId,
        question.options.length,
        question.multiSelect
      );

      // Clear the active question
      this.activeQuestionId = null;

      // Inject the answer into Claude's stdin
      const escaped = answer
        .replace(/\x1b/g, "\\x1b")
        .replace(/\r/g, "\\r")
        .replace(/\n/g, "\\n");
      debugLog(`[DEBUG] Injecting keys: ${escaped}`);
      if (this.claudeProcess?.stdin) {
        await this.sendKeySequence(answer);
        console.log(chalk.dim("  Answer sent"));
        debugLog("[DEBUG] Answer sent to Claude stdin");
      }
    } catch (error) {
      this.activeQuestionId = null;
      console.error(chalk.red(`  Error: ${(error as Error).message}`));
    }
  }

  /**
   * Create a question request on the cloud server.
   */
  private async createCloudQuestion(question: ParsedQuestion): Promise<string | null> {
    try {
      const requestData = {
        pairingId: this.pairingId,
        type: "question",
        question: question.text,
        header: question.header || "Question",
        options: question.options.map((label) => ({
          label,
          description: "",
        })),
        multiSelect: question.multiSelect,
        hasOtherOption: question.options.some((opt) =>
          opt.toLowerCase().includes("other")
        ),
      };

      const response = await fetch(`${this.cloudUrl}/question`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(requestData),
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const result = (await response.json()) as { questionId: string };
      return result.questionId;
    } catch (error) {
      console.error(chalk.dim(`  Cloud error: ${(error as Error).message}`));
      return null;
    }
  }

  /**
   * Race between watch answer and terminal input.
   * Returns the answer (option number) to inject.
   */
  private async raceForAnswer(
    questionId: string,
    optionCount: number,
    multiSelect: boolean
  ): Promise<string> {
    // Create abort controller for cancellation
    this.terminalInputAbort = new AbortController();

    try {
      const answer = await Promise.race([
        this.pollWatchAnswer(questionId, multiSelect),
        this.readTerminalInput(optionCount, multiSelect),
      ]);

      return answer;
    } finally {
      // Cancel any pending operations
      this.terminalInputAbort?.abort();
      this.terminalInputAbort = null;
    }
  }

  /**
   * Poll the cloud server for watch answer.
   */
  private async pollWatchAnswer(
    questionId: string,
    multiSelect: boolean
  ): Promise<string> {
    const timeout = 300000; // 5 minutes
    const pollInterval = 1000; // 1 second
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
            const selectedIndices =
              result.selectedIndices.length > 0 ? result.selectedIndices : [0];
            console.log(chalk.green("  Answered from watch"));
            const keys = this.buildSelectionKeys(selectedIndices, multiSelect);
            debugLog(
              `[DEBUG] Watch indices: ${selectedIndices.join(",")} (multi=${multiSelect})`
            );
            return keys;
          }

          if (result.status === "skipped") {
            // User chose to answer in terminal
            console.log(chalk.yellow("  Watch: answer in terminal"));
            debugLog("[DEBUG] Watch skipped question - waiting for terminal input");
            // Continue waiting for terminal input
            return new Promise(() => {}); // Never resolves
          }
        }
      } catch {
        // Ignore poll errors, continue polling
      }

      // Wait before next poll
      await new Promise((resolve) => setTimeout(resolve, pollInterval));
    }

    // Timeout - never resolves (let terminal input win)
    return new Promise(() => {});
  }

  /**
   * Read answer from terminal stdin.
   */
  private readTerminalInput(
    optionCount: number,
    multiSelect: boolean
  ): Promise<string> {
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
          resolve(this.buildSelectionKeys([num - 1], multiSelect));
        } else if (input.length > 0) {
          // For "Other" text input, just pass through
          cleanup();
          resolve(`${input}\n`);
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

  /**
   * Build a key sequence to select an option in the CLI list.
   * Assumes the first option is selected by default.
   */
  private buildSelectionKeys(index: number): string;
  private buildSelectionKeys(indices: number[], multiSelect: boolean): string;
  private buildSelectionKeys(
    indexOrIndices: number | number[],
    multiSelect: boolean = false
  ): string {
    const down = "\x1b[B";
    const enter = "\r";
    const space = " ";
    const indices = Array.isArray(indexOrIndices)
      ? indexOrIndices
      : [indexOrIndices];
    const ordered = [...indices].sort((a, b) => a - b);
    let current = 0;
    let sequence = "";

    for (const index of ordered) {
      const steps = Math.max(0, index - current);
      if (steps > 0) {
        sequence += down.repeat(steps);
        current = index;
      }
      if (multiSelect) {
        sequence += space;
      }
    }

    if (!multiSelect && ordered.length > 0) {
      // Single-select list: Enter chooses current option
      sequence += enter;
    } else if (multiSelect) {
      // Multi-select checkbox list: Enter submits after toggles
      sequence += enter;
    }

    return sequence;
  }

  private normalizeBuffer(buffer: string): string {
    // Strip ANSI escape codes and normalize line endings for parsing
    return buffer
      .replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")
      .replace(/\r\n/g, "\n");
  }

  private async sendKeySequence(sequence: string): Promise<void> {
    if (!this.claudeProcess?.stdin) {
      return;
    }
    const tokens = sequence.match(/\x1b\[[0-9;]*[A-Za-z]|./g) || [];
    for (const token of tokens) {
      this.claudeProcess.stdin.write(token);
      await new Promise((resolve) => setTimeout(resolve, 50));
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
  if (!process.env.ANTHROPIC_API_KEY) {
    console.log(
      chalk.yellow(
        "  Warning: ANTHROPIC_API_KEY is not set. Claude may not start in this shell."
      )
    );
    console.log(
      chalk.yellow(
        "  If you normally run `claude` successfully elsewhere, run `npx cc-watch` from that same terminal."
      )
    );
    console.log(chalk.yellow(`  Debug log: ${DEBUG_LOG_FILE}`));
    console.log();
  }

  const proxy = new StdinProxy(config.pairingId, config.cloudUrl);
  return proxy.start(claudeArgs);
}
