import chalk from "chalk";
import prompts from "prompts";
import {
  deletePairingConfig,
  isPaired,
  getConfigPath,
} from "../config/pairing-store.js";
import {
  removeClaudeWatchServer,
  isClaudeWatchConfigured,
  getMCPConfigPath,
} from "../config/mcp-config.js";
import {
  removeHook,
  isHookConfigured,
  getInstalledHookPath,
} from "../config/hooks-config.js";

/**
 * Remove Claude Watch configuration
 */
export async function runUnpair(): Promise<void> {
  console.log();
  console.log(chalk.bold.cyan("  Claude Watch Unpair"));
  console.log();

  const paired = isPaired();
  const claudeConfigured = isClaudeWatchConfigured();
  const hookConfigured = isHookConfigured();

  if (!paired && !claudeConfigured && !hookConfigured) {
    console.log(chalk.dim("  No configuration found."));
    console.log();
    return;
  }

  // Show what will be removed
  console.log(chalk.dim("  The following will be removed:"));
  console.log();
  if (paired) {
    console.log(`    ${chalk.yellow("•")} Pairing configuration`);
    console.log(`      ${chalk.dim(getConfigPath())}`);
  }
  if (claudeConfigured) {
    console.log(`    ${chalk.yellow("•")} Claude Code MCP server entry`);
    console.log(`      ${chalk.dim(getMCPConfigPath())}`);
  }
  if (hookConfigured) {
    console.log(`    ${chalk.yellow("•")} PreToolUse approval hook`);
    console.log(`      ${chalk.dim(getInstalledHookPath())}`);
  }
  console.log();

  // Confirm
  const response = await prompts({
    type: "confirm",
    name: "confirm",
    message: "Are you sure you want to remove the configuration?",
    initial: false,
  });

  if (!response.confirm) {
    console.log();
    console.log(chalk.dim("  Cancelled. No changes made."));
    console.log();
    return;
  }

  // Remove configs
  console.log();

  if (paired) {
    const deleted = deletePairingConfig();
    if (deleted) {
      console.log(chalk.green("  ✓ Pairing configuration removed"));
    }
  }

  if (claudeConfigured) {
    try {
      removeClaudeWatchServer();
      console.log(chalk.green("  ✓ Claude Code MCP server entry removed"));
    } catch (error) {
      console.log(chalk.red("  ✗ Failed to remove MCP server entry"));
    }
  }

  if (hookConfigured) {
    try {
      removeHook();
      console.log(chalk.green("  ✓ PreToolUse approval hook removed"));
    } catch (error) {
      console.log(chalk.red("  ✗ Failed to remove approval hook"));
    }
  }

  console.log();
  console.log(chalk.dim("  Done. Run npx claude-watch to set up again."));
  console.log();
}
