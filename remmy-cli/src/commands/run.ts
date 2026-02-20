/**
 * Run command — launch Claude with watch approvals. Must be paired.
 *
 * Flow:
 * 1. Check isPaired(). If not, error: "Not paired. Run `remmy` first."
 * 2. Ensure hook is installed
 * 3. Launch Claude with CLAUDE_WATCH_SESSION_ACTIVE=1 and extraArgs
 * 4. Exit with Claude's exit code
 */

import { dim, red, yellow } from "../ui/colors.ts";
import { readConfig, isPaired } from "../lib/config.ts";
import { setupHook } from "../lib/hooks-config.ts";
import { launchClaude } from "../lib/claude-launcher.ts";

export async function runRun(extraArgs?: string[]): Promise<void> {
  // Step 1: Must be paired
  if (!isPaired()) {
    process.stdout.write(`\n  ${red("Not paired.")} Run ${dim("`remmy`")} first.\n\n`);
    process.exitCode = 1;
    return;
  }

  // Step 2: Ensure hook is installed
  const hookResult = setupHook();
  if (!hookResult.installed) {
    process.stdout.write(`  ${yellow("Warning:")} Could not install hook script.\n`);
  }

  // Step 3: Launch Claude
  process.stdout.write(`  ${dim("Launching Claude with watch approvals...")}\n\n`);

  try {
    const exitCode = await launchClaude({ extraArgs });
    process.exit(exitCode);
  } catch (err) {
    const msg = err instanceof Error ? err.message : "Unknown error";
    process.stdout.write(`\n  ${red("Claude failed:")} ${msg}\n\n`);
    process.exitCode = 1;
  }
}
