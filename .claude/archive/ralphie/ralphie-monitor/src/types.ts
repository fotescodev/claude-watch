/**
 * Task status from tasks.yaml
 */
export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'failed';

/**
 * Task priority levels
 */
export type TaskPriority = 'critical' | 'high' | 'normal' | 'low';

/**
 * Raw task from tasks.yaml (actual format)
 */
export interface RawTask {
  id: string;
  title: string;
  description?: string;
  priority: TaskPriority;
  completed?: boolean;
  in_progress?: boolean;
  parallel_group?: number;
}

/**
 * Normalized task for display
 */
export interface Task {
  id: string;
  title: string;
  status: TaskStatus;
  priority: TaskPriority;
}

/**
 * Convert raw task to normalized task
 */
export function normalizeTask(raw: RawTask): Task {
  let status: TaskStatus = 'pending';
  if (raw.completed) {
    status = 'completed';
  } else if (raw.in_progress) {
    status = 'in_progress';
  }

  return {
    id: raw.id,
    title: raw.title,
    status,
    priority: raw.priority,
  };
}

/**
 * Metrics from metrics.json
 */
export interface Metrics {
  sessions: number;
  tokensUsed: number;
  estimatedCost: number;
  successRate: number;
}

/**
 * Application state
 */
export interface AppState {
  tasks: Task[];
  metrics: Metrics | null;
  progressLines: string[];
  isRalphRunning: boolean;
  selectedTaskIndex: number;
}

/**
 * File watcher state (returned by useFileWatcher hook)
 */
export interface WatcherState {
  tasks: Task[];
  metrics: Metrics | null;
  progressLines: string[];
  error: Error | null;
}
