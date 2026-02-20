import { describe, test, expect, mock, beforeEach } from "bun:test";
import type { ChildProcess } from "node:child_process";

// ---- Mocks ----

// We capture calls to spawn/execSync so we can assert args and options.
let spawnCalls: Array<{ command: string; args: string[]; options: Record<string, unknown> }> = [];
let execSyncResult: string | Error = "/usr/local/bin/claude";
let fakeExitCode = 0;

// Fake ChildProcess event emitter
function makeFakeChild(exitCode: number): Partial<ChildProcess> {
  const child: Partial<ChildProcess> = {
    on(event: string, cb: (...args: unknown[]) => void) {
      // Auto-fire "close" on next tick so the promise resolves
      if (event === "close") {
        setTimeout(() => cb(exitCode), 0);
      }
      return child as ChildProcess;
    },
  };

  return child;
}

// Mock the entire node:child_process module
mock.module("node:child_process", () => ({
  spawn: (command: string, args: string[], options: Record<string, unknown>) => {
    spawnCalls.push({ command, args, options });
    return makeFakeChild(fakeExitCode);
  },
  execSync: (_cmd: string, _opts?: Record<string, unknown>) => {
    if (execSyncResult instanceof Error) {
      throw execSyncResult;
    }
    return execSyncResult;
  },
}));

// Import AFTER mocking so the module picks up our mocks
const { launchClaude, findClaude } = await import("./claude-launcher.ts");

// ---- Tests ----

describe("claude-launcher", () => {
  beforeEach(() => {
    spawnCalls = [];
    execSyncResult = "/usr/local/bin/claude";
    fakeExitCode = 0;
  });

  describe("launchClaude", () => {
    test("spawns with NO --sdk-url flag", async () => {
      await launchClaude();

      expect(spawnCalls).toHaveLength(1);
      const call = spawnCalls[0]!;
      // No args by default (no --sdk-url)
      expect(call.args).toEqual([]);

      // Verify forbidden flags are NOT present
      const forbidden = ["--sdk-url", "--print", "--output-format", "--input-format", "-p", "--verbose"];
      for (const flag of forbidden) {
        expect(call.args).not.toContain(flag);
      }
    });

    test("spawn options include stdio: 'inherit'", async () => {
      await launchClaude();

      expect(spawnCalls).toHaveLength(1);
      expect(spawnCalls[0]!.options.stdio).toBe("inherit");
    });

    test("returns exit code from process", async () => {
      fakeExitCode = 42;
      const code = await launchClaude();
      expect(code).toBe(42);
    });

    test("env CONTAINS CLAUDE_WATCH_SESSION_ACTIVE=1", async () => {
      await launchClaude();

      expect(spawnCalls).toHaveLength(1);
      const env = spawnCalls[0]!.options.env as Record<string, string | undefined>;

      // Must contain the env var
      expect(env.CLAUDE_WATCH_SESSION_ACTIVE).toBe("1");
    });

    test("env is a copy of process.env (not the same reference)", async () => {
      await launchClaude();

      expect(spawnCalls).toHaveLength(1);
      const env = spawnCalls[0]!.options.env as Record<string, string | undefined>;

      // Should NOT be process.env itself — it should be a copy with additions
      expect(env).not.toBe(process.env);
    });

    test("passes extra args", async () => {
      await launchClaude({
        extraArgs: ["--model", "opus"],
      });

      expect(spawnCalls).toHaveLength(1);
      const call = spawnCalls[0]!;
      expect(call.args).toEqual(["--model", "opus"]);
    });

    test("throws when claude binary is not found", async () => {
      execSyncResult = new Error("not found");

      await expect(
        launchClaude(),
      ).rejects.toThrow("Claude CLI not found");
    });
  });

  describe("findClaude", () => {
    test("returns path when claude binary exists", () => {
      execSyncResult = "/usr/local/bin/claude\n";
      const result = findClaude();
      expect(result).toBe("/usr/local/bin/claude");
    });

    test("returns null when binary not found", () => {
      execSyncResult = new Error("which: no claude in PATH");
      const result = findClaude();
      expect(result).toBeNull();
    });

    test("returns null when execSync returns empty string", () => {
      execSyncResult = "";
      const result = findClaude();
      expect(result).toBeNull();
    });
  });
});
