//
//  BreathingAnimation.swift
//  ClaudeWatch
//
//  V2: Idle state breathing animation
//  3s ease-in-out cycle, respects Reduce Motion
//

import SwiftUI

// MARK: - Breathing Animation Modifier

/// Applies a subtle breathing animation to any view
/// - 3 second ease-in-out cycle
/// - Scale: 0.9 → 1.0 → 0.9
/// - Opacity: 0.6 → 1.0 → 0.6
/// - Respects accessibilityReduceMotion
struct BreathingAnimationModifier: ViewModifier {
    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Animation duration in seconds
    var duration: Double = 3.0

    /// Minimum scale (at exhale)
    var minScale: CGFloat = 0.9

    /// Minimum opacity (at exhale)
    var minOpacity: Double = 0.6

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.0 : minScale))
            .opacity(reduceMotion ? 1.0 : (isBreathing ? 1.0 : minOpacity))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            }
    }
}

// MARK: - View Extension

extension View {
    /// Applies a breathing animation (idle state polish)
    /// - Parameters:
    ///   - duration: Animation cycle duration (default: 3s)
    ///   - minScale: Minimum scale at exhale (default: 0.9)
    ///   - minOpacity: Minimum opacity at exhale (default: 0.6)
    func breathingAnimation(
        duration: Double = 3.0,
        minScale: CGFloat = 0.9,
        minOpacity: Double = 0.6
    ) -> some View {
        modifier(BreathingAnimationModifier(
            duration: duration,
            minScale: minScale,
            minOpacity: minOpacity
        ))
    }
}

// MARK: - Breathing Circle

/// A circle with built-in breathing animation
/// Used for idle state indicator
struct BreathingCircle: View {
    var color: Color = Claude.anthropicOrange
    var size: CGFloat = 40

    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        ZStack {
            // Outer glow (more pronounced breathing)
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.1 : 0.85))
                .opacity(reduceMotion ? 0.3 : (isBreathing ? 0.5 : 0.2))

            // Inner circle
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .scaleEffect(reduceMotion ? 1.0 : (isBreathing ? 1.0 : 0.9))
                .opacity(reduceMotion ? 1.0 : (isBreathing ? 1.0 : 0.6))
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                isBreathing = true
            }
        }
        .accessibilityLabel("Claude is idle and ready")
    }
}

// MARK: - Claude Face Logo

/// The official Claude face logo from asset catalog
/// Used in Unpaired and Connected Idle screens
struct ClaudeFaceLogo: View {
    var size: CGFloat = 60
    var animated: Bool = false

    @State private var isBreathing = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    var body: some View {
        Image("ClaudeLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .scaleEffect(animated && !reduceMotion ? (isBreathing ? 1.0 : 0.95) : 1.0)
            .opacity(animated && !reduceMotion ? (isBreathing ? 1.0 : 0.8) : 1.0)
            .onAppear {
                guard animated && !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            }
            .accessibilityLabel("Claude logo")
    }
}

// MARK: - Breathing Logo (Legacy wrapper)

/// Claude logo with breathing animation for idle state
struct BreathingLogo: View {
    var size: CGFloat = 60

    var body: some View {
        ClaudeFaceLogo(size: size, animated: true)
    }
}

// MARK: - Previews

#Preview("Breathing Animation Modifier") {
    VStack(spacing: 20) {
        Text("Breathing Text")
            .font(.title3)
            .breathingAnimation()

        Circle()
            .fill(Claude.anthropicOrange)
            .frame(width: 40, height: 40)
            .breathingAnimation()
    }
}

#Preview("Breathing Circle") {
    VStack(spacing: 30) {
        BreathingCircle(color: Claude.anthropicOrange, size: 40)
        BreathingCircle(color: .blue, size: 30)
        BreathingCircle(color: .green, size: 20)
    }
}

#Preview("Breathing Logo") {
    BreathingLogo(size: 60)
}
