# PRD: Ralphie Monitor TUI

> **Status:** Draft
> **Date:** 2026-01-17
> **Scope:** Read-only terminal monitor for Ralph execution
> **Priority:** High
> **Related:** prd-ralph-resilience.md (learning system)

---

## Executive Summary

Build a minimal, read-only terminal monitor that displays Ralph execution status. No orchestration features, no learning system - just visibility into what Ralph is doing.

### Research Foundation

Analyzed three production Ralph implementations:
- **snarktank/ralph** - 80-line bash loop with progress.txt
- **frankbria/ralph-claude-code** - 308 tests, circuit breaker, tmux monitor
- **subsy/ralph-tui** - Bun + OpenTUI, plugin architecture, session persistence

---

## Decision: OpenTUI over React Ink

After reviewing ralph-tui, OpenTUI is the recommended framework:

| Aspect | React Ink | OpenTUI |
|--------|-----------|---------|
| Runtime | Node.js | Bun (faster) |
| Maturity | Stable | Active development |
| Architecture | React patterns | React patterns |
| Real-world use | Many projects | ralph-tui (production) |

**Decision:** Use OpenTUI following ralph-tui patterns.

---

## Scope: What This PRD Covers

**In Scope:**
- Read-only task queue display
- Real-time progress log
- Basic metrics display
- Keyboard navigation
- Session status

**Out of Scope (see prd-ralph-resilience.md):**
- Circuit breaker integration
- Response analyzer
- Self-learning system
- Skill generation
- Parallel/sharding modes

---

## Architecture

### Tech Stack

```
ralphie-monitor/
├── package.json           # Bun project
├── tsconfig.json          # Strict TypeScript
├── src/
│   ├── index.ts           # Entry point
│   ├── App.tsx            # Main component
│   ├── components/
│   │   ├── Header.tsx     # Status bar
│   │   ├── TaskList.tsx   # Task queue
│   │   ├── ProgressLog.tsx # Live output
│   │   └── Footer.tsx     # Keybindings
│   ├── hooks/
│   │   └── useFileWatcher.ts
│   └── types.ts           # Type definitions
└── bin/
    └── ralphie-monitor    # CLI entry
```

### Data Sources (Read-Only)

The monitor watches these files with no write operations:

| File | Data | Type |
|------|------|------|
| `tasks.yaml` | Task queue | YAML |
| `metrics.json` | Session stats | JSON |
| `current-progress.log` | Live output | Text |

---

## Component Specifications

### types.ts

```typescript
/**
 * Task status from tasks.yaml
 */
export type TaskStatus = 'pending' | 'in_progress' | 'completed' | 'failed';

/**
 * Task from tasks.yaml
 */
export interface Task {
  id: string;
  title: string;
  status: TaskStatus;
  priority: 'critical' | 'high' | 'normal' | 'low';
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
```

### useFileWatcher.ts (Async, Error-Handled)

```typescript
import { useState, useEffect, useCallback } from 'react';
import { watch } from 'fs/promises';
import { readFile } from 'fs/promises';
import { parse as parseYaml } from 'yaml';
import type { Task, Metrics } from '../types';

interface WatcherState {
  tasks: Task[];
  metrics: Metrics | null;
  progressLines: string[];
  error: Error | null;
}

const RALPH_DIR = process.env.RALPH_DIR ?? '.claude/ralph';
const MAX_PROGRESS_LINES = 50;

/**
 * Watches Ralph state files and provides reactive updates.
 * Uses async file operations throughout.
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
      const data = parseYaml(content) as { tasks?: Task[] };
      setState((prev) => ({ ...prev, tasks: data.tasks ?? [], error: null }));
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
      const lines = content.split('\n').slice(-MAX_PROGRESS_LINES);
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
    const controllers: AbortController[] = [];

    const watchFile = async (path: string, onUpdate: () => Promise<void>) => {
      const controller = new AbortController();
      controllers.push(controller);

      try {
        const watcher = watch(path, { signal: controller.signal });
        for await (const event of watcher) {
          if (event.eventType === 'change') {
            await onUpdate();
          }
        }
      } catch (err) {
        // AbortError is expected on cleanup
        if ((err as Error).name !== 'AbortError') {
          console.error(`Watch error for ${path}:`, err);
        }
      }
    };

    void watchFile(`${RALPH_DIR}/tasks.yaml`, loadTasks);
    void watchFile(`${RALPH_DIR}/metrics.json`, loadMetrics);
    void watchFile(`${RALPH_DIR}/current-progress.log`, loadProgress);

    return () => {
      controllers.forEach((c) => c.abort());
    };
  }, [loadTasks, loadMetrics, loadProgress]);

  return state;
}
```

### App.tsx

```typescript
import { useState, useCallback } from 'react';
import { useKeyboard, useTerminalDimensions } from '@opentui/react';
import { useFileWatcher } from './hooks/useFileWatcher';
import { Header } from './components/Header';
import { TaskList } from './components/TaskList';
import { ProgressLog } from './components/ProgressLog';
import { Footer } from './components/Footer';

export function App(): JSX.Element {
  const { width, height } = useTerminalDimensions();
  const { tasks, metrics, progressLines, error } = useFileWatcher();
  const [selectedIndex, setSelectedIndex] = useState(0);

  const handleKeyboard = useCallback(
    (key: { name: string }) => {
      switch (key.name) {
        case 'q':
        case 'escape':
          process.exit(0);
          break;
        case 'up':
        case 'k':
          setSelectedIndex((prev) => Math.max(0, prev - 1));
          break;
        case 'down':
        case 'j':
          setSelectedIndex((prev) => Math.min(tasks.length - 1, prev + 1));
          break;
      }
    },
    [tasks.length]
  );

  useKeyboard(handleKeyboard);

  const completedCount = tasks.filter((t) => t.status === 'completed').length;
  const isRunning = tasks.some((t) => t.status === 'in_progress');

  return (
    <box style={{ flexDirection: 'column', width: '100%', height: '100%' }}>
      <Header
        isRunning={isRunning}
        completedTasks={completedCount}
        totalTasks={tasks.length}
        error={error?.message}
      />

      <box style={{ flexDirection: 'row', flexGrow: 1 }}>
        <TaskList
          tasks={tasks}
          selectedIndex={selectedIndex}
          width={Math.floor(width * 0.4)}
        />
        <ProgressLog
          lines={progressLines}
          width={Math.floor(width * 0.6)}
        />
      </box>

      <Footer />
    </box>
  );
}
```

---

## Wireframe

```
┌─────────────────────────────────────────────────────────────────┐
│  RALPHIE MONITOR                               ● RUNNING        │
│  3/15 tasks complete                                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─ TASKS ─────────────────┐  ┌─ PROGRESS ───────────────────┐  │
│  │                         │  │                               │  │
│  │  ✓ C1  Accessibility    │  │  [14:32:45] Starting C3...   │  │
│  │  ✓ C2  App icons        │  │  [14:32:46] Read file.swift  │  │
│  │  → C3  Consent dialog   │  │  [14:32:47] Creating view... │  │
│  │  ○ H1  Font sizes       │  │  [14:32:52] Wrote 127 lines  │  │
│  │  ○ H2  App Groups       │  │  [14:32:53] Verifying...     │  │
│  │                         │  │                               │  │
│  └─────────────────────────┘  └───────────────────────────────┘  │
│                                                                 │
│  [q] Quit  [j/k] Navigate  [?] Help                             │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Tasks

### Phase 1: Core Monitor

1. [ ] Initialize Bun project with OpenTUI + TypeScript strict mode
2. [ ] Define types.ts with Task, Metrics, AppState interfaces
3. [ ] Implement useFileWatcher hook with async operations
4. [ ] Build Header component (running status, task count)
5. [ ] Build TaskList component (scrollable, highlighted selection)
6. [ ] Build ProgressLog component (tail -f style)
7. [ ] Build Footer component (keybindings)
8. [ ] Create CLI entry point
9. [ ] Add graceful handling when Ralph isn't running

### Acceptance Criteria

- [ ] `bun run ralphie-monitor` launches TUI
- [ ] Shows tasks from tasks.yaml with correct status icons
- [ ] Updates within 500ms of file change
- [ ] Memory usage <30MB (measured with `bun --smol`)
- [ ] Gracefully shows "Ralph not running" when no in_progress task
- [ ] j/k navigation works
- [ ] q quits cleanly

### Files to Create

```
.claude/ralph/ralphie-monitor/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.ts
│   ├── App.tsx
│   ├── types.ts
│   ├── components/
│   │   ├── Header.tsx
│   │   ├── TaskList.tsx
│   │   ├── ProgressLog.tsx
│   │   └── Footer.tsx
│   └── hooks/
│       └── useFileWatcher.ts
└── bin/
    └── ralphie-monitor
```

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Startup time | <500ms |
| File change latency | <500ms |
| Memory usage | <30MB |
| CPU idle | <1% |

---

## Non-Goals

- Parallel mode display (separate phase)
- Circuit breaker integration (see prd-ralph-resilience.md)
- Learning system (see prd-ralph-resilience.md)
- Remote control / write operations
- Web dashboard

---

## Architecture Patterns from ralph-tui Deep Dive

### Theme System

Following ralph-tui's `theme.ts` pattern for consistent styling:

```typescript
// src/theme.ts
export const colors = {
  bg: { primary: '#1a1b26', secondary: '#24283b', highlight: '#3d4259' },
  fg: { primary: '#c0caf5', secondary: '#a9b1d6', muted: '#565f89' },
  status: { success: '#9ece6a', warning: '#e0af68', error: '#f7768e', info: '#7aa2f7' },
  task: { done: '#9ece6a', active: '#7aa2f7', pending: '#565f89', blocked: '#f7768e' },
} as const;

export const statusIndicators = {
  done: '✓', active: '▶', pending: '○', blocked: '⊘',
  running: '▶', paused: '⏸', ready: '◉',
} as const;

export type TaskStatus = 'done' | 'active' | 'pending' | 'blocked';
```

### Component Memoization

Following ralph-tui's LeftPanel pattern for performance:

```typescript
// Use React.memo for panels that don't need frequent re-renders
export const TaskList = memo(function TaskList({ tasks, selectedIndex }: Props) {
  // ...
});
```

### Subagent Tree (Future Enhancement)

ralph-tui's SubagentTreePanel provides real-time visualization of nested Task tool calls:

```typescript
// Status icons for subagent tracking
function getStatusIcon(status: 'running' | 'completed' | 'error'): string {
  switch (status) {
    case 'running': return '◐';
    case 'completed': return '✓';
    case 'error': return '✗';
  }
}
```

This could be added in Phase 2 if Ralph supports Task tool subagents.

---

## Testing Strategy

Following ralph-tui's Bun test patterns:

### Test Structure

```
tests/
├── factories/
│   └── task.ts          # Factory functions for test data
├── mocks/
│   └── watcher.ts       # Mock file watcher
└── components/
    └── TaskList.test.ts # Component tests
```

### Factory Pattern for Test Data

```typescript
// tests/factories/task.ts
export function createTask(overrides: Partial<Task> = {}): Task {
  return {
    id: `task-${Date.now()}`,
    title: 'Test Task',
    status: 'pending',
    priority: 'normal',
    ...overrides,
  };
}

export function createTasks(count: number): Task[] {
  return Array.from({ length: count }, (_, i) =>
    createTask({ id: `task-${i + 1}`, title: `Task ${i + 1}` })
  );
}
```

### Mock Module Override

```typescript
// tests/hooks/useFileWatcher.test.ts
import { describe, test, expect, mock, beforeEach } from 'bun:test';

mock.module('fs/promises', () => ({
  readFile: mock(() => Promise.resolve('{}')),
  watch: mock(() => ({ [Symbol.asyncIterator]: () => ({ next: () => Promise.resolve({ done: true }) }) })),
}));
```

---

## References

- ralph-tui: https://github.com/subsy/ralph-tui (architecture patterns)
- OpenTUI: https://github.com/sst/opentui
- Deep dive files analyzed:
  - `src/tui/components/App.tsx` - Main component patterns
  - `src/tui/components/Header.tsx` - Status bar with mini progress
  - `src/tui/components/LeftPanel.tsx` - Memoized task list
  - `src/tui/components/SubagentTreePanel.tsx` - Nested agent visualization
  - `src/tui/theme.ts` - Design system
  - `tests/engine/execution-engine.test.ts` - Testing patterns

---

**END OF PRD**
