/**
 * Unpair command — remove config and legacy cc-watch artifacts.
 *
 * Flow:
 * 1. If not paired: show "Not paired. Nothing to remove."
 * 2. Show what will be deleted
 * 3. Confirm with askConfirm
 * 4. Delete config via deleteConfig()
 * 5. Check/remove legacy files
 * 6. Show "Run `remmy` to set up again."
 */

import { askConfirm } from "../ui/prompt.ts";
import { green, red, dim, yellow } from "../ui/colors.ts";
import {
  isPaired,
  deleteConfig,
  getConfigPath,
} from "../lib/config.ts";
import { existsSync, readFileSync, writeFileSync, unlinkSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

/** Legacy hook script path. */
function legacyHookPath(): string {
  return join(homedir(), ".claude", "hooks", "watch-approval-cloud.py");
}

/** Legacy settings.json path. */
function legacySettingsPath(): string {
  return join(homedir(), ".claude", "settings.json");
}

/** Legacy .mcp.json path. */
function legacyMcpPath(): string {
  return join(homedir(), ".claude", ".mcp.json");
}

/**
 * Check if any legacy cc-watch artifacts exist.
 * Returns a list of descriptions for display.
 */
function findLegacyArtifacts(): string[] {
  const found: string[] = [];

  if (existsSync(legacyHookPath())) {
    found.push(legacyHookPath());
  }

  try {
    const raw = readFileSync(legacySettingsPath(), "utf-8");
    const settings: unknown = JSON.parse(raw);
    if (
      settings &&
      typeof settings === "object" &&
      "hooks" in settings
    ) {
      const hooks = (settings as Record<string, unknown>)["hooks"];
      if (hooks && typeof hooks === "object" && "PreToolUse" in hooks) {
        const entries = (hooks as Record<string, unknown>)["PreToolUse"];
        if (Array.isArray(entries)) {
          const hasWatchHook = entries.some(
            (e: unknown) =>
              typeof e === "object" &&
              e !== null &&
              "command" in e &&
              typeof (e as Record<string, unknown>)["command"] === "string" &&
              ((e as Record<string, string>)["command"]).includes(
                "watch-approval",
              ),
          );
          if (hasWatchHook) {
            found.push(`${legacySettingsPath()} (PreToolUse hook)`);
          }
        }
      }
    }
  } catch {
    // settings.json missing or unparsable — no artifact
  }

  try {
    const raw = readFileSync(legacyMcpPath(), "utf-8");
    const mcp: unknown = JSON.parse(raw);
    if (
      mcp &&
      typeof mcp === "object" &&
      "mcpServers" in mcp
    ) {
      const servers = (mcp as Record<string, unknown>)["mcpServers"];
      if (servers && typeof servers === "object" && "claude-watch" in servers) {
        found.push(`${legacyMcpPath()} (claude-watch server)`);
      }
    }
  } catch {
    // .mcp.json missing or unparsable — no artifact
  }

  return found;
}

/** Remove legacy cc-watch artifacts. */
function removeLegacyArtifacts(): void {
  // Remove hook script
  if (existsSync(legacyHookPath())) {
    try {
      unlinkSync(legacyHookPath());
    } catch {
      // ignore
    }
  }

  // Clean settings.json — remove PreToolUse entries containing "watch-approval"
  try {
    const raw = readFileSync(legacySettingsPath(), "utf-8");
    const settings = JSON.parse(raw) as Record<string, unknown>;
    if (settings["hooks"] && typeof settings["hooks"] === "object") {
      const hooks = settings["hooks"] as Record<string, unknown>;
      if (Array.isArray(hooks["PreToolUse"])) {
        hooks["PreToolUse"] = (hooks["PreToolUse"] as Array<Record<string, unknown>>).filter(
          (entry) => {
            const cmd = entry["command"];
            return !(typeof cmd === "string" && cmd.includes("watch-approval"));
          },
        );
        writeFileSync(legacySettingsPath(), JSON.stringify(settings, null, 2) + "\n");
      }
    }
  } catch {
    // ignore
  }

  // Clean .mcp.json — remove "claude-watch" server entry
  try {
    const raw = readFileSync(legacyMcpPath(), "utf-8");
    const mcp = JSON.parse(raw) as Record<string, unknown>;
    if (mcp["mcpServers"] && typeof mcp["mcpServers"] === "object") {
      const servers = mcp["mcpServers"] as Record<string, unknown>;
      if ("claude-watch" in servers) {
        delete servers["claude-watch"];
        writeFileSync(legacyMcpPath(), JSON.stringify(mcp, null, 2) + "\n");
      }
    }
  } catch {
    // ignore
  }
}

export async function runUnpair(): Promise<void> {
  // Step 1: If not paired
  if (!isPaired()) {
    process.stdout.write(`\n  ${yellow("Not paired.")} Nothing to remove.\n\n`);
    return;
  }

  // Step 2: Show what will be deleted
  process.stdout.write("\n  The following will be removed:\n\n");
  process.stdout.write(`    ${dim(getConfigPath())}\n`);

  const legacyArtifacts = findLegacyArtifacts();
  for (const artifact of legacyArtifacts) {
    process.stdout.write(`    ${dim(artifact)} ${yellow("(legacy)")}\n`);
  }

  process.stdout.write("\n");

  // Step 3: Confirm
  const confirmed = await askConfirm("  Remove configuration?", false);
  if (!confirmed) {
    process.stdout.write("\n  Cancelled.\n\n");
    return;
  }

  // Step 4: Delete config
  deleteConfig();
  process.stdout.write(`\n  ${green("Configuration removed.")}\n`);

  // Step 5: Remove legacy artifacts
  if (legacyArtifacts.length > 0) {
    removeLegacyArtifacts();
    process.stdout.write(`  ${green("Legacy artifacts cleaned up.")}\n`);
  }

  // Step 6: Next steps
  process.stdout.write(`\n  Run ${dim("`remmy`")} to set up again.\n\n`);
}
