import WatchKit

/// Enhanced haptic feedback service for Claude Watch
class HapticService {
    static let shared = HapticService()
    private let device = WKInterfaceDevice.current()

    private init() {}

    // MARK: - Standard Feedback
    func success() {
        device.play(.success)
    }

    func failure() {
        device.play(.failure)
    }

    func click() {
        device.play(.click)
    }

    func directionUp() {
        device.play(.directionUp)
    }

    func directionDown() {
        device.play(.directionDown)
    }

    func notification() {
        device.play(.notification)
    }

    // MARK: - Contextual Feedback
    func actionAccepted() {
        // Double tap for acceptance
        device.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.device.play(.click)
        }
    }

    func actionDiscarded() {
        device.play(.failure)
    }

    func yoloModeEnabled() {
        // Ascending pattern for YOLO mode
        device.play(.start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.device.play(.directionUp)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.device.play(.success)
        }
    }

    func yoloModeDisabled() {
        // Descending pattern
        device.play(.stop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.device.play(.directionDown)
        }
    }

    func taskCompleted() {
        // Celebration pattern
        device.play(.success)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.device.play(.success)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.device.play(.success)
        }
    }

    func pendingAction() {
        // Alert pattern
        device.play(.notification)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.device.play(.directionUp)
        }
    }

    func modelChanged() {
        device.play(.click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.device.play(.directionUp)
        }
    }

    func connectionEstablished() {
        device.play(.start)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.device.play(.success)
        }
    }

    func connectionLost() {
        device.play(.stop)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.device.play(.failure)
        }
    }

    func promptSent() {
        device.play(.click)
    }

    // MARK: - Progress Feedback
    func progressMilestone(progress: Double) {
        switch progress {
        case 0.25:
            device.play(.directionUp)
        case 0.5:
            device.play(.directionUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.device.play(.click)
            }
        case 0.75:
            device.play(.directionUp)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.device.play(.directionUp)
            }
        case 1.0:
            taskCompleted()
        default:
            break
        }
    }
}
