#!/usr/bin/env node
import { spawn } from "child_process";
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";
import { runCcWatch } from "./cli/cc-watch.js";
import { readPairingConfig, isPaired } from "./config/pairing-store.js";

const HELP = `
  Claude Watch - Control Claude Code from your Apple Watch

  Usage:
    npx cc-watch                 Pair (if needed) then run Claude with watch support
    npx cc-watch "task"          Run Claude directly with a task
    npx cc-watch [command]       Run a specific command

  Commands:
    (default)   Pair + prompt for task + run Claude with full watch support
    status      Check connection status
    watch       Start progress monitor only (no Claude)
    unpair      Remove configuration
    help        Show this help message

  Examples:
    npx cc-watch                           # Pair and run Claude interactively
    npx cc-watch "build a login feature"   # Run Claude directly with task
    npx cc-watch status                    # Check pairing status
`;

/**
 * Run Claude with watch session environment variables.
 * Tool approvals are handled by watch-approval-cloud.py hook.
 * Questions are answered in terminal (watch can only approve/reject).
 */
async function runClaudeWithWatch(args: string[]): Promise<number> {
  const config = readPairingConfig();
  if (!config?.pairingId) {
    console.error("Not paired. Run 'npx cc-watch' first to pair.");
    return 1;
  }

  return new Promise((resolve) => {
    const claudeProcess = spawn("claude", args, {
      stdio: "inherit",
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
        CLAUDE_WATCH_PAIRING_ID: config.pairingId,
      },
    });

    claudeProcess.on("close", (code) => resolve(code ?? 0));
    claudeProcess.on("error", () => resolve(1));
  });
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0] || "";

  // If first arg looks like a task (not a known command), run Claude directly
  // e.g., `npx cc-watch "build a login feature"`
  const knownCommands = ["", "setup", "watch", "cc-watch", "status", "serve", "unpair", "help", "--help", "-h", "version", "--version", "-v"];
  if (command && !knownCommands.includes(command)) {
    // Treat as task - run Claude with watch env vars
    const exitCode = await runClaudeWithWatch(args);
    process.exit(exitCode);
  }

  switch (command) {
    case "":
    case "setup":
      await runSetup();
      break;

    case "watch":
    case "cc-watch":
      await runCcWatch();
      break;

    case "status":
      await runStatus();
      break;

    case "serve":
      await runServe();
      break;

    case "unpair":
      await runUnpair();
      break;

    case "help":
    case "--help":
    case "-h":
      console.log(HELP);
      break;

    case "version":
    case "--version":
    case "-v":
      console.log("cc-watch v0.1.1");
      break;

    default:
      console.error(`Unknown command: ${command}`);
      console.log(HELP);
      process.exit(1);
  }
}

main().catch((error) => {
  console.error("Error:", error);
  process.exit(1);
});

// Export for programmatic use
export { runSetup } from "./cli/setup.js";
export { runStatus } from "./cli/status.js";
export { runUnpair } from "./cli/unpair.js";
export { runServe } from "./cli/serve.js";
export { runCcWatch } from "./cli/cc-watch.js";
export { runMCPServer, createMCPServer } from "./server/index.js";
export * from "./types/index.js";
