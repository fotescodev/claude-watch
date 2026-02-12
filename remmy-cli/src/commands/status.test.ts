/**
 * Tests for the status command.
 *
 * Mocks ALL dependencies: config, cloud-client, spinner, header, colors.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { RemmyConfig } from "../types.ts";
import type { ConnectivityResult } from "../lib/cloud-client.ts";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

let mockIsPaired = false;
let mockConfig: RemmyConfig | null = null;
let mockConnectivity: ConnectivityResult = { connected: true, latency: 35 };

// Track calls
const calls = {
  showHeader: [] as unknown[][],
  isPaired: [] as unknown[][],
  readConfig: [] as unknown[][],
  checkConnectivity: [] as unknown[][],
  getCloudUrl: [] as unknown[][],
  getConfigPath: [] as unknown[][],
  spinnerStart: [] as string[],
  spinnerSucceed: [] as string[],
  spinnerFail: [] as string[],
};

// Capture stdout
let stdoutWrites: string[] = [];

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
  askText: () => Promise.resolve(null),
  askConfirm: () => Promise.resolve(false),
}));

mock.module("../lib/config.ts", () => ({
  readConfig: () => {
    calls.readConfig.push([]);
    return mockConfig;
  },
  isPaired: () => {
    calls.isPaired.push([]);
    return mockIsPaired;
  },
  getConfigPath: () => {
    calls.getConfigPath.push([]);
    return "/home/test/.remmy/config.json";
  },
  createConfig: (cloudUrl: string) => ({
    pairingId: "placeholder-uuid",
    cloudUrl,
    createdAt: "2026-01-01T00:00:00.000Z",
  }),
  migrateLegacyConfig: () => false,
  getConfigDir: () => "/home/test/.remmy",
  saveConfig: () => {},
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
  completePairing: () => Promise.resolve("pair-id"),
}));

mock.module("../lib/bridge-launcher.ts", () => ({
  launchBridge: () => Promise.resolve({ process: {}, port: 8787, httpPort: 8788, pairingId: "x" }),
  stopBridge: () => Promise.resolve(),
}));

mock.module("../lib/claude-launcher.ts", () => ({
  launchClaude: () => Promise.resolve(0),
}));

// Import AFTER all mocks
const { runStatus } = await import("./status.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("status command", () => {
  beforeEach(() => {
    // Reset mock state
    mockIsPaired = false;
    mockConfig = null;
    mockConnectivity = { connected: true, latency: 35 };

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
  });

  // R8.T6: shows pairing info when configured
  test("R8.T6: shows pairing info when configured", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "abcd1234-5678-90ef-ghij-klmnopqrstuv",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-02-10T14:30:00.000Z",
      watchId: "watch-xyz-789",
    };

    await runStatus();

    // Should show header
    expect(calls.showHeader).toHaveLength(1);

    // Should show "Paired" status
    const pairedMsg = stdoutWrites.find((w) => w.includes("Paired"));
    expect(pairedMsg).toBeDefined();

    // Should show truncated pairing ID (first 8 chars)
    const idOutput = stdoutWrites.find((w) => w.includes("abcd1234"));
    expect(idOutput).toBeDefined();

    // Should show cloud URL
    const urlOutput = stdoutWrites.find((w) => w.includes("remmy.watch"));
    expect(urlOutput).toBeDefined();

    // Should show createdAt
    const dateOutput = stdoutWrites.find((w) => w.includes("2026-02-10"));
    expect(dateOutput).toBeDefined();

    // Should show watchId
    const watchOutput = stdoutWrites.find((w) => w.includes("watch-xyz-789"));
    expect(watchOutput).toBeDefined();

    // Should check connectivity
    expect(calls.checkConnectivity).toHaveLength(1);

    // Should show latency (connected)
    expect(calls.spinnerSucceed.some((m) => m.includes("reachable"))).toBe(true);

    // Should show config path
    const pathOutput = stdoutWrites.find((w) => w.includes("config.json"));
    expect(pathOutput).toBeDefined();
  });

  // R8.T7: shows "not paired" when unconfigured
  test("R8.T7: shows 'not paired' when unconfigured", async () => {
    mockIsPaired = false;
    mockConfig = null;

    await runStatus();

    // Should show header
    expect(calls.showHeader).toHaveLength(1);

    // Should show "Not paired" message
    const notPairedMsg = stdoutWrites.find((w) => w.includes("Not paired"));
    expect(notPairedMsg).toBeDefined();

    // Should suggest running remmy to set up
    const setupMsg = stdoutWrites.find((w) => w.includes("remmy"));
    expect(setupMsg).toBeDefined();

    // Should still check connectivity
    expect(calls.checkConnectivity).toHaveLength(1);

    // Should still show config path
    const pathOutput = stdoutWrites.find((w) => w.includes("config.json"));
    expect(pathOutput).toBeDefined();
  });

  test("shows cloud error when connectivity fails", async () => {
    mockIsPaired = false;
    mockConnectivity = { connected: false, error: "Connection timeout" };

    await runStatus();

    // Should show failure in spinner
    expect(calls.spinnerFail.some((m) => m.includes("unreachable"))).toBe(true);
  });
});
