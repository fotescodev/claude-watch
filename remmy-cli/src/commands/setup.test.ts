/**
 * Tests for the setup command.
 *
 * Mocks ALL dependencies: config, cloud-client, prompt, spinner, header, colors.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { RemmyConfig } from "../types.ts";
import type { ConnectivityResult } from "../lib/cloud-client.ts";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

let mockIsPaired = false;
let mockConfig: RemmyConfig | null = null;
let mockConnectivity: ConnectivityResult = { connected: true, latency: 42 };
let mockCompletePairingResult: string | Error = "pairing-id-from-server";
let mockAskTextResult: string | null = "123456";
let mockAskConfirmResult: boolean | null = true;

// Track calls for assertions
const calls = {
  showHeader: [] as unknown[][],
  isPaired: [] as unknown[][],
  readConfig: [] as unknown[][],
  saveConfig: [] as unknown[][],
  checkConnectivity: [] as unknown[][],
  completePairing: [] as unknown[][],
  getCloudUrl: [] as unknown[][],
  askText: [] as unknown[][],
  askConfirm: [] as unknown[][],
  launchBridge: [] as unknown[][],
  spinnerStart: [] as string[],
  spinnerSucceed: [] as string[],
  spinnerFail: [] as string[],
};

// Capture stdout writes
let stdoutWrites: string[] = [];
const originalStdoutWrite = process.stdout.write;

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

mock.module("../ui/header.ts", () => ({
  showHeader: (...args: unknown[]) => {
    calls.showHeader.push(args);
  },
}));

mock.module("../ui/colors.ts", () => ({
  red: (s: string) => `[red:${s}]`,
  green: (s: string) => `[green:${s}]`,
  yellow: (s: string) => `[yellow:${s}]`,
  cyan: (s: string) => `[cyan:${s}]`,
  dim: (s: string) => `[dim:${s}]`,
  bold: (s: string) => `[bold:${s}]`,
  white: (s: string) => `[white:${s}]`,
}));

mock.module("../ui/spinner.ts", () => ({
  Spinner: class {
    start(msg: string) {
      calls.spinnerStart.push(msg);
    }
    succeed(msg: string) {
      calls.spinnerSucceed.push(msg);
    }
    fail(msg: string) {
      calls.spinnerFail.push(msg);
    }
    stop() {}
  },
}));

mock.module("../ui/prompt.ts", () => ({
  askText: (question: string, validate?: (input: string) => true | string) => {
    calls.askText.push([question, validate]);
    return Promise.resolve(mockAskTextResult);
  },
  askConfirm: (question: string, defaultVal?: boolean) => {
    calls.askConfirm.push([question, defaultVal]);
    return Promise.resolve(mockAskConfirmResult);
  },
}));

mock.module("../lib/config.ts", () => ({
  readConfig: () => {
    calls.readConfig.push([]);
    return mockConfig;
  },
  saveConfig: (config: RemmyConfig) => {
    calls.saveConfig.push([config]);
  },
  isPaired: () => {
    calls.isPaired.push([]);
    return mockIsPaired;
  },
  createConfig: (cloudUrl: string) => ({
    pairingId: "placeholder-uuid",
    cloudUrl,
    createdAt: "2026-01-01T00:00:00.000Z",
  }),
  migrateLegacyConfig: () => false,
  getConfigPath: () => "/home/test/.remmy/config.json",
  getConfigDir: () => "/home/test/.remmy",
  deleteConfig: () => {},
}));

mock.module("../lib/cloud-client.ts", () => ({
  DEFAULT_CLOUD_URL: "https://remmy.watch",
  getCloudUrl: () => {
    calls.getCloudUrl.push([]);
    return "https://remmy.watch";
  },
  checkConnectivity: (url?: string) => {
    calls.checkConnectivity.push([url]);
    return Promise.resolve(mockConnectivity);
  },
  completePairing: (code: string, url?: string) => {
    calls.completePairing.push([code, url]);
    if (mockCompletePairingResult instanceof Error) {
      return Promise.reject(mockCompletePairingResult);
    }
    return Promise.resolve(mockCompletePairingResult);
  },
}));

mock.module("../lib/bridge-launcher.ts", () => ({
  launchBridge: (opts: unknown) => {
    calls.launchBridge.push([opts]);
    return Promise.resolve({
      process: {},
      port: 8787,
      httpPort: 8788,
      pairingId: "test-pairing-id",
    });
  },
  stopBridge: () => Promise.resolve(),
}));

mock.module("../lib/claude-launcher.ts", () => ({
  launchClaude: () => Promise.resolve(0),
}));

// Import AFTER all mocks
const { runSetup } = await import("./setup.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("setup command", () => {
  beforeEach(() => {
    // Reset mock state
    mockIsPaired = false;
    mockConfig = null;
    mockConnectivity = { connected: true, latency: 42 };
    mockCompletePairingResult = "pairing-id-from-server";
    mockAskTextResult = "123456";
    mockAskConfirmResult = true;

    // Reset call trackers
    for (const key of Object.keys(calls) as (keyof typeof calls)[]) {
      calls[key] = [];
    }

    // Capture stdout
    stdoutWrites = [];
    process.stdout.write = ((chunk: unknown) => {
      if (typeof chunk === "string") {
        stdoutWrites.push(chunk);
      }
      return true;
    }) as typeof process.stdout.write;

    process.exitCode = undefined;
  });

  // R8.T1: runs pairing, saves config, does not call launchBridge
  test("R8.T1: runs pairing, saves config, does not call launchBridge", async () => {
    mockIsPaired = false;
    mockAskTextResult = "654321";
    mockCompletePairingResult = "new-pair-id-abc";

    await runSetup();

    // Should show header
    expect(calls.showHeader).toHaveLength(1);

    // Should check connectivity
    expect(calls.checkConnectivity).toHaveLength(1);

    // Should prompt for code
    expect(calls.askText).toHaveLength(1);

    // Should call completePairing with the entered code
    expect(calls.completePairing).toHaveLength(1);
    expect(calls.completePairing[0]![0]).toBe("654321");

    // Should save config with the returned pairingId
    expect(calls.saveConfig).toHaveLength(1);
    const savedConfig = (calls.saveConfig[0] as [RemmyConfig])[0];
    expect(savedConfig.pairingId).toBe("new-pair-id-abc");
    expect(savedConfig.cloudUrl).toBe("https://remmy.watch");
    expect(savedConfig.createdAt).toBeTruthy();

    // Should NOT call launchBridge — setup only, no launch
    expect(calls.launchBridge).toHaveLength(0);

    // Should show next steps message
    const nextSteps = stdoutWrites.find((w) => w.includes("remmy run"));
    expect(nextSteps).toBeDefined();

    // Spinner should succeed
    expect(calls.spinnerSucceed.length).toBeGreaterThanOrEqual(1);
    expect(calls.spinnerSucceed.some((m) => m.includes("Paired"))).toBe(true);
  });

  // R8.T2: offers reconfigure when already paired
  test("R8.T2: offers reconfigure when already paired, user declines", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "existing-pair-id-12345678",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-15T00:00:00.000Z",
    };
    mockAskConfirmResult = false; // User declines reconfigure

    await runSetup();

    // Should show header
    expect(calls.showHeader).toHaveLength(1);

    // Should show current pairing ID (truncated)
    const idOutput = stdoutWrites.find((w) => w.includes("Already paired"));
    expect(idOutput).toBeDefined();
    const truncated = stdoutWrites.find((w) => w.includes("existing."));
    expect(truncated).toBeDefined();

    // Should ask to reconfigure
    expect(calls.askConfirm).toHaveLength(1);
    expect((calls.askConfirm[0]![0] as string)).toContain("Reconfigure");

    // Should NOT proceed with pairing (user declined)
    expect(calls.checkConnectivity).toHaveLength(0);
    expect(calls.askText).toHaveLength(0);
    expect(calls.completePairing).toHaveLength(0);
    expect(calls.saveConfig).toHaveLength(0);
  });

  test("R8.T2b: proceeds with reconfigure when user confirms", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "old-pair-id-12345678",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-15T00:00:00.000Z",
    };
    mockAskConfirmResult = true; // User confirms reconfigure
    mockAskTextResult = "999888";
    mockCompletePairingResult = "reconfigured-pair-id";

    await runSetup();

    // Should proceed through full pairing flow
    expect(calls.checkConnectivity).toHaveLength(1);
    expect(calls.askText).toHaveLength(1);
    expect(calls.completePairing).toHaveLength(1);
    expect(calls.saveConfig).toHaveLength(1);

    const savedConfig = (calls.saveConfig[0] as [RemmyConfig])[0];
    expect(savedConfig.pairingId).toBe("reconfigured-pair-id");
  });
});
