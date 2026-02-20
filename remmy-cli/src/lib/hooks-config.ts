/**
 * Hook management — installs and registers the watch-approval hook
 * in Claude Code's user-level settings.
 *
 * The hook script lives at ~/.claude/hooks/watch-approval-cloud.py
 * and is registered in ~/.claude/settings.json under hooks.PreToolUse.
 *
 * Session isolation: the hook only activates when CLAUDE_WATCH_SESSION_ACTIVE=1
 * is set in the environment (which `remmy` does automatically).
 */

import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  copyFileSync,
  chmodSync,
  unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, dirname } from "node:path";

const CLAUDE_DIR = join(homedir(), ".claude");
const HOOKS_DIR = join(CLAUDE_DIR, "hooks");
const SETTINGS_PATH = join(CLAUDE_DIR, "settings.json");
const HOOK_FILENAME = "watch-approval-cloud.py";

interface HookEntry {
  type: string;
  command: string;
}

interface HookMatcher {
  matcher: string;
  hooks: HookEntry[];
}

interface ClaudeSettings {
  hooks?: {
    PreToolUse?: HookMatcher[];
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

/**
 * Get the path to the bundled hook script shipped with remmy-cli.
 *
 * Resolves relative to this file's location in the source tree:
 *   src/lib/hooks-config.ts  ->  hooks/watch-approval-cloud.py
 *
 * When built (dist/), the hooks/ dir is included in the package files.
 */
function getBundledHookPath(): string {
  // import.meta.dirname is the directory of this file
  const currentDir =
    typeof import.meta.dirname === "string"
      ? import.meta.dirname
      : dirname(new URL(import.meta.url).pathname);

  // From src/lib/ → ../../hooks/ (package root)
  const srcPath = join(currentDir, "..", "..", "hooks", HOOK_FILENAME);
  if (existsSync(srcPath)) return srcPath;

  // From dist/ → ./hooks/ (copied during build)
  const distPath = join(currentDir, "hooks", HOOK_FILENAME);
  if (existsSync(distPath)) return distPath;

  // Neither found — return srcPath and let caller handle missing file
  return srcPath;
}

/**
 * Get the path where the hook should be installed.
 */
export function getInstalledHookPath(): string {
  return join(HOOKS_DIR, HOOK_FILENAME);
}

/**
 * Ensure ~/.claude/ and ~/.claude/hooks/ directories exist.
 */
function ensureDirs(): void {
  if (!existsSync(HOOKS_DIR)) {
    mkdirSync(HOOKS_DIR, { recursive: true });
  }
}

/**
 * Read Claude's user-level settings.json.
 */
function readSettings(): ClaudeSettings {
  if (!existsSync(SETTINGS_PATH)) {
    return {};
  }

  try {
    const content = readFileSync(SETTINGS_PATH, "utf-8");
    return JSON.parse(content) as ClaudeSettings;
  } catch {
    return {};
  }
}

/**
 * Write Claude's user-level settings.json.
 */
function writeSettings(settings: ClaudeSettings): void {
  ensureDirs();
  writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + "\n");
}

/**
 * Install the hook script to ~/.claude/hooks/.
 * Copies from the bundled location and sets executable permissions.
 */
export function installHookScript(): boolean {
  ensureDirs();

  const bundledPath = getBundledHookPath();
  const installedPath = getInstalledHookPath();

  if (!existsSync(bundledPath)) {
    // Fallback: try CWD-relative path (for development)
    const devPath = join(process.cwd(), "hooks", HOOK_FILENAME);
    if (existsSync(devPath)) {
      copyFileSync(devPath, installedPath);
      chmodSync(installedPath, 0o755);
      return true;
    }
    return false;
  }

  copyFileSync(bundledPath, installedPath);
  chmodSync(installedPath, 0o755);
  return true;
}

/**
 * Register the hook in Claude's user-level settings.json.
 *
 * Adds an entry to hooks.PreToolUse with matcher: "" (all tools).
 * Idempotent: finds existing entry by command path and updates it.
 */
export function registerHook(): boolean {
  const settings = readSettings();
  const hookPath = getInstalledHookPath();

  // Ensure hooks object exists
  if (!settings.hooks) {
    settings.hooks = {};
  }

  // Ensure PreToolUse array exists
  if (!settings.hooks.PreToolUse) {
    settings.hooks.PreToolUse = [];
  }

  // Check if already registered (look inside hooks array for our script)
  const existingIndex = settings.hooks.PreToolUse.findIndex((entry) =>
    entry.hooks?.some((h) => h.command?.includes("watch-approval-cloud.py")),
  );

  const hookEntry: HookMatcher = {
    matcher: "", // Empty string matches ALL tools
    hooks: [
      {
        type: "command",
        command: hookPath,
      },
    ],
  };

  if (existingIndex >= 0) {
    // Update existing entry
    settings.hooks.PreToolUse[existingIndex] = hookEntry;
  } else {
    // Add new entry
    settings.hooks.PreToolUse.push(hookEntry);
  }

  writeSettings(settings);
  return true;
}

/**
 * Unregister the hook from Claude's settings.json.
 */
export function unregisterHook(): boolean {
  const settings = readSettings();

  if (!settings.hooks?.PreToolUse) {
    return true;
  }

  settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(
    (entry) =>
      !entry.hooks?.some((h) =>
        h.command?.includes("watch-approval-cloud.py"),
      ),
  );

  writeSettings(settings);
  return true;
}

/**
 * Check if the hook is installed and registered.
 */
export function isHookConfigured(): boolean {
  const installedPath = getInstalledHookPath();

  // Check if script exists
  if (!existsSync(installedPath)) {
    return false;
  }

  // Check if registered in settings
  const settings = readSettings();
  if (!settings.hooks?.PreToolUse) {
    return false;
  }

  return settings.hooks.PreToolUse.some((entry) =>
    entry.hooks?.some((h) => h.command?.includes("watch-approval-cloud.py")),
  );
}

/**
 * Install and register the hook (convenience function).
 */
export function setupHook(): { installed: boolean; registered: boolean } {
  const installed = installHookScript();
  const registered = installed ? registerHook() : false;
  return { installed, registered };
}

/**
 * Remove the hook completely (unregister + delete script file).
 */
export function removeHook(): void {
  unregisterHook();
  const installedPath = getInstalledHookPath();
  if (existsSync(installedPath)) {
    try {
      unlinkSync(installedPath);
    } catch {
      // Ignore removal errors
    }
  }
}
