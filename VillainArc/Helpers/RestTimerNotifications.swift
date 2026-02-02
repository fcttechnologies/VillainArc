import Foundation
import UserNotifications

enum RestTimerNotifications {
    private static let notificationID = "restTimerComplete"

    static func schedule(endDate: Date, durationSeconds: Int) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        let isAuthorized = await requestAuthorizationIfNeeded(center: center, settings: settings)
        guard isAuthorized else { return }

        cancel(center: center)

        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Time to lift again."
        content.sound = .default

        let interval = max(1, endDate.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)

        do {
            try await center.add(request)
        } catch {
            return
        }
    }

    static func cancel() async {
        cancel(center: UNUserNotificationCenter.current())
    }

    private static func cancel(center: UNUserNotificationCenter) {
        center.removePendingNotificationRequests(withIdentifiers: [notificationID])
        center.removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    private static func requestAuthorizationIfNeeded(
        center: UNUserNotificationCenter,
        settings: UNNotificationSettings
    ) async -> Bool {
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                return false
            }
        case .denied:
            return false
        @unknown default:
            return false
        }
    }
}
