import SwiftUI
import WidgetKit

// MARK: - Widget Entry
struct ClaudeEntry: TimelineEntry {
    let date: Date
    let taskName: String
    let progress: Double
    let pendingCount: Int
    let model: String
    let isConnected: Bool

    /// Relevance score for Smart Stack (0.0 to 1.0)
    /// Higher scores surface the widget when most useful
    var relevance: TimelineEntryRelevance? {
        // High relevance when actions pending (user needs to respond)
        if pendingCount > 0 {
            return TimelineEntryRelevance(score: 1.0, duration: 300) // 5 min
        }
        // Medium relevance when actively working
        if progress > 0 && progress < 1.0 {
            return TimelineEntryRelevance(score: 0.6, duration: 60) // 1 min
        }
        // Low relevance when idle
        return TimelineEntryRelevance(score: 0.1, duration: 900) // 15 min
    }
}

// MARK: - Provider (with RelevanceKit support for Smart Stack)
struct ClaudeProvider: TimelineProvider {
    private let defaults = UserDefaults(suiteName: "group.com.claudewatch")

    func placeholder(in context: Context) -> ClaudeEntry {
        ClaudeEntry(
            date: .now,
            taskName: "Claude",
            progress: 0.5,
            pendingCount: 0,
            model: "opus",
            isConnected: true
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ClaudeEntry) -> Void) {
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClaudeEntry>) -> Void) {
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

        let timeline = Timeline(
            entries: [entry],
            policy: .after(Date().addingTimeInterval(refreshInterval))
        )
        completion(timeline)
    }

    private func currentEntry() -> ClaudeEntry {
        ClaudeEntry(
            date: .now,
            taskName: defaults?.string(forKey: "taskName") ?? "Claude",
            progress: defaults?.double(forKey: "progress") ?? 0,
            pendingCount: defaults?.integer(forKey: "pendingCount") ?? 0,
            model: defaults?.string(forKey: "model") ?? "opus",
            isConnected: defaults?.bool(forKey: "isConnected") ?? false
        )
    }
}

// MARK: - Widget Views
struct ClaudeWidgetEntryView: View {
    var entry: ClaudeProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
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
    let entry: ClaudeEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        ZStack {
            // Progress Ring - dimmed in always-on mode
            Circle()
                .stroke(progressColor.opacity(isLuminanceReduced ? 0.15 : 0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(progressColor.opacity(isLuminanceReduced ? 0.5 : 1.0), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center Content
            VStack(spacing: 0) {
                Image(systemName: entry.pendingCount > 0 ? "hand.raised.fill" : "terminal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(iconColor.opacity(isLuminanceReduced ? 0.6 : 1.0))

                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount)")
                        .font(.caption2.weight(.bold).monospaced())
                        .foregroundColor(Color.orange.opacity(isLuminanceReduced ? 0.6 : 1.0))
                }
            }
        }
        .padding(2)
    }

    private var progressColor: Color {
        .green
    }

    private var iconColor: Color {
        entry.pendingCount > 0 ? .orange : .green
    }
}

// MARK: - Rectangular Widget
struct RectangularWidgetView: View {
    let entry: ClaudeEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.caption2)
                    .foregroundColor(greenColor)

                Text("CLAUDE")
                    .font(.caption2.weight(.bold).monospaced())
                    .foregroundColor(greenColor)

                Spacer()

                if entry.isConnected {
                    Circle()
                        .fill(greenColor)
                        .frame(width: 6, height: 6)
                }
            }

            // Task Info
            HStack {
                Text(entry.taskName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(isLuminanceReduced ? .gray : .white)

                Spacer()

                Text("\(Int(entry.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(greenColor)
            }

            // Progress Bar - dimmed in always-on mode
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(isLuminanceReduced ? 0.15 : 0.3))
                        .frame(height: 3)
                        .cornerRadius(1.5)

                    Rectangle()
                        .fill(greenColor)
                        .frame(width: geometry.size.width * entry.progress, height: 3)
                        .cornerRadius(1.5)
                }
            }
            .frame(height: 3)

            // Bottom Info
            HStack {
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount) pending")
                        .font(.caption2.monospaced())
                        .foregroundColor(orangeColor)
                } else {
                    Text("All clear")
                        .font(.caption2.monospaced())
                        .foregroundColor(greenColor)
                }

                Spacer()

                Text(entry.model)
                    .font(.caption2.weight(.medium).monospaced())
                    .foregroundColor(purpleColor)
            }
        }
        .padding(4)
    }

    // Dimmed colors for always-on mode
    private var greenColor: Color {
        Color.green.opacity(isLuminanceReduced ? 0.5 : 1.0)
    }

    private var orangeColor: Color {
        Color.orange.opacity(isLuminanceReduced ? 0.5 : 1.0)
    }

    private var purpleColor: Color {
        Color.purple.opacity(isLuminanceReduced ? 0.5 : 1.0)
    }
}

// MARK: - Corner Widget
struct CornerWidgetView: View {
    let entry: ClaudeEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        ZStack {
            // Arc Progress - dimmed in always-on mode
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(greenColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(entry.progress * 100))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(isLuminanceReduced ? .gray : .white)

                Text("%")
                    .font(.caption2.monospaced())
                    .foregroundColor(.gray)
            }
        }
    }

    private var greenColor: Color {
        Color.green.opacity(isLuminanceReduced ? 0.5 : 1.0)
    }
}

// MARK: - Inline Widget
struct InlineWidgetView: View {
    let entry: ClaudeEntry
    @Environment(\.isLuminanceReduced) var isLuminanceReduced

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "terminal.fill")
                .foregroundColor(isLuminanceReduced ? .gray : .white)

            Text("\(entry.taskName) \(Int(entry.progress * 100))%")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isLuminanceReduced ? .gray : .white)

            if entry.pendingCount > 0 {
                Text("• \(entry.pendingCount)")
                    .foregroundColor(Color.orange.opacity(isLuminanceReduced ? 0.5 : 1.0))
            }
        }
    }
}

// MARK: - Widget Definition
struct ClaudeWatchWidgets: Widget {
    let kind: String = "ClaudeWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClaudeProvider()) { entry in
            ClaudeWidgetEntryView(entry: entry)
                .containerBackground(.black, for: .widget)
        }
        .configurationDisplayName("Claude Code")
        .description("Monitor your Claude Code session")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryCorner,
            .accessoryInline
        ])
    }
}

#Preview(as: .accessoryRectangular) {
    ClaudeWatchWidgets()
} timeline: {
    ClaudeEntry(date: .now, taskName: "REFACTOR", progress: 0.6, pendingCount: 3, model: "OPUS", isConnected: true)
    ClaudeEntry(date: .now, taskName: "BUILD", progress: 0.9, pendingCount: 0, model: "OPUS", isConnected: true)
}
