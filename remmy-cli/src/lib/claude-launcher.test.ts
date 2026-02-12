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
    test("R6.T1: constructs args with ONLY --sdk-url, no forbidden flags", async () => {
      const sdkUrl = "ws://localhost:8787/ws/cli/test-session";
      await launchClaude({ sdkUrl });

      expect(spawnCalls).toHaveLength(1);
      const call = spawnCalls[0]!;
      expect(call.args).toEqual(["--sdk-url", sdkUrl]);

      // Verify forbidden flags are NOT present
      const forbidden = ["--print", "--output-format", "--input-format", "-p", "--verbose"];
      for (const flag of forbidden) {
        expect(call.args).not.toContain(flag);
      }
    });

    test("R6.T2: spawn options include stdio: 'inherit'", async () => {
      await launchClaude({ sdkUrl: "ws://localhost:8787/ws/cli/s1" });

      expect(spawnCalls).toHaveLength(1);
      expect(spawnCalls[0]!.options.stdio).toBe("inherit");
    });

    test("R6.T3: returns exit code from process", async () => {
      fakeExitCode = 42;
      const code = await launchClaude({ sdkUrl: "ws://localhost:8787/ws/cli/s2" });
      expect(code).toBe(42);
    });

    test("R6.T4: env does NOT contain CLAUDE_WATCH_SESSION_ACTIVE", async () => {
      await launchClaude({ sdkUrl: "ws://localhost:8787/ws/cli/s3" });

      expect(spawnCalls).toHaveLength(1);
      const env = spawnCalls[0]!.options.env as Record<string, string | undefined>;

      // The env should be process.env itself (no additions)
      expect(env).toBe(process.env);

      // Double-check the key isn't present
      expect(env.CLAUDE_WATCH_SESSION_ACTIVE).toBeUndefined();
    });

    test("R6.T5: passes extra args after --sdk-url", async () => {
      const sdkUrl = "ws://localhost:8787/ws/cli/s4";
      await launchClaude({
        sdkUrl,
        extraArgs: ["--model", "opus"],
      });

      expect(spawnCalls).toHaveLength(1);
      const call = spawnCalls[0]!;
      expect(call.args).toEqual(["--sdk-url", sdkUrl, "--model", "opus"]);

      // --sdk-url must come before extra args
      const sdkIndex = call.args.indexOf("--sdk-url");
      const modelIndex = call.args.indexOf("--model");
      expect(sdkIndex).toBeLessThan(modelIndex);
    });

    test("throws when claude binary is not found", async () => {
      execSyncResult = new Error("not found");

      await expect(
        launchClaude({ sdkUrl: "ws://localhost:8787/ws/cli/nope" }),
      ).rejects.toThrow("Claude CLI not found");
    });
  });

  describe("findClaude", () => {
    test("returns path when claude binary exists", () => {
      execSyncResult = "/usr/local/bin/claude\n";
      const result = findClaude();
      expect(result).toBe("/usr/local/bin/claude");
    });

    test("R6.T6: returns null when binary not found", () => {
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
