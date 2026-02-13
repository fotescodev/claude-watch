/**
 * Run command — launch bridge + Claude. Must be paired.
 *
 * Flow:
 * 1. Check isPaired(). If not, error: "Not paired. Run `remmy` first."
 * 2. Read config for pairingId
 * 3. Launch bridge with pairingId
 * 4. Launch Claude with --sdk-url and extraArgs
 * 5. On exit: stop bridge, exit with same code
 * 6. Handle SIGINT
 */

import { Spinner } from "../ui/spinner.ts";
import { dim, red } from "../ui/colors.ts";
import { readConfig, isPaired } from "../lib/config.ts";
import { getCloudUrl } from "../lib/cloud-client.ts";
import { launchBridge, stopBridge } from "../lib/bridge-launcher.ts";
import { launchClaude } from "../lib/claude-launcher.ts";
import type { BridgeProcess } from "../lib/bridge-launcher.ts";

export async function runRun(extraArgs?: string[]): Promise<void> {
  // Step 1: Must be paired
  if (!isPaired()) {
    process.stdout.write(`\n  ${red("Not paired.")} Run ${dim("`remmy`")} first.\n\n`);
    process.exitCode = 1;
    return;
  }

  // Step 2: Read config
  const config = readConfig()!;
  const spinner = new Spinner();

  // Step 3: Launch bridge
  let bridge: BridgeProcess;
  spinner.start("Starting bridge server...");

  try {
    bridge = await launchBridge({
      pairingId: config.pairingId,
      port: 8787,
      cloudUrl: getCloudUrl(),
    });
    spinner.succeed(`Bridge running on port ${bridge.port}`);
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    spinner.fail(`Bridge failed: ${msg}`);
    process.exitCode = 1;
    return;
  }

  // Step 6: Handle SIGINT — stop bridge cleanly
  const onSigint = async () => {
    process.stdout.write("\n");
    await stopBridge(bridge);
    process.exit(130);
  };
  process.on("SIGINT", onSigint);

  // Step 4: Launch Claude with --sdk-url
  const sdkUrl = `ws://localhost:${bridge.port}/ws/cli/${bridge.pairingId}`;
  process.stdout.write(`  ${dim("Launching Claude with watch approvals...")}\n\n`);

  try {
    const exitCode = await launchClaude({ sdkUrl, extraArgs });

    // Step 5: On exit — stop bridge, exit with same code
    await stopBridge(bridge);
    process.removeListener("SIGINT", onSigint);
    process.exit(exitCode);
  } catch (err) {
    await stopBridge(bridge);
    process.removeListener("SIGINT", onSigint);
    const msg = err instanceof Error ? err.message : "Unknown error";
    process.stdout.write(`\n  ${red("Claude failed:")} ${msg}\n\n`);
    process.exitCode = 1;
  }
}
