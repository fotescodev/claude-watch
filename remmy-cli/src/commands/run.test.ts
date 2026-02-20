/**
 * Tests for the run command.
 *
 * Mocks ALL dependencies: config, hooks-config, claude-launcher, spinner, colors.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { RemmyConfig } from "../types.ts";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

let mockIsPaired = false;
let mockConfig: RemmyConfig | null = null;
let mockLaunchClaudeExitCode = 0;
let mockLaunchClaudeError: Error | null = null;

// Track calls
const calls = {
  isPaired: [] as unknown[][],
  readConfig: [] as unknown[][],
  setupHook: [] as unknown[][],
  launchClaude: [] as unknown[][],
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
    start() {}
    succeed() {}
    fail() {}
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

mock.module("../lib/hooks-config.ts", () => ({
  setupHook: () => {
    calls.setupHook.push([]);
    return { installed: true, registered: true };
  },
  isHookConfigured: () => true,
}));

mock.module("../lib/claude-launcher.ts", () => ({
  launchClaude: (opts: unknown) => {
    calls.launchClaude.push([opts]);
    if (mockLaunchClaudeError) {
      return Promise.reject(mockLaunchClaudeError);
    }
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
    mockLaunchClaudeError = null;
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

  // Rejects if not paired
  test("rejects if not paired", async () => {
    mockIsPaired = false;

    await runRun();

    // Should show error about not being paired
    const errorOutput = stdoutWrites.find((w) => w.includes("Not paired"));
    expect(errorOutput).toBeDefined();

    // Should set exit code to 1
    expect(process.exitCode).toBe(1);

    // Should NOT launch claude
    expect(calls.launchClaude).toHaveLength(0);
  });

  // Calls setupHook + launchClaude when paired (no bridge)
  test("calls setupHook + launchClaude when paired", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "my-pair-id-for-run",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-02-01T00:00:00.000Z",
    };
    mockLaunchClaudeExitCode = 0;

    await runRun();

    // Should call setupHook
    expect(calls.setupHook).toHaveLength(1);

    // Should launch claude (no sdkUrl, no bridge)
    expect(calls.launchClaude).toHaveLength(1);
  });

  // Passes extra args directly
  test("passes extra args directly to launchClaude", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "pair-with-args",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-02-01T00:00:00.000Z",
    };

    await runRun(["--model", "opus", "--verbose"]);

    // Should launch claude with extra args
    expect(calls.launchClaude).toHaveLength(1);
    const claudeOpts = (calls.launchClaude[0] as [{ extraArgs?: string[] }])[0];
    expect(claudeOpts.extraArgs).toEqual(["--model", "opus", "--verbose"]);
  });
});
