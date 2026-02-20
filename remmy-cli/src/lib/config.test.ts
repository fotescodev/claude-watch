import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { mkdtempSync, existsSync, mkdirSync, writeFileSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { tmpdir } from "node:os";
import {
  readConfig,
  saveConfig,
  deleteConfig,
  isPaired,
  createConfig,
  getConfigPath,
  getConfigDir,
  migrateLegacyConfig,
} from "./config.js";
import type { RemmyConfig } from "../types.js";

let tempDir: string;
let legacyDir: string;

beforeEach(() => {
  tempDir = mkdtempSync(join(tmpdir(), "remmy-test-"));
  legacyDir = mkdtempSync(join(tmpdir(), "remmy-legacy-test-"));
  process.env["REMMY_CONFIG_DIR"] = tempDir;
  process.env["REMMY_LEGACY_CONFIG_DIR"] = legacyDir;
});

afterEach(() => {
  delete process.env["REMMY_CONFIG_DIR"];
  delete process.env["REMMY_LEGACY_CONFIG_DIR"];
});

describe("config", () => {
  // R3.T1: save/read roundtrip preserves all fields
  test("R3.T1: save/read roundtrip preserves all fields", () => {
    const config: RemmyConfig = {
      pairingId: "test-pairing-id-123",
      cloudUrl: "https://example.com/api",
      createdAt: "2026-02-12T10:00:00.000Z",
      watchId: "watch-abc-456",
    };

    saveConfig(config);
    const loaded = readConfig();

    expect(loaded).not.toBeNull();
    expect(loaded!.pairingId).toBe(config.pairingId);
    expect(loaded!.cloudUrl).toBe(config.cloudUrl);
    expect(loaded!.createdAt).toBe(config.createdAt);
    expect(loaded!.watchId).toBe(config.watchId);
  });

  test("R3.T1b: roundtrip preserves config without optional watchId", () => {
    const config: RemmyConfig = {
      pairingId: "id-no-watch",
      cloudUrl: "https://example.com",
      createdAt: "2026-01-01T00:00:00.000Z",
    };

    saveConfig(config);
    const loaded = readConfig();

    expect(loaded).not.toBeNull();
    expect(loaded!.pairingId).toBe("id-no-watch");
    expect(loaded!.watchId).toBeUndefined();
  });

  // R3.T2: isPaired() true when config has pairingId
  test("R3.T2: isPaired() returns true when config has pairingId", () => {
    const config: RemmyConfig = {
      pairingId: "valid-id",
      cloudUrl: "https://example.com",
      createdAt: new Date().toISOString(),
    };

    saveConfig(config);
    expect(isPaired()).toBe(true);
  });

  test("R3.T2b: isPaired() returns false when pairingId is empty string", () => {
    const config: RemmyConfig = {
      pairingId: "",
      cloudUrl: "https://example.com",
      createdAt: new Date().toISOString(),
    };

    saveConfig(config);
    expect(isPaired()).toBe(false);
  });

  // R3.T3: isPaired() false when no config
  test("R3.T3: isPaired() returns false when no config exists", () => {
    expect(isPaired()).toBe(false);
  });

  // R3.T4: deleteConfig() removes file
  test("R3.T4: deleteConfig() removes file and empty directory", () => {
    const config: RemmyConfig = {
      pairingId: "to-delete",
      cloudUrl: "https://example.com",
      createdAt: new Date().toISOString(),
    };

    saveConfig(config);
    expect(existsSync(getConfigPath())).toBe(true);

    deleteConfig();
    expect(existsSync(getConfigPath())).toBe(false);
    // Directory should also be removed since it's empty
    expect(existsSync(tempDir)).toBe(false);
  });

  test("R3.T4b: deleteConfig() is safe when no config exists", () => {
    // Should not throw
    deleteConfig();
    expect(isPaired()).toBe(false);
  });

  // R3.T5: createConfig() returns valid structure with createdAt as ISO string
  test("R3.T5: createConfig() returns valid structure", () => {
    const before = new Date().toISOString();
    const config = createConfig("https://my-cloud.example.com");
    const after = new Date().toISOString();

    expect(config.pairingId).toBeTruthy();
    expect(config.pairingId.length).toBeGreaterThan(0);
    expect(config.cloudUrl).toBe("https://my-cloud.example.com");

    // createdAt should be a valid ISO 8601 string
    const parsed = new Date(config.createdAt);
    expect(parsed.toISOString()).toBe(config.createdAt);

    // Should be between before and after timestamps
    expect(config.createdAt >= before).toBe(true);
    expect(config.createdAt <= after).toBe(true);
  });

  test("R3.T5b: createConfig() generates unique pairingIds", () => {
    const a = createConfig("https://example.com");
    const b = createConfig("https://example.com");
    expect(a.pairingId).not.toBe(b.pairingId);
  });

  // R3.T6: atomic write (verify .tmp file is used)
  test("R3.T6: atomic write uses .tmp file", () => {
    const config: RemmyConfig = {
      pairingId: "atomic-test",
      cloudUrl: "https://example.com",
      createdAt: new Date().toISOString(),
    };

    // After save completes, the .tmp file should NOT exist (it was renamed)
    saveConfig(config);
    const tmpPath = `${getConfigPath()}.tmp`;
    expect(existsSync(tmpPath)).toBe(false);

    // But the final config file should exist with correct content
    expect(existsSync(getConfigPath())).toBe(true);
    const raw = readFileSync(getConfigPath(), "utf-8");
    const parsed = JSON.parse(raw) as RemmyConfig;
    expect(parsed.pairingId).toBe("atomic-test");
  });

  // R3.T7: legacy migration moves file from old dir to new dir
  test("R3.T7: migrateLegacyConfig() moves file from old dir to new dir", () => {
    // Set up a new (empty) config dir so migration isn't blocked
    const newDir = mkdtempSync(join(tmpdir(), "remmy-migrate-new-"));
    process.env["REMMY_CONFIG_DIR"] = newDir;

    // Write a legacy config
    const legacyConfig: RemmyConfig = {
      pairingId: "legacy-id",
      cloudUrl: "https://legacy.example.com",
      createdAt: "2025-12-01T00:00:00.000Z",
    };
    const legacyPath = join(legacyDir, "config.json");
    writeFileSync(legacyPath, JSON.stringify(legacyConfig, null, 2) + "\n");

    expect(existsSync(legacyPath)).toBe(true);

    const migrated = migrateLegacyConfig();
    expect(migrated).toBe(true);

    // Source should be deleted
    expect(existsSync(legacyPath)).toBe(false);

    // New config should exist with same content
    const loaded = readConfig();
    expect(loaded).not.toBeNull();
    expect(loaded!.pairingId).toBe("legacy-id");
    expect(loaded!.cloudUrl).toBe("https://legacy.example.com");
  });

  test("R3.T7b: migrateLegacyConfig() returns false when no legacy config", () => {
    const result = migrateLegacyConfig();
    expect(result).toBe(false);
  });

  test("R3.T7c: migrateLegacyConfig() does not overwrite existing config", () => {
    // Save a current config
    const current: RemmyConfig = {
      pairingId: "current-id",
      cloudUrl: "https://current.example.com",
      createdAt: new Date().toISOString(),
    };
    saveConfig(current);

    // Write a legacy config
    const legacyConfig: RemmyConfig = {
      pairingId: "legacy-id",
      cloudUrl: "https://legacy.example.com",
      createdAt: "2025-01-01T00:00:00.000Z",
    };
    writeFileSync(
      join(legacyDir, "config.json"),
      JSON.stringify(legacyConfig, null, 2) + "\n"
    );

    const migrated = migrateLegacyConfig();
    expect(migrated).toBe(false);

    // Current config should be untouched
    const loaded = readConfig();
    expect(loaded!.pairingId).toBe("current-id");
  });

  // R3.T8: getConfigPath() returns correct path
  test("R3.T8: getConfigPath() returns correct path", () => {
    const path = getConfigPath();
    expect(path).toBe(join(tempDir, "config.json"));
  });

  test("R3.T8b: getConfigDir() returns correct directory", () => {
    const dir = getConfigDir();
    expect(dir).toBe(tempDir);
  });

  // Edge cases
  test("readConfig() returns null for invalid JSON", () => {
    mkdirSync(tempDir, { recursive: true });
    writeFileSync(join(tempDir, "config.json"), "not valid json {{{");
    expect(readConfig()).toBeNull();
  });

  test("readConfig() returns null for JSON missing pairingId", () => {
    mkdirSync(tempDir, { recursive: true });
    writeFileSync(
      join(tempDir, "config.json"),
      JSON.stringify({ cloudUrl: "https://example.com" })
    );
    expect(readConfig()).toBeNull();
  });

  test("readConfig() returns null for non-string pairingId", () => {
    mkdirSync(tempDir, { recursive: true });
    writeFileSync(
      join(tempDir, "config.json"),
      JSON.stringify({ pairingId: 123, cloudUrl: "https://example.com" })
    );
    expect(readConfig()).toBeNull();
  });
});
