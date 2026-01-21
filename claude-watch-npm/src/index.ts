#!/usr/bin/env node
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";
import { runCcWatch } from "./cli/cc-watch.js";
import { runClaudeProxy } from "./cli/stdin-proxy.js";

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

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0] || "";

  // If first arg looks like a task (not a known command), run proxy directly
  // e.g., `npx cc-watch "build a login feature"`
  const knownCommands = ["", "setup", "watch", "cc-watch", "claude", "status", "serve", "unpair", "help", "--help", "-h", "version", "--version", "-v"];
  if (command && !knownCommands.includes(command)) {
    // Treat as task - run Claude with proxy
    const exitCode = await runClaudeProxy(args);
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

    case "claude": {
      // Run Claude with stdin proxy for watch question support
      const claudeArgs = args.slice(1); // Remove 'claude' from args
      const exitCode = await runClaudeProxy(claudeArgs);
      process.exit(exitCode);
    }

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
export { runClaudeProxy, StdinProxy } from "./cli/stdin-proxy.js";
export { runMCPServer, createMCPServer } from "./server/index.js";
export * from "./types/index.js";
