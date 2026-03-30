import Foundation
import SwiftData
import UserNotifications

final class NotificationCoordinator: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationCoordinator()

    private enum NotificationType: String {
        case restTimerComplete
        case stepsGoalComplete
    }

    private enum UserInfoKey {
        static let type = "notificationType"
        static let targetSteps = "targetSteps"
        static let stepCount = "stepCount"
    }

    private let center = UNUserNotificationCenter.current()
    private let restTimerNotificationID = "restTimerComplete"
    private let stepsGoalNotificationID = "stepsGoalComplete"

    private override init() {
        super.init()
    }

    func installDelegate() {
        center.delegate = self
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeededAfterOnboarding() async {
        let status = await authorizationStatus()
        guard status == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func scheduleRestTimer(endDate: Date) async {
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

        cancelRestTimer()

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time to lift again."
        content.sound = .default
        content.threadIdentifier = "restTimer"
        content.userInfo = [UserInfoKey.type: NotificationType.restTimerComplete.rawValue]

        let interval = max(0.1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: restTimerNotificationID, content: content, trigger: trigger)

        try? await center.add(request)
    }

    func cancelRestTimer() {
        center.removePendingNotificationRequests(withIdentifiers: [restTimerNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [restTimerNotificationID])
    }

    func deliverStepsGoalCompletion(targetSteps: Int, stepCount: Int) async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        guard settings.stepsNotificationMode != .off, status.allowsLocalDelivery else {
            await presentToastIfPossible(.stepsGoalComplete(targetSteps: targetSteps, stepCount: stepCount))
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [stepsGoalNotificationID])
        center.removeDeliveredNotifications(withIdentifiers: [stepsGoalNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "Steps goal reached"
        content.body = "You hit \(stepCount.formatted(.number)) steps and cleared your \(targetSteps.formatted(.number)) step target."
        content.sound = .default
        content.threadIdentifier = "healthGoals"
        content.userInfo = [
            UserInfoKey.type: NotificationType.stepsGoalComplete.rawValue,
            UserInfoKey.targetSteps: targetSteps,
            UserInfoKey.stepCount: stepCount
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: stepsGoalNotificationID, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func deliverRestTimerCompletionIfNeeded() async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        guard settings.restTimerNotificationsEnabled, status.allowsLocalDelivery else {
            await presentToastIfPossible(.restTimerComplete)
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

    private func currentAppSettingsSnapshot() -> AppSettingsSnapshot {
        let context = SharedModelContainer.container.mainContext
        return AppSettingsSnapshot(settings: try? context.fetch(AppSettings.single).first)
    }

    private func presentToastIfPossible(_ toast: ToastManager.Toast) async {
        await MainActor.run {
            guard ToastManager.shared.canPresentToasts else { return }
            ToastManager.shared.show(toast)
        }
    }

    private func toast(for userInfo: [AnyHashable: Any]) -> ToastManager.Toast? {
        guard let rawValue = userInfo[UserInfoKey.type] as? String, let type = NotificationType(rawValue: rawValue) else {
            return nil
        }

        switch type {
        case .restTimerComplete:
            return .restTimerComplete
        case .stepsGoalComplete:
            let targetSteps = userInfo[UserInfoKey.targetSteps] as? Int ?? 0
            let stepCount = userInfo[UserInfoKey.stepCount] as? Int ?? 0
            return .stepsGoalComplete(targetSteps: targetSteps, stepCount: stepCount)
        }
    }
}

extension UNAuthorizationStatus {
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
