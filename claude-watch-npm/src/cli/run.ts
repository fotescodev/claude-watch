import chalk from "chalk";
import { spawn, type ChildProcess } from "child_process";
import {
  isPaired,
  readPairingConfig,
} from "../config/pairing-store.js";
import { CloudClient } from "../cloud/client.js";
import type { PendingQuestion } from "../types/index.js";

/**
 * COMP5: cc-watch run - Claude Launcher Mode
 *
 * This command spawns claude as a child process, intercepting stdout
 * to detect AskUserQuestion prompts and forwarding them to the watch.
 * Answers from the watch are injected into claude's stdin.
 *
 * This solves the limitation where:
 * - AskUserQuestion outputs to stdout (no hook available)
 * - User input comes from stdin (no hook available)
 * - Watch can only intercept tool calls via hooks
 */

interface QuestionDetection {
  type: "multiple_choice" | "text_input" | "confirmation";
  prompt: string;
  options?: string[];
}

/**
 * Detect AskUserQuestion patterns in Claude's output
 *
 * Patterns detected:
 * 1. Numbered options: "Which option?\n  1. Option A\n  2. Option B"
 * 2. Yes/No confirmation: "Do you want to proceed? (y/n)"
 * 3. Selection prompt: "Select an option: [1/2/3]"
 */
function detectQuestion(text: string): QuestionDetection | null {
  // Pattern 1: Numbered options (AskUserQuestion multiple choice)
  // Matches: "Question?\n  1. Option A\n  2. Option B\n  3. Option C"
  const numberedMatch = text.match(
    /([^\n]+\?)\s*\n((?:\s*\d+\.\s+[^\n]+\n?)+)/
  );
  if (numberedMatch) {
    const prompt = numberedMatch[1].trim();
    const optionsText = numberedMatch[2];
    const options = optionsText
      .split("\n")
      .map((line) => line.replace(/^\s*\d+\.\s*/, "").trim())
      .filter(Boolean);

    if (options.length >= 2) {
      return { type: "multiple_choice", prompt, options };
    }
  }

  // Pattern 2: Yes/No confirmation
  // Matches: "Do you want to proceed? (y/n)" or "(Y/n)" or "[y/N]"
  const confirmMatch = text.match(/([^\n]+\?)\s*[\[(]?[yY]\/[nN][\])]?/);
  if (confirmMatch) {
    return {
      type: "confirmation",
      prompt: confirmMatch[1].trim(),
      options: ["Yes", "No"],
    };
  }

  // Pattern 3: Bracketed selection
  // Matches: "Select: [1/2/3]" or "Choose [A/B/C]:"
  const bracketMatch = text.match(/([^\n]+):\s*\[([^\]]+)\]\s*$/);
  if (bracketMatch) {
    const prompt = bracketMatch[1].trim();
    const optionsStr = bracketMatch[2];
    const options = optionsStr.split("/").map((o) => o.trim());
    if (options.length >= 2) {
      return { type: "multiple_choice", prompt, options };
    }
  }

  return null;
}

/**
 * Display the cc-watch run header
 */
function showHeader(): void {
  console.log();
  console.log(chalk.bold.magenta("  cc-watch run - Claude Launcher"));
  console.log();
}

/**
 * Start claude as a child process with I/O interception
 */
async function spawnClaudeWithInterception(
  args: string[],
  client: CloudClient
): Promise<number> {
  return new Promise((resolve) => {
    // Spawn claude with piped stdio
    const claude = spawn("claude", args, {
      stdio: ["pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        // Signal to hooks that we're in a watch session
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
      },
    });

    // Buffer for detecting multi-line questions
    let outputBuffer = "";
    let currentQuestionId: string | null = null;
    let pollIntervalId: NodeJS.Timeout | null = null;

    // Clean up function
    const cleanup = (): void => {
      if (pollIntervalId) {
        clearInterval(pollIntervalId);
        pollIntervalId = null;
      }
    };

    // Send question to watch via cloud
    const sendQuestionToWatch = async (
      question: QuestionDetection
    ): Promise<void> => {
      const questionId = crypto.randomUUID();
      currentQuestionId = questionId;

      const pendingQuestion: PendingQuestion = {
        id: questionId,
        type: question.type,
        prompt: question.prompt,
        options: question.options || [],
        timestamp: new Date().toISOString(),
      };

      console.log(
        chalk.yellow(`\n  [Watch] Forwarding question: "${question.prompt}"`)
      );

      // Send to cloud
      const sent = await client.sendQuestion(pendingQuestion);
      if (!sent) {
        console.log(chalk.dim("  [Watch] Failed to send question to watch"));
        return;
      }

      console.log(chalk.dim("  [Watch] Waiting for answer from watch..."));
      console.log(chalk.dim("  [Watch] (You can also type locally)"));

      // Start polling for answer
      pollIntervalId = setInterval(async () => {
        if (!currentQuestionId) {
          if (pollIntervalId) clearInterval(pollIntervalId);
          return;
        }

        const answer = await client.pollForAnswer(currentQuestionId);
        if (answer) {
          console.log(chalk.green(`\n  [Watch] Answer received: ${answer}`));

          // Inject answer into claude's stdin
          if (claude.stdin && !claude.stdin.destroyed) {
            claude.stdin.write(answer + "\n");
          }

          // Clear current question
          currentQuestionId = null;
          if (pollIntervalId) {
            clearInterval(pollIntervalId);
            pollIntervalId = null;
          }
        }
      }, 500);
    };

    // Intercept stdout
    claude.stdout.on("data", (data: Buffer) => {
      const text = data.toString();
      outputBuffer += text;

      // Check for question patterns (only if we're not already waiting)
      if (!currentQuestionId) {
        const question = detectQuestion(outputBuffer);
        if (question) {
          sendQuestionToWatch(question);
          outputBuffer = ""; // Reset buffer
        }

        // Prevent buffer from growing too large
        if (outputBuffer.length > 10000) {
          outputBuffer = outputBuffer.slice(-5000);
        }
      }

      // Always pass through to terminal
      process.stdout.write(data);
    });

    // Intercept stderr (pass through)
    claude.stderr.on("data", (data: Buffer) => {
      process.stderr.write(data);
    });

    // Forward local stdin to claude (for local typing)
    // This allows the user to still type answers locally
    process.stdin.setRawMode?.(false);
    process.stdin.pipe(claude.stdin);

    // When user types locally, clear the current question polling
    process.stdin.on("data", () => {
      if (currentQuestionId) {
        currentQuestionId = null;
        if (pollIntervalId) {
          clearInterval(pollIntervalId);
          pollIntervalId = null;
        }
      }
    });

    // Handle exit
    claude.on("close", (code) => {
      cleanup();
      resolve(code ?? 0);
    });

    claude.on("error", (error) => {
      console.error(chalk.red(`\n  Claude process error: ${error.message}`));
      cleanup();
      resolve(1);
    });

    // Handle Ctrl+C
    process.on("SIGINT", () => {
      console.log(chalk.dim("\n  Stopping claude..."));
      claude.kill("SIGINT");
    });
  });
}

/**
 * Main run command
 */
export async function runRun(args: string[]): Promise<void> {
  showHeader();

  // Check if paired
  if (!isPaired()) {
    console.log(chalk.red("  Not paired with watch."));
    console.log(chalk.dim("  Run: npx cc-watch"));
    console.log();
    process.exit(1);
  }

  const config = readPairingConfig();
  if (!config?.pairingId) {
    console.log(chalk.red("  Invalid pairing configuration."));
    process.exit(1);
  }

  console.log(chalk.dim(`  Pairing: ${config.pairingId.slice(0, 8)}...`));
  console.log();

  // Create cloud client
  const client = new CloudClient(config.cloudUrl, config.pairingId);

  // Check connectivity
  const connectivity = await client.checkConnectivity();
  if (!connectivity.connected) {
    console.log(chalk.yellow("  Warning: Cloud not connected"));
    console.log(chalk.dim(`  ${connectivity.error}`));
    console.log(chalk.dim("  Questions won't be forwarded to watch."));
    console.log();
  } else {
    console.log(
      chalk.green(`  Cloud connected`) + chalk.dim(` (${connectivity.latency}ms)`)
    );
    console.log();
  }

  // If no args provided, start interactive claude
  const claudeArgs = args.length > 0 ? args : [];

  console.log(chalk.cyan("  Starting claude..."));
  if (claudeArgs.length > 0) {
    console.log(chalk.dim(`  Args: ${claudeArgs.join(" ")}`));
  }
  console.log();
  console.log(chalk.dim("  Questions will be forwarded to your watch."));
  console.log(chalk.dim("  You can also answer locally by typing."));
  console.log(chalk.dim("─".repeat(50)));
  console.log();

  // Spawn claude with interception
  const exitCode = await spawnClaudeWithInterception(claudeArgs, client);

  console.log();
  console.log(chalk.dim("─".repeat(50)));
  console.log(
    chalk.dim(`  Claude exited with code ${exitCode}`)
  );
  process.exit(exitCode);
}
