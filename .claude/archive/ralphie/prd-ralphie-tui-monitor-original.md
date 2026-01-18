# PRD: Ralphie TUI Monitor

> **Status:** Draft (Deepened)
> **Date:** 2026-01-17
> **Author:** Claude + Human
> **Priority:** High
> **Research:** snarktank/ralph, frankbria/ralph-claude-code

---

## Enhancement Summary

**Deepened on:** 2026-01-17
**Research sources:** 2 external Ralph implementations analyzed
**Key additions:** Circuit Breaker, Response Analyzer, Session Continuity, EXIT_SIGNAL detection

### Key Improvements from Research
1. **Circuit Breaker Pattern** - Prevent runaway loops (from frankbria/ralph)
2. **Response Analyzer** - Semantic completion detection
3. **EXIT_SIGNAL Gate** - Dual-condition completion check
4. **Session Continuity** - Context preservation across iterations
5. **tmux Integration** - Alternative to React Ink for simpler deployment

---

## Executive Summary

Build a terminal-based monitor for Ralph orchestration using React Ink. Start read-only, evolve toward cognitive features. This PRD also evaluates whether parallelization, grouping, and sharding are real value or hype.

### Research Insights (External Implementations)

**snarktank/ralph** (Simple, Amp-based):
- JSON-based PRD with `passes: true/false` tracking
- `progress.txt` for cross-iteration learnings
- AGENTS.md updates for persistent memory
- Clean 80-line bash loop

**frankbria/ralph-claude-code** (Comprehensive, 308 tests):
- Circuit breaker with stagnation detection
- Response analyzer with semantic understanding
- Session continuity via `--continue` flag
- EXIT_SIGNAL dual-condition gate
- tmux split-pane monitoring
- Rate limiting with hourly reset

---

## Part 1: Orchestration Mode Reality Check

Before building UI for orchestration modes, let's evaluate what's real vs. theoretical.

### 1.1 Sequential Mode

**Status:** ✅ REAL VALUE - Already Working

```
Task A → Complete → Task B → Complete → Task C
```

**Evidence:**
- `ralph.sh` default behavior (lines 287-353)
- 80% success rate in `metrics.json` with sequential execution
- Predictable, debuggable, no race conditions

**When it's the right choice:**
- High-risk dependency chains
- Tasks that share files
- When correctness > speed

**Verdict:** Keep as default. Don't fix what works.

---

### 1.2 Parallel Mode

**Status:** ⚠️ PARTIALLY REAL - Implemented but Fragile

```
┌─ Worker 1: Task A (Views/)
├─ Worker 2: Task B (Services/)
└─ Worker 3: Task C (Tests/)
```

**Evidence:**
- `parallel-utils.sh` has file locking (lines 36-100)
- `ralph-worker.sh` uses git worktrees (lines 87-119)
- `--parallel --max-workers N` flag exists

**Real benefits observed:**
- 2-3x speedup when tasks touch different files
- Works well for independent domains (UI vs API vs tests)

**Real problems observed:**
- File conflicts cause stalls (SHARD-04 in mock data)
- Context overhead: each worker loads full codebase
- Merge conflicts when workers finish
- Debugging is 3x harder

**When it's the right choice:**
- Tasks explicitly tagged with non-overlapping `files:` arrays
- Large task queues (10+) with clear domain separation
- Human available to resolve conflicts

**Verdict:** Keep but don't default to it. Use for specific scenarios.

---

### 1.3 Grouped Batching

**Status:** ❌ NOT IMPLEMENTED - Theoretical

```
{ Edit A, Edit B, Edit C } → Single Claude call → Apply all
```

**Theoretical benefit:**
- Token efficiency (one context load for multiple edits)
- Reduced API costs
- Coherent cross-file changes

**Reality check:**
- Claude Code already batches related edits naturally
- The `Task` tool with agents handles multi-file work
- Manual batching adds complexity without clear gain

**Implementation effort:** Medium (batch detection, conflict resolution)

**Verdict:** SKIP for MVP. Claude's natural behavior already batches. Revisit if token costs become a problem.

---

### 1.4 Sharding (Horizontal Scaling)

**Status:** ❌ NOT IMPLEMENTED - Mostly Hype for This Use Case

```
MASTER_TASK (refactor 500 files)
    ↓
┌─ Shard 1: files 1-100
├─ Shard 2: files 101-200
├─ Shard 3: files 201-300
├─ Shard 4: files 301-400
└─ Shard 5: files 401-500
```

**Theoretical benefit:**
- Massive parallelism for homogeneous work
- Linear speedup with shard count

**Reality check for watchOS project:**
- ClaudeWatch has ~15 Swift files, not 500
- Tasks are heterogeneous (UI, logic, tests), not homogeneous
- Sharding complexity > benefit at this scale

**When sharding IS real value:**
- Monorepo migrations (100+ packages)
- Large codemod operations
- Bulk test generation

**Verdict:** SKIP entirely. Not applicable to Claude Watch scale. Keep in PRD for future reference if project grows 10x.

---

### 1.5 Summary: What to Build

| Mode | Build It? | Why |
|------|-----------|-----|
| Sequential | ✅ Display | Already works, show status |
| Parallel | ✅ Display + Control | Works for some cases, let user toggle |
| Grouped | ❌ Skip | Claude handles naturally |
| Sharding | ❌ Skip | Wrong scale for this project |

**Focus the TUI on:**
1. Displaying what Ralph is actually doing (Sequential or Parallel)
2. Showing real metrics (not fake orchestration theater)
3. Enabling the self-learning loop (the real value-add)

---

## Part 2: TUI Architecture

### 2.1 Tech Stack

```
┌─────────────────────────────────────────┐
│           ralphie-tui/                  │
├─────────────────────────────────────────┤
│  React 18 + Ink 4                       │  ← Terminal UI framework
│  TypeScript                             │  ← Type safety
│  chokidar                               │  ← File watching
│  yaml                                   │  ← Parse tasks.yaml
│  chalk                                  │  ← Colors (Ink includes)
└─────────────────────────────────────────┘
```

**Why React Ink over bash:**
- Component-based UI (reusable boxes, lists, progress bars)
- State management with hooks
- Better handling of real-time updates
- Easier to extend with interactivity later

**Why NOT a web dashboard:**
- Ralph runs in terminal, monitor should too
- No context switching
- Works over SSH
- Lighter weight

### 2.2 Directory Structure

```
.claude/ralph/ralphie-tui/
├── package.json
├── tsconfig.json
├── src/
│   ├── index.tsx              # Entry point
│   ├── App.tsx                # Main app component
│   ├── components/
│   │   ├── Header.tsx         # Title + status
│   │   ├── TaskList.tsx       # Task queue display
│   │   ├── WorkerStatus.tsx   # Parallel workers (if active)
│   │   ├── Metrics.tsx        # Token usage, cost, success rate
│   │   ├── LiveLog.tsx        # Streaming progress
│   │   ├── LearningsPanel.tsx # Self-improvement status
│   │   └── TUIBox.tsx         # Reusable bordered box
│   ├── hooks/
│   │   ├── useRalphState.ts   # Watch state files
│   │   ├── useMetrics.ts      # Parse metrics.json
│   │   └── useLearnings.ts    # Parse learnings/
│   └── utils/
│       ├── parseYaml.ts       # YAML helpers
│       └── formatters.ts      # Time, bytes, etc.
└── bin/
    └── ralphie                # CLI entry (chmod +x)
```

### 2.3 Data Sources (Read-Only)

The TUI watches these files (no writing in Phase 1):

| File | Data | Update Frequency |
|------|------|------------------|
| `tasks.yaml` | Task queue, completion status | On task complete |
| `metrics.json` | Sessions, tokens, cost, success rate | On session end |
| `session-log.md` | Session history | On session end |
| `current-progress.log` | Live step-by-step | Continuously |
| `parallel/queue.yaml` | Worker assignments (if parallel) | On task claim |
| `parallel/workers/*.status` | Worker health | Every few seconds |
| `learnings/*.yaml` | Captured patterns (Phase 2) | On task complete |

### 2.4 Component Wireframes

```
┌─────────────────────────────────────────────────────────────────┐
│  RALPHIE v1.0                              MODE: SEQUENTIAL     │
│  ════════════════════════════════════════════════════════════   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─ TASK QUEUE ──────────────────────┐  ┌─ METRICS ──────────┐ │
│  │                                    │  │                    │ │
│  │  ✓ C1  Add accessibility labels   │  │  Sessions: 26      │ │
│  │  ✓ C2  Create app icons           │  │  Tokens: 69K       │ │
│  │  → C3  Add consent dialog         │  │  Cost: $8.65       │ │
│  │  ○ H1  Fix font sizes             │  │  Success: 80%      │ │
│  │  ○ H2  Wire App Groups            │  │                    │ │
│  │                                    │  │  ▂▃▄▅▆▇█ Trend     │ │
│  │  3/15 complete                     │  │                    │ │
│  └────────────────────────────────────┘  └────────────────────┘ │
│                                                                 │
│  ┌─ LIVE PROGRESS ──────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  [14:32:45] → STARTING TASK C3                           │   │
│  │  [14:32:46] ✓ Read ConsentView.swift (0 lines - new)     │   │
│  │  [14:32:47] ✓ Read ClaudeWatchApp.swift (89 lines)       │   │
│  │  [14:32:48] → Creating ConsentView component...          │   │
│  │  [14:32:52] ✓ Wrote ConsentView.swift (127 lines)        │   │
│  │  [14:32:53] → Running verification...                    │   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                 │
│  [q] Quit  [p] Toggle Parallel View  [l] Show Learnings         │
└─────────────────────────────────────────────────────────────────┘
```

### 2.5 Parallel Mode View (When Active)

```
┌─────────────────────────────────────────────────────────────────┐
│  RALPHIE v1.0                              MODE: PARALLEL (3)   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─ WORKERS ────────────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  WORKER-1  [████████░░]  84%   C3 - Consent dialog       │   │
│  │  WORKER-2  [████░░░░░░]  42%   H1 - Font sizes           │   │
│  │  WORKER-3  [██████████] 100%   IDLE (waiting)            │   │
│  │                                                           │   │
│  │  Active Locks: Views/ConsentView.swift (W1)              │   │
│  │                Views/MainView.swift (W2)                 │   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                 │
│  ┌─ COORDINATION ───────────────────────────────────────────┐   │
│  │                                                           │   │
│  │  Queue Depth: 12 tasks remaining                         │   │
│  │  Current Group: 2 (Group 1 complete)                     │   │
│  │  Blocked Tasks: H2 (depends on C3)                       │   │
│  │                                                           │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 2.5: Patterns from External Ralph Implementations

### Research Insights

These patterns come from analyzing:
- `git@github.com:snarktank/ralph.git` - Simple, focused implementation
- `https://github.com/frankbria/ralph-claude-code` - Production-grade with 308 tests

### 2.5.1 Circuit Breaker Pattern (ADOPT)

**Source:** frankbria/ralph `lib/circuit_breaker.sh`

Prevents runaway token consumption by detecting stagnation:

```bash
# Circuit Breaker States
CB_STATE_CLOSED="CLOSED"        # Normal operation
CB_STATE_HALF_OPEN="HALF_OPEN"  # Monitoring for recovery
CB_STATE_OPEN="OPEN"            # Failure detected, halt

# Thresholds
CB_NO_PROGRESS_THRESHOLD=3      # Open after 3 loops with no progress
CB_SAME_ERROR_THRESHOLD=5       # Open after 5 loops with same error
CB_OUTPUT_DECLINE_THRESHOLD=70  # Open if output declines >70%
```

**TUI Integration:**
```
┌─ CIRCUIT BREAKER ─────────────────────────┐
│  State: CLOSED ✓                          │
│  No-progress loops: 0/3                   │
│  Same-error loops: 0/5                    │
│  Output trend: ▂▃▄▅▆ (healthy)            │
└───────────────────────────────────────────┘
```

**Recommendation:** Add circuit breaker state to TUI and implement in ralph.sh

### 2.5.2 Response Analyzer (ADOPT)

**Source:** frankbria/ralph `lib/response_analyzer.sh`

Semantic detection of completion vs. stuck states:

```bash
COMPLETION_KEYWORDS=("done" "complete" "finished" "all tasks complete")
TEST_ONLY_PATTERNS=("npm test" "bats" "pytest" "running tests")
NO_WORK_PATTERNS=("nothing to do" "no changes" "already implemented")
```

**Key insight:** Dual-condition EXIT check:
```bash
# WRONG: Exit on any completion indicator
if [[ "$status" == "COMPLETE" ]]; then exit; fi

# RIGHT: Require BOTH completion indicator AND explicit EXIT_SIGNAL
if [[ "$status" == "COMPLETE" && "$exit_signal" == "true" ]]; then exit; fi
```

**TUI Integration:** Show detected state (working/testing/stuck/complete)

### 2.5.3 Session Continuity (ADOPT)

**Source:** frankbria/ralph session management

Preserve context across loop iterations:

```bash
CLAUDE_SESSION_FILE=".claude_session_id"
CLAUDE_SESSION_EXPIRY_HOURS=24

# On each iteration
if should_resume_session; then
    claude --continue "$session_id" ...
else
    session_id=$(claude ... | extract_session_id)
    store_session_id "$session_id"
fi
```

**TUI Integration:** Show session age, continuity status

### 2.5.4 tmux Split-Pane Monitor (ALTERNATIVE)

**Source:** frankbria/ralph `ralph_monitor.sh`

Simpler alternative to React Ink - use tmux:

```bash
setup_tmux_session() {
    tmux new-session -d -s "ralph-$(date +%s)"
    tmux split-window -h  # Split horizontally
    tmux send-keys -t 0.1 "ralph-monitor" Enter  # Right: monitor
    tmux send-keys -t 0.0 "ralph" Enter          # Left: execution
    tmux attach-session
}
```

**Recommendation:** Offer BOTH options:
- `ralphie` - React Ink TUI (richer, more features)
- `ralph --monitor` - tmux split (simpler, lighter)

### 2.5.5 progress.txt Pattern (ADOPT)

**Source:** snarktank/ralph

Append-only learnings file for cross-iteration memory:

```bash
# After each iteration
echo "## Iteration $i - $(date)" >> progress.txt
echo "Task: $task_id" >> progress.txt
echo "Outcome: $outcome" >> progress.txt
echo "Learnings:" >> progress.txt
echo "$learnings" >> progress.txt
echo "---" >> progress.txt
```

**Key insight:** This IS our self-learning system, but simpler. Could start with progress.txt before full YAML learnings.

### 2.5.6 AGENTS.md Updates (ADOPT)

**Source:** snarktank/ralph

After each iteration, update AGENTS.md with discovered patterns:

```markdown
## Patterns Discovered
- This codebase uses X for Y
- Do not forget to update Z when changing W
- The settings panel is in component X
```

**Key insight:** This is automatic CLAUDE.md improvement. Very valuable.

### Summary: What to Adopt

| Pattern | Priority | Effort | Value |
|---------|----------|--------|-------|
| Circuit Breaker | HIGH | Medium | Prevents runaway costs |
| Response Analyzer | HIGH | Medium | Better exit detection |
| Session Continuity | MEDIUM | Small | Context preservation |
| tmux Alternative | LOW | Small | Simpler deployment |
| progress.txt | HIGH | Small | Quick win for learning |
| AGENTS.md Updates | HIGH | Small | Compounds over time |

---

## Part 3: Self-Learning Integration (Phase 2)

This is the real differentiator. Reference: `SELF-IMPROVING-SPEC.md`

### 3.1 Learning Capture (Backend - ralph.sh)

Add to `ralph.sh` after task completion:

```bash
capture_learnings() {
    local task_id="$1"
    local outcome="$2"  # success | failure

    # Use Claude to extract learnings from session
    cat <<EOF | claude --print > "$LEARNINGS_DIR/learning-${task_id}-$(date +%Y%m%d-%H%M%S).yaml"
Analyze this task execution and extract learnings.

Task: $task_id
Outcome: $outcome
Session Log: $(tail -100 "$SESSION_LOG")

Output YAML with:
- successes: [{pattern, category, reusable}]
- failures: [{pattern, lesson}]
- discoveries: [{description, category}]
EOF
}
```

### 3.2 Learnings Panel (TUI)

```
┌─ LEARNINGS ─────────────────────────────────────────────────┐
│                                                              │
│  Patterns Captured: 47                                       │
│  Categories: ios26 (15), swiftui (12), accessibility (8)     │
│                                                              │
│  Recent:                                                     │
│  ✓ "Use .glassEffect() not .thinMaterial" (ios26)           │
│  ✓ "Check SystemLanguageModel availability first" (fm)       │
│  ✗ "Tried deprecated API" → lesson captured                 │
│                                                              │
│  Skills Generated: 3                                         │
│  │ ios26-learned.md (15 patterns)                           │
│  │ swiftui-learned.md (12 patterns)                         │
│  │ accessibility-learned.md (8 patterns)                    │
│                                                              │
│  Next Aggregation: 2 tasks remaining                         │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

### 3.3 Skill Generation Flow

```
Task Complete
     │
     ▼
capture_learnings()
     │
     ▼
Store in learnings/learning-{task}-{ts}.yaml
     │
     ▼
Count patterns by category
     │
     ▼
If category count >= 3:
     │
     ▼
generate_skill() → .claude/commands/{category}-learned.md
     │
     ▼
TUI shows: "New skill generated: ios26-learned"
```

---

## Part 4: Implementation Phases

### Phase 1: Read-Only Monitor (MVP)

**Goal:** Replace `monitor-ralph.sh` with React Ink TUI

**Tasks:**
1. [ ] Initialize `ralphie-tui/` with React Ink + TypeScript
2. [ ] Implement file watchers for state files
3. [ ] Build core components: Header, TaskList, Metrics, LiveLog
4. [ ] Add TUIBox component matching existing ASCII style
5. [ ] Create `ralphie` CLI command
6. [ ] Test with actual Ralph execution

**Acceptance Criteria:**
- `npx ralphie` or `./ralphie-tui/bin/ralphie` launches TUI
- Shows real-time task progress from `current-progress.log`
- Displays metrics from `metrics.json`
- Updates when `tasks.yaml` changes
- Graceful handling when Ralph isn't running

**Effort:** 2-3 days

### Phase 2: Parallel Mode Display

**Goal:** Show worker status when `--parallel` is active

**Tasks:**
1. [ ] Detect parallel mode from `parallel/` directory existence
2. [ ] Watch `parallel/workers/*.status` files
3. [ ] Watch `parallel/locks/*.lock` files
4. [ ] Build WorkerStatus component
5. [ ] Add mode toggle keybinding

**Acceptance Criteria:**
- Automatically switches to parallel view when detected
- Shows worker progress bars
- Shows active file locks
- Shows blocked tasks

**Effort:** 1-2 days

### Phase 3: Self-Learning Backend

**Goal:** Implement `SELF-IMPROVING-SPEC.md` in `ralph.sh`

**Tasks:**
1. [ ] Create `learnings/` directory structure
2. [ ] Implement `capture_learnings()` function
3. [ ] Implement `aggregate_learnings()` function
4. [ ] Implement `generate_skill()` function
5. [ ] Implement `load_relevant_skills()` function
6. [ ] Add `--aggregate`, `--show-learnings` CLI options

**Acceptance Criteria:**
- Learnings captured after each task
- Aggregation runs every 5 tasks
- Skills generated when pattern threshold (3+) reached
- Skills loaded based on task tags

**Effort:** 3-4 days

### Phase 4: Learnings TUI Panel

**Goal:** Visualize self-improvement in TUI

**Tasks:**
1. [ ] Watch `learnings/` directory for changes
2. [ ] Parse aggregated learnings
3. [ ] Build LearningsPanel component
4. [ ] Show pattern categories and counts
5. [ ] Show generated skills
6. [ ] Add keybinding to toggle learnings view

**Acceptance Criteria:**
- Real-time update when learnings captured
- Shows pattern categories with counts
- Shows generated skills
- Shows "next aggregation" countdown

**Effort:** 1-2 days

---

## Part 5: Success Metrics

### Monitor Success
- [ ] TUI starts in <1 second
- [ ] Updates within 500ms of file change
- [ ] Memory usage <50MB
- [ ] Works over SSH (no special terminal requirements)

### Self-Learning Success
- [ ] 80%+ of task completions capture learnings
- [ ] At least 3 skills auto-generated after 20 tasks
- [ ] Token usage decreases by 10%+ after skills loaded
- [ ] Reduced failure rate on similar task types

---

## Part 6: Non-Goals

Things we're explicitly NOT building:

1. **Web Dashboard** - Terminal is the right UX
2. **Grouped Batching** - Claude handles naturally
3. **Sharding** - Wrong scale for this project
4. **Remote Control** - Read-only first, control later
5. **Multi-project Support** - Claude Watch only for now

---

## Appendix A: React Ink Starter

```tsx
// src/index.tsx
#!/usr/bin/env node
import React from 'react';
import { render } from 'ink';
import { App } from './App';

render(<App />);
```

```tsx
// src/App.tsx
import React from 'react';
import { Box, Text } from 'ink';
import { useRalphState } from './hooks/useRalphState';
import { Header } from './components/Header';
import { TaskList } from './components/TaskList';
import { Metrics } from './components/Metrics';
import { LiveLog } from './components/LiveLog';

export const App: React.FC = () => {
  const { tasks, metrics, progress, mode } = useRalphState();

  return (
    <Box flexDirection="column" padding={1}>
      <Header mode={mode} />
      <Box>
        <TaskList tasks={tasks} />
        <Metrics data={metrics} />
      </Box>
      <LiveLog lines={progress} />
    </Box>
  );
};
```

```tsx
// src/components/TUIBox.tsx
import React from 'react';
import { Box, Text } from 'ink';

interface TUIBoxProps {
  title?: string;
  children: React.ReactNode;
  width?: number;
}

export const TUIBox: React.FC<TUIBoxProps> = ({ title, children, width }) => (
  <Box
    flexDirection="column"
    borderStyle="single"
    borderColor="gray"
    width={width}
    padding={1}
  >
    {title && (
      <Box marginTop={-1} marginLeft={1}>
        <Text color="cyan" bold> {title} </Text>
      </Box>
    )}
    {children}
  </Box>
);
```

---

## Appendix B: File Watcher Hook

```tsx
// src/hooks/useRalphState.ts
import { useState, useEffect } from 'react';
import chokidar from 'chokidar';
import { readFileSync } from 'fs';
import { parse } from 'yaml';

const RALPH_DIR = process.env.RALPH_DIR || '.claude/ralph';

export function useRalphState() {
  const [tasks, setTasks] = useState([]);
  const [metrics, setMetrics] = useState({});
  const [progress, setProgress] = useState<string[]>([]);
  const [mode, setMode] = useState<'sequential' | 'parallel'>('sequential');

  useEffect(() => {
    const watcher = chokidar.watch([
      `${RALPH_DIR}/tasks.yaml`,
      `${RALPH_DIR}/metrics.json`,
      `${RALPH_DIR}/current-progress.log`,
      `${RALPH_DIR}/parallel/`,
    ], { ignoreInitial: false });

    watcher.on('change', (path) => {
      if (path.endsWith('tasks.yaml')) {
        const content = readFileSync(path, 'utf-8');
        const data = parse(content);
        setTasks(data.tasks || []);
      }
      if (path.endsWith('metrics.json')) {
        const content = readFileSync(path, 'utf-8');
        setMetrics(JSON.parse(content));
      }
      if (path.endsWith('current-progress.log')) {
        const content = readFileSync(path, 'utf-8');
        setProgress(content.split('\n').slice(-20));
      }
      if (path.includes('parallel/')) {
        setMode('parallel');
      }
    });

    return () => watcher.close();
  }, []);

  return { tasks, metrics, progress, mode };
}
```

---

## Appendix C: Existing Commands to Integrate

| Command | Purpose | Integration |
|---------|---------|-------------|
| `/ralph-it` | Run Ralph loop | TUI could spawn this |
| `/build` | Build watchOS | Show build status |
| `/fix-build` | Auto-fix builds | Trigger on failure |
| `/skill-harvesting` | Extract skills | After task complete |
| `/watchos-audit` | Audit code | Pre-task check |

---

## Decision Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-17 | Skip Grouped Batching | Claude handles naturally |
| 2026-01-17 | Skip Sharding | Wrong scale for 15-file project |
| 2026-01-17 | React Ink over bash | Better component model |
| 2026-01-17 | Read-only first | Simpler, safer, faster to ship |
| 2026-01-17 | Self-learning as Phase 3 | Real differentiator, needs backend first |
| 2026-01-17 | Adopt Circuit Breaker | frankbria/ralph proves value at scale |
| 2026-01-17 | Adopt progress.txt first | Simpler than full YAML learnings |
| 2026-01-17 | Offer tmux alternative | Not everyone wants Node.js dependency |

---

## Appendix D: Revised Implementation Phases (Post-Research)

Based on external Ralph implementations, here's the revised phasing:

### Phase 0: Quick Wins (1 day)

**Goal:** Adopt patterns that work immediately with minimal code

**Tasks:**
1. [ ] Add `progress.txt` capture to ralph.sh (snarktank pattern)
2. [ ] Add CLAUDE.md auto-update for discovered patterns
3. [ ] Add `--monitor` flag to spawn tmux split-pane view

**Files to create:**
```
.claude/ralph/progress.txt          # Append-only learnings
.claude/ralph/lib/progress.sh       # Helper functions
```

### Phase 1: Circuit Breaker + Response Analyzer (2 days)

**Goal:** Prevent runaway loops, better exit detection

**Tasks:**
1. [ ] Port `circuit_breaker.sh` from frankbria/ralph
2. [ ] Port `response_analyzer.sh` (simplified)
3. [ ] Add EXIT_SIGNAL dual-condition gate
4. [ ] Update monitor-ralph.sh to show circuit breaker state

**Files to create:**
```
.claude/ralph/lib/circuit_breaker.sh
.claude/ralph/lib/response_analyzer.sh
```

### Phase 2: React Ink TUI (2-3 days)

**Goal:** Rich terminal dashboard

**Tasks:**
1. [ ] Initialize ralphie-tui with React Ink
2. [ ] Port components from wireframes
3. [ ] Add circuit breaker panel
4. [ ] Add progress.txt viewer

### Phase 3: Self-Learning Backend (3-4 days)

**Goal:** Implement SELF-IMPROVING-SPEC.md

**Tasks:**
1. [ ] Evolve progress.txt to structured YAML
2. [ ] Add aggregation and skill generation
3. [ ] Add skill loading based on task tags

---

## Appendix E: Reference Implementations

### snarktank/ralph
- **Repo:** `git@github.com:snarktank/ralph.git`
- **Style:** Minimal, focused, 80-line loop
- **Key files:** `ralph.sh`, `prompt.md`, `prd.json`
- **Best for:** Understanding the core pattern

### frankbria/ralph-claude-code
- **Repo:** `https://github.com/frankbria/ralph-claude-code`
- **Style:** Production-grade, 308 tests
- **Key files:** `ralph_loop.sh`, `lib/circuit_breaker.sh`, `lib/response_analyzer.sh`
- **Best for:** Robustness patterns to adopt

---

**END OF PRD**
