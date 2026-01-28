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
  setupHook,
  isHookConfigured,
  getInstalledHookPath,
} from "../config/hooks-config.js";
import { CloudClient } from "../cloud/client.js";

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
  if (isPaired() && isHookConfigured()) {
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
      console.log(chalk.green.bold("  Ready!"));
      console.log(
        chalk.dim("  Run `claude` normally. Tool calls route to your watch.")
      );
      console.log();
      return false;
    }
  }

  return true;
}

/**
 * Run cloud pairing flow (user enters code from watch)
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
 * Install and register the PreToolUse hook
 */
function configureHook(): void {
  const hookSpinner = ora("Installing approval hook...").start();
  try {
    const result = setupHook();
    if (result.installed && result.registered) {
      hookSpinner.succeed("Approval hook installed");
      console.log(`  Hook: ${chalk.dim(getInstalledHookPath())}`);
    } else if (!result.installed) {
      hookSpinner.fail("Failed to install hook script");
    } else {
      hookSpinner.fail("Failed to register hook");
    }
  } catch (error) {
    hookSpinner.fail("Failed to configure hook");
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
 * Main setup wizard
 *
 * Flow: check existing -> pair via cloud -> install hook -> print Ready -> exit
 * Does NOT spawn Claude. User runs `claude` separately.
 */
export async function runSetup(): Promise<void> {
  showHeader();

  // Check existing config
  const shouldContinue = await checkExistingConfig();
  if (!shouldContinue) {
    return;
  }

  const cloudUrl = "https://claude-watch.fotescodev.workers.dev";

  // Check cloud connectivity first
  console.log();
  const cloudConnected = await verifyCloud(cloudUrl);
  if (!cloudConnected) {
    console.log();
    console.log(chalk.red("  Cloud relay unavailable. Cannot pair."));
    console.log();
    return;
  }

  // Run cloud pairing
  const pairingId = await runCloudPairing(cloudUrl);
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

  // Install hook
  console.log();
  configureHook();

  // Done
  console.log();
  console.log(chalk.green.bold("  Ready!"));
  console.log(
    chalk.dim("  Run `claude` normally. Tool calls route to your watch.")
  );
  console.log();
  console.log(chalk.dim("  Commands:"));
  console.log(chalk.dim("    npx cc-watch status   Check connection"));
  console.log(chalk.dim("    npx cc-watch unpair   Remove configuration"));
  console.log();
}
