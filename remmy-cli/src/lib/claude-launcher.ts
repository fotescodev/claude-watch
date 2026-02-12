/**
 * Claude Launcher — spawns the Claude CLI with --sdk-url for bridge control.
 *
 * Zero runtime dependencies: uses node:child_process only.
 *
 * CRITICAL: Claude MUST run in interactive TUI mode. The --sdk-url flag is the
 * ONLY extra flag passed. DO NOT add --print, --output-format, --input-format,
 * or -p "" flags. The user gets the normal Claude Code interactive experience.
 */

import { spawn, execSync } from "node:child_process";

export interface ClaudeOptions {
  sdkUrl: string; // ws://localhost:{port}/ws/cli/{sessionId}
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
 * Launch Claude CLI with --sdk-url pointing to the bridge WebSocket.
 *
 * - Spawns with `stdio: "inherit"` so the user gets the full interactive TUI.
 * - Does NOT set CLAUDE_WATCH_SESSION_ACTIVE or any other custom env vars.
 * - Only passes --sdk-url and any user-provided extraArgs.
 *
 * Returns a Promise that resolves with the exit code when Claude exits.
 * Throws if the `claude` binary cannot be found.
 */
export async function launchClaude(opts: ClaudeOptions): Promise<number> {
  const claudePath = findClaude();
  if (!claudePath) {
    throw new Error(
      "Claude CLI not found. Install: npm install -g @anthropic-ai/claude-code",
    );
  }

  const args = ["--sdk-url", opts.sdkUrl];

  if (opts.extraArgs) {
    args.push(...opts.extraArgs);
  }

  return new Promise<number>((resolve, reject) => {
    const child = spawn(claudePath, args, {
      stdio: "inherit",
      env: process.env,
    });

    child.on("close", (code) => {
      resolve(code ?? 1);
    });

    child.on("error", (err) => {
      reject(err);
    });
  });
}
