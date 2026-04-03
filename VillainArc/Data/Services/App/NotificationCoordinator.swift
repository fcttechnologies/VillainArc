import Foundation
import SwiftData
import UserNotifications

nonisolated enum NotificationType: String {
    case restTimerComplete
    case stepsGoalComplete
    case stepsEvent
}

nonisolated enum NotificationUserInfoKey {
    static let type = "notificationType"
    static let targetSteps = "targetSteps"
    static let stepCount = "stepCount"
    static let stepsMilestone = "stepsMilestone"
    static let includesNewBest = "stepsIncludesNewBest"
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
        let canPresentRestTimerCompletionAlert = await MainActor.run {
            WorkoutActivityManager.canPresentRestTimerCompletionAlert
        }

        guard !canPresentRestTimerCompletionAlert else {
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
        content.title = "Rest time done"
        content.body = "Time to lift again."
        content.sound = .default
        content.threadIdentifier = "restTimer"
        content.userInfo = [NotificationUserInfoKey.type: NotificationType.restTimerComplete.rawValue]

        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: "restTimerComplete", content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule rest timer notification: \(error)")
        }
    }

    nonisolated static func cancelRestTimer() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["restTimerComplete"])
        center.removeDeliveredNotifications(withIdentifiers: ["restTimerComplete"])
    }

    nonisolated static func deliverStepsGoalCompletion(targetSteps: Int, stepCount: Int) async {
        await deliverStepsEvent(StepsEventNotification(stepCount: stepCount, targetSteps: targetSteps, milestone: .goal, includesNewBest: false, includesGoalCompletion: true))
    }

    nonisolated static func deliverStepsEvent(_ event: StepsEventNotification) async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        await shared.presentToastIfPossible(.stepsEvent(event))

        guard let localEvent = event.localNotificationVersion(for: settings.stepsNotificationMode), status.allowsLocalDelivery else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["stepsGoalComplete", "stepsEvent"])
        center.removeDeliveredNotifications(withIdentifiers: ["stepsGoalComplete", "stepsEvent"])

        let content = UNMutableNotificationContent()
        content.title = localEvent.title
        content.body = localEvent.body
        content.sound = .default
        content.threadIdentifier = "healthGoals"
        content.userInfo = [
            NotificationUserInfoKey.type: NotificationType.stepsEvent.rawValue,
            NotificationUserInfoKey.targetSteps: localEvent.targetSteps as Any,
            NotificationUserInfoKey.stepCount: localEvent.stepCount,
            NotificationUserInfoKey.stepsMilestone: localEvent.milestone?.rawValue as Any,
            NotificationUserInfoKey.includesNewBest: localEvent.includesNewBest
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "stepsEvent", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule steps event notification: \(error)")
        }
    }

    nonisolated static func deliverRestTimerCompletionIfNeeded() async {
        let status = await authorizationStatus()
        let canPresentRestTimerCompletionAlert = await MainActor.run {
            WorkoutActivityManager.canPresentRestTimerCompletionAlert
        }

        guard !canPresentRestTimerCompletionAlert else { return }

        guard status.allowsLocalDelivery else {
            await shared.presentToastIfPossible(.restTimerComplete)
            return
        }
    }

    nonisolated static func presentRestTimerCompletionToastIfPossible() async {
        await shared.presentToastIfPossible(.restTimerComplete)
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

    nonisolated private func presentToastIfPossible(_ toast: ToastManager.Toast) async {
        await MainActor.run {
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
        case .stepsEvent:
            return nil
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
