# watchOS Ralph Loop - Complete Specification

> **Version:** 1.0.0
> **Platform:** watchOS 26+ / Swift 5.9+ / SwiftUI
> **Project:** Claude Watch
> **Created:** 2026-01-16

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Architecture Overview](#2-architecture-overview)
3. [Component Specifications](#3-component-specifications)
4. [Task Inventory](#4-task-inventory)
5. [Integration Matrix](#5-integration-matrix)
6. [Validation Harness](#6-validation-harness)
7. [Session Protocols](#7-session-protocols)
8. [watchOS Best Practices Enforcement](#8-watchos-best-practices-enforcement)
9. [Implementation Tasks](#9-implementation-tasks)
10. [Holistic Review](#10-holistic-review)

---

## 1. Executive Summary

### What is the watchOS Ralph Loop?

The Ralph Loop is an autonomous AI coding harness that runs Claude Code in a continuous loop, guided by structured prompts and task lists. This specification defines a **watchOS-specialized version** that:

- Understands watchOS 26, SwiftUI, and Apple's Liquid Glass design language
- Integrates with existing project skills, agents, and MCP servers
- Enforces Apple Human Interface Guidelines automatically
- Prevents deprecated API usage and accessibility violations
- Tracks progress with structured YAML tasks and metrics
- Supports both sequential and parallel execution modes

### Why watchOS-Specific?

Generic Ralph implementations lack:
- Knowledge of `WKApplication`, `WKExtension` deprecations
- Awareness of watchOS constraints (battery, screen size, connectivity)
- Integration with `xcodebuild` for watchOS Simulator
- Understanding of complications, Always-On Display, Digital Crown
- Enforcement of 11pt minimum fonts, 44x44pt touch targets
- Liquid Glass material adoption guidance

### Project Context

**Claude Watch** is a watchOS app providing a wearable interface for Claude Code:
- WebSocket real-time communication
- Actionable push notifications (APNs)
- Voice commands
- Watch face complications

**Current State:**
- Core architecture: Solid (WebSocket, notifications, state management)
- Deprecated APIs: Already replaced (WKExtension → WKApplication)
- App Store blockers: Icons, privacy policy, accessibility labels
- Design system: Needs Liquid Glass adoption for watchOS 26

---

## 2. Architecture Overview

### Directory Structure

```
.claude/ralph/
├── SPEC.md                   # This specification document
├── PROMPT.md                 # Core autonomous loop instructions
├── INITIALIZER.md            # First-run bootstrap prompt
├── tasks.yaml                # Structured task list with priorities
├── session-log.md            # Rolling session handoff notes
├── metrics.json              # Token/cost/duration tracking
├── ralph.sh                  # Main launch script
├── watchos-verify.sh         # watchOS validation harness
└── templates/
    ├── task-template.yaml    # Template for adding new tasks
    └── session-template.md   # Template for session logs
```

### Execution Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                       RALPH LOOP LIFECYCLE                          │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│  INITIALIZE  │────▶│   SESSION    │────▶│   HANDOFF    │
│  (first run) │     │    LOOP      │     │  (per iter)  │
└──────────────┘     └──────┬───────┘     └──────────────┘
                            │
                            ▼
              ┌─────────────────────────────┐
              │      SESSION ITERATION      │
              │                             │
              │  1. Read Progress State     │
              │  2. Select Next Task        │
              │  3. Research (read-only)    │
              │  4. Implement (code)        │
              │  5. Verify (build/test)     │
              │  6. Commit & Update         │
              │  7. Write Handoff Notes     │
              │                             │
              └─────────────────────────────┘
                            │
                            ▼
                    [Loop Repeats]
```

### Parallel Execution Mode

```
┌─────────────────────────────────────────────────────────────────────┐
│                    PARALLEL EXECUTION (Optional)                    │
└─────────────────────────────────────────────────────────────────────┘

Main Worktree                 Agent Worktrees (isolated)
─────────────                 ────────────────────────────
     │
     ├──▶ .worktrees/agent-1/ ──▶ ralph/agent-1-task-slug
     │         │
     │         └──▶ Task from parallel_group: 1
     │
     ├──▶ .worktrees/agent-2/ ──▶ ralph/agent-2-task-slug
     │         │
     │         └──▶ Task from parallel_group: 1
     │
     └──▶ Merge when group completes ──▶ Next parallel_group
```

---

## 3. Component Specifications

### 3.1 `ralph.sh` - Main Launch Script

**Purpose:** Orchestrate the Ralph Loop execution

**Features:**
| Feature | Description |
|---------|-------------|
| Engine selection | Claude Code via `claude` CLI |
| Sequential mode | Default: one task at a time |
| Parallel mode | `--parallel` with git worktrees |
| Retry logic | `--max-retries N` (default: 3) |
| Iteration limit | `--max-iterations N` |
| Branch-per-task | `--branch-per-task` creates feature branches |
| PR creation | `--create-pr` / `--draft-pr` |
| Dry run | `--dry-run` shows prompts without executing |
| Metrics | Token/cost tracking per session |
| Notifications | macOS notifications on completion |

**Interface:**
```bash
./ralph.sh [OPTIONS]

OPTIONS:
  -h, --help              Show help message
  -v, --verbose           Enable verbose output
  --dry-run               Show prompts without executing
  --parallel              Run multiple agents concurrently
  --max-parallel N        Max concurrent agents (default: 2)
  --max-iterations N      Limit total loop iterations
  --max-retries N         Retries per failed task (default: 3)
  --retry-delay N         Seconds between retries (default: 5)
  --branch-per-task       Create feature branches per task
  --create-pr             Auto-create PRs on task completion
  --draft-pr              Create draft PRs instead
  --base-branch NAME      Base branch for PRs (default: main)
  --init                  Run initializer instead of main loop
```

**Exit Codes:**
| Code | Meaning |
|------|---------|
| 0 | All tasks completed successfully |
| 1 | Task failed after max retries |
| 2 | Build failure |
| 3 | Verification failure |
| 130 | User interrupt (Ctrl+C) |

---

### 3.2 `tasks.yaml` - Task Definition Schema

**Purpose:** Structured task list with priorities, verification, and parallel grouping

**Schema:**
```yaml
# tasks.yaml - watchOS Ralph Loop Task Definition
version: "1.0"
project: "ClaudeWatch"
platform: "watchOS"
min_deployment: "10.6"
swift_version: "5.9"

# Global settings
settings:
  require_build_pass: true
  require_accessibility: true
  require_hig_compliance: true
  auto_liquid_glass: true

# Task definitions
tasks:
  - id: string              # Unique identifier (e.g., "C1", "UI-001")
    title: string           # Human-readable task name
    description: string     # Detailed description (optional)
    priority: enum          # "critical" | "high" | "medium" | "low"
    parallel_group: int     # Tasks in same group run concurrently
    completed: bool         # true if task is done

    # Verification
    verification: string    # Shell command that returns 0 on success
    acceptance_criteria:    # List of criteria (optional)
      - string

    # File targeting
    files:                  # Files to modify
      - string
    read_only_files:        # Files to read for context (optional)
      - string

    # Metadata
    tags:                   # Categorization tags
      - string
    estimated_tokens: int   # Expected token usage (optional)
    commit_template: string # Git commit message template (optional)

    # Dependencies
    depends_on:             # Task IDs that must complete first (optional)
      - string
    blocks:                 # Task IDs blocked by this task (optional)
      - string
```

**Example:**
```yaml
version: "1.0"
project: "ClaudeWatch"
platform: "watchOS"
min_deployment: "10.6"
swift_version: "5.9"

settings:
  require_build_pass: true
  require_accessibility: true
  require_hig_compliance: true
  auto_liquid_glass: true

tasks:
  # ═══════════════════════════════════════════════════════════════════
  # PHASE 1: CRITICAL (App Store Blockers)
  # ═══════════════════════════════════════════════════════════════════

  - id: "C1"
    title: "Add accessibility labels to all interactive elements"
    description: |
      Add .accessibilityLabel() modifiers to all Button, NavigationLink,
      and interactive elements in MainView.swift and SettingsView.swift.
    priority: critical
    parallel_group: 1
    completed: false
    verification: |
      grep -c 'accessibilityLabel' ClaudeWatch/Views/*.swift |
      awk -F: '{sum += $2} END {exit (sum >= 10 ? 0 : 1)}'
    acceptance_criteria:
      - "Every Button has .accessibilityLabel()"
      - "Every NavigationLink has .accessibilityLabel()"
      - "VoiceOver announces all elements correctly"
    files:
      - "ClaudeWatch/Views/MainView.swift"
      - "ClaudeWatch/Views/SettingsView.swift"
    tags: ["accessibility", "app-store", "hig"]
    commit_template: "fix(a11y): Add accessibility labels to {component}"

  - id: "C2"
    title: "Create app icon assets for all required sizes"
    description: |
      Generate PNG app icons for all 16 required watchOS sizes.
      Use SF Symbol 'brain.head.profile' or custom Claude logo.
    priority: critical
    parallel_group: 1
    completed: false
    verification: |
      ls ClaudeWatch/Assets.xcassets/AppIcon.appiconset/*.png | wc -l |
      awk '{exit ($1 >= 16 ? 0 : 1)}'
    acceptance_criteria:
      - "16 PNG files exist in AppIcon.appiconset"
      - "Icons render correctly in simulator"
      - "No placeholder images"
    files:
      - "ClaudeWatch/Assets.xcassets/AppIcon.appiconset/"
    tags: ["assets", "app-store"]
    commit_template: "feat(assets): Add watchOS app icons"

  - id: "C3"
    title: "Add AI data consent dialog"
    description: |
      Display consent dialog on first launch explaining:
      - Data sent to Claude API
      - Voice transcription handling
      - No data sold to third parties
    priority: critical
    parallel_group: 2
    completed: false
    depends_on: ["C1"]
    verification: |
      grep -q 'ConsentView\|onboardingComplete' ClaudeWatch/
    acceptance_criteria:
      - "Consent view shown on first launch"
      - "@AppStorage tracks consent state"
      - "User can review in Settings"
    files:
      - "ClaudeWatch/Views/ConsentView.swift"
      - "ClaudeWatch/App/ClaudeWatchApp.swift"
    tags: ["privacy", "app-store", "onboarding"]
    commit_template: "feat(privacy): Add AI data consent dialog"

  # ═══════════════════════════════════════════════════════════════════
  # PHASE 2: HIGH PRIORITY (Quality & Polish)
  # ═══════════════════════════════════════════════════════════════════

  - id: "H1"
    title: "Fix font sizes below 11pt minimum"
    description: |
      Replace hardcoded font sizes in ComplicationViews.swift with
      semantic styles. Ensure all text meets 11pt minimum.
    priority: high
    parallel_group: 3
    completed: false
    verification: |
      ! grep -E '\.font\(.*size:\s*([0-9]|10)\.' ClaudeWatch/
    acceptance_criteria:
      - "No font sizes below 11pt"
      - "Use semantic styles (.caption, .footnote)"
      - "Complications remain readable"
    files:
      - "ClaudeWatch/Complications/ComplicationViews.swift"
    tags: ["hig", "typography", "accessibility"]
    commit_template: "fix(ui): Ensure minimum 11pt font sizes"

  - id: "H2"
    title: "Wire App Groups for complication data sharing"
    description: |
      Configure App Groups entitlement and use UserDefaults(suiteName:)
      for sharing state between app and complications.
    priority: high
    parallel_group: 3
    completed: false
    verification: |
      grep -q 'group.com.edgeoftrust.claudewatch' ClaudeWatch/*.entitlements
    acceptance_criteria:
      - "App Groups entitlement configured"
      - "Complications read shared state"
      - "State persists across app launches"
    files:
      - "ClaudeWatch/ClaudeWatch.entitlements"
      - "ClaudeWatch/Services/WatchService.swift"
      - "ClaudeWatch/Complications/ComplicationViews.swift"
    tags: ["entitlements", "complications", "state"]
    commit_template: "feat(complications): Wire App Groups for data sharing"

  - id: "H3"
    title: "Add recording indicator for voice input"
    description: |
      Show visual indicator when microphone is active for voice commands.
      Required by App Store guidelines.
    priority: high
    parallel_group: 3
    completed: false
    verification: |
      grep -q 'isRecording\|RecordingIndicator' ClaudeWatch/Views/
    acceptance_criteria:
      - "Red dot or pulsing indicator during recording"
      - "Indicator visible in all lighting conditions"
      - "Haptic feedback on start/stop"
    files:
      - "ClaudeWatch/Views/MainView.swift"
      - "ClaudeWatch/Views/Components/RecordingIndicator.swift"
    tags: ["voice", "privacy", "app-store"]
    commit_template: "feat(voice): Add recording indicator"

  # ═══════════════════════════════════════════════════════════════════
  # PHASE 3: MEDIUM PRIORITY (Enhancement)
  # ═══════════════════════════════════════════════════════════════════

  - id: "M1"
    title: "Implement Digital Crown support"
    description: |
      Add .digitalCrownRotation() for scrolling lists and adjusting values.
      Provide haptic feedback on detent boundaries.
    priority: medium
    parallel_group: 4
    completed: false
    verification: |
      grep -q 'digitalCrownRotation\|DigitalCrown' ClaudeWatch/Views/
    acceptance_criteria:
      - "Crown scrolls message history"
      - "Haptic feedback on boundaries"
      - "Smooth rotation feel"
    files:
      - "ClaudeWatch/Views/MainView.swift"
    tags: ["hig", "input", "haptics"]
    commit_template: "feat(input): Add Digital Crown support"

  - id: "M2"
    title: "Add Always-On Display support"
    description: |
      Detect .isLuminanceReduced environment and show simplified UI.
      Reduce colors, hide animations, show essential info only.
    priority: medium
    parallel_group: 4
    completed: false
    verification: |
      grep -q 'isLuminanceReduced' ClaudeWatch/Views/
    acceptance_criteria:
      - "Simplified UI in always-on mode"
      - "No bright colors or animations"
      - "Connection status always visible"
    files:
      - "ClaudeWatch/Views/MainView.swift"
      - "ClaudeWatch/Complications/ComplicationViews.swift"
    tags: ["always-on", "hig", "battery"]
    commit_template: "feat(display): Add Always-On Display support"

  - id: "M3"
    title: "Add Dynamic Type support"
    description: |
      Use .dynamicTypeSize environment and prefer semantic fonts.
      Test with all accessibility sizes.
    priority: medium
    parallel_group: 4
    completed: false
    verification: |
      grep -q 'dynamicTypeSize\|@ScaledMetric' ClaudeWatch/Views/
    acceptance_criteria:
      - "Text scales with system setting"
      - "Layout adapts to larger sizes"
      - "No text truncation at largest size"
    files:
      - "ClaudeWatch/Views/MainView.swift"
      - "ClaudeWatch/Views/SettingsView.swift"
    tags: ["accessibility", "typography", "hig"]
    commit_template: "feat(a11y): Add Dynamic Type support"

  # ═══════════════════════════════════════════════════════════════════
  # PHASE 4: WATCHOS 26 / LIQUID GLASS
  # ═══════════════════════════════════════════════════════════════════

  - id: "LG1"
    title: "Adopt Liquid Glass materials"
    description: |
      Replace .opacity() backgrounds with .glassBackgroundEffect().
      Update to translucent, depth-aware UI components.
    priority: medium
    parallel_group: 5
    completed: false
    verification: |
      grep -q 'glassBackgroundEffect\|\.glass' ClaudeWatch/Views/
    acceptance_criteria:
      - "Glass materials on primary containers"
      - "Proper light refraction effects"
      - "Fallback for older watchOS versions"
    files:
      - "ClaudeWatch/Views/MainView.swift"
      - "ClaudeWatch/Views/Components/"
    tags: ["liquid-glass", "watchos26", "design"]
    commit_template: "feat(design): Adopt Liquid Glass materials"

  - id: "LG2"
    title: "Add spring animations"
    description: |
      Replace linear animations with .spring() for natural feel.
      Use .interpolatingSpring() for interactive elements.
    priority: low
    parallel_group: 5
    completed: false
    verification: |
      grep -q '\.spring\|interpolatingSpring' ClaudeWatch/Views/
    acceptance_criteria:
      - "Buttons use spring animations"
      - "Transitions feel natural"
      - "No jarring motion"
    files:
      - "ClaudeWatch/Views/MainView.swift"
    tags: ["animation", "liquid-glass", "hig"]
    commit_template: "feat(animation): Add spring animations"

  # ═══════════════════════════════════════════════════════════════════
  # PHASE 5: TESTING & DOCUMENTATION
  # ═══════════════════════════════════════════════════════════════════

  - id: "T1"
    title: "Add UI tests for critical flows"
    description: |
      Create XCUITest cases for:
      - Connection flow
      - Approval/rejection
      - Settings navigation
    priority: medium
    parallel_group: 6
    completed: false
    verification: |
      ls ClaudeWatch/Tests/UI*.swift 2>/dev/null | wc -l |
      awk '{exit ($1 >= 1 ? 0 : 1)}'
    acceptance_criteria:
      - "UI tests for main flow"
      - "Tests pass on simulator"
      - "Coverage > 60%"
    files:
      - "ClaudeWatch/Tests/UITests/"
    tags: ["testing", "quality"]
    commit_template: "test(ui): Add UI tests for critical flows"

  - id: "T2"
    title: "Update Swift version to 5.9+"
    description: |
      Update SWIFT_VERSION in project.pbxproj from 5.0 to 5.9.
      Enable strict concurrency checking.
    priority: high
    parallel_group: 3
    completed: false
    verification: |
      grep -q 'SWIFT_VERSION = 5.9' ClaudeWatch.xcodeproj/project.pbxproj
    acceptance_criteria:
      - "Swift 5.9 in build settings"
      - "No compilation warnings"
      - "Strict concurrency enabled"
    files:
      - "ClaudeWatch.xcodeproj/project.pbxproj"
    tags: ["build", "swift", "quality"]
    commit_template: "build: Update Swift version to 5.9"
```

---

### 3.3 `PROMPT.md` - Core Loop Instructions

**Purpose:** The prompt that guides each iteration of the Ralph Loop

**Structure:**
```markdown
# watchOS Ralph Loop - Autonomous Coding Agent

## Identity & Expertise
[watchOS/SwiftUI expert persona with specific knowledge areas]

## Session Start Protocol
[Steps to read state, select task, announce intent]

## Research Protocol
[How to gather context before coding]

## Implementation Protocol
[How to make changes, patterns to follow]

## Verification Protocol
[Build, test, validate steps]

## watchOS Guardrails
[Deprecated APIs, required patterns, HIG rules]

## Handoff Protocol
[How to update state, commit, log]

## Failure Handling
[Retry logic, escalation, blocking]
```

**Key Sections:**

#### Identity & Expertise
```markdown
You are an expert watchOS/SwiftUI developer working autonomously on the
Claude Watch project. You have deep knowledge of:

- watchOS 26 and Liquid Glass design language
- SwiftUI state management (@Observable, @State, @Environment)
- Swift Concurrency (async/await, actors, Sendable)
- WKApplication lifecycle and background tasks
- UNUserNotificationCenter and APNs
- Watch face complications (WidgetKit)
- Apple Human Interface Guidelines for watchOS
- Accessibility (VoiceOver, Dynamic Type, reduced motion)

You have access to these specialized agents:
- watchos-architect: System design and architecture decisions
- swiftui-specialist: Complex UI implementation
- swift-reviewer: Code quality review
- websocket-expert: Real-time communication

You have access to these skills:
- /build: Compile for watchOS Simulator
- /fix-build: Diagnose and fix build errors
- /watchos-audit: Audit against HIG guidelines
- /apple-review: Code review against Apple best practices
- /run-app: Launch app on simulator
```

#### watchOS Guardrails
```markdown
## watchOS Guardrails

### NEVER Use (Deprecated)
- `WKExtension.shared()` → Use `WKApplication.shared()`
- `presentTextInputController()` → Use SwiftUI TextField
- `WKInterfaceController` → Use SwiftUI views
- `WKAlertAction` → Use SwiftUI .alert()
- Polling loops → Use async/await with proper lifecycle

### ALWAYS Do
- Add `.accessibilityLabel()` to ALL interactive elements
- Use minimum 11pt font sizes (prefer semantic: .caption, .footnote)
- Support Always-On Display via `@Environment(\.isLuminanceReduced)`
- Handle offline states gracefully
- Use `.digitalCrownRotation()` for scrollable content
- Add haptic feedback for user actions (`WKInterfaceDevice.current().play()`)
- Support Dynamic Type via `@ScaledMetric` or semantic fonts

### Human Interface Guidelines
- Touch targets: minimum 44x44 points
- Glanceable information: user should understand in <2 seconds
- Progressive disclosure: show essential info first
- Respect system settings: reduce motion, bold text, larger text

### Liquid Glass (watchOS 26+)
- Use `.glassBackgroundEffect()` for translucent containers
- Avoid harsh shadows, prefer subtle depth
- Use spring animations for natural feel
- Ensure legibility with proper contrast ratios
```

---

### 3.4 `INITIALIZER.md` - Bootstrap Prompt

**Purpose:** First-run setup that creates initial state

**Actions:**
1. Validate environment (Xcode version, simulators, Swift)
2. Create `tasks.yaml` from existing TASKS.md
3. Initialize `session-log.md`
4. Initialize `metrics.json`
5. Run baseline `/build` to verify project compiles
6. Run `/watchos-audit` for initial assessment
7. Commit initialization state

---

### 3.5 `watchos-verify.sh` - Validation Harness

**Purpose:** watchOS-specific verification script

**Checks:**
| Check | Command | Pass Criteria |
|-------|---------|---------------|
| Build | `xcodebuild` | Exit code 0 |
| Deprecated APIs | `grep -r` | No matches |
| Accessibility | `grep accessibilityLabel` | Count >= threshold |
| Font sizes | `grep -E size:` | None < 11pt |
| Touch targets | Static analysis | >= 44pt |
| Liquid Glass | `grep glass` | Present (optional) |

---

### 3.6 `metrics.json` - Progress Tracking

**Schema:**
```json
{
  "version": "1.0",
  "project": "ClaudeWatch",
  "initialized": "2026-01-16T00:00:00Z",
  "lastSession": "2026-01-16T12:00:00Z",
  "totalSessions": 0,
  "totalTokens": {
    "input": 0,
    "output": 0
  },
  "estimatedCost": 0.00,
  "tasksCompleted": 0,
  "tasksFailed": 0,
  "totalRetries": 0,
  "buildFailures": 0,
  "sessions": [
    {
      "id": "session-001",
      "timestamp": "2026-01-16T12:00:00Z",
      "taskId": "C1",
      "status": "completed",
      "tokens": { "input": 5000, "output": 2000 },
      "duration": 120,
      "retries": 0
    }
  ]
}
```

---

### 3.7 `session-log.md` - Handoff Notes

**Purpose:** Rolling log for session handoffs

**Format:**
```markdown
# Session Log

## Session 001 - 2026-01-16 12:00 UTC

**Task:** C1 - Add accessibility labels to all interactive elements
**Status:** COMPLETED
**Duration:** 2 minutes
**Tokens:** 5,000 in / 2,000 out

### What Was Done
- Added .accessibilityLabel() to 12 buttons in MainView.swift
- Added .accessibilityLabel() to 5 navigation links in SettingsView.swift
- Verified with VoiceOver in simulator

### Verification Results
- Build: PASS
- Accessibility count: 17 (threshold: 10)
- /watchos-audit: PASS

### Commit
`abc1234` - fix(a11y): Add accessibility labels to MainView and SettingsView

### Notes for Next Session
- Consider adding .accessibilityHint() for complex actions
- ComplicationViews.swift still needs accessibility work

---

## Session 002 - 2026-01-16 12:30 UTC
...
```

---

## 4. Task Inventory

### Task Summary by Phase

| Phase | Priority | Tasks | Description |
|-------|----------|-------|-------------|
| 1 | Critical | 3 | App Store blockers (accessibility, icons, consent) |
| 2 | High | 4 | Quality & polish (fonts, App Groups, recording indicator, Swift version) |
| 3 | Medium | 3 | Enhancement (Digital Crown, Always-On, Dynamic Type) |
| 4 | Medium/Low | 2 | watchOS 26 / Liquid Glass adoption |
| 5 | Medium | 2 | Testing & documentation |

### Parallel Groups

| Group | Tasks | Can Run Concurrently |
|-------|-------|---------------------|
| 1 | C1, C2 | Yes |
| 2 | C3 | No (depends on C1) |
| 3 | H1, H2, H3, T2 | Yes |
| 4 | M1, M2, M3 | Yes |
| 5 | LG1, LG2 | Yes |
| 6 | T1 | Yes |

### Dependency Graph

```
C1 (accessibility) ──┬──▶ C3 (consent dialog)
                     │
C2 (app icons) ──────┘

H1, H2, H3, T2 run in parallel (no dependencies)

M1, M2, M3 run in parallel (no dependencies)

LG1, LG2 run in parallel (no dependencies)

T1 (UI tests) runs last (validates all features)
```

---

## 5. Integration Matrix

### Existing Infrastructure Integration

| Component | Type | Ralph Integration |
|-----------|------|-------------------|
| `/build` | Skill | Called after every implementation |
| `/fix-build` | Skill | Called when build fails |
| `/watchos-audit` | Skill | Verification before marking complete |
| `/apple-review` | Skill | Pre-commit code review |
| `/run-app` | Skill | Launch for manual verification |
| `/liquid-glass` | Skill | Liquid Glass design audit |
| `watchos-architect` | Agent | Architecture decisions |
| `swiftui-specialist` | Agent | Complex UI implementation |
| `swift-reviewer` | Agent | Code quality review |
| `websocket-expert` | Agent | WebSocket issues |
| `notification-expert` | Agent | Push notification work |
| `watchos-testing` | Agent | Test implementation |
| `apple-docs` MCP | Server | API documentation lookup |
| `xcodebuild` MCP | Server | Build automation |
| `session-start.sh` | Hook | Environment display |
| `post-swift-edit.sh` | Hook | Auto-lint on edit |
| `file-protection.sh` | Hook | Protect sensitive files |

### MCP Server Usage

| Server | Purpose | When Used |
|--------|---------|-----------|
| `apple-docs` | Look up API documentation | Research phase |
| `xcodebuild` | Build automation | Verification phase |
| `watch` | Local Python server | Testing connectivity |

---

## 6. Validation Harness

### Pre-Implementation Checks

| Check | Tool | Purpose |
|-------|------|---------|
| Git status clean | `git status` | No uncommitted changes |
| Base branch up-to-date | `git fetch` | Latest code |
| Simulator available | `xcrun simctl list` | Can build/test |
| MCP servers running | `curl localhost:8787` | Optional |

### Post-Implementation Checks

| Check | Tool | Pass Criteria |
|-------|------|---------------|
| Build succeeds | `/build` | Exit 0, no errors |
| No warnings | `xcodebuild` | Warning count = 0 |
| No deprecated APIs | `grep -r` | No matches |
| Accessibility present | `grep accessibilityLabel` | >= threshold |
| Font sizes valid | `grep -E 'size:'` | All >= 11 |
| Task verification | `task.verification` | Exit 0 |
| Code review | `/apple-review` | No critical issues |

### Verification Script Flow

```bash
#!/bin/bash
# watchos-verify.sh

set -e  # Exit on any failure

echo "=== watchOS Verification Harness ==="

# 1. Build Check
echo "→ Building for watchOS Simulator..."
if ! xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)' \
  build 2>&1 | tee /tmp/build.log | tail -5; then
  echo "✗ Build FAILED"
  exit 2
fi
echo "✓ Build passed"

# 2. Deprecation Check
echo "→ Checking for deprecated APIs..."
DEPRECATED=("WKExtension.shared" "presentTextInputController" "WKInterfaceController")
for api in "${DEPRECATED[@]}"; do
  if grep -r "$api" ClaudeWatch/ --include="*.swift" > /dev/null 2>&1; then
    echo "✗ Found deprecated API: $api"
    exit 3
  fi
done
echo "✓ No deprecated APIs found"

# 3. Accessibility Check
echo "→ Checking accessibility labels..."
LABEL_COUNT=$(grep -r 'accessibilityLabel' ClaudeWatch/Views/ --include="*.swift" | wc -l)
if [ "$LABEL_COUNT" -lt 10 ]; then
  echo "⚠ Warning: Only $LABEL_COUNT accessibility labels found (target: 10+)"
fi
echo "✓ Accessibility labels: $LABEL_COUNT"

# 4. Font Size Check
echo "→ Checking font sizes..."
if grep -rE '\.font\(.*size:\s*([0-9])\.' ClaudeWatch/ --include="*.swift" | grep -v 'size: 1[0-9]'; then
  echo "⚠ Warning: Found font sizes below 10pt"
fi
echo "✓ Font sizes checked"

# 5. Task-Specific Verification
if [ -n "$TASK_VERIFICATION" ]; then
  echo "→ Running task verification: $TASK_VERIFICATION"
  if ! eval "$TASK_VERIFICATION"; then
    echo "✗ Task verification FAILED"
    exit 3
  fi
  echo "✓ Task verification passed"
fi

echo "=== All Checks Passed ==="
exit 0
```

---

## 7. Session Protocols

### Session Start Protocol

```markdown
## Session Start Protocol

1. **Verify Environment**
   - Run `pwd` to confirm working directory is `/home/user/claude-watch`
   - Check git status for clean working tree

2. **Read Progress State**
   - Read `.claude/ralph/tasks.yaml` for task list
   - Read `.claude/ralph/session-log.md` for context from last session
   - Read `.claude/ralph/metrics.json` for cumulative progress

3. **Select Next Task**
   - Find lowest `parallel_group` with incomplete tasks
   - Within group, select highest `priority` task
   - If task has `depends_on`, verify dependencies completed

4. **Announce Intent**
   - Output: "Starting task: {id} - {title}"
   - Output: "Priority: {priority}, Group: {parallel_group}"
   - Output: "Files: {files}"
```

### Research Protocol

```markdown
## Research Protocol (Read-Only)

1. **Read Target Files**
   - Read all files listed in `task.files`
   - Read any files in `task.read_only_files`

2. **Understand Context**
   - Check existing patterns in the file
   - Look for related code in adjacent files
   - Note any existing accessibility/HIG implementations

3. **Consult Documentation**
   - Use `apple-docs` MCP for API guidance if needed
   - Check `.claude/WWDC2025-WATCHOS26.md` for deprecation info

4. **Consult Agents (if needed)**
   - Architecture questions → `watchos-architect` agent
   - Complex UI → `swiftui-specialist` agent
   - WebSocket issues → `websocket-expert` agent
```

### Implementation Protocol

```markdown
## Implementation Protocol

1. **Plan Changes**
   - Identify exact locations for modifications
   - Plan minimal, focused changes for THIS TASK ONLY
   - Do not refactor unrelated code

2. **Make Changes**
   - Edit files using Edit tool
   - Follow existing code style and patterns
   - Add accessibility modifiers where required
   - Use modern APIs (no deprecated)

3. **Verify Incrementally**
   - After significant changes, run `/build`
   - Fix any compilation errors immediately
   - Don't accumulate errors
```

### Verification Protocol

```markdown
## Verification Protocol

1. **Build Check**
   - Run `/build` skill
   - If fails, run `/fix-build` skill
   - Maximum 3 attempts to fix build

2. **Run Task Verification**
   - Execute `task.verification` command
   - Must return exit code 0

3. **Run Audit**
   - Run `/watchos-audit` for HIG compliance
   - Address any critical issues

4. **Code Review**
   - Run `/apple-review` for quality check
   - Address any critical issues
```

### Handoff Protocol

```markdown
## Handoff Protocol

1. **Update Task Status**
   - Set `completed: true` in tasks.yaml
   - Only if ALL verification passed

2. **Commit Changes**
   - Use `task.commit_template` or generate appropriate message
   - Format: `type(scope): description`
   - Include task ID in commit body

3. **Update Session Log**
   - Append session details to session-log.md
   - Document what was done, verification results
   - Note any issues for next session

4. **Update Metrics**
   - Record tokens used
   - Record duration
   - Increment counters
```

### Failure Handling

```markdown
## Failure Handling

### Build Failure
1. Run `/fix-build` skill
2. Retry build (max 3 attempts)
3. If still failing, document in session-log.md
4. Do NOT mark task as completed
5. Move to next task or exit

### Verification Failure
1. Review failure output
2. Make corrective changes
3. Retry verification (max 3 attempts)
4. If still failing, document blocker
5. Do NOT mark task as completed

### Agent/Tool Failure
1. Retry once with backoff
2. If still failing, proceed without
3. Document limitation in session-log.md

### Context Exhaustion
1. Commit current progress
2. Update session-log.md with state
3. Exit cleanly for loop restart
```

---

## 8. watchOS Best Practices Enforcement

### Apple Human Interface Guidelines Compliance

| Guideline | Enforcement | Verification |
|-----------|-------------|--------------|
| 44x44pt touch targets | Code review | Static analysis |
| 11pt minimum fonts | Guardrails in prompt | Grep check |
| Accessibility labels | Guardrails + verification | Count threshold |
| Glanceable design | Code review | Manual audit |
| Digital Crown support | Task requirement | Grep check |
| Always-On Display | Task requirement | Grep check |
| Dynamic Type | Task requirement | Grep check |
| Haptic feedback | Code review | Grep check |

### Swift/SwiftUI Best Practices

| Practice | Enforcement | Verification |
|----------|-------------|--------------|
| @Observable for models | Pattern in prompt | Code review |
| async/await for async | Guardrails | No completion handlers |
| @Environment injection | Pattern in prompt | Code review |
| View < 100 lines | Guideline | Static analysis |
| guard for early exit | Code review | Pattern matching |
| Value types preferred | Code review | Class audit |

### watchOS 26 / Liquid Glass

| Feature | Enforcement | Verification |
|---------|-------------|--------------|
| .glassBackgroundEffect() | Task + guideline | Grep check |
| Spring animations | Task + guideline | Grep check |
| Translucent materials | Design review | Manual audit |
| Proper depth | Design review | Manual audit |

### Deprecation Prevention

| Deprecated API | Replacement | Detection |
|----------------|-------------|-----------|
| `WKExtension.shared()` | `WKApplication.shared()` | Grep |
| `presentTextInputController()` | SwiftUI TextField | Grep |
| `WKInterfaceController` | SwiftUI View | Grep |
| `WKAlertAction` | SwiftUI .alert() | Grep |
| `WKInterfaceDevice.current().play(_:)` | WKInterfaceDevice haptic | Pattern |

---

## 9. Implementation Tasks

### Phase 1: Core Infrastructure (Create Files)

| ID | Task | File | Priority |
|----|------|------|----------|
| R1 | Create ralph.sh launch script | `.claude/ralph/ralph.sh` | P0 |
| R2 | Create PROMPT.md core instructions | `.claude/ralph/PROMPT.md` | P0 |
| R3 | Create INITIALIZER.md bootstrap | `.claude/ralph/INITIALIZER.md` | P0 |
| R4 | Create tasks.yaml from spec | `.claude/ralph/tasks.yaml` | P0 |
| R5 | Create watchos-verify.sh | `.claude/ralph/watchos-verify.sh` | P0 |
| R6 | Create session-log.md template | `.claude/ralph/session-log.md` | P1 |
| R7 | Create metrics.json initial | `.claude/ralph/metrics.json` | P1 |
| R8 | Create task-template.yaml | `.claude/ralph/templates/task-template.yaml` | P2 |

### Phase 2: Integration

| ID | Task | Description | Priority |
|----|------|-------------|----------|
| I1 | Test /build integration | Verify skill works in loop | P0 |
| I2 | Test /fix-build integration | Verify error recovery | P0 |
| I3 | Test /watchos-audit integration | Verify audit runs | P1 |
| I4 | Test agent invocation | Verify agents respond | P1 |
| I5 | Test MCP server access | Verify apple-docs works | P2 |

### Phase 3: Validation

| ID | Task | Description | Priority |
|----|------|-------------|----------|
| V1 | Dry run single session | Test without execution | P0 |
| V2 | Execute single session | Complete one task | P0 |
| V3 | Test retry logic | Simulate failure | P1 |
| V4 | Test parallel mode | Run two agents | P2 |
| V5 | Test full loop | Multiple iterations | P1 |

### Phase 4: Documentation

| ID | Task | Description | Priority |
|----|------|-------------|----------|
| D1 | Update CLAUDE.md | Add Ralph Loop section | P1 |
| D2 | Create README for ralph/ | Usage documentation | P1 |
| D3 | Add troubleshooting guide | Common issues | P2 |

---

## 10. Holistic Review

### Alignment with Ralph Loop Principles

| Principle | Implementation | Status |
|-----------|----------------|--------|
| **Structured task lists** | tasks.yaml with YAML schema | Aligned |
| **Single-task focus** | Prompt enforces one task per session | Aligned |
| **Verification before completion** | Multi-stage verification pipeline | Aligned |
| **Session handoff** | session-log.md + metrics.json | Aligned |
| **Git-based state** | Commits after each task | Aligned |
| **Retry with backoff** | Configurable in ralph.sh | Aligned |
| **Parallel execution** | Git worktrees + parallel_group | Aligned |

### Alignment with Apple Ecosystem (2026)

| Apple Requirement | Implementation | Status |
|-------------------|----------------|--------|
| **watchOS 26 SDK** | Build target, verification | Ready |
| **Liquid Glass** | Tasks LG1, LG2 + guardrails | Planned |
| **Swift 5.9+** | Task T2, verification | Planned |
| **Accessibility** | Task C1, guardrails, verification | Enforced |
| **64-bit support** | Standard Xcode architectures | Ready |
| **HIG compliance** | Guardrails + /watchos-audit | Enforced |
| **App Store requirements** | Tasks C1-C3, H3 | Planned |

### Alignment with Claude Watch Project

| Project Need | Ralph Solution | Status |
|--------------|----------------|--------|
| **App Store submission** | Phase 1-2 critical tasks | Planned |
| **Code quality** | /apple-review, swift-reviewer | Integrated |
| **Build stability** | /build, /fix-build skills | Integrated |
| **WebSocket reliability** | websocket-expert agent | Available |
| **Notification handling** | notification-expert agent | Available |
| **Existing hooks** | session-start, post-swift-edit | Preserved |

### Risk Assessment

| Risk | Mitigation |
|------|------------|
| Context exhaustion mid-task | Commit checkpoints, session-log handoff |
| Build failures blocking progress | /fix-build skill, skip and document |
| Incorrect task completion | Multi-stage verification, acceptance criteria |
| Deprecated API introduction | Guardrails + grep verification |
| Parallel merge conflicts | AI-assisted conflict resolution |
| Xcode/simulator issues | Pre-flight checks in session start |

### Recommended Execution Order

1. **Create core files** (R1-R5) - Foundation
2. **Test single session** (V1-V2) - Validate loop works
3. **Complete Phase 1 tasks** - App Store blockers
4. **Enable parallel mode** - Faster execution
5. **Complete Phase 2-3 tasks** - Quality polish
6. **Adopt Liquid Glass** - watchOS 26 readiness
7. **Add UI tests** - Quality assurance

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Tasks completed per hour | 2-4 | metrics.json |
| Build success rate | > 90% | metrics.json |
| First-attempt task success | > 70% | metrics.json |
| Token efficiency | < 10K per task | metrics.json |
| Zero deprecated APIs | 0 matches | verification |
| Accessibility compliance | 100% | /watchos-audit |

---

## Appendix A: Command Reference

```bash
# Initialize Ralph Loop (first time)
./.claude/ralph/ralph.sh --init

# Run single session
cat .claude/ralph/PROMPT.md | claude --print

# Run autonomous loop
./.claude/ralph/ralph.sh

# Run with parallel execution
./.claude/ralph/ralph.sh --parallel --max-parallel 2

# Run with PR creation
./.claude/ralph/ralph.sh --branch-per-task --create-pr

# Dry run (preview only)
./.claude/ralph/ralph.sh --dry-run

# Run verification manually
./.claude/ralph/watchos-verify.sh

# View progress
cat .claude/ralph/metrics.json | jq '.tasksCompleted, .tasksFailed'

# View session history
tail -100 .claude/ralph/session-log.md
```

---

## Appendix B: Sources

- [Effective Harnesses for Long-Running Agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents)
- [iOS 26 Developer Guide](https://www.index.dev/blog/ios-26-developer-guide)
- [What's New in SwiftUI - WWDC25](https://wwdcnotes.com/documentation/wwdcnotes/wwdc25-256-whats-new-in-swiftui/)
- [Designing for watchOS - Apple HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-watchos)
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [ralphy-swift Repository](https://github.com/fotescodev/ralphy-swift)

---

*Specification complete. Ready for implementation.*
