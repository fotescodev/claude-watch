# TestFlight Launch Plan

> Created: 2026-03-02
> Status: **IN PROGRESS** — iOS debris cleaned, ready for retry

## Background

First TestFlight upload attempt (2026-02-25) failed. Initial hypothesis was wrong Xcode project template. Deep analysis (2026-03-02) revealed the project IS a correctly structured Xcode 14+ single-target standalone watchOS app. The `productType = "com.apple.product-type.application"` is correct — do NOT change it to `watchapp2`.

Fixes applied so far:
1. `57cee28` — Replaced localhost default with cloud worker URL, fixed test target signing, cleaned ATS
2. `355c022` — Added privacy policy for App Store Connect
3. `abdc677` — Removed alpha channel from all 23 app icons
4. (this session) — Removed `UISupportedInterfaceOrientations` from Info.plist + both Debug/Release build settings in pbxproj

## Step 1: Retry Archive + Upload

```bash
# Archive for App Store
xcodebuild -project ClaudeWatch.xcodeproj \
  -scheme ClaudeWatch \
  -configuration Release \
  -destination 'generic/platform=watchOS' \
  -archivePath /tmp/ClaudeWatch.xcarchive \
  archive

# If Xcode Organizer upload doesn't work, try:
xcrun altool --upload-app -f /tmp/ClaudeWatch.ipa -t watchos -u YOUR_APPLE_ID -p APP_SPECIFIC_PASSWORD
# Or use Transporter.app
```

## Step 2: If Upload Still Fails

Capture the **exact error message** — ITMS code, Xcode error, or Organizer message. Common issues:

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Organizer doesn't show "App Store Connect" | Xcode 26 bug for standalone watchOS | Use `xcrun altool` or Transporter |
| ITMS-90683 | Missing permissions plist key | Add missing usage description |
| ITMS-90362 | Invalid UIRequiredDeviceCapabilities | Remove iOS capabilities |
| Archive fails to build | Code signing issue | Check provisioning in Xcode |
| "Invalid bundle structure" | Widget embedding wrong | Check Embed App Extensions build phase |

## Step 3: Nuclear Option — Recreate from Template

**ONLY do this if Steps 1-2 fail with a structural project issue (not a signing/metadata issue).**

### Instructions for user (in Xcode):

1. File → New → Project → watchOS → App
2. Product Name: `Remmy` (or `ClaudeWatch`)
3. Bundle Identifier: `com.edgeoftrust.remmy`
4. Interface: SwiftUI
5. Language: Swift
6. Team: 98R5RJKR5F
7. Save as `ClaudeWatch.xcodeproj` (rename/backup old one first)

### Migration checklist (for Claude agent):

After user creates the new project, the agent must:

- [ ] Add all 61 Swift source files to the new project's compile sources
- [ ] Preserve the directory group structure (App/, Views/, Views/Components/, Services/, Models/, Components/, Controls/, Complications/, Intents/, DesignSystem/, Tests/)
- [ ] Add Assets.xcassets to the new project's resources
- [ ] Configure entitlements:
  - Debug: `ClaudeWatch/ClaudeWatch.entitlements` (aps-environment: development)
  - Release: `ClaudeWatch/ClaudeWatch-Release.entitlements` (aps-environment: production)
- [ ] Add `PrivacyInfo.xcprivacy` to resources
- [ ] Set up `Info.plist` (copy existing, already cleaned of iOS keys)
- [ ] Create RemmyWidgetExtension target:
  - Product type: `com.apple.product-type.app-extension`
  - Bundle ID: `com.edgeoftrust.remmy.widget`
  - Entitlements: `RemmyWidget/RemmyWidget.entitlements`
  - Info.plist: `RemmyWidget/Info.plist` (NSExtensionPointIdentifier: com.apple.widgetkit-extension)
  - Sources: RemmyWidgetBundle.swift + shared files (ComplicationViews.swift, Claude.swift, ClaudeState.swift, SessionStatus.swift)
  - SKIP_INSTALL = YES
  - SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG, WIDGET_EXTENSION (Debug) / WIDGET_EXTENSION (Release)
- [ ] Create ClaudeWatchTests target:
  - Bundle ID: `com.edgeoftrust.remmy.tests`
  - 10 test files
  - Depends on ClaudeWatch target
- [ ] Embed RemmyWidgetExtension in main app's "Embed App Extensions" build phase
- [ ] Build settings to verify:
  - SDKROOT = watchos (all targets)
  - TARGETED_DEVICE_FAMILY = 4 (all targets)
  - WATCHOS_DEPLOYMENT_TARGET = 10.6 (all targets)
  - DEVELOPMENT_TEAM = 98R5RJKR5F (all targets)
  - SWIFT_VERSION = 5.0
  - App group: group.com.remmy (main app + widget)
- [ ] Verify build succeeds on watchOS Simulator
- [ ] Verify archive builds for generic watchOS destination

## Complete File Inventory

### Swift Source Files (61 total)

**App/ (1 file)**
- ClaudeWatch/App/ClaudeWatchApp.swift

**Views/ (17 files)**
- ClaudeWatch/Views/MainView.swift
- ClaudeWatch/Views/PairingView.swift
- ClaudeWatch/Views/ConsentView.swift
- ClaudeWatch/Views/StateViews.swift
- ClaudeWatch/Views/ActionViews.swift
- ClaudeWatch/Views/CommandViews.swift
- ClaudeWatch/Views/SheetViews.swift
- ClaudeWatch/Views/HistoryView.swift
- ClaudeWatch/Views/WorkingView.swift
- ClaudeWatch/Views/TaskOutcomeView.swift
- ClaudeWatch/Views/PausedView.swift
- ClaudeWatch/Views/QuestionResponseView.swift
- ClaudeWatch/Views/ContextWarningView.swift
- ClaudeWatch/Views/ApprovalQueueView.swift
- ClaudeWatch/Views/QuickActionsView.swift
- ClaudeWatch/Views/ApprovalView.swift
- ClaudeWatch/Views/Components/RecordingIndicator.swift

**Services/ (5 files)**
- ClaudeWatch/Services/WatchService.swift
- ClaudeWatch/Services/EncryptionService.swift
- ClaudeWatch/Services/KeychainHelper.swift
- ClaudeWatch/Services/ActivityStore.swift
- ClaudeWatch/Services/WidgetReloadCoordinator.swift

**Models/ (5 files)**
- ClaudeWatch/Models/ApprovalRequest.swift
- ClaudeWatch/Models/ClaudeState.swift
- ClaudeWatch/Models/ActionTier.swift
- ClaudeWatch/Models/ActivityEvent.swift
- ClaudeWatch/Models/SessionStatus.swift

**Components/ (11 files)**
- ClaudeWatch/Components/ActionButtonHandler.swift
- ClaudeWatch/Components/ActionButtonRow.swift
- ClaudeWatch/Components/AmbientGlow.swift
- ClaudeWatch/Components/BreathingAnimation.swift
- ClaudeWatch/Components/FloatingSettingsButton.swift
- ClaudeWatch/Components/ModeIndicator.swift
- ClaudeWatch/Components/ScreenShell.swift
- ClaudeWatch/Components/ScreenTransition.swift
- ClaudeWatch/Components/StateCard.swift
- ClaudeWatch/Components/SwipeActionCard.swift
- ClaudeWatch/Components/TaskChecklist.swift

**Controls/ (4 files)**
- ClaudeWatch/Controls/ApproveControl.swift
- ClaudeWatch/Controls/RejectControl.swift
- ClaudeWatch/Controls/PauseResumeControl.swift
- ClaudeWatch/Controls/StatusControl.swift

**Complications/ (1 file)**
- ClaudeWatch/Complications/ComplicationViews.swift

**Intents/ (5 files)**
- ClaudeWatch/Intents/ApproveRemmyIntent.swift
- ClaudeWatch/Intents/RejectRemmyIntent.swift
- ClaudeWatch/Intents/PauseRemmyIntent.swift
- ClaudeWatch/Intents/RemmyStatusIntent.swift
- ClaudeWatch/Intents/RemmyShortcuts.swift

**DesignSystem/ (2 files)**
- ClaudeWatch/DesignSystem/Claude.swift
- ClaudeWatch/DesignSystem/Remmy.swift

**Tests/ (10 files)**
- ClaudeWatch/Tests/ReconnectionConfigTests.swift
- ClaudeWatch/Tests/ConnectionStatusTests.swift
- ClaudeWatch/Tests/WebSocketErrorTests.swift
- ClaudeWatch/Tests/QueuedMessageTests.swift
- ClaudeWatch/Tests/WatchServiceTests.swift
- ClaudeWatch/Tests/UITests.swift
- ClaudeWatch/Tests/DesignSystemTests.swift
- ClaudeWatch/Tests/FoundationModelsStatusTests.swift
- ClaudeWatch/Tests/CloudErrorTests.swift
- ClaudeWatch/Tests/ApprovalRequestTests.swift

### Widget Extension (3 files)
- RemmyWidget/RemmyWidgetBundle.swift
- RemmyWidget/RemmyWidget.entitlements
- RemmyWidget/Info.plist

**Cross-compiled into widget target (NOT duplicated):**
- ClaudeWatch/Complications/ComplicationViews.swift
- ClaudeWatch/DesignSystem/Claude.swift
- ClaudeWatch/Models/ClaudeState.swift
- ClaudeWatch/Models/SessionStatus.swift

### Configuration Files
- ClaudeWatch/Info.plist
- ClaudeWatch/ClaudeWatch.entitlements (Debug)
- ClaudeWatch/ClaudeWatch-Release.entitlements (Release)
- ClaudeWatch/PrivacyInfo.xcprivacy
- ClaudeWatch/Assets.xcassets/ (23 icons + 2 logo variants + AccentColor + 4 Contents.json)

### Key Build Settings (non-default)
- SDKROOT: watchos
- TARGETED_DEVICE_FAMILY: 4
- WATCHOS_DEPLOYMENT_TARGET: 10.6
- DEVELOPMENT_TEAM: 98R5RJKR5F
- CODE_SIGN_STYLE: Automatic
- PRODUCT_BUNDLE_IDENTIFIER: com.edgeoftrust.remmy
- MARKETING_VERSION: 1.0
- CURRENT_PROJECT_VERSION: 1
- SWIFT_VERSION: 5.0
- 0 SPM dependencies (all system frameworks)

## Accessibility Gaps (Fix before or after TestFlight)

8 views with zero accessibility labels identified. Priority order:

1. **ApprovalView.swift** (CRITICAL) — Approve/Reject buttons lack context about what action is being approved
2. **MainView.swift** — Pause/Resume icon-only button, long-press gesture invisible to VoiceOver
3. **QuestionResponseView.swift** — Recommended vs alternative option not distinguishable
4. **ContextWarningView.swift** — Progress bar, OK button lack context
5. **QuickActionsView.swift** — Permission mode buttons missing selected state
6. **PausedView.swift** — Double-tap-to-resume not discoverable via VoiceOver
7. **TaskOutcomeView.swift** — Decorative icons announced, dismiss gesture hidden
8. **HistoryView.swift** — Minor: decorative icon, row grouping
