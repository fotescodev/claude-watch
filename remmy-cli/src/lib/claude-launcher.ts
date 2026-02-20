/**
 * Claude Launcher — spawns the Claude CLI with CLAUDE_WATCH_SESSION_ACTIVE=1.
 *
 * Zero runtime dependencies: uses node:child_process only.
 *
 * CRITICAL: Claude MUST run in interactive TUI mode. NO extra flags are passed
 * (no --sdk-url, --print, --output-format, --input-format, or -p "").
 * The user gets the normal Claude Code interactive experience.
 * The watch approval hook activates via the CLAUDE_WATCH_SESSION_ACTIVE env var.
 */

import { spawn, execSync } from "node:child_process";

export interface ClaudeOptions {
  extraArgs?: string[]; // User-provided args passed through to Claude
}

/**
 * Find the `claude` binary on the system PATH.
 * Returns the absolute path or null if not found.
 */
export function findClaude(): string | null {
  try {
    const result = execSync("which claude", { encoding: "utf-8" }).trim();
    return result || null;
  } catch {
    return null;
  }
}

/**
 * Launch Claude CLI with the watch session env var set.
 *
 * - Spawns with `stdio: "inherit"` so the user gets the full interactive TUI.
 * - Sets CLAUDE_WATCH_SESSION_ACTIVE=1 to activate the approval hook.
 * - Only passes user-provided extraArgs (no --sdk-url).
 *
 * Returns a Promise that resolves with the exit code when Claude exits.
 * Throws if the `claude` binary cannot be found.
 */
export async function launchClaude(opts?: ClaudeOptions): Promise<number> {
  const claudePath = findClaude();
  if (!claudePath) {
    throw new Error(
      "Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code",
    );
  }

  const args = opts?.extraArgs ?? [];

  return new Promise<number>((resolve, reject) => {
    const child = spawn(claudePath, args, {
      stdio: "inherit",
      env: { ...process.env, CLAUDE_WATCH_SESSION_ACTIVE: "1" },
    });

    child.on("close", (code) => {
      resolve(code ?? 1);
    });

    child.on("error", (err) => {
      reject(err);
    });
  });
}
