#!/usr/bin/env node
import { spawn } from "child_process";
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";
import { runCcWatch } from "./cli/cc-watch.js";
import { isPaired } from "./config/pairing-store.js";

const HELP = `
  Claude Watch - Approve Claude Code actions from your Apple Watch

  Usage:
    npx cc-watch                 Pair (if needed) + launch Claude with watch approvals
    npx cc-watch [command]       Run a specific command

  Commands:
    (default)   Pair (if needed) + install hook + launch Claude
    run         Launch Claude with watch approvals (skips pairing check)
    setup       Pair + install hook only (no launch)
    status      Check connection status
    unpair      Remove configuration and hook
    help        Show this help message

  Other \`claude\` sessions run normally without watch routing.

  Examples:
    npx cc-watch                 # Pair and launch Claude
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

    case "run": {
      // Guard: must be paired first
      if (!isPaired()) {
        console.error("Not paired. Run `npx cc-watch` first to pair with your watch.");
        process.exit(1);
      }
      // Launch claude with watch session env var — forwards all extra args
      const claudeArgs = args.slice(1);
      const claude = spawn("claude", claudeArgs, {
        stdio: "inherit",
        env: { ...process.env, CLAUDE_WATCH_SESSION_ACTIVE: "1" },
      });
      claude.on("close", (code) => process.exit(code ?? 0));
      claude.on("error", (err) => {
        console.error(`Failed to start claude: ${err.message}`);
        process.exit(1);
      });
      return; // don't fall through — wait for claude to exit
    }

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
