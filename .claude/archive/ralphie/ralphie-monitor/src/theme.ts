import type { TaskStatus } from './types.js';

/**
 * Color palette for the Ralph TUI (Tokyo Night inspired)
 */
export const colors = {
  bg: {
    primary: '#1a1b26',
    secondary: '#24283b',
    highlight: '#3d4259',
  },
  fg: {
    primary: '#c0caf5',
    secondary: '#a9b1d6',
    muted: '#565f89',
    dim: '#414868',
  },
  status: {
    success: '#9ece6a',
    warning: '#e0af68',
    error: '#f7768e',
    info: '#7aa2f7',
  },
  task: {
    completed: '#9ece6a',
    in_progress: '#7aa2f7',
    pending: '#565f89',
    failed: '#f7768e',
  },
} as const;

/**
 * Status indicator symbols
 */
export const statusIndicators = {
  completed: '✓',
  in_progress: '▶',
  pending: '○',
  failed: '✗',
  running: '●',
  stopped: '○',
} as const;

/**
 * Keyboard shortcuts for footer display
 */
export const keyboardShortcuts = [
  { key: 'q', description: 'Quit' },
  { key: 'j/k', description: 'Navigate' },
  { key: '?', description: 'Help' },
] as const;

/**
 * Get the color for a given task status
 */
export function getTaskStatusColor(status: TaskStatus): string {
  return colors.task[status];
}

/**
 * Get the indicator symbol for a given task status
 */
export function getTaskStatusIndicator(status: TaskStatus): string {
  return statusIndicators[status];
}

/**
 * Format elapsed time in human-readable format
 */
export function formatElapsedTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = seconds % 60;

  if (hours > 0) {
    return `${hours}h ${minutes}m ${secs}s`;
  }
  if (minutes > 0) {
    return `${minutes}m ${secs}s`;
  }
  return `${secs}s`;
}
