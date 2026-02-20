# Claude Watch: User Journey Maps

**Document Version:** 1.0
**Last Updated:** January 2026
**Author:** Design Lead
**Status:** Final

---

## Overview

This document presents comprehensive user journey maps for Claude Watch, tracing user experiences from initial discovery through daily usage patterns. Each journey map identifies touchpoints, emotions, pain points, and opportunities for design improvement.

---

## Journey Map 1: First-Time User - Discovery to First Approval

**Persona:** Alex Chen (Mobile Developer)
**Journey Duration:** 15-30 minutes
**Goal:** Successfully pair Claude Watch and approve first action

### Journey Phases

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  DISCOVERY      │   DECISION      │    SETUP        │  FIRST USE      │   ADOPTION      │
│  (2-5 min)      │   (1-2 min)     │    (5-15 min)   │  (2-5 min)      │   (ongoing)     │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                 │                 │                 │                 │                 │
│  Learn about    │   Decide to     │    Install &    │  Approve        │   Integrate     │
│  Claude Watch   │   try it        │    configure    │  first action   │   into workflow │
│                 │                 │                 │                 │                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Discovery (2-5 minutes)

| Stage | User Actions | Touchpoints | Thoughts/Feelings | Pain Points | Opportunities |
|-------|--------------|-------------|-------------------|-------------|---------------|
| Awareness | Sees mention on HN/Twitter/Claude Discord | Social media, forums | "This could solve my approval problem" | - | Ensure shareable content |
| Interest | Visits App Store listing | App Store page | "Looks useful, reviews are good" | Limited screenshots | Better App Store assets |
| Research | Reads description and reviews | App Store, website | "Will this work with my setup?" | Requirements unclear | Clear compatibility info |

**Emotions:**
```
Curiosity ────▶ Interest ────▶ Cautious Optimism
```

### Phase 2: Decision (1-2 minutes)

| Stage | User Actions | Touchpoints | Thoughts/Feelings | Pain Points | Opportunities |
|-------|--------------|-------------|-------------------|-------------|---------------|
| Evaluation | Checks price, requirements | App Store | "Free tier should work for me" | Pricing confusion | Clear pricing display |
| Commitment | Taps download | App Store | "Let's see if this works" | - | Streamlined install |
| Anticipation | Watches install progress | Watch face | "Hope this is worth it" | Slow download on watch | Set expectations |

**Emotions:**
```
Consideration ────▶ Decision ────▶ Anticipation
```

### Phase 3: Setup (5-15 minutes)

| Stage | User Actions | Touchpoints | Thoughts/Feelings | Pain Points | Opportunities |
|-------|--------------|-------------|-------------------|-------------|---------------|
| First Launch | Opens app on watch | Claude Watch app | "Clean interface, now what?" | No onboarding guidance | Welcome screen |
| Permission Request | Approves notifications | System dialog | "I want these, that's the point" | - | Explain why needed |
| Consent Screen | Reviews privacy policy | ConsentView | "Standard stuff, ok" | Long consent text | Scannable format |
| Pairing Start | Taps "Pair with Code" | PairingView | "Ok, where do I get a code?" | Process unclear | Better instructions |
| Server Setup | Starts MCP server in terminal | Terminal | "Let me find those docs..." | Complex server setup | Clearer CLI output |
| Code Entry | Types pairing code | Watch keyboard | "This keyboard is terrible" | Tiny keyboard frustration | **QR code pairing** |
| Connection | Sees "Connected" status | MainView | "Finally! That was painful" | Relief mixed with frustration | Celebrate success |

**Emotions:**
```
Eager ────▶ Confused ────▶ Frustrated (keyboard) ────▶ Relief
```

**Critical Pain Point:** Keyboard entry is the #1 friction point in the entire journey.

### Phase 4: First Use (2-5 minutes)

| Stage | User Actions | Touchpoints | Thoughts/Feelings | Pain Points | Opportunities |
|-------|--------------|-------------|-------------------|-------------|---------------|
| Wait for Action | Continues work in Claude Code | Terminal | "Let's see if it works" | Anticipation anxiety | Demo mode option |
| Notification | Receives first push | Watch notification | "It works!" | - | Celebration haptic |
| Review | Reads action details | Notification expand | "Edit App.tsx, looks right" | Limited context | Show file preview |
| Approval | Taps Approve button | Action buttons | "That was easy!" | - | Confirm success |
| Verification | Sees Claude Code continue | Terminal | "Magic. This is great." | - | Success feedback |

**Emotions:**
```
Anticipation ────▶ Excitement ────▶ Delight ────▶ Satisfaction
```

### Phase 5: Adoption (Ongoing)

| Stage | User Actions | Touchpoints | Thoughts/Feelings | Pain Points | Opportunities |
|-------|--------------|-------------|-------------------|-------------|---------------|
| Integration | Adds complication to watch face | Watch settings | "Always want to see status" | Complication setup | Suggest complication |
| Habit Formation | Checks watch before leaving desk | Claude Watch | "Let me clear pending" | - | Smart reminders |
| Feature Discovery | Explores modes, voice | Settings, commands | "What else can I do?" | Hidden features | Progressive disclosure |
| Advocacy | Recommends to colleagues | Word of mouth | "You need this app" | - | Share/invite feature |

**Emotions:**
```
Growing Confidence ────▶ Habit Formation ────▶ Advocacy
```

### Journey Summary Visualization

```
EMOTIONAL CURVE
     ^
     │                                              ★ First successful approval
     │                                             /
 (+) │                               Relief ──────★─────▶ Delight
     │                              /
     │         ▲                   /
     │        / \                 /
     │   Interest              Connection
     │      /     \              /
─────┼─────/───────\──Frustrated/────────────────────────────────────▶ Time
     │              \          /
     │               Keyboard /
 (-) │                pain   ▼
     │                point
     ▼
```

---

## Journey Map 2: Daily Use - Morning Workflow

**Persona:** Jordan Martinez (Remote Worker)
**Journey Duration:** 2-3 hours
**Goal:** Complete morning work session with Claude assistance while mobile

### Journey Overview

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  MORNING START  │   TASK KICK-OFF │   EXERCISE      │  MONITORING     │   RETURN        │
│  (30 min)       │   (15 min)      │    (45 min)     │  (sporadic)     │   (15 min)      │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                 │                 │                 │                 │                 │
│  Wake up,       │   Start long    │    Go for       │  Glance at      │   Review        │
│  check email    │   task          │    morning run  │  watch          │   results       │
│                 │                 │                 │                 │                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Detailed Phase Breakdown

#### Phase 1: Morning Start (30 minutes)

| Time | Action | Touchpoint | Emotion | Design Need |
|------|--------|------------|---------|-------------|
| 07:00 | Wake up, check watch | Watch face complication | Calm curiosity | Show overnight status |
| 07:05 | Glance at Claude status | Complication | Relieved (no issues) | Clear "all clear" state |
| 07:15 | Open MacBook, check terminal | Terminal | Focused | - |
| 07:30 | Plan morning tasks | Notes app | Intentional | - |

**Key Touchpoint: Complication**
```
┌─────────────────────┐
│    ○ CLAUDE         │
│                     │
│  ✓ All Clear        │
│    No pending       │
└─────────────────────┘
```

#### Phase 2: Task Kick-off (15 minutes)

| Time | Action | Touchpoint | Emotion | Design Need |
|------|--------|------------|---------|-------------|
| 07:45 | Start database migration | Terminal | Anticipation | - |
| 07:50 | First approval request | Watch notification | Engaged | Quick glance approval |
| 07:52 | Approve initial setup | Watch app | Confident | Batch approve option |
| 07:58 | Close laptop for run | - | Trusting | Progress visible on watch |

**Key Interaction: Pre-departure Check**
```
User thought: "Can I leave now?"
Watch shows: 15% complete, 0 pending
Decision: Safe to go
```

#### Phase 3: Exercise (45 minutes)

| Time | Action | Touchpoint | Emotion | Design Need |
|------|--------|------------|---------|-------------|
| 08:00 | Start run, quick glance | Watch face | Free | Minimal distraction |
| 08:15 | Check during rest | Complication | Curious | Progress update |
| 08:20 | Approve during walk | Notification | Efficient | One-tap approval |
| 08:35 | Cool down, status check | Watch app | Satisfied | Clear progress display |

**Interaction Pattern During Exercise:**
```
Notification arrives
   │
   ▼
Raise wrist (auto-wake)
   │
   ▼
Read action (2 seconds)
   │
   ▼
Tap Approve/Reject (1 second)
   │
   ▼
Feel haptic confirmation
   │
   ▼
Lower wrist, continue run
```

#### Phase 4: Monitoring (Sporadic)

| Time | Action | Touchpoint | Emotion | Design Need |
|------|--------|------------|---------|-------------|
| 08:40 | Shower (no access) | - | Slight anxiety | Tolerant of delay |
| 09:00 | Quick breakfast check | Complication | Reassured | Accurate status |
| 09:15 | Handle 2 pending | Watch app | Productive | Queue management |

**Critical Design Requirement:** Status must be accurate within 60 seconds

#### Phase 5: Return (15 minutes)

| Time | Action | Touchpoint | Emotion | Design Need |
|------|--------|------------|---------|-------------|
| 09:30 | Return to desk | - | Ready | - |
| 09:32 | Open laptop, check terminal | Terminal | Satisfied | - |
| 09:35 | See migration complete | Terminal | Accomplished | - |

### Jordan's Journey Emotional Arc

```
EMOTIONAL CURVE
     ^
 (+) │         ★ Leave for run     ★ Task complete
     │        / \                 /
     │   Task / Monitoring OK    /
     │  start     \             /
     │  /          \           /
─────┼─/────────────\─────────/─────────────────────────────────────▶ Time
     │               \       /
     │                Shower anxiety
 (-) │                  ▼
     ▼
```

---

## Journey Map 3: Complex Approval - Power User Scenario

**Persona:** Sam Okonkwo (Power User)
**Journey Duration:** Variable (can span hours)
**Goal:** Safely execute large-scale refactoring with granular control

### Journey Overview

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  PREPARATION    │   EXECUTION     │   MONITORING    │  INTERVENTION   │   COMPLETION    │
│  (10 min)       │   (variable)    │    (ongoing)    │  (as needed)    │   (10 min)      │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                 │                 │                 │                 │                 │
│  Configure      │   Start         │    Monitor      │  Reject bad     │   Review        │
│  modes, review  │   operation     │    from watch   │  operations     │   results       │
│                 │                 │                 │                 │                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Preparation (10 minutes)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Assessment | Review task scope | Terminal | "500 files, need careful monitoring" | - |
| Mode Selection | Set to Normal mode | Watch app | "Every action needs review" | Easy mode access |
| Notification Check | Verify watch notifications on | Settings | "Can't miss any critical actions" | Notification confirmation |
| Position Watch | Set watch where visible | Physical | "Need to see this during meeting" | Complication visibility |

### Phase 2: Execution (Variable)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Launch | Start refactoring task | Terminal | "Here we go" | - |
| Initial Burst | Handle 5 rapid approvals | Watch app | "This is efficient" | Quick approval flow |
| Pattern Recognition | Notice routine operations | Watch | "These are all safe" | Batch approve |
| Mode Switch | Switch to Auto-Accept | Watch app | "Trusted phase, auto it" | Mode confirmation |

**Mode Selection UI:**
```
┌─────────────────────────┐
│ Permission Mode         │
│                         │
│ ○ Normal (current)      │
│   Review each action    │
│                         │
│ ● Auto-Accept           │
│   Approve automatically │
│   ⚠️ USE WITH CAUTION   │
│                         │
│ ○ Plan                  │
│   Read-only planning    │
└─────────────────────────┘
```

### Phase 3: Monitoring (Ongoing)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Glance Check | Check complication | Watch face | "67% done, good progress" | Accurate progress |
| Meeting Monitor | Quick glances during meeting | Complication | "Still auto-approving, OK" | Minimal distraction |
| Anomaly Detection | Notice unexpected pending | Watch app | "Why is this pending in auto mode?" | Clear anomaly indication |
| Investigation | Open app for details | Watch app | "Ah, Claude is asking for input" | Distinguish action types |

**Complication States:**
```
Normal Progress:           Anomaly Alert:
┌─────────────────┐       ┌─────────────────┐
│   ⚡ 67%        │       │   ⚠️ 67%        │
│   Auto-Accept   │       │   1 NEEDS INPUT │
└─────────────────┘       └─────────────────┘
```

### Phase 4: Intervention (As Needed)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Alert | Receive critical notification | Watch | "DELETE operation?" | Priority indication |
| Review | Read full action details | Watch app | "Wrong table, reject this" | Clear action details |
| Reject | Tap Reject button | Watch app | "Caught a dangerous one" | Strong reject haptic |
| Correction | Voice command correction | Voice input | "Use users_archive instead" | Voice command flow |
| Resume | Operations continue | Watch | "Back on track" | Status update |

**Critical Action UI:**
```
┌─────────────────────────┐
│ ⚠️ DANGEROUS OPERATION  │
│                         │
│ 🗑️ DELETE FROM users   │
│    WHERE inactive=true  │
│                         │
│ ┌────────┐ ┌──────────┐ │
│ │ REJECT │ │  Approve │ │
│ │ (red)  │ │ (muted)  │ │
│ └────────┘ └──────────┘ │
└─────────────────────────┘
```

### Phase 5: Completion (10 minutes)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Completion Alert | Receive completion notification | Watch | "Finally done" | Celebration feedback |
| Summary | Review operation stats | Watch app | "427 approved, 3 rejected" | Operation summary |
| Mode Reset | Return to Normal mode | Watch app | "Back to careful mode" | Auto mode-reset option |
| Documentation | Note any issues | Notes | "That DELETE caught was good" | Export capability |

### Sam's Journey Emotional Arc

```
EMOTIONAL CURVE
     ^
 (+) │            ★ Caught dangerous operation
     │           /  \
     │   Trust  /    \        ★ Completion
     │  builds /      \      /
     │        /        \    /
─────┼───────/──────────\──/───────────────────────────────────────▶ Time
     │  Careful            \/
     │  vigilance    Brief anxiety
 (-) │                  ▼
     ▼
```

---

## Journey Map 4: iOS Companion Pairing

**Persona:** Riley Nakamura (iOS Companion User)
**Journey Duration:** 5-10 minutes
**Goal:** Pair Claude Watch using QR code on iPhone

### Journey Overview

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  INSTALL iOS    │   OPEN CAMERA   │   SCAN QR       │   AUTO SYNC     │   VERIFY        │
│  (2 min)        │   (30 sec)      │    (5 sec)      │   (5-15 sec)    │   (1 min)       │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                 │                 │                 │                 │                 │
│  Download iOS   │   Launch app    │    Point at     │   Watch syncs   │   Test first    │
│  companion      │   scanner       │    terminal QR  │   automatically │   approval      │
│                 │                 │                 │                 │                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Install iOS App (2 minutes)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Discovery | Find companion app | App Store search | "There's an iPhone app too" | Clear naming |
| Download | Install app | App Store | "Quick download" | Small app size |
| Launch | Open app first time | iOS app | "Nice, clean welcome screen" | Immediate value prop |
| Permission | Grant camera access | iOS permission | "Makes sense for QR" | Clear explanation |

**iOS Welcome Screen:**
```
┌─────────────────────────────┐
│                             │
│    ◯ Claude Watch           │
│    ─────────────            │
│                             │
│    Pair your Apple Watch    │
│    with Claude Code in      │
│    seconds using QR code    │
│                             │
│    ┌───────────────────┐    │
│    │   Scan QR Code    │    │
│    └───────────────────┘    │
│                             │
│    Or enter code manually   │
│                             │
└─────────────────────────────┘
```

### Phase 2: Open Camera (30 seconds)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Tap Scan | Tap "Scan QR Code" | iOS app | "Easy enough" | Large tap target |
| Camera View | Camera viewfinder appears | iOS camera | "Clean interface" | Clear frame guide |
| Instructions | See scanning instructions | iOS overlay | "Point at terminal, got it" | Helpful guidance |

**Scanner UI:**
```
┌─────────────────────────────┐
│  ──────────────────────────│
│                             │
│     ┌─────────────────┐     │
│     │                 │     │
│     │    [QR Frame]   │     │
│     │                 │     │
│     └─────────────────┘     │
│                             │
│    Point camera at the      │
│    QR code in your terminal │
│                             │
│  ──────────────────────────│
│    Having trouble?          │
│    Enter code manually →    │
└─────────────────────────────┘
```

### Phase 3: Scan QR (5 seconds)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Align | Point camera at terminal | Physical | "There's the QR code" | - |
| Capture | QR detected automatically | iOS app | "That was instant!" | Fast recognition |
| Feedback | Success animation | iOS app | "Cool, it worked" | Satisfying confirmation |
| Parse | Code extracted | iOS app | - | Instant processing |

**Success Animation:**
```
Before scan:           After scan:
┌─────────────────┐   ┌─────────────────┐
│    [QR Frame]   │   │    ✓ Success    │
│                 │   │                 │
│   Searching...  │   │   Code: ABC123  │
└─────────────────┘   └─────────────────┘
```

### Phase 4: Auto Sync (5-15 seconds)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Transfer Start | WatchConnectivity begins | iOS app | "Sending to watch..." | Progress indicator |
| Watch Update | Watch receives token | Watch | "Watch just buzzed" | Haptic notification |
| Verification | Server confirms pairing | Both devices | "It's connecting" | Clear status |
| Complete | "Connected" on both devices | iOS + Watch | "That was so easy!" | Celebration moment |

**Sync Progress UI (iOS):**
```
┌─────────────────────────────┐
│                             │
│    ✓ Code scanned           │
│                             │
│    ● Syncing to Watch...    │
│      ▓▓▓▓▓▓▓░░░ 70%        │
│                             │
│    ○ Connecting to server   │
│                             │
│    Keep this app open       │
│                             │
└─────────────────────────────┘
```

**Watch During Sync:**
```
┌─────────────────────┐
│                     │
│  📲 Receiving       │
│     pairing...      │
│                     │
│  ▓▓▓▓▓▓▓▓░░░        │
│                     │
└─────────────────────┘
```

### Phase 5: Verify (1 minute)

| Stage | Action | Touchpoint | Thought | Design Need |
|-------|--------|------------|---------|-------------|
| Check Watch | Open Claude Watch | Watch | "Let's see if it worked" | Show connected state |
| Connected State | See "Connected" status | Watch app | "Perfect, it worked!" | Clear confirmation |
| Test Action | Start a Claude task | Terminal | "Let me test it" | - |
| First Notification | Receive first approval request | Watch | "It works!" | Celebratory haptic |

**Connected State (Watch):**
```
┌─────────────────────┐
│      ◯ Claude       │
│                     │
│  ✓ Connected        │
│                     │
│  Ready to approve   │
│  actions from       │
│  Claude Code        │
│                     │
│  ┌───────────────┐  │
│  │   Load Demo   │  │
│  └───────────────┘  │
└─────────────────────┘
```

### Riley's Journey Emotional Arc

```
EMOTIONAL CURVE
     ^
 (+) │                    ★ QR scans instantly
     │                   / \
     │                  /   \     ★ It works!
     │    Interest     /     \   /
     │       ╱        /       \ /
─────┼──────╱────────/─────────────────────────────────────────────▶ Time
     │ "Another    /
     │  app?"     /
 (-) │   ▼       /
     ▼        Scan starts
```

**Key Success Factor:** Total pairing time < 2 minutes vs. 5-10 minutes with keyboard entry

---

## Journey Map 5: Error Recovery

**Persona:** Any user
**Journey Duration:** 2-5 minutes
**Goal:** Recover from connection failure

### Journey Phases

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│  ERROR OCCURS   │   AWARENESS     │   DIAGNOSIS     │   RECOVERY      │   RESUME        │
│  (instant)      │   (seconds)     │    (1-2 min)    │   (1-2 min)     │   (seconds)     │
├──────────────────────────────────────────────────────────────────────────────────────────┤
│                 │                 │                 │                 │                 │
│  Connection     │   See error     │    Understand   │   Take action   │   Continue      │
│  drops          │   state         │    cause        │   to fix        │   work          │
│                 │                 │                 │                 │                 │
└──────────────────────────────────────────────────────────────────────────────────────────┘
```

### Phase 1: Error Occurs

| Trigger | System Response | User Impact |
|---------|-----------------|-------------|
| Server stops | WebSocket disconnects | Actions pile up unhandled |
| WiFi drops | Connection timeout | No status updates |
| Token expires | Auth failure | Must re-pair |
| Server error | Error response | Action stuck |

### Phase 2: Awareness

**Error States (Watch Display):**

```
Connection Lost:              Server Error:
┌─────────────────────┐      ┌─────────────────────┐
│                     │      │                     │
│  📡 Disconnected    │      │  ⚠️ Server Error   │
│                     │      │                     │
│  Lost connection    │      │  Could not process  │
│  to server          │      │  your request       │
│                     │      │                     │
│  ┌───────────────┐  │      │  ┌───────────────┐  │
│  │     Retry     │  │      │  │     Retry     │  │
│  └───────────────┘  │      │  └───────────────┘  │
│                     │      │                     │
│  Demo Mode          │      │  View Details       │
└─────────────────────┘      └─────────────────────┘
```

### Phase 3: Diagnosis

| Error Type | Explanation Shown | User Thought |
|------------|-------------------|--------------|
| Connection Lost | "Lost connection to server" | "Is my server running?" |
| Token Expired | "Pairing expired, please reconnect" | "Need to re-pair" |
| Server Error | "Server returned an error" | "Something's wrong server-side" |
| Network Offline | "Watch is offline" | "No WiFi or cellular" |

### Phase 4: Recovery

**Recovery Actions by Error Type:**

| Error | Primary Action | Secondary Action | Outcome |
|-------|----------------|------------------|---------|
| Connection Lost | Retry button | Check server | Auto-reconnect with backoff |
| Token Expired | Re-pair flow | Contact support | New pairing session |
| Server Error | Retry | View error details | Usually self-resolves |
| Offline | Wait for connection | Use Demo Mode | Resume when online |

**Reconnection UI:**
```
┌─────────────────────┐
│                     │
│  🔄 Reconnecting... │
│                     │
│  Attempt 2 of 10    │
│  Next retry: 4s     │
│                     │
│  ▓▓▓▓░░░░░░░░░░░    │
│                     │
│  Cancel             │
└─────────────────────┘
```

### Phase 5: Resume

| Success State | Feedback | User Emotion |
|---------------|----------|--------------|
| Reconnected | "Connected" + success haptic | Relief |
| Re-paired | "Paired successfully" | Satisfaction |
| Error resolved | Actions resume | Back to normal |

---

## Cross-Journey Insights

### Critical Moments of Truth

1. **Pairing** - First impression, highest abandonment risk
2. **First Approval** - Proves value, builds trust
3. **Error Recovery** - Tests reliability, affects long-term trust
4. **Meeting Approval** - Core use case validation

### Emotional Peaks and Valleys

| Journey | Peak Positive | Valley Negative |
|---------|---------------|-----------------|
| First Use | First successful approval | Keyboard pairing frustration |
| Daily Use | Task completes while AFK | Connection drop during run |
| Power User | Catching dangerous operation | Missing critical notification |
| QR Pairing | Instant QR scan | None (designed out friction) |
| Error Recovery | Quick reconnection | Repeated failures |

### Design Priorities from Journeys

1. **Pairing Experience** - QR code eliminates #1 friction point
2. **Glanceable Status** - Complication accuracy is critical
3. **Fast Approval** - Sub-2-second approval flow
4. **Clear Error States** - User should never wonder "what happened?"
5. **Celebration Moments** - Mark successes with haptics and animation

---

## Appendix: Journey Map Methodology

### Data Sources
- Persona research
- Competitive analysis (GitHub Mobile, Linear watch apps)
- Apple Watch interaction pattern studies
- Developer workflow observations

### Validation Plan
- Beta tester journey logging
- Screen flow analytics
- Time-to-completion metrics
- Net Promoter Score at journey end

---

*Document maintained by Design Lead. Update based on user research and analytics.*
