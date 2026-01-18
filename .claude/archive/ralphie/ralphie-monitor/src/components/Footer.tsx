import React from 'react';
import { Box, Text } from 'ink';
import { colors, keyboardShortcuts } from '../theme.js';

/**
 * Footer component showing keyboard shortcuts
 */
export function Footer(): React.ReactElement {
  return (
    <Box
      borderStyle="single"
      borderColor={colors.fg.dim}
      paddingX={1}
      justifyContent="center"
      gap={2}
    >
      {keyboardShortcuts.map(({ key, description }) => (
        <Box key={key} gap={1}>
          <Text color={colors.status.info}>[{key}]</Text>
          <Text color={colors.fg.muted}>{description}</Text>
        </Box>
      ))}
    </Box>
  );
}
