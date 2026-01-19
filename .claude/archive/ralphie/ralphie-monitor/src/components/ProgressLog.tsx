import React from 'react';
import { Box, Text } from 'ink';
import { colors } from '../theme.js';

interface ProgressLogProps {
  lines: string[];
}

/**
 * ProgressLog component showing tail -f style output
 */
export function ProgressLog({ lines }: ProgressLogProps): React.ReactElement {
  return (
    <Box
      flexDirection="column"
      borderStyle="single"
      borderColor={colors.fg.dim}
      flexGrow={1}
      paddingX={1}
    >
      <Box marginBottom={1}>
        <Text bold color={colors.fg.primary}>PROGRESS</Text>
      </Box>
      {lines.length === 0 ? (
        <Text color={colors.fg.muted}>Waiting for output...</Text>
      ) : (
        lines.map((line, index) => (
          <Text key={index} color={colors.fg.secondary} wrap="truncate">
            {line}
          </Text>
        ))
      )}
    </Box>
  );
}
