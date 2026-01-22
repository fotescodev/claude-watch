import { describe, it } from "node:test";
import assert from "node:assert";

/**
 * Test the question parsing logic from stdin-proxy.ts
 *
 * Claude's interactive question UI format:
 * - Header line with checkbox and title
 * - Question text (can be multi-line)
 * - Numbered options with ❯ for selected
 * - Footer with "Enter to select"
 */

// Simulated Claude question output (based on real screenshot)
const SAMPLE_QUESTION_OUTPUT = `
❯ Problem

What problem did you recently solve that you'd like to document?
Please describe the issue and its solution briefly.

❯ 1. From current session
     Document a problem we just solved in this conversation
  2. From recent work
     Document a problem solved in a previous session that I should
     investigate
  3. Describe manually
     I'll provide the problem details directly
  4. Type something.

────────────────────────────────────────────────────────────────────

  Chat about this

Enter to select · ↑/↓ to navigate · Esc to cancel
`;

// Another example with different header
const SAMPLE_QUESTION_OUTPUT_2 = `
❯ Auth method

Which authentication method should we use?

❯ 1. OAuth 2.0
     Industry standard, supports social login
  2. JWT tokens
     Stateless, good for APIs
  3. Session cookies
     Traditional, simpler setup

Enter to select · ↑/↓ to navigate · Esc to cancel
`;

// Simpler format sometimes seen
const SAMPLE_QUESTION_OUTPUT_3 = `
? Which framework do you prefer?

  1. React
  2. Vue
  3. Angular
  4. Other

>
`;

/**
 * Parse question from Claude's stdout - copy of logic from stdin-proxy.ts
 */
function parseQuestion(
  buffer: string
): { text: string; options: string[]; header?: string; multiSelect: boolean } | null {
  const normalized = buffer
    .replace(/\x1b\[[0-9;]*[A-Za-z]/g, "")
    .replace(/\r\n/g, "\n");
  // Check for prompt indicators
  const hasInteractivePrompt =
    /enter to select|use .*arrow|esc to cancel|press enter|return to select/i.test(normalized) ||
    /\n>\s*$/.test(normalized);

  if (!hasInteractivePrompt) {
    const headerMatch = normalized.match(/[❯?]\s*([^\n]+?)\s*\n/);
    if (!headerMatch) {
      return null;
    }
  }

  // Try to extract header (line starting with ❯ followed by a word, or ? for simple format)
  const headerMatch = normalized.match(/[❯?]\s*([^\n]+?)\s*\n/);
  const header = headerMatch ? headerMatch[1].trim() : "Question";

  // Extract question text
  let questionText = "Question from Claude";

  // For ? format: the header line IS the question
  if (header && header.includes("?")) {
    questionText = header;
  } else {
    // For ❯ format: text is between header and first numbered option
    const questionMatch = normalized.match(/[❯]\s*[^\n]+\s*\n\n?([\s\S]*?)\n\s*[❯>\s]*1\./);
    if (questionMatch) {
      questionText = questionMatch[1].trim().replace(/\s+/g, ' ');
    }
  }

  // Extract options - lines with "❯ N." or "  N." or just "N." pattern
  const optionRegex = /[❯>\s]*(\d+)\.\s+([^\n]+)/g;
  const options: string[] = [];
  let optMatch;

  while ((optMatch = optionRegex.exec(normalized)) !== null) {
    const label = optMatch[2].trim();
    // Skip description lines (they're indented more and follow an option)
    if (label && !label.match(/^\s{4,}/)) {
      options.push(label);
    }
  }

  if (options.length < 2) {
    return null;
  }

  const multiSelect = /\[[ xX]\]|☐|☑|◻|◼/.test(normalized);

  return { text: questionText, options, header, multiSelect };
}

describe("Question Parsing", () => {
  it("should parse the Problem question format", () => {
    const result = parseQuestion(SAMPLE_QUESTION_OUTPUT);

    assert.ok(result, "Should parse the question");
    assert.strictEqual(result.header, "Problem");
    assert.ok(result.text.includes("problem did you recently solve"), `Text should contain question: ${result.text}`);
    assert.strictEqual(result.options.length, 4, `Should have 4 options, got: ${result.options}`);
    assert.strictEqual(result.options[0], "From current session");
    assert.strictEqual(result.options[1], "From recent work");
    assert.strictEqual(result.options[2], "Describe manually");
    assert.strictEqual(result.options[3], "Type something.");
    assert.strictEqual(result.multiSelect, false);
  });

  it("should parse the Auth method question format", () => {
    const result = parseQuestion(SAMPLE_QUESTION_OUTPUT_2);

    assert.ok(result, "Should parse the question");
    assert.strictEqual(result.header, "Auth method");
    assert.ok(result.text.includes("authentication method"), `Text should contain question: ${result.text}`);
    assert.strictEqual(result.options.length, 3);
    assert.strictEqual(result.options[0], "OAuth 2.0");
    assert.strictEqual(result.options[1], "JWT tokens");
    assert.strictEqual(result.options[2], "Session cookies");
    assert.strictEqual(result.multiSelect, false);
  });

  it("should parse the simple ? format", () => {
    const result = parseQuestion(SAMPLE_QUESTION_OUTPUT_3);

    assert.ok(result, "Should parse the question");
    // In simple format, the header line IS the question
    assert.ok(
      result.text.includes("framework") || result.header?.includes("framework"),
      `Text or header should contain question: text=${result.text}, header=${result.header}`
    );
    assert.strictEqual(result.options.length, 4);
    assert.strictEqual(result.options[0], "React");
    assert.strictEqual(result.options[1], "Vue");
    assert.strictEqual(result.options[2], "Angular");
    assert.strictEqual(result.options[3], "Other");
    assert.strictEqual(result.multiSelect, false);
  });

  it("should detect checkbox prompts as multi-select", () => {
    const result = parseQuestion(`
☐ Phase

Choose a phase:

❯ 1. Phase 6
  2. Phase 8
  3. Other

Enter to select
`);

    assert.ok(result, "Should parse the question");
    assert.strictEqual(result.multiSelect, true);
  });

  it("should return null for non-question output", () => {
    const result = parseQuestion("Just some regular output\nwith multiple lines\n");
    assert.strictEqual(result, null);
  });

  it("should return null for output without enough options", () => {
    const result = parseQuestion(`
❯ Header

Question?

❯ 1. Only one option

Enter to select
`);
    assert.strictEqual(result, null);
  });
});

// Run tests
console.log("Running stdin-proxy tests...\n");
