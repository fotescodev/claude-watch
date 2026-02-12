import { describe, test, expect, beforeEach, afterEach, spyOn } from "bun:test";

describe("showHeader", () => {
  let writeSpy: ReturnType<typeof spyOn>;
  let written: string[];
  let originalNoColor: string | undefined;
  let originalIsTTY: boolean;

  beforeEach(() => {
    written = [];
    writeSpy = spyOn(process.stdout, "write").mockImplementation((chunk: string | Uint8Array) => {
      written.push(String(chunk));
      return true;
    });
    // Enable colors so we test real output
    originalNoColor = process.env.NO_COLOR;
    originalIsTTY = process.stdout.isTTY;
    delete process.env.NO_COLOR;
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true, configurable: true });
  });

  afterEach(() => {
    writeSpy.mockRestore();
    if (originalNoColor !== undefined) {
      process.env.NO_COLOR = originalNoColor;
    } else {
      delete process.env.NO_COLOR;
    }
    Object.defineProperty(process.stdout, "isTTY", { value: originalIsTTY, writable: true, configurable: true });
  });

  test("output contains 'remmy'", async () => {
    // Dynamic import to pick up mocked env
    const { showHeader } = await import("./header.ts");
    showHeader();
    const output = written.join("");
    expect(output).toContain("remmy");
  });

  test("output includes version when provided", async () => {
    const { showHeader } = await import("./header.ts");
    showHeader("1.2.3");
    const output = written.join("");
    expect(output).toContain("remmy");
    expect(output).toContain("1.2.3");
  });

  test("output does not include version line when not provided", async () => {
    const { showHeader } = await import("./header.ts");
    showHeader();
    const output = written.join("");
    expect(output).toContain("remmy");
    // Should not have "v" prefix for version
    expect(output).not.toContain("vundefined");
  });

  test("applies cyan and bold formatting to remmy text", async () => {
    const { showHeader } = await import("./header.ts");
    showHeader();
    const output = written.join("");
    // Should contain ANSI codes for cyan (36) and bold (1)
    expect(output).toContain("\x1b[36m");
    expect(output).toContain("\x1b[1m");
  });

  test("applies dim formatting to version", async () => {
    const { showHeader } = await import("./header.ts");
    showHeader("0.1.0");
    const output = written.join("");
    // Should contain ANSI code for dim (2)
    expect(output).toContain("\x1b[2m");
    expect(output).toContain("v0.1.0");
  });
});
