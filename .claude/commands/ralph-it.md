# Ralph Loop - Verbose Task Execution

Execute tasks from `tasks.yaml` in a continuous loop with verbose output.

## Usage

```bash
/ralph-it          # Run until all tasks complete
/ralph-it 3        # Run exactly 3 tasks then stop
```

## Loop Execution

### Before Each Task

```
╔══════════════════════════════════════════════════════════════╗
║                    RALPH LOOP STATUS                         ║
╠══════════════════════════════════════════════════════════════╣
║  Tasks Remaining: [count]                                    ║
║  Tasks Completed This Session: [count]                       ║
║  Current Time: [timestamp]                                   ║
╚══════════════════════════════════════════════════════════════╝
```

### Execute Task

Follow the full Ralph workflow from `.claude/ralph/PROMPT.md`:

1. **Phase 0**: Task Selection & Clarification
2. **Phase 1**: Context Gathering
3. **Phase 2**: Execute the Task (with Xcode sync if needed)
4. **Phase 3**: Quality Gate (build must pass)
5. **Phase 4**: Complete & Ship (commit)

### After Each Task

```
╔══════════════════════════════════════════════════════════════╗
║                    TASK COMPLETED                            ║
╠══════════════════════════════════════════════════════════════╣
║  ID: [task_id]                                               ║
║  Title: [title]                                              ║
║  Duration: [time]                                            ║
║  Files Changed: [count]                                      ║
║  Build: PASSED                                               ║
║  Commit: [hash]                                              ║
╚══════════════════════════════════════════════════════════════╝

Proceeding to next task...
```

### Loop Termination

Stop the loop when:
- All tasks in `tasks.yaml` are `completed: true`
- Reached the task limit (if specified)
- Build fails and cannot be fixed after 3 attempts
- User interrupts

### Final Summary

```
╔══════════════════════════════════════════════════════════════╗
║                    RALPH SESSION COMPLETE                    ║
╠══════════════════════════════════════════════════════════════╣
║  Tasks Completed: [count]                                    ║
║  Tasks Remaining: [count]                                    ║
║  Total Commits: [count]                                      ║
║  Session Duration: [time]                                    ║
╚══════════════════════════════════════════════════════════════╝

Commits this session:
- [hash] [message]
- [hash] [message]
```

## Verbose Mode Features

Throughout execution, provide:

1. **File reads**: Show which files are being read and why
2. **Pattern searches**: Show what patterns are being searched
3. **Code changes**: Summarize each edit before making it
4. **Build output**: Show last 20 lines of build output
5. **Verification**: Show verification command and result

Example verbose output:

```
[CONTEXT] Reading ClaudeWatch/Views/MainView.swift (referenced in task)
[CONTEXT] Reading ClaudeWatch/DesignSystem/Claude.swift (referenced in task)
[PATTERN] Searching for similar button implementations...
[PATTERN] Found 3 matches in ConsentView.swift, MainView.swift, SettingsView.swift
[EDIT] MainView.swift:45 - Adding new button component
[EDIT] MainView.swift:120 - Updating view body
[BUILD] Running xcodebuild for watchOS Simulator...
[BUILD] ** BUILD SUCCEEDED ** (23 warnings)
[VERIFY] Running: grep -q 'NewButton' MainView.swift
[VERIFY] PASSED
[COMMIT] feat(ui): Add new button to main view
```

## Error Handling

If a task fails:

```
╔══════════════════════════════════════════════════════════════╗
║                    TASK FAILED                               ║
╠══════════════════════════════════════════════════════════════╣
║  ID: [task_id]                                               ║
║  Error: [description]                                        ║
║  Attempt: [n] of 3                                           ║
╚══════════════════════════════════════════════════════════════╝
```

- Retry up to 3 times
- If still failing, skip task and note in summary
- Continue with next task

## Quick Start

Read the PROMPT.md for detailed phase instructions:

```bash
cat .claude/ralph/PROMPT.md
```

Then read tasks.yaml and begin the loop:

```bash
cat .claude/ralph/tasks.yaml
```

**START THE LOOP NOW** - Read tasks.yaml and execute until complete.
