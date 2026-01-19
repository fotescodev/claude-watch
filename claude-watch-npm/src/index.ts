#!/usr/bin/env node
import { runSetup } from "./cli/setup.js";
import { runStatus } from "./cli/status.js";
import { runUnpair } from "./cli/unpair.js";
import { runServe } from "./cli/serve.js";

const HELP = `
  Claude Watch - Control Claude Code from your Apple Watch

  Usage:
    npx claude-watch [command] [options]

  Commands:
    (default)   Interactive setup wizard
    status      Check connection status
    serve       Start MCP server (called by Claude Code)
    unpair      Remove configuration
    help        Show this help message

  Options:
    --wrapper=<name>   Use a wrapper command to launch Claude (e.g., specstory)
    --specstory        Shortcut for --wrapper=specstory

  Examples:
    npx claude-watch                    # Run setup wizard
    npx claude-watch --specstory        # Setup with specstory wrapper
    npx claude-watch --wrapper=mytool   # Setup with custom wrapper
    npx claude-watch status             # Check status
    npx claude-watch unpair             # Remove configuration
`;

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  // Extract flags before command routing
  const flags = args.filter((arg) => arg.startsWith("--"));
  const nonFlagArgs = args.filter((arg) => !arg.startsWith("--"));
  const command = nonFlagArgs[0] || "";

  // Parse wrapper flags: --wrapper=value takes precedence over --specstory
  const wrapperFlag = flags.find((f) => f.startsWith("--wrapper="));
  const wrapperValue = wrapperFlag?.split("=")[1];
  const wrapper =
    wrapperValue && wrapperValue.trim() !== ""
      ? wrapperValue
      : flags.includes("--specstory")
        ? "specstory"
        : undefined;

  switch (command) {
    case "":
    case "setup":
      await runSetup(wrapper);
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
export { runMCPServer, createMCPServer } from "./server/index.js";
export * from "./types/index.js";
