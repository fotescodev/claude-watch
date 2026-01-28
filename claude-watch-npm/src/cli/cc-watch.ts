import chalk from "chalk";
import ora from "ora";
import prompts from "prompts";
import {
  isPaired,
  readPairingConfig,
  savePairingConfig,
  createPairingConfig,
} from "../config/pairing-store.js";
import {
  isHookConfigured,
  setupHook,
  getInstalledHookPath,
} from "../config/hooks-config.js";
import { CloudClient } from "../cloud/client.js";

// Default URLs
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";

/**
 * Display the cc-watch header
 */
function showHeader(): void {
  console.log();
  console.log(chalk.bold.cyan("  cc-watch"));
  console.log();
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
 * Run cloud pairing flow - user enters code from watch
 */
async function runPairing(cloudUrl: string): Promise<string | null> {
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
 * Ensure the hook is installed and registered
 */
function ensureHook(): void {
  if (isHookConfigured()) {
    console.log(chalk.dim(`  Hook: ${chalk.green("installed")}`));
    return;
  }

  const hookSpinner = ora("Installing approval hook...").start();
  const result = setupHook();
  if (result.installed && result.registered) {
    hookSpinner.succeed("Approval hook installed");
    console.log(chalk.dim(`  Hook: ${getInstalledHookPath()}`));
  } else {
    hookSpinner.warn("Hook installation incomplete - approvals may not work");
  }
}

/**
 * Main cc-watch command
 *
 * Flow: pair (if needed) -> install hook -> print Ready -> exit
 * Does NOT spawn Claude. User runs `claude` separately.
 */
export async function runCcWatch(): Promise<void> {
  showHeader();

  const cloudUrl = DEFAULT_CLOUD_URL;

  // Check if already paired
  const paired = isPaired();
  const config = readPairingConfig();

  if (paired && config) {
    // Already paired
    console.log(chalk.dim(`  Paired: ${config.pairingId.slice(0, 8)}...`));

    // Verify connectivity
    await verifyCloud(cloudUrl);

    // Ensure hook is installed
    ensureHook();
  } else {
    // Need to pair first
    console.log(chalk.dim("  Not paired. Starting pairing flow..."));

    // Check cloud connectivity
    const cloudConnected = await verifyCloud(cloudUrl);
    if (!cloudConnected) {
      console.log();
      console.log(chalk.red("  Cloud relay unavailable. Cannot pair."));
      console.log();
      return;
    }

    // Run pairing
    const pairingId = await runPairing(cloudUrl);
    if (!pairingId) {
      console.log();
      console.log(chalk.red("  Pairing failed."));
      console.log();
      return;
    }

    // Save config
    const newConfig = createPairingConfig(cloudUrl);
    newConfig.pairingId = pairingId;
    savePairingConfig(newConfig);

    console.log(chalk.green("  Pairing saved!"));
    console.log();

    // Install hook
    ensureHook();
  }

  // Done — user runs `claude` separately
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
