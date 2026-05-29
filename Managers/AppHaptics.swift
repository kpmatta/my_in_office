import UIKit

enum AppHaptics {
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private static let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private static let notification = UINotificationFeedbackGenerator()

    static func prepare() {
        performOnMain {
            lightImpact.prepare()
            rigidImpact.prepare()
            notification.prepare()
        }
    }

    /// Reversible UI selections such as opening a picker or switching periods.
    static func selection() {
        performOnMain {
            lightImpact.impactOccurred()
            lightImpact.prepare()
        }
    }

    /// More committed mode changes such as entering batch-edit mode.
    static func emphasizedSelection() {
        performOnMain {
            rigidImpact.impactOccurred()
            rigidImpact.prepare()
        }
    }

    static func success() {
        performOnMain {
            notification.notificationOccurred(.success)
            notification.prepare()
        }
    }

    static func error() {
        performOnMain {
            notification.notificationOccurred(.error)
            notification.prepare()
        }
    }

    private static func performOnMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread {
            work()
        } else {
            DispatchQueue.main.async(execute: work)
        }
    }
}
