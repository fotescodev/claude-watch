// Readline-based prompts — zero dependencies
// Returns null on Ctrl+C / Ctrl+D (closed input)

import * as readline from "node:readline";

export async function askText(
  question: string,
  validate?: (input: string) => true | string,
): Promise<string | null> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    // eslint-disable-next-line no-constant-condition
    while (true) {
      const answer = await new Promise<string | null>((resolve) => {
        rl.question(question, (ans) => resolve(ans));
        rl.once("close", () => resolve(null));
      });

      if (answer === null) return null;

      if (validate) {
        const result = validate(answer);
        if (result !== true) {
          // result is the error message string
          process.stdout.write(`${result}\n`);
          continue;
        }
      }

      return answer;
    }
  } finally {
    rl.close();
  }
}

export async function askConfirm(
  question: string,
  defaultValue?: boolean,
): Promise<boolean | null> {
  const hint =
    defaultValue === true
      ? "(Y/n)"
      : defaultValue === false
        ? "(y/N)"
        : "(y/n)";

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    const answer = await new Promise<string | null>((resolve) => {
      rl.question(`${question} ${hint} `, (ans) => resolve(ans));
      rl.once("close", () => resolve(null));
    });

    if (answer === null) return null;

    const trimmed = answer.trim().toLowerCase();

    if (trimmed === "" && defaultValue !== undefined) {
      return defaultValue;
    }

    if (trimmed === "y" || trimmed === "yes") return true;
    if (trimmed === "n" || trimmed === "no") return false;

    // Unrecognized input: use default if available, otherwise false
    if (defaultValue !== undefined) return defaultValue;
    return false;
  } finally {
    rl.close();
  }
}
