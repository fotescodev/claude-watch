/**
 * Tests for the run command.
 *
 * Mocks ALL dependencies: config, bridge-launcher, claude-launcher, spinner, colors.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { RemmyConfig } from "../types.ts";
import type { BridgeProcess } from "../lib/bridge-launcher.ts";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

let mockIsPaired = false;
let mockConfig: RemmyConfig | null = null;
let mockLaunchClaudeExitCode = 0;
let mockLaunchBridgeError: Error | null = null;

// Fake bridge process
const fakeBridge: BridgeProcess = {
  process: {} as BridgeProcess["process"],
  port: 8787,
  httpPort: 8788,
  pairingId: "test-pairing-id",
};

// Track calls
const calls = {
  isPaired: [] as unknown[][],
  readConfig: [] as unknown[][],
  launchBridge: [] as unknown[][],
  launchClaude: [] as unknown[][],
  stopBridge: [] as unknown[][],
  spinnerStart: [] as string[],
  spinnerSucceed: [] as string[],
  spinnerFail: [] as string[],
};

// Capture stdout + process.exit
let stdoutWrites: string[] = [];
let processExitCode: number | undefined;

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

mock.module("../ui/header.ts", () => ({
  showHeader: () => {},
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
  createConfig: (cloudUrl: string) => ({
    pairingId: "placeholder-uuid",
    cloudUrl,
    createdAt: "2026-01-01T00:00:00.000Z",
  }),
  migrateLegacyConfig: () => false,
  getConfigPath: () => "/home/test/.remmy/config.json",
  getConfigDir: () => "/home/test/.remmy",
  saveConfig: () => {},
  deleteConfig: () => {},
}));

mock.module("../lib/cloud-client.ts", () => ({
  DEFAULT_CLOUD_URL: "https://remmy.watch",
  getCloudUrl: () => "https://remmy.watch",
  checkConnectivity: () => Promise.resolve({ connected: true, latency: 10 }),
  completePairing: () => Promise.resolve("pair-id"),
}));

mock.module("../lib/bridge-launcher.ts", () => ({
  launchBridge: (opts: unknown) => {
    calls.launchBridge.push([opts]);
    if (mockLaunchBridgeError) {
      return Promise.reject(mockLaunchBridgeError);
    }
    return Promise.resolve({ ...fakeBridge, pairingId: (opts as { pairingId: string }).pairingId });
  },
  stopBridge: (bp: unknown) => {
    calls.stopBridge.push([bp]);
    return Promise.resolve();
  },
}));

mock.module("../lib/claude-launcher.ts", () => ({
  launchClaude: (opts: unknown) => {
    calls.launchClaude.push([opts]);
    return Promise.resolve(mockLaunchClaudeExitCode);
  },
}));

// Import AFTER all mocks
const { runRun } = await import("./run.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("run command", () => {
  beforeEach(() => {
    // Reset mock state
    mockIsPaired = false;
    mockConfig = null;
    mockLaunchClaudeExitCode = 0;
    mockLaunchBridgeError = null;
    processExitCode = undefined;

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

    // Mock process.exit
    process.exit = ((code?: number) => {
      processExitCode = code ?? 0;
    }) as typeof process.exit;
  });

  // R8.T3: rejects if not paired
  test("R8.T3: rejects if not paired", async () => {
    mockIsPaired = false;

    await runRun();

    // Should show error about not being paired
    const errorOutput = stdoutWrites.find((w) => w.includes("Not paired"));
    expect(errorOutput).toBeDefined();

    // Should set exit code to 1
    expect(process.exitCode).toBe(1);

    // Should NOT launch bridge or claude
    expect(calls.launchBridge).toHaveLength(0);
    expect(calls.launchClaude).toHaveLength(0);
  });

  // R8.T4: launches bridge + claude when paired
  test("R8.T4: launches bridge + claude when paired", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "my-pair-id-for-run",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-02-01T00:00:00.000Z",
    };
    mockLaunchClaudeExitCode = 0;

    await runRun();

    // Should launch bridge with correct pairingId
    expect(calls.launchBridge).toHaveLength(1);
    const bridgeOpts = (calls.launchBridge[0] as [{ pairingId: string; port: number }])[0];
    expect(bridgeOpts.pairingId).toBe("my-pair-id-for-run");
    expect(bridgeOpts.port).toBe(8787);

    // Should launch claude with sdkUrl
    expect(calls.launchClaude).toHaveLength(1);
    const claudeOpts = (calls.launchClaude[0] as [{ sdkUrl: string; extraArgs?: string[] }])[0];
    expect(claudeOpts.sdkUrl).toContain("ws://localhost:8787/ws/cli/");

    // Should stop bridge after claude exits
    expect(calls.stopBridge).toHaveLength(1);

    // Spinner should show bridge start
    expect(calls.spinnerStart.some((m) => m.includes("bridge"))).toBe(true);
  });

  // R8.T5: passes extra args directly
  test("R8.T5: passes extra args directly to launchClaude", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "pair-with-args",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-02-01T00:00:00.000Z",
    };

    await runRun(["--model", "opus", "--verbose"]);

    // Should launch claude with extra args
    expect(calls.launchClaude).toHaveLength(1);
    const claudeOpts = (calls.launchClaude[0] as [{ sdkUrl: string; extraArgs?: string[] }])[0];
    expect(claudeOpts.extraArgs).toEqual(["--model", "opus", "--verbose"]);
  });
});
