import SwiftUI

/// Floating settings button for demo mode navigation
/// Positioned at bottom-right corner
/// - alwaysShow: If true, shows even when not in demo mode (for pairing screen)
struct FloatingSettingsButton: View {
    var service = WatchService.shared
    var alwaysShow: Bool = false

    var body: some View {
        if service.isDemoMode || alwaysShow {
            VStack {
                Spacer()
                NavigationLink(destination: SettingsSheet()) {
                    Image(systemName: "gearshape.fill")
                        .font(.claudeTitle)
                        .foregroundStyle(Claude.textMuted)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
        }
    }
}

/// View modifier to add floating settings button as overlay
struct FloatingSettingsModifier: ViewModifier {
    var alwaysShow: Bool = false

    func body(content: Content) -> some View {
        content
            .overlay(FloatingSettingsButton(alwaysShow: alwaysShow))
    }
}

extension View {
    /// Adds a floating settings button overlay (only visible in demo mode)
    func withFloatingSettings(alwaysShow: Bool = false) -> some View {
        modifier(FloatingSettingsModifier(alwaysShow: alwaysShow))
    }
}
