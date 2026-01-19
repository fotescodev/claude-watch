import chalk from "chalk";
import ora from "ora";
import prompts from "prompts";
import { spawn } from "child_process";
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
import { createLocalPairing } from "../cloud/pairing.js";
import { CloudClient } from "../cloud/client.js";

type ConnectionMode = "cloud" | "local";

/**
 * Build the command and arguments for launching Claude Code.
 * If a wrapper is provided, uses the pattern: <wrapper> run claude
 * Otherwise, launches claude directly.
 *
 * @param wrapper - Optional wrapper command (e.g., 'specstory')
 * @returns Object with command and args for spawn()
 */
function buildClaudeCommand(wrapper?: string): { command: string; args: string[] } {
  if (wrapper) {
    return { command: wrapper, args: ["run", "claude"] };
  }
  return { command: "claude", args: [] };
}

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
      // Already paired - offer to start Claude anyway
      await offerStartClaude();
      return false;
    }
  }

  return true;
}

/**
 * Offer to start Claude Code (used when already paired)
 */
async function offerStartClaude(): Promise<void> {
  const response = await prompts({
    type: "confirm",
    name: "startClaude",
    message: "Start Claude Code with watch approvals?",
    initial: true,
  });

  if (response.startClaude) {
    // Ask for project directory
    const dirResponse = await prompts({
      type: "text",
      name: "projectDir",
      message: "Project directory:",
      initial: process.cwd(),
    });

    const projectDir = dirResponse.projectDir || process.cwd();

    // Get wrapper from config (if configured)
    const config = readPairingConfig();
    const { command, args } = buildClaudeCommand(config?.wrapper);

    console.log();
    console.log(chalk.cyan(`  Starting Claude Code in ${projectDir}...`));
    if (config?.wrapper) {
      console.log(chalk.dim(`  Using wrapper: ${config.wrapper}`));
    }
    console.log();

    const claude = spawn(command, args, {
      stdio: "inherit",
      shell: true,
      cwd: projectDir,
    });

    claude.on("error", (err) => {
      console.error(chalk.red(`  Failed to start Claude: ${err.message}`));
    });

    await new Promise<void>((resolve) => {
      claude.on("close", () => resolve());
    });
  }
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
 * Run cloud pairing flow (NEW: User enters code from watch)
 */
async function runCloudPairing(cloudUrl: string): Promise<string | null> {
  console.log();
  console.log(chalk.dim("  Open Claude Watch on your Apple Watch."));
  console.log(chalk.dim("  Tap 'Pair Now' to see a 6-digit code."));
  console.log();

  // Prompt for code from watch
  const response = await prompts({
    type: "text",
    name: "code",
    message: "Enter the code from your watch:",
    validate: (value: string) => {
      const cleaned = value.replace(/\s/g, "");
      if (/^\d{6}$/.test(cleaned)) {
        return true;
      }
      return "Enter 6 digits (shown on your watch)";
    },
  });

  if (!response.code) {
    console.log(chalk.yellow("  Pairing cancelled."));
    return null;
  }

  // Clean up the code (remove spaces)
  const code = response.code.replace(/\s/g, "");

  // Submit code to cloud
  const pairingSpinner = ora("Completing pairing...").start();

  try {
    const res = await fetch(`${cloudUrl}/pair/complete`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ code }),
    });

    if (!res.ok) {
      const error = await res.json().catch(() => ({ error: "Unknown error" }));
      if (res.status === 404) {
        pairingSpinner.fail("Invalid or expired code");
        console.log();
        console.log(
          chalk.yellow("  Make sure your watch is showing a fresh code.")
        );
        console.log();
        return null;
      }
      throw new Error((error as { error: string }).error || `HTTP ${res.status}`);
    }

    const data = (await res.json()) as { pairingId: string };
    pairingSpinner.succeed("Watch paired!");
    return data.pairingId;
  } catch (error) {
    pairingSpinner.fail(`Pairing failed: ${(error as Error).message}`);
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
 * Show completion message and optionally start Claude Code
 */
async function showComplete(): Promise<void> {
  console.log();
  console.log(chalk.green.bold("  Paired!"));
  console.log();
  console.log(
    chalk.dim("  Your watch will buzz when Claude needs approval.")
  );
  console.log();

  // Ask if user wants to start Claude Code
  const response = await prompts({
    type: "confirm",
    name: "startClaude",
    message: "Start Claude Code with watch approvals enabled?",
    initial: true,
  });

  if (response.startClaude) {
    // Ask for project directory
    const dirResponse = await prompts({
      type: "text",
      name: "projectDir",
      message: "Project directory (or Enter for current):",
      initial: process.cwd(),
    });

    const projectDir = dirResponse.projectDir || process.cwd();

    // Get wrapper from config (if configured)
    const config = readPairingConfig();
    const { command, args } = buildClaudeCommand(config?.wrapper);

    console.log();
    console.log(chalk.cyan(`  Starting Claude Code in ${projectDir}...`));
    if (config?.wrapper) {
      console.log(chalk.dim(`  Using wrapper: ${config.wrapper}`));
    }
    console.log(chalk.dim("  (All tool calls will require watch approval)"));
    console.log();

    // Start Claude Code in the specified directory
    const claude = spawn(command, args, {
      stdio: "inherit",
      shell: true,
      cwd: projectDir,
    });

    claude.on("error", (err) => {
      console.error(chalk.red(`  Failed to start Claude: ${err.message}`));
      console.log();
      console.log(chalk.dim("  Try running 'claude' manually."));
    });

    // Wait for Claude to exit
    await new Promise<void>((resolve) => {
      claude.on("close", () => resolve());
    });
  } else {
    console.log();
    console.log(chalk.dim("  Commands:"));
    console.log(chalk.dim("    claude                    Start Claude Code"));
    console.log(chalk.dim("    npx claude-watch status   Check connection"));
    console.log(chalk.dim("    npx claude-watch unpair   Remove configuration"));
    console.log();
  }
}

/**
 * Main setup wizard
 * @param wrapper - Optional wrapper command to use when launching Claude (e.g., 'specstory')
 */
export async function runSetup(wrapper?: string): Promise<void> {
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
  let cloudUrl = "https://claude-watch.fotescodev.workers.dev";

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
      pairingId = await runCloudPairing(cloudUrl);
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
  if (wrapper) {
    config.wrapper = wrapper;
  }
  savePairingConfig(config);

  // Configure Claude Code
  console.log();
  configureClaude();

  // Show completion and optionally start Claude
  await showComplete();
}
