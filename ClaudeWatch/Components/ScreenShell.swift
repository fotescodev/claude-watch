import SwiftUI

// MARK: - ScreenShell
/// Unified layout container for all screens
/// Provides consistent spacing, slot-based architecture, and coordinated transitions
///
/// Layout structure:
/// ```
/// ┌─────────────────────────┐
/// │ ● Status      [toolbar] │  ← handled by MainView toolbar
/// ├─────────────────────────┤
/// │      Spacer(4)          │
/// │      Content Card       │  ← cardSlot (StateCard)
/// │      Spacer(4)          │
/// ├─────────────────────────┤
/// │   [ Action Button(s) ]  │  ← actionSlot (optional)
/// │      hint text          │  ← hintSlot (optional)
/// └─────────────────────────┘
/// ```
///
/// Standard values:
/// - Root spacing: 6pt (between major sections)
/// - Card horizontal padding: 8pt
/// - Button horizontal padding: 16pt
/// - Top padding: 4pt, Bottom: 8pt
struct ScreenShell<CardContent: View, ActionContent: View, HintContent: View>: View {
    let cardContent: CardContent
    let actionContent: ActionContent
    let hintContent: HintContent

    /// Initialize with all slots
    init(
        @ViewBuilder card: () -> CardContent,
        @ViewBuilder action: () -> ActionContent,
        @ViewBuilder hint: () -> HintContent
    ) {
        self.cardContent = card()
        self.actionContent = action()
        self.hintContent = hint()
    }

    var body: some View {
        VStack(spacing: Claude.Screen.Shell.rootSpacing) {
            // Top spacer
            Spacer(minLength: Claude.Screen.Shell.topPadding)

            // Card slot with standard horizontal padding
            cardContent
                .padding(.horizontal, Claude.Screen.Shell.cardHorizontalPadding)

            // Flexible space between card and action
            Spacer(minLength: Claude.Screen.Shell.topPadding)

            // Action slot with standard horizontal padding
            actionContent
                .padding(.horizontal, Claude.Screen.Shell.buttonHorizontalPadding)

            // Hint slot (no padding, content handles its own)
            hintContent

            // Bottom padding handled by spacing
        }
        .padding(.bottom, Claude.Screen.Shell.bottomPadding)
    }
}

// MARK: - Convenience Initializers

extension ScreenShell where ActionContent == EmptyView, HintContent == EmptyView {
    /// Card-only screen (no action or hint)
    init(@ViewBuilder card: () -> CardContent) {
        self.cardContent = card()
        self.actionContent = EmptyView()
        self.hintContent = EmptyView()
    }
}

extension ScreenShell where HintContent == EmptyView {
    /// Screen with card and action (no hint)
    init(
        @ViewBuilder card: () -> CardContent,
        @ViewBuilder action: () -> ActionContent
    ) {
        self.cardContent = card()
        self.actionContent = action()
        self.hintContent = EmptyView()
    }
}

extension ScreenShell where ActionContent == EmptyView {
    /// Screen with card and hint (no action)
    init(
        @ViewBuilder card: () -> CardContent,
        @ViewBuilder hint: () -> HintContent
    ) {
        self.cardContent = card()
        self.actionContent = EmptyView()
        self.hintContent = hint()
    }
}

// MARK: - Standard Hint Text

/// Standard hint text style for ScreenShell
struct ScreenHint: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.claudeNano)
            .foregroundStyle(Claude.textHint)
    }
}

// MARK: - Standard Action Button

/// Standard action button for ScreenShell
struct ScreenActionButton: View {
    let title: String
    let icon: String?
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = Claude.info,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.claudeBody)
                }
                Text(title)
                    .font(.claudeBodyMedium)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Secondary Action Button

/// Secondary (ghost) action button for less prominent actions
struct ScreenSecondaryButton: View {
    let title: String
    let icon: String?
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.claudeMicro)
                }
                Text(title)
                    .font(.claudeFootnoteMedium)
            }
            .foregroundStyle(Claude.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Claude.fill1)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Previews

#Preview("ScreenShell - Full") {
    ZStack {
        Color.black.ignoresSafeArea()

        ScreenShell {
            StateCard(state: .working) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("2/3 Update auth")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Working...")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(red: 0.431, green: 0.431, blue: 0.451))
                }
            }
        } action: {
            ScreenSecondaryButton("Pause", icon: "pause.fill") {
                // Action
            }
        } hint: {
            ScreenHint("Double tap to pause")
        }
    }
}

#Preview("ScreenShell - Card Only") {
    ZStack {
        Color.black.ignoresSafeArea()

        ScreenShell {
            StateCard(state: .idle) {
                Text("Simple card content")
                    .foregroundStyle(.white)
            }
        }
    }
}

#Preview("ScreenShell - With Primary Button") {
    ZStack {
        Color.black.ignoresSafeArea()

        ScreenShell {
            StateCard(state: .approval) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Approve Changes?")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
        } action: {
            ScreenActionButton("Resume", icon: "play.fill", color: Claude.info) {
                // Action
            }
        } hint: {
            ScreenHint("Double tap to resume")
        }
    }
}
