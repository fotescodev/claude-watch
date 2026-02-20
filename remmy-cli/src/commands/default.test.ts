/**
 * Tests for the default command (main happy path).
 *
 * Mocks ALL dependencies: config, cloud-client, hooks-config, claude-launcher,
 * prompt, spinner, header.
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
let mockLaunchClaudeExitCode = 0;
let mockHookResult = { installed: true, registered: true };

// Track calls for assertions
const calls = {
  showHeader: [] as unknown[][],
  migrateLegacyConfig: [] as unknown[][],
  isPaired: [] as unknown[][],
  readConfig: [] as unknown[][],
  checkConnectivity: [] as unknown[][],
  completePairing: [] as unknown[][],
  createConfig: [] as unknown[][],
  saveConfig: [] as unknown[][],
  getCloudUrl: [] as unknown[][],
  setupHook: [] as unknown[][],
  launchClaude: [] as unknown[][],
  askText: [] as unknown[][],
  askConfirm: [] as unknown[][],
  deleteConfig: [] as unknown[][],
  spinnerStart: [] as string[],
  spinnerSucceed: [] as string[],
  spinnerFail: [] as string[],
};

// Capture askText validator for testing
let capturedValidator: ((input: string) => true | string) | undefined;

// Track process.exit calls instead of actually exiting
let processExitCode: number | undefined;

// Capture stdout writes
let stdoutWrites: string[] = [];

// ---------------------------------------------------------------------------
// Module mocks — must be set up before importing the module under test
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
    capturedValidator = validate;
    return Promise.resolve(mockAskTextResult);
  },
  askConfirm: (question: string, defaultValue?: boolean) => {
    calls.askConfirm.push([question, defaultValue]);
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
  createConfig: (cloudUrl: string) => {
    calls.createConfig.push([cloudUrl]);
    return {
      pairingId: "placeholder-uuid",
      cloudUrl,
      createdAt: "2026-01-01T00:00:00.000Z",
    } as RemmyConfig;
  },
  migrateLegacyConfig: () => {
    calls.migrateLegacyConfig.push([]);
    return false;
  },
  deleteConfig: () => {
    calls.deleteConfig.push([]);
  },
  getConfigPath: () => "/home/test/.remmy/config.json",
  getConfigDir: () => "/home/test/.remmy",
}));

mock.module("../lib/cloud-client.ts", () => ({
  DEFAULT_CLOUD_URL: "https://remmy.watch",
  getCloudUrl: () => {
    calls.getCloudUrl.push([]);
    return "https://remmy.watch";
  },
  checkConnectivity: () => {
    calls.checkConnectivity.push([]);
    return Promise.resolve(mockConnectivity);
  },
  completePairing: (code: string) => {
    calls.completePairing.push([code]);
    if (mockCompletePairingResult instanceof Error) {
      return Promise.reject(mockCompletePairingResult);
    }
    return Promise.resolve(mockCompletePairingResult);
  },
}));

mock.module("../lib/hooks-config.ts", () => ({
  setupHook: () => {
    calls.setupHook.push([]);
    return mockHookResult;
  },
  isHookConfigured: () => mockHookResult.installed && mockHookResult.registered,
}));

mock.module("../lib/claude-launcher.ts", () => ({
  launchClaude: (opts: unknown) => {
    calls.launchClaude.push([opts]);
    return Promise.resolve(mockLaunchClaudeExitCode);
  },
}));

// Import AFTER all mocks are registered
const { runDefault } = await import("./default.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("default command", () => {
  beforeEach(() => {
    // Reset all mock state
    mockIsPaired = false;
    mockConfig = null;
    mockConnectivity = { connected: true, latency: 42 };
    mockCompletePairingResult = "pairing-id-from-server";
    mockAskTextResult = "123456";
    mockAskConfirmResult = true;
    mockLaunchClaudeExitCode = 0;
    mockHookResult = { installed: true, registered: true };
    capturedValidator = undefined;
    processExitCode = undefined;

    // Reset call trackers
    for (const key of Object.keys(calls) as (keyof typeof calls)[]) {
      calls[key] = [];
    }

    // Capture stdout writes
    stdoutWrites = [];
    process.stdout.write = ((chunk: unknown) => {
      if (typeof chunk === "string") {
        stdoutWrites.push(chunk);
      }
      return true;
    }) as typeof process.stdout.write;

    // Mock process.exit to capture code instead of exiting
    process.exit = ((code?: number) => {
      processExitCode = code ?? 0;
    }) as typeof process.exit;
  });

  // -------------------------------------------------------------------------
  // Paired flow — skips pairing, calls setupHook + launchClaude (no bridge)
  // -------------------------------------------------------------------------
  test("paired flow — asks to keep pairing, calls setupHook + launchClaude", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = true;
    mockConfig = {
      pairingId: "abcd1234-5678-90ab-cdef-1234567890ab",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-01T00:00:00.000Z",
    };

    await runDefault();

    // Should call showHeader
    expect(calls.showHeader).toHaveLength(1);

    // Should call migrateLegacyConfig
    expect(calls.migrateLegacyConfig).toHaveLength(1);

    // Should ask to keep pairing (with default=true)
    expect(calls.askConfirm).toHaveLength(1);
    expect(calls.askConfirm[0]![1]).toBe(true); // defaultValue = true

    // Should NOT prompt for code
    expect(calls.askText).toHaveLength(0);

    // Should NOT call completePairing
    expect(calls.completePairing).toHaveLength(0);

    // Should call setupHook
    expect(calls.setupHook).toHaveLength(1);

    // Should call launchClaude (no sdkUrl arg)
    expect(calls.launchClaude).toHaveLength(1);

    // Should show truncated pairing ID (first 8 chars)
    const idOutput = stdoutWrites.find((w) => w.includes("abcd1234"));
    expect(idOutput).toBeDefined();

    // Should show launch messages
    const launchMsg = stdoutWrites.find((w) =>
      w.includes("Launching Claude with watch approvals"),
    );
    expect(launchMsg).toBeDefined();
  });

  // -------------------------------------------------------------------------
  // Paired flow — user declines re-pair → falls through to unpaired flow
  // -------------------------------------------------------------------------
  test("paired flow — user declines → deletes config and runs unpaired flow", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = false;
    mockConfig = {
      pairingId: "old-pairing-to-replace",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-01T00:00:00.000Z",
    };
    // Unpaired flow will need these:
    mockAskTextResult = "111222";
    mockCompletePairingResult = "new-pairing-after-repairage";

    await runDefault();

    // Should ask to keep pairing
    expect(calls.askConfirm).toHaveLength(1);

    // Should delete existing config
    expect(calls.deleteConfig).toHaveLength(1);

    // Should fall through to unpaired flow — prompts for code
    expect(calls.askText).toHaveLength(1);

    // Should complete pairing with new code
    expect(calls.completePairing).toHaveLength(1);
    expect(calls.completePairing[0]).toEqual(["111222"]);

    // Should launch claude after re-pairing
    expect(calls.launchClaude).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Paired flow — user Ctrl+C → exits without launch
  // -------------------------------------------------------------------------
  test("paired flow — user Ctrl+C on confirm → exits without launch", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = null; // Ctrl+C
    mockConfig = {
      pairingId: "test-pair-ctrl-c",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-01T00:00:00.000Z",
    };

    await runDefault();

    // Should ask to keep pairing
    expect(calls.askConfirm).toHaveLength(1);

    // Should NOT delete config
    expect(calls.deleteConfig).toHaveLength(0);

    // Should NOT launch claude
    expect(calls.launchClaude).toHaveLength(0);

    // Should NOT call setupHook
    expect(calls.setupHook).toHaveLength(0);
  });

  // -------------------------------------------------------------------------
  // Unpaired flow — prompts for code, pairs, installs hook, launches
  // -------------------------------------------------------------------------
  test("unpaired flow — prompts for code, calls completePairing, saves config, launches", async () => {
    mockIsPaired = false;
    mockAskTextResult = "987654";
    mockCompletePairingResult = "new-pairing-id-from-server";

    await runDefault();

    // Should call showHeader
    expect(calls.showHeader).toHaveLength(1);

    // Should call migrateLegacyConfig
    expect(calls.migrateLegacyConfig).toHaveLength(1);

    // Should show "Not paired" message
    const notPairedMsg = stdoutWrites.find((w) => w.includes("Not paired"));
    expect(notPairedMsg).toBeDefined();

    // Should check connectivity (BLOCKING)
    expect(calls.checkConnectivity).toHaveLength(1);

    // Should prompt for code
    expect(calls.askText).toHaveLength(1);

    // Should call completePairing with the entered code
    expect(calls.completePairing).toHaveLength(1);
    expect(calls.completePairing[0]).toEqual(["987654"]);

    // Should show spinner
    expect(calls.spinnerStart).toHaveLength(1);
    expect(calls.spinnerSucceed).toHaveLength(1);

    // Should create and save config
    expect(calls.createConfig).toHaveLength(1);
    expect(calls.saveConfig).toHaveLength(1);
    const savedConfig = (calls.saveConfig[0] as [RemmyConfig])[0];
    expect(savedConfig.pairingId).toBe("new-pairing-id-from-server");

    // Should call setupHook
    expect(calls.setupHook).toHaveLength(1);

    // Should launch claude (no bridge)
    expect(calls.launchClaude).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Validates 6-digit input
  // -------------------------------------------------------------------------
  test("validates 6-digit input — askText validator rejects non-6-digit", async () => {
    mockIsPaired = false;
    mockAskTextResult = "123456";

    await runDefault();

    // askText should have been called with a validator
    expect(calls.askText).toHaveLength(1);
    expect(capturedValidator).toBeDefined();

    const validate = capturedValidator!;

    // Valid: exactly 6 digits
    expect(validate("123456")).toBe(true);
    expect(validate("000000")).toBe(true);
    expect(validate("999999")).toBe(true);

    // Invalid: not 6 digits
    expect(validate("12345")).not.toBe(true); // too short
    expect(validate("1234567")).not.toBe(true); // too long
    expect(validate("abcdef")).not.toBe(true); // not digits
    expect(validate("12 34 56")).not.toBe(true); // spaces
    expect(validate("")).not.toBe(true); // empty
    expect(validate("12345a")).not.toBe(true); // mixed
  });

  // -------------------------------------------------------------------------
  // Pairing failure — completePairing throws, shows error, no launch
  // -------------------------------------------------------------------------
  test("pairing failure — completePairing throws, shows error, doesn't launch", async () => {
    mockIsPaired = false;
    mockAskTextResult = "999999";
    mockCompletePairingResult = new Error("Invalid or expired code");

    await runDefault();

    // Should call completePairing
    expect(calls.completePairing).toHaveLength(1);

    // Spinner should fail
    expect(calls.spinnerFail).toHaveLength(1);
    expect(calls.spinnerFail[0]).toContain("Invalid or expired code");

    // Should NOT launch claude
    expect(calls.launchClaude).toHaveLength(0);

    // Should NOT save config
    expect(calls.saveConfig).toHaveLength(0);
  });

  // -------------------------------------------------------------------------
  // Exits with Claude's exit code
  // -------------------------------------------------------------------------
  test("exits with Claude's exit code", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "test-pair-id-for-exit-check",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-01T00:00:00.000Z",
    };
    mockLaunchClaudeExitCode = 7;

    await runDefault();

    // process.exit should be called with claude's exit code
    expect(processExitCode).toBe(7);
  });

  // -------------------------------------------------------------------------
  // Cloud failure when paired is informational (still launches)
  // -------------------------------------------------------------------------
  test("cloud failure when paired is informational — still launches", async () => {
    mockIsPaired = true;
    mockConfig = {
      pairingId: "paired-but-cloud-down",
      cloudUrl: "https://remmy.watch",
      createdAt: "2026-01-01T00:00:00.000Z",
    };
    mockConnectivity = { connected: false, error: "Connection timeout" };

    await runDefault();

    // Should show warning but NOT block
    const warningMsg = stdoutWrites.find((w) => w.includes("Cloud unreachable"));
    expect(warningMsg).toBeDefined();

    // Should still launch claude despite cloud being down
    expect(calls.launchClaude).toHaveLength(1);
  });

  // -------------------------------------------------------------------------
  // Cloud failure when unpaired blocks pairing
  // -------------------------------------------------------------------------
  test("cloud failure when unpaired blocks pairing and does not launch", async () => {
    mockIsPaired = false;
    mockConnectivity = { connected: false, error: "DNS resolution failed" };

    await runDefault();

    // Should show error
    const errorMsg = stdoutWrites.find((w) => w.includes("Cannot reach cloud relay"));
    expect(errorMsg).toBeDefined();

    // Should NOT prompt for code
    expect(calls.askText).toHaveLength(0);

    // Should NOT launch claude
    expect(calls.launchClaude).toHaveLength(0);
  });
});
