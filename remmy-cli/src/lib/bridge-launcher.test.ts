/**
 * Tests for bridge-launcher.
 *
 * Mocks child_process (spawn/execSync) and fetch to avoid spawning real processes.
 */

import { describe, test, expect, mock, beforeEach, afterEach } from "bun:test";
import { EventEmitter } from "node:events";
import type { ChildProcess } from "node:child_process";

// ---------------------------------------------------------------------------
// Mock setup — must happen before importing the module under test
// ---------------------------------------------------------------------------

// We'll use Bun's module mocking to intercept child_process
let mockSpawn: ReturnType<typeof mock>;
let mockExecSync: ReturnType<typeof mock>;

// Create a fake ChildProcess-like EventEmitter for spawn mocks
function createFakeProcess(opts?: {
  exitCode?: number | null;
  killed?: boolean;
}): ChildProcess {
  const proc = new EventEmitter() as unknown as ChildProcess;
  const stderr = new EventEmitter();

  Object.assign(proc, {
    pid: 12345,
    exitCode: opts?.exitCode ?? null,
    killed: opts?.killed ?? false,
    stderr,
    stdout: null,
    stdin: null,
    kill: mock((signal?: string) => {
      (proc as { killed: boolean }).killed = true;
      if (signal === "SIGKILL" || signal === "SIGTERM") {
        // Emit exit asynchronously so tests can observe behavior
        setTimeout(() => {
          proc.emit("exit", signal === "SIGKILL" ? 137 : 0, signal);
          proc.emit("close", signal === "SIGKILL" ? 137 : 0, signal);
        }, 10);
      }
      return true;
    }),
  });

  return proc;
}

// Save original fetch
const originalFetch = globalThis.fetch;

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe("bridge-launcher", () => {
  let bridgeLauncher: typeof import("./bridge-launcher.js");

  beforeEach(async () => {
    // Reset mocks before each test
    mockSpawn = mock();
    mockExecSync = mock();

    // Mock the child_process module
    mock.module("node:child_process", () => ({
      spawn: mockSpawn,
      execSync: mockExecSync,
    }));

    // Re-import to pick up mocks
    // Use a cache-buster query param to force re-evaluation
    bridgeLauncher = await import("./bridge-launcher.js");
  });

  afterEach(() => {
    // Restore original fetch
    globalThis.fetch = originalFetch;
  });

  // -------------------------------------------------------------------------
  // R5.T5: findPython detects python3 (mock execSync)
  // -------------------------------------------------------------------------
  describe("findPython", () => {
    test("R5.T5: returns 'python3' when python3 --version succeeds with Python 3", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "python3 --version") {
          return Buffer.from("Python 3.11.5\n");
        }
        throw new Error("command not found");
      });

      const result = bridgeLauncher.findPython();
      expect(result).toBe("python3");
    });

    test("falls back to 'python' when python3 fails but python is Python 3", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "python3 --version") {
          throw new Error("command not found");
        }
        if (cmd === "python --version") {
          return Buffer.from("Python 3.10.0\n");
        }
        throw new Error("command not found");
      });

      const result = bridgeLauncher.findPython();
      expect(result).toBe("python");
    });

    test("returns null when no Python 3 is found", () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("command not found");
      });

      const result = bridgeLauncher.findPython();
      expect(result).toBeNull();
    });

    test("returns null when python is Python 2", () => {
      mockExecSync.mockImplementation((cmd: string) => {
        if (cmd === "python3 --version") {
          throw new Error("command not found");
        }
        if (cmd === "python --version") {
          return Buffer.from("Python 2.7.18\n");
        }
        throw new Error("command not found");
      });

      const result = bridgeLauncher.findPython();
      expect(result).toBeNull();
    });
  });

  // -------------------------------------------------------------------------
  // R5.T2: waitForHealth returns true when fetch returns 200
  // -------------------------------------------------------------------------
  describe("waitForHealth", () => {
    test("R5.T2: returns true when fetch returns 200", async () => {
      globalThis.fetch = mock(async () => {
        return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
      }) as unknown as typeof fetch;

      const result = await bridgeLauncher.waitForHealth(8788, 2000);
      expect(result).toBe(true);
    });

    // R5.T3: waitForHealth returns false after timeout
    test("R5.T3: returns false after timeout when server never responds", async () => {
      globalThis.fetch = mock(async () => {
        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      const result = await bridgeLauncher.waitForHealth(8788, 500);
      expect(result).toBe(false);
    });

    test("returns true after initial failures then success", async () => {
      let callCount = 0;
      globalThis.fetch = mock(async () => {
        callCount++;
        if (callCount < 3) {
          throw new TypeError("fetch failed");
        }
        return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
      }) as unknown as typeof fetch;

      const result = await bridgeLauncher.waitForHealth(8788, 5000);
      expect(result).toBe(true);
      expect(callCount).toBeGreaterThanOrEqual(3);
    });
  });

  // -------------------------------------------------------------------------
  // R5.T1: launchBridge constructs correct spawn args
  // -------------------------------------------------------------------------
  describe("launchBridge", () => {
    test("R5.T1: constructs correct spawn args", async () => {
      const fakeProc = createFakeProcess();
      mockSpawn.mockReturnValue(fakeProc);

      // Health check succeeds immediately
      globalThis.fetch = mock(async (url: string | URL | Request) => {
        const urlStr = typeof url === "string" ? url : url.toString();
        if (urlStr.includes("/health")) {
          return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
        }
        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      const promise = bridgeLauncher.launchBridge({
        pairingId: "PAIR-123",
        port: 8787,
        pythonPath: "/usr/bin/python3",
      });

      const result = await promise;

      // Verify spawn was called with correct args
      expect(mockSpawn).toHaveBeenCalledTimes(1);
      const [bin, args] = mockSpawn.mock.calls[0] as [string, string[], Record<string, unknown>];

      expect(bin).toBe("/usr/bin/python3");
      expect(args).toContain("-m");
      expect(args).toContain("MCPServer.bridge");
      expect(args).toContain("--port");
      expect(args).toContain("8787");
      expect(args).toContain("--pairing-id");
      expect(args).toContain("PAIR-123");

      expect(result.port).toBe(8787);
      expect(result.httpPort).toBe(8788);
      expect(result.pairingId).toBe("PAIR-123");
      expect(result.process).toBe(fakeProc);
    });

    // R5.T6: launchBridge passes --verbose flag when verbose=true
    test("R5.T6: passes --verbose flag when verbose=true", async () => {
      const fakeProc = createFakeProcess();
      mockSpawn.mockReturnValue(fakeProc);

      globalThis.fetch = mock(async (url: string | URL | Request) => {
        const urlStr = typeof url === "string" ? url : url.toString();
        if (urlStr.includes("/health")) {
          return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
        }
        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      await bridgeLauncher.launchBridge({
        pairingId: "PAIR-456",
        port: 8787,
        verbose: true,
        pythonPath: "/usr/bin/python3",
      });

      const [_bin, args] = mockSpawn.mock.calls[0] as [string, string[]];
      expect(args).toContain("--verbose");
    });

    test("does not pass --verbose when verbose is false/undefined", async () => {
      const fakeProc = createFakeProcess();
      mockSpawn.mockReturnValue(fakeProc);

      globalThis.fetch = mock(async (url: string | URL | Request) => {
        const urlStr = typeof url === "string" ? url : url.toString();
        if (urlStr.includes("/health")) {
          return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
        }
        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      await bridgeLauncher.launchBridge({
        pairingId: "PAIR-789",
        port: 8787,
        pythonPath: "/usr/bin/python3",
      });

      const [_bin, args] = mockSpawn.mock.calls[0] as [string, string[]];
      expect(args).not.toContain("--verbose");
    });

    // R5.T7: launchBridge sets PYTHONPATH in spawn env
    test("R5.T7: sets PYTHONPATH in spawn env", async () => {
      const fakeProc = createFakeProcess();
      mockSpawn.mockReturnValue(fakeProc);

      globalThis.fetch = mock(async (url: string | URL | Request) => {
        const urlStr = typeof url === "string" ? url : url.toString();
        if (urlStr.includes("/health")) {
          return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
        }
        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      await bridgeLauncher.launchBridge({
        pairingId: "PAIR-ENV",
        port: 8787,
        pythonPath: "/usr/bin/python3",
      });

      const [_bin, _args, options] = mockSpawn.mock.calls[0] as [string, string[], { env: Record<string, string | undefined> }];
      expect(options.env).toBeDefined();
      expect(options.env.PYTHONPATH).toBeDefined();
      expect(typeof options.env.PYTHONPATH).toBe("string");
      // PYTHONPATH should be a directory path (the repo root)
      expect(options.env.PYTHONPATH!.length).toBeGreaterThan(0);
    });

    // R5.T8: port fallback when first port fails
    test("R5.T8: tries next port when first port is busy", async () => {
      const fakeProc = createFakeProcess();
      mockSpawn.mockReturnValue(fakeProc);

      // First port (8787) is busy, second (8788) is also busy (it's httpPort of 8787),
      // third (8789) is free
      let fetchCallCount = 0;
      globalThis.fetch = mock(async (url: string | URL | Request) => {
        fetchCallCount++;
        const urlStr = typeof url === "string" ? url : url.toString();

        // Port check: ports 8787 and 8788 are busy
        if (urlStr === "http://localhost:8787") {
          return new Response("busy", { status: 200 });
        }
        if (urlStr === "http://localhost:8788") {
          return new Response("busy", { status: 200 });
        }
        // Port 8789 is free (connection refused)
        if (urlStr === "http://localhost:8789") {
          throw new TypeError("fetch failed");
        }

        // Health check on port 8790 (8789 + 1)
        if (urlStr.includes("8790") && urlStr.includes("/health")) {
          return new Response(JSON.stringify({ status: "ok" }), { status: 200 });
        }

        throw new TypeError("fetch failed");
      }) as unknown as typeof fetch;

      const result = await bridgeLauncher.launchBridge({
        pairingId: "PAIR-PORT",
        port: 8787,
        pythonPath: "/usr/bin/python3",
      });

      // Should have settled on port 8789
      expect(result.port).toBe(8789);
      expect(result.httpPort).toBe(8790);

      // Verify spawn was called with the correct port
      const [_bin, args] = mockSpawn.mock.calls[0] as [string, string[]];
      const portIdx = args.indexOf("--port");
      expect(args[portIdx + 1]).toBe("8789");
    });

    test("throws when Python is not found", async () => {
      mockExecSync.mockImplementation(() => {
        throw new Error("command not found");
      });

      await expect(
        bridgeLauncher.launchBridge({
          pairingId: "PAIR-NOPY",
          // No pythonPath override — forces findPython()
        }),
      ).rejects.toThrow("Python 3 not found");
    });
  });

  // -------------------------------------------------------------------------
  // R5.T4: stopBridge sends SIGTERM then SIGKILL after timeout
  // -------------------------------------------------------------------------
  describe("stopBridge", () => {
    test("R5.T4: sends SIGTERM then SIGKILL after timeout", async () => {
      const fakeProc = createFakeProcess();
      // Override kill to NOT auto-emit exit for SIGTERM (simulating hung process)
      const killCalls: string[] = [];
      (fakeProc as { kill: (sig?: string) => boolean }).kill = mock((signal?: string) => {
        killCalls.push(signal ?? "SIGTERM");
        if (signal === "SIGKILL") {
          // SIGKILL always works — emit exit
          setTimeout(() => {
            fakeProc.emit("exit", 137, "SIGKILL");
            fakeProc.emit("close", 137, "SIGKILL");
          }, 5);
        }
        // SIGTERM: don't emit exit (process is hung)
        return true;
      });

      const bp: import("./bridge-launcher.js").BridgeProcess = {
        process: fakeProc,
        port: 8787,
        httpPort: 8788,
        pairingId: "PAIR-STOP",
      };

      // Use a short timeout to speed up the test — we'll monkey-patch
      // the STOP_TIMEOUT_MS is 3000 in the module but stopBridge will
      // wait for exit or send SIGKILL after the internal timer
      await bridgeLauncher.stopBridge(bp);

      // SIGTERM should be sent first
      expect(killCalls[0]).toBe("SIGTERM");
      // SIGKILL should follow after the timeout
      expect(killCalls).toContain("SIGKILL");
    });

    test("returns immediately if process already exited", async () => {
      const fakeProc = createFakeProcess({ exitCode: 0 });

      const bp: import("./bridge-launcher.js").BridgeProcess = {
        process: fakeProc,
        port: 8787,
        httpPort: 8788,
        pairingId: "PAIR-DONE",
      };

      // Should resolve near-instantly
      await bridgeLauncher.stopBridge(bp);
      // kill should NOT have been called
      expect(fakeProc.kill).not.toHaveBeenCalled();
    });

    test("resolves when SIGTERM causes clean exit", async () => {
      const fakeProc = createFakeProcess();
      // Override kill to emit exit on SIGTERM (clean shutdown)
      (fakeProc as { kill: (sig?: string) => boolean }).kill = mock((signal?: string) => {
        (fakeProc as { killed: boolean }).killed = true;
        if (signal === "SIGTERM") {
          setTimeout(() => {
            fakeProc.emit("exit", 0, "SIGTERM");
            fakeProc.emit("close", 0, "SIGTERM");
          }, 10);
        }
        return true;
      });

      const bp: import("./bridge-launcher.js").BridgeProcess = {
        process: fakeProc,
        port: 8787,
        httpPort: 8788,
        pairingId: "PAIR-CLEAN",
      };

      await bridgeLauncher.stopBridge(bp);
      // Only SIGTERM should be called (no SIGKILL needed)
      expect(fakeProc.kill).toHaveBeenCalledTimes(1);
    });
  });
});
