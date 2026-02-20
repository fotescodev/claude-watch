#!/usr/bin/env node
/**
 * Remmy CLI entry point — command router and global flag handling.
 * Zero runtime dependencies.
 */

import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const pkg: { version: string } = JSON.parse(
  readFileSync(join(__dirname, "../package.json"), "utf8")
);

/** Package version read from package.json */
export const VERSION = pkg.version;

/** Global verbose flag — set by --verbose, readable by other modules */
export let verbose = false;

/** Help text displayed for help / --help / -h and on unknown commands */
export const HELP = `
  Remmy - Approve Claude Code changes from your Apple Watch

  Usage:
    remmy                    Pair (if needed) + launch Claude with watch approvals
    remmy [command]          Run a specific command

  Commands:
    (default)   Pair (if needed) + launch bridge + Claude
    run         Launch bridge + Claude (must be paired)
    setup       Pair only (no launch)
    status      Check connection status
    unpair      Remove configuration
    help        Show this help message

  Options:
    --verbose   Enable verbose logging

  Other \`claude\` sessions run normally without watch routing.

  Examples:
    remmy                      # Pair and launch Claude
    remmy run --model opus     # Launch with specific model
    remmy status               # Check pairing status
    remmy unpair               # Remove watch integration
`;

/**
 * Route CLI arguments to the appropriate command handler.
 * Exported separately from main() for testability.
 */
export async function route(args: string[]): Promise<void> {
  // Reset verbose for each invocation
  verbose = false;

  // Extract global --verbose flag from anywhere in args
  const filteredArgs = args.filter((arg) => {
    if (arg === "--verbose") {
      verbose = true;
      return false;
    }
    return true;
  });

  const command = filteredArgs[0] ?? "";

  switch (command) {
    case "": {
      const { runDefault } = await import("./commands/default.ts");
      await runDefault();
      break;
    }
    case "setup": {
      const { runSetup } = await import("./commands/setup.ts");
      await runSetup();
      break;
    }
    case "run": {
      const extraArgs = filteredArgs.slice(1);
      const { runRun } = await import("./commands/run.ts");
      await runRun(extraArgs);
      break;
    }
    case "status": {
      const { runStatus } = await import("./commands/status.ts");
      await runStatus();
      break;
    }
    case "unpair": {
      const { runUnpair } = await import("./commands/unpair.ts");
      await runUnpair();
      break;
    }
    case "help":
    case "--help":
    case "-h":
      console.log(HELP);
      break;
    case "version":
    case "--version":
    case "-v":
      console.log(VERSION);
      break;
    default:
      console.error(`Unknown command: ${command}`);
      console.log(HELP);
      process.exit(1);
  }
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  await route(args);
}

// Run when executed directly, not when imported by tests.
// Bun: import.meta.main is true (entry) or false (imported).
// Node: import.meta.main is undefined, and undefined !== false is true.
if (import.meta.main !== false) {
  main().catch((error: Error) => {
    console.error("Error:", error.message || error);
    process.exit(1);
  });
}
