/**
 * Default command — the main happy path.
 *
 * 1. Show header
 * 2. Migrate legacy config if present
 * 3. If paired → informational cloud check → launch bridge + Claude
 * 4. If unpaired → blocking cloud check → pair → launch bridge + Claude
 * 5. Stop bridge on Claude exit
 */

import { showHeader } from "../ui/header.ts";
import { Spinner } from "../ui/spinner.ts";
import { askText } from "../ui/prompt.ts";
import { green, yellow, red, dim } from "../ui/colors.ts";
import {
  readConfig,
  saveConfig,
  isPaired,
  createConfig,
  migrateLegacyConfig,
} from "../lib/config.ts";
import {
  checkConnectivity,
  completePairing,
  getCloudUrl,
} from "../lib/cloud-client.ts";
import { launchBridge, stopBridge } from "../lib/bridge-launcher.ts";
import { launchClaude } from "../lib/claude-launcher.ts";

export async function runDefault(): Promise<void> {
  showHeader();
  migrateLegacyConfig();

  if (isPaired()) {
    await pairedFlow();
  } else {
    await unpairedFlow();
  }
}

async function pairedFlow(): Promise<void> {
  const config = readConfig()!;
  const cloudUrl = config.cloudUrl ?? getCloudUrl();
  const truncatedId = config.pairingId.substring(0, 8);
  process.stdout.write(`  ${dim("Pairing ID:")} ${truncatedId}\n`);

  // Cloud check is INFORMATIONAL when paired — warn but don't block
  const connectivity = await checkConnectivity();
  if (!connectivity.connected) {
    process.stdout.write(
      `  ${yellow("Cloud unreachable")} — watch notifications may be delayed\n`,
    );
  }

  // Launch bridge + Claude
  await launchAndRun(config.pairingId, cloudUrl);
}

async function unpairedFlow(): Promise<void> {
  process.stdout.write(
    `\n  ${yellow("Not paired.")} Let's set up your watch connection.\n\n`,
  );

  // Cloud check is BLOCKING when unpaired — can't pair without cloud
  const connectivity = await checkConnectivity();
  if (!connectivity.connected) {
    process.stdout.write(
      `  ${red("Cannot reach cloud relay")} — check your internet connection.\n`,
    );
    return;
  }

  // Prompt for 6-digit code from watch
  const code = await askText(
    `  Enter the 6-digit code from your watch: `,
    (input: string) => {
      if (/^\d{6}$/.test(input)) return true;
      return "Please enter exactly 6 digits.";
    },
  );

  if (!code) return;

  // Complete pairing via cloud
  const spinner = new Spinner();
  spinner.start("Completing pairing...");

  let pairingId: string;
  try {
    pairingId = await completePairing(code);
  } catch (err) {
    spinner.fail((err as Error).message);
    return;
  }

  spinner.succeed("Paired successfully!");

  // Save config
  const cloudUrl = getCloudUrl();
  const config = createConfig(cloudUrl);
  config.pairingId = pairingId;
  saveConfig(config);

  // Launch bridge + Claude
  await launchAndRun(pairingId, cloudUrl);
}

/**
 * Shared launch logic: start bridge, register SIGINT, launch Claude, cleanup.
 */
async function launchAndRun(pairingId: string, cloudUrl?: string): Promise<void> {
  const bridge = await launchBridge({
    pairingId,
    port: 8787,
    cloudUrl: cloudUrl ?? getCloudUrl(),
  });

  // Handle Ctrl+C — stop bridge gracefully
  const onSigint = async () => {
    process.stdout.write("\n");
    await stopBridge(bridge);
    process.exit(130);
  };
  process.on("SIGINT", onSigint);

  process.stdout.write(
    `\n  ${green("Launching Claude with watch approvals...")}\n`,
  );
  process.stdout.write(
    `  ${dim("Other `claude` sessions run normally.")}\n\n`,
  );

  const exitCode = await launchClaude({
    sdkUrl: `ws://localhost:${bridge.port}/ws/cli/${bridge.pairingId}`,
  });

  process.removeListener("SIGINT", onSigint);
  await stopBridge(bridge);
  process.exit(exitCode);
}
