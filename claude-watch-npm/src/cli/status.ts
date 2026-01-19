import chalk from "chalk";
import {
  isPaired,
  readPairingConfig,
  getConfigPath,
} from "../config/pairing-store.js";
import {
  isClaudeWatchConfigured,
  getMCPConfigPath,
} from "../config/mcp-config.js";
import { CloudClient } from "../cloud/client.js";

/**
 * Display connection status
 */
export async function runStatus(): Promise<void> {
  console.log();
  console.log(chalk.bold.cyan("  Claude Watch Status"));
  console.log();

  // Check pairing
  const paired = isPaired();
  const config = readPairingConfig();

  console.log(chalk.dim("  Pairing:"));
  if (paired && config) {
    console.log(`    Status:     ${chalk.green("configured")}`);
    console.log(`    Pairing ID: ${chalk.dim(config.pairingId.slice(0, 8) + "...")}`);
    console.log(`    Cloud URL:  ${chalk.dim(config.cloudUrl)}`);
    console.log(`    Created:    ${chalk.dim(config.createdAt)}`);
    if (config.watchId) {
      console.log(`    Watch ID:   ${chalk.dim(config.watchId)}`);
    }
  } else {
    console.log(`    Status: ${chalk.yellow("not configured")}`);
    console.log(chalk.dim(`    Run ${chalk.white("npx claude-watch")} to set up`));
  }
  console.log();

  // Check Claude Code config
  const claudeConfigured = isClaudeWatchConfigured();
  console.log(chalk.dim("  Claude Code:"));
  if (claudeConfigured) {
    console.log(`    MCP Server: ${chalk.green("configured")}`);
    console.log(`    Config:     ${chalk.dim(getMCPConfigPath())}`);
  } else {
    console.log(`    MCP Server: ${chalk.yellow("not configured")}`);
    console.log(chalk.dim(`    Run ${chalk.white("npx claude-watch")} to set up`));
  }
  console.log();

  // Check cloud connectivity (if paired)
  if (paired && config) {
    console.log(chalk.dim("  Cloud Relay:"));
    const client = new CloudClient(config.cloudUrl, config.pairingId);
    const result = await client.checkConnectivity();

    if (result.connected) {
      console.log(`    Status:  ${chalk.green("connected")}`);
      console.log(`    Latency: ${chalk.dim(result.latency + "ms")}`);
    } else {
      console.log(`    Status: ${chalk.red("not connected")}`);
      console.log(`    Error:  ${chalk.dim(result.error)}`);
    }
    console.log();
  }

  // Show config file locations
  console.log(chalk.dim("  Config Files:"));
  console.log(`    Pairing: ${chalk.dim(getConfigPath())}`);
  console.log(`    MCP:     ${chalk.dim(getMCPConfigPath())}`);
  console.log();

  // Summary
  if (paired && claudeConfigured) {
    console.log(chalk.green("  Ready to use!"));
    console.log(
      chalk.dim("  Your watch will receive notifications from Claude.")
    );
  } else {
    console.log(chalk.yellow("  Setup incomplete."));
    console.log(chalk.dim(`  Run ${chalk.white("npx claude-watch")} to complete setup.`));
  }
  console.log();
}
