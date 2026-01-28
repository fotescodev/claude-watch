import { existsSync, mkdirSync, readFileSync, writeFileSync, copyFileSync, chmodSync, unlinkSync } from "fs";
import { homedir } from "os";
import { join, dirname } from "path";
import { fileURLToPath } from "url";

const CLAUDE_DIR = join(homedir(), ".claude");
const HOOKS_DIR = join(CLAUDE_DIR, "hooks");
const SETTINGS_PATH = join(CLAUDE_DIR, "settings.json");
const HOOK_FILENAME = "watch-approval-cloud.py";

interface ClaudeSettings {
  hooks?: {
    PreToolUse?: Array<{
      type: string;
      command: string;
    }>;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

/**
 * Get the path to the bundled hook script
 */
function getBundledHookPath(): string {
  // In ESM, we need to resolve relative to the current file
  const currentDir = dirname(fileURLToPath(import.meta.url));
  // Go up from dist/src/config to package root, then into hooks
  return join(currentDir, "..", "..", "..", "hooks", HOOK_FILENAME);
}

/**
 * Get the path where the hook should be installed
 */
export function getInstalledHookPath(): string {
  return join(HOOKS_DIR, HOOK_FILENAME);
}

/**
 * Ensure directories exist
 */
function ensureDirs(): void {
  if (!existsSync(CLAUDE_DIR)) {
    mkdirSync(CLAUDE_DIR, { recursive: true });
  }
  if (!existsSync(HOOKS_DIR)) {
    mkdirSync(HOOKS_DIR, { recursive: true });
  }
}

/**
 * Read Claude settings.json
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
 * Write Claude settings.json
 */
function writeSettings(settings: ClaudeSettings): void {
  ensureDirs();
  writeFileSync(SETTINGS_PATH, JSON.stringify(settings, null, 2) + "\n");
}

/**
 * Install the hook script to ~/.claude/hooks/
 */
export function installHookScript(): boolean {
  ensureDirs();

  const bundledPath = getBundledHookPath();
  const installedPath = getInstalledHookPath();

  if (!existsSync(bundledPath)) {
    // For development, try the local repo path
    const devPath = join(process.cwd(), "hooks", HOOK_FILENAME);
    if (existsSync(devPath)) {
      copyFileSync(devPath, installedPath);
      chmodSync(installedPath, 0o755);
      return true;
    }
    console.error(`Hook script not found at: ${bundledPath}`);
    return false;
  }

  copyFileSync(bundledPath, installedPath);
  chmodSync(installedPath, 0o755);
  return true;
}

/**
 * Register the hook in Claude's settings.json
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

  // Check if already registered
  const existingIndex = settings.hooks.PreToolUse.findIndex(
    (hook) => hook.command?.includes("watch-approval-cloud.py")
  );

  if (existingIndex >= 0) {
    // Update existing entry
    settings.hooks.PreToolUse[existingIndex] = {
      type: "command",
      command: hookPath,
    };
  } else {
    // Add new entry
    settings.hooks.PreToolUse.push({
      type: "command",
      command: hookPath,
    });
  }

  writeSettings(settings);
  return true;
}

/**
 * Unregister the hook from Claude's settings.json
 */
export function unregisterHook(): boolean {
  const settings = readSettings();

  if (!settings.hooks?.PreToolUse) {
    return true;
  }

  settings.hooks.PreToolUse = settings.hooks.PreToolUse.filter(
    (hook) => !hook.command?.includes("watch-approval-cloud.py")
  );

  writeSettings(settings);
  return true;
}

/**
 * Check if the hook is installed and registered
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

  return settings.hooks.PreToolUse.some(
    (hook) => hook.command?.includes("watch-approval-cloud.py")
  );
}

/**
 * Install and register the hook (convenience function)
 */
export function setupHook(): { installed: boolean; registered: boolean } {
  const installed = installHookScript();
  const registered = installed ? registerHook() : false;
  return { installed, registered };
}

/**
 * Remove the hook completely
 */
export function removeHook(): void {
  unregisterHook();
  // Optionally remove the script file too
  const installedPath = getInstalledHookPath();
  if (existsSync(installedPath)) {
    try {
      unlinkSync(installedPath);
    } catch {
      // Ignore removal errors
    }
  }
}
