import React, { useState, useCallback } from 'react';
import { Box, useApp, useInput } from 'ink';
import { useFileWatcher } from './hooks/useFileWatcher.js';
import { Header } from './components/Header.js';
import { TaskList } from './components/TaskList.js';
import { ProgressLog } from './components/ProgressLog.js';
import { Footer } from './components/Footer.js';

/**
 * Main App component with keyboard navigation
 */
export function App(): React.ReactElement {
  const { exit } = useApp();
  const { tasks, metrics, progressLines, error } = useFileWatcher();
  const [selectedIndex, setSelectedIndex] = useState(0);

  // Handle keyboard input
  useInput((input, key) => {
    if (input === 'q' || key.escape) {
      exit();
      return;
    }

    if (key.upArrow || input === 'k') {
      setSelectedIndex((prev) => Math.max(0, prev - 1));
      return;
    }

    if (key.downArrow || input === 'j') {
      setSelectedIndex((prev) => Math.min(tasks.length - 1, prev + 1));
      return;
    }
  });

  const completedCount = tasks.filter((t) => t.status === 'completed').length;
  const isRunning = tasks.some((t) => t.status === 'in_progress');

  return (
    <Box flexDirection="column" height="100%">
      <Header
        isRunning={isRunning}
        completedTasks={completedCount}
        totalTasks={tasks.length}
        error={error?.message}
      />

      <Box flexGrow={1}>
        <TaskList
          tasks={tasks}
          selectedIndex={selectedIndex}
        />
        <ProgressLog
          lines={progressLines}
        />
      </Box>

      <Footer />
    </Box>
  );
}
