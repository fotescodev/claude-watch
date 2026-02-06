//
//  ModeIndicator.swift
//  Remmy
//
//  V3: Agent mode indicator component for status bar
//  Shows current operating mode (Normal/Plan/Auto)
//

import SwiftUI

// MARK: - Agent Operating Mode

/// The operating mode of the Claude agent
enum AgentMode: String, CaseIterable {
    case normal   // Standard mode - green circle
    case plan     // Plan mode - purple rounded square
    case auto     // Auto mode - orange pill

    var color: Color {
        switch self {
        case .normal: return Claude.success      // Green
        case .plan: return Claude.plan           // #5E5CE6
        case .auto: return Claude.warning        // Orange
        }
    }

    var letter: String {
        switch self {
        case .normal: return "N"
        case .plan: return "P"
        case .auto: return "A"
        }
    }
}

// MARK: - Mode Indicator View

/// Compact mode indicator badge for status bar
/// Shows letter inside colored shape based on mode
struct ModeIndicator: View {
    let mode: AgentMode

    var body: some View {
        ZStack {
            modeShape
                .fill(mode.color)
                .frame(width: 18, height: 18)

            Text(mode.letter)
                .font(.claudeMicroMono)
                .foregroundStyle(.black)
        }
    }

    @ViewBuilder
    private var modeShape: some View {
        switch mode {
        case .normal:
            Circle()
        case .plan:
            RoundedRectangle(cornerRadius: 4)
        case .auto:
            Capsule()
        }
    }
}

// MARK: - Preview

#Preview("Mode Indicators") {
    HStack(spacing: 16) {
        ForEach(AgentMode.allCases, id: \.self) { mode in
            VStack {
                ModeIndicator(mode: mode)
                Text(mode.rawValue.capitalized)
                    .font(.caption2)
            }
        }
    }
    .padding()
    .background(Color.black)
}
