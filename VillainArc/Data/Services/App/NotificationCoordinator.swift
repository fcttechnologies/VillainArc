import Foundation
import SwiftData
import UserNotifications

nonisolated enum NotificationType: String {
    case restTimerComplete
    case stepsGoalComplete
}

nonisolated enum NotificationUserInfoKey {
    static let type = "notificationType"
    static let targetSteps = "targetSteps"
    static let stepCount = "stepCount"
}

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()

    private override init() {
        super.init()
    }

    func installDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }

    nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    nonisolated static func requestAuthorizationIfNeededAfterOnboarding() async {
        let status = await authorizationStatus()
        guard status == .notDetermined else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    nonisolated static func scheduleRestTimer(endDate: Date) async {
        let settings = currentAppSettingsSnapshot()
        guard settings.restTimerNotificationsEnabled else {
            cancelRestTimer()
            return
        }

        let status = await authorizationStatus()
        guard status.allowsLocalDelivery else {
            cancelRestTimer()
            return
        }

        let center = UNUserNotificationCenter.current()
        cancelRestTimer()

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time to lift again."
        content.sound = .default
        content.threadIdentifier = "restTimer"
        content.userInfo = [NotificationUserInfoKey.type: NotificationType.restTimerComplete.rawValue]

        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "restTimerComplete", content: content, trigger: trigger)

        try? await center.add(request)
    }

    nonisolated static func cancelRestTimer() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["restTimerComplete"])
        center.removeDeliveredNotifications(withIdentifiers: ["restTimerComplete"])
    }

    nonisolated static func deliverStepsGoalCompletion(targetSteps: Int, stepCount: Int) async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        guard settings.stepsNotificationMode != .off, status.allowsLocalDelivery else {
            await shared.presentToastIfPossible(.stepsGoalComplete(targetSteps: targetSteps, stepCount: stepCount))
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["stepsGoalComplete"])
        center.removeDeliveredNotifications(withIdentifiers: ["stepsGoalComplete"])
        let compactStepCount = compactStepsText(stepCount)
        let compactTargetSteps = compactStepsText(targetSteps)

        let content = UNMutableNotificationContent()
        content.title = "Steps Goal Reached"
        content.body = "You hit \(compactStepCount) steps and cleared your \(compactTargetSteps) daily step goal."
        content.sound = .default
        content.threadIdentifier = "healthGoals"
        content.userInfo = [
            NotificationUserInfoKey.type: NotificationType.stepsGoalComplete.rawValue,
            NotificationUserInfoKey.targetSteps: targetSteps,
            NotificationUserInfoKey.stepCount: stepCount
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "stepsGoalComplete", content: content, trigger: trigger)
        try? await center.add(request)
    }

    nonisolated static func deliverRestTimerCompletionIfNeeded() async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        guard settings.restTimerNotificationsEnabled, status.allowsLocalDelivery else {
            await shared.presentToastIfPossible(.restTimerComplete)
            return
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        if let toast = toast(for: notification.request.content.userInfo) {
            await presentToastIfPossible(toast)
        }

        return []
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        center.removeDeliveredNotifications(withIdentifiers: [response.notification.request.identifier])
    }

    nonisolated private static func currentAppSettingsSnapshot() -> AppSettingsSnapshot {
        let context = ModelContext(SharedModelContainer.container)
        context.autosaveEnabled = false
        return AppSettingsSnapshot(settings: try? context.fetch(AppSettings.single).first)
    }

    nonisolated private static func compactStepsText(_ steps: Int) -> String {
        steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
    }

    nonisolated private func presentToastIfPossible(_ toast: ToastManager.Toast) async {
        await MainActor.run {
            guard ToastManager.shared.canPresentToasts else { return }
            ToastManager.shared.show(toast)
        }
    }

    private func toast(for userInfo: [AnyHashable: Any]) -> ToastManager.Toast? {
        guard let rawValue = userInfo[NotificationUserInfoKey.type] as? String, let type = NotificationType(rawValue: rawValue) else {
            return nil
        }

        switch type {
        case .restTimerComplete:
            return .restTimerComplete
        case .stepsGoalComplete:
            let targetSteps = userInfo[NotificationUserInfoKey.targetSteps] as? Int ?? 0
            let stepCount = userInfo[NotificationUserInfoKey.stepCount] as? Int ?? 0
            return .stepsGoalComplete(targetSteps: targetSteps, stepCount: stepCount)
        }
    }
}

nonisolated extension UNAuthorizationStatus {
    var allowsLocalDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined, .denied:
            return false
        @unknown default:
            return false
        }
    }
}
