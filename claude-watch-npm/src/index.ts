#!/usr/bin/env node
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";
import { runCcWatch } from "./cli/cc-watch.js";
import { runRun } from "./cli/run.js";

const HELP = `
  Claude Watch - Control Claude Code from your Apple Watch

  Usage:
    npx claude-watch [command]

  Commands:
    (default)   Interactive setup wizard
    watch       Start progress monitor (alias: cc-watch)
    run [args]  Launch claude with watch question forwarding
    status      Check connection status
    serve       Start MCP server (called by Claude Code)
    unpair      Remove configuration
    help        Show this help message

  Examples:
    npx claude-watch           # Run setup wizard
    npx claude-watch watch     # Start progress monitor
    npx claude-watch run       # Launch interactive claude with watch
    npx claude-watch run "fix the bug"  # Launch with prompt
    npx claude-watch status    # Check status
    npx claude-watch unpair    # Remove configuration
`;

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0] || "";

  switch (command) {
    case "":
    case "setup":
      await runSetup();
      break;

    case "watch":
    case "cc-watch":
      await runCcWatch();
      break;

    case "run":
      // Pass remaining args to claude
      await runRun(args.slice(1));
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
export { runRun } from "./cli/run.js";
export { runMCPServer, createMCPServer } from "./server/index.js";
export * from "./types/index.js";
