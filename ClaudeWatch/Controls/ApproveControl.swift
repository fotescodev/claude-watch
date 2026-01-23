import SwiftUI
import WidgetKit

/// Control Center button to approve the next pending Claude action
/// Appears in Control Center on watchOS 26+
@available(watchOS 26.0, *)
struct ApproveControl: ControlWidget {
    static let kind = "com.claudewatch.approve"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ApproveClaudeIntent()) {
                Label {
                    Text("Approve")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
        }
        .displayName("Approve Claude")
        .description("Approve the next pending Claude action")
    }
}

