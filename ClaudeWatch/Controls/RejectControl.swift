import SwiftUI
import WidgetKit

/// Control Center button to reject the next pending Claude action
/// Appears in Control Center on watchOS 26+
@available(watchOS 26.0, *)
struct RejectControl: ControlWidget {
    static let kind = "com.claudewatch.reject"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: RejectClaudeIntent()) {
                Label {
                    Text("Reject")
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .displayName("Reject Claude")
        .description("Reject the next pending Claude action")
    }
}

