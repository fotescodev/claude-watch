import SwiftUI

// MARK: - Screen Transition Modifier
/// Replaces the `.id()` + spring animation pattern that causes animation racing
/// Uses a coordinated transition approach that:
/// 1. Fades out the old content
/// 2. Updates the content
/// 3. Fades in the new content
///
/// This prevents the "ghost" effect where old and new views overlap during transitions
struct ScreenTransition: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .transition(reduceMotion ? .identity : .asymmetric(
                insertion: .opacity.animation(.easeIn(duration: 0.15).delay(0.1)),
                removal: .opacity.animation(.easeOut(duration: 0.1))
            ))
    }
}

extension View {
    /// Apply coordinated screen transition
    /// Use this instead of `.id(viewState)` + `.animation()` to prevent racing
    func screenTransition() -> some View {
        modifier(ScreenTransition())
    }
}

// MARK: - Screen Container
/// Container that handles coordinated transitions between screen states
/// Use this in MainView instead of `.id(currentViewState)`
struct ScreenContainer<Content: View, State: Hashable>: View {
    let state: State
    let content: Content

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    init(state: State, @ViewBuilder content: () -> Content) {
        self.state = state
        self.content = content()
    }

    var body: some View {
        content
            .id(state)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: state)
    }
}

// MARK: - Coordinated Animation Modifier
/// Ensures animations don't overlap by using a single animation context
/// Replaces nested spring + pulse animation conflicts
struct CoordinatedAnimation: ViewModifier {
    let isAnimating: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: isAnimating)
    }
}

extension View {
    /// Apply coordinated animation that respects reduce motion
    func coordinatedAnimation(isAnimating: Bool) -> some View {
        modifier(CoordinatedAnimation(isAnimating: isAnimating))
    }
}
