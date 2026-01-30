import SwiftUI
import WidgetKit

/// Control Center button to reject the next pending Remmy action
/// Appears in Control Center on watchOS 26+
@available(watchOS 26.0, *)
struct RejectControl: ControlWidget {
    static let kind = "com.remmy.reject"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: RejectRemmyIntent()) {
                Label {
                    Text("Reject")
                } icon: {
                    Image(systemName: "xmark.circle.fill")
                }
            }
        }
        .displayName("Reject Remmy")
        .description("Reject the next pending Remmy action")
    }
}
