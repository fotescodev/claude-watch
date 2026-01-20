//
//  DangerIndicator.swift
//  ClaudeWatch
//
//  Visual indicator for dangerous/destructive operations
//

import SwiftUI

/// Compact danger indicator showing warning icon and "Destructive" label
/// Used in action cards for file_delete and dangerous bash commands
struct DangerIndicator: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Claude.danger)

            Text("Destructive")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Claude.danger)
        }
    }
}

/// Larger danger badge for detail views
struct DangerBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))

            Text("Destructive Action")
                .font(.claudeCaption)
                .fontWeight(.semibold)
        }
        .foregroundColor(Claude.danger)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Claude.dangerBackground)
        .clipShape(Capsule())
    }
}

/// Hint text shown below dangerous action cards
struct DangerHint: View {
    var body: some View {
        Text("Review carefully")
            .font(.system(size: 10))
            .foregroundColor(Claude.danger)
    }
}

// MARK: - Previews

#Preview("DangerIndicator") {
    VStack(spacing: 20) {
        DangerIndicator()

        DangerBadge()

        DangerHint()
    }
    .padding()
    .background(Claude.surface1)
}
