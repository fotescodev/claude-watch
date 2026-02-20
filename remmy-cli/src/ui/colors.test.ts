import { describe, test, expect, beforeEach, afterEach } from "bun:test";
import { red, green, yellow, blue, cyan, white, dim, bold } from "./colors.ts";

describe("colors", () => {
  let originalNoColor: string | undefined;
  let originalIsTTY: boolean;

  beforeEach(() => {
    originalNoColor = process.env.NO_COLOR;
    originalIsTTY = process.stdout.isTTY;
    // Enable colors for most tests
    delete process.env.NO_COLOR;
    Object.defineProperty(process.stdout, "isTTY", { value: true, writable: true, configurable: true });
  });

  afterEach(() => {
    if (originalNoColor !== undefined) {
      process.env.NO_COLOR = originalNoColor;
    } else {
      delete process.env.NO_COLOR;
    }
    Object.defineProperty(process.stdout, "isTTY", { value: originalIsTTY, writable: true, configurable: true });
  });

  describe("ANSI escape codes", () => {
    test("red wraps text with code 31", () => {
      expect(red("error")).toBe("\x1b[31merror\x1b[0m");
    });

    test("green wraps text with code 32", () => {
      expect(green("success")).toBe("\x1b[32msuccess\x1b[0m");
    });

    test("yellow wraps text with code 33", () => {
      expect(yellow("warning")).toBe("\x1b[33mwarning\x1b[0m");
    });

    test("blue wraps text with code 34", () => {
      expect(blue("info")).toBe("\x1b[34minfo\x1b[0m");
    });

    test("cyan wraps text with code 36", () => {
      expect(cyan("highlight")).toBe("\x1b[36mhighlight\x1b[0m");
    });

    test("white wraps text with code 37", () => {
      expect(white("text")).toBe("\x1b[37mtext\x1b[0m");
    });

    test("dim wraps text with code 2", () => {
      expect(dim("faded")).toBe("\x1b[2mfaded\x1b[0m");
    });

    test("bold wraps text with code 1", () => {
      expect(bold("strong")).toBe("\x1b[1mstrong\x1b[0m");
    });

    test("handles empty string", () => {
      expect(red("")).toBe("\x1b[31m\x1b[0m");
    });

    test("handles text with spaces", () => {
      expect(green("hello world")).toBe("\x1b[32mhello world\x1b[0m");
    });
  });

  describe("NO_COLOR environment variable", () => {
    test("returns unformatted text when NO_COLOR is set", () => {
      process.env.NO_COLOR = "";
      expect(red("error")).toBe("error");
      expect(green("success")).toBe("success");
      expect(bold("strong")).toBe("strong");
    });

    test("returns unformatted text when NO_COLOR is set to any value", () => {
      process.env.NO_COLOR = "1";
      expect(cyan("text")).toBe("text");
      expect(dim("text")).toBe("text");
    });
  });

  describe("non-TTY mode", () => {
    test("returns unformatted text when stdout is not a TTY", () => {
      Object.defineProperty(process.stdout, "isTTY", { value: false, writable: true, configurable: true });
      expect(red("error")).toBe("error");
      expect(green("success")).toBe("success");
      expect(yellow("warning")).toBe("warning");
      expect(bold("strong")).toBe("strong");
      expect(dim("faded")).toBe("faded");
    });

    test("returns unformatted text when isTTY is undefined", () => {
      Object.defineProperty(process.stdout, "isTTY", { value: undefined, writable: true, configurable: true });
      expect(red("error")).toBe("error");
      expect(cyan("highlight")).toBe("highlight");
    });
  });
});
