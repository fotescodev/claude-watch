# Claude Watch V2 Redesign Implementation Plan

## Summary

Implement V2 redesign incorporating Pencil design mockups (`pencil-new.pen`) **plus** Anthropic designer feedback. The Pencil design is a strong foundation (7/10 completeness) but needs refinements before implementation.

---

## Designer Feedback Summary

**Score: 8.3/10** - Strong foundation with gaps in information density

### What's Validated
- Five core states (Idle, Working, Paused, Approval, Success/Error)
- Color language (Green=safe, Orange=attention, Red=danger, Blue=working)
- Liquid Glass aesthetic
- Tiered Risk Approval System (Tier 1-3) - **EXCELLENT, adopt this**
- F16: Context Warning - **adopt**
- F18: Question Response - **adopt with fixes**
- Emergency Stop (Action Button Long Press) - **add to spec**

### Must Fix Before Implementation

| Issue | Current | Required Fix |
|-------|---------|--------------|
| **Working state** | Only shows "Implementing API..." + progress bar | Add collapsible task list |
| **Progress bar** | No percentage | Add "33%" or "1/3" indicator |
| **Tier 3 escape** | Only "Review on Mac" | Add "Reject" + "Remind in 5m" |
| **F18 Question** | Only one answer button | Show BOTH options as tappable |
| **Task Outcome** | Only stats (5 files, 2m 34s) | Add bullet summary of changes |

### Should Add

- Complication designs (missing from mockups)
- Double Tap behavior on Tier 3 (spec says "Cancel")
- Timeout/reminder for pending approvals
- Onboarding "How it works" screen

### Consider Changing

- Pairing code format: `A7X9` (current) vs `ABC-123` (spec) - test both
- Action Button: Pause/Resume (current) vs Approve (spec) - test which is more frequent
- Control Center: 4 controls may be overkill - prioritize 2 (Approve, Pause)

---

## Implementation Phases

### Phase 0: Pencil Design Refinements (Design Work)

**Before coding**, update `pencil-new.pen` to address designer feedback:

#### 0.1 Working State Enhancement
```
┌─────────────────────────────┐
│ ● Working            2:34   │
├─────────────────────────────┤
│ Implementing API            │
│ endpoint...                 │
│                             │
│ ━━━━━━━━━━━━━━━━━━━ 33%    │  ← ADD percentage
│                             │
│ ▼ Tasks (tap to expand)     │  ← ADD collapsible
│ ✓ Research existing code    │
│ ● Update auth service       │
│ ○ Add unit tests            │
└─────────────────────────────┘
```

#### 0.2 Tier 3 Danger Escape Options
```
┌─────────────────────────────┐
│ ! DANGEROUS           2:34  │
├─────────────────────────────┤
│ rm -rf ./build              │
│                             │
│ [Review on Mac]             │
│ [Reject]        [Remind 5m] │  ← ADD escape options
│                             │
│ Double tap = Cancel         │  ← CLARIFY hint
└─────────────────────────────┘
```

#### 0.3 F18 Question - Both Options Tappable
```
┌─────────────────────────────┐
│ ? Question            2:34  │
├─────────────────────────────┤
│ Which approach?             │
│                             │
│ [REST] (recommended)        │  ← Both tappable
│ [GraphQL]                   │  ← Both tappable
│                             │
│ [Handle on Mac]             │  ← Escape hatch
└─────────────────────────────┘
```

#### 0.4 Task Outcome - Add Bullet Summary
```
┌─────────────────────────────┐
│ ✓ Complete           2:34   │
├─────────────────────────────┤
│ Task Complete               │
│                             │
│ • Updated JWT validation    │  ← ADD bullet summary
│ • Added error handling      │
│ • Created 3 unit tests      │
│                             │
│ 5 files  12 tools  2m 34s   │
│ [Dismiss]                   │
└─────────────────────────────┘
```

---

### Phase 1: Design System Updates (Claude.swift)

**Files**: `ClaudeWatch/DesignSystem/Claude.swift`

1. **Update text colors** to match Pencil:
   ```swift
   static let textSecondary = Color(hex: "#8E8E93")
   static let textTertiary = Color(hex: "#666666")
   ```

2. **Add button radius constant**: `Radius.button = 22`

3. **Add colored card modifier**:
   ```swift
   func claudeColoredCard(_ color: Color, radius: CGFloat = 16) -> some View
   ```

4. **Standardize status dot**: 8×8 with 4px corner radius

---

### Phase 2: Working State Enhancement

**Files**: `ClaudeWatch/Views/WorkingView.swift`

1. **Add progress percentage** next to bar:
   ```swift
   HStack {
       ProgressView(value: progress)
       Text("\(Int(progress * 100))%")
           .font(.system(size: 11, weight: .medium, design: .monospaced))
   }
   ```

2. **Add collapsible task list** (from SessionProgress.tasks):
   ```swift
   DisclosureGroup("Tasks") {
       ForEach(tasks) { task in
           HStack {
               Text(task.status.icon)  // ✓ ● ○
               Text(task.content)
           }
       }
   }
   ```

3. **Digital Crown scrolls** task list when expanded

---

### Phase 3: Tiered Approval System

**Files**: `ClaudeWatch/Views/ActionViews.swift`, create `Models/ActionTier.swift`

#### 3.1 ActionTier Enum
```swift
enum ActionTier: Int, Comparable {
    case low = 1      // Edit, Create - Green
    case medium = 2   // Bash - Orange
    case high = 3     // Delete, Dangerous - Red

    var cardColor: Color { ... }
    var canDoubleTapApprove: Bool { self != .high }
    var canApproveFromWatch: Bool { self != .high || hasEscapeOptions }
}
```

#### 3.2 Tier 3 Escape Options
For high-risk actions, show:
- "Review on Mac" (primary)
- "Reject" (secondary)
- "Remind in 5m" (tertiary)

#### 3.3 Double Tap Behavior
- Tier 1-2: Approve
- Tier 3: Cancel (reject)

---

### Phase 4: F18 Question Response Fix

**Files**: `ClaudeWatch/Views/QuestionResponseView.swift`

**Current**: Only shows recommended option + "On Mac"
**Required**: Show ALL options as tappable buttons

```swift
// Show all question options
ForEach(question.options, id: \.self) { option in
    Button(option) {
        respond(with: option)
    }
    .buttonStyle(option == question.recommended ? .primary : .secondary)
}

// Escape hatch
Button("Handle on Mac") { ... }
    .buttonStyle(.tertiary)
```

---

### Phase 5: Task Outcome Enhancement

**Files**: `ClaudeWatch/Views/TaskOutcomeView.swift`

1. **Add bullet summary** from session outcome:
   ```swift
   if let summary = sessionProgress?.outcome {
       VStack(alignment: .leading, spacing: 4) {
           ForEach(summary.bullets, id: \.self) { bullet in
               HStack(alignment: .top, spacing: 6) {
                   Text("•").foregroundColor(Claude.anthropicOrange)
                   Text(bullet).font(.system(size: 11))
               }
           }
       }
   }
   ```

2. **Keep stats row** (files, tools, duration)

3. **ScrollView** for long summaries with Digital Crown

---

### Phase 6: Breathing Animation (Idle State)

**Files**: Create `Components/BreathingAnimation.swift`, update `StateViews.swift`

**Specs**:
- Duration: 3s ease-in-out cycle
- Scale: 0.9 → 1.0
- Opacity: 0.6 → 1.0
- Color: `#d97757` (Anthropic orange)
- Respects Reduce Motion

---

### Phase 7: Swipe-to-Approve Gesture

**Files**: Create `Components/SwipeActionCard.swift`, update `ActionViews.swift`

**Specs**:
- Swipe right = approve (green fill)
- Swipe left = reject (red fill)
- Threshold: 50% of card width
- Haptic at threshold
- Keep tap buttons for accessibility
- **Disabled for Tier 3** (must use explicit buttons)

---

### Phase 8: Action Button Enhancement

**Files**: `ClaudeWatch/App/ClaudeWatchApp.swift` or relevant handler

Add **Long Press = Emergency Stop**:
```swift
// Action Button mapping
switch press {
case .single: togglePauseResume()
case .double: quickApproveIfPending()
case .long: emergencyStop()  // NEW - abort everything
}
```

---

## Critical Files

| File | Changes |
|------|---------|
| `pencil-new.pen` | Design fixes before implementation |
| `Claude.swift` | Color tokens, radius, modifiers |
| `WorkingView.swift` | Progress %, collapsible task list |
| `ActionViews.swift` | Tiered styling, swipe gesture, escape options |
| `QuestionResponseView.swift` | All options tappable |
| `TaskOutcomeView.swift` | Bullet summary |
| `StateViews.swift` | Breathing animation |

---

## Verification Checklist

### Designer Feedback (Must Pass)
- [ ] Working state shows collapsible task list
- [ ] Progress bar shows percentage (e.g., "33%")
- [ ] Tier 3 has escape options (Reject, Remind 5m)
- [ ] F18 Question shows ALL options as buttons
- [ ] Task Outcome shows bullet summary
- [ ] Double Tap on Tier 3 = Cancel

### Visual (From Pencil)
- [ ] Breathing animation in idle (3s cycle, orange)
- [ ] Tier 1 = green card, Tier 2 = orange, Tier 3 = red + border
- [ ] All cards use 16px corner radius
- [ ] All buttons use 22px corner radius

### Interaction
- [ ] Swipe right approves (Tier 1-2 only)
- [ ] Swipe disabled for Tier 3
- [ ] Action Button long press = Emergency Stop
- [ ] Haptic at swipe threshold

---

## Implementation Order

| Order | Phase | Priority | Notes |
|-------|-------|----------|-------|
| 0 | Pencil Design Fixes | P0 | Before any code |
| 1 | Design System | P0 | Foundation |
| 2 | Working State | P0 | Designer must-fix |
| 3 | Tiered Approval | P0 | Designer must-fix |
| 4 | F18 Question Fix | P0 | Designer must-fix |
| 5 | Task Outcome | P0 | Designer must-fix |
| 6 | Breathing Animation | P1 | Visual polish |
| 7 | Swipe Gesture | P1 | Enhanced interaction |
| 8 | Action Button | P1 | Emergency stop |

---

## Open Questions

1. **Pairing code format**: Test `A7X9` vs `ABC-123` with users?
2. **Action Button primary**: Pause/Resume vs Approve - which is more frequent during dog walks?
3. **Control Center**: Keep 4 controls or reduce to 2?
4. **Alarm fatigue**: Will frequent Tier 3 (all-red) cause users to ignore warnings?

---

---

## Stretch Goals: FOMO Features (Post-Launch)

After core V2 implementation, add features that make developers **want to be seen using it**.

### Priority A: Stats & Shareability

#### A1. Session Stats & Streaks
Track and display:
- Weekly approval count ("47 approvals from your wrist")
- Time away from desk ("2h 34m while mobile")
- Consecutive day streaks (7-day streak indicator)

#### A2. Share Cards
Generate shareable images for Twitter/LinkedIn:
```
This week I shipped code while:
  Making coffee     12 approvals
  Walking           23 approvals
  On the couch      12 approvals

47 total - 2h 34m away from desk
```

#### A3. Terminal Stats Banner
Show at session end:
```
Stats:
  12 approvals (8 from watch, 4 from terminal)
  5 files changed, 234 lines added
  Time away from desk: 12m 8s
  67% of requests approved while moving
```

### Priority B: Celebration & Personality

#### B1. "Ship It" Haptic Celebration
For significant completions (N+ files, M+ lines, or "deploy" detected):
- Special haptic pattern (distinct from standard .success)
- Brief completion animation
- Make it meme-able - "getting the ship-it tap"

#### B2. Voice Confirmation Personality
Contextual Siri responses (subtle, 1 per 5-10 interactions):

| Context | Response |
|---------|----------|
| Standard | "Approved. Claude is editing auth.ts." |
| Late night | "Approved. Shipping at midnight, respect." |
| Fast (<2s) | "Approved. Fastest fingers in the west." |
| 10th today | "Approved. You're on a roll." |

### Priority C: Visibility Features

#### C1. Complications That Flex
Modular Ultra / Infograph complications showing:
- Daily approval count
- Current streak
- Mini progress bar

Visible on wrist all day - coworkers will ask about it.

#### C2. Mac Menu Bar Companion
Mirror watch state in menu bar:
- Connection status
- Current session name
- Last approval timestamp
- "Copy Stats" for sharing

Visible during screen sharing - creates conversation.

### Priority D: Smart Features

#### D1. Away Mode with Motion Detection
When CoreMotion detects walking:
- Low-risk approvals auto-batch
- Only Tier 2+ interrupts immediately
- Summary when stopped: "Approved 5 requests while walking"

"My watch knows when I'm busy."

#### D2. Offline Queue Celebration
When reconnecting after dead zone:
```
Back Online
3 approvals synced
0 conflicts
Claude never stopped.
```

Reinforces system resilience.

### Priority E: Annual & Long-term

#### E1. Claude Watch Wrapped (December)
Annual stats summary:
- Total approvals for year
- Hours away from desk
- Top tool used
- Longest streak
- Shareable card

#### E2. Integration Badges
GitHub profile badge:
```
[Claude Watch | 1,247 approvals 2026]
```

Public flex: "I ship from my wrist."

### Priority F: Enterprise (Future)

#### F1. Team Presence
Show who else is shipping:
```
Team Activity
  Sarah    Working
  Mike     Approval pending
  You      Paused
3 of 5 team members active
```

Not collaboration, just presence. Social proof.

---

## FOMO Stack Summary

| Layer | Feature | Trigger |
|-------|---------|---------|
| Stats | Weekly stats, streaks | "I approved 47 this week" |
| Social | Share cards, badges | "Look at my numbers" |
| Status | Complications, menu bar | "What's that on your wrist?" |
| Celebration | Ship-it haptic, personality | "Did you get the tap?" |
| Annual | Wrapped | "My year with Claude" |

**Goal**: Make developers want to be seen using it.

---

## Summary

The Pencil design is a strong foundation but needs refinement before implementation. Key additions from designer feedback:

1. **Information density** - Working state needs task list + percentage
2. **Safety escapes** - Tier 3 must have Reject/Remind options
3. **Full options** - F18 Question needs all answers tappable
4. **Closure detail** - Task Outcome needs bullet summary
5. **Emergency stop** - Action Button long press

Address design fixes first (Phase 0), then implement core phases, then tackle stretch goals for organic marketing.
