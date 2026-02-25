import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Widget Entry
struct RemmyEntry: TimelineEntry, Sendable {
    let date: Date
    let taskName: String
    let progress: Double
    let pendingCount: Int
    let model: String
    let isConnected: Bool
    let sessionState: ClaudeState

    /// Relevance score for Smart Stack (0.0 to 1.0)
    /// Higher scores surface the widget when most useful
    var relevance: TimelineEntryRelevance? {
        // High relevance when actions pending (user needs to respond)
        if pendingCount > 0 {
            return TimelineEntryRelevance(score: 1.0, duration: 300) // 5 min
        }
        // Medium-high relevance on error or context warning
        if sessionState == .error || sessionState == .context {
            return TimelineEntryRelevance(score: 0.8, duration: 120) // 2 min
        }
        // Medium relevance when actively working
        if sessionState == .working {
            return TimelineEntryRelevance(score: 0.6, duration: 60) // 1 min
        }
        // Low relevance when idle
        return TimelineEntryRelevance(score: 0.1, duration: 900) // 15 min
    }
}

// MARK: - Widget Configuration Intent
struct RemmyWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Remmy Widget"
    static var description = IntentDescription("Configure the Remmy widget display")
}

// MARK: - Provider (with RelevanceKit support for Smart Stack)
struct RemmyProvider: AppIntentTimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.remmy")

    func placeholder(in context: Context) -> RemmyEntry {
        RemmyEntry(
            date: .now,
            taskName: "Remmy",
            progress: 0.5,
            pendingCount: 0,
            model: "opus",
            isConnected: true,
            sessionState: .working
        )
    }

    func snapshot(for configuration: RemmyWidgetConfigIntent, in context: Context) async -> RemmyEntry {
        currentEntry()
    }

    func timeline(for configuration: RemmyWidgetConfigIntent, in context: Context) async -> Timeline<RemmyEntry> {
        let entry = currentEntry()

        // Dynamic refresh based on activity level
        let refreshInterval: TimeInterval
        if entry.pendingCount > 0 {
            // Active approval needed - check frequently
            refreshInterval = 30
        } else if entry.progress > 0 && entry.progress < 1.0 {
            // Task in progress - moderate refresh
            refreshInterval = 60
        } else {
            // Idle - less frequent refresh
            refreshInterval = 900
        }

        return Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
    }

    func recommendations() -> [AppIntentRecommendation<RemmyWidgetConfigIntent>] {
        [AppIntentRecommendation(intent: RemmyWidgetConfigIntent(), description: "Remmy")]
    }

    private func currentEntry() -> RemmyEntry {
        // Read session state from shared UserDefaults
        let sessionState: ClaudeState
        if let stateString = defaults?.string(forKey: "session_state"),
           let decoded = ClaudeState(rawValue: stateString) {
            sessionState = decoded
        } else {
            sessionState = .idle
        }

        return RemmyEntry(
            date: .now,
            taskName: defaults?.string(forKey: "taskName") ?? "Remmy",
            progress: defaults?.double(forKey: "progress") ?? 0,
            pendingCount: defaults?.integer(forKey: "pendingCount") ?? 0,
            model: defaults?.string(forKey: "model") ?? "opus",
            isConnected: defaults?.bool(forKey: "isConnected") ?? false,
            sessionState: sessionState
        )
    }
}

// MARK: - Widget Views
struct RemmyWidgetEntryView: View {
    var entry: RemmyProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryCorner:
            CornerWidgetView(entry: entry)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
        @unknown default:
            CircularWidgetView(entry: entry)
        }
    }
}

// MARK: - Circular Widget
struct CircularWidgetView: View {
    let entry: RemmyEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    private var dimFactor: Double { isLuminanceReduced ? 0.5 : 1.0 }

    private var stateColor: Color {
        entry.sessionState.color
    }

    /// Center content: pending count > progress % > state label
    @ViewBuilder
    private var centerContent: some View {
        if entry.pendingCount > 0 {
            Text("\(entry.pendingCount)")
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(Claude.warning.opacity(dimFactor))
        } else if entry.progress > 0 && entry.progress < 1.0 {
            Text("\(Int(entry.progress * 100))")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(stateColor.opacity(dimFactor))
        } else {
            Text(entry.sessionState.shortLabel)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(stateColor.opacity(dimFactor))
        }
    }

    var body: some View {
        Gauge(value: entry.progress) {
            centerContent
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(stateColor.opacity(dimFactor))
    }
}

// MARK: - Corner Widget
struct CornerWidgetView: View {
    let entry: RemmyEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    private var dimFactor: Double { isLuminanceReduced ? 0.5 : 1.0 }

    private var stateColor: Color {
        entry.sessionState.color
    }

    var body: some View {
        ZStack {
            if entry.pendingCount > 0 {
                Text("\(entry.pendingCount)")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(Claude.warning.opacity(dimFactor))
            } else {
                Text(entry.sessionState.shortLabel)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(stateColor.opacity(dimFactor))
            }
        }
        .widgetLabel {
            Gauge(value: entry.progress) {
                Text("R")
            }
            .gaugeStyle(.accessoryLinearCapacity)
            .tint(stateColor.opacity(dimFactor))
        }
    }
}

// MARK: - Inline Widget
struct InlineWidgetView: View {
    let entry: RemmyEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    private var displayText: String {
        if entry.pendingCount > 0 {
            return "\(entry.pendingCount) pending"
        }
        if entry.sessionState == .working {
            let name = entry.taskName.isEmpty ? "" : ": \(entry.taskName)"
            let truncated = name.count > 20 ? String(name.prefix(20)) + "..." : name
            return "Working\(truncated)"
        }
        return entry.sessionState.displayName
    }

    var body: some View {
        Text(displayText)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(isLuminanceReduced ? .gray : .white)
    }
}

// MARK: - Widget Definition
struct RemmyWidgets: Widget {
    let kind: String = "RemmyWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: RemmyWidgetConfigIntent.self, provider: RemmyProvider()) { entry in
            RemmyWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Remmy")
        .description("Monitor your coding session")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryCircular) {
    RemmyWidgets()
} timeline: {
    // Active session with pending actions
    RemmyEntry(
        date: .now, taskName: "REFACTOR", progress: 0.6,
        pendingCount: 3, model: "OPUS", isConnected: true,
        sessionState: .approval
    )
    // Working session, no pending
    RemmyEntry(
        date: .now, taskName: "auth-service", progress: 0.75,
        pendingCount: 0, model: "OPUS", isConnected: true,
        sessionState: .working
    )
    // Idle
    RemmyEntry(
        date: .now, taskName: "", progress: 0,
        pendingCount: 0, model: "OPUS", isConnected: true,
        sessionState: .idle
    )
}
