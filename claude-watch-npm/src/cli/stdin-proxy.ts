import { spawn, type ChildProcess } from "child_process";
import chalk from "chalk";
import { readPairingConfig } from "../config/pairing-store.js";

/**
 * Run Claude with stdio inherited (full TTY passthrough).
 *
 * Questions are handled via the PreToolUse hook (watch-approval-cloud.py)
 * which intercepts AskUserQuestion and sends to the watch.
 *
 * This approach:
 * - Claude runs with full TTY (colors, interactivity)
 * - Hook handles AskUserQuestion before Claude displays it
 * - No output interception needed
 */
export class StdinProxy {
  private claudeProcess: ChildProcess | null = null;

  /**
   * Start Claude with inherited stdio (full TTY passthrough).
   * Returns the exit code when Claude completes.
   */
  async start(claudeArgs: string[]): Promise<number> {
    // Spawn Claude with inherited stdio - full TTY passthrough
    this.claudeProcess = spawn("claude", claudeArgs, {
      stdio: "inherit",  // Full TTY passthrough
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
        // NOT setting PROXY_MODE - let hooks handle questions
      },
    });

    return new Promise((resolve) => {
      this.claudeProcess?.on("close", (code) => {
        resolve(code ?? 1);
      });

      this.claudeProcess?.on("error", (error) => {
        console.error(chalk.red(`Failed to start Claude: ${error.message}`));
        resolve(1);
      });
    });
  }
}

/**
 * Run Claude with watch integration.
 *
 * Questions are handled via the PreToolUse hook, not stdout parsing.
 */
export async function runClaudeProxy(claudeArgs: string[]): Promise<number> {
  const config = readPairingConfig();

  if (!config?.pairingId) {
    console.log(chalk.red("Not paired. Run 'npx cc-watch' first to pair."));
    return 1;
  }

  console.log(chalk.dim("Running Claude with watch integration..."));
  console.log(chalk.dim("Questions will be sent to watch via hooks."));
  console.log();

  const proxy = new StdinProxy();
  return proxy.start(claudeArgs);
}
