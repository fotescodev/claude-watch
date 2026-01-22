/**
 * App - Main Ink application component for cc-watch
 * Integrates StreamingClaudeRunner with TerminalUI
 */

import React, { useState, useEffect, useCallback, useRef } from "react";
import { render } from "ink";
import { TerminalUI, type WatchState, type PendingQuestion } from "./TerminalUI.js";
import { MessageBuffer } from "./MessageBuffer.js";

interface AppProps {
  prompt: string;
  cloudUrl: string;
  pairingId: string;
  onComplete?: (exitCode: number) => void;
}

interface SDKMessage {
  type: string;
  message?: {
    content?: Array<{ type: string; text?: string; name?: string }>;
  };
  is_error?: boolean;
  result?: string;
  usage?: { input_tokens?: number; output_tokens?: number };
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

export const App: React.FC<AppProps> = ({ prompt, cloudUrl, pairingId, onComplete }) => {
  const [messageBuffer] = useState(() => new MessageBuffer());
  const [watchState, setWatchState] = useState<WatchState>({
    connected: true, // Assume connected initially
    pendingQuestion: null,
    pendingApprovals: 0,
  });
  const [tokenCount, setTokenCount] = useState({ input: 0, output: 0 });
  const [elapsedSeconds, setElapsedSeconds] = useState(0);
  const runnerRef = useRef<StreamingClaudeRunnerInternal | null>(null);
  const startTimeRef = useRef(Date.now());
  const questionResolverRef = useRef<((indices: number[]) => void) | null>(null);

  // Elapsed time counter
  useEffect(() => {
    const timer = setInterval(() => {
      setElapsedSeconds(Math.floor((Date.now() - startTimeRef.current) / 1000));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  // Handle exit
  const handleExit = useCallback(() => {
    runnerRef.current?.kill();
    onComplete?.(130); // SIGINT exit code
  }, [onComplete]);

  // Handle interrupt
  const handleInterrupt = useCallback(() => {
    runnerRef.current?.interrupt();
  }, []);

  // Handle question answer from terminal UI
  const handleQuestionAnswer = useCallback((questionId: string, selectedIndices: number[]) => {
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
      } else if (message.type === "system") {
        const content = (message as { content?: string }).content;
        if (content) {
          messageBuffer.addMessage(content, "system");
        }
      }
    },
    [messageBuffer]
  );

  // Start the runner
  useEffect(() => {
    const runner = new StreamingClaudeRunnerInternal(cloudUrl, pairingId);
    runnerRef.current = runner;

    // Set up question handler
    runner.onQuestion = async (questionData): Promise<number[]> => {
      return new Promise((resolve) => {
        // Store resolver for terminal fallback
        questionResolverRef.current = resolve;

        // Create pending question state
        const pendingQuestion: PendingQuestion = {
          id: questionData.requestId,
          question: questionData.question,
          options: questionData.options,
          multiSelect: questionData.multiSelect,
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
                // Switch to terminal fallback
                return {
                  ...prev,
                  pendingQuestion: {
                    ...prev.pendingQuestion,
                    waitingForWatch: false,
                    timeoutSeconds: 0,
                  },
                };
              }
              return {
                ...prev,
                pendingQuestion: {
                  ...prev.pendingQuestion,
                  timeoutSeconds: newTimeout,
                },
              };
            }
            return prev;
          });
        }, 1000);

        // Try to get answer from watch first
        runner
          .pollWatchForAnswer(
            questionData.requestId,
            {
              question: questionData.question,
              options: questionData.options,
              multiSelect: questionData.multiSelect,
            },
            30000
          )
          .then((watchAnswer) => {
            clearInterval(countdownInterval);
            if (watchAnswer !== null && questionResolverRef.current) {
              questionResolverRef.current(watchAnswer);
              questionResolverRef.current = null;
              setWatchState((prev) => ({ ...prev, pendingQuestion: null }));
            }
          })
          .catch(() => {
            clearInterval(countdownInterval);
            // Watch timeout - terminal fallback is already shown
            messageBuffer.addMessage("Watch timeout - please answer in terminal", "status");
          });
      });
    };

    // Start the runner
    runner
      .start(prompt, {
        onOutput: processMessage,
      })
      .then((exitCode) => {
        onComplete?.(exitCode);
      });

    return () => {
      runner.kill();
    };
  }, [prompt, cloudUrl, pairingId, processMessage, messageBuffer, onComplete]);

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
 * Internal StreamingClaudeRunner with question handling
 * This is a simplified version that integrates with the UI
 */
class StreamingClaudeRunnerInternal {
  private cloudUrl: string;
  private pairingId: string;
  private process: import("child_process").ChildProcess | null = null;
  private isRunning = false;
  public onQuestion:
    | ((data: {
        requestId: string;
        question: string;
        options: Array<{ label: string; description?: string }>;
        multiSelect: boolean;
      }) => Promise<number[]>)
    | null = null;

  constructor(cloudUrl: string, pairingId: string) {
    this.cloudUrl = cloudUrl;
    this.pairingId = pairingId;
  }

  async start(
    prompt: string,
    options?: { onOutput?: (message: SDKMessage) => void }
  ): Promise<number> {
    const { spawn } = await import("child_process");
    const { createInterface } = await import("readline");

    this.isRunning = true;

    const args = [
      "--output-format",
      "stream-json",
      "--input-format",
      "stream-json",
      "--permission-prompt-tool",
      "stdio",
      "--permission-mode",
      "default",
      "--verbose",
    ];

    this.process = spawn("claude", args, {
      stdio: ["pipe", "pipe", "pipe"],
      env: {
        ...process.env,
        CLAUDE_WATCH_SESSION_ACTIVE: "1",
      },
    });

    // Read JSON messages from stdout
    const readline = createInterface({
      input: this.process.stdout!,
      crlfDelay: Infinity,
    });

    // Process messages
    (async () => {
      for await (const line of readline) {
        if (!line.trim()) continue;
        try {
          const message = JSON.parse(line) as SDKMessage;
          await this.handleMessage(message, options?.onOutput);
        } catch {
          // Non-JSON output
        }
      }
    })();

    // Send initial prompt
    await new Promise((resolve) => setTimeout(resolve, 100));
    this.writeToStdin({
      type: "user",
      message: { role: "user", content: prompt },
    });

    return new Promise((resolve) => {
      this.process?.on("close", (code) => {
        this.isRunning = false;
        resolve(code ?? 0);
      });
      this.process?.on("error", () => {
        this.isRunning = false;
        resolve(1);
      });
    });
  }

  private async handleMessage(
    message: SDKMessage,
    onOutput?: (message: SDKMessage) => void
  ): Promise<void> {
    if (message.type === "control_request") {
      await this.handleControlRequest(message);
    } else {
      onOutput?.(message);
    }
  }

  private async handleControlRequest(message: SDKMessage): Promise<void> {
    const requestId = (message as { request_id?: string }).request_id;
    const request = (message as { request?: { subtype?: string; tool_name?: string; input?: unknown } })
      .request;

    if (!requestId || !request) return;

    if (request.subtype === "can_use_tool" && request.tool_name === "AskUserQuestion") {
      // Handle question
      const input = request.input as QuestionInput;
      const questions = input?.questions || [];

      if (questions.length > 0 && this.onQuestion) {
        const q = questions[0];
        const answer = await this.onQuestion({
          requestId,
          question: q.question,
          options: q.options,
          multiSelect: q.multiSelect || false,
        });

        // Send response
        this.sendControlResponse(requestId, answer, input);
      }
    } else {
      // For other tools, auto-approve (tool approvals go through hooks)
      this.writeToStdin({
        type: "control_response",
        response: {
          subtype: "success",
          request_id: requestId,
          response: { behavior: "allow" },
        },
      });
    }
  }

  private sendControlResponse(requestId: string, selectedIndices: number[], originalInput: QuestionInput): void {
    // Build the answers object matching Claude's expected format
    const questions = originalInput.questions || [];
    const answers: Record<string, string> = {};

    if (questions.length > 0) {
      const q = questions[0];
      // Map indices to option labels
      const selectedLabels = selectedIndices.map((i) => q.options[i]?.label || "").filter(Boolean);
      answers[q.question] = selectedLabels.join(", ");
    }

    this.writeToStdin({
      type: "control_response",
      response: {
        subtype: "success",
        request_id: requestId,
        response: {
          behavior: "allow",
          updatedInput: {
            ...originalInput,
            answers,
          },
        },
      },
    });
  }

  async pollWatchForAnswer(
    questionId: string,
    questionData: {
      question: string;
      options: Array<{ label: string; description?: string }>;
      multiSelect: boolean;
      header?: string;
    },
    timeoutMs: number
  ): Promise<number[] | null> {
    const startTime = Date.now();

    // First, send question to watch
    try {
      const response = await fetch(`${this.cloudUrl}/question`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          id: questionId,
          pairingId: this.pairingId,
          question: questionData.question,
          header: questionData.header || "Question",
          options: questionData.options.map((opt) => ({
            label: opt.label,
            description: opt.description || "",
          })),
          multiSelect: questionData.multiSelect,
        }),
      });
      if (!response.ok) {
        console.error(`Failed to send question to cloud: ${response.status}`);
      }
    } catch (error) {
      console.error(`Failed to send question to watch: ${error}`);
      return null;
    }

    // Poll for answer
    while (Date.now() - startTime < timeoutMs) {
      try {
        const response = await fetch(`${this.cloudUrl}/question/${questionId}`);
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
        // Polling error - continue
      }
      await new Promise((resolve) => setTimeout(resolve, 500));
    }

    return null;
  }

  private writeToStdin(message: object): void {
    if (!this.process?.stdin) return;
    this.process.stdin.write(JSON.stringify(message) + "\n");
  }

  async interrupt(): Promise<void> {
    // Send interrupt signal
    this.process?.kill("SIGINT");
  }

  kill(): void {
    this.process?.kill("SIGTERM");
    this.isRunning = false;
  }
}

/**
 * Render the cc-watch app
 */
export function renderApp(props: AppProps): void {
  render(<App {...props} />);
}
