import React, { memo } from 'react';
import { Box, Text } from 'ink';
import type { Task } from '../types.js';
import { colors, getTaskStatusColor, getTaskStatusIndicator } from '../theme.js';

interface TaskListProps {
  tasks: Task[];
  selectedIndex: number;
}

/**
 * Truncate text to fit within a maximum width
 */
function truncateText(text: string, maxWidth: number): string {
  if (text.length <= maxWidth) return text;
  if (maxWidth <= 3) return text.slice(0, maxWidth);
  return text.slice(0, maxWidth - 1) + '…';
}

/**
 * Single task row component
 */
function TaskRow({ task, isSelected }: { task: Task; isSelected: boolean }): React.ReactElement {
  const statusColor = getTaskStatusColor(task.status);
  const statusIndicator = getTaskStatusIndicator(task.status);
  const textColor = isSelected ? colors.fg.primary : colors.fg.secondary;
  const prefix = isSelected ? '▸ ' : '  ';

  return (
    <Box>
      <Text color={isSelected ? colors.status.info : colors.fg.dim}>{prefix}</Text>
      <Text color={statusColor}>{statusIndicator} </Text>
      <Text color={colors.fg.muted}>{task.id.padEnd(6)} </Text>
      <Text color={textColor} bold={isSelected}>{truncateText(task.title, 30)}</Text>
    </Box>
  );
}

/**
 * TaskList component showing scrollable task queue
 * Wrapped in React.memo for performance
 */
export const TaskList = memo(function TaskList({ tasks, selectedIndex }: TaskListProps): React.ReactElement {
  return (
    <Box
      flexDirection="column"
      borderStyle="single"
      borderColor={colors.fg.dim}
      width="40%"
      paddingX={1}
    >
      <Box marginBottom={1}>
        <Text bold color={colors.fg.primary}>TASKS</Text>
      </Box>
      {tasks.length === 0 ? (
        <Text color={colors.fg.muted}>No tasks loaded</Text>
      ) : (
        tasks.map((task, index) => (
          <TaskRow
            key={task.id}
            task={task}
            isSelected={index === selectedIndex}
          />
        ))
      )}
    </Box>
  );
});
