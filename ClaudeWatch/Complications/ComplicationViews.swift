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
}

// MARK: - Provider
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
        let timeline = Timeline(entries: [currentEntry()], policy: .after(Date().addingTimeInterval(900)))
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

    var body: some View {
        ZStack {
            // Progress Ring
            Circle()
                .stroke(Color.green.opacity(0.3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Center Content
            VStack(spacing: 0) {
                Image(systemName: entry.pendingCount > 0 ? "hand.raised.fill" : "terminal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(entry.pendingCount > 0 ? .orange : .green)

                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(2)
    }
}

// MARK: - Rectangular Widget
struct RectangularWidgetView: View {
    let entry: ClaudeEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Header
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)

                Text("CLAUDE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)

                Spacer()

                if entry.isConnected {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                }
            }

            // Task Info
            HStack {
                Text(entry.taskName)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))

                Spacer()

                Text("\(Int(entry.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.green)
            }

            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 3)
                        .cornerRadius(1.5)

                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geometry.size.width * entry.progress, height: 3)
                        .cornerRadius(1.5)
                }
            }
            .frame(height: 3)

            // Bottom Info
            HStack {
                if entry.pendingCount > 0 {
                    Text("\(entry.pendingCount) pending")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.orange)
                } else {
                    Text("All clear")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.green)
                }

                Spacer()

                Text(entry.model)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.purple)
            }
        }
        .padding(4)
    }
}

// MARK: - Corner Widget
struct CornerWidgetView: View {
    let entry: ClaudeEntry

    var body: some View {
        ZStack {
            // Arc Progress
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(Color.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 0) {
                Text("\(Int(entry.progress * 100))")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))

                Text("%")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Inline Widget
struct InlineWidgetView: View {
    let entry: ClaudeEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "terminal.fill")

            Text("\(entry.taskName) \(Int(entry.progress * 100))%")
                .font(.system(size: 12, design: .monospaced))

            if entry.pendingCount > 0 {
                Text("• \(entry.pendingCount)")
                    .foregroundColor(.orange)
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
