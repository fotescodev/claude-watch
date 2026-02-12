/**
 * Tests for the unpair command.
 *
 * Mocks ALL dependencies: config, prompt, colors, and node:fs/node:os/node:path.
 */

import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { RemmyConfig } from "../types.ts";

// ---------------------------------------------------------------------------
// Shared mock state
// ---------------------------------------------------------------------------

let mockIsPaired = false;
let mockAskConfirmResult: boolean | null = true;
let mockDeleteConfigCalled = false;

// Simulated filesystem for legacy artifact detection
let fsFiles: Record<string, string> = {};

// Track calls
const calls = {
  isPaired: [] as unknown[][],
  deleteConfig: [] as unknown[][],
  getConfigPath: [] as unknown[][],
  askConfirm: [] as unknown[][],
  existsSync: [] as string[],
  readFileSync: [] as string[],
  writeFileSync: [] as unknown[][],
  unlinkSync: [] as string[],
};

// Capture stdout
let stdoutWrites: string[] = [];

// ---------------------------------------------------------------------------
// Module mocks
// ---------------------------------------------------------------------------

mock.module("../ui/colors.ts", () => ({
  red: (s: string) => `[red:${s}]`,
  green: (s: string) => `[green:${s}]`,
  yellow: (s: string) => `[yellow:${s}]`,
  cyan: (s: string) => `[cyan:${s}]`,
  dim: (s: string) => `[dim:${s}]`,
  bold: (s: string) => `[bold:${s}]`,
  white: (s: string) => `[white:${s}]`,
}));

mock.module("../ui/prompt.ts", () => ({
  askText: () => Promise.resolve(null),
  askConfirm: (question: string, defaultVal?: boolean) => {
    calls.askConfirm.push([question, defaultVal]);
    return Promise.resolve(mockAskConfirmResult);
  },
}));

mock.module("../lib/config.ts", () => ({
  isPaired: () => {
    calls.isPaired.push([]);
    return mockIsPaired;
  },
  deleteConfig: () => {
    calls.deleteConfig.push([]);
    mockDeleteConfigCalled = true;
  },
  getConfigPath: () => {
    calls.getConfigPath.push([]);
    return "/home/test/.remmy/config.json";
  },
  readConfig: () => null,
  saveConfig: () => {},
  createConfig: (cloudUrl: string) => ({
    pairingId: "placeholder-uuid",
    cloudUrl,
    createdAt: "2026-01-01T00:00:00.000Z",
  }),
  migrateLegacyConfig: () => false,
  getConfigDir: () => "/home/test/.remmy",
}));

mock.module("node:os", () => ({
  homedir: () => "/home/test",
}));

mock.module("node:path", () => ({
  join: (...parts: string[]) => parts.join("/"),
}));

mock.module("node:fs", () => ({
  existsSync: (path: string) => {
    calls.existsSync.push(path);
    return path in fsFiles;
  },
  readFileSync: (path: string, _encoding?: string) => {
    calls.readFileSync.push(path);
    if (path in fsFiles) {
      return fsFiles[path]!;
    }
    throw new Error(`ENOENT: no such file: ${path}`);
  },
  writeFileSync: (path: string, content: string) => {
    calls.writeFileSync.push([path, content]);
    fsFiles[path] = content;
  },
  unlinkSync: (path: string) => {
    calls.unlinkSync.push(path);
    delete fsFiles[path];
  },
}));

// Import AFTER all mocks
const { runUnpair } = await import("./unpair.ts");

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("unpair command", () => {
  beforeEach(() => {
    // Reset mock state
    mockIsPaired = false;
    mockAskConfirmResult = true;
    mockDeleteConfigCalled = false;
    fsFiles = {};

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

  // R8.T8: deletes config after confirmation
  test("R8.T8: deletes config after confirmation", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = true;

    await runUnpair();

    // Should ask for confirmation
    expect(calls.askConfirm).toHaveLength(1);
    expect((calls.askConfirm[0]![0] as string)).toContain("Remove configuration");

    // Should call deleteConfig
    expect(calls.deleteConfig).toHaveLength(1);
    expect(mockDeleteConfigCalled).toBe(true);

    // Should show success message
    const removedMsg = stdoutWrites.find((w) => w.includes("Configuration removed"));
    expect(removedMsg).toBeDefined();

    // Should show "set up again" message
    const setupMsg = stdoutWrites.find((w) => w.includes("set up again"));
    expect(setupMsg).toBeDefined();
  });

  // R8.T9: cancellation preserves config
  test("R8.T9: cancellation preserves config", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = false; // User cancels

    await runUnpair();

    // Should ask for confirmation
    expect(calls.askConfirm).toHaveLength(1);

    // Should NOT call deleteConfig
    expect(calls.deleteConfig).toHaveLength(0);
    expect(mockDeleteConfigCalled).toBe(false);

    // Should show "Cancelled" message
    const cancelledMsg = stdoutWrites.find((w) => w.includes("Cancelled"));
    expect(cancelledMsg).toBeDefined();
  });

  // R8.T10: detects legacy cc-watch artifacts
  test("R8.T10: detects legacy cc-watch artifacts", async () => {
    mockIsPaired = true;
    mockAskConfirmResult = true;

    // Set up legacy filesystem artifacts
    const hookPath = "/home/test/.claude/hooks/watch-approval-cloud.py";
    const settingsPath = "/home/test/.claude/settings.json";
    const mcpPath = "/home/test/.claude/.mcp.json";

    fsFiles[hookPath] = "#!/usr/bin/env python3\n# legacy hook";
    fsFiles[settingsPath] = JSON.stringify({
      hooks: {
        PreToolUse: [
          { command: "python3 watch-approval-cloud.py", timeout: 30 },
          { command: "other-hook.py", timeout: 10 },
        ],
      },
    });
    fsFiles[mcpPath] = JSON.stringify({
      mcpServers: {
        "claude-watch": { command: "python", args: ["-m", "MCPServer"] },
        "other-server": { command: "node", args: ["server.js"] },
      },
    });

    await runUnpair();

    // Should detect and display legacy artifacts
    const legacyOutput = stdoutWrites.find((w) => w.includes("legacy"));
    expect(legacyOutput).toBeDefined();

    // Should show the hook path in what will be deleted
    const hookOutput = stdoutWrites.find((w) => w.includes("watch-approval"));
    expect(hookOutput).toBeDefined();

    // Should remove legacy artifacts after confirmation
    expect(calls.deleteConfig).toHaveLength(1);

    // Hook file should be removed
    expect(calls.unlinkSync).toContain(hookPath);

    // Settings.json should be rewritten (PreToolUse hook filtered)
    const settingsWrite = calls.writeFileSync.find(
      (c) => (c as [string, string])[0] === settingsPath,
    );
    expect(settingsWrite).toBeDefined();
    const updatedSettings = JSON.parse((settingsWrite as [string, string])[1]);
    // "watch-approval" entry should be removed, "other-hook" preserved
    expect(updatedSettings.hooks.PreToolUse).toHaveLength(1);
    expect(updatedSettings.hooks.PreToolUse[0].command).toBe("other-hook.py");

    // .mcp.json should be rewritten (claude-watch server removed)
    const mcpWrite = calls.writeFileSync.find(
      (c) => (c as [string, string])[0] === mcpPath,
    );
    expect(mcpWrite).toBeDefined();
    const updatedMcp = JSON.parse((mcpWrite as [string, string])[1]);
    expect(updatedMcp.mcpServers["claude-watch"]).toBeUndefined();
    expect(updatedMcp.mcpServers["other-server"]).toBeDefined();

    // Should show legacy cleanup message
    const cleanupMsg = stdoutWrites.find((w) => w.includes("Legacy artifacts cleaned up"));
    expect(cleanupMsg).toBeDefined();
  });

  test("shows 'not paired' when no config exists", async () => {
    mockIsPaired = false;

    await runUnpair();

    // Should show not paired message
    const notPairedMsg = stdoutWrites.find((w) => w.includes("Not paired"));
    expect(notPairedMsg).toBeDefined();

    // Should NOT ask for confirmation
    expect(calls.askConfirm).toHaveLength(0);

    // Should NOT call deleteConfig
    expect(calls.deleteConfig).toHaveLength(0);
  });
});
