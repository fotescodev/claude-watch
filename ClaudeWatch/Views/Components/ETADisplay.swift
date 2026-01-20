//
//  ETADisplay.swift
//  ClaudeWatch
//
//  Displays estimated time remaining for running tasks
//  Addresses Jordan's need for progress monitoring
//

import SwiftUI

/// Compact ETA display showing clock icon and time remaining
struct ETADisplay: View {
    let progress: TaskProgress

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.system(size: 10))
                .foregroundColor(Claude.textSecondary)

            Text(progress.formattedETA)
                .font(.claudeCaption)
                .foregroundColor(Claude.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Estimated time remaining: \(progress.formattedETA)")
    }
}

/// Larger progress display with percentage, ETA, and elapsed time
struct ProgressDisplay: View {
    let progress: TaskProgress

    var body: some View {
        VStack(spacing: Claude.Spacing.sm) {
            // Task name if available
            if let name = progress.taskName {
                HStack {
                    Text(name)
                        .font(.claudeCaption)
                        .foregroundColor(Claude.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text("\(progress.percentInt)%")
                        .font(.claudeCaption)
                        .fontWeight(.semibold)
                        .foregroundColor(Claude.success)
                }
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Claude.surface2)
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Claude.success)
                        .frame(width: geo.size.width * progress.percentComplete, height: 6)
                }
            }
            .frame(height: 6)

            // Stats row
            HStack {
                Text(progress.progressString)
                    .font(.system(size: 10))
                    .foregroundColor(Claude.textSecondary)

                Spacer()

                ETADisplay(progress: progress)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        var desc = "\(progress.percentInt)% complete"
        if let name = progress.taskName {
            desc = "\(name): " + desc
        }
        if progress.estimatedRemainingSeconds != nil {
            desc += ", \(progress.formattedETA) remaining"
        }
        return desc
    }
}

/// Minimal inline progress for tight spaces
struct InlineProgress: View {
    let progress: TaskProgress

    var body: some View {
        HStack(spacing: 6) {
            // Mini progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Claude.surface2)

                    Capsule()
                        .fill(Claude.success)
                        .frame(width: geo.size.width * progress.percentComplete)
                }
            }
            .frame(width: 40, height: 4)

            Text("\(progress.percentInt)%")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Claude.textSecondary)
        }
    }
}

// MARK: - Previews

#Preview("ETADisplay") {
    VStack(spacing: 20) {
        ETADisplay(progress: .sample)
        ETADisplay(progress: .earlyStage)
        ETADisplay(progress: .nearlyComplete)
    }
    .padding()
    .background(Claude.surface1)
}

#Preview("ProgressDisplay") {
    VStack(spacing: 20) {
        ProgressDisplay(progress: .sample)
        ProgressDisplay(progress: .earlyStage)
    }
    .padding()
    .background(Claude.surface1)
}

#Preview("InlineProgress") {
    VStack(spacing: 20) {
        InlineProgress(progress: .sample)
        InlineProgress(progress: .earlyStage)
        InlineProgress(progress: .nearlyComplete)
    }
    .padding()
    .background(Claude.surface1)
}
