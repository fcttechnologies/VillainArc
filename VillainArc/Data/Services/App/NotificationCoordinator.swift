import Foundation
import SwiftData
import UserNotifications

nonisolated enum NotificationType: String {
    case restTimerComplete
    case stepsGoalComplete
    case stepsEvent
    case sleepGoalComplete
    case weeklyHealthCoaching
}

nonisolated enum NotificationUserInfoKey {
    static let type = "notificationType"
    static let targetSteps = "targetSteps"
    static let stepCount = "stepCount"
    static let stepsMilestone = "stepsMilestone"
    static let includesNewBest = "stepsIncludesNewBest"
    static let sleepWakeDay = "sleepWakeDay"
    static let weeklyIncludesSteps = "weeklyIncludesSteps"
    static let weeklyIncludesSleep = "weeklyIncludesSleep"
    static let weeklyWeekStart = "weeklyWeekStart"
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
        content.userInfo = [NotificationUserInfoKey.type: NotificationType.stepsEvent.rawValue, NotificationUserInfoKey.targetSteps: localEvent.targetSteps as Any, NotificationUserInfoKey.stepCount: localEvent.stepCount, NotificationUserInfoKey.stepsMilestone: localEvent.milestone?.rawValue as Any, NotificationUserInfoKey.includesNewBest: localEvent.includesNewBest]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "stepsEvent", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule steps event notification: \(error)")
        }
    }

    nonisolated static func deliverSleepGoal(_ event: SleepGoalNotification) async {
        let settings = currentAppSettingsSnapshot()
        let status = await authorizationStatus()

        await shared.presentToastIfPossible(.sleepGoalComplete(event))

        guard let localEvent = event.localNotificationVersion(for: settings.sleepNotificationMode), status.allowsLocalDelivery else {
            return
        }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["sleepGoalComplete"])
        center.removeDeliveredNotifications(withIdentifiers: ["sleepGoalComplete"])

        let content = UNMutableNotificationContent()
        content.title = localEvent.title
        content.body = localEvent.body
        content.sound = .default
        content.threadIdentifier = "healthGoals"
        content.userInfo = [NotificationUserInfoKey.type: NotificationType.sleepGoalComplete.rawValue, NotificationUserInfoKey.sleepWakeDay: localEvent.wakeDay.timeIntervalSince1970]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "sleepGoalComplete", content: content, trigger: trigger)
        do {
            try await center.add(request)
        } catch {
            print("Failed to schedule sleep goal notification: \(error)")
        }
    }

    nonisolated static func deliverWeeklyHealthCoaching(averageSteps: Int?, averageSleepDuration: TimeInterval?, weekStart: Date) async -> Bool {
        let status = await authorizationStatus()
        guard status.allowsLocalDelivery else { return false }
        guard averageSteps != nil || averageSleepDuration != nil else { return false }

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weeklyHealthCoaching"])
        center.removeDeliveredNotifications(withIdentifiers: ["weeklyHealthCoaching"])

        let content = UNMutableNotificationContent()
        content.title = "Weekly Health Recap"
        content.body = weeklyHealthCoachingBody(averageSteps: averageSteps, averageSleepDuration: averageSleepDuration)
        content.sound = .default
        content.threadIdentifier = "healthGoals"
        content.userInfo = [
            NotificationUserInfoKey.type: NotificationType.weeklyHealthCoaching.rawValue,
            NotificationUserInfoKey.weeklyIncludesSteps: averageSteps != nil,
            NotificationUserInfoKey.weeklyIncludesSleep: averageSleepDuration != nil,
            NotificationUserInfoKey.weeklyWeekStart: weekStart.timeIntervalSince1970
        ]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "weeklyHealthCoaching", content: content, trigger: trigger)
        do {
            try await center.add(request)
            return true
        } catch {
            print("Failed to schedule weekly health coaching notification: \(error)")
            return false
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

        guard let destination = notificationTapDestination(for: response.notification.request.content.userInfo) else {
            return
        }

        await MainActor.run {
            AppRouter.shared.handleNotificationDestination(destination)
        }
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
        case .stepsEvent, .weeklyHealthCoaching:
            return nil
        case .sleepGoalComplete:
            return nil
        }
    }

    private func notificationTapDestination(for userInfo: [AnyHashable: Any]) -> AppRouter.Destination? {
        guard let rawValue = userInfo[NotificationUserInfoKey.type] as? String, let type = NotificationType(rawValue: rawValue) else {
            return nil
        }

        switch type {
        case .stepsGoalComplete, .stepsEvent:
            return .stepsDistanceHistory
        case .weeklyHealthCoaching:
            let includesSteps = userInfo[NotificationUserInfoKey.weeklyIncludesSteps] as? Bool ?? false
            return includesSteps ? .stepsDistanceHistory : .sleepHistory
        case .sleepGoalComplete:
            return .sleepHistory
        case .restTimerComplete:
            return nil
        }
    }

    nonisolated private static func weeklyHealthCoachingBody(averageSteps: Int?, averageSleepDuration: TimeInterval?) -> String {
        switch (averageSteps, averageSleepDuration) {
        case let (.some(steps), .some(sleepDuration)):
            return "Last week you averaged \(compactStepsText(steps)) steps and \(formattedDurationText(sleepDuration)) of sleep."
        case let (.some(steps), .none):
            return "Last week you averaged \(compactStepsText(steps)) steps."
        case let (.none, .some(sleepDuration)):
            return "Last week you averaged \(formattedDurationText(sleepDuration)) of sleep."
        case (.none, .none):
            return "Your weekly health recap is ready."
        }
    }

    nonisolated private static func compactStepsText(_ steps: Int) -> String {
        steps.formatted(.number.notation(.compactName).precision(.fractionLength(0...1))).lowercased()
    }

    nonisolated private static func formattedDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int((duration / 60).rounded())
        let hours = max(totalMinutes / 60, 0)
        let minutes = max(totalMinutes % 60, 0)

        if minutes == 0 {
            return "\(hours)h"
        }
        if hours == 0 {
            return "\(minutes)m"
        }
        return "\(hours)h \(minutes)m"
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
