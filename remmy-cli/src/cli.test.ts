import { describe, test, expect, beforeEach, afterEach, mock, spyOn } from "bun:test";
import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

// Create mock command handlers before mocking modules
const mockRunDefault = mock(() => Promise.resolve());
const mockRunSetup = mock(() => Promise.resolve());
const mockRunRun = mock((_args: string[]) => Promise.resolve());
const mockRunStatus = mock(() => Promise.resolve());
const mockRunUnpair = mock(() => Promise.resolve());

// Mock all command modules (they may not exist yet — Wave 2 parallel)
mock.module("./commands/default.ts", () => ({
  runDefault: mockRunDefault,
}));
mock.module("./commands/setup.ts", () => ({
  runSetup: mockRunSetup,
}));
mock.module("./commands/run.ts", () => ({
  runRun: mockRunRun,
}));
mock.module("./commands/status.ts", () => ({
  runStatus: mockRunStatus,
}));
mock.module("./commands/unpair.ts", () => ({
  runUnpair: mockRunUnpair,
}));

// Import after mocking
import { route, verbose } from "./cli.ts";

// Read version independently from package.json for test comparison
const testDirname = dirname(fileURLToPath(import.meta.url));
const expectedVersion: string = JSON.parse(
  readFileSync(join(testDirname, "../package.json"), "utf8")
).version;

describe("CLI router", () => {
  let consoleSpy: ReturnType<typeof spyOn>;
  let consoleErrorSpy: ReturnType<typeof spyOn>;
  let exitSpy: ReturnType<typeof spyOn>;
  let logs: string[];
  let errors: string[];

  beforeEach(() => {
    logs = [];
    errors = [];
    consoleSpy = spyOn(console, "log").mockImplementation((...args: unknown[]) => {
      logs.push(args.map(String).join(" "));
    });
    consoleErrorSpy = spyOn(console, "error").mockImplementation((...args: unknown[]) => {
      errors.push(args.map(String).join(" "));
    });
    exitSpy = spyOn(process, "exit").mockImplementation((() => {
      // Prevent actual process exit in tests
    }) as (code?: number) => never);

    // Reset all command mock call counts
    mockRunDefault.mockClear();
    mockRunSetup.mockClear();
    mockRunRun.mockClear();
    mockRunStatus.mockClear();
    mockRunUnpair.mockClear();
  });

  afterEach(() => {
    consoleSpy.mockRestore();
    consoleErrorSpy.mockRestore();
    exitSpy.mockRestore();
  });

  // --- R9.T1: routes "setup" to runSetup ---
  test("R9.T1: routes 'setup' to runSetup", async () => {
    await route(["setup"]);
    expect(mockRunSetup).toHaveBeenCalledTimes(1);
  });

  // --- R9.T2: routes "" (empty) to runDefault ---
  test("R9.T2: routes empty args to runDefault", async () => {
    await route([]);
    expect(mockRunDefault).toHaveBeenCalledTimes(1);
  });

  // --- R9.T3: unknown command exits with code 1 ---
  test("R9.T3: unknown command exits with code 1", async () => {
    await route(["foobar"]);
    expect(exitSpy).toHaveBeenCalledWith(1);
    expect(errors.some((e) => e.includes("Unknown command"))).toBe(true);
    expect(errors.some((e) => e.includes("foobar"))).toBe(true);
    // Should also print help text
    expect(logs.some((l) => l.includes("Remmy"))).toBe(true);
  });

  // --- R9.T4: --help prints help text containing "Remmy" ---
  test("R9.T4: --help prints help text containing 'Remmy'", async () => {
    await route(["--help"]);
    const output = logs.join("\n");
    expect(output).toContain("Remmy");
    expect(output).toContain("setup");
    expect(output).toContain("run");
    expect(output).toContain("status");
    expect(output).toContain("unpair");
    expect(output).toContain("--verbose");
  });

  // --- R9.T5: --version prints semver matching package.json ---
  test("R9.T5: --version prints semver matching package.json", async () => {
    await route(["--version"]);
    expect(logs).toHaveLength(1);
    expect(logs[0]).toBe(expectedVersion);
    // Verify it looks like a semver
    expect(logs[0]).toMatch(/^\d+\.\d+\.\d+/);
  });

  // --- R9.T6: bare "version" also works ---
  test("R9.T6: bare 'version' also prints version", async () => {
    await route(["version"]);
    expect(logs).toHaveLength(1);
    expect(logs[0]).toBe(expectedVersion);
  });

  // --- Additional route coverage ---

  test("routes 'run' to runRun with extra args passed through", async () => {
    await route(["run", "--model", "opus"]);
    expect(mockRunRun).toHaveBeenCalledTimes(1);
    expect(mockRunRun).toHaveBeenCalledWith(["--model", "opus"]);
  });

  test("routes 'status' to runStatus", async () => {
    await route(["status"]);
    expect(mockRunStatus).toHaveBeenCalledTimes(1);
  });

  test("routes 'unpair' to runUnpair", async () => {
    await route(["unpair"]);
    expect(mockRunUnpair).toHaveBeenCalledTimes(1);
  });

  test("'-h' is an alias for --help", async () => {
    await route(["-h"]);
    const output = logs.join("\n");
    expect(output).toContain("Remmy");
  });

  test("'help' is an alias for --help", async () => {
    await route(["help"]);
    const output = logs.join("\n");
    expect(output).toContain("Remmy");
  });

  test("'-v' is an alias for --version", async () => {
    await route(["-v"]);
    expect(logs).toHaveLength(1);
    expect(logs[0]).toBe(expectedVersion);
  });

  test("--verbose sets the verbose flag", async () => {
    // Before: verbose is reset to false at start of route
    await route(["--verbose", "--help"]);
    expect(verbose).toBe(true);
  });

  test("--verbose is stripped before routing", async () => {
    await route(["--verbose", "setup"]);
    expect(mockRunSetup).toHaveBeenCalledTimes(1);
    expect(verbose).toBe(true);
  });

  test("--verbose works after command", async () => {
    await route(["run", "--verbose", "--model", "opus"]);
    expect(mockRunRun).toHaveBeenCalledTimes(1);
    // --verbose should be stripped from extra args
    expect(mockRunRun).toHaveBeenCalledWith(["--model", "opus"]);
    expect(verbose).toBe(true);
  });

  test("verbose resets to false on each route call", async () => {
    await route(["--verbose", "--help"]);
    expect(verbose).toBe(true);
    await route(["--help"]);
    expect(verbose).toBe(false);
  });
});
