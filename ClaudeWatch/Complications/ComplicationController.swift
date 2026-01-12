import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Complication Configuration
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "claude_task_progress",
                displayName: "Claude Task",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianSmallFlat,
                    .utilitarianLarge,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular,
                    .graphicExtraLarge
                ]
            ),
            CLKComplicationDescriptor(
                identifier: "claude_quick_action",
                displayName: "Claude Actions",
                supportedFamilies: [
                    .circularSmall,
                    .graphicCircular
                ]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Timeline Configuration
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        handler(nil) // No end date - always current
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let entry = createTimelineEntry(for: complication, date: Date())
        handler(entry)
    }

    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        handler(nil) // No future entries - updates come from app
    }

    // MARK: - Placeholder Templates
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication, progress: 0.6, taskName: "REFACTOR", pendingCount: 3)
        handler(template)
    }

    // MARK: - Template Creation
    private func createTimelineEntry(for complication: CLKComplication, date: Date) -> CLKComplicationTimelineEntry? {
        // Get current state from SessionManager (would need shared data in real app)
        let progress: Float = 0.6
        let taskName = "TASK"
        let pendingCount = 3

        guard let template = createTemplate(for: complication, progress: progress, taskName: taskName, pendingCount: pendingCount) else {
            return nil
        }

        return CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
    }

    private func createTemplate(for complication: CLKComplication, progress: Float, taskName: String, pendingCount: Int) -> CLKComplicationTemplate? {
        switch complication.family {
        case .circularSmall:
            return createCircularSmallTemplate(progress: progress)

        case .modularSmall:
            return createModularSmallTemplate(progress: progress)

        case .modularLarge:
            return createModularLargeTemplate(progress: progress, taskName: taskName, pendingCount: pendingCount)

        case .utilitarianSmall, .utilitarianSmallFlat:
            return createUtilitarianSmallTemplate(progress: progress)

        case .utilitarianLarge:
            return createUtilitarianLargeTemplate(progress: progress, taskName: taskName)

        case .graphicCorner:
            return createGraphicCornerTemplate(progress: progress, taskName: taskName)

        case .graphicCircular:
            return createGraphicCircularTemplate(progress: progress)

        case .graphicRectangular:
            return createGraphicRectangularTemplate(progress: progress, taskName: taskName, pendingCount: pendingCount)

        case .graphicExtraLarge:
            return createGraphicExtraLargeTemplate(progress: progress, taskName: taskName)

        @unknown default:
            return nil
        }
    }

    // MARK: - Individual Template Factories

    private func createCircularSmallTemplate(progress: Float) -> CLKComplicationTemplate {
        CLKComplicationTemplateCircularSmallRingImage(
            imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "terminal")!),
            fillFraction: progress,
            ringStyle: .closed
        )
    }

    private func createModularSmallTemplate(progress: Float) -> CLKComplicationTemplate {
        CLKComplicationTemplateModularSmallRingImage(
            imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "terminal.fill")!),
            fillFraction: progress,
            ringStyle: .closed
        )
    }

    private func createModularLargeTemplate(progress: Float, taskName: String, pendingCount: Int) -> CLKComplicationTemplate {
        CLKComplicationTemplateModularLargeStandardBody(
            headerImageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "terminal.fill")!),
            headerTextProvider: CLKTextProvider(format: "Claude"),
            body1TextProvider: CLKTextProvider(format: "%@ - %d%%", taskName, Int(progress * 100)),
            body2TextProvider: CLKTextProvider(format: "%d pending actions", pendingCount)
        )
    }

    private func createUtilitarianSmallTemplate(progress: Float) -> CLKComplicationTemplate {
        CLKComplicationTemplateUtilitarianSmallRingImage(
            imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "terminal")!),
            fillFraction: progress,
            ringStyle: .closed
        )
    }

    private func createUtilitarianLargeTemplate(progress: Float, taskName: String) -> CLKComplicationTemplate {
        CLKComplicationTemplateUtilitarianLargeFlat(
            textProvider: CLKTextProvider(format: "%@ %d%%", taskName, Int(progress * 100)),
            imageProvider: CLKImageProvider(onePieceImage: UIImage(systemName: "terminal")!)
        )
    }

    private func createGraphicCornerTemplate(progress: Float, taskName: String) -> CLKComplicationTemplate {
        CLKComplicationTemplateGraphicCornerGaugeText(
            gaugeProvider: CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: .green,
                fillFraction: progress
            ),
            outerTextProvider: CLKTextProvider(format: taskName)
        )
    }

    private func createGraphicCircularTemplate(progress: Float) -> CLKComplicationTemplate {
        CLKComplicationTemplateGraphicCircularClosedGaugeImage(
            gaugeProvider: CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: .green,
                fillFraction: progress
            ),
            imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "terminal.fill")!)
        )
    }

    private func createGraphicRectangularTemplate(progress: Float, taskName: String, pendingCount: Int) -> CLKComplicationTemplate {
        CLKComplicationTemplateGraphicRectangularTextGauge(
            headerImageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "terminal.fill")!),
            headerTextProvider: CLKTextProvider(format: "Claude"),
            body1TextProvider: CLKTextProvider(format: "%@ • %d pending", taskName, pendingCount),
            gaugeProvider: CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: .green,
                fillFraction: progress
            )
        )
    }

    private func createGraphicExtraLargeTemplate(progress: Float, taskName: String) -> CLKComplicationTemplate {
        CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeImage(
            gaugeProvider: CLKSimpleGaugeProvider(
                style: .fill,
                gaugeColor: .green,
                fillFraction: progress
            ),
            imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "terminal.fill")!)
        )
    }
}

// MARK: - Complication Refresh
extension ComplicationController {
    static func reloadAllComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}
