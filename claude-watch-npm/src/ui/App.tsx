/**
 * App - Main Ink application component for cc-watch
 * Based on Happy Coder's SDK implementation patterns
 */

import React, { useState, useEffect, useCallback, useRef } from "react";
import { render } from "ink";
import { spawn, type ChildProcess } from "child_process";
import { createInterface } from "readline";
import * as fs from "fs";
import { TerminalUI, type WatchState, type PendingQuestion } from "./TerminalUI.js";
import { MessageBuffer } from "./MessageBuffer.js";

const LOG_PATH = "/tmp/cc-watch-debug.log";

function log(msg: string): void {
  fs.appendFileSync(LOG_PATH, `${new Date().toISOString()} ${msg}\n`);
}

interface AppProps {
  prompt: string;
  cloudUrl: string;
  pairingId: string;
  onComplete?: (exitCode: number) => void;
}

interface SDKMessage {
  type: string;
  subtype?: string;
  session_id?: string;
  message?: {
    content?: Array<{ type: string; text?: string; name?: string }>;
  };
  is_error?: boolean;
  result?: string;
  usage?: { input_tokens?: number; output_tokens?: number };
  request_id?: string;
  request?: {
    subtype?: string;
    tool_name?: string;
    input?: unknown;
  };
  [key: string]: unknown;
}

interface QuestionInput {
  questions?: Array<{
    question: string;
    header?: string;
    options: Array<{ label: string; description?: string }>;
    multiSelect?: boolean;
  }>;
}

export const App: React.FC<AppProps> = ({ prompt, cloudUrl, pairingId }) => {
  const [messageBuffer] = useState(() => new MessageBuffer());
  const [watchState, setWatchState] = useState<WatchState>({
    connected: true,
    pendingQuestion: null,
    pendingApprovals: 0,
  });
  const [tokenCount, setTokenCount] = useState({ input: 0, output: 0 });
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const childRef = useRef<ChildProcess | null>(null);
  const rlRef = useRef<ReturnType<typeof createInterface> | null>(null);
  const abortControllerRef = useRef(new AbortController());
  const startTimeRef = useRef(Date.now());
  const questionResolverRef = useRef<((indices: number[]) => void) | null>(null);

  // Elapsed time counter
  useEffect(() => {
    const timer = setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - startTimeRef.current) / 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Handle exit - aggressive cleanup
  const handleExit = useCallback(() => {
    log("[EXIT] User requested exit");
    abortControllerRef.current.abort();

    // Close readline to unblock event loop
    if (rlRef.current) {
      rlRef.current.close();
      rlRef.current = null;
    }

    // Kill child process aggressively
    if (childRef.current && !childRef.current.killed) {
      childRef.current.kill("SIGKILL");
    }

    // Force exit after brief delay
    setTimeout(() => {
      log("[EXIT] Force exit after timeout");
      process.exit(130);
    }, 100);

    process.exit(130);
  }, []);

  // Handle interrupt
  const handleInterrupt = useCallback(() => {
    log("[INTERRUPT] User requested interrupt");
    if (childRef.current?.stdin) {
      childRef.current.stdin.write(JSON.stringify({
        type: "control_request",
        request_id: `interrupt-${Date.now()}`,
        request: { subtype: "interrupt" }
      }) + "\n");
    }
  }, []);

  // Handle question answer from terminal UI
  const handleQuestionAnswer = useCallback((questionId: string, selectedIndices: number[]) => {
    log(`[ANSWER] Terminal answer for ${questionId}: ${selectedIndices}`);
    if (questionResolverRef.current) {
      questionResolverRef.current(selectedIndices);
      questionResolverRef.current = null;
    }
    setWatchState((prev) => ({ ...prev, pendingQuestion: null }));
  }, []);

  // Process SDK message for display
  const processMessage = useCallback(
    (message: SDKMessage) => {
      if (message.type === "assistant" && message.message?.content) {
        for (const block of message.message.content) {
          if (block.type === "text" && block.text) {
            messageBuffer.addMessage(block.text, "assistant");
          } else if (block.type === "tool_use" && block.name) {
            messageBuffer.addMessage(`[Using tool: ${block.name}]`, "tool");
          }
        }
      } else if (message.type === "result") {
        if (message.is_error) {
          messageBuffer.addMessage(`Error: ${message.result || "Unknown error"}`, "status");
        } else {
          messageBuffer.addMessage(message.result || "Task completed", "result");
        }
        if (message.usage) {
          setTokenCount({
            input: message.usage.input_tokens || 0,
            output: message.usage.output_tokens || 0,
          });
        }
        // Close stdin to signal we're done - Claude will exit
        if (childRef.current?.stdin && !childRef.current.stdin.destroyed) {
          log("[RESULT] Closing stdin to signal completion");
          childRef.current.stdin.end();

          // Give Claude 2 seconds to exit gracefully, then force kill
          const proc = childRef.current;
          setTimeout(() => {
            if (proc && !proc.killed) {
              log("[RESULT] Force killing after timeout");
              proc.kill("SIGKILL");
            }
          }, 2000);
        }
      } else if (message.type === "system") {
        const content = (message as { content?: string }).content;
        if (content) {
          messageBuffer.addMessage(content, "system");
        }
      }
    },
    [messageBuffer]
  );

  // Handle control_request for tool permissions
  const handleControlRequest = useCallback(
    async (message: SDKMessage, writeResponse: (response: object) => void) => {
      const requestId = message.request_id;
      const request = message.request;

      if (!requestId || !request) return;

      log(`[CONTROL] request_id=${requestId} subtype=${request.subtype} tool=${request.tool_name}`);

      if (request.subtype === "can_use_tool" && request.tool_name === "AskUserQuestion") {
        // Handle question - route to watch first, then terminal fallback
        const input = request.input as QuestionInput;
        const questions = input?.questions || [];

        if (questions.length > 0) {
          const q = questions[0];
          const answer = await new Promise<number[]>((resolve) => {
            questionResolverRef.current = resolve;

            // Create pending question state
            const pendingQuestion: PendingQuestion = {
              id: requestId,
              question: q.question,
              options: q.options,
              multiSelect: q.multiSelect || false,
              waitingForWatch: true,
              timeoutSeconds: 30,
            };

            setWatchState((prev) => ({ ...prev, pendingQuestion }));

            // Countdown timer
            const countdownInterval = setInterval(() => {
              setWatchState((prev) => {
                if (prev.pendingQuestion && prev.pendingQuestion.waitingForWatch) {
                  const newTimeout = prev.pendingQuestion.timeoutSeconds - 1;
                  if (newTimeout <= 0) {
                    return {
                      ...prev,
                      pendingQuestion: { ...prev.pendingQuestion, waitingForWatch: false, timeoutSeconds: 0 },
                    };
                  }
                  return {
                    ...prev,
                    pendingQuestion: { ...prev.pendingQuestion, timeoutSeconds: newTimeout },
                  };
                }
                return prev;
              });
            }, 1000);

            // Send to watch and poll for answer
            pollWatchForAnswer(requestId, cloudUrl, pairingId, {
              question: q.question,
              options: q.options,
              multiSelect: q.multiSelect || false,
              header: q.header,
            }, 30000)
              .then((watchAnswer) => {
                clearInterval(countdownInterval);
                if (watchAnswer !== null && questionResolverRef.current) {
                  log(`[WATCH] Got answer from watch: ${watchAnswer}`);
                  questionResolverRef.current(watchAnswer);
                  questionResolverRef.current = null;
                  setWatchState((prev) => ({ ...prev, pendingQuestion: null }));
                }
              })
              .catch((err) => {
                clearInterval(countdownInterval);
                log(`[WATCH] Error: ${err}`);
                messageBuffer.addMessage("Watch timeout - please answer in terminal", "status");
              });
          });

          // Send response back to Claude
          const selectedLabels = answer.map((i) => q.options[i]?.label || "").filter(Boolean);
          const answers: Record<string, string> = { [q.question]: selectedLabels.join(", ") };

          writeResponse({
            type: "control_response",
            response: {
              subtype: "success",
              request_id: requestId,
              response: {
                behavior: "allow",
                updatedInput: { ...input, answers },
              },
            },
          });
        }
      } else {
        // Auto-approve other tools
        log(`[CONTROL] Auto-approving tool: ${request.tool_name}`);
        writeResponse({
          type: "control_response",
          response: {
            subtype: "success",
            request_id: requestId,
            response: { behavior: "allow" },
          },
        });
      }
    },
    [cloudUrl, pairingId, messageBuffer]
  );

  // Start Claude process
  useEffect(() => {
    fs.writeFileSync(LOG_PATH, `--- Session started ${new Date().toISOString()} ---\n`);
    log(`[START] prompt="${prompt.slice(0, 50)}..."`);

    const args = [
      "--output-format", "stream-json",
      "--input-format", "stream-json",
      "--permission-prompt-tool", "stdio",
      "--permission-mode", "default",
      "--verbose",
    ];

    const child = spawn("claude", args, {
      stdio: ["pipe", "pipe", "pipe"],
      shell: true,
      signal: abortControllerRef.current.signal,
      env: { ...process.env },
    });
    childRef.current = child;
    setGlobalChild(child);  // Store for SIGINT cleanup

    // Write response helper
    const writeResponse = (response: object): void => {
      if (child.stdin && !child.stdin.destroyed) {
        const json = JSON.stringify(response);
        log(`[SEND] ${json.slice(0, 200)}`);
        child.stdin.write(json + "\n");
      }
    };

    // Read messages from stdout
    const rl = createInterface({ input: child.stdout! });
    rlRef.current = rl;  // Store for cleanup

    rl.on("line", async (line) => {
      if (!line.trim()) return;
      try {
        const message = JSON.parse(line) as SDKMessage;
        log(`[RECV] type=${message.type} ${JSON.stringify(message).slice(0, 150)}`);

        if (message.type === "control_request") {
          await handleControlRequest(message, writeResponse);
        } else {
          processMessage(message);
        }
      } catch {
        log(`[PARSE_ERROR] ${line.slice(0, 100)}`);
      }
    });

    // Handle stderr
    child.stderr?.on("data", (data: Buffer) => {
      log(`[STDERR] ${data.toString().slice(0, 200)}`);
    });

    // Send initial prompt after small delay
    setTimeout(() => {
      writeResponse({
        type: "user",
        message: { role: "user", content: prompt },
      });
    }, 200);

    // Handle process exit
    child.on("close", (code) => {
      log(`[EXIT] Claude exited with code ${code}`);
      process.exit(code ?? 0);
    });

    child.on("error", (err) => {
      log(`[ERROR] Spawn error: ${err.message}`);
      process.exit(1);
    });

    // Cleanup
    return () => {
      rl.close();
      rlRef.current = null;
      if (child && !child.killed) {
        child.kill("SIGKILL");
      }
    };
  }, [prompt, handleControlRequest, processMessage]);

  return (
    <TerminalUI
      messageBuffer={messageBuffer}
      watchState={watchState}
      onExit={handleExit}
      onInterrupt={handleInterrupt}
      onQuestionAnswer={handleQuestionAnswer}
      tokenCount={tokenCount}
      elapsedSeconds={elapsedSeconds}
    />
  );
};

/**
 * Poll watch for answer via cloud endpoint
 */
async function pollWatchForAnswer(
  questionId: string,
  cloudUrl: string,
  pairingId: string,
  questionData: {
    question: string;
    options: Array<{ label: string; description?: string }>;
    multiSelect: boolean;
    header?: string;
  },
  timeoutMs: number
): Promise<number[] | null> {
  const startTime = Date.now();

  // Send question to watch
  try {
    log(`[WATCH] Sending question to ${cloudUrl}/question`);
    const response = await fetch(`${cloudUrl}/question`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        id: questionId,
        pairingId,
        question: questionData.question,
        header: questionData.header || "Question",
        options: questionData.options.map((opt) => ({
          label: opt.label,
          description: opt.description || "",
        })),
        multiSelect: questionData.multiSelect,
      }),
    });
    log(`[WATCH] POST /question status=${response.status}`);
    if (!response.ok) {
      const text = await response.text();
      log(`[WATCH] POST error: ${text}`);
    }
  } catch (error) {
    log(`[WATCH] Failed to send question: ${error}`);
    return null;
  }

  // Poll for answer
  while (Date.now() - startTime < timeoutMs) {
    try {
      const response = await fetch(`${cloudUrl}/question/${questionId}`);
      if (response.ok) {
        const data = (await response.json()) as {
          status: string;
          selectedIndices?: number[];
        };
        if (data.status === "answered" && data.selectedIndices) {
          return data.selectedIndices;
        }
        if (data.status === "skipped") {
          return null;
        }
      }
    } catch {
      // Continue polling
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }

  return null;
}

// Store child process reference globally for cleanup
let globalChild: ChildProcess | null = null;

/**
 * Render the cc-watch app
 */
export function renderApp(props: AppProps): void {
  log("[RENDER] Starting renderApp");

  // Cleanup function
  const cleanup = () => {
    log("[CLEANUP] Running cleanup");
    if (globalChild && !globalChild.killed) {
      log("[CLEANUP] Killing child process");
      globalChild.kill("SIGKILL");
    }
  };

  // Register cleanup handlers
  process.on("exit", cleanup);
  process.on("SIGINT", () => {
    log("[SIGINT] Received, cleaning up");
    cleanup();
    process.exit(130);
  });
  process.on("SIGTERM", () => {
    log("[SIGTERM] Received, cleaning up");
    cleanup();
    process.exit(143);
  });

  // Let Ink handle Ctrl+C - it will call process.exit() which triggers our cleanup
  const instance = render(<App {...props} />, {
    exitOnCtrlC: true,
  });

  log("[RENDER] Ink render started");
}

// Export setter for child process
export function setGlobalChild(child: ChildProcess): void {
  globalChild = child;
}
