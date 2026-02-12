import { describe, test, expect, beforeEach, afterEach, spyOn } from "bun:test";
import { Spinner } from "./spinner.ts";

describe("Spinner", () => {
  let writeSpy: ReturnType<typeof spyOn>;
  let written: string[];

  beforeEach(() => {
    written = [];
    writeSpy = spyOn(process.stdout, "write").mockImplementation((chunk: string | Uint8Array) => {
      written.push(String(chunk));
      return true;
    });
  });

  afterEach(() => {
    writeSpy.mockRestore();
  });

  test("succeed writes green checkmark", () => {
    const spinner = new Spinner();
    spinner.succeed("done");
    const output = written.join("");
    expect(output).toContain("\x1b[32m✓\x1b[0m");
    expect(output).toContain("done");
  });

  test("fail writes red cross", () => {
    const spinner = new Spinner();
    spinner.fail("failed");
    const output = written.join("");
    expect(output).toContain("\x1b[31m✗\x1b[0m");
    expect(output).toContain("failed");
  });

  test("succeed shows cursor after stopping", () => {
    const spinner = new Spinner();
    spinner.succeed("complete");
    const output = written.join("");
    expect(output).toContain("\x1b[?25h");
  });

  test("fail shows cursor after stopping", () => {
    const spinner = new Spinner();
    spinner.fail("error");
    const output = written.join("");
    expect(output).toContain("\x1b[?25h");
  });

  test("start hides cursor", () => {
    const spinner = new Spinner();
    spinner.start("loading");
    const output = written.join("");
    expect(output).toContain("\x1b[?25l");
    spinner.stop(); // clean up
  });

  test("stop clears line and shows cursor", () => {
    const spinner = new Spinner();
    spinner.start("loading");
    written = [];
    spinner.stop();
    const output = written.join("");
    expect(output).toContain("\r\x1b[K");
    expect(output).toContain("\x1b[?25h");
  });

  test("start clears previous timer on re-start", () => {
    const spinner = new Spinner();
    spinner.start("first");
    spinner.start("second");
    spinner.stop(); // should not throw, only one timer active
    // Verify cursor shown
    const output = written.join("");
    expect(output).toContain("\x1b[?25h");
  });
});
