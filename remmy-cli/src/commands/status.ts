/**
 * Status command — show pairing and connectivity info.
 *
 * Flow:
 * 1. Show header
 * 2. If paired: show pairingId (truncated), cloudUrl, createdAt, watchId
 * 3. If not paired: show "Not paired" + "Run `remmy` to set up"
 * 4. Check cloud connectivity, show latency or error
 * 5. Show config file path via getConfigPath()
 */

import { showHeader } from "../ui/header.ts";
import { Spinner } from "../ui/spinner.ts";
import { green, red, dim, yellow } from "../ui/colors.ts";
import { readConfig, isPaired, getConfigPath } from "../lib/config.ts";
import { checkConnectivity, getCloudUrl } from "../lib/cloud-client.ts";

export async function runStatus(): Promise<void> {
  showHeader();

  // Steps 2-3: Pairing status
  if (isPaired()) {
    const config = readConfig()!;
    const truncatedId = config.pairingId.slice(0, 8) + "...";

    process.stdout.write(`  ${green("Paired")}\n\n`);
    process.stdout.write(`  Pairing ID:  ${dim(truncatedId)}\n`);
    process.stdout.write(`  Cloud URL:   ${dim(config.cloudUrl)}\n`);
    process.stdout.write(`  Created:     ${dim(config.createdAt)}\n`);

    if (config.watchId) {
      process.stdout.write(`  Watch ID:    ${dim(config.watchId)}\n`);
    }
  } else {
    process.stdout.write(`  ${yellow("Not paired")}\n\n`);
    process.stdout.write(`  Run ${dim("`remmy`")} to set up.\n`);
  }

  process.stdout.write("\n");

  // Step 4: Cloud connectivity
  const spinner = new Spinner();
  spinner.start("Checking cloud connectivity...");

  const cloudUrl = getCloudUrl();
  const connectivity = await checkConnectivity(cloudUrl);

  if (connectivity.connected) {
    spinner.succeed(
      `Cloud reachable ${dim(`(${connectivity.latency}ms)`)}`,
    );
  } else {
    spinner.fail(
      `Cloud unreachable: ${red(connectivity.error ?? "unknown error")}`,
    );
  }

  // Step 5: Config file path
  process.stdout.write(`\n  Config: ${dim(getConfigPath())}\n\n`);
}
