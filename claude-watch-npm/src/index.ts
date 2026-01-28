#!/usr/bin/env node
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";
import { runCcWatch } from "./cli/cc-watch.js";

const HELP = `
  Claude Watch - Approve Claude Code actions from your Apple Watch

  Usage:
    npx cc-watch                 Pair with watch and install hook
    npx cc-watch [command]       Run a specific command

  Commands:
    (default)   Pair (if needed) + install hook + exit
    setup       Full setup wizard
    status      Check connection status
    unpair      Remove configuration and hook
    help        Show this help message

  After setup, run \`claude\` normally. Tool calls route to your watch.

  Examples:
    npx cc-watch                 # Pair and install hook
    npx cc-watch status          # Check pairing status
    npx cc-watch unpair          # Remove watch integration
`;

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const command = args[0] || "";

  switch (command) {
    case "":
      await runCcWatch();
      break;

    case "setup":
      await runSetup();
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
      console.log("cc-watch v0.1.4");
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
