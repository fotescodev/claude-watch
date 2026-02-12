/**
 * Config persistence for remmy-watch.
 *
 * Stores pairing configuration at ~/.remmy/config.json.
 * Supports legacy migration from ~/.claude-watch/config.json.
 *
 * Set REMMY_CONFIG_DIR env var to override the config directory (for testing).
 */

import {
  existsSync,
  mkdirSync,
  readFileSync,
  writeFileSync,
  unlinkSync,
  renameSync,
  readdirSync,
  rmdirSync,
  copyFileSync,
} from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import type { RemmyConfig } from "../types.js";

const DEFAULT_CONFIG_DIR_NAME = ".remmy";
const LEGACY_CONFIG_DIR_NAME = ".claude-watch";
const CONFIG_FILE_NAME = "config.json";

/**
 * Get the config directory path.
 * Uses REMMY_CONFIG_DIR env var if set, otherwise ~/.remmy/.
 */
export function getConfigDir(): string {
  const override = process.env["REMMY_CONFIG_DIR"];
  if (override) {
    return override;
  }
  return join(homedir(), DEFAULT_CONFIG_DIR_NAME);
}

/**
 * Get the full path to the config file.
 */
export function getConfigPath(): string {
  return join(getConfigDir(), CONFIG_FILE_NAME);
}

/**
 * Get the legacy config directory path (~/.claude-watch/).
 * Uses REMMY_LEGACY_CONFIG_DIR env var if set (for testing).
 */
function getLegacyConfigDir(): string {
  const override = process.env["REMMY_LEGACY_CONFIG_DIR"];
  if (override) {
    return override;
  }
  return join(homedir(), LEGACY_CONFIG_DIR_NAME);
}

/**
 * Ensure the config directory exists.
 */
function ensureConfigDir(): void {
  const dir = getConfigDir();
  if (!existsSync(dir)) {
    mkdirSync(dir, { recursive: true });
  }
}

/**
 * Read and parse the config file.
 * Returns null if missing or invalid JSON.
 */
export function readConfig(): RemmyConfig | null {
  const configPath = getConfigPath();
  if (!existsSync(configPath)) {
    return null;
  }

  try {
    const content = readFileSync(configPath, "utf-8");
    const parsed: unknown = JSON.parse(content);
    // Basic validation: must be an object with pairingId
    if (
      parsed !== null &&
      typeof parsed === "object" &&
      "pairingId" in parsed &&
      typeof (parsed as RemmyConfig).pairingId === "string"
    ) {
      return parsed as RemmyConfig;
    }
    return null;
  } catch {
    return null;
  }
}

/**
 * Save config to disk with atomic write (.tmp + rename).
 */
export function saveConfig(config: RemmyConfig): void {
  ensureConfigDir();
  const configPath = getConfigPath();
  const tmpPath = `${configPath}.tmp`;

  writeFileSync(tmpPath, JSON.stringify(config, null, 2) + "\n");
  renameSync(tmpPath, configPath);
}

/**
 * Delete the config file. Removes the directory if empty afterward.
 */
export function deleteConfig(): void {
  const configPath = getConfigPath();
  if (existsSync(configPath)) {
    unlinkSync(configPath);
  }

  // Remove dir if empty
  const dir = getConfigDir();
  if (existsSync(dir)) {
    try {
      const entries = readdirSync(dir);
      if (entries.length === 0) {
        rmdirSync(dir);
      }
    } catch {
      // Ignore errors (dir may already be removed, etc.)
    }
  }
}

/**
 * Check if we have a valid pairing (config exists with non-empty pairingId).
 */
export function isPaired(): boolean {
  const config = readConfig();
  return config !== null && config.pairingId.length > 0;
}

/**
 * Create a new config with a placeholder pairingId and current timestamp.
 */
export function createConfig(cloudUrl: string): RemmyConfig {
  return {
    pairingId: crypto.randomUUID(),
    cloudUrl,
    createdAt: new Date().toISOString(),
  };
}

/**
 * Migrate legacy config from ~/.claude-watch/config.json to ~/.remmy/config.json.
 *
 * Copies the file to the new location, then deletes the source.
 * Returns true if migration was performed, false otherwise.
 */
export function migrateLegacyConfig(): boolean {
  const legacyDir = getLegacyConfigDir();
  const legacyPath = join(legacyDir, CONFIG_FILE_NAME);

  if (!existsSync(legacyPath)) {
    return false;
  }

  // Don't overwrite existing config
  const newPath = getConfigPath();
  if (existsSync(newPath)) {
    return false;
  }

  try {
    ensureConfigDir();
    copyFileSync(legacyPath, newPath);
    unlinkSync(legacyPath);

    // Remove legacy dir if empty
    try {
      const entries = readdirSync(legacyDir);
      if (entries.length === 0) {
        rmdirSync(legacyDir);
      }
    } catch {
      // Ignore cleanup errors
    }

    return true;
  } catch {
    return false;
  }
}
