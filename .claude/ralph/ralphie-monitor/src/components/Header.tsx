import React from 'react';
import { Box, Text } from 'ink';
import { colors, statusIndicators } from '../theme.js';

interface HeaderProps {
  isRunning: boolean;
  completedTasks: number;
  totalTasks: number;
  error?: string;
}

/**
 * Header component showing Ralph status and task progress
 */
export function Header({ isRunning, completedTasks, totalTasks, error }: HeaderProps): React.ReactElement {
  const statusColor = isRunning ? colors.status.success : colors.fg.muted;
  const statusIcon = isRunning ? statusIndicators.running : statusIndicators.stopped;
  const statusText = isRunning ? 'RUNNING' : 'STOPPED';

  return (
    <Box flexDirection="column" borderStyle="single" borderColor={colors.fg.dim} paddingX={1}>
      <Box justifyContent="space-between">
        <Text bold color={colors.fg.primary}>RALPHIE MONITOR</Text>
        <Box>
          <Text color={statusColor}>{statusIcon} </Text>
          <Text color={statusColor}>{statusText}</Text>
        </Box>
      </Box>
      <Box justifyContent="space-between">
        <Text color={colors.fg.secondary}>
          {completedTasks}/{totalTasks} tasks complete
        </Text>
        {error && (
          <Text color={colors.status.error}>Error: {error}</Text>
        )}
      </Box>
    </Box>
  );
}
