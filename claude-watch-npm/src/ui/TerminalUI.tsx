/**
 * TerminalUI - Ink-based terminal UI for cc-watch
 * Based on Happy Coder's RemoteModeDisplay pattern
 */

import React, { useState, useEffect, useCallback, useRef } from "react";
import { Box, Text, useStdout, useInput } from "ink";
import Spinner from "ink-spinner";
import { MessageBuffer, type BufferedMessage } from "./MessageBuffer.js";

// UI State for watch integration
export interface WatchState {
  connected: boolean;
  pendingQuestion: PendingQuestion | null;
  pendingApprovals: number;
}

export interface PendingQuestion {
  id: string;
  question: string;
  options: Array<{ label: string; description?: string }>;
  multiSelect: boolean;
  waitingForWatch: boolean;
  timeoutSeconds: number;
}

interface TerminalUIProps {
  messageBuffer: MessageBuffer;
  watchState: WatchState;
  onExit?: () => void;
  onInterrupt?: () => void;
  onQuestionAnswer?: (questionId: string, selectedIndices: number[]) => void;
  tokenCount?: { input: number; output: number };
  elapsedSeconds?: number;
}

export const TerminalUI: React.FC<TerminalUIProps> = ({
  messageBuffer,
  watchState,
  onExit,
  onInterrupt,
  onQuestionAnswer,
  tokenCount,
  elapsedSeconds,
}) => {
  const [messages, setMessages] = useState<BufferedMessage[]>([]);
  const [selectedOption, setSelectedOption] = useState(0);
  const [exiting, setExiting] = useState(false);
  const { stdout } = useStdout();
  const terminalWidth = stdout?.columns || 80;
  const terminalHeight = stdout?.rows || 24;

  // Subscribe to message updates
  useEffect(() => {
    setMessages(messageBuffer.getMessages());

    const unsubscribe = messageBuffer.onUpdate((newMessages) => {
      setMessages(newMessages);
    });

    return () => {
      unsubscribe();
    };
  }, [messageBuffer]);

  // Handle keyboard input - Following Happy's pattern
  useInput(
    useCallback(
      (input, key) => {
        // Don't process if already exiting
        if (exiting) return;

        // Handle Ctrl+C - exit immediately
        if (key.ctrl && input === "c") {
          setExiting(true);
          onExit?.();
          return;
        }

        // If we have a pending question in terminal fallback mode
        if (watchState.pendingQuestion && !watchState.pendingQuestion.waitingForWatch) {
          const optionCount = watchState.pendingQuestion.options.length;

          if (key.upArrow) {
            setSelectedOption((prev) => (prev > 0 ? prev - 1 : optionCount - 1));
          } else if (key.downArrow) {
            setSelectedOption((prev) => (prev < optionCount - 1 ? prev + 1 : 0));
          } else if (key.return) {
            onQuestionAnswer?.(watchState.pendingQuestion.id, [selectedOption]);
            setSelectedOption(0);
          } else if (input >= "1" && input <= "9") {
            const index = parseInt(input, 10) - 1;
            if (index < optionCount) {
              onQuestionAnswer?.(watchState.pendingQuestion.id, [index]);
              setSelectedOption(0);
            }
          }
        }
      },
      [exiting, watchState.pendingQuestion, selectedOption, onExit, onQuestionAnswer]
    )
  );

  // Format elapsed time
  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return mins > 0 ? `${mins}m ${secs}s` : `${secs}s`;
  };

  // Get color for message type
  const getMessageColor = (type: BufferedMessage["type"]): string => {
    switch (type) {
      case "user":
        return "magenta";
      case "assistant":
        return "cyan";
      case "system":
        return "blue";
      case "tool":
        return "yellow";
      case "result":
        return "green";
      case "status":
        return "gray";
      case "question":
        return "yellow";
      default:
        return "white";
    }
  };

  // Calculate available height for messages
  const headerHeight = 3;
  const statusBarHeight = 3;
  const questionHeight = watchState.pendingQuestion ? 8 : 0;
  const messageAreaHeight = terminalHeight - headerHeight - statusBarHeight - questionHeight;

  return (
    <Box flexDirection="column" width={terminalWidth} height={terminalHeight}>
      {/* Header */}
      <Box
        borderStyle="round"
        borderColor={watchState.connected ? "green" : "yellow"}
        paddingX={1}
        justifyContent="space-between"
      >
        <Box>
          <Text color={watchState.connected ? "green" : "yellow"} bold>
            {watchState.connected ? "⌚ Watch Connected" : "⌚ Watch Disconnected"}
          </Text>
          {watchState.pendingApprovals > 0 && (
            <Text color="yellow"> • {watchState.pendingApprovals} pending</Text>
          )}
        </Box>
        <Box>
          {tokenCount && (
            <Text color="gray">
              ↓{tokenCount.input} ↑{tokenCount.output}
            </Text>
          )}
          {elapsedSeconds !== undefined && (
            <Text color="gray"> • {formatTime(elapsedSeconds)}</Text>
          )}
        </Box>
      </Box>

      {/* Message Area - Shows recent output, auto-scrolls to bottom */}
      <Box
        flexDirection="column"
        height={messageAreaHeight}
        borderStyle="round"
        borderColor="gray"
        paddingX={1}
        overflowY="hidden"
      >
        {messages.length === 0 ? (
          <Box>
            <Text color="gray">
              <Spinner type="dots" /> Waiting for Claude...
            </Text>
          </Box>
        ) : (
          // Show last 10 messages max, each truncated to fit reasonable space
          messages.slice(-10).map((msg) => (
            <Box key={msg.id} marginBottom={0}>
              <Text color={getMessageColor(msg.type)} wrap="wrap">
                {msg.content.length > 500 ? msg.content.slice(0, 500) + "..." : msg.content}
              </Text>
            </Box>
          ))
        )}
      </Box>

      {/* Question Overlay (if pending) */}
      {watchState.pendingQuestion && (
        <Box
          flexDirection="column"
          borderStyle="round"
          borderColor={watchState.pendingQuestion.waitingForWatch ? "cyan" : "yellow"}
          paddingX={1}
        >
          {watchState.pendingQuestion.waitingForWatch ? (
            <Box flexDirection="column">
              <Text color="cyan" bold>
                <Spinner type="dots" /> Waiting for watch response...
              </Text>
              <Text color="gray" dimColor>
                {watchState.pendingQuestion.question}
              </Text>
              <Text color="gray" dimColor>
                Timeout in {watchState.pendingQuestion.timeoutSeconds}s (then answer here)
              </Text>
            </Box>
          ) : (
            <Box flexDirection="column">
              <Text color="yellow" bold>
                Watch timeout - answer here:
              </Text>
              <Text color="white">{watchState.pendingQuestion.question}</Text>
              <Box flexDirection="column" marginTop={1}>
                {watchState.pendingQuestion.options.map((opt, idx) => (
                  <Text
                    key={idx}
                    color={idx === selectedOption ? "cyan" : "white"}
                    bold={idx === selectedOption}
                  >
                    {idx === selectedOption ? "› " : "  "}
                    {idx + 1}. {opt.label}
                  </Text>
                ))}
              </Box>
              <Text color="gray" dimColor>
                ↑↓ to select, Enter or 1-{watchState.pendingQuestion.options.length} to confirm
              </Text>
            </Box>
          )}
        </Box>
      )}

      {/* Status Bar */}
      <Box
        borderStyle="round"
        borderColor={exiting ? "gray" : "green"}
        paddingX={1}
        justifyContent="center"
      >
        {exiting ? (
          <Text color="gray" bold>
            Exiting...
          </Text>
        ) : (
          <Text color="green" bold>
            Ctrl+C to exit • Questions route to watch
          </Text>
        )}
      </Box>
    </Box>
  );
};

export default TerminalUI;
