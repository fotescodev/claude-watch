import { useState, useEffect, useCallback } from 'react';
import { readFile } from 'fs/promises';
import { watch, type FSWatcher } from 'fs';
import { parse as parseYaml } from 'yaml';
import { dirname, resolve } from 'path';
import { fileURLToPath } from 'url';
import type { RawTask, Metrics, WatcherState } from '../types.js';
import { normalizeTask } from '../types.js';

// Resolve RALPH_DIR: use env var, or default to parent of this package (ralphie-monitor is inside .claude/ralph)
const __dirname = dirname(fileURLToPath(import.meta.url));
const RALPH_DIR = process.env.RALPH_DIR ?? resolve(__dirname, '..', '..', '..');
const MAX_PROGRESS_LINES = 50;

/**
 * Watches Ralph state files and provides reactive updates.
 * Uses async file operations with fs.watch for change detection.
 */
export function useFileWatcher(): WatcherState {
  const [state, setState] = useState<WatcherState>({
    tasks: [],
    metrics: null,
    progressLines: [],
    error: null,
  });

  const loadTasks = useCallback(async () => {
    try {
      const content = await readFile(`${RALPH_DIR}/tasks.yaml`, 'utf-8');
      const data = parseYaml(content) as { tasks?: RawTask[] };
      const tasks = (data.tasks ?? []).map(normalizeTask);
      setState((prev) => ({ ...prev, tasks, error: null }));
    } catch (err) {
      // File may not exist yet - not an error
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        setState((prev) => ({ ...prev, error: err as Error }));
      }
    }
  }, []);

  const loadMetrics = useCallback(async () => {
    try {
      const content = await readFile(`${RALPH_DIR}/metrics.json`, 'utf-8');
      const data = JSON.parse(content) as Metrics;
      setState((prev) => ({ ...prev, metrics: data, error: null }));
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        setState((prev) => ({ ...prev, error: err as Error }));
      }
    }
  }, []);

  const loadProgress = useCallback(async () => {
    try {
      const content = await readFile(`${RALPH_DIR}/current-progress.log`, 'utf-8');
      const lines = content.split('\n').filter(Boolean).slice(-MAX_PROGRESS_LINES);
      setState((prev) => ({ ...prev, progressLines: lines, error: null }));
    } catch (err) {
      if ((err as NodeJS.ErrnoException).code !== 'ENOENT') {
        setState((prev) => ({ ...prev, error: err as Error }));
      }
    }
  }, []);

  useEffect(() => {
    // Initial load
    void loadTasks();
    void loadMetrics();
    void loadProgress();

    // Set up file watchers
    const watchers: FSWatcher[] = [];

    const watchFile = (path: string, onUpdate: () => Promise<void>) => {
      try {
        const watcher = watch(path, (eventType) => {
          if (eventType === 'change') {
            void onUpdate();
          }
        });
        watchers.push(watcher);
      } catch {
        // File doesn't exist yet - that's OK
      }
    };

    watchFile(`${RALPH_DIR}/tasks.yaml`, loadTasks);
    watchFile(`${RALPH_DIR}/metrics.json`, loadMetrics);
    watchFile(`${RALPH_DIR}/current-progress.log`, loadProgress);

    // Poll for files that may not exist yet
    const pollInterval = setInterval(() => {
      void loadTasks();
      void loadMetrics();
      void loadProgress();
    }, 2000);

    return () => {
      watchers.forEach((w) => w.close());
      clearInterval(pollInterval);
    };
  }, [loadTasks, loadMetrics, loadProgress]);

  return state;
}
