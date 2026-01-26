//
//  SwipeActionCard.swift
//  ClaudeWatch
//
//  V2: Swipe gesture for approve/reject
//  Swipe right = approve (green), swipe left = reject (red)
//  50% threshold + haptic feedback
//  DISABLED for Tier 3 actions
//

import SwiftUI
import WatchKit

// MARK: - Swipe Action Card

/// A card that supports swipe gestures for approve/reject
/// - Swipe right: Approve (green fill)
/// - Swipe left: Reject (red fill)
/// - 50% threshold triggers action
/// - Haptic feedback at threshold
/// - DISABLED for Tier 3 (dangerous) actions
struct SwipeActionCard<Content: View>: View {
    let tier: ActionTier
    let onApprove: () -> Void
    let onReject: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var isApproving = false
    @State private var isRejecting = false

    @Environment(\.accessibilityReduceMotion) var reduceMotion

    /// Threshold percentage to trigger action
    private let threshold: CGFloat = 0.5

    /// Card width for calculating threshold
    private let cardWidth: CGFloat = 160

    /// Whether swipe is enabled (disabled for Tier 3)
    private var swipeEnabled: Bool {
        tier.canApproveFromWatch
    }

    var body: some View {
        ZStack {
            // Background fill based on swipe direction
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left side (reject - red)
                    Rectangle()
                        .fill(Claude.danger)
                        .frame(width: max(0, -offset))
                        .opacity(isRejecting ? 1.0 : 0.8)

                    Spacer()

                    // Right side (approve - green)
                    Rectangle()
                        .fill(Claude.success)
                        .frame(width: max(0, offset))
                        .opacity(isApproving ? 1.0 : 0.8)
                }
            }

            // Icons at edges
            HStack {
                // Reject icon (left)
                if offset < 0 {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(min(1.0, Double(-offset) / Double(cardWidth * threshold)))
                        .padding(.leading, 16)
                }

                Spacer()

                // Approve icon (right)
                if offset > 0 {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                        .opacity(min(1.0, Double(offset) / Double(cardWidth * threshold)))
                        .padding(.trailing, 16)
                }
            }

            // Main content
            content()
                .offset(x: swipeEnabled ? offset : 0)
        }
        .clipShape(RoundedRectangle(cornerRadius: Claude.Radius.large))
        .gesture(swipeEnabled ? swipeGesture : nil)
        .accessibilityAction(named: "Approve") {
            if tier.canApproveFromWatch {
                onApprove()
            }
        }
        .accessibilityAction(named: "Reject") {
            onReject()
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Only allow horizontal swipe
                if abs(value.translation.width) > abs(value.translation.height) {
                    offset = value.translation.width

                    // Check threshold and provide haptic
                    let progress = abs(offset) / (cardWidth * threshold)

                    if offset > 0 && progress >= 1.0 && !isApproving {
                        // Crossed approve threshold
                        isApproving = true
                        WKInterfaceDevice.current().play(.click)
                    } else if offset < 0 && progress >= 1.0 && !isRejecting {
                        // Crossed reject threshold
                        isRejecting = true
                        WKInterfaceDevice.current().play(.click)
                    } else if progress < 1.0 {
                        // Below threshold
                        isApproving = false
                        isRejecting = false
                    }
                }
            }
            .onEnded { value in
                let progress = abs(offset) / (cardWidth * threshold)

                if progress >= 1.0 {
                    // Trigger action
                    if offset > 0 {
                        WKInterfaceDevice.current().play(.success)
                        onApprove()
                    } else {
                        WKInterfaceDevice.current().play(.failure)
                        onReject()
                    }
                }

                // Reset with animation
                withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                    offset = 0
                    isApproving = false
                    isRejecting = false
                }
            }
    }
}

// MARK: - Swipe Action Modifier

/// Modifier to add swipe-to-action functionality to any view
struct SwipeActionModifier: ViewModifier {
    let tier: ActionTier
    let onApprove: () -> Void
    let onReject: () -> Void

    func body(content: Content) -> some View {
        if tier.canApproveFromWatch {
            SwipeActionCard(tier: tier, onApprove: onApprove, onReject: onReject) {
                content
            }
        } else {
            // Tier 3: No swipe, just show content
            content
        }
    }
}

// MARK: - View Extension

extension View {
    /// Adds swipe-to-approve/reject functionality
    /// - Parameters:
    ///   - tier: The action tier (swipe disabled for Tier 3)
    ///   - onApprove: Called when swipe right completes
    ///   - onReject: Called when swipe left completes
    func swipeAction(
        tier: ActionTier,
        onApprove: @escaping () -> Void,
        onReject: @escaping () -> Void
    ) -> some View {
        modifier(SwipeActionModifier(tier: tier, onApprove: onApprove, onReject: onReject))
    }
}

// MARK: - Swipe Hint View

/// Shows a hint about swipe gestures
struct SwipeHintView: View {
    let tier: ActionTier

    var body: some View {
        if tier.canApproveFromWatch {
            HStack(spacing: 8) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 10))
                Text("Swipe to approve/reject")
                    .font(.system(size: 9))
            }
            .foregroundColor(Claude.textTertiary)
        } else {
            Text("Swipe disabled for dangerous actions")
                .font(.system(size: 9))
                .foregroundColor(Claude.danger.opacity(0.7))
        }
    }
}

// MARK: - Previews

#Preview("Swipe Action Card - Low Tier") {
    SwipeActionCard(
        tier: .low,
        onApprove: { print("Approved") },
        onReject: { print("Rejected") }
    ) {
        VStack {
            Text("Edit file.swift")
                .font(.headline)
            Text("Low Risk")
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.2))
    }
    .padding()
}

#Preview("Swipe Action Card - High Tier (Disabled)") {
    SwipeActionCard(
        tier: .high,
        onApprove: { print("Should not happen") },
        onReject: { print("Rejected") }
    ) {
        VStack {
            Text("rm -rf ./build")
                .font(.headline)
            Text("DANGER - No swipe")
                .font(.caption)
                .foregroundColor(.red)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.red.opacity(0.2))
    }
    .padding()
}

#Preview("Swipe Hints") {
    VStack(spacing: 20) {
        SwipeHintView(tier: .low)
        SwipeHintView(tier: .medium)
        SwipeHintView(tier: .high)
    }
    .padding()
}
