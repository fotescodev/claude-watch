import { existsSync, mkdirSync, readFileSync, writeFileSync, unlinkSync } from "fs";
import { homedir } from "os";
import { join } from "path";
import type { PairingConfig } from "../types/index.js";
import { generateKeyPair, serializeKeyPair } from "../crypto/encryption.js";

const CONFIG_DIR = join(homedir(), ".claude-watch");
const CONFIG_PATH = join(CONFIG_DIR, "config.json");
// Legacy pairing file for hooks
const LEGACY_PAIRING_PATH = join(homedir(), ".claude-watch-pairing");

// Default cloud URL - Cloudflare Worker
const DEFAULT_CLOUD_URL = "https://claude-watch.fotescodev.workers.dev";

/**
 * Ensure the ~/.claude-watch directory exists
 */
function ensureConfigDir(): void {
  if (!existsSync(CONFIG_DIR)) {
    mkdirSync(CONFIG_DIR, { recursive: true });
  }
}

/**
 * Read the pairing configuration
 */
export function readPairingConfig(): PairingConfig | null {
  if (!existsSync(CONFIG_PATH)) {
    return null;
  }

  try {
    const content = readFileSync(CONFIG_PATH, "utf-8");
    return JSON.parse(content);
  } catch (error) {
    return null;
  }
}

/**
 * Save the pairing configuration
 */
export function savePairingConfig(config: PairingConfig): void {
  ensureConfigDir();
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2) + "\n");

  // Also write to legacy file for hooks compatibility
  if (config.pairingId) {
    writeFileSync(LEGACY_PAIRING_PATH, config.pairingId + "\n");
  }
}

/**
 * Delete the pairing configuration
 */
export function deletePairingConfig(): boolean {
  if (existsSync(CONFIG_PATH)) {
    unlinkSync(CONFIG_PATH);
    return true;
  }
  return false;
}

/**
 * Check if we have a valid pairing
 */
export function isPaired(): boolean {
  const config = readPairingConfig();
  return config !== null && !!config.pairingId;
}

/**
 * Get the cloud URL from config or default
 */
export function getCloudUrl(): string {
  const config = readPairingConfig();
  return config?.cloudUrl || DEFAULT_CLOUD_URL;
}

/**
 * Get the pairing ID
 */
export function getPairingId(): string | null {
  const config = readPairingConfig();
  return config?.pairingId || null;
}

/**
 * Get the config directory path
 */
export function getConfigDir(): string {
  return CONFIG_DIR;
}

/**
 * Get the config file path
 */
export function getConfigPath(): string {
  return CONFIG_PATH;
}

/**
 * Create a new pairing config with generated ID and encryption keys
 */
export function createPairingConfig(cloudUrl?: string): PairingConfig {
  // Generate E2E encryption keypair
  const keyPair = generateKeyPair();
  const serializedKeys = serializeKeyPair(keyPair);

  return {
    pairingId: crypto.randomUUID(),
    cloudUrl: cloudUrl || DEFAULT_CLOUD_URL,
    createdAt: new Date().toISOString(),
    encryption: {
      publicKey: serializedKeys.publicKey,
      secretKey: serializedKeys.secretKey,
      // watchPublicKey will be set when watch completes pairing
    },
  };
}

/**
 * Get our encryption public key (to send to watch)
 */
export function getPublicKey(): string | null {
  const config = readPairingConfig();
  return config?.encryption?.publicKey || null;
}

/**
 * Get our encryption secret key (for decryption)
 */
export function getSecretKey(): string | null {
  const config = readPairingConfig();
  return config?.encryption?.secretKey || null;
}

/**
 * Get watch's public key (for encryption)
 */
export function getWatchPublicKey(): string | null {
  const config = readPairingConfig();
  return config?.encryption?.watchPublicKey || null;
}

/**
 * Store watch's public key after pairing
 */
export function setWatchPublicKey(watchPublicKey: string): void {
  const config = readPairingConfig();
  if (!config) {
    throw new Error("No pairing config found");
  }

  if (!config.encryption) {
    config.encryption = {
      publicKey: "",
      secretKey: "",
    };
  }

  config.encryption.watchPublicKey = watchPublicKey;
  savePairingConfig(config);
}

/**
 * Check if E2E encryption is available (both keys present)
 */
export function isEncryptionReady(): boolean {
  const config = readPairingConfig();
  return !!(
    config?.encryption?.publicKey &&
    config?.encryption?.secretKey &&
    config?.encryption?.watchPublicKey
  );
}
