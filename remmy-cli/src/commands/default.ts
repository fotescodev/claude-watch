/**
 * Default command — the main happy path.
 *
 * 1. Show header
 * 2. Migrate legacy config if present
 * 3. If paired → informational cloud check → ensure hook → launch Claude
 * 4. If unpaired → blocking cloud check → pair → ensure hook → launch Claude
 */

import { showHeader } from "../ui/header.ts";
import { Spinner } from "../ui/spinner.ts";
import { askText, askConfirm } from "../ui/prompt.ts";
import { green, yellow, red, dim } from "../ui/colors.ts";
import {
  readConfig,
  saveConfig,
  isPaired,
  createConfig,
  deleteConfig,
  migrateLegacyConfig,
} from "../lib/config.ts";
import {
  checkConnectivity,
  completePairing,
  getCloudUrl,
} from "../lib/cloud-client.ts";
import { setupHook } from "../lib/hooks-config.ts";
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
  process.stdout.write(`  ${dim("Paired as")} ${truncatedId}\n`);

  // Ask if user wants to keep this pairing
  const keepPairing = await askConfirm(`  Keep this pairing?`, true);
  if (keepPairing === null) return; // Ctrl+C
  if (!keepPairing) {
    deleteConfig();
    await unpairedFlow();
    return;
  }

  // Cloud check is INFORMATIONAL when paired — warn but don't block
  const connectivity = await checkConnectivity(cloudUrl);
  if (!connectivity.connected) {
    process.stdout.write(
      `  ${yellow("Cloud unreachable")} — watch notifications may be delayed\n`,
    );
  }

  // Ensure hook is installed
  ensureHook();

  // Launch Claude with watch session active
  await launchAndRun();
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

  // Ensure hook is installed
  ensureHook();

  // Launch Claude with watch session active
  await launchAndRun();
}

/**
 * Install the watch-approval hook if not already configured.
 */
function ensureHook(): void {
  const result = setupHook();
  if (result.installed && result.registered) {
    process.stdout.write(`  ${dim("Hook installed")} ✓\n`);
  } else if (!result.installed) {
    process.stdout.write(
      `  ${yellow("Warning:")} Could not install hook script.\n`,
    );
  }
}

/**
 * Launch Claude with CLAUDE_WATCH_SESSION_ACTIVE=1 and exit when it does.
 */
async function launchAndRun(): Promise<void> {
  process.stdout.write(
    `\n  ${green("Launching Claude with watch approvals...")}\n`,
  );
  process.stdout.write(
    `  ${dim("Other `claude` sessions run normally.")}\n\n`,
  );

  const exitCode = await launchClaude();
  process.exit(exitCode);
}
