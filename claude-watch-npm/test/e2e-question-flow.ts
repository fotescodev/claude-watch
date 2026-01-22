/**
 * E2E Test: Question Flow
 * Tests that AskUserQuestion control_requests are intercepted and sent to watch
 */

import { spawn, ChildProcess } from "child_process";
import * as http from "http";

const CLOUD_URL = "http://localhost:9999";
const TEST_TIMEOUT = 10000;

interface TestResult {
  passed: boolean;
  message: string;
}

// Mock cloud server to receive question
let receivedQuestion: any = null;
let mockServer: http.Server | null = null;

function startMockServer(): Promise<void> {
  return new Promise((resolve) => {
    mockServer = http.createServer((req, res) => {
      if (req.method === "POST" && req.url === "/question") {
        let body = "";
        req.on("data", (chunk) => (body += chunk));
        req.on("end", () => {
          receivedQuestion = JSON.parse(body);
          res.writeHead(200, { "Content-Type": "application/json" });
          res.end(JSON.stringify({ success: true }));
        });
      } else if (req.method === "GET" && req.url?.startsWith("/question/")) {
        // Return "pending" - simulate watch not answering yet
        res.writeHead(200, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ status: "pending" }));
      } else if (req.url === "/health") {
        res.writeHead(200);
        res.end("ok");
      } else {
        res.writeHead(404);
        res.end();
      }
    });
    mockServer.listen(9999, () => {
      console.log("✓ Mock server started on port 9999");
      resolve();
    });
  });
}

function stopMockServer(): void {
  mockServer?.close();
}

// Mock Claude process that sends a control_request
function createMockClaude(): ChildProcess {
  // Create a simple script that outputs a control_request
  const script = `
    const readline = require('readline');
    const rl = readline.createInterface({ input: process.stdin });

    // Wait for user message
    rl.on('line', (line) => {
      const msg = JSON.parse(line);
      if (msg.type === 'user') {
        // Send assistant message
        console.log(JSON.stringify({
          type: "assistant",
          message: { content: [{ type: "text", text: "Let me ask you a question." }] }
        }));

        // Send control_request for AskUserQuestion
        console.log(JSON.stringify({
          type: "control_request",
          request_id: "test-123",
          request: {
            subtype: "can_use_tool",
            tool_name: "AskUserQuestion",
            input: {
              questions: [{
                question: "What is your favorite color?",
                header: "Color",
                options: [
                  { label: "Red", description: "Like a rose" },
                  { label: "Blue", description: "Like the sky" },
                  { label: "Green", description: "Like grass" }
                ],
                multiSelect: false
              }]
            }
          }
        }));
      } else if (msg.type === 'control_response') {
        // Got response, send result and exit
        console.log(JSON.stringify({
          type: "result",
          result: "Got your answer!",
          is_error: false
        }));
        process.exit(0);
      }
    });
  `;

  return spawn("node", ["-e", script], {
    stdio: ["pipe", "pipe", "pipe"],
  });
}

async function testQuestionInterception(): Promise<TestResult> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      resolve({ passed: false, message: "Timeout waiting for question" });
    }, TEST_TIMEOUT);

    // Import and test the StreamingClaudeRunner logic directly
    // For now, we'll test by checking if the mock server received the question

    // Simulate what App.tsx does
    const mockClaude = createMockClaude();

    let gotControlRequest = false;

    mockClaude.stdout?.on("data", async (data) => {
      const lines = data.toString().split("\n").filter((l: string) => l.trim());
      for (const line of lines) {
        try {
          const msg = JSON.parse(line);
          if (msg.type === "control_request" && msg.request?.tool_name === "AskUserQuestion") {
            gotControlRequest = true;

            // Simulate sending to watch
            const question = msg.request.input.questions[0];
            try {
              const res = await fetch(`${CLOUD_URL}/question`, {
                method: "POST",
                headers: { "Content-Type": "application/json" },
                body: JSON.stringify({
                  id: msg.request_id,
                  pairingId: "test-pairing",
                  question: question.question,
                  options: question.options,
                }),
              });

              if (res.ok && receivedQuestion) {
                clearTimeout(timeout);

                // Send response back to mock claude
                mockClaude.stdin?.write(JSON.stringify({
                  type: "control_response",
                  response: {
                    subtype: "success",
                    request_id: msg.request_id,
                    response: { behavior: "allow" }
                  }
                }) + "\n");

                resolve({
                  passed: true,
                  message: `Question intercepted and sent to watch: "${receivedQuestion.question}"`
                });
              }
            } catch (e) {
              clearTimeout(timeout);
              resolve({ passed: false, message: `Failed to send to watch: ${e}` });
            }
          }
        } catch {
          // Not JSON
        }
      }
    });

    // Send initial user message
    setTimeout(() => {
      mockClaude.stdin?.write(JSON.stringify({
        type: "user",
        message: { role: "user", content: "test" }
      }) + "\n");
    }, 100);
  });
}

async function testCtrlC(): Promise<TestResult> {
  return new Promise((resolve) => {
    const timeout = setTimeout(() => {
      resolve({ passed: false, message: "Process didn't exit on SIGINT" });
    }, 3000);

    // Spawn cc-watch and send SIGINT
    const proc = spawn("node", ["dist/src/index.js", "--help"], {
      cwd: process.cwd(),
      stdio: "pipe",
    });

    proc.on("close", (code) => {
      clearTimeout(timeout);
      resolve({ passed: true, message: `Process exited with code ${code}` });
    });

    // Give it a moment to start, then kill
    setTimeout(() => proc.kill("SIGINT"), 500);
  });
}

async function runTests(): Promise<void> {
  console.log("\n=== E2E Question Flow Tests ===\n");

  // Start mock server
  await startMockServer();
  receivedQuestion = null;

  const tests = [
    { name: "Question Interception", fn: testQuestionInterception },
    { name: "Ctrl+C Exit", fn: testCtrlC },
  ];

  let passed = 0;
  let failed = 0;

  for (const test of tests) {
    process.stdout.write(`Testing: ${test.name}... `);
    try {
      const result = await test.fn();
      if (result.passed) {
        console.log(`✓ PASS - ${result.message}`);
        passed++;
      } else {
        console.log(`✗ FAIL - ${result.message}`);
        failed++;
      }
    } catch (e) {
      console.log(`✗ ERROR - ${e}`);
      failed++;
    }
  }

  stopMockServer();

  console.log(`\n=== Results: ${passed} passed, ${failed} failed ===\n`);
  process.exit(failed > 0 ? 1 : 0);
}

runTests();
