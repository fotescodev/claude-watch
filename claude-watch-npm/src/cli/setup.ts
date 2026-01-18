import chalk from "chalk";
import ora from "ora";
import prompts from "prompts";
import {
  savePairingConfig,
  isPaired,
  readPairingConfig,
  createPairingConfig,
} from "../config/pairing-store.js";
import {
  addClaudeWatchServer,
  isClaudeWatchConfigured,
  getMCPConfigPath,
} from "../config/mcp-config.js";
import { PairingSession, createLocalPairing } from "../cloud/pairing.js";
import { CloudClient } from "../cloud/client.js";

type ConnectionMode = "cloud" | "local";

/**
 * Display the header
 */
function showHeader(): void {
  console.log();
  console.log(chalk.bold.cyan("  Claude Watch Setup"));
  console.log();
}

/**
 * Check if already configured
 */
async function checkExistingConfig(): Promise<boolean> {
  if (isPaired() && isClaudeWatchConfigured()) {
    const config = readPairingConfig();
    console.log(chalk.yellow("  Already configured!"));
    console.log();
    console.log(`  Pairing ID: ${chalk.dim(config?.pairingId?.slice(0, 8) + "...")}`);
    console.log(`  Cloud URL:  ${chalk.dim(config?.cloudUrl)}`);
    console.log();

    const response = await prompts({
      type: "confirm",
      name: "reconfigure",
      message: "Do you want to reconfigure?",
      initial: false,
    });

    if (!response.reconfigure) {
      console.log();
      console.log(chalk.green("  No changes made."));
      console.log();
      return false;
    }
  }

  return true;
}

/**
 * Ask for connection mode
 */
async function askConnectionMode(): Promise<ConnectionMode | null> {
  const response = await prompts({
    type: "select",
    name: "mode",
    message: "How do you want to connect?",
    choices: [
      {
        title: "Cloud Mode (recommended)",
        description: "Uses cloud relay for easy pairing with your watch",
        value: "cloud",
      },
      {
        title: "Local Mode",
        description: "Direct connection (requires same network)",
        value: "local",
      },
    ],
    initial: 0,
  });

  return response.mode as ConnectionMode | null;
}

/**
 * Run cloud pairing flow
 */
async function runCloudPairing(): Promise<string | null> {
  const session = new PairingSession();

  // Register with cloud
  const registerSpinner = ora("Registering pairing code...").start();
  const registered = await session.register();

  if (!registered) {
    registerSpinner.fail("Failed to register pairing code");
    console.log();
    console.log(
      chalk.yellow("  The cloud relay may be unavailable. Try local mode.")
    );
    console.log();
    return null;
  }

  registerSpinner.stop();

  // Show pairing code
  console.log();
  console.log(chalk.dim("  Your pairing code:"));
  console.log();
  console.log(chalk.bold.white(`    ${session.getFormattedCode()}`));
  console.log();
  console.log(chalk.dim("  Enter this on your Apple Watch."));
  console.log();

  // Wait for pairing
  const pairingSpinner = ora("Waiting for watch to pair...").start();

  const pairingId = await session.waitForPairing((attempt, max) => {
    const elapsed = Math.floor(attempt);
    const remaining = Math.floor((max - attempt) / 60);
    pairingSpinner.text = `Waiting for watch to pair... (${remaining}m remaining)`;
  });

  if (pairingId) {
    pairingSpinner.succeed("Watch paired!");
    return pairingId;
  } else {
    pairingSpinner.fail("Pairing timed out");
    await session.cleanup();
    return null;
  }
}

/**
 * Run local mode setup
 */
async function runLocalSetup(): Promise<string> {
  console.log();
  console.log(chalk.dim("  Local mode uses a direct connection."));
  console.log(chalk.dim("  Your watch must be on the same network."));
  console.log();

  const pairingId = createLocalPairing();
  console.log(`  Generated pairing ID: ${chalk.cyan(pairingId.slice(0, 8) + "...")}`);

  return pairingId;
}

/**
 * Configure Claude Code
 */
function configureClaude(): void {
  const spinner = ora("Configuring Claude Code...").start();

  try {
    addClaudeWatchServer();
    spinner.succeed("Claude Code configured");
    console.log();
    console.log(`  Config: ${chalk.dim(getMCPConfigPath())}`);
  } catch (error) {
    spinner.fail("Failed to configure Claude Code");
    console.error(error);
  }
}

/**
 * Verify cloud connectivity
 */
async function verifyCloud(cloudUrl: string): Promise<boolean> {
  const client = new CloudClient(cloudUrl);
  const result = await client.checkConnectivity();

  if (result.connected) {
    console.log(
      chalk.dim(`  Cloud: ${chalk.green("connected")} (${result.latency}ms)`)
    );
    return true;
  } else {
    console.log(
      chalk.dim(`  Cloud: ${chalk.red("not connected")} (${result.error})`)
    );
    return false;
  }
}

/**
 * Show completion message
 */
function showComplete(): void {
  console.log();
  console.log(chalk.green.bold("  Done!"));
  console.log();
  console.log(
    chalk.dim("  Your watch will buzz when Claude needs approval.")
  );
  console.log();
  console.log(chalk.dim("  Commands:"));
  console.log(chalk.dim("    npx claude-watch status   Check connection"));
  console.log(chalk.dim("    npx claude-watch unpair   Remove configuration"));
  console.log();
}

/**
 * Main setup wizard
 */
export async function runSetup(): Promise<void> {
  showHeader();

  // Check existing config
  const shouldContinue = await checkExistingConfig();
  if (!shouldContinue) {
    return;
  }

  // Ask for connection mode
  const mode = await askConnectionMode();
  if (!mode) {
    console.log(chalk.yellow("  Setup cancelled."));
    return;
  }

  console.log();

  let pairingId: string | null = null;
  let cloudUrl = "https://claude-watch.fly.dev";

  if (mode === "cloud") {
    // Check cloud connectivity first
    const cloudConnected = await verifyCloud(cloudUrl);
    if (!cloudConnected) {
      console.log();
      console.log(
        chalk.yellow("  Cloud relay unavailable. Falling back to local mode.")
      );
      pairingId = await runLocalSetup();
    } else {
      pairingId = await runCloudPairing();
    }
  } else {
    pairingId = await runLocalSetup();
    cloudUrl = "http://localhost:8787"; // Local server
  }

  if (!pairingId) {
    console.log();
    console.log(chalk.red("  Setup failed. Please try again."));
    console.log();
    return;
  }

  // Save config
  const config = createPairingConfig(cloudUrl);
  config.pairingId = pairingId;
  savePairingConfig(config);

  // Configure Claude Code
  console.log();
  configureClaude();

  // Show completion
  showComplete();
}
