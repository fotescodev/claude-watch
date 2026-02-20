import { describe, test, expect, mock, spyOn } from "bun:test";

// We mock readline.createInterface to avoid real stdin/stdout interaction
// The approach: mock the module, control what "question" returns

function createMockReadline(answers: (string | null)[]) {
  let answerIndex = 0;
  return {
    question: (_prompt: string, callback: (answer: string) => void) => {
      const answer = answers[answerIndex++] ?? null;
      if (answer === null) {
        // Simulate close (Ctrl+C/Ctrl+D)
        return;
      }
      // Use queueMicrotask to simulate async behavior
      queueMicrotask(() => callback(answer));
    },
    once: (event: string, callback: () => void) => {
      const answer = answers[answerIndex - 1];
      if (event === "close" && answer === null) {
        queueMicrotask(() => callback());
      }
    },
    close: () => {},
  };
}

// Mock readline module
const mockCreateInterface = mock();

mock.module("node:readline", () => ({
  createInterface: mockCreateInterface,
}));

// Import after mocking
const { askText, askConfirm } = await import("./prompt.ts");

describe("askText", () => {
  test("returns user input", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["hello world"]));
    const result = await askText("Enter text: ");
    expect(result).toBe("hello world");
  });

  test("returns null on close (Ctrl+C)", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline([null]));
    const result = await askText("Enter text: ");
    expect(result).toBeNull();
  });

  test("re-prompts on validation failure then accepts valid input", async () => {
    const writeOutput: string[] = [];
    const writeSpy = spyOn(process.stdout, "write").mockImplementation((chunk: string | Uint8Array) => {
      writeOutput.push(String(chunk));
      return true;
    });

    // First answer fails validation, second passes
    let callCount = 0;
    const rl = {
      question: (_prompt: string, callback: (answer: string) => void) => {
        callCount++;
        if (callCount === 1) {
          queueMicrotask(() => callback(""));
        } else {
          queueMicrotask(() => callback("valid"));
        }
      },
      once: () => {},
      close: () => {},
    };
    mockCreateInterface.mockReturnValueOnce(rl);

    const validate = (input: string) => {
      if (input.length === 0) return "Cannot be empty";
      return true as const;
    };

    const result = await askText("Name: ", validate);
    expect(result).toBe("valid");
    expect(writeOutput.some((s) => s.includes("Cannot be empty"))).toBe(true);

    writeSpy.mockRestore();
  });
});

describe("askConfirm", () => {
  test("returns true for 'y'", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["y"]));
    const result = await askConfirm("Continue?");
    expect(result).toBe(true);
  });

  test("returns true for 'yes'", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["yes"]));
    const result = await askConfirm("Continue?");
    expect(result).toBe(true);
  });

  test("returns false for 'n'", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["n"]));
    const result = await askConfirm("Continue?");
    expect(result).toBe(false);
  });

  test("returns false for 'no'", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["no"]));
    const result = await askConfirm("Continue?");
    expect(result).toBe(false);
  });

  test("returns default value on empty input", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline([""]));
    const result = await askConfirm("Continue?", true);
    expect(result).toBe(true);
  });

  test("returns false default on empty input", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline([""]));
    const result = await askConfirm("Continue?", false);
    expect(result).toBe(false);
  });

  test("returns null on close (Ctrl+C)", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline([null]));
    const result = await askConfirm("Continue?");
    expect(result).toBeNull();
  });

  test("uses default for unrecognized input", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["maybe"]));
    const result = await askConfirm("Continue?", true);
    expect(result).toBe(true);
  });

  test("returns false for unrecognized input with no default", async () => {
    mockCreateInterface.mockReturnValueOnce(createMockReadline(["maybe"]));
    const result = await askConfirm("Continue?");
    expect(result).toBe(false);
  });
});
