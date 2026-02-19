/**
 * Setup command — pair with a watch, don't launch.
 *
 * Flow:
 * 1. Show header
 * 2. If already paired: show current pairing ID, ask "Reconfigure? (y/n)"
 * 3. Check cloud connectivity (BLOCKING)
 * 4. Prompt 6-digit code via askText
 * 5. Call completePairing, save config
 * 6. Show "Run `remmy run` to start a watch-supervised session."
 */

import { showHeader } from "../ui/header.ts";
import { Spinner } from "../ui/spinner.ts";
import { askText, askConfirm } from "../ui/prompt.ts";
import { green, dim, yellow } from "../ui/colors.ts";
import { readConfig, saveConfig, isPaired } from "../lib/config.ts";
import {
  checkConnectivity,
  completePairing,
  getCloudUrl,
} from "../lib/cloud-client.ts";

export async function runSetup(): Promise<void> {
  showHeader();

  // Read existing config upfront to get cloudUrl if available
  const existingConfig = readConfig();

  // Step 2: If already paired, offer reconfigure
  if (isPaired()) {
    const config = existingConfig!;
    const truncatedId = config.pairingId.slice(0, 8) + "...";
    process.stdout.write(`  Already paired: ${dim(truncatedId)}\n\n`);

    const reconfig = await askConfirm("  Reconfigure?", false);
    if (!reconfig) {
      return;
    }
    process.stdout.write("\n");
  }

  // Step 3: Check cloud connectivity (BLOCKING)
  // Prefer cloudUrl from existing config, fall back to env/default
  const cloudUrl = existingConfig?.cloudUrl ?? getCloudUrl();
  const spinner = new Spinner();
  spinner.start("Checking cloud connectivity...");

  const connectivity = await checkConnectivity(cloudUrl);

  if (!connectivity.connected) {
    spinner.fail(`Cloud unreachable: ${connectivity.error ?? "unknown error"}`);
    process.exitCode = 1;
    return;
  }

  spinner.succeed(`Cloud connected ${dim(`(${connectivity.latency}ms)`)}`);
  process.stdout.write("\n");

  // Step 4: Prompt for 6-digit code
  process.stdout.write(
    `  Open the Remmy app on your Apple Watch and tap ${yellow("Pair")}.\n`,
  );
  process.stdout.write("  Enter the 6-digit code shown on the watch:\n\n");

  const code = await askText("  Code: ", (input) => {
    const cleaned = input.trim().replace(/[-\s]/g, "");
    if (cleaned.length !== 6) {
      return "  Code must be 6 characters.";
    }
    return true;
  });

  if (code === null) {
    process.stdout.write("\n  Cancelled.\n");
    return;
  }

  // Step 5: Complete pairing
  spinner.start("Pairing...");

  try {
    const pairingId = await completePairing(code.trim(), cloudUrl);

    saveConfig({
      pairingId,
      cloudUrl,
      createdAt: new Date().toISOString(),
    });

    spinner.succeed("Paired successfully!");
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    spinner.fail(`Pairing failed: ${msg}`);
    process.exitCode = 1;
    return;
  }

  // Step 6: Next steps
  process.stdout.write("\n");
  process.stdout.write(
    `  ${green("Run")} ${dim("`remmy run`")} to start a watch-supervised session.\n`,
  );
  process.stdout.write("\n");
}
