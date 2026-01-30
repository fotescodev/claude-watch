import SwiftUI
import WidgetKit

/// Control Center button to approve the next pending Remmy action
/// Appears in Control Center on watchOS 26+
@available(watchOS 26.0, *)
struct ApproveControl: ControlWidget {
    static let kind = "com.remmy.approve"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ApproveRemmyIntent()) {
                Label {
                    Text("Approve")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
            }
        }
        .displayName("Approve Remmy")
        .description("Approve the next pending Remmy action")
    }
}
